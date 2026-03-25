import React from 'react'
import { MetricBadge } from './Common'

export const OOBPanel = ({ uartLogs, bleStatus, smbusStatus, isLoading }) => {
  if (isLoading) {
    return (
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {[1, 2, 3].map((i) => (
          <div key={i} className="chart-container animate-pulse">
            <div className="h-80 bg-dark-700 rounded"></div>
          </div>
        ))}
      </div>
    )
  }

  const getBleStatusColor = (status) => {
    if (status === 'Connected') return 'success'
    if (status === 'Connecting') return 'warning'
    return 'error'
  }

  const getSmbusStatusColor = (status) => {
    if (status === 'OK') return 'success'
    if (status === 'Warning') return 'warning'
    return 'error'
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
      {/* UART Logs */}
      <div className="chart-container lg:col-span-1">
        <h3 className="text-lg font-semibold mb-4 text-white">UART Logs</h3>
        <div className="space-y-2 font-mono text-xs max-h-96 overflow-y-auto">
          {uartLogs.length === 0 ? (
            <p className="text-gray-500 italic">No logs yet...</p>
          ) : (
            uartLogs.map((log, idx) => (
              <div key={idx} className="text-gray-400 hover:text-gray-300 transition-colors py-1 px-2 hover:bg-dark-700/50 rounded">
                {log}
              </div>
            ))
          )}
        </div>
      </div>

      {/* BLE Broadcast */}
      <div className="chart-container">
        <h3 className="text-lg font-semibold mb-4 text-white">BLE Broadcast</h3>
        <div className="space-y-4">
          <div className="bg-dark-700/30 border border-dark-700 rounded p-4">
            <div className="text-sm text-gray-400 mb-2">Connection Status</div>
            <div className="flex items-center gap-3 my-4">
              <div
                className={`w-8 h-8 rounded-full flex items-center justify-center ${
                  bleStatus === 'Connected'
                    ? 'bg-green-900 border-2 border-green-500'
                    : 'bg-yellow-900 border-2 border-yellow-500'
                }`}
              >
                <span className="text-lg">📡</span>
              </div>
              <div>
                <p className="text-white font-semibold">{bleStatus}</p>
                <p className="text-xs text-gray-400">BLE 5.0</p>
              </div>
            </div>

            <div className="mt-4 pt-4 border-t border-dark-700 space-y-1">
              <div className="flex justify-between text-xs">
                <span className="text-gray-400">RSSI</span>
                <span className="text-green-400">-45 dBm</span>
              </div>
              <div className="flex justify-between text-xs">
                <span className="text-gray-400">Tx Power</span>
                <span className="text-blue-400">0 dBm</span>
              </div>
              <div className="flex justify-between text-xs">
                <span className="text-gray-400">Packets</span>
                <span className="text-cyan-400">{Math.floor(Math.random() * 10000) + 1000}</span>
              </div>
              <div className="flex justify-between text-xs">
                <span className="text-gray-400">MTU</span>
                <span className="text-purple-400">247</span>
              </div>
            </div>
          </div>

          <div className="bg-dark-700/30 border border-dark-700 rounded p-4">
            <div className="text-sm text-gray-400 mb-3">Broadcast Data</div>
            <div className="space-y-2 font-mono text-xs">
              <div className="text-gray-500">
                <span className="text-gray-600">UUID:</span> {' '}
                <span className="text-blue-400">550e8400-e29b-41d4</span>
              </div>
              <div className="text-gray-500">
                <span className="text-gray-600">Major:</span> {' '}
                <span className="text-green-400">{Math.floor(Math.random() * 1000)}</span>
              </div>
              <div className="text-gray-500">
                <span className="text-gray-600">Minor:</span> {' '}
                <span className="text-green-400">{Math.floor(Math.random() * 100)}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* SMBus Status */}
      <div className="chart-container">
        <h3 className="text-lg font-semibold mb-4 text-white">SMBus Interface</h3>
        <div className="space-y-4">
          <div className={`rounded p-4 border ${
            smbusStatus === 'OK'
              ? 'bg-green-900/20 border-green-700'
              : 'bg-yellow-900/20 border-yellow-700'
          }`}>
            <div className="flex items-center justify-between">
              <span className={`font-semibold ${
                smbusStatus === 'OK' ? 'text-green-400' : 'text-yellow-400'
              }`}>
                Status: {smbusStatus}
              </span>
              <span className={`w-3 h-3 rounded-full ${
                smbusStatus === 'OK' ? 'bg-green-500 animate-pulse' : 'bg-yellow-500'
              }`}></span>
            </div>
          </div>

          <div className="bg-dark-700/30 border border-dark-700 rounded p-4">
            <h4 className="text-sm font-semibold text-white mb-3">Register Status</h4>
            <div className="space-y-2">
              <div className="flex justify-between items-center text-xs">
                <span className="text-gray-400">0x00 - Control</span>
                <span className="font-mono text-cyan-400">0x{Math.floor(Math.random() * 256).toString(16).toUpperCase().padStart(2, '0')}</span>
              </div>
              <div className="flex justify-between items-center text-xs">
                <span className="text-gray-400">0x01 - Status</span>
                <span className="font-mono text-cyan-400">0x{Math.floor(Math.random() * 256).toString(16).toUpperCase().padStart(2, '0')}</span>
              </div>
              <div className="flex justify-between items-center text-xs">
                <span className="text-gray-400">0x02 - Error</span>
                <span className="font-mono text-cyan-400">0x{Math.floor(Math.random() * 256).toString(16).toUpperCase().padStart(2, '0')}</span>
              </div>
              <div className="flex justify-between items-center text-xs">
                <span className="text-gray-400">0x03 - Data</span>
                <span className="font-mono text-cyan-400">0x{Math.floor(Math.random() * 256).toString(16).toUpperCase().padStart(2, '0')}</span>
              </div>
            </div>
          </div>

          <div className="bg-dark-700/30 border border-dark-700 rounded p-4">
            <h4 className="text-sm font-semibold text-white mb-3">Protocol Info</h4>
            <div className="space-y-1 text-xs text-gray-400">
              <div className="flex justify-between">
                <span>Version:</span>
                <span className="text-gray-300">3.0</span>
              </div>
              <div className="flex justify-between">
                <span>Frequency:</span>
                <span className="text-gray-300">100 kHz</span>
              </div>
              <div className="flex justify-between">
                <span>Address:</span>
                <span className="text-gray-300">0x72</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
