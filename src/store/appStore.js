import { create } from 'zustand'

export const useStore = create((set) => ({
  // API Mode Toggle — default to live backend data
  useMockData: false,
  setUseMockData: (useMockData) => set({ useMockData }),

  // Telemetry (raw from Simulink/backend)
  telemetry: null,
  setTelemetry: (telemetry) => set({ telemetry }),

  // Rolling history for charts (max 60 samples)
  telemetryHistory: [],
  pushTelemetryHistory: (sample) =>
    set((state) => ({
      telemetryHistory: [...state.telemetryHistory.slice(-59), sample],
    })),

  // Prediction (ML outputs from XGBoost + LSTM)
  prediction: null,
  setPrediction: (prediction) => set({ prediction }),

  // Health score (0-100) and failure probability (0-1) extracted separately
  healthScore: null,
  setHealthScore: (healthScore) => set({ healthScore }),
  failureProbability: null,
  setFailureProbability: (failureProbability) => set({ failureProbability }),

  // SHAP
  shap: null,
  setShap: (shap) => set({ shap }),

  // Alerts
  alerts: null,
  setAlerts: (alerts) => set({ alerts }),

  // Data source tracking
  dataSource: 'offline',     // 'offline' | 'mock' | 'simulation' | 'simulink'
  setDataSource: (src) => set({ dataSource: src }),

  // Simulation pipeline status: 'offline' | 'live' | 'stale'
  simulationStatus: 'offline',
  setSimulationStatus: (status) => set({ simulationStatus: status }),

  lastIngestAgeMs: null,
  setLastIngestAgeMs: (ms) => set({ lastIngestAgeMs: ms }),

  // OOB Data
  uartLogs: [],
  addUartLog: (log) =>
    set((state) => ({
      uartLogs: [log, ...state.uartLogs.slice(0, 99)],
    })),

  bleStatus: 'Connected',
  setBleStatus: (status) => set({ bleStatus: status }),

  smbusStatus: 'OK',
  setSmbusStatus: (status) => set({ smbusStatus: status }),

  // Loading states
  isLoading: false,
  setIsLoading: (isLoading) => set({ isLoading }),

  error: null,
  setError: (error) => set({ error }),
}))


