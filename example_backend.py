"""
NAND Guardian - Example Backend Implementation
==============================================

This is a minimal example Flask backend that implements all required
NAND Guardian endpoints. Use this as a starting point for your ML backend.

To run:
    pip install flask flask-cors
    python example_backend.py

Will serve at http://localhost:8000

Requirements:
    - Flask (Python web framework)
    - flask-cors (Cross-Origin Resource Sharing)
    - numpy (for random data generation in this example)

In production, replace mock data generation with:
    - Real telemetry from SSD sensors
    - XGBoost model inference
    - LSTM model inference
    - SHAP value calculation
"""

from flask import Flask, jsonify
from flask_cors import CORS
from datetime import datetime
import numpy as np

app = Flask(__name__)

# Enable CORS for frontend (adjust origins for production)
CORS(app, resources={
    r"/api/*": {
        "origins": "*",  # Change to ["http://localhost:5173"] for production
        "methods": ["GET", "POST", "OPTIONS"],
        "allow_headers": ["Content-Type"]
    }
})


# ============================================================================
# TELEMETRY ENDPOINT - Real-time SSD sensor data
# ============================================================================

@app.route('/api/telemetry', methods=['GET'])
def get_telemetry():
    """
    Stream real-time SSD telemetry data
    
    In production, this would:
    1. Read actual HDD/SSD sensor data
    2. Parse UART logs
    3. Query SMBus registers
    4. Return current metrics
    """
    
    # TODO: Replace with real sensor data
    telemetry = {
        "ecc_count": int(np.random.randint(20, 100)),
        "ecc_rate": float(np.random.uniform(0.05, 0.5)),
        "retries": int(np.random.randint(10, 150)),
        "temperature": int(np.random.randint(35, 55)),
        "wear_level": float(np.random.uniform(5, 50)),
        "latency": float(np.random.uniform(0.5, 3.0)),
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    
    return jsonify(telemetry)


# ============================================================================
# PREDICTION ENDPOINT - ML model outputs
# ============================================================================

@app.route('/api/prediction', methods=['GET'])
def get_prediction():
    """
    Get ML model predictions for SSD health
    
    In production, this would:
    1. Fetch latest telemetry
    2. Preprocess features for ML models
    3. Run XGBoost for health_score
    4. Run LSTM for remaining_life_days
    5. Calculate failure_probability
    
    Example implementation (pseudo-code):
    
        # Get latest telemetry
        telemetry = get_latest_telemetry()
        
        # Prepare features
        X = prepare_features(telemetry)
        
        # XGBoost for health score
        health_score = int(xgboost_model.predict(X)[0] * 100)
        
        # LSTM for RUL
        remaining_life_days = int(lstm_model.predict(X)[0])
        
        # Calculate failure probability
        failure_prob = 1.0 / (1.0 + np.exp(-health_score))
    """
    
    # TODO: Replace with real ML model inference
    # Current: Mock data
    health_score = int(np.random.randint(30, 95))
    
    prediction = {
        "health_score": health_score,
        "failure_probability": float(np.random.uniform(0.05, 0.5)),
        "remaining_life_days": int(np.random.randint(50, 1000))
    }
    
    return jsonify(prediction)


# ============================================================================
# SHAP ENDPOINT - Feature explainability
# ============================================================================

@app.route('/api/shap', methods=['GET'])
def get_shap():
    """
    Calculate SHAP feature importance for explainability
    
    In production, this would:
    1. Calculate SHAP values for the latest prediction
    2. Use SHAP library (pip install shap)
    3. Normalize impacts to sum to 1.0
    
    Example implementation:
    
        import shap
        
        # Get latest telemetry and prepare features
        X = prepare_features(get_latest_telemetry())
        
        # Create SHAP explainer
        explainer = shap.TreeExplainer(xgboost_model)
        
        # Calculate SHAP values
        shap_values = explainer.shap_values(X)
        
        # Extract feature impacts (absolute values, normalized)
        impacts = np.abs(shap_values[0])
        impacts = impacts / np.sum(impacts)
        
        # Map to feature names
        features = ['ecc_acceleration', 'temperature', 'retry_count', ...]
        return [{"feature": f, "impact": float(i)} for f, i in zip(features, impacts)]
    """
    
    # TODO: Replace with real SHAP calculation
    # Current: Mock data (normalized to sum ~1.0)
    shap_data = [
        {"feature": "ECC acceleration", "impact": float(np.random.uniform(0.25, 0.45))},
        {"feature": "Temperature", "impact": float(np.random.uniform(0.15, 0.35))},
        {"feature": "Retry count", "impact": float(np.random.uniform(0.10, 0.25))},
        {"feature": "Wear level", "impact": float(np.random.uniform(0.05, 0.15))},
        {"feature": "Read latency", "impact": float(np.random.uniform(0.02, 0.10))},
    ]
    
    # Normalize to sum to 1.0 (optional but recommended)
    total = sum(item["impact"] for item in shap_data)
    for item in shap_data:
        item["impact"] = item["impact"] / total
    
    # Sort by impact descending
    shap_data.sort(key=lambda x: x["impact"], reverse=True)
    
    return jsonify(shap_data)


# ============================================================================
# ALERTS ENDPOINT - Alert generation
# ============================================================================

@app.route('/api/alerts', methods=['GET'])
def get_alerts():
    """
    Generate alerts based on drive health
    
    In production:
    1. Get current health score (from prediction endpoint)
    2. Generate alert level and message
    3. Provide actionable recommendation
    
    Alert level mapping:
    - INFO:     health_score >= 80  (Green)
    - WARNING:  60 <= health_score < 80  (Yellow)
    - CRITICAL: 40 <= health_score < 60  (Red)
    - FATAL:    health_score < 40   (Black)
    """
    
    # TODO: Get real health_score from prediction
    health_score = int(np.random.randint(30, 95))
    
    # Determine alert level and messages
    if health_score >= 80:
        level = "INFO"
        message = "SSD operating within normal parameters"
        recommendation = "Continue normal operations"
    elif health_score >= 60:
        level = "WARNING"
        message = "ECC error rate elevated - monitor closely"
        recommendation = "Back up critical data within 30 days"
    elif health_score >= 40:
        level = "CRITICAL"
        message = "Drive degradation detected - plan replacement"
        recommendation = "Schedule drive replacement within 7 days"
    else:
        level = "FATAL"
        message = "Imminent drive failure detected"
        recommendation = "Replace drive immediately to prevent data loss"
    
    alert = {
        "level": level,
        "message": message,
        "recommendation": recommendation
    }
    
    return jsonify(alert)


# ============================================================================
# HEALTH CHECK ENDPOINT
# ============================================================================

@app.route('/api/health', methods=['GET'])
def health_check():
    """
    Health check endpoint for monitoring backend availability
    """
    return jsonify({"status": "ok", "timestamp": datetime.utcnow().isoformat()}), 200


# ============================================================================
# ROOT ENDPOINT
# ============================================================================

@app.route('/', methods=['GET'])
def root():
    """Root endpoint"""
    return jsonify({
        "name": "NAND Guardian Backend",
        "version": "0.1.0",
        "endpoints": [
            "/api/telemetry - Real-time SSD telemetry data",
            "/api/prediction - ML model predictions",
            "/api/shap - SHAP explainability",
            "/api/alerts - Alert system",
            "/api/health - Health check"
        ]
    })


# ============================================================================
# ERROR HANDLING
# ============================================================================

@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found"}), 404


@app.errorhandler(500)
def server_error(error):
    return jsonify({"error": "Internal server error"}), 500


# ============================================================================
# MAIN
# ============================================================================

if __name__ == '__main__':
    print("🔷 NAND Guardian Backend Server")
    print("================================")
    print("")
    print("Starting server on http://localhost:8000")
    print("")
    print("Available endpoints:")
    print("  GET /api/telemetry  - Real-time SSD telemetry")
    print("  GET /api/prediction - ML model predictions")
    print("  GET /api/shap       - Feature importance")
    print("  GET /api/alerts     - Alert system")
    print("  GET /api/health     - Health check")
    print("")
    print("Frontend: http://localhost:5173")
    print("")
    
    # Run with debug=True for development (disable in production!)
    app.run(debug=True, port=8000, host='0.0.0.0')
