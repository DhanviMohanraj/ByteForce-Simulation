# NAND Guardian - Project Structure & Components

## 📁 Complete File Structure

```
nand-guardian/
├── src/
│   ├── components/
│   │   ├── Common.jsx                 # Reusable UI components (Header, StatusCard, AlertBanner, etc.)
│   │   ├── DashboardOverview.jsx      # Health score, RUL, failure probability overview
│   │   ├── TelemetryChart.jsx         # Real-time telemetry charts (ECC, temp, latency)
│   │   ├── SHAPChart.jsx              # SHAP feature importance bar chart
│   │   └── OOBPanel.jsx               # Out-of-band interfaces (UART, BLE, SMBus)
│   │
│   ├── services/
│   │   ├── api.js                     # 🔑 Centralized API layer (mock ↔ real)
│   │   └── mockData.js                # Mock data generators for development
│   │
│   ├── store/
│   │   └── appStore.js                # Zustand global state management
│   │
│   ├── utils/
│   │   └── formatting.js              # Color, formatting, and utility functions
│   │
│   ├── App.jsx                        # Main app component with data fetching
│   ├── main.jsx                       # React entry point
│   └── index.css                      # Tailwind + custom styles
│
├── index.html                         # HTML template
├── vite.config.js                     # Vite dev server & proxy config
├── tailwind.config.js                 # Tailwind theme customization
├── postcss.config.js                  # PostCSS plugin config
├── package.json                       # Dependencies and scripts
├── .env.example                       # Environment variables template
├── .gitignore                         # Git ignore rules
├── README.md                          # Main documentation
├── BACKEND_INTEGRATION.md             # Backend integration guide
└── STRUCTURE.md                       # This file

```

---

## 🧩 Component Breakdown

### Common.jsx
**Reusable components used across the dashboard:**

```javascript
export const Header              // Top navigation with mode toggle
export const StatusCard          // Metric display card with icon/trend
export const AlertBanner         // Color-coded alert with message
export const LoadingSpinner      // Loading indicator
export const MetricBadge         // Small metric display (variants: default, success, warning, error)
```

### DashboardOverview.jsx
**Main overview section showing:**
- Health score with progress bar (0-100)
- Remaining Useful Life (in days)
- Failure probability (%)
- Alert banner with recommendation

**Uses:** StatusCard, AlertBanner, formatting utilities

### TelemetryChart.jsx
**Real-time data visualization with three charts:**
1. **ECC & Retry Metrics** - LineChart tracking ECC count + Retries
2. **Temperature & Wear** - Dual-axis LineChart for thermal + wear level
3. **Latency Trend** - BarChart for I/O latency
4. **Current Metrics** - MetricBadge display

**Updates:** Every 2 seconds (streaming data)
**Library:** Recharts

### SHAPChart.jsx
**SHAP explainability features:**
- Horizontal BarChart of feature importance
- Impact breakdown section (visual bars + percentages)
- Insights panel (top drivers + statistics)

**Uses:** Recharts, SHAP data from API

### OOBPanel.jsx
**Out-of-band interfaces (3-column grid):**

1. **UART Logs**
   - Console-style log display
   - Scrollable container (max 100 logs)
   - Real-time updates

2. **BLE Broadcast**
   - Connection status indicator
   - RSSI, Tx Power, Packets, MTU display
   - Broadcast data (UUID, Major, Minor)

3. **SMBus Status**
   - Status indicator (OK/Warning/Error)
   - Register status panel (hex values)
   - Protocol info (Version, Frequency, Address)

---

## 🔄 Data Flow

### 1. App Initialization (Mount)
```
App Component Mounts
    ↓
useStore() hook connects to Zustand
    ↓
useEffect hook triggers
    ↓
Parallel API calls:
  - getTelemetry()
  - getPrediction()
  - getShapExplanation()
  - getAlerts()
    ↓
Store updated with data
    ↓
Components re-render
```

### 2. Continuous Polling
```
Telemetry Polling (Every 2 seconds):
  - Calls getTelemetry()
  - Updates chart data
  
Prediction Polling (Every 5 seconds):
  - Calls getPrediction()
  - Calls getShapExplanation()
  - Calls getAlerts()
  
OOB Polling (Every 3 seconds):
  - Generates new UART log
  - Updates random BLE/SMBus values
```

### 3. Data Transformation
```
Raw API Response
    ↓
Zustand Store
    ↓
Component Props
    ↓
Formatted Display
```

---

## 🛠 Key Technologies

### React 18.2
- Hooks only (no class components)
- Functional components
- useEffect for side effects
- Context API (via Zustand)

### Vite 5.0
- Lightning-fast dev server (HMR)
- Automatic code splitting
- Optimized production builds
- Built-in CSS handling

### Tailwind CSS 3.3
- Utility-first CSS
- Dark mode support
- Custom animations
- Responsive design (mobile-first)

### Recharts 2.10
- React charting library
- Multiple chart types (Line, Bar, etc.)
- Custom tooltips
- Responsive containers

### Zustand 4.4
- Lightweight state management
- No boilerplate
- Subscriptions instead of selectors
- Easy to understand

### Axios 1.6
- Promise-based HTTP client
- Request/response interceptors
- Built-in timeout handling
- Error standardization

---

## 📊 State Management (Zustand)

### Single Store Pattern
```javascript
const useStore = create((set) => ({
  // Toggle mode
  useMockData: true,
  setUseMockData: (value) => set({ useMockData: value }),

  // Data
  telemetry: null,
  setTelemetry: (data) => set({ telemetry: data }),
  
  prediction: null,
  setPrediction: (data) => set({ prediction: data }),
  
  shap: null,
  setShap: (data) => set({ shap: data }),
  
  alerts: [],
  setAlerts: (data) => set({ alerts: data }),
  
  // OOB
  uartLogs: [],
  addUartLog: (log) => set((state) => ({
    uartLogs: [log, ...state.uartLogs.slice(0, 99)]
  })),
  
  // UI
  isLoading: false,
  setIsLoading: (value) => set({ isLoading: value }),
  
  error: null,
  setError: (value) => set({ error: value }),
}))
```

### Usage in Components
```javascript
const { telemetry, setTelemetry } = useStore()
```

---

## 🎨 Styling Architecture

### Tailwind Configuration
- **Dark theme colors** defined in `tailwind.config.js`
- **Custom animations** (pulse, slideIn, shimmer)
- **Reusable classes** (.stat-card, .chart-container, .glass)

### CSS Classes

**Card Styles:**
- `.stat-card` - Standard metric card
- `.chart-container` - Chart wrapper
- `.glass` - Glass morphism effect
- `.glass-dark` - Dark glass variant

**Colors:**
- `bg-dark-900` - Main background
- `bg-dark-800` - Cards/panels
- `bg-dark-700` - Borders/disabled

**Status Colors:**
- `text-green-400` - INFO
- `text-yellow-400` - WARNING
- `text-red-400` - CRITICAL
- `text-gray-300` - FATAL

### Custom Animations
```css
@keyframes pulse         /* Pulsing effect */
@keyframes shimmer      /* Loading shimmer */
@keyframes slideIn      /* Slide in from top */
```

---

## 🔌 API Service Layer

### Design Pattern: Dependency Injection

```javascript
// api.js provides single entry point
export const getTelemetry = async (useMockData = false) => {
  if (useMockData) {
    return mockDataService.generateMockTelemetry()
  }
  
  try {
    const response = await apiClient.get('/telemetry')
    return response.data
  } catch (error) {
    return mockDataService.generateMockTelemetry()  // Fallback
  }
}
```

### Mock vs. Real Switching
- Simple boolean flag: `useMockData`
- User can toggle in UI header
- Same component code works for both
- Errors automatically fallback to mock

---

## 🚀 Performance Optimizations

### Bundle Size
- Vite tree-shaking removes unused code
- Recharts provides only needed chart types
- Zustand is lightweight (~2KB)

### Rendering
- Components only re-render when their data changes
- Recharts handles its own re-renders efficiently
- Zustand subscriptions are granular

### Data Updates
- Telemetry polled every 2s (real-time feel)
- Predictions polled every 5s (expensive to compute)
- SHAP cached (recomputed every 5s max)

---

## 📝 API Response Contracts

See [BACKEND_INTEGRATION.md](./BACKEND_INTEGRATION.md) for complete specifications.

### Quick Reference

**Telemetry:**
```json
{ ecc_count, ecc_rate, retries, temperature, wear_level, latency, timestamp }
```

**Prediction:**
```json
{ health_score, failure_probability, remaining_life_days }
```

**SHAP:**
```json
[{ feature: string, impact: 0-1 }, ...]
```

**Alerts:**
```json
{ level: "INFO|WARNING|CRITICAL|FATAL", message, recommendation }
```

---

## 🧪 Testing Checklist

### Development Mode
- [ ] `npm run dev` starts without errors
- [ ] All charts render correctly
- [ ] Mock data updates every 2-5s
- [ ] Toggle Mock/API mode in header
- [ ] No console errors

### API Mode
- [ ] Backend running on port 8000
- [ ] Switch to API mode - data loads
- [ ] Telemetry updates every 2s
- [ ] Predictions update every 5s
- [ ] SHAP visualization correct

### Components
- [ ] Header renders and is clickable
- [ ] Overview cards display correctly
- [ ] Charts show data points
- [ ] SHAP shows all features
- [ ] OOB panels populated

### Responsive
- [ ] Mobile view (< 768px) works
- [ ] Tablet view (768px-1024px) works
- [ ] Desktop view (> 1024px) works
- [ ] Charts responsive to width

---

## 🔍 Debugging Tips

### Check Store State
```javascript
// In browser console
useStore.getState()
```

### Check API Calls
DevTools → Network tab
- Filter to XHR requests
- Verify response status & payload
- Check response times

### Enable Debug Mode
```javascript
// In App.jsx before fetch
console.log('Fetching data in mode:', useMockData)
```

### Mock Data Issues
1. Check mockData.js generators
2. Verify store is updated
3. Check component props
4. Inspect render output

---

## 📦 Dependencies Overview

| Package | Version | Purpose |
|---------|---------|---------|
| react | 18.2 | UI framework |
| vite | 5.0 | Build tool & dev server |
| tailwindcss | 3.3 | Styling |
| recharts | 2.10 | Charting |
| zustand | 4.4 | State management |
| axios | 1.6 | HTTP client |
| postcss | 8.4 | CSS transformation |
| autoprefixer | 10.4 | CSS vendor prefixes |

---

## 🎓 Architecture Decisions

### Why Zustand?
- ✅ Minimal boilerplate
- ✅ Easy to reason about
- ✅ Great TypeScript support
- ✅ Lightweight (~2KB)

### Why Recharts?
- ✅ React-native library
- ✅ Responsive components
- ✅ Good customization
- ✅ Active maintenance

### Why Vite?
- ✅ Lightning-fast HMR
- ✅ Zero-config setup
- ✅ Modern ES6+
- ✅ Fast production builds

### Why Tailwind?
- ✅ Utility-first approach
- ✅ Dark mode built-in
- ✅ Consistent design system
- ✅ Responsive utilities

---

## 🔄 Extension Points

### Add New Metric
1. Create component in `src/components/`
2. Add API call to `src/services/api.js`
3. Add store state to `src/store/appStore.js`
4. Fetch and display in `App.jsx`

### Add New API Endpoint
1. Implement in backend
2. Add fetch function in `src/services/api.js`
3. Add mock generator in `src/services/mockData.js`
4. Update store if needed
5. Create component to display

### Customize Colors
Edit `src/tailwind.config.js`:
```javascript
theme: {
  extend: {
    colors: {
      dark: { /* custom colors */ }
    }
  }
}
```

---

**Built for extensibility and production readiness**
