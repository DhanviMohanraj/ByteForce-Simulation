$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonExe = 'c:/Users/dhanv/OneDrive/Desktop/ByteForce-Simulation/.venv/Scripts/python.exe'
$xgbModelPath = Join-Path $projectRoot 'model/xgboost.pkl'
if (-not (Test-Path $xgbModelPath)) {
    $altXgbPath = Join-Path $projectRoot 'model/xgboost_model.pkl'
    if (Test-Path $altXgbPath) {
        $xgbModelPath = $altXgbPath
    }
}
$lstmModelPath = Join-Path $projectRoot 'model/lstm.h5'
if (-not (Test-Path $lstmModelPath)) {
    $altLstmPath = Join-Path $projectRoot 'model/lstm_model.h5'
    if (Test-Path $altLstmPath) {
        $lstmModelPath = $altLstmPath
    }
}
$featuresPath = Join-Path $projectRoot 'model/features.json'
$simulinkDir  = Join-Path $projectRoot 'simulink'

Write-Host '=================================================================' -ForegroundColor Cyan
Write-Host '  ByteForce — Full System Startup' -ForegroundColor Cyan
Write-Host '  Simulation → ML Backend → Dashboard' -ForegroundColor Cyan
Write-Host '=================================================================' -ForegroundColor Cyan
Write-Host ''

# INGEST_TTL raised to 30s so stale telemetry stays visible between MATLAB steps
$backendCmd  = "Set-Location '$projectRoot'; `$env:MODEL_PATH='$xgbModelPath'; `$env:LSTM_MODEL_PATH='$lstmModelPath'; `$env:FEATURES_PATH='$featuresPath'; `$env:INGEST_TTL_SECONDS='30'; & '$pythonExe' example_backend.py"
$frontendCmd = "Set-Location '$projectRoot'; npm run dev -- --host 0.0.0.0 --port 5173"

# ── Clear conflicting port listeners ─────────────────────────────────────────
foreach ($port in @(8000, 5173)) {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        $conn | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object {
            try { Stop-Process -Id $_ -Force -ErrorAction Stop } catch {}
        }
        Write-Host "  Freed port $port" -ForegroundColor Gray
    }
}

# ── Start backend + frontend ──────────────────────────────────────────────────
Write-Host '[1/2] Starting Flask ML backend on port 8000...' -ForegroundColor Yellow
Start-Process powershell -ArgumentList '-NoExit', '-Command', $backendCmd | Out-Null
Start-Sleep -Seconds 3

Write-Host '[2/2] Starting Vite frontend on port 5173...' -ForegroundColor Yellow
Start-Process powershell -ArgumentList '-NoExit', '-Command', $frontendCmd | Out-Null
Start-Sleep -Seconds 3

# ── Health checks ─────────────────────────────────────────────────────────────
$backendOk  = $false
$frontendOk = $false
$modelOk    = $false

try {
    $health    = Invoke-RestMethod -Uri 'http://localhost:8000/api/health' -TimeoutSec 8
    $backendOk = $health.status -eq 'ok'
    $modelOk   = $health.model_loaded -eq $true
} catch {}

try {
    $statusCode = (Invoke-WebRequest -Uri 'http://localhost:5173' -UseBasicParsing -TimeoutSec 8).StatusCode
    $frontendOk = $statusCode -eq 200
} catch {}

Write-Host ''
Write-Host '=================================================================' -ForegroundColor Yellow
Write-Host '  System Status' -ForegroundColor Yellow
Write-Host '=================================================================' -ForegroundColor Yellow
Write-Host ("  Flask backend:   {0}" -f $(if ($backendOk) { '✓ UP' } else { '✗ DOWN — check the backend window' }))
Write-Host ("  XGBoost model:  {0}" -f $(if ($modelOk)   { '✓ Loaded' } else { '✗ Not loaded' }))
Write-Host ("  React frontend: {0}" -f $(if ($frontendOk) { '✓ UP' } else { '✗ DOWN — check the frontend window' }))
Write-Host ''

Write-Host '  URLs' -ForegroundColor Green
Write-Host '    Dashboard:          http://localhost:5173'
Write-Host '    Backend health:     http://localhost:8000/api/health'
Write-Host '    Simulation status:  http://localhost:8000/api/simulation-status'
Write-Host '    SSE stream:         http://localhost:8000/api/stream'
Write-Host '    Feature vector:     http://localhost:8000/api/feature-vector'
Write-Host ''

Write-Host '=================================================================' -ForegroundColor Magenta
Write-Host '  MATLAB — Simulation Setup' -ForegroundColor Magenta
Write-Host '=================================================================' -ForegroundColor Magenta
Write-Host '  OPTION A: Interactive (Simulink GUI)'
Write-Host "    cd('$($simulinkDir.Replace('\','/'))')"
Write-Host "    run('SSD_Simulation.m')"
Write-Host "    % Click [Run] in Simulink → data streams live to dashboard"
Write-Host ''
Write-Host '  OPTION B: Headless (no Simulink GUI needed)'
Write-Host "    cd('$($simulinkDir.Replace('\','/'))')"
Write-Host "    run('runSimulationAndStream.m')"
Write-Host "    % Script builds model, runs sim, streams all telemetry"
Write-Host ''
Write-Host '  When MATLAB is running, the dashboard banner will show:' -ForegroundColor Cyan
Write-Host '    [MATLAB] → [Flask API] → [XGBoost/LSTM] → [Dashboard]' -ForegroundColor Cyan
Write-Host '  All nodes green = full pipeline live.' -ForegroundColor Cyan
Write-Host ''

