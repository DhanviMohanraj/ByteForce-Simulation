import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  getHealthStatus,
  healthCheck,
  openSseStream,
} from '../services/api'
import SimulationStatus from './SimulationStatus'

// ─── Constants ────────────────────────────────────────────────────────────────

const ALERT_COLORS = {
  INFO:     { badge: 'bg-blue-400/80 text-blue-950',           active: 'ring-1 ring-blue-400/50'    },
  WARNING:  { badge: 'bg-amber-400/80 text-amber-950',         active: 'ring-1 ring-amber-400/50'   },
  CRITICAL: { badge: 'bg-red-500/80 text-white',               active: 'ring-1 ring-red-500/50'     },
  FATAL:    { badge: 'bg-red-700 text-white animate-pulse',     active: 'ring-1 ring-red-700/50'     },
}

const LEVEL_NUM = { INFO: 1, WARNING: 2, CRITICAL: 3, FATAL: 4 }

// ─── Helpers ──────────────────────────────────────────────────────────────────

function createBlocks(badBlocks = 0, journalPct = 0) {
  // 250 blocks total in visualization
  const total = 250;
  // Proportional bad blocks
  const badCount = Math.min(total, Math.ceil((badBlocks / 1000) * total)); 
  // Proportional erasing blocks based on journal
  const eraseCount = Math.min(total - badCount, Math.ceil((journalPct / 100) * 15)); 
  // Some active blocks
  const activeCount = 8;
  const writingCount = 4;

  const blocks = Array.from({ length: total }, (_, i) => {
    if (i < badCount) return { id: i, state: 'bad' };
    if (i < badCount + eraseCount) return { id: i, state: 'erasing' };
    if (i < badCount + eraseCount + activeCount) return { id: i, state: 'active' };
    if (i < badCount + eraseCount + activeCount + writingCount) return { id: i, state: 'writing' };
    return { id: i, state: 'good' };
  });

  // Shuffle for realistic look
  for (let i = blocks.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [blocks[i], blocks[j]] = [blocks[j], blocks[i]];
  }
  return blocks;
}

function createLinePoints(data) {
  const max = Math.max(...data, 1)
  const min = Math.min(...data, 0)
  const span = Math.max(max - min, 0.001)
  return data
    .map((v, i) => {
      const x = (i / Math.max(data.length - 1, 1)) * 100
      const y = 100 - ((v - min) / span) * 80 - 10
      return `${x},${y}`
    })
    .join(' ')
}

function wearStageLabel(wear) {
  if (wear == null) return '—'
  if (wear < 25) return 'Stage 1'
  if (wear < 50) return 'Stage 2'
  if (wear < 75) return 'Stage 3'
  return 'Stage 4'
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function MiniLine({ data, color }) {
  const points = useMemo(() => createLinePoints(data), [data])
  return (
    <svg viewBox="0 0 100 100" className="h-16 w-full">
      <polyline fill="none" stroke={color} strokeWidth="2.5" points={points} />
    </svg>
  )
}

/** Half-circle gauge — score 0-100 */
function HealthGauge({ score = 0 }) {
  const clamped = Math.max(0, Math.min(100, score))
  const totalArc = 141  // π × radius(45)
  const filled = (clamped / 100) * totalArc
  const color =
    clamped >= 75 ? '#22d3ee'
    : clamped >= 50 ? '#eab308'
    : clamped >= 25 ? '#f97316'
    : '#ef4444'

  return (
    <div className="relative flex flex-col items-center justify-center">
      <svg width="130" height="75" viewBox="0 0 130 75">
        {/* track */}
        <path d="M 10 70 A 55 55 0 0 1 120 70"
          fill="none" stroke="#0d1f3a" strokeWidth="12" strokeLinecap="round" />
        {/* minimum tick so 0 is visible */}
        <path d="M 10 70 A 55 55 0 0 1 12 62"
          fill="none" stroke="#1e3a5f" strokeWidth="12" strokeLinecap="round" />
        {/* filled arc */}
        <path d="M 10 70 A 55 55 0 0 1 120 70"
          fill="none"
          stroke={color}
          strokeWidth="12"
          strokeLinecap="round"
          strokeDasharray={`${filled} ${totalArc}`}
          style={{ transition: 'stroke-dasharray 0.8s ease, stroke 0.8s ease' }}
        />
      </svg>
      <div className="absolute bottom-0 text-center leading-none">
        <span className="text-4xl font-extrabold tabular-nums" style={{ color }}>
          {clamped}
        </span>
        <span className="ml-0.5 text-xs text-slate-500">/100</span>
      </div>
    </div>
  )
}

function MetricTile({ title, value, hint, highlight, live }) {
  return (
    <div className={`rounded-md border p-3 transition-all duration-500 ${
      highlight ? 'border-cyan-400/70 bg-cyan-500/5' : 'border-[#1a2a42] bg-[#0b1221]'
    } ${live ? 'ring-1 ring-cyan-500/15' : ''}`}>
      <p className="text-[0.65rem] uppercase tracking-[0.15em] text-gray-400">{title}</p>
      <p className="mt-1 truncate text-base font-semibold text-cyan-300">{value}</p>
      <p className="text-[0.65rem] text-[#4a6388]">{hint}</p>
    </div>
  )
}

// ─── Left Panel — single real SSD ─────────────────────────────────────────────

function LeftPanel({ telemetry, prediction, simStatus }) {
  const wear      = telemetry ? Number(telemetry.wear_level)  : null
  const temp      = telemetry ? Number(telemetry.temperature) : null
  const eccRate   = telemetry ? Number(telemetry.ecc_rate)    : null
  const retries   = telemetry ? Number(telemetry.retries)     : null
  const latency   = telemetry ? Number(telemetry.latency)     : null
  const failPct   = prediction ? (Number(prediction.failure_probability ?? 0) * 100).toFixed(1) : null
  const healthSc  = prediction ? Number(prediction.health_score ?? 0) : null

  const isLive    = simStatus === 'live'

  return (
    <aside className="space-y-3 border-r border-[#16233d] bg-[#060b17] p-3">
      <p className="text-[0.65rem] uppercase tracking-[0.24em] text-[#4a6388]">
        Drive Monitor
      </p>

      {/* Single real drive card */}
      <div className={`rounded-md border p-3 transition-colors duration-500 ${
        isLive ? 'border-cyan-400/80 bg-[#0d1527]' : 'border-[#1a2a42] bg-[#0b1221]'
      }`}>
        <div className="flex items-center justify-between">
          <p className="font-semibold text-gray-100">SSD — Monitored Drive</p>
          {isLive
            ? <span className="text-[0.6rem] font-semibold text-cyan-400">● LIVE</span>
            : <span className="text-[0.6rem] text-slate-500">○ WAITING</span>
          }
        </div>

        {healthSc != null && (
          <div className="mt-2 flex items-center gap-2">
            <div className={`h-2 flex-1 rounded bg-[#14284b]`}>
              <div
                className="h-2 rounded transition-all duration-700"
                style={{
                  width: `${healthSc}%`,
                  backgroundColor:
                    healthSc >= 75 ? '#22d3ee' : healthSc >= 50 ? '#eab308' : healthSc >= 25 ? '#f97316' : '#ef4444',
                }}
              />
            </div>
            <span className="text-xs font-bold text-slate-300">{healthSc}</span>
          </div>
        )}

        <div className="mt-3 space-y-1 text-xs text-[#7f97bc]">
          <div className="flex justify-between">
            <span>Wear Level</span>
            <span className={wear != null && wear > 75 ? 'text-red-400' : 'text-green-400'}>
              {wear != null ? `${wear.toFixed(1)}%` : '—'}
            </span>
          </div>
          <div className="flex justify-between">
            <span>Temperature</span>
            <span className={temp != null && temp > 75 ? 'text-red-400' : ''}>
              {temp != null ? `${temp.toFixed(1)}°C` : '—'}
            </span>
          </div>
          <div className="flex justify-between">
            <span>ECC Rate</span>
            <span>{eccRate != null ? eccRate.toFixed(4) : '—'}</span>
          </div>
          <div className="flex justify-between">
            <span>Retries</span>
            <span>{retries != null ? retries : '—'}</span>
          </div>
          <div className="flex justify-between">
            <span>Latency</span>
            <span>{latency != null ? `${latency.toFixed(2)} ms` : '—'}</span>
          </div>
          <div className="flex justify-between">
            <span>Fail Probability</span>
            <span className={failPct != null && Number(failPct) > 50 ? 'text-red-400 font-semibold' : 'text-slate-300'}>
              {failPct != null ? `${failPct}%` : '—'}
            </span>
          </div>
        </div>
      </div>

      {/* NAND parameters box */}
      <section className="rounded-md border border-[#1a2a42] bg-[#0b1221] p-3 text-xs text-[#7f97bc]">
        <p className="mb-2 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">NAND Parameters</p>
        <div className="space-y-1">
          <div className="flex justify-between">
            <span>Wear stage</span>
            <span className="text-cyan-400">{wearStageLabel(wear)}</span>
          </div>
          <div className="flex justify-between">
            <span>ECC rate</span>
            <span>{eccRate != null ? eccRate.toFixed(5) : '—'}</span>
          </div>
          <div className="flex justify-between">
            <span>Retries</span>
            <span>{retries != null ? retries : '—'}</span>
          </div>
          <div className="flex justify-between">
            <span>Latency</span>
            <span>{latency != null ? `${latency.toFixed(2)} ms` : '—'}</span>
          </div>
          <div className="flex justify-between">
            <span>Temperature</span>
            <span>{temp != null ? `${temp.toFixed(1)}°C` : '—'}</span>
          </div>
        </div>
      </section>
    </aside>
  )
}

// ─── Center Panel ─────────────────────────────────────────────────────────────

function CenterPanel({ blocks, logs, architectureData, simStatus }) {
  const isLive = simStatus === 'live'
  
  return (
    <section className="relative space-y-4 p-4">
      {!isLive && (
        <div className="absolute inset-0 z-10 flex flex-col items-center justify-center bg-[#030814]/80 backdrop-blur-sm rounded-lg border border-[#1a2a42] m-4">
          <p className="text-xl font-bold tracking-widest text-[#4a6388]">SSD NOT PAIRED</p>
          <p className="mt-2 text-xs text-[#4a6388]">Waiting for Simulink Telemetry...</p>
        </div>
      )}
      
      {/* Architecture tiles */}
      <div className="rounded-lg border border-[#1a2a42] bg-[#0b1221] p-4">
        <p className="mb-3 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">
          System Architecture — Live Flow
        </p>
        <div className="space-y-3">
          {architectureData.map((group) => (
            <div key={group.row} className="grid grid-cols-[82px_1fr] gap-3">
              <p className="pt-3 text-[0.65rem] uppercase tracking-[0.2em] text-[#4a6388]">{group.row}</p>
              <div className="grid gap-2 md:grid-cols-2 xl:grid-cols-4">
                {group.items.map((item) => (
                  <MetricTile key={item.title} {...item} />
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* NAND Flash map */}
      <div className="rounded-lg border border-[#1a2a42] bg-[#0b1221] p-4">
        <div className="mb-2 flex items-center justify-between">
          <p className="text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">
            NAND Flash Map — Block Level
          </p>
          <div className="flex gap-3 text-[0.65rem] text-[#4a6388]">
            <span className="text-green-500">■ good</span>
            <span className="text-cyan-400">■ active</span>
            <span className="text-lime-400">■ writing</span>
            <span className="text-amber-400">■ erasing</span>
            <span className="text-red-500">■ bad</span>
          </div>
        </div>
        <div className="grid grid-cols-25 gap-[2px] rounded-md border border-[#14203a] bg-[#071022] p-3">
          {blocks.map((cell) => (
            <div
              key={cell.id}
              className={`h-8 rounded-sm transition-colors duration-700 ${
                cell.state === 'good'    ? 'bg-green-950/70'
                : cell.state === 'active'  ? 'bg-cyan-900/70'
                : cell.state === 'writing' ? 'bg-lime-700/70'
                : cell.state === 'erasing' ? 'bg-amber-700/60'
                : 'bg-red-800/70'
              }`}
            />
          ))}
        </div>
      </div>

      {/* Live telemetry event log */}
      <div className="rounded-lg border border-[#1a2a42] bg-[#0b1221] p-4">
        <div className="mb-2 flex items-center gap-2">
          <p className="text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">
            Telemetry Event Log
          </p>
          <span className="rounded bg-cyan-900/40 px-1.5 py-0.5 text-[0.55rem] text-cyan-400 uppercase tracking-wider">
            live
          </span>
          <span className="text-[0.55rem] text-slate-600 ml-auto">
            entries generated from real telemetry values
          </span>
        </div>
        <div className="max-h-44 space-y-1 overflow-auto pr-1 font-mono text-xs text-[#7f97bc]">
          {logs.length === 0 ? (
            <p className="py-4 text-center text-[#4a6388]">
              Waiting for simulation data…
            </p>
          ) : (
            logs.map((entry) => (
              <div
                key={entry.id}
                className={`rounded border border-transparent px-3 py-1 transition-colors hover:border-[#1a2a42] bg-[#071422]`}
              >
                <span className="mr-2 text-[#4a6388]">{entry.time}</span>
                <span className={`text-[0.65rem] mr-2 rounded px-1 ${
                  entry.tag === 'UBER'     ? 'bg-red-900/80 text-white'
                  : entry.tag === 'BBM'    ? 'bg-cyan-900/60 text-cyan-300'
                  : entry.tag === 'JOURNAL'? 'bg-amber-900/60 text-amber-300'
                  : entry.tag === 'RETRY'  ? 'bg-purple-900/60 text-purple-300'
                  : entry.tag === 'WEAR'   ? 'bg-orange-900/60 text-orange-300'
                  : 'bg-slate-900/60 text-slate-400'
                }`}>{entry.tag}</span>
                <span className="text-slate-200">
                  {entry.message}
                </span>
              </div>
            ))
          )}
        </div>
      </div>
    </section>
  )
}

// ─── Right Panel ──────────────────────────────────────────────────────────────

function RightPanel({ prediction, shap, alert, oobStatus, eccLine, wearLine, simStatus }) {
  const isLive = simStatus === 'live'
  
  const healthScore   = prediction ? Number(prediction.health_score ?? 0)          : null
  const remainingDays = prediction ? Number(prediction.remaining_life_days ?? 0)    : null
  const failureProb   = prediction ? Number(prediction.failure_probability ?? 0)    : null

  const shapFactors = useMemo(() => {
    if (!Array.isArray(shap) || shap.length === 0) return []
    return shap
      .slice(0, 5)
      .map((item) => [item.feature, Math.round(Number(item.impact || 0) * 100)])
  }, [shap])

  const alertLevel  = alert?.level ?? 'INFO'
  const alertColors = ALERT_COLORS[alertLevel] ?? ALERT_COLORS.INFO

  const uartStatus = oobStatus?.uart ?? 'IDLE'
  const bleStatus = oobStatus?.ble ?? '30s'
  const smbusStatus = oobStatus?.smbus ?? 'OK'

  return (
    <aside className="space-y-3 border-l border-[#16233d] bg-[#060b17] p-3">

      {/* AI Prediction Engine — health gauge + core metrics */}
      <div className="relative rounded-md border border-cyan-500/40 bg-[#07182f] p-3">
        {!isLive && (
          <div className="absolute inset-0 z-10 flex items-center justify-center bg-[#07182f]/80 backdrop-blur-[2px]">
            <p className="text-sm font-bold tracking-widest text-cyan-800">NO SIGNAL</p>
          </div>
        )}
        <p className="text-[0.65rem] uppercase tracking-[0.22em] text-cyan-300">
          AI Prediction Engine
        </p>

        {prediction ? (
          <>
            <div className="mt-2 flex flex-col items-center">
              <HealthGauge score={healthScore ?? 0} />
              <p className="mt-1 text-[0.65rem] text-slate-500">Health Score (XGBoost)</p>
            </div>

            {/* Failure probability bar */}
            <div className="mt-3">
              <div className="flex justify-between text-xs mb-1">
                <span className="text-slate-500">Failure probability</span>
                <span className={`font-semibold ${failureProb > 0.5 ? 'text-red-400' : 'text-green-400'}`}>
                  {(failureProb * 100).toFixed(1)}%
                </span>
              </div>
              <div className="h-2 w-full rounded bg-[#14284b]">
                <div
                  className="h-2 rounded transition-all duration-700"
                  style={{
                    width: `${(failureProb * 100).toFixed(1)}%`,
                    backgroundColor: failureProb > 0.7 ? '#ef4444' : failureProb > 0.4 ? '#f97316' : '#22d3ee',
                  }}
                />
              </div>
            </div>

            {/* RUL from LSTM */}
            <div className="mt-3 flex items-end gap-1">
              <p className="text-4xl font-bold text-green-400">
                {remainingDays != null ? remainingDays : '—'}
              </p>
              <p className="mb-1 text-xs text-[#7f97bc]">days remaining (LSTM)</p>
            </div>
          </>
        ) : (
          <div className="mt-4 py-6 text-center text-xs text-slate-600">
            Waiting for ML prediction…<br />
            <span className="text-[0.6rem]">Start the backend and simulation</span>
          </div>
        )}
      </div>

      {/* ECC Rate chart */}
      <div className="rounded-md border border-[#1a2a42] bg-[#0b1221] p-3">
        <p className="mb-1 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">
          ECC Rate — Rolling Window
        </p>
        <MiniLine data={eccLine} color="#22d3ee" />
      </div>

      {/* Wear Level chart */}
      <div className="rounded-md border border-[#1a2a42] bg-[#0b1221] p-3">
        <p className="mb-1 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">
          Wear Level Trend
        </p>
        <MiniLine data={wearLine} color="#eab308" />
      </div>

      {/* SHAP factors */}
      {shapFactors.length > 0 && (
        <div className="rounded-md border border-[#1a2a42] bg-[#0b1221] p-3">
          <p className="mb-2 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">
            SHAP — Top Factors
          </p>
          <div className="space-y-2">
            {shapFactors.map(([label, value]) => (
              <div key={label}>
                <div className="flex justify-between text-xs">
                  <span className="text-slate-400 truncate">{label}</span>
                  <span className="ml-2 shrink-0 text-purple-300">{value}%</span>
                </div>
                <div className="mt-0.5 h-1 rounded bg-[#14284b]">
                  <div
                    className="h-1 rounded bg-purple-400 transition-all duration-700"
                    style={{ width: `${value}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Alert */}
      {alert && (
        <div className="rounded-md border border-[#1a2a42] bg-[#0b1221] p-3">
          <p className="mb-2 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">Alert Protocol</p>
          <div className="grid grid-cols-4 gap-1 text-[0.65rem]">
            {['INFO', 'WARNING', 'CRITICAL', 'FATAL'].map((lvl) => (
              <div
                key={lvl}
                className={`rounded p-1.5 text-center transition-all duration-300 ${
                  alertLevel === lvl ? alertColors.badge : 'border border-[#1a2a42] text-[#5f769d]'
                }`}
              >
                {lvl.slice(0, 4)}
              </div>
            ))}
          </div>
          {alert.message && (
            <p className="mt-2 text-xs text-slate-400">{alert.message}</p>
          )}
          {alert.recommendation && (
            <p className="mt-1 text-[0.65rem] text-[#4a6388]">{alert.recommendation}</p>
          )}
        </div>
      )}

      {/* OOB Channels */}
      <div className="rounded-md border border-[#1a2a42] bg-[#0b1221] p-3">
        <p className="mb-2 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">OOB Channels</p>
        <div className="space-y-2">
          {[['UART Bridge', uartStatus], ['BLE Beacon', bleStatus], ['SMBus / BMC', smbusStatus]].map(([label, status]) => (
            <div key={label} className="flex items-center justify-between rounded bg-[#070d18] px-2 py-2 text-sm">
              <div className="flex items-center gap-2 text-gray-200">
                <span className={`h-2 w-2 rounded-full ${
                  status === 'CRITICAL' || status === 'OVERLOAD' ? 'bg-red-500 shadow-[0_0_10px_1px_rgba(239,68,68,0.7)]'
                  : status === 'ACTIVE' || status === 'ALERT' || status === '10s' || status === '3s' ? 'bg-amber-400 shadow-[0_0_10px_1px_rgba(251,191,36,0.7)]'
                  : 'bg-green-400 shadow-[0_0_10px_1px_rgba(74,222,128,0.7)]'
                }`} />
                <span>{label}</span>
              </div>
              <span className={`text-xs ${
                status === 'CRITICAL' || status === 'OVERLOAD' ? 'text-red-400'
                : status === 'ACTIVE' || status === 'ALERT' || status === '10s' || status === '3s' ? 'text-amber-400'
                : 'text-[#7f97bc]'
              }`}>{status}</span>
            </div>
          ))}
        </div>
      </div>
    </aside>
  )
}

// ─── Main Dashboard ────────────────────────────────────────────────────────────

export default function ReferenceDashboard() {
  const [time, setTime]             = useState(() => new Date())
  const [blocks, setBlocks]         = useState(() => createBlocks())
  const [logs, setLogs]             = useState([])
  const [events, setEvents]         = useState(0)

  // Live ML state
  const [telemetry, setTelemetry]   = useState(null)
  const [prediction, setPrediction] = useState(null)
  const [shap, setShap]             = useState(null)
  const [alert, setAlert]           = useState(null)
  const [oobStatus, setOobStatus]   = useState(null)

  // Chart history — seeded with zeros so charts render immediately
  const [eccLine, setEccLine]   = useState(() => Array.from({ length: 30 }, () => 0))
  const [wearLine, setWearLine] = useState(() => Array.from({ length: 30 }, () => 0))

  // Connection state
  const [backendOk, setBackendOk]           = useState(false)
  const [simStatus, setSimStatus]           = useState('offline')
  const [modelLoaded, setModelLoaded]       = useState(false)
  const [telemetryAgeMs, setTelemetryAgeMs] = useState(null)

  const sseRef = useRef(null)

  // ── Build live architecture tiles ─────────────────────────────────────────
  const architectureData = useMemo(() => {
    const f = (v, digits = 4) => v != null ? Number(v).toFixed(digits) : '—'

    const eccRateStr  = telemetry ? `${f(telemetry.ecc_rate)} rate`           : '—'
    const tempStr     = telemetry ? `${f(telemetry.temperature, 1)}°C`        : '—'
    const wearStr     = telemetry ? `${f(telemetry.wear_level, 1)}%`          : '—'
    const latStr      = telemetry ? `${f(telemetry.latency, 2)} ms`           : '—'
    const eccCnt      = telemetry ? String(telemetry.ecc_count)               : '—'
    const retries     = telemetry ? String(telemetry.retries)                 : '—'
    const failProb    = prediction
      ? `${(Number(prediction.failure_probability) * 100).toFixed(1)}%` : '—'
    const health      = prediction ? String(prediction.health_score ?? '—')   : '—'
    const rul         = prediction ? `RUL ~${prediction.remaining_life_days}d` : '—'
    const shapCount   = shap       ? `${shap.length} features`                : '—'

    return [
      {
        row: 'INPUT',
        items: [
          { title: 'ECC Rate',    value: eccRateStr, hint: 'from Simulink',  live: !!telemetry },
          { title: 'Temperature', value: tempStr,    hint: 'junction temp',  live: !!telemetry },
          { title: 'Retries',     value: retries,    hint: 'read retries',   live: !!telemetry },
          { title: 'ECC Count',   value: eccCnt,     hint: 'cumulative',     live: !!telemetry },
        ],
      },
      {
        row: 'FIRMWARE',
        items: [
          { title: 'Wear Level',    value: wearStr,   hint: 'P/E normalized',  live: !!telemetry },
          { title: 'Latency',       value: latStr,    hint: 'processing ms',   live: !!telemetry },
          { title: 'Adaptive LDPC', value: 'Active',  hint: 'Min-Sum decoder'              },
          { title: 'Bad Block Mgr', value: 'Running', hint: '3-tier lookup'                },
        ],
      },
      {
        row: 'AI ENGINE',
        items: [
          { title: 'Health Score', value: health,    hint: 'XGBoost output', live: !!prediction, highlight: true },
          { title: 'Fail Prob',    value: failProb,  hint: '7-day window',   live: !!prediction },
          { title: 'LSTM / RUL',   value: rul,       hint: 'trajectory',     live: !!prediction },
          { title: 'SHAP',         value: shapCount, hint: 'explainability', live: !!shap },
        ],
      },
      {
        row: 'OOB ALERTS',
        items: [
          { title: 'UART Bridge',  value: 'IDLE',              hint: '115,200 baud'   },
          { title: 'BLE Beacon',   value: '30s',               hint: 'nRF52832'       },
          { title: 'SMBus / BMC',  value: 'OK',                hint: 'IPMI · Redfish' },
          { title: 'Alert Level',  value: alert?.level ?? '—', hint: '4-level protocol', live: !!alert },
        ],
      },
    ]
  }, [telemetry, prediction, shap, alert, simStatus])

  // ── Apply SSE bundle ───────────────────────────────────────────────────────
  const applyBundle = useCallback((bundle) => {
    const tel  = bundle.telemetry  || null
    const pred = bundle.prediction || null
    const alt  = bundle.alert      || null

    if (tel) {
      setTelemetry(tel)
      setEccLine((prev) => [...prev.slice(1), Number(tel.ecc_rate ?? 0)])
      setWearLine((prev) => [...prev.slice(1), Number(tel.wear_level ?? 0)])
    }

    if (pred) setPrediction(pred)
    if (bundle.shap) setShap(bundle.shap)
    if (alt) setAlert(alt)
    if (bundle.simulation_status) setSimStatus(bundle.simulation_status)
    if (bundle.oob_status) setOobStatus(bundle.oob_status)

    // Load real firmware events stream
    if (bundle.events && Array.isArray(bundle.events)) {
      setLogs(bundle.events)
    }

    setEvents((prev) => prev + 1)

    // Compute NAND blocks using real signals instead of completely random
    if (tel) {
      setBlocks(createBlocks(
        Number(tel.bad_block_count || 0),
        Number(tel.journal_fill_pct || 0)
      ))
    }
  }, [])

  // ── SSE connection ─────────────────────────────────────────────────────────
  useEffect(() => {
    function connectSse() {
      if (sseRef.current) { sseRef.current.close(); sseRef.current = null }
      sseRef.current = openSseStream(applyBundle, () => {
        setBackendOk(false)
        setSimStatus('offline')
      })
    }

    async function bootstrap() {
      const [ok, health] = await Promise.all([healthCheck(), getHealthStatus()])
      setBackendOk(ok)
      setModelLoaded(health?.model_loaded ?? false)

      const ageMs = health?.telemetry_age_ms
      setTelemetryAgeMs(typeof ageMs === 'number' ? ageMs : null)

      const src   = health?.telemetry_source
      const ttl   = health?.ingest_ttl_seconds
      const fresh = typeof ttl === 'number' && typeof ageMs === 'number' && ageMs <= ttl * 1000
      setSimStatus(src === 'simulink' && fresh ? 'live' : src === 'simulink' ? 'stale' : 'offline')

      if (ok) connectSse()
    }

    bootstrap()

    const reconnect = setInterval(async () => {
      const ok = await healthCheck()
      setBackendOk(ok)
      if (ok && (!sseRef.current || sseRef.current.readyState === EventSource.CLOSED)) connectSse()
      if (!ok && sseRef.current) { sseRef.current.close(); sseRef.current = null; setSimStatus('offline') }
    }, 8000)

    const clock = setInterval(() => setTime(new Date()), 1000)

    return () => {
      if (sseRef.current) sseRef.current.close()
      clearInterval(reconnect)
      clearInterval(clock)
    }
  }, [applyBundle])

  const alertNum = alert ? (LEVEL_NUM[alert.level] ?? 1) : 0

  // ───────────────────────────────────────────────────────────────────────────

  return (
    <div className="min-h-screen bg-[#030814] text-gray-100">

      {/* Header */}
      <header className="flex flex-wrap items-center justify-between gap-2 border-b border-[#15233d] bg-[#050b17] px-5 py-3">
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="text-2xl font-extrabold tracking-wide text-white">
            <span className="text-cyan-300">NAND</span>GUARDIAN
          </h1>
          <span className="rounded border border-[#1a2a42] bg-[#071022] px-3 py-1 text-xs uppercase tracking-[0.2em] text-[#7f97bc]">
            SSD Simulation
          </span>
          <span className="rounded border border-[#1a2a42] bg-[#071022] px-3 py-1 font-mono text-sm text-[#9bc7ff]">
            {time.toLocaleTimeString('en-GB')}
          </span>
          <span className={`rounded border px-2 py-1 text-xs font-semibold ${
            backendOk
              ? 'border-green-700 bg-green-900/30 text-green-400'
              : 'border-red-900 bg-red-900/20 text-red-400'
          }`}>
            {backendOk ? '● MODEL API' : '○ BACKEND OFFLINE'}
          </span>
          <span className={`rounded border px-2 py-1 text-xs font-semibold ${
            simStatus === 'live'  ? 'border-cyan-700 bg-cyan-900/30 text-cyan-300'
            : simStatus === 'stale' ? 'border-amber-700 bg-amber-900/20 text-amber-400'
            : 'border-slate-700 bg-slate-900/30 text-slate-500'
          }`}>
            {simStatus === 'live' ? '● SIMULINK LIVE' : simStatus === 'stale' ? '◑ SIMULINK STALE' : '○ SIMULINK OFFLINE'}
          </span>
        </div>
        <div className="flex flex-wrap items-center gap-4 text-sm text-[#7f97bc]">
          <span>Drive: <b className="text-white">1</b></span>
          <span>Events: <b className="text-white">{events}</b></span>
          {alertNum > 0 && (
            <span>Alert: <b className={alertNum >= 3 ? 'text-red-400' : 'text-amber-400'}>
              {alert?.level}
            </b></span>
          )}
        </div>
      </header>

      {/* Pipeline banner */}
      <div className="border-b border-[#0e1e35] bg-[#040a17] px-5 py-2">
        <SimulationStatus
          backendConnected={backendOk}
          simulationStatus={simStatus}
          modelLoaded={modelLoaded}
          telemetryAgeMs={telemetryAgeMs}
        />
      </div>

      {/* Main 3-column grid */}
      <div className="grid min-h-[calc(100vh-112px)] grid-cols-1 xl:grid-cols-[220px_1fr_270px]">
        <LeftPanel
          telemetry={simStatus === 'live' ? telemetry : null}
          prediction={simStatus === 'live' ? prediction : null}
          simStatus={simStatus}
        />
        <CenterPanel
          blocks={simStatus === 'live' ? blocks : createBlocks(0, 0)}
          logs={simStatus === 'live' ? logs : []}
          architectureData={architectureData}
          simStatus={simStatus}
        />
        <RightPanel
          prediction={simStatus === 'live' ? prediction : null}
          shap={simStatus === 'live' ? shap : null}
          alert={simStatus === 'live' ? alert : null}
          oobStatus={simStatus === 'live' ? oobStatus : null}
          eccLine={simStatus === 'live' ? eccLine : Array(30).fill(0)}
          wearLine={simStatus === 'live' ? wearLine : Array(30).fill(0)}
          simStatus={simStatus}
        />
      </div>
    </div>
  )
}
