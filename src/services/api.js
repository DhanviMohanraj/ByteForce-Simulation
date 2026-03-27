import axios from 'axios'
import { mockDataService } from './mockData'

/**
 * Centralized API Layer for NAND Guardian
 *
 * Handles all communication with the Flask ML backend.
 * Supports:
 *   1. Mock data mode (development/testing)
 *   2. Live polling mode (REST GET endpoints)
 *   3. Server-Sent Events mode (real-time push from /api/stream)
 *
 * Backend endpoints:
 *   GET  /api/telemetry          - Latest SSD telemetry
 *   POST /api/ingest-telemetry   - Push telemetry from Simulink/MATLAB
 *   GET  /api/prediction         - XGBoost + LSTM outputs
 *   GET  /api/shap               - Feature importance
 *   GET  /api/alerts             - Alert level + recommendation
 *   GET  /api/simulation-status  - Is simulation data flowing?
 *   GET  /api/stream             - SSE push stream (all-in-one bundle)
 *   GET  /api/health             - Backend health check
 */

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000/api'

// Axios instance
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 3000,
  headers: { 'Content-Type': 'application/json' },
})

// ─── Telemetry ───────────────────────────────────────────────────────────────

/**
 * GET /api/telemetry
 * Returns: { ecc_count, ecc_rate, retries, temperature, wear_level, latency, timestamp }
 */
export const getTelemetry = async (useMockData = false) => {
  if (useMockData) return mockDataService.generateMockTelemetry()
  try {
    const { data } = await apiClient.get('/telemetry')
    return data
  } catch {
    return mockDataService.generateMockTelemetry()
  }
}

/**
 * POST /api/ingest-telemetry
 * Sends a telemetry object from the browser directly to the backend
 * (useful for testing the pipeline without MATLAB running).
 */
export const ingestTelemetry = async (payload) => {
  try {
    const { data } = await apiClient.post('/ingest-telemetry', payload)
    return data
  } catch (error) {
    console.error('ingestTelemetry failed:', error.message)
    return null
  }
}

// ─── Prediction ──────────────────────────────────────────────────────────────

/**
 * GET /api/prediction
 * Returns: { health_score, failure_probability, remaining_life_days }
 */
export const getPrediction = async (useMockData = false) => {
  if (useMockData) return mockDataService.generateMockPrediction()
  try {
    const { data } = await apiClient.get('/prediction')
    return data
  } catch {
    return mockDataService.generateMockPrediction()
  }
}

// ─── SHAP ─────────────────────────────────────────────────────────────────────

/**
 * GET /api/shap
 * Returns: [{ feature: string, impact: number }, ...]
 */
export const getShapExplanation = async (useMockData = false) => {
  if (useMockData) return mockDataService.generateMockShap()
  try {
    const { data } = await apiClient.get('/shap')
    return data
  } catch {
    return mockDataService.generateMockShap()
  }
}

// ─── Alerts ───────────────────────────────────────────────────────────────────

/**
 * GET /api/alerts
 * Returns: { level, message, recommendation }
 */
export const getAlerts = async (useMockData = false) => {
  if (useMockData) return mockDataService.generateMockAlerts()
  try {
    const { data } = await apiClient.get('/alerts')
    return data
  } catch {
    return mockDataService.generateMockAlerts()
  }
}

// ─── Simulation Status ────────────────────────────────────────────────────────

/**
 * GET /api/simulation-status
 * Returns: { status: 'live'|'stale'|'offline', source, telemetry_age_ms, ingest_ttl_seconds }
 */
export const getSimulationStatus = async () => {
  try {
    const { data } = await apiClient.get('/simulation-status')
    return data
  } catch {
    return { status: 'offline', source: 'unknown', telemetry_age_ms: null }
  }
}

// ─── Health Check ─────────────────────────────────────────────────────────────

/** Returns true if the backend is reachable */
export const healthCheck = async () => {
  try {
    const { status } = await apiClient.get('/health')
    return status === 200
  } catch {
    return false
  }
}

/** Returns the full health payload */
export const getHealthStatus = async () => {
  try {
    const { data } = await apiClient.get('/health')
    return data
  } catch {
    return null
  }
}

// ─── Server-Sent Events ───────────────────────────────────────────────────────

/**
 * Opens an EventSource connection to /api/stream.
 * Each event carries a JSON bundle:
 *   { telemetry, prediction, shap, alert, simulation_status, timestamp }
 *
 * @param {Function} onMessage  - Called with the parsed bundle on every event
 * @param {Function} onError    - Called on connection error
 * @returns {EventSource}       - Call .close() to disconnect
 */
export const openSseStream = (onMessage, onError) => {
  const url = `${API_BASE_URL}/stream`
  const es = new EventSource(url)

  es.onmessage = (event) => {
    try {
      const bundle = JSON.parse(event.data)
      onMessage(bundle)
    } catch {
      // ignore malformed frames
    }
  }

  es.onerror = (err) => {
    if (onError) onError(err)
  }

  return es
}

// ─── Config ───────────────────────────────────────────────────────────────────

export const setApiUrl = (url) => {
  apiClient.defaults.baseURL = url
}

export default {
  getTelemetry,
  ingestTelemetry,
  getPrediction,
  getShapExplanation,
  getAlerts,
  getSimulationStatus,
  healthCheck,
  getHealthStatus,
  openSseStream,
  setApiUrl,
}

