import React from 'react'
import { getStatusColor, getAlertIcon } from '../utils/formatting'

export const Header = ({ useMockData, onToggleMockData }) => {
  return (
    <header className="border-b border-dark-700/30 bg-dark-900/50 backdrop-blur-md sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-6 py-4 flex justify-between items-center">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-cyan-500 rounded-lg flex items-center justify-center">
            <span className="text-white font-bold text-lg">NG</span>
          </div>
          <div>
            <h1 className="text-xl font-bold text-white">NAND Guardian</h1>
            <p className="text-xs text-gray-400">SSD Health Monitoring System</p>
          </div>
        </div>

        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2 px-3 py-2 bg-dark-800 border border-dark-700 rounded-lg">
            <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse"></span>
            <span className="text-sm text-green-400">Live</span>
          </div>

          <button
            onClick={onToggleMockData}
            className={`px-4 py-2 rounded-lg border transition-all ${
              useMockData
                ? 'bg-yellow-900/20 border-yellow-700 text-yellow-400'
                : 'bg-green-900/20 border-green-700 text-green-400'
            }`}
          >
            {useMockData ? 'Mock Mode' : 'API Mode'}
          </button>
        </div>
      </div>
    </header>
  )
}

export const StatusCard = ({ label, value, unit, icon, trend }) => {
  const trendColor = trend > 0 ? 'text-red-400' : 'text-green-400'
  const trendIcon = trend > 0 ? '↑' : '↓'

  return (
    <div className="stat-card group">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-gray-400 text-sm">{label}</p>
          <div className="mt-2 flex items-baseline gap-2">
            <span className="text-3xl font-bold text-white">{value}</span>
            {unit && <span className="text-sm text-gray-400">{unit}</span>}
          </div>
        </div>
        <div className="text-2xl opacity-50 group-hover:opacity-100 transition-opacity">{icon}</div>
      </div>
      {trend !== undefined && (
        <div className={`text-xs mt-3 ${trendColor}`}>
          {trendIcon} {Math.abs(trend).toFixed(1)}% from baseline
        </div>
      )}
    </div>
  )
}

export const AlertBanner = ({ level, message, recommendation, animated = true }) => {
  const colors = getStatusColor(level)

  return (
    <div className={`${colors.bg} border ${colors.border} rounded-lg p-4 ${animated ? 'animate-slideIn' : ''}`}>
      <div className="flex items-start gap-3">
        <div className={`w-2 h-2 rounded-full ${colors.dot} flex-shrink-0 mt-1.5`}></div>
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <span className="font-semibold text-white">{level}</span>
            <span className={colors.text}>{getAlertIcon(level)}</span>
          </div>
          <p className="text-sm text-gray-300 mt-1">{message}</p>
          {recommendation && (
            <p className="text-xs text-gray-400 mt-2 italic">
              Recommended: {recommendation}
            </p>
          )}
        </div>
      </div>
    </div>
  )
}

export const LoadingSpinner = () => (
  <div className="flex items-center justify-center p-8">
    <div className="relative w-8 h-8">
      <div className="absolute inset-0 bg-gradient-to-r from-blue-500 to-cyan-500 rounded-full animate-spin"></div>
      <div className="absolute inset-1 bg-dark-900 rounded-full"></div>
    </div>
  </div>
)

export const MetricBadge = ({ label, value, unit, variant = 'default' }) => {
  const baseStyle = 'px-3 py-1 rounded text-xs font-medium'
  const variants = {
    default: 'bg-dark-700 text-gray-300',
    success: 'bg-green-900/30 text-green-400 border border-green-700',
    warning: 'bg-yellow-900/30 text-yellow-400 border border-yellow-700',
    error: 'bg-red-900/30 text-red-400 border border-red-700',
  }

  return (
    <div className={`${baseStyle} ${variants[variant]}`}>
      {label}: <span className="font-bold">{value}{unit}</span>
    </div>
  )
}
