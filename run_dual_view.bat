@echo off
setlocal

REM Run Software Dashboard + Backend for Simulink hardware co-simulation
set ROOT=%~dp0
set PY_EXE=c:/Users/dhanv/OneDrive/Desktop/ByteForce-Simulation/.venv/Scripts/python.exe
set MODEL_PATH=%ROOT%model\xgboost.pkl
if not exist "%MODEL_PATH%" set MODEL_PATH=%ROOT%model\xgboost_model.pkl
set LSTM_MODEL_PATH=%ROOT%model\lstm.h5
if not exist "%LSTM_MODEL_PATH%" set LSTM_MODEL_PATH=%ROOT%model\lstm_model.h5
set FEATURES_PATH=%ROOT%model\features.json

echo Starting ByteForce backend...
start "ByteForce Backend" cmd /k "cd /d %ROOT% && set MODEL_PATH=%MODEL_PATH% && set LSTM_MODEL_PATH=%LSTM_MODEL_PATH% && set FEATURES_PATH=%FEATURES_PATH% && %PY_EXE% example_backend.py"

timeout /t 2 >nul

echo Starting ByteForce frontend...
start "ByteForce Frontend" cmd /k "cd /d %ROOT% && npm run dev -- --host 0.0.0.0 --port 5173"

timeout /t 2 >nul

echo Opening dashboard and backend monitor endpoints...
start "" http://localhost:5173/
start "" http://localhost:8000/api/health
start "" http://localhost:8000/api/feature-vector

echo.
echo Software side is running.
echo Now run your Simulink model publisher to POST telemetry to:
echo   http://localhost:8000/api/ingest-telemetry

echo.
echo Keep Simulink window open alongside the browser to view hardware + software together.
endlocal
