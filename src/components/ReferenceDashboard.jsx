import { useEffect, useMemo, useState } from 'react'

const DRIVE_IDS = ['SSD-A1', 'SSD-B2', 'SSD-C3', 'SSD-D4']

const architectureRows = [
  {
    row: 'INPUT',
    items: [
      { title: 'SMART Telemetry', value: '5.9 ecc/pg', hint: '20+ attributes' },
      { title: 'NAND Page Reads', value: '1121 IOPS', hint: 'ECC / page' },
      { title: 'Host Interface', value: '3 queue', hint: 'NVMe queue' },
      { title: 'Control Flags', value: 'NORMAL', hint: 'state machine' },
    ],
  },
  {
    row: 'FIRMWARE',
    items: [
      { title: 'Bad Block Mgr', value: '14 bad', hint: '3-tier lookup' },
      { title: 'Adaptive LDPC', value: 'Stage 1', hint: 'Min-Sum decoder' },
      { title: 'QMC Optimizer', value: '69% saved', hint: 'logic minimize' },
      { title: 'Proactive Retire', value: 'WATCHING', hint: 'ECC accel watch' },
    ],
  },
  {
    row: 'AI ENGINE',
    items: [
      { title: 'Feature Engineering', value: '158 signals', hint: '150+ signals' },
      { title: 'XGBoost', value: '69% fail', hint: 'snapshot model' },
      { title: 'LSTM', value: 'RUL ~309.8d', hint: 'trajectory 30d' },
      { title: 'Ensemble + SHAP', value: '309.8d ±46d', hint: 'RUL estimate', highlight: true },
    ],
  },
  {
    row: 'FLEET INTEL',
    items: [
      { title: 'Pattern Library', value: '15 sigs', hint: 'failure sigs' },
      { title: 'Confidence Score', value: '77%', hint: 'fleet calibrated' },
      { title: 'Maintenance Opt.', value: 'Day 216', hint: '3-date window' },
      { title: 'Federated Learn', value: '8 fleet', hint: 'privacy-safe' },
    ],
  },
  {
    row: 'OOB ALERTS',
    items: [
      { title: 'UART Bridge', value: 'IDLE', hint: '115,200 baud' },
      { title: 'BLE Beacon', value: '30s', hint: 'nRF52832' },
      { title: 'SMBus / BMC', value: 'OK', hint: 'IPMI · Redfish' },
      { title: 'Alert Level', value: 'INFO', hint: '4-level protocol' },
    ],
  },
]

const eventTemplates = [
  'BBM Hash lookup: block 77227 → GOOD in <1µs',
  'Drive SSD-A1 — wear 12.9% · temp 50°C · ECC 5.7/pg',
  'XGBoost snapshot — P(fail 7d) = 30.5%',
  'B-Tree index rebuilt — 14 bad blocks mapped across 4 zones',
  'Fleet reference aligned — confidence score 77%',
  'SMBus register 0x01 updated by controller',
  'BLE beacon heartbeat — healthy',
]

function createDrives() {
  return DRIVE_IDS.map((id, index) => {
    const wear = 6 + Math.random() * 70
    const temp = 40 + Math.random() * 26
    const ecc = 2 + Math.random() * 35
    const pe = 200 + Math.random() * 5200
    const failing = index === 1

    return {
      id,
      wear,
      temp,
      ecc,
      pe,
      failing,
      active: index === 0,
    }
  })
}

function createBlocks() {
  const cells = []
  for (let i = 0; i < 250; i += 1) {
    const roll = Math.random()
    let state = 'good'
    if (roll > 0.93) state = 'active'
    if (roll > 0.965) state = 'writing'
    if (roll > 0.985) state = 'erasing'
    if (roll > 0.995) state = 'bad'
    cells.push({ id: i, state })
  }
  return cells
}

function createLinePoints(data) {
  const max = Math.max(...data)
  const min = Math.min(...data)
  const span = Math.max(max - min, 1)

  return data
    .map((value, index) => {
      const x = (index / (data.length - 1)) * 100
      const y = 100 - ((value - min) / span) * 80 - 10
      return `${x},${y}`
    })
    .join(' ')
}

function MiniLine({ data, color }) {
  const points = useMemo(() => createLinePoints(data), [data])

  return (
    <svg viewBox="0 0 100 100" className="h-16 w-full">
      <polyline fill="none" stroke={color} strokeWidth="2.5" points={points} />
    </svg>
  )
}

function MetricTile({ title, value, hint, highlight }) {
  return (
    <div className={`rounded-md border p-3 ${highlight ? 'border-cyan-400/70 bg-cyan-500/5' : 'border-[#1a2a42] bg-[#0b1221]'}`}>
      <p className="text-[0.65rem] uppercase tracking-[0.15em] text-gray-400">{title}</p>
      <p className="mt-1 text-base font-semibold text-cyan-300">{value}</p>
      <p className="text-[0.65rem] text-[#4a6388]">{hint}</p>
    </div>
  )
}

function LeftPanel({ drives }) {
  const stats = {
    badBlocks: 14,
    hashHits: 4606,
    lookups: 294,
    journal: 112,
    nandUsed: 0.011,
    stage: 1,
    iterations: 10,
    corrections: 5.9,
    ber: 0.00059,
    recovery: 99.8,
  }

  return (
    <aside className="space-y-3 border-r border-[#16233d] bg-[#060b17] p-3">
      <p className="text-[0.65rem] uppercase tracking-[0.24em] text-[#4a6388]">Fleet Monitor</p>
      {drives.map((drive) => (
        <div
          key={drive.id}
          className={`rounded-md border p-3 ${drive.active ? 'border-cyan-400/80 bg-[#0d1527]' : 'border-[#1a2a42] bg-[#0b1221]'}`}
        >
          <div className="flex items-center justify-between">
            <p className="font-semibold text-gray-100">{drive.id}</p>
            {drive.failing && <span className="text-[0.65rem] font-semibold text-red-400">▲ FAILING</span>}
          </div>
          <div className="mt-2 space-y-1 text-xs text-[#7f97bc]">
            <div className="flex justify-between"><span>Wear</span><span className="text-green-400">{drive.wear.toFixed(1)}%</span></div>
            <div className="flex justify-between"><span>Temp</span><span>{drive.temp.toFixed(1)}°C</span></div>
            <div className="flex justify-between"><span>ECC/pg</span><span>{drive.ecc.toFixed(1)}</span></div>
            <div className="flex justify-between"><span>P/E</span><span>{drive.pe.toFixed(1)}</span></div>
          </div>
        </div>
      ))}

      <section className="rounded-md border border-[#1a2a42] bg-[#0b1221] p-3 text-xs text-[#7f97bc]">
        <p className="mb-2 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">Bad Block Table</p>
        <div className="space-y-1">
          <div className="flex justify-between"><span>Bad blocks</span><span className="text-red-400">{stats.badBlocks}</span></div>
          <div className="flex justify-between"><span>DRAM hash hits</span><span className="text-green-400">{stats.hashHits}</span></div>
          <div className="flex justify-between"><span>B-Tree lookups</span><span>{stats.lookups}</span></div>
          <div className="flex justify-between"><span>Journal entries</span><span>{stats.journal}</span></div>
          <div className="flex justify-between"><span>% NAND used</span><span>{stats.nandUsed}%</span></div>
        </div>
      </section>

      <section className="rounded-md border border-[#1a2a42] bg-[#0b1221] p-3 text-xs text-[#7f97bc]">
        <p className="mb-2 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">LDPC Decoder</p>
        <div className="space-y-1">
          <div className="flex justify-between"><span>Wear stage</span><span className="text-cyan-400">Stage {stats.stage}</span></div>
          <div className="flex justify-between"><span>Avg iterations</span><span>{stats.iterations}</span></div>
          <div className="flex justify-between"><span>Corrections/pg</span><span>{stats.corrections}</span></div>
          <div className="flex justify-between"><span>BER</span><span>{stats.ber}</span></div>
          <div className="flex justify-between"><span>Recovery rate</span><span className="text-green-400">{stats.recovery}%</span></div>
        </div>
      </section>
    </aside>
  )
}

function CenterPanel({ blocks, logs }) {
  return (
    <section className="space-y-4 p-4">
      <div className="rounded-lg border border-[#1a2a42] bg-[#0b1221] p-4">
        <p className="mb-3 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">System Architecture — Live Flow</p>
        <div className="space-y-3">
          {architectureRows.map((group) => (
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

      <div className="rounded-lg border border-[#1a2a42] bg-[#0b1221] p-4">
        <div className="mb-2 flex items-center justify-between">
          <p className="text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">NAND Flash Map — Block Level</p>
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
              className={`h-8 rounded-sm ${
                cell.state === 'good'
                  ? 'bg-green-950/70'
                  : cell.state === 'active'
                    ? 'bg-cyan-900/70'
                    : cell.state === 'writing'
                      ? 'bg-lime-700/70'
                      : cell.state === 'erasing'
                        ? 'bg-amber-700/60'
                        : 'bg-red-800/70'
              }`}
            />
          ))}
        </div>
      </div>

      <div className="rounded-lg border border-[#1a2a42] bg-[#0b1221] p-4">
        <div className="mb-2 flex items-center justify-between">
          <p className="text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">System Event Log</p>
          <button className="text-xs text-[#4a6388] hover:text-cyan-300">clear</button>
        </div>
        <div className="max-h-44 space-y-1 overflow-auto pr-1 text-sm text-[#7f97bc]">
          {logs.map((entry) => (
            <div key={entry.id} className="rounded border border-transparent bg-[#0a1223] px-3 py-1 hover:border-[#1a2a42]">
              <span className="mr-2 text-[#4a6388]">{entry.time}</span>
              <span>{entry.message}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

function RightPanel({ predictionDays, confidence, eccLine, wearLine }) {
  return (
    <aside className="space-y-3 border-l border-[#16233d] bg-[#060b17] p-3">
      <div className="rounded-md border border-[#1a2a42] bg-[#0b1221] p-3">
        <p className="mb-2 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">ECC Corrections — 30s Window</p>
        <MiniLine data={eccLine} color="#22d3ee" />
      </div>

      <div className="rounded-md border border-[#1a2a42] bg-[#0b1221] p-3">
        <p className="mb-2 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">Wear Level Trend</p>
        <MiniLine data={wearLine} color="#eab308" />
      </div>

      <div className="rounded-md border border-cyan-500/40 bg-[#07182f] p-3">
        <p className="text-[0.65rem] uppercase tracking-[0.22em] text-cyan-300">AI Prediction Engine</p>
        <p className="mt-2 text-5xl font-bold text-green-400">{predictionDays.toFixed(1)}</p>
        <p className="text-sm text-[#7f97bc]">days remaining (est.)</p>

        <div className="mt-2 text-sm text-[#7f97bc]">Confidence: <span className="font-semibold text-cyan-300">{confidence}%</span></div>
        <div className="mt-2 h-1.5 rounded bg-[#14284b]">
          <div className="h-1.5 rounded bg-cyan-400" style={{ width: `${confidence}%` }} />
        </div>

        <div className="mt-4 space-y-2 text-sm text-[#7f97bc]">
          <p className="text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">SHAP — Top Factors</p>
          {[
            ['ECC acceleration', 30],
            ['Wear level', 29],
            ['Temperature avg', 24],
          ].map(([label, value]) => (
            <div key={label}>
              <div className="flex justify-between text-xs">
                <span>{label}</span>
                <span className="text-purple-300">{value}%</span>
              </div>
              <div className="mt-1 h-1 rounded bg-[#14284b]">
                <div className="h-1 rounded bg-purple-400" style={{ width: `${value}%` }} />
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="rounded-md border border-[#1a2a42] bg-[#0b1221] p-3">
        <p className="mb-2 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">OOB Channels</p>
        <div className="space-y-2">
          {[
            ['UART Bridge', 'STANDBY'],
            ['BLE Beacon', '30s'],
            ['SMBus / BMC', 'ACTIVE'],
          ].map(([label, status]) => (
            <div key={label} className="flex items-center justify-between rounded bg-[#070d18] px-2 py-2 text-sm">
              <div className="flex items-center gap-2 text-gray-200">
                <span className="h-2 w-2 rounded-full bg-green-400 shadow-[0_0_10px_1px_rgba(74,222,128,0.7)]" />
                <span>{label}</span>
              </div>
              <span className="text-xs text-[#7f97bc]">{status}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="rounded-md border border-[#1a2a42] bg-[#0b1221] p-3">
        <p className="mb-2 text-[0.65rem] uppercase tracking-[0.22em] text-[#4a6388]">Alert Protocol</p>
        <div className="grid grid-cols-4 gap-1 text-[0.65rem] text-[#5f769d]">
          <div className="rounded bg-blue-400/80 p-2 text-center text-blue-950">INFO</div>
          <div className="rounded border border-[#1a2a42] p-2 text-center">WARN</div>
          <div className="rounded border border-[#1a2a42] p-2 text-center">CRIT</div>
          <div className="rounded border border-[#1a2a42] p-2 text-center">FATAL</div>
        </div>
      </div>
    </aside>
  )
}

export default function ReferenceDashboard() {
  const [time, setTime] = useState(() => new Date())
  const [drives, setDrives] = useState(() => createDrives())
  const [blocks, setBlocks] = useState(() => createBlocks())
  const [logs, setLogs] = useState(() => [])
  const [events, setEvents] = useState(26)
  const [alerts, setAlerts] = useState(1)
  const [predictionDays, setPredictionDays] = useState(309.8)
  const [confidence, setConfidence] = useState(77)
  const [eccLine, setEccLine] = useState(() => Array.from({ length: 30 }, (_, i) => 20 + i * 1.2 + Math.random() * 8))
  const [wearLine, setWearLine] = useState(() => Array.from({ length: 30 }, (_, i) => 8 + i * 0.9 + Math.random() * 2))

  useEffect(() => {
    const clockTimer = setInterval(() => setTime(new Date()), 1000)

    const metricTimer = setInterval(() => {
      setDrives((prev) => prev.map((drive, idx) => ({
        ...drive,
        wear: Math.max(1, drive.wear + (Math.random() - 0.45) * 0.8),
        temp: Math.max(25, drive.temp + (Math.random() - 0.48) * 0.8),
        ecc: Math.max(0.5, drive.ecc + (Math.random() - 0.45) * 1.2),
        active: idx === Math.floor(Math.random() * prev.length),
      })))

      setPredictionDays((prev) => Math.max(70, prev + (Math.random() - 0.5) * 2.8))
      setConfidence((prev) => Math.min(95, Math.max(62, prev + (Math.random() - 0.5) * 2)))
      setEvents((prev) => prev + (Math.random() > 0.62 ? 1 : 0))
      setAlerts((prev) => (Math.random() > 0.9 ? Math.min(prev + 1, 4) : Math.max(prev - 1, 1)))

      setEccLine((prev) => [...prev.slice(1), prev[prev.length - 1] + (Math.random() - 0.3) * 4])
      setWearLine((prev) => [...prev.slice(1), prev[prev.length - 1] + Math.random() * 0.9])

      setBlocks((prev) => prev.map((cell) => {
        if (Math.random() > 0.985) {
          const states = ['good', 'active', 'writing', 'erasing', 'bad']
          return { ...cell, state: states[Math.floor(Math.random() * states.length)] }
        }
        return cell
      }))

      setLogs((prev) => {
        const stamp = new Date().toLocaleTimeString('en-GB', { hour12: false })
        const next = {
          id: `${Date.now()}-${Math.random()}`,
          time: stamp,
          message: eventTemplates[Math.floor(Math.random() * eventTemplates.length)],
        }
        return [next, ...prev].slice(0, 12)
      })
    }, 2500)

    return () => {
      clearInterval(clockTimer)
      clearInterval(metricTimer)
    }
  }, [])

  return (
    <div className="min-h-screen bg-[#030814] text-gray-100">
      <header className="flex items-center justify-between border-b border-[#15233d] bg-[#050b17] px-5 py-3">
        <div className="flex items-center gap-4">
          <h1 className="text-2xl font-extrabold tracking-wide text-white"><span className="text-cyan-300">NAND</span>GUARDIAN</h1>
          <span className="rounded border border-[#1a2a42] bg-[#071022] px-3 py-1 text-xs uppercase tracking-[0.2em] text-[#7f97bc]">SSD Simulation</span>
          <span className="rounded border border-[#1a2a42] bg-[#071022] px-3 py-1 font-mono text-sm text-[#9bc7ff]">{time.toLocaleTimeString('en-GB')}</span>
          <span className="flex items-center gap-2 text-sm text-green-400"><span className="h-2 w-2 rounded-full bg-green-400" />LIVE</span>
        </div>
        <div className="flex items-center gap-4 text-sm text-[#7f97bc]">
          <span>Drives: <b className="text-white">4</b></span>
          <span>Events: <b className="text-white">{events}</b></span>
          <span>Alerts: <b className="text-red-400">{alerts}</b></span>
          <button className="rounded bg-cyan-400 px-5 py-2 font-semibold text-[#082035]">▶ START</button>
        </div>
      </header>

      <div className="grid min-h-[calc(100vh-72px)] grid-cols-1 xl:grid-cols-[220px_1fr_270px]">
        <LeftPanel drives={drives} />
        <CenterPanel blocks={blocks} logs={logs} />
        <RightPanel predictionDays={predictionDays} confidence={confidence} eccLine={eccLine} wearLine={wearLine} />
      </div>
    </div>
  )
}
