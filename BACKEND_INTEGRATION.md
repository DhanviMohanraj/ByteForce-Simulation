# Backend Integration Guide for NAND Guardian

This document is for **ML engineers** and **backend developers** integrating their models into NAND Guardian.

---

## Quick Integration Checklist

- [ ] Implement `/api/telemetry` endpoint
- [ ] Implement `/api/prediction` endpoint
- [ ] Implement `/api/shap` endpoint
- [ ] Implement `/api/alerts` endpoint
- [ ] Enable CORS for frontend origin
- [ ] Test with the frontend
- [ ] Document response formats
- [ ] Set up error handling

---

## Expected Endpoints

Your backend must expose these endpoints to the frontend. All responses should be JSON with the formats specified below.

### 1. Real-Time Telemetry

**Endpoint:** `GET /api/telemetry`

**Purpose:** Stream real-time SSD sensor data to the frontend

**Response Format:**
```json
{
  "ecc_count": 42,
  "ecc_rate": 0.15,
  "retries": 87,
  "temperature": 48,
  "wear_level": 23.5,
  "latency": 1.2,
  "timestamp": "2026-03-24T10:30:45.123Z"
}
```

**Field Specifications:**
| Field | Type | Unit | Range | Description |
|-------|------|------|-------|-------------|
| `ecc_count` | integer | count | 0+ | Accumulated ECC errors detected |
| `ecc_rate` | number | ‰ or % | 0-1 | ECC error rate (normalized) |
| `retries` | integer | count | 0+ | Number of I/O retries |
| `temperature` | integer | °C | 0-100 | Drive temperature |
| `wear_level` | number | % | 0-100 | Drive wear percentage |
| `latency` | number | ms | 0+ | Average read latency |
| `timestamp` | string | ISO8601 | - | UTC timestamp of measurement |

**Polling Policy:** Frontend polls every **2 seconds**

**Error Handling:** Return 500 on failure; frontend falls back to mock data

---

### 2. ML Predictions

**Endpoint:** `GET /api/prediction`

**Purpose:** Provide ML model's health assessment and failure prediction

**Response Format:**
```json
{
  "health_score": 72,
  "failure_probability": 0.15,
  "remaining_life_days": 320
}
```

**Field Specifications:**
| Field | Type | Unit | Range | Description |
|-------|------|-----|-------|-------------|
| `health_score` | integer | score | 0-100 | SSD health (100=healthy, 0=failed) |
| `failure_probability` | number | probability | 0-1 | Model's confidence of imminent failure |
| `remaining_life_days` | integer | days | 0+ | Predicted remaining operational life |

**Model Integration:**
- Use your **XGBoost model** for health_score
- Use your **LSTM model** for remaining_life_days
- Calculate failure_probability from both models

**Health Score Thresholds:**
```
80-100: GREEN (INFO) - Healthy
60-79:  YELLOW (WARNING) - Monitor
40-59:  ORANGE (WARNING) - Plan replacement soon
0-39:   RED (CRITICAL/FATAL) - Replace immediately
```

**Polling Policy:** Frontend polls every **5 seconds**

---

### 3. SHAP Feature Importance

**Endpoint:** `GET /api/shap`

**Purpose:** Explain which features drive the health prediction

**Response Format:**
```json
[
  { "feature": "ECC acceleration", "impact": 0.40 },
  { "feature": "Temperature", "impact": 0.25 },
  { "feature": "Retry count", "impact": 0.20 },
  { "feature": "Wear level", "impact": 0.10 },
  { "feature": "Read latency", "impact": 0.05 }
]
```

**Field Specifications:**
| Field | Type | Description |
|-------|------|-------------|
| `feature` | string | Name of the input feature (human-readable) |
| `impact` | number | SHAP value normalized to 0-1 (sum ≈ 1.0) |

**Implementation Guide:**
1. Calculate SHAP values for the latest telemetry
2. Normalize impacts to sum to 1.0
3. Sort by impact (descending)
4. Top 5-8 features should be enough
5. Use consistent feature names

**Example Features:**
- ECC acceleration (rate of ECC error increase)
- Temperature (raw or trend)
- Retry count (raw or rate)
- Wear level (raw or trend)
- Read latency (raw or trend)
- P/E cycles (if available)
- Thermal cycles (if available)

**Polling Policy:** Frontend polls every **5 seconds**

---

### 4. Alert System

**Endpoint:** `GET /api/alerts`

**Purpose:** Provide actionable alerts to the user

**Response Format:**
```json
{
  "level": "WARNING",
  "message": "ECC error rate elevated - monitor closely",
  "recommendation": "Back up critical data within 30 days"
}
```

**Alert Levels:**
| Level | Condition | Color | Urgency |
|-------|-----------|-------|---------|
| `INFO` | health_score ≥ 80 | 🟢 Green | Low |
| `WARNING` | health_score 60-79 | 🟡 Yellow | Medium |
| `CRITICAL` | health_score 40-59 | 🔴 Red | High |
| `FATAL` | health_score < 40 | ⚫ Black | Critical |

**Recommended Message & Action Mapping:**

```javascript
const alertMapping = {
  "INFO": {
    message: "SSD operating within normal parameters",
    recommendation: "Continue normal operations"
  },
  "WARNING": {
    message: "ECC error rate elevated - monitor closely",
    recommendation: "Back up critical data within 30 days"
  },
  "CRITICAL": {
    message: "Drive degradation detected - plan replacement",
    recommendation: "Schedule drive replacement within 7 days"
  },
  "FATAL": {
    message: "Imminent drive failure detected",
    recommendation: "Replace drive immediately to prevent data loss"
  }
}
```

**Polling Policy:** Frontend polls every **5 seconds**

---

## Example Implementation (Flask)

```python
from flask import Flask, jsonify
from flask_cors import CORS
import json
from datetime import datetime
import numpy as np

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Initialize your ML models
# xgboost_model = joblib.load('xgboost_model.pkl')
# lstm_model = tf.keras.models.load_model('lstm_model.h5')

@app.route('/api/telemetry', methods=['GET'])
def get_telemetry():
    """
    Stream real-time SSD telemetry
    In production, this would read from actual sensor data
    """
    return jsonify({
        "ecc_count": 42,
        "ecc_rate": 0.15,
        "retries": 87,
        "temperature": 48,
        "wear_level": 23.5,
        "latency": 1.2,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    })

@app.route('/api/prediction', methods=['GET'])
def get_prediction():
    """
    ML model predictions using latest telemetry
    """
    # In production:
    # 1. Get latest telemetry
    # 2. Prepare features for XGBoost
    # 3. Run through LSTM
    # 4. Calculate failure probability
    
    return jsonify({
        "health_score": 72,
        "failure_probability": 0.15,
        "remaining_life_days": 320
    })

@app.route('/api/shap', methods=['GET'])
def get_shap():
    """
    SHAP feature importance for explainability
    """
    # In production:
    # 1. Get latest prediction
    # 2. Calculate SHAP values using explainer
    # 3. Normalize to 0-1
    # 4. Sort by impact
    
    features = [
        {"feature": "ECC acceleration", "impact": 0.40},
        {"feature": "Temperature", "impact": 0.25},
        {"feature": "Retry count", "impact": 0.20},
        {"feature": "Wear level", "impact": 0.10},
        {"feature": "Read latency", "impact": 0.05},
    ]
    return jsonify(features)

@app.route('/api/alerts', methods=['GET'])
def get_alerts():
    """
    Alert system based on health score
    """
    # Get current health score
    # health_score = get_health_score()
    
    health_score = 72  # Example
    
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
    
    return jsonify({
        "level": level,
        "message": message,
        "recommendation": recommendation
    })

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "ok"}), 200

if __name__ == '__main__':
    app.run(debug=True, port=8000)
```

---

## CORS Configuration Examples

### Flask
```python
from flask_cors import CORS

app = Flask(__name__)

# Allow all origins (development only!)
CORS(app)

# Or allow specific origin (production)
CORS(app, resources={
    r"/api/*": {
        "origins": "http://localhost:5173",
        "methods": ["GET", "POST", "OPTIONS"],
        "allow_headers": ["Content-Type"]
    }
})
```

### FastAPI
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],  # Frontend URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### Django
```python
# settings.py
INSTALLED_APPS = [
    # ...
    'corsheaders',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
]

CORS_ALLOWED_ORIGINS = [
    "http://localhost:5173",
]
```

### FastAPI (Alternative)
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Or ["http://localhost:5173"]
    allow_credentials=True,
    allow_methods=["GET", "OPTIONS"],
    allow_headers=["*"],
)
```

---

## Testing Your Integration

### 1. Test with cURL

```bash
# Test telemetry
curl http://localhost:8000/api/telemetry

# Test prediction
curl http://localhost:8000/api/prediction

# Test SHAP
curl http://localhost:8000/api/shap

# Test alerts
curl http://localhost:8000/api/alerts
```

### 2. Test with Python

```python
import requests

BASE_URL = "http://localhost:8000/api"

# Test all endpoints
endpoints = ["telemetry", "prediction", "shap", "alerts"]

for endpoint in endpoints:
    response = requests.get(f"{BASE_URL}/{endpoint}")
    print(f"{endpoint}: {response.status_code}")
    print(response.json())
```

### 3. Start Both Frontend and Backend

**Terminal 1 - Backend:**
```bash
python app.py  # Or your backend startup command
```

**Terminal 2 - Frontend:**
```bash
npm run dev
```

**Test in Browser:**
1. Visit `http://localhost:5173`
2. Toggle to "API Mode" in header
3. Verify data loads from your backend
4. Check browser DevTools → Network tab

---

## Progressive Enhancement Strategy

### Phase 1: Basic Implementation
- ✅ Implement all 4 endpoints with mock data
- ✅ Enable CORS
- ✅ Test connectivity

### Phase 2: Real ML Models
- Chain your XGBoost + LSTM models
- Connect to actual telemetry source
- Implement SHAP calculation

### Phase 3: Optimization
- Add caching for SHAP (expensive to compute)
- Batch predictions if needed
- Add request/response validation

### Phase 4: Advanced Features
- Add websocket support for real-time streaming
- Implement historical data queries
- Add data aggregation endpoints

---

## Performance Considerations

### Response Times
- **Telemetry:** < 100ms (called every 2s)
- **Prediction:** < 500ms (called every 5s)
- **SHAP:** < 1000ms (calculated once, cached often)
- **Alerts:** < 100ms (simple logic)

### Data Volume
- Telemetry: ~1KB per request
- Predictions: ~100B per request
- SHAP: ~2KB per request (max 10 features)
- Alerts: ~200B per request

### Optimization Tips
1. Cache SHAP results (recalculate every 30s instead of 5s)
2. Use model inference caching (batch if possible)
3. Consider async/await in Python
4. Profile your models for bottlenecks

---

## Error Handling

### Graceful Degradation
If your backend is down, the frontend:
1. Falls back to mock data automatically
2. Shows a notification to the user
3. Continues polling and retries connection
4. Works perfectly for UI testing

### Common Issues

**CORS Errors:**
```
Access to XMLHttpRequest blocked by CORS policy
```
→ Solution: Enable CORS on your backend (see examples above)

**Timeout Errors:**
```
Request timeout after 5000ms
```
→ Solution: Optimize your ML model inference

**Bad Gateway:**
```
503 Service Unavailable
```
→ Solution: Ensure backend is running properly

---

## Best Practices

1. **Return consistent field names** (snake_case as shown)
2. **Always include timestamps** for telemetry
3. **Validate input** (if accepting query parameters)
4. **Log all requests** for debugging
5. **Use proper HTTP status codes** (200 OK, 500 Error, etc.)
6. **Document your implementation** for handoff
7. **Test with the actual frontend** before deployment
8. **Monitor API response times** in production

---

## Deployment Checklist

Before going to production:

- [ ] Backend running on cloud/server (not localhost)
- [ ] CORS configured for production frontend URL
- [ ] SSL/HTTPS enabled
- [ ] API endpoints respond with actual data
- [ ] Error handling implemented
- [ ] Logging enabled
- [ ] Rate limiting configured (optional)
- [ ] Health check endpoint working
- [ ] Frontend tested with backend API
- [ ] API documentation updated

---

## Support

For frontend-specific issues:
- Review the [main README](./README.md)
- Check component implementations in `src/components/`
- Examine the API layer in `src/services/api.js`

For ML model questions:
- Review the expected response formats above
- Test endpoints individually with cURL
- Check mock data generation in `src/services/mockData.js`

---

**Built with ❤️ to make ML model integration seamless**
