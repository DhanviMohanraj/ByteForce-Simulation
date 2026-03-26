% Example MATLAB loop to simulate a Simulink hardware model publisher.
% Replace these synthetic hardware signals with your Simulink outputs.

endpoint = 'http://localhost:8000/api/ingest-telemetry';

for k = 1:500
    hardwareSignals.distortion_events = randi([0, 120]);
    hardwareSignals.packet_error_rate = rand() * 0.4;
    hardwareSignals.tx_retry_count = randi([0, 180]);
    hardwareSignals.junction_temp_c = 35 + rand() * 20;
    hardwareSignals.stress_percent = 5 + rand() * 70;
    hardwareSignals.processing_latency_ms = 0.2 + rand() * 3.0;

    sample = mapHardwareSignalsToByteForce(hardwareSignals);

    response = sendTelemetryToByteForce(sample, endpoint); %#ok<NASGU>
    pause(0.5);
end
