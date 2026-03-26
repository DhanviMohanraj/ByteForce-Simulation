import axios from 'axios'
import { mockDataService } from './mockData'

/**
 * Centralized API Layer for NAND Guardian
 * 
 * This service handles all communication with backend ML models.
 * It can seamlessly switch between:
 * 1. Mock data mode (development/testing)
 * 2. Real API mode (production)
 * 
 * Expected backend endpoints:
 * - GET /api/telemetry - Real-time SSD telemetry
 * - GET /api/prediction - ML health prediction
 * - GET /api/shap - Feature importance explanation
 * - GET /api/alerts - Current alerts and recommendations
 */

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000/api'

// Axios instance for API calls
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 5000,
  headers: {
    'Content-Type': 'application/json',
  },
})

/**
 * Telemetry API
 * Returns: { ecc_count, ecc_rate, retries, temperature, wear_level, latency, timestamp }
 */
export const getTelemetry = async (useMockData = false) => {
  if (useMockData) {
    return mockDataService.generateMockTelemetry()
  }
  
  try {
    const response = await apiClient.get('/telemetry')
    return response.data
  } catch (error) {
    console.error('Error fetching telemetry:', error.message)
    // Fallback to mock data on error
    return mockDataService.generateMockTelemetry()
  }
}

/**
 * Prediction API
 * Returns: { health_score, failure_probability, remaining_life_days }
 */
export const getPrediction = async (useMockData = false) => {
  if (useMockData) {
    return mockDataService.generateMockPrediction()
  }

  try {
    const response = await apiClient.get('/prediction')
    return response.data
  } catch (error) {
    console.error('Error fetching prediction:', error.message)
    return mockDataService.generateMockPrediction()
  }
}

/**
 * SHAP Explanation API
 * Returns: [{ feature: string, impact: number }, ...]
 */
export const getShapExplanation = async (useMockData = false) => {
  if (useMockData) {
    return mockDataService.generateMockShap()
  }

  try {
    const response = await apiClient.get('/shap')
    return response.data
  } catch (error) {
    console.error('Error fetching SHAP data:', error.message)
    return mockDataService.generateMockShap()
  }
}

/**
 * Alerts API
 * Returns: { level, message, recommendation }
 */
export const getAlerts = async (useMockData = false) => {
  if (useMockData) {
    return mockDataService.generateMockAlerts()
  }

  try {
    const response = await apiClient.get('/alerts')
    return response.data
  } catch (error) {
    console.error('Error fetching alerts:', error.message)
    return mockDataService.generateMockAlerts()
  }
}

/**
 * Health Check
 * Verify backend connectivity
 */
export const healthCheck = async () => {
  try {
    const response = await apiClient.get('/health')
    return response.status === 200
  } catch (error) {
    console.warn('Backend health check failed:', error.message)
    return false
  }
}

/**
 * Health details
 * Returns backend health payload for connectivity/source diagnostics
 */
export const getHealthStatus = async () => {
  try {
    const response = await apiClient.get('/health')
    return response.data
  } catch (error) {
    console.warn('Backend health details unavailable:', error.message)
    return null
  }
}

/**
 * Set API configuration
 * For connecting to different backend environments
 */
export const setApiUrl = (url) => {
  apiClient.defaults.baseURL = url
}

export default {
  getTelemetry,
  getPrediction,
  getShapExplanation,
  getAlerts,
  healthCheck,
  getHealthStatus,
  setApiUrl,
}
