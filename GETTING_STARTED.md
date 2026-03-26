# 🚀 NAND Guardian - Getting Started

**The production-ready SSD health monitoring frontend - built for seamless ML integration**

---

## ⚡ 5-Minute Quick Start

### For Frontend Developers

```bash
# 1. Install dependencies
npm install

# 2. Start development server
npm run dev

# 3. Open browser
# http://localhost:5173

# 4. Done! Dashboard is running with mock data 🎉
```

### For Backend Engineers

1. **Run example backend** (or use Dockerfile example in BACKEND_INTEGRATION.md)
   ```bash
   pip install flask flask-cors numpy xgboost joblib shap tensorflow
   # Place your trained artifacts in ./model/
   #   xgboost.pkl
   #   lstm.h5
   #   features.json
   # (or set MODEL_PATH / LSTM_MODEL_PATH / FEATURES_PATH)
   # Windows PowerShell
   $env:MODEL_PATH="C:/path/to/your/xgboost.pkl"
   $env:LSTM_MODEL_PATH="C:/path/to/your/lstm.h5"
   $env:FEATURES_PATH="C:/path/to/your/features.json"
   # macOS/Linux
   # export MODEL_PATH="/path/to/your/xgboost.pkl"
   # export LSTM_MODEL_PATH="/path/to/your/lstm.h5"
   # export FEATURES_PATH="/path/to/your/features.json"
   python example_backend.py
   ```

2. **Connect frontend to backend**
   - Click "Mock Mode" → "API Mode" toggle in header
   - Data now streams from your backend!

3. **Implement your ML models** replacing the mock data generators

4. **See full guide:** [BACKEND_INTEGRATION.md](./BACKEND_INTEGRATION.md)

---

## 📚 Documentation Index

| Document | For | Content |
|----------|-----|---------|
| **README.md** | Everyone | Project overview, features, tech stack, development guide |
| **BACKEND_INTEGRATION.md** | ML/Backend Engineers | API specs, implementation examples, CORS setup, testing |
| **STRUCTURE.md** | Developers | Component breakdown, data flow, architecture decisions |
| **GETTING_STARTED.md** | New Users | This file - quick orientation |

---

## 🎯 What You Can Do Right Now

### ✅ Development Mode (Mock Data)

```bash
npm run dev
```

Visit `http://localhost:5173` and see:

- 📊 **Dashboard Overview** - Health score, RUL, failure probability
- 📈 **Real-Time Telemetry** - Live charts updating every 2 seconds
  - ECC metrics (count, rate)
  - Temperature & wear level
  - I/O latency trend
- 🔍 **AI Explainability** - SHAP feature importance
- 📋 **Out-of-Band Interfaces** - UART logs, BLE, SMBus
- 🔔 **Alert System** - Color-coded alerts with recommendations
- 🔄 **Mode Toggle** - Seamlessly switch between mock and API data

Everything works without a backend!

### 📦 Production Build

```bash
npm run build
npm run preview
```

Outputs optimized bundle to `dist/`

### 🔌 Backend Integration

```bash
# Terminal 1: Start your backend API
python example_backend.py

# Terminal 2: Start frontend (if not already running)
npm run dev

# In browser: Click "Mock Mode" toggle → "API Mode"
```

---

## 🏗 Project Structure at a Glance

```
nand-guardian/
├── src/
│   ├── components/          # React components (charts, cards, etc.)
│   ├── services/            # API layer + mock data
│   ├── store/               # Zustand state management
│   ├── utils/               # Helper functions
│   ├── App.jsx              # Main app
│   └── index.css            # Tailwind styles
├── package.json             # Dependencies
├── vite.config.js           # Dev server config
├── tailwind.config.js       # Theme customization
├── README.md                # Full documentation
├── BACKEND_INTEGRATION.md   # Backend guide
├── STRUCTURE.md             # Architecture
└── example_backend.py       # Flask backend example
```

See [STRUCTURE.md](./STRUCTURE.md) for detailed breakdown.

---

## 🎨 Key Features

### 1. **Real-Time Telemetry**
- Live charts with ECC errors, temperature, latency
- Auto-updates every 2 seconds
- 30-point history per chart
- Zoom-friendly responsive design

### 2. **ML Predictions**
- Health score (0-100) with progress bar
- Remaining Useful Life (in days)
- Failure probability (%)
- Color-coded status indicators

### 3. **AI Explainability (SHAP)**
- Bar chart of feature importance
- Top 5 contributing factors
- Impact breakdown visualization
- Helps understand why drive might fail

### 4. **Out-of-Band Monitoring**
- **UART Logs** - Console-style interface
- **BLE Broadcast** - Connection status, RSSI, UUID
- **SMBus** - Register status, protocol info

### 5. **Alert System**
- 4-level alerts: INFO → WARNING → CRITICAL → FATAL
- Color-coded (Green → Yellow → Red → Black)
- Actionable recommendations per level

### 6. **Mode Toggle**
- **Mock Mode** - Simulated data (development)
- **API Mode** - Real backend (production)
- Same UI, different data source!

---

## 🔌 API Integration Overview

### Your Backend Needs These Endpoints

```
GET /api/telemetry        → Real-time sensor data
GET /api/prediction       → ML health predictions
GET /api/shap            → Feature importance
GET /api/alerts          → Alert generation
GET /api/health          → Health check
```

**See [BACKEND_INTEGRATION.md](./BACKEND_INTEGRATION.md) for complete specs and examples.**

### Frontend Automatically:
- ✅ Polls endpoints every 2-5 seconds
- ✅ Handles errors gracefully
- ✅ Falls back to mock data on failure
- ✅ Formats data for display
- ✅ Updates charts in real-time

---

## 🛠 Common Tasks

### Customize Colors

Edit `tailwind.config.js`:

```javascript
// Change dark background color
dark: {
  900: "#0a0e12",  // Was #0f1419
  800: "#151a20",  // Was #1a1f26
  // ...
}
```

### Change Polling Intervals

Edit `src/App.jsx`:

```javascript
// Telemetry every 1 second instead of 2
const telemetryInterval = setInterval(() => {
  // ...
}, 1000)  // Changed from 2000
```

### Add New Endpoint

1. Add to `src/services/api.js`:
   ```javascript
   export const getNewData = async (useMockData = false) => {
     // ...
   }
   ```

2. Add mock generator to `src/services/mockData.js`:
   ```javascript
   export const generateMockNewData = () => {
     // Return mock data
   }
   ```

3. Add to Zustand store `src/store/appStore.js`:
   ```javascript
   newData: null,
   setNewData: (data) => set({ newData: data }),
   ```

4. Use in component:
   ```javascript
   const { newData } = useStore()
   ```

---

## 🧪 Testing Your Setup

### Test 1: Frontend Works
```bash
npm run dev
# Open http://localhost:5173
# See charts updating with mock data ✓
```

### Test 2: Backend Connected
```bash
# Terminal 1
python example_backend.py

# Terminal 2
npm run dev

# In browser, click "API Mode" toggle
# Data should load from your backend ✓
```

### Test 3: Check Data Flow
```bash
# Browser DevTools → Network tab
# Should see requests to:
# - GET /api/telemetry (every 2s)
# - GET /api/prediction (every 5s)
# - GET /api/shap (every 5s)
# - GET /api/alerts (every 5s)
```

---

## 🚨 Troubleshooting

| Issue | Solution |
|-------|----------|
| Port 5173 in use | `npm run dev -- --port 3000` |
| Module not found | `rm -rf node_modules && npm install` |
| CORS errors | Enable CORS in your backend (see BACKEND_INTEGRATION.md) |
| Charts not showing | Check browser console for errors |
| API not connecting | Verify backend running on port 8000 |
| Mock data not updating | Toggle mode switch, check console |

---

## 📊 Architecture Overview

```
┌──────────────────────────────────────────┐
│        React Components (UI Layer)       │
│  - DashboardOverview                     │
│  - TelemetryChart                        │
│  - SHAPChart                             │
│  - OOBPanel                              │
└──────────────┬───────────────────────────┘
               ↓
┌──────────────────────────────────────────┐
│    Zustand Store (State Management)      │
│  - Telemetry data                        │
│  - Predictions                           │
│  - SHAP values                           │
│  - Alerts                                │
└──────────────┬───────────────────────────┘
               ↓
┌──────────────────────────────────────────┐
│      API Service Layer (api.js)          │
│  - Switches between mock/real data       │
│  - Error handling & fallbacks            │
│  - Response formatting                   │
└──────────────┬───────────────────────────┘
               ↓
         ┌─────┴─────┐
         ↓           ↓
    ┌────────┐  ┌──────────┐
    │  Mock  │  │ Backend  │
    │  Data  │  │   API    │
    └────────┘  └──────────┘
```

---

## 🚀 Next Steps

### For Frontend Developers
1. ✅ Run `npm install` & `npm run dev`
2. Read [README.md](./README.md) for full feature guide
3. Explore components in `src/components/`
4. Customize styling in `tailwind.config.js`

### For Backend Engineers
1. ✅ Run `python example_backend.py`
2. Read [BACKEND_INTEGRATION.md](./BACKEND_INTEGRATION.md)
3. Implement the 4 required endpoints
4. Test with frontend in API Mode

### For DevOps/Deployment
1. Read Production Build section in [README.md](./README.md)
2. Deploy `dist/` folder to static hosting
3. Point API proxy to your backend
4. Monitor frontend error rates

---

## 📝 Key Technologies

- **React 18.2** - UI library
- **Vite 5.0** - Dev server & build tool (⚡ ultra-fast)
- **Tailwind CSS** - Dark theme styling
- **Recharts** - Real-time charting
- **Zustand** - Lightweight state management
- **Axios** - HTTP client

---

## 💡 Development Tips

### See Real-Time State
```javascript
// In browser console
useStore.getState()
```

### Check API Calls
```
DevTools → Network tab → Filter XHR
```

### Enable Debug Logging
```javascript
// Add to App.jsx
console.log('Data updated:', { telemetry, prediction, shap })
```

### Test Different Scenarios
1. **No backend** - Uses mock data automatically
2. **Slow backend** - See loading spinner
3. **Backend error** - Falls back to mock
4. **Mixed mode** - Some endpoints from backend, some mocked

---

## 🤝 Contributing

1. Create feature branch: `git checkout -b feature/my-feature`
2. Follow existing component patterns
3. Test with both mock and API modes
4. Update docs if needed

---

## 📞 Support

**Frontend Questions:**
- Check [README.md](./README.md) and [STRUCTURE.md](./STRUCTURE.md)
- Review existing components for patterns
- Check browser console for errors

**Backend Questions:**
- See [BACKEND_INTEGRATION.md](./BACKEND_INTEGRATION.md)
- Review `example_backend.py` for reference implementation
- Check API response formats match specs

**General Questions:**
- Review documentation files in order
- Search existing issues/code
- Check DevTools for runtime errors

---

## 📄 License

MIT - Use freely for any purpose

---

## ✨ Quick Commands Reference

```bash
# Setup
npm install                    # Install dependencies
setup.bat / setup.sh          # Auto setup script

# Development
npm run dev                    # Start dev server (port 5173)
npm run build                  # Production build
npm run preview               # Preview production build

# Example Backend
python example_backend.py     # Start Flask backend (port 8000)

# Cleanup
rm -rf node_modules dist     # Clean build
npm install                   # Reinstall everything
```

---

## 🎓 Learning Path

1. **Installation** (5 min)
   - `npm install && npm run dev`
   - Visit http://localhost:5173

2. **Explore UI** (10 min)
   - Click around dashboard
   - Watch data update
   - Check settings/mode toggles

3. **Read README.md** (15 min)
   - Understand features
   - See component breakdown
   - Learn API structure

4. **Backend Integration** (30 min)
   - Start `example_backend.py`
   - Toggle to API mode
   - Integrate your own models

5. **Customization** (varies)
   - Adjust colors/theme
   - Add new metrics
   - Extend components

---

**Built for production. Designed for extensibility. Ready for your ML models.**

🔷 Happy building! 🔷
