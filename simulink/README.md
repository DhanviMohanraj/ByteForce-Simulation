# Simulink Integration (Hardware + Software Together)

Put your MATLAB/Simulink bridge code in this folder.

Generated integration files in this folder:

- `mapHardwareSignalsToByteForce.m` → maps hardware-simulation signals to software telemetry schema
- `sendTelemetryToByteForce.m` → posts payload to backend ingestion endpoint
- `simulinkPublishStep.m` → MATLAB Function-block compatible publisher step
- `exampleSimulinkPublisher.m` → runnable script example
- `generateByteForceHardwareModel.m` → auto-generates a complete `.slx` hardware model
- `runByteForceHardwareSoftware.m` → starts the generated model for co-simulation

## Where to place your simulation code

- Keep your `.slx` model files in this folder (or a subfolder), e.g.:
  - `simulink/your_hardware_model.slx`
- Keep MATLAB scripts/functions that publish telemetry here:
  - `simulink/sendTelemetryToByteForce.m`
  - `simulink/exampleSimulinkPublisher.m`

## Backend endpoint to send telemetry

Use:

- `POST http://localhost:8000/api/ingest-telemetry`

Payload should include either your SMART fields or base fields:

- Base fields: `ecc_count`, `ecc_rate`, `retries`, `temperature`, `wear_level`, `latency`
- Optional: `smart_*` fields if you already compute them in Simulink

## Minimal MATLAB usage

```matlab
sample.ecc_count = 42;
sample.ecc_rate = 0.12;
sample.retries = 9;
sample.temperature = 47;
sample.wear_level = 21.4;
sample.latency = 1.32;

sendTelemetryToByteForce(sample);
```

## Direct Simulink mapping workflow

1. In your Simulink model, collect hardware outputs into signals (for example distortion events, packet error rate, retry count, junction temp, stress, processing delay).
2. Call `simulinkPublishStep(...)` from a MATLAB Function block each simulation step.
3. The function maps those signals into the software telemetry schema and posts to backend.

Example call signature:

```matlab
status = simulinkPublishStep(distortionEvents, packetErrorRate, retryCount, junctionTempC, stressPercent, processingLatencyMs);
```

## Generate full Simulink model automatically

In MATLAB Command Window (from this folder):

```matlab
generateByteForceHardwareModel();
runByteForceHardwareSoftware();
```

This creates `ByteForceHardwareModel.slx`, opens it, and starts simulation.

## Run both views together

1. Start backend: `python example_backend.py`
2. Start frontend: `npm run dev`
3. Run your Simulink model so it posts to `/api/ingest-telemetry`
4. Open software dashboard: `http://localhost:5173`
5. Keep Simulink window open to see hardware model in parallel

## Verify ingestion

- `http://localhost:8000/api/health` should show `telemetry_source: "simulink"` while data is arriving.
- `http://localhost:8000/api/feature-vector` shows exact derived inputs used by the model.
