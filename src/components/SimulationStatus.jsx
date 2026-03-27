/**
 * SimulationStatus — visual pipeline banner
 *
 * Shows the live state of each stage in the data pipeline:
 *   [MATLAB Simulink] → [Flask Backend] → [XGBoost/LSTM] → [Dashboard]
 *
 * Each node is coloured:
 *   green  = live / connected
 *   amber  = stale / degraded
 *   red    = offline / disconnected
 */

const STATUS_COLORS = {
  live: {
    dot: 'bg-green-400 shadow-[0_0_8px_2px_rgba(74,222,128,0.6)]',
    badge: 'border-green-700/60 bg-green-900/20 text-green-400',
    label: '● LIVE',
  },
  stale: {
    dot: 'bg-amber-400 shadow-[0_0_8px_2px_rgba(251,191,36,0.5)]',
    badge: 'border-amber-700/60 bg-amber-900/20 text-amber-400',
    label: '● STALE',
  },
  offline: {
    dot: 'bg-red-500/70',
    badge: 'border-red-900/60 bg-red-900/10 text-red-400/80',
    label: '○ OFFLINE',
  },
  ok: {
    dot: 'bg-green-400 shadow-[0_0_8px_2px_rgba(74,222,128,0.6)]',
    badge: 'border-green-700/60 bg-green-900/20 text-green-400',
    label: '● OK',
  },
}

function PipelineNode({ label, sublabel, status }) {
  const s = STATUS_COLORS[status] ?? STATUS_COLORS.offline
  return (
    <div className="flex flex-col items-center gap-1">
      <div className={`h-2 w-2 rounded-full ${s.dot}`} />
      <div className={`rounded border px-2 py-0.5 text-[0.6rem] font-semibold uppercase tracking-widest ${s.badge}`}>
        {label}
      </div>
      {sublabel && (
        <div className="text-[0.55rem] text-slate-500 tracking-wider">{sublabel}</div>
      )}
    </div>
  )
}

function Arrow({ active }) {
  return (
    <div className={`flex items-center pb-2 transition-colors duration-500 ${active ? 'text-cyan-500' : 'text-slate-700'}`}>
      <div className={`h-px w-6 ${active ? 'bg-cyan-500/60' : 'bg-slate-700/60'}`} />
      <span className="text-xs">▶</span>
      <div className={`h-px w-6 ${active ? 'bg-cyan-500/60' : 'bg-slate-700/60'}`} />
    </div>
  )
}

/**
 * @param {Object} props
 * @param {boolean} props.backendConnected   - Flask backend reachable
 * @param {'live'|'stale'|'offline'} props.simulationStatus - Simulink data freshness
 * @param {boolean} props.modelLoaded        - XGBoost model loaded
 * @param {number|null} props.telemetryAgeMs - Age of last Simulink POST in ms
 */
export default function SimulationStatus({ backendConnected, simulationStatus, modelLoaded, telemetryAgeMs }) {
  const simStatus = simulationStatus ?? 'offline'
  const backendStatus = backendConnected ? 'ok' : 'offline'
  const modelStatus = backendConnected && modelLoaded ? 'ok' : (backendConnected ? 'stale' : 'offline')
  const dashStatus = backendConnected ? 'ok' : 'offline'

  const ageLabel = telemetryAgeMs != null
    ? `${(telemetryAgeMs / 1000).toFixed(1)}s ago`
    : null

  return (
    <div className="flex items-center gap-1 rounded-md border border-[#16273e] bg-[#04091a] px-3 py-2">
      <span className="mr-2 text-[0.6rem] uppercase tracking-widest text-slate-500">Pipeline</span>

      <PipelineNode
        label="MATLAB"
        sublabel={ageLabel}
        status={simStatus}
      />
      <Arrow active={simStatus === 'live'} />
      <PipelineNode
        label="Flask API"
        sublabel="port 8000"
        status={backendStatus}
      />
      <Arrow active={backendConnected} />
      <PipelineNode
        label="XGBoost/LSTM"
        sublabel={modelLoaded ? 'model loaded' : 'no model'}
        status={modelStatus}
      />
      <Arrow active={backendConnected && modelLoaded} />
      <PipelineNode
        label="Dashboard"
        sublabel="live data"
        status={dashStatus}
      />
    </div>
  )
}
