/**
 * Utility functions for NAND Guardian
 */

export const getStatusColor = (level) => {
  const colors = {
    INFO: { bg: 'bg-green-900', text: 'text-green-400', border: 'border-green-700', dot: 'bg-green-500' },
    WARNING: { bg: 'bg-yellow-900', text: 'text-yellow-400', border: 'border-yellow-700', dot: 'bg-yellow-500' },
    CRITICAL: { bg: 'bg-red-900', text: 'text-red-400', border: 'border-red-700', dot: 'bg-red-500' },
    FATAL: { bg: 'bg-gray-900', text: 'text-gray-300', border: 'border-gray-700', dot: 'bg-gray-500' },
  }
  return colors[level] || colors.INFO
}

export const getHealthScoreColor = (score) => {
  if (score >= 80) return 'text-green-400'
  if (score >= 60) return 'text-yellow-400'
  if (score >= 40) return 'text-orange-400'
  return 'text-red-400'
}

export const getHealthScoreBgColor = (score) => {
  if (score >= 80) return 'bg-green-900/20'
  if (score >= 60) return 'bg-yellow-900/20'
  if (score >= 40) return 'bg-orange-900/20'
  return 'bg-red-900/20'
}

export const formatBytes = (bytes) => {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i]
}

export const formatDate = (dateString) => {
  const date = new Date(dateString)
  return date.toLocaleTimeString()
}

export const formatPercent = (value) => {
  return Math.round(value * 100) / 100
}

export const getAlertIcon = (level) => {
  const icons = {
    INFO: '●',
    WARNING: '⚠',
    CRITICAL: '●',
    FATAL: '✕',
  }
  return icons[level] || '●'
}
