"""NAND Guardian backend with real XGBoost .pkl inference support."""

from datetime import datetime
from pathlib import Path
from collections import deque
import json
import os
import pickle
import time

from flask import Flask, jsonify, request
from flask_cors import CORS
import numpy as np

try:
    import joblib
except ImportError:
    joblib = None

try:
    import shap
except ImportError:
    shap = None

try:
    from tensorflow.keras.models import load_model as keras_load_model
except Exception:
    keras_load_model = None

app = Flask(__name__)

# Enable CORS for frontend (adjust origins for production)
CORS(app, resources={
    r"/api/*": {
        "origins": "*",  # Change to ["http://localhost:5173"] for production
        "methods": ["GET", "POST", "OPTIONS"],
        "allow_headers": ["Content-Type"]
    }
})


def _resolve_artifact_path(primary_env, legacy_env, default_candidates):
    raw_path = os.getenv(primary_env) or (os.getenv(legacy_env) if legacy_env else None)
    if raw_path:
        return Path(raw_path)

    for candidate in default_candidates:
        candidate_path = Path(candidate)
        if candidate_path.exists():
            return candidate_path

    return Path(default_candidates[0])

XGBOOST_MODEL_PATH = _resolve_artifact_path(
    'MODEL_PATH',
    'XGBOOST_MODEL_PATH',
    ['./model/xgboost.pkl', './model/xgboost_model.pkl'],
)
LSTM_MODEL_PATH = _resolve_artifact_path(
    'LSTM_MODEL_PATH',
    None,
    ['./model/lstm.h5', './model/lstm_model.h5'],
)
FEATURES_PATH = _resolve_artifact_path(
    'FEATURES_PATH',
    None,
    ['./model/features.json'],
)
INGEST_TTL_SECONDS = float(os.getenv('INGEST_TTL_SECONDS', '6'))
LSTM_WINDOW = int(os.getenv('LSTM_WINDOW', '20'))

FEATURE_ORDER = [
    'ecc_count',
    'ecc_rate',
    'retries',
    'temperature',
    'wear_level',
    'latency',
]

FEATURE_LABELS = {
    'ecc_count': 'ECC count',
    'ecc_rate': 'ECC rate',
    'retries': 'Retry count',
    'temperature': 'Temperature',
    'wear_level': 'Wear level',
    'latency': 'Read latency',
}

_model = None
_model_load_error = None
_shap_explainer = None
_model_feature_order = list(FEATURE_ORDER)
_lstm_model = None
_lstm_model_load_error = None
_features_file_load_error = None
_features_from_file = []
_unmapped_model_features = []
_last_feature_mapping = []
_last_derived_features = {}
_last_model_input_vector = []
_latest_telemetry = None
_latest_telemetry_source = 'simulation'
_latest_ingest_epoch = None
_latest_prediction = {
    'health_score': 72,
    'failure_probability': 0.15,
    'remaining_life_days': 320,
}

_lstm_history = deque(maxlen=max(LSTM_WINDOW, 1))

FEATURE_ALIASES = {
    'ecc_count': ['ecc_count', 'ecccount', 'ecc_total', 'ecc_errors', 'ecc_error_count'],
    'ecc_rate': ['ecc_rate', 'eccrate', 'ecc_acceleration', 'ecc_accel', 'ecc_per_page'],
    'retries': ['retries', 'retry_count', 'retrycount', 'io_retries', 'retry_rate'],
    'temperature': ['temperature', 'temp', 'temp_c', 'temperature_c', 'avg_temp'],
    'wear_level': ['wear_level', 'wearlevel', 'wear', 'wear_percent', 'percent_worn'],
    'latency': ['latency', 'read_latency', 'io_latency', 'latency_ms', 'avg_latency'],
}

SMART_BASE_KEYS = ['smart_5_raw', 'smart_187_raw', 'smart_197_raw', 'smart_198_raw']
SMART_HISTORY_WINDOW = 20

_smart_history = {
    'smart_5_raw': deque(maxlen=SMART_HISTORY_WINDOW),
    'smart_187_raw': deque(maxlen=SMART_HISTORY_WINDOW),
    'smart_197_raw': deque(maxlen=SMART_HISTORY_WINDOW),
    'smart_198_raw': deque(maxlen=SMART_HISTORY_WINDOW),
}


def _normalize_feature_name(name):
    return ''.join(ch for ch in str(name).lower() if ch.isalnum())


ALIAS_TO_CANONICAL = {}
for canonical, aliases in FEATURE_ALIASES.items():
    for alias in aliases:
        ALIAS_TO_CANONICAL[_normalize_feature_name(alias)] = canonical


def _resolve_model_feature_order(model):
    if _features_from_file:
        return list(_features_from_file)

    if hasattr(model, 'feature_names_in_') and getattr(model, 'feature_names_in_', None) is not None:
        return [str(name) for name in list(model.feature_names_in_)]

    if hasattr(model, 'get_booster'):
        try:
            names = model.get_booster().feature_names
            if names:
                return [str(name) for name in names]
        except Exception:
            pass

    return list(FEATURE_ORDER)


def _load_feature_order_from_file():
    global _features_from_file, _features_file_load_error

    if _features_from_file:
        return list(_features_from_file)

    if not FEATURES_PATH.exists():
        _features_file_load_error = f'Features file not found: {FEATURES_PATH.resolve()}'
        return []

    try:
        with open(FEATURES_PATH, 'r', encoding='utf-8') as handle:
            payload = json.load(handle)

        feature_candidates = payload
        if isinstance(payload, dict):
            for key in ('features', 'feature_names', 'columns', 'input_features'):
                if key in payload:
                    feature_candidates = payload[key]
                    break

        if not isinstance(feature_candidates, list):
            raise ValueError('Expected a list of feature names or a dict containing one')

        parsed = [str(item).strip() for item in feature_candidates if str(item).strip()]
        if not parsed:
            raise ValueError('features.json has no valid feature names')

        _features_from_file = parsed
        _features_file_load_error = None
        return list(_features_from_file)
    except Exception as exc:
        _features_file_load_error = str(exc)
        return []


def _get_numeric_value(payload, keys, default_value=0.0):
    for key in keys:
        if key in payload:
            try:
                return float(payload[key])
            except Exception:
                continue
    if default_value is None:
        return None
    return float(default_value)


def _build_smart_base_values(telemetry):
    base = {}

    base['smart_5_raw'] = _get_numeric_value(
        telemetry,
        ['smart_5_raw', 'ecc_count', 'reallocated_sector_count'],
        default_value=0.0,
    )
    base['smart_187_raw'] = _get_numeric_value(
        telemetry,
        ['smart_187_raw', 'retries', 'reported_uncorrectable_errors'],
        default_value=0.0,
    )
    base['smart_197_raw'] = _get_numeric_value(
        telemetry,
        ['smart_197_raw', 'ecc_rate', 'current_pending_sector'],
        default_value=0.0,
    )
    base['smart_198_raw'] = _get_numeric_value(
        telemetry,
        ['smart_198_raw', 'latency', 'offline_uncorrectable'],
        default_value=0.0,
    )

    base['smart_197_raw'] = base['smart_197_raw'] * 1000.0
    base['smart_198_raw'] = base['smart_198_raw'] * 100.0

    return base


def _stats_from_history(history_values):
    if not history_values:
        return 0.0, 0.0, 0.0, 0.0, 0.0

    current = float(history_values[-1])
    mean_value = float(np.mean(history_values))
    std_value = float(np.std(history_values))

    if len(history_values) < 2:
        diff_value = 0.0
    else:
        diff_value = float(history_values[-1] - history_values[-2])

    if len(history_values) < 3:
        acc_value = 0.0
    else:
        acc_value = float(history_values[-1] - (2 * history_values[-2]) + history_values[-3])

    return current, mean_value, diff_value, acc_value, std_value


def _build_derived_feature_payload(telemetry):
    derived = dict(telemetry)

    base_values = _build_smart_base_values(telemetry)
    for feature_name, feature_value in base_values.items():
        _smart_history[feature_name].append(float(feature_value))

    for feature_name in SMART_BASE_KEYS:
        history_values = list(_smart_history[feature_name])
        current, mean_value, diff_value, acc_value, std_value = _stats_from_history(history_values)

        derived[feature_name] = current
        derived[f'{feature_name}_roll_mean'] = mean_value
        derived[f'{feature_name}_diff'] = diff_value
        derived[f'{feature_name}_acc'] = acc_value
        derived[f'{feature_name}_roll_std'] = std_value

    return derived


def _value_for_model_feature(feature_name, telemetry):
    if feature_name in telemetry:
        return float(telemetry[feature_name]), None, feature_name

    normalized = _normalize_feature_name(feature_name)
    canonical = ALIAS_TO_CANONICAL.get(normalized)
    if canonical and canonical in telemetry:
        return float(telemetry[canonical]), None, canonical

    for telemetry_key in telemetry:
        if _normalize_feature_name(telemetry_key) == normalized:
            return float(telemetry[telemetry_key]), None, telemetry_key

    return 0.0, feature_name, None


def _load_model():
    global _model, _model_load_error, _shap_explainer, _model_feature_order

    if _model is not None:
        return _model

    _load_feature_order_from_file()

    if not XGBOOST_MODEL_PATH.exists():
        _model_load_error = f'Model file not found: {XGBOOST_MODEL_PATH.resolve()}'
        return None

    loaders = []
    if joblib is not None:
        loaders.append(('joblib', joblib.load))
    loaders.append(('pickle', lambda p: pickle.load(open(p, 'rb'))))

    errors = []
    for name, loader in loaders:
        try:
            _model = loader(XGBOOST_MODEL_PATH)
            _model_load_error = None
            break
        except Exception as exc:
            errors.append(f'{name}: {exc}')

    if _model is None:
        _model_load_error = '; '.join(errors)
        return None

    if shap is not None:
        try:
            _shap_explainer = shap.TreeExplainer(_model)
        except Exception:
            _shap_explainer = None

    _model_feature_order = _resolve_model_feature_order(_model)

    return _model


def _load_lstm_model():
    global _lstm_model, _lstm_model_load_error

    if _lstm_model is not None:
        return _lstm_model

    if not LSTM_MODEL_PATH.exists():
        _lstm_model_load_error = f'LSTM model file not found: {LSTM_MODEL_PATH.resolve()}'
        return None

    if keras_load_model is None:
        _lstm_model_load_error = 'TensorFlow/Keras not installed; install tensorflow to use lstm.h5'
        return None

    try:
        _lstm_model = keras_load_model(LSTM_MODEL_PATH)
        _lstm_model_load_error = None
        return _lstm_model
    except Exception as exc:
        _lstm_model_load_error = str(exc)
        return None


def _predict_remaining_life_days_lstm():
    lstm_model = _load_lstm_model()
    if lstm_model is None or not _last_model_input_vector:
        return None

    current_vector = np.array([row['value'] for row in _last_model_input_vector], dtype=float)
    _lstm_history.append(current_vector)

    try:
        input_shape = getattr(lstm_model, 'input_shape', None)
        expected_timesteps = input_shape[1] if input_shape and len(input_shape) >= 3 else LSTM_WINDOW
        expected_features = input_shape[2] if input_shape and len(input_shape) >= 3 else current_vector.shape[0]
    except Exception:
        expected_timesteps = LSTM_WINDOW
        expected_features = current_vector.shape[0]

    if expected_features is not None and int(expected_features) != int(current_vector.shape[0]):
        return None

    expected_timesteps = int(expected_timesteps) if expected_timesteps is not None else LSTM_WINDOW
    expected_timesteps = max(expected_timesteps, 1)

    sequence = list(_lstm_history)
    if len(sequence) < expected_timesteps:
        pad = [sequence[0] if sequence else current_vector] * (expected_timesteps - len(sequence))
        sequence = pad + sequence
    else:
        sequence = sequence[-expected_timesteps:]

    lstm_input = np.array([sequence], dtype=float)

    try:
        pred = float(np.ravel(lstm_model.predict(lstm_input, verbose=0))[0])
    except TypeError:
        pred = float(np.ravel(lstm_model.predict(lstm_input))[0])
    except Exception:
        return None

    if not np.isfinite(pred):
        return None

    if 0.0 <= pred <= 1.0:
        return int(round(pred * 365.0))

    return int(round(max(0.0, pred)))


def _generate_telemetry():
    return {
        'ecc_count': int(np.random.randint(20, 100)),
        'ecc_rate': float(np.random.uniform(0.05, 0.5)),
        'retries': int(np.random.randint(10, 150)),
        'temperature': int(np.random.randint(35, 55)),
        'wear_level': float(np.random.uniform(5, 50)),
        'latency': float(np.random.uniform(0.5, 3.0)),
        'timestamp': datetime.utcnow().isoformat() + 'Z',
    }


def _is_ingested_telemetry_fresh():
    if _latest_telemetry_source != 'simulink' or _latest_ingest_epoch is None:
        return False
    return (time.time() - _latest_ingest_epoch) <= INGEST_TTL_SECONDS


def _normalize_telemetry_payload(payload):
    normalized = {}
    for key, value in payload.items():
        if isinstance(value, (int, float, np.number)):
            normalized[key] = float(value)
        else:
            normalized[key] = value

    for base_key in FEATURE_ORDER:
        if base_key in normalized:
            continue
        fallback_value = _get_numeric_value(normalized, FEATURE_ALIASES.get(base_key, []), default_value=None)
        if fallback_value is not None:
            normalized[base_key] = float(fallback_value)

    if 'timestamp' not in normalized:
        normalized['timestamp'] = datetime.utcnow().isoformat() + 'Z'

    return normalized


def _extract_feature_vector(telemetry):
    global _unmapped_model_features, _last_feature_mapping, _last_derived_features, _last_model_input_vector

    feature_payload = _build_derived_feature_payload(telemetry)
    _last_derived_features = {
        key: float(value)
        for key, value in feature_payload.items()
        if isinstance(value, (int, float, np.number))
    }

    values = []
    unmapped = []
    mapping_rows = []
    input_vector_rows = []
    for feature_name in _model_feature_order:
        value, missing_feature, source_key = _value_for_model_feature(feature_name, feature_payload)
        values.append(value)
        if missing_feature:
            unmapped.append(missing_feature)
        mapping_rows.append({
            'model_feature': feature_name,
            'telemetry_source': source_key,
            'defaulted': source_key is None,
            'value': float(value),
        })
        input_vector_rows.append({
            'feature': feature_name,
            'value': float(value),
        })

    _unmapped_model_features = unmapped
    _last_feature_mapping = mapping_rows
    _last_model_input_vector = input_vector_rows
    return np.array([values], dtype=float)


def _predict_from_telemetry(telemetry):
    model = _load_model()
    if model is None:
        return dict(_latest_prediction)

    X = _extract_feature_vector(telemetry)

    probability = None
    if hasattr(model, 'predict_proba'):
        try:
            proba = model.predict_proba(X)
            if proba.ndim == 2 and proba.shape[1] > 1:
                probability = float(proba[0, 1])
            else:
                probability = float(proba[0])
        except Exception:
            probability = None

    raw_prediction = float(model.predict(X)[0])

    if probability is None:
        if 0 <= raw_prediction <= 1:
            probability = raw_prediction
        elif raw_prediction > 1:
            probability = min(raw_prediction / 100.0, 1.0)
        else:
            probability = 1.0 / (1.0 + np.exp(-raw_prediction))

    probability = float(np.clip(probability, 0.0, 1.0))
    health_score = int(round((1.0 - probability) * 100))
    remaining_life_days = _predict_remaining_life_days_lstm()
    if remaining_life_days is None:
        remaining_life_days = int(round(max(0, health_score * 6.0)))

    return {
        'health_score': health_score,
        'failure_probability': probability,
        'remaining_life_days': remaining_life_days,
    }


def _shap_from_telemetry(telemetry):
    model = _load_model()
    if model is None or _shap_explainer is None:
        fallback = [
            {'feature': 'ECC rate', 'impact': 0.35},
            {'feature': 'Temperature', 'impact': 0.25},
            {'feature': 'Retry count', 'impact': 0.2},
            {'feature': 'Wear level', 'impact': 0.15},
            {'feature': 'Read latency', 'impact': 0.05},
        ]
        return fallback

    X = _extract_feature_vector(telemetry)
    shap_values = _shap_explainer.shap_values(X)

    if isinstance(shap_values, list):
        values = np.array(shap_values[-1][0], dtype=float)
    else:
        values = np.array(shap_values[0], dtype=float)

    impacts = np.abs(values)
    total = float(np.sum(impacts))
    features_count = len(_model_feature_order)

    if total <= 0:
        impacts = np.ones(features_count, dtype=float) / max(features_count, 1)
    else:
        impacts = impacts / total

    rows = []
    limit = min(features_count, len(impacts))
    for index in range(limit):
        feature_name = _model_feature_order[index]
        rows.append({
            'feature': FEATURE_LABELS.get(feature_name, feature_name),
            'impact': float(impacts[index]),
        })

    rows.sort(key=lambda item: item['impact'], reverse=True)
    return rows


# ============================================================================
# TELEMETRY ENDPOINT - Real-time SSD sensor data
# ============================================================================

@app.route('/api/telemetry', methods=['GET'])
def get_telemetry():
    global _latest_telemetry, _latest_telemetry_source

    if _latest_telemetry is not None and _is_ingested_telemetry_fresh():
        return jsonify(_latest_telemetry)

    telemetry = _generate_telemetry()
    _latest_telemetry = telemetry
    _latest_telemetry_source = 'simulation'
    return jsonify(telemetry)


@app.route('/api/ingest-telemetry', methods=['POST'])
def ingest_telemetry():
    global _latest_telemetry, _latest_telemetry_source, _latest_ingest_epoch

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({'error': 'Expected JSON object payload'}), 400

    normalized = _normalize_telemetry_payload(payload)
    _latest_telemetry = normalized
    _latest_telemetry_source = 'simulink'
    _latest_ingest_epoch = time.time()

    return jsonify({
        'status': 'ok',
        'source': _latest_telemetry_source,
        'timestamp': normalized.get('timestamp'),
        'received_fields': sorted(list(normalized.keys())),
    }), 200


# ============================================================================
# PREDICTION ENDPOINT - ML model outputs
# ============================================================================

@app.route('/api/prediction', methods=['GET'])
def get_prediction():
    global _latest_telemetry, _latest_prediction

    telemetry = _latest_telemetry or _generate_telemetry()
    _latest_telemetry = telemetry

    prediction = _predict_from_telemetry(telemetry)
    _latest_prediction = prediction

    return jsonify(prediction)


# ============================================================================
# SHAP ENDPOINT - Feature explainability
# ============================================================================

@app.route('/api/shap', methods=['GET'])
def get_shap():
    global _latest_telemetry
    telemetry = _latest_telemetry or _generate_telemetry()
    _latest_telemetry = telemetry
    shap_data = _shap_from_telemetry(telemetry)
    return jsonify(shap_data)


# ============================================================================
# ALERTS ENDPOINT - Alert generation
# ============================================================================

@app.route('/api/alerts', methods=['GET'])
def get_alerts():
    health_score = int(_latest_prediction.get('health_score', 72))

    if health_score >= 80:
        level = 'INFO'
        message = 'SSD operating within normal parameters'
        recommendation = 'Continue normal operations'
    elif health_score >= 60:
        level = 'WARNING'
        message = 'ECC error rate elevated - monitor closely'
        recommendation = 'Back up critical data within 30 days'
    elif health_score >= 40:
        level = 'CRITICAL'
        message = 'Drive degradation detected - plan replacement'
        recommendation = 'Schedule drive replacement within 7 days'
    else:
        level = 'FATAL'
        message = 'Imminent drive failure detected'
        recommendation = 'Replace drive immediately to prevent data loss'

    alert = {
        'level': level,
        'message': message,
        'recommendation': recommendation,
    }

    return jsonify(alert)


# ============================================================================
# HEALTH CHECK ENDPOINT
# ============================================================================

@app.route('/api/health', methods=['GET'])
def health_check():
    model = _load_model()
    telemetry = _latest_telemetry or _generate_telemetry()
    _extract_feature_vector(telemetry)

    telemetry_age_ms = None
    if _latest_ingest_epoch is not None:
        telemetry_age_ms = int((time.time() - _latest_ingest_epoch) * 1000)

    return jsonify({
        'status': 'ok',
        'timestamp': datetime.utcnow().isoformat(),
        'model_loaded': model is not None,
        'xgboost_model_loaded': model is not None,
        'xgboost_model_path': str(XGBOOST_MODEL_PATH),
        'lstm_model_loaded': _load_lstm_model() is not None,
        'lstm_model_path': str(LSTM_MODEL_PATH),
        'features_path': str(FEATURES_PATH),
        'features_loaded': bool(_features_from_file),
        'features_count': len(_model_feature_order),
        'telemetry_source': _latest_telemetry_source,
        'telemetry_age_ms': telemetry_age_ms,
        'ingest_ttl_seconds': INGEST_TTL_SECONDS,
        'model_features': _model_feature_order,
        'unmapped_features': _unmapped_model_features,
        'feature_mapping': _last_feature_mapping,
        'xgboost_model_error': _model_load_error,
        'lstm_model_error': _lstm_model_load_error,
        'features_file_error': _features_file_load_error,
        'shap_available': _shap_explainer is not None,
    }), 200


@app.route('/api/feature-mapping', methods=['GET'])
def feature_mapping():
    model = _load_model()
    telemetry = _latest_telemetry or _generate_telemetry()
    _extract_feature_vector(telemetry)

    return jsonify({
        'model_loaded': model is not None,
        'model_path': str(XGBOOST_MODEL_PATH),
        'mapping_count': len(_last_feature_mapping),
        'unmapped_count': len(_unmapped_model_features),
        'unmapped_features': _unmapped_model_features,
        'feature_mapping': _last_feature_mapping,
    }), 200


@app.route('/api/feature-vector', methods=['GET'])
def feature_vector():
    model = _load_model()
    telemetry = _latest_telemetry or _generate_telemetry()
    _extract_feature_vector(telemetry)

    return jsonify({
        'model_loaded': model is not None,
        'model_path': str(XGBOOST_MODEL_PATH),
        'feature_count': len(_last_model_input_vector),
        'unmapped_count': len(_unmapped_model_features),
        'unmapped_features': _unmapped_model_features,
        'telemetry': telemetry,
        'derived_features': _last_derived_features,
        'model_input_vector': _last_model_input_vector,
    }), 200


# ============================================================================
# ROOT ENDPOINT
# ============================================================================

@app.route('/', methods=['GET'])
def root():
    return jsonify({
        'name': 'NAND Guardian Backend',
        'version': '0.2.0',
        'xgboost_model_path': str(XGBOOST_MODEL_PATH),
        'lstm_model_path': str(LSTM_MODEL_PATH),
        'features_path': str(FEATURES_PATH),
        'endpoints': [
            '/api/telemetry - Real-time SSD telemetry data',
            '/api/ingest-telemetry - Receive telemetry from Simulink',
            '/api/prediction - ML model predictions',
            '/api/shap - SHAP explainability',
            '/api/alerts - Alert system',
            '/api/health - Health check',
            '/api/feature-mapping - Model feature alignment',
            '/api/feature-vector - Current derived model input',
        ],
    })


# ============================================================================
# ERROR HANDLING
# ============================================================================

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404


@app.errorhandler(500)
def server_error(error):
    return jsonify({'error': 'Internal server error'}), 500


# ============================================================================
# MAIN
# ============================================================================

if __name__ == '__main__':
    _load_model()

    print('🔷 NAND Guardian Backend Server')
    print('================================')
    print('')
    print('Starting server on http://localhost:8000')
    print(f'XGBOOST_MODEL_PATH: {XGBOOST_MODEL_PATH.resolve()}')
    print(f'LSTM_MODEL_PATH: {LSTM_MODEL_PATH.resolve()}')
    print(f'FEATURES_PATH: {FEATURES_PATH.resolve()}')
    if _model_load_error:
        print(f'XGBoost load status: fallback mode ({_model_load_error})')
    else:
        print('XGBoost load status: loaded successfully')
    _load_lstm_model()
    if _lstm_model_load_error:
        print(f'LSTM load status: optional fallback ({_lstm_model_load_error})')
    else:
        print('LSTM load status: loaded successfully')
    if _features_file_load_error:
        print(f'Features file status: fallback to detected model features ({_features_file_load_error})')
    else:
        print(f'Features file status: loaded {len(_model_feature_order)} features')
    print('')
    print('Available endpoints:')
    print('  GET /api/telemetry  - Real-time SSD telemetry')
    print('  POST /api/ingest-telemetry - Receive telemetry from Simulink')
    print('  GET /api/prediction - ML model predictions')
    print('  GET /api/shap       - Feature importance')
    print('  GET /api/alerts     - Alert system')
    print('  GET /api/feature-mapping - Model feature alignment')
    print('  GET /api/feature-vector  - Current derived model input')
    print('  GET /api/health     - Health check')
    print('')
    print('Frontend: http://localhost:5173')
    print('')

    startup_telemetry = _generate_telemetry()
    _extract_feature_vector(startup_telemetry)
    print('Feature mapping audit (model_feature -> telemetry_source):')
    for row in _last_feature_mapping:
        source = row['telemetry_source'] if row['telemetry_source'] is not None else 'DEFAULT(0.0)'
        print(f"  {row['model_feature']} -> {source}")
    if _unmapped_model_features:
        print(f'Unmapped model features: {_unmapped_model_features}')
    print('')

    app.run(debug=True, port=8000, host='0.0.0.0')
