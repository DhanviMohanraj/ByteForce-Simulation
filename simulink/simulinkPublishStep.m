function statusCode = simulinkPublishStep(distortionEvents, packetErrorRate, retryCount, junctionTempC, stressPercent, processingLatencyMs)
% Works for interpreted MATLAB Fcn block and MATLAB Function simulation mode.
if ~isempty(coder.target)
	coder.extrinsic('sendTelemetryToByteForce');
	coder.extrinsic('mapHardwareSignalsToByteForce');
end

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
