function response = sendTelemetryToByteForce(telemetry, endpoint)
% Send one telemetry sample from MATLAB/Simulink to ByteForce backend.
% FAULT-TOLERANT: if the backend is offline, logs a one-time warning and
% returns 0 — the simulation is NEVER stopped due to a connection error.
%
% telemetry: struct with fields:
%   ecc_count, ecc_rate, retries, temperature, wear_level, latency
% endpoint: optional, defaults to local ingest endpoint

persistent backendOfflineWarned;

if nargin < 2 || isempty(endpoint)
    endpoint = 'http://localhost:8000/api/ingest-telemetry';
end

if ~isstruct(telemetry)
    response = 0;
    return;
end

if ~isfield(telemetry, 'timestamp')
    telemetry.timestamp = string(datetime('now', 'TimeZone', 'UTC', ...
        'Format', "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

try
    opts = weboptions('MediaType', 'application/json', 'Timeout', 3);
    response = webwrite(endpoint, telemetry, opts);
    % Reset warning flag if connection succeeds
    backendOfflineWarned = false;
catch ME
    % Backend is offline — suppress crash, show one-time warning
    if isempty(backendOfflineWarned) || ~backendOfflineWarned
        fprintf('[ByteForce Bridge] Backend unreachable (%s).\n', endpoint);
        fprintf('  Simulation continues with data logged to workspace only.\n');
        fprintf('  To send live data: python example_backend.py\n\n');
        backendOfflineWarned = true;
    end
    response = 0;
end
end
