import { create } from 'zustand'

export const useStore = create((set) => ({
  // API Mode Toggle
  useMockData: true,
  setUseMockData: (useMockData) => set({ useMockData }),

  // Telemetry
  telemetry: null,
  setTelemetry: (telemetry) => set({ telemetry }),

  // Prediction
  prediction: null,
  setPrediction: (prediction) => set({ prediction }),

  // SHAP
  shap: null,
  setShap: (shap) => set({ shap }),

  // Alerts
  alerts: [],
  setAlerts: (alerts) => set({ alerts }),

  // OOB Data
  uartLogs: [],
  addUartLog: (log) => set((state) => ({
    uartLogs: [log, ...state.uartLogs.slice(0, 99)]
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
