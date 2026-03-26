function statusCode = simulinkPublishStep(distortionEvents, packetErrorRate, retryCount, junctionTempC, stressPercent, processingLatencyMs)
% Use this in a MATLAB Function block (simulation mode).
coder.extrinsic('sendTelemetryToByteForce');
coder.extrinsic('mapHardwareSignalsToByteForce');

signals = struct();
signals.distortion_events = distortionEvents;
signals.packet_error_rate = packetErrorRate;
signals.tx_retry_count = retryCount;
signals.junction_temp_c = junctionTempC;
signals.stress_percent = stressPercent;
signals.processing_latency_ms = processingLatencyMs;

telemetry = mapHardwareSignalsToByteForce(signals);
response = sendTelemetryToByteForce(telemetry, 'http://localhost:8000/api/ingest-telemetry'); %#ok<NASGU>

statusCode = 1;
end
