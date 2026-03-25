// Mock data generator for development and testing

const generateMockTelemetry = () => ({
  ecc_count: Math.floor(Math.random() * 50) + 10,
  ecc_rate: (Math.random() * 0.5 + 0.1).toFixed(3),
  retries: Math.floor(Math.random() * 100) + 5,
  temperature: Math.floor(Math.random() * 15) + 35,
  wear_level: Math.random() * 30 + 20,
  latency: (Math.random() * 2 + 0.5).toFixed(2),
  timestamp: new Date().toISOString(),
})

const generateMockPrediction = () => ({
  health_score: Math.floor(Math.random() * 40) + 50,
  failure_probability: (Math.random() * 0.4 + 0.1).toFixed(3),
  remaining_life_days: Math.floor(Math.random() * 500) + 100,
})

const generateMockShap = () => [
  { feature: 'ECC acceleration', impact: 0.4 + Math.random() * 0.2 },
  { feature: 'Temperature', impact: 0.25 + Math.random() * 0.15 },
  { feature: 'Retry count', impact: 0.2 + Math.random() * 0.1 },
  { feature: 'Wear level', impact: 0.1 + Math.random() * 0.08 },
  { feature: 'Read latency', impact: 0.05 + Math.random() * 0.05 },
]

const generateMockAlerts = () => {
  const levels = ['INFO', 'WARNING', 'CRITICAL', 'FATAL']
  const level = levels[Math.floor(Math.random() * levels.length)]
  
  const messages = {
    INFO: 'SSD operating within normal parameters',
    WARNING: 'ECC error rate elevated - monitor closely',
    CRITICAL: 'Drive degradation detected - plan replacement',
    FATAL: 'Imminent drive failure - replace immediately'
  }

  const recommendations = {
    INFO: 'Continue normal operations',
    WARNING: 'Back up critical data within 30 days',
    CRITICAL: 'Schedule drive replacement within 7 days',
    FATAL: 'Replace drive immediately to prevent data loss'
  }

  return {
    level,
    message: messages[level] || 'Unknown status',
    recommendation: recommendations[level] || 'Monitor system',
  }
}

const generateUartLog = () => {
  const timestamp = new Date().toLocaleTimeString()
  const messages = [
    `[${timestamp}] UART: FW version check - OK`,
    `[${timestamp}] UART: Temperature sensor - ${Math.floor(Math.random() * 15) + 35}°C`,
    `[${timestamp}] UART: Power state - Active`,
    `[${timestamp}] UART: ECC status - ${Math.random() > 0.7 ? 'CORRECTED' : 'OK'}`,
    `[${timestamp}] UART: Cache status - Flushed`,
    `[${timestamp}] UART: Thermal throttle - ${Math.random() > 0.8 ? 'ENABLED' : 'DISABLED'}`,
  ]
  return messages[Math.floor(Math.random() * messages.length)]
}

export const mockDataService = {
  generateMockTelemetry,
  generateMockPrediction,
  generateMockShap,
  generateMockAlerts,
  generateUartLog,
}
