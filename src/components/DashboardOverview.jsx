import React from 'react'
import { StatusCard, AlertBanner } from './Common'
import { getHealthScoreColor, getHealthScoreBgColor } from '../utils/formatting'

export const DashboardOverview = ({ prediction, alert, isLoading }) => {
  if (isLoading || !prediction) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {[1, 2, 3].map((i) => (
          <div key={i} className="stat-card animate-pulse">
            <div className="h-20 bg-dark-700 rounded"></div>
          </div>
        ))}
      </div>
    )
  }

  const healthScore = Math.round(prediction.health_score)
  const failureProbability = Math.round(prediction.failure_probability * 100)
  const remainingDays = prediction.remaining_life_days

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className={`stat-card ${getHealthScoreBgColor(healthScore)}`}>
          <p className="text-gray-400 text-sm mb-2">Drive Health Score</p>
          <div className="flex items-center justify-between">
            <span className={`text-4xl font-bold ${getHealthScoreColor(healthScore)}`}>
              {healthScore}
            </span>
            <span className="text-3xl">❤️</span>
          </div>
          <div className="mt-4 bg-dark-700 rounded-full h-2 overflow-hidden">
            <div
              className={`h-full transition-all ${
                healthScore >= 80 ? 'bg-green-500' :
                healthScore >= 60 ? 'bg-yellow-500' :
                healthScore >= 40 ? 'bg-orange-500' :
                'bg-red-500'
              }`}
              style={{ width: `${healthScore}%` }}
            ></div>
          </div>
        </div>

        <StatusCard
          label="Remaining Useful Life"
          value={remainingDays}
          unit="days"
          icon="📅"
          trend={0}
        />

        <StatusCard
          label="Failure Probability"
          value={failureProbability}
          unit="%"
          icon="⚠️"
          trend={Math.random() * 10 - 5}
        />
      </div>

      {alert && (
        <AlertBanner
          level={alert.level}
          message={alert.message}
          recommendation={alert.recommendation}
        />
      )}
    </div>
  )
}
