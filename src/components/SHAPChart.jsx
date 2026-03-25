import React from 'react'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts'

export const SHAPChart = ({ shapData, isLoading }) => {
  if (isLoading || !shapData) {
    return (
      <div className="chart-container animate-pulse">
        <div className="h-96 bg-dark-700 rounded"></div>
      </div>
    )
  }

  const sortedData = [...shapData].sort((a, b) => b.impact - a.impact)

  const CustomTooltip = ({ active, payload }) => {
    if (active && payload && payload.length) {
      return (
        <div className="bg-dark-800 border border-dark-700 rounded px-3 py-2 text-sm">
          <p className="text-white">{payload[0].payload.feature}</p>
          <p style={{ color: payload[0].color }}>
            Impact: {(payload[0].value * 100).toFixed(1)}%
          </p>
        </div>
      )
    }
    return null
  }

  const totalImpact = sortedData.reduce((sum, item) => sum + item.impact, 0)

  return (
    <div className="chart-container">
      <div className="mb-6">
        <h3 className="text-lg font-semibold mb-2 text-white">Feature Importance (SHAP)</h3>
        <p className="text-sm text-gray-400">
          Top contributing factors to the current health prediction
        </p>
      </div>

      <ResponsiveContainer width="100%" height={400}>
        <BarChart data={sortedData} layout="vertical" margin={{ left: 150, right: 20 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
          <XAxis type="number" stroke="#9ca3af" style={{ fontSize: '12px' }} />
          <YAxis dataKey="feature" type="category" stroke="#9ca3af" style={{ fontSize: '11px' }} width={140} />
          <Tooltip content={<CustomTooltip />} />
          <Bar dataKey="impact" fill="#06b6d4" isAnimationActive={false} radius={[0, 4, 4, 0]} />
        </BarChart>
      </ResponsiveContainer>

      <div className="mt-6 grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-dark-700/30 border border-dark-700 rounded p-4">
          <h4 className="text-sm font-semibold text-white mb-3">Impact Breakdown</h4>
          <div className="space-y-2">
            {sortedData.map((item) => (
              <div key={item.feature} className="flex items-center justify-between">
                <span className="text-xs text-gray-400">{item.feature}</span>
                <div className="flex items-center gap-2">
                  <div className="w-24 bg-dark-600 rounded h-1.5 overflow-hidden">
                    <div
                      className="bg-gradient-to-r from-cyan-500 to-blue-500 h-full"
                      style={{ width: `${(item.impact / Math.max(...sortedData.map((d) => d.impact))) * 100}%` }}
                    ></div>
                  </div>
                  <span className="text-xs font-semibold text-cyan-400 w-12 text-right">
                    {(item.impact * 100).toFixed(1)}%
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-dark-700/30 border border-dark-700 rounded p-4">
          <h4 className="text-sm font-semibold text-white mb-3">Insights</h4>
          <div className="space-y-2 text-xs text-gray-300">
            <p>
              <span className="text-cyan-400 font-semibold">{sortedData[0]?.feature}</span> is the primary
              driver ({(sortedData[0]?.impact * 100).toFixed(1)}%)
            </p>
            <p>
              Top 3 features account for{' '}
              <span className="text-cyan-400 font-semibold">
                {(sortedData.slice(0, 3).reduce((sum, item) => sum + item.impact, 0) * 100).toFixed(1)}%
              </span>{' '}
              of the prediction
            </p>
            <p className="text-gray-500 italic">These factors are influencing the drive's health score</p>
          </div>
        </div>
      </div>
    </div>
  )
}
