# 🔷 NAND Guardian - Frontend

A **production-ready React frontend** for AI-powered SSD health monitoring, featuring real-time telemetry visualization, ML predictions, and SHAP explainability.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Integration](#api-integration)
- [Features](#features)
- [Architecture](#architecture)
- [Development](#development)
- [Production Build](#production-build)

---

## 🎯 Overview

NAND Guardian is a **dashboard for monitoring SSD health metrics** using machine learning models (XGBoost + LSTM). It provides:

- **Real-time telemetry visualization** (ECC errors, temperature, wear level, etc.)
- **ML-based health scoring** (0-100 scale)
- **Remaining Useful Life (RUL) prediction** (in days)
- **SHAP explainability** (why is the drive failing?)
- **Alert system** (INFO, WARNING, CRITICAL, FATAL)
- **Out-of-Band interfaces** (UART logs, BLE status, SMBus)

The frontend is **designed to seamlessly plug into backend ML APIs** without requiring UI changes.

---

## 🛠 Tech Stack

| Layer | Technology |
|-------|------------|
| **Framework** | React 18.2 + Vite 5.0 |
| **Styling** | Tailwind CSS 3.3 |
| **Charts** | Recharts 2.10 |
| **State Management** | Zustand 4.4 |
| **HTTP Client** | Axios 1.6 |
| **Node** | 18+ |

---

## 📁 Project Structure

```
nand-guardian/
├── src/
│   ├── components/
│   │   ├── Common.jsx              # Reusable UI components
│   │   ├── DashboardOverview.jsx   # Health score + alerts
│   │   ├── TelemetryChart.jsx      # Real-time data charts
│   │   ├── SHAPChart.jsx           # Feature importance
│   │   └── OOBPanel.jsx            # UART, BLE, SMBus
│   ├── services/
│   │   ├── api.js                  # 🔑 API layer (mock ↔ real)
│   │   └── mockData.js             # Mock data generation
│   ├── store/
│   │   └── appStore.js             # Zustand state management
│   ├── utils/
│   │   └── formatting.js           # Helper functions
│   ├── App.jsx                     # Main app component
│   ├── main.jsx                    # Entry point
│   └── index.css                   # Tailwind imports + custom styles
├── index.html                      # HTML template
├── vite.config.js                  # Vite configuration
├── tailwind.config.js              # Tailwind theming
├── postcss.config.js               # PostCSS plugins
├── package.json                    # Dependencies
└── README.md                       # This file
```

---

## 🚀 Installation

### Prerequisites

- **Node.js** 18+ ([Download](https://nodejs.org/))
- **npm** 9+ or **yarn** 4+

### Step 1: Clone and Navigate

```bash
cd nand-guardian
```

### Step 2: Install Dependencies

```bash
npm install
```

This will install:
- React & React DOM
- Vite (dev server)
- Tailwind CSS (styling)
- Recharts (charting)
- Zustand (state management)
- Axios (HTTP client)

---

## 🎬 Quick Start

### Development Mode (with Mock Data)

```bash
npm run dev
```

This starts the **Vite dev server** at `http://localhost:5173`

**Features:**
- ✅ Hot Module Replacement (HMR) - changes auto-reload
- ✅ Mock data streams automatically every 2-3 seconds
- ✅ No backend needed to develop the UI
- ✅ Toggle between Mock/API mode in the header

### Production Build

```bash
npm run build
```

Outputs optimized bundle to `dist/`

### Preview Production Build

```bash
npm run preview
```

Serves the production build locally for testing

---

## 🔌 API Integration

### 🎯 Key Design Pattern

The frontend is built around **easy API integration**:

1. **Mock data mode** - Use simulated data during development
2. **API mode** - Switch to real backend endpoints in production
3. **Zero UI changes** - Same component code works with both

### API Layer

**File:** `src/services/api.js`

All API calls go through this centralized service. It automatically:
- Switches between mock and real data
- Handles errors and fallbacks to mock data
- Provides consistent response formats

### Backend Endpoints Expected

Your backend ML API should implement these endpoints:

#### 1. **GET `/api/telemetry`**

Real-time SSD sensor data (called every 2 seconds)

**Response:**
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

#### 2. **GET `/api/prediction`**

ML model predictions (called every 5 seconds)

**Response:**
```json
{
  "health_score": 72,
  "failure_probability": 0.15,
  "remaining_life_days": 320
}
```

#### 3. **GET `/api/shap`**

SHAP feature importance (called every 5 seconds)

**Response:**
```json
[
  { "feature": "ECC acceleration", "impact": 0.40 },
  { "feature": "Temperature", "impact": 0.25 },
  { "feature": "Retry count", "impact": 0.20 },
  { "feature": "Wear level", "impact": 0.10 },
  { "feature": "Read latency", "impact": 0.05 }
]
```

#### 4. **GET `/api/alerts`**

Current system alerts

**Response:**
```json
{
  "level": "WARNING",
  "message": "ECC error rate elevated - monitor closely",
  "recommendation": "Back up critical data within 30 days"
}
```

### Backend Setup Example (Flask)

```python
from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route('/api/telemetry', methods=['GET'])
def get_telemetry():
    return jsonify({
        "ecc_count": 42,
        "ecc_rate": 0.15,
        "retries": 87,
        "temperature": 48,
        "wear_level": 23.5,
        "latency": 1.2,
        "timestamp": "2026-03-24T10:30:45.123Z"
    })

@app.route('/api/prediction', methods=['GET'])
def get_prediction():
    return jsonify({
        "health_score": 72,
        "failure_probability": 0.15,
        "remaining_life_days": 320
    })

# ... implement /api/shap and /api/alerts

if __name__ == '__main__':
    app.run(debug=True, port=8000)
```

### Switching to Backend API

1. **Start your backend** on port 8000 (or configure in `vite.config.js`)

2. **Click the mode toggle** in the header (Mock Mode → API Mode)

3. **Or programmatically:**

```javascript
// In your App component
const { setUseMockData } = useStore()

// Switch to API mode
setUseMockData(false)
```

---

## ✨ Features

### 1. Dashboard Overview
- Drive Health Score (0-100)
- Remaining Useful Life in days
- Failure Probability (%)
- Alert banner with recommendations

### 2. Real-Time Telemetry
- **ECC & Retry Metrics** - Line chart tracking ECC count and retries
- **Temperature & Wear** - Dual-axis chart for thermal monitoring
- **Latency Trend** - Bar chart for I/O latency
- **Current Metrics** - Badge display of latest values
- Updates every 2 seconds

### 3. AI Explainability
- SHAP feature importance bar chart
- Impact breakdown for each feature
- Insights about top contributing factors
- Shows what's driving the predictions

### 4. Out-of-Band Interfaces
- **UART Logs** - Console-style log display
- **BLE Broadcast** - Connection status, RSSI, UUID, Major/Minor
- **SMBus Status** - Register status, protocol info

### 5. Alert System
- 4-level alert system (INFO, WARNING, CRITICAL, FATAL)
- Color-coded alerts with icons
- Actionable recommendations
- Real-time updates

### 6. Mode Toggle
- Click header badge to switch between Mock/API mode
- Seamless data source switching
- Perfect for development and testing

---

## 🏗 Architecture

### State Management (Zustand)

```javascript
// All app state in: src/store/appStore.js
{
  // Toggle between mock and real data
  useMockData: boolean,
  
  // Telemetry data (updates ~2s)
  telemetry: { ecc_count, ecc_rate, retries, ... },
  
  // Predictions (updates ~5s)
  prediction: { health_score, failure_probability, remaining_life_days },
  
  // SHAP explanations (updates ~5s)
  shap: [{ feature, impact }, ...],
  
  // Alerts
  alerts: { level, message, recommendation },
  
  // OOB data
  uartLogs: [...],
  bleStatus: string,
  smbusStatus: string,
  
  // UI state
  isLoading: boolean,
  error: string
}
```

### Component Hierarchy

```
App
├── Header (mode toggle, live indicator)
├── DashboardOverview
│   ├── StatusCard (health score)
│   ├── StatusCard (RUL)
│   ├── StatusCard (failure prob)
│   └── AlertBanner
├── TelemetryChart
│   ├── LineChart (ECC & Retries)
│   ├── LineChart (Temp & Wear)
│   ├── BarChart (Latency)
│   └── MetricBadges
├── SHAPChart
│   ├── BarChart (feature importance)
│   └── Insights panels
└── OOBPanel
    ├── UART logs
    ├── BLE status
    └── SMBus registers
```

### Data Flow

```
┌─────────────────────────────────────────┐
│   API Service Layer (src/services/)     │
│   ├─ api.js (centralized)               │
│   └─ mockData.js (fallback)             │
└──────────────┬──────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────┐
│   Zustand Store (src/store/)            │
│   └─ appStore.js (global state)         │
└──────────────┬──────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────┐
│   React Components (src/components/)    │
│   ├─ DashboardOverview                  │
│   ├─ TelemetryChart                     │
│   ├─ SHAPChart                          │
│   ├─ OOBPanel                           │
│   └─ Common (reusables)                 │
└─────────────────────────────────────────┘
```

---

## 💻 Development Guide

### Adding a New Component

1. **Create in `src/components/`**

```javascript
// src/components/MyComponent.jsx
import React from 'react'

export const MyComponent = ({ data }) => {
  return (
    <div className="chart-container">
      <h3 className="text-lg font-semibold text-white">My Component</h3>
      {/* Content here */}
    </div>
  )
}
```

2. **Use in App.jsx**

```javascript
import { MyComponent } from './components/MyComponent'

function App() {
  // In JSX:
  <MyComponent data={someData} />
}
```

### Adding a New API Endpoint

1. **Extend `src/services/api.js`**

```javascript
export const getMyData = async (useMockData = false) => {
  if (useMockData) {
    return mockDataService.generateMyData()
  }
  
  try {
    const response = await apiClient.get('/my-endpoint')
    return response.data
  } catch (error) {
    return mockDataService.generateMyData()
  }
}
```

2. **Add to Zustand store** (`src/store/appStore.js`)

```javascript
myData: null,
setMyData: (myData) => set({ myData }),
```

3. **Fetch in App component and pass to child**

---

## 🎨 Styling Guide

### Tailwind Classes Used

```css
/* Dark theme colors */
bg-dark-900    /* #0f1419 - Main background */
bg-dark-800    /* #1a1f26 - Cards */
bg-dark-700    /* #2a2f3a - Borders */

/* Status colors */
text-green-400   /* INFO */
text-yellow-400  /* WARNING */
text-red-400     /* CRITICAL */
text-gray-300    /* FATAL */

/* Reusable classes */
.stat-card         /* Standard card */
.chart-container   /* Chart wrapper */
.glass             /* Glass morphism effect */
```

### Custom Animations

- `animate-pulse` - Pulsing indicator
- `animate-slideIn` - Slide animation
- `animate-shimmer` - Loading shimmer

### Dark Theme Colors

Edit `tailwind.config.js` to customize:

```javascript
theme: {
  extend: {
    colors: {
      dark: {
        900: "#0f1419",  // Main bg
        800: "#1a1f26",  // Cards
        700: "#2a2f3a",  // Borders
        600: "#3a3f4a",
      },
    },
  },
}
```

---

## 🔧 Troubleshooting

### Module not found errors

```bash
# Clear node_modules and reinstall
rm -rf node_modules
npm install
```

### Port 5173 already in use

```bash
# Use a different port
npm run dev -- --port 3000
```

### Axios CORS errors

Ensure your backend has CORS enabled:

```python
# Flask example
from flask_cors import CORS
CORS(app)
```

### Charts not showing

- Check that Recharts is installed: `npm list recharts`
- Verify data structure matches expected format
- Check browser console for errors

### Mock data not updating

- Click "Mock Mode" in header to toggle
- Check that polling intervals are running (see App.jsx)
- Open DevTools → Network tab to verify calls

---

## 📊 Performance Optimization

- **Code splitting** - Vite automatically handles this
- **Lazy loading** - Consider using React.lazy for future features
- **Memoization** - Use React.memo on expensive components
- **Chart optimization** - Recharts handles this automatically

### Current Performance Targets

- Initial load: < 2s
- Chart updates: 60 FPS
- API polling: 2-5s intervals

---

## 🚀 Deployment

### Build for Production

```bash
npm run build
```

Creates optimized bundle in `dist/`

### Deploy Options

**1. Static Hosting (Vercel, Netlify, AWS S3)**

```bash
# Upload dist/ folder
npm run build
```

**2. Docker**

```dockerfile
FROM node:18-alpine

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

EXPOSE 3000
CMD ["npm", "run", "preview"]
```

**3. Environment Variables**

Create `.env.production`:

```
VITE_API_URL=https://api.yourbackend.com
VITE_DEBUG=false
```

---

## 📝 API Response Contracts

### Telemetry Contract

```json
{
  "ecc_count": { "type": "integer", "description": "Total ECC errors detected" },
  "ecc_rate": { "type": "number", "description": "ECC error rate (‰ or %)" },
  "retries": { "type": "integer", "description": "Number of retries" },
  "temperature": { "type": "integer", "description": "Temperature in °C" },
  "wear_level": { "type": "number", "description": "Wear percentage (0-100)" },
  "latency": { "type": "number", "description": "Read latency in ms" },
  "timestamp": { "type": "string", "format": "ISO8601" }
}
```

### Prediction Contract

```json
{
  "health_score": { "type": "integer", "min": 0, "max": 100 },
  "failure_probability": { "type": "number", "min": 0, "max": 1 },
  "remaining_life_days": { "type": "integer", "min": 0 }
}
```

### SHAP Contract

```json
[
  {
    "feature": { "type": "string" },
    "impact": { "type": "number", "min": 0, "max": 1 }
  }
]
```

### Alerts Contract

```json
{
  "level": { "enum": ["INFO", "WARNING", "CRITICAL", "FATAL"] },
  "message": { "type": "string" },
  "recommendation": { "type": "string" }
}
```

---

## 🤝 Contributing

To extend NAND Guardian:

1. Create feature branch: `git checkout -b feature/my-feature`
2. Follow component conventions (see existing components)
3. Test with both mock and API modes
4. Update README if adding new endpoints

---

## 📝 License

MIT License - Feel free to use for any purpose

---

## 🎓 Learning Resources

- [React Documentation](https://react.dev)
- [Vite Docs](https://vitejs.dev)
- [Tailwind CSS](https://tailwindcss.com)
- [Recharts](https://recharts.org)
- [Zustand](https://github.com/pmndrs/zustand)

---

## 💬 Support

For issues or questions:
1. Check existing components for patterns
2. Review API response formats
3. Test with mock data first
4. Inspect browser DevTools console

---

**Built with ❤️ for SSD health monitoring**

Last Updated: March 24, 2026
