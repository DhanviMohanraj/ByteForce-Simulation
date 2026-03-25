import React, { useState, useEffect } from 'react'
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts'
import { MetricBadge } from './Common'

export const TelemetryChart = ({ telemetry, isLoading }) => {
  const [chartData, setChartData] = useState([])

  useEffect(() => {
    if (telemetry) {
      setChartData((prev) => {
        const newData = [
          ...prev,
          {
            time: new Date(telemetry.timestamp).toLocaleTimeString(),
            eccCount: telemetry.ecc_count,
            eccRate: parseFloat(telemetry.ecc_rate),
            retries: telemetry.retries,
            temperature: telemetry.temperature,
            wearLevel: telemetry.wear_level,
            latency: parseFloat(telemetry.latency),
          },
        ]
        return newData.slice(-30)
      })
    }
  }, [telemetry])

  const CustomTooltip = ({ active, payload }) => {
    if (active && payload && payload.length) {
      return (
        <div className="bg-dark-800 border border-dark-700 rounded px-3 py-2 text-sm">
          {payload.map((entry, index) => (
            <p key={index} style={{ color: entry.color }}>
              {entry.name}: {entry.value.toFixed(2)}
            </p>
          ))}
        </div>
      )
    }
    return null
  }

  if (isLoading) {
    return (
      <div className="chart-container animate-pulse">
        <div className="h-80 bg-dark-700 rounded"></div>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div className="chart-container">
        <h3 className="text-lg font-semibold mb-4 text-white">ECC & Retry Metrics</h3>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
            <XAxis dataKey="time" stroke="#9ca3af" style={{ fontSize: '12px' }} />
            <YAxis stroke="#9ca3af" style={{ fontSize: '12px' }} />
            <Tooltip content={<CustomTooltip />} />
            <Legend />
            <Line
              type="monotone"
              dataKey="eccCount"
              stroke="#ef4444"
              dot={false}
              name="ECC Count"
              isAnimationActive={false}
            />
            <Line
              type="monotone"
              dataKey="retries"
              stroke="#f59e0b"
              dot={false}
              name="Retries"
              isAnimationActive={false}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>

      <div className="chart-container">
        <h3 className="text-lg font-semibold mb-4 text-white">Temperature & Wear Level</h3>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
            <XAxis dataKey="time" stroke="#9ca3af" style={{ fontSize: '12px' }} />
            <YAxis stroke="#9ca3af" style={{ fontSize: '12px' }} yAxisId="left" />
            <YAxis stroke="#9ca3af" style={{ fontSize: '12px' }} yAxisId="right" orientation="right" />
            <Tooltip content={<CustomTooltip />} />
            <Legend />
            <Line
              yAxisId="left"
              type="monotone"
              dataKey="temperature"
              stroke="#ff6b6b"
              dot={false}
              name="Temperature (°C)"
              isAnimationActive={false}
            />
            <Line
              yAxisId="right"
              type="monotone"
              dataKey="wearLevel"
              stroke="#8b5cf6"
              dot={false}
              name="Wear Level (%)"
              isAnimationActive={false}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>

      <div className="chart-container">
        <h3 className="text-lg font-semibold mb-4 text-white">Latency Trend</h3>
        <ResponsiveContainer width="100%" height={250}>
          <BarChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
            <XAxis dataKey="time" stroke="#9ca3af" style={{ fontSize: '12px' }} />
            <YAxis stroke="#9ca3af" style={{ fontSize: '12px' }} />
            <Tooltip content={<CustomTooltip />} />
            <Bar dataKey="latency" fill="#06b6d4" name="Latency (ms)" isAnimationActive={false} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {telemetry && (
        <div className="chart-container">
          <h3 className="text-lg font-semibold mb-4 text-white">Current Metrics</h3>
          <div className="grid grid-cols-2 md:grid-cols-6 gap-2">
            <MetricBadge label="ECC Count" value={telemetry.ecc_count} variant="error" />
            <MetricBadge label="ECC Rate" value={telemetry.ecc_rate} variant="warning" />
            <MetricBadge label="Retries" value={telemetry.retries} variant="warning" />
            <MetricBadge label="Temp" value={telemetry.temperature} unit="°C" variant="error" />
            <MetricBadge label="Wear" value={telemetry.wear_level.toFixed(1)} unit="%" variant="warning" />
            <MetricBadge label="Latency" value={telemetry.latency} unit="ms" variant="default" />
          </div>
        </div>
      )}
    </div>
  )
}
