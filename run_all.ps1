$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonExe = 'c:/Users/dhanv/OneDrive/Desktop/ByteForce-Simulation/.venv/Scripts/python.exe'
$modelPath = Join-Path $projectRoot 'model/xgboost_model.pkl'

Write-Host 'Starting ByteForce full system...' -ForegroundColor Cyan

$backendCmd = "Set-Location '$projectRoot'; `$env:MODEL_PATH='$modelPath'; `$env:INGEST_TTL_SECONDS='30'; & '$pythonExe' example_backend.py"
$frontendCmd = "Set-Location '$projectRoot'; npm run dev -- --host 0.0.0.0 --port 5173"

# Clear conflicting listeners
foreach ($port in @(8000, 5173)) {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        $conn | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object {
            try { Stop-Process -Id $_ -Force -ErrorAction Stop } catch {}
        }
    }
}

Start-Process powershell -ArgumentList '-NoExit', '-Command', $backendCmd | Out-Null
Start-Sleep -Seconds 2
Start-Process powershell -ArgumentList '-NoExit', '-Command', $frontendCmd | Out-Null
Start-Sleep -Seconds 3

$backendOk = $false
$frontendOk = $false

try {
    $health = Invoke-RestMethod -Uri 'http://localhost:8000/api/health' -TimeoutSec 5
    $backendOk = $health.status -eq 'ok'
} catch {}

try {
    $statusCode = (Invoke-WebRequest -Uri 'http://localhost:5173' -UseBasicParsing -TimeoutSec 5).StatusCode
    $frontendOk = $statusCode -eq 200
} catch {}

Write-Host ''
Write-Host '=== Status ===' -ForegroundColor Yellow
Write-Host ("Backend:  {0}" -f ($(if ($backendOk) { 'UP' } else { 'DOWN' })))
Write-Host ("Frontend: {0}" -f ($(if ($frontendOk) { 'UP' } else { 'DOWN' })))
Write-Host ''
Write-Host 'Open:' -ForegroundColor Green
Write-Host '  Dashboard:      http://localhost:5173'
Write-Host '  Backend health: http://localhost:8000/api/health'
Write-Host '  Feature vector: http://localhost:8000/api/feature-vector'
Write-Host ''
Write-Host 'MATLAB steps (hardware simulation):' -ForegroundColor Magenta
Write-Host "  cd('$($projectRoot.Replace('\','/'))/simulink')"
Write-Host "  run('SSD_Simulation.m')"
Write-Host '  In Simulink SSD_Pro model, click Run.'
Write-Host ''
Write-Host 'When Simulink is running, /api/health should show telemetry_source = simulink.' -ForegroundColor Cyan
