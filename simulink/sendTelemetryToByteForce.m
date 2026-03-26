function response = sendTelemetryToByteForce(telemetry, endpoint)
% Send one telemetry sample from MATLAB/Simulink to ByteForce backend.
%
% telemetry: struct with fields such as:
%   ecc_count, ecc_rate, retries, temperature, wear_level, latency
% endpoint: optional, defaults to local ingest endpoint
%
% Example:
%   sample.ecc_count = 42;
%   sample.ecc_rate = 0.12;
%   sample.retries = 9;
%   sample.temperature = 47;
%   sample.wear_level = 21.4;
%   sample.latency = 1.32;
%   response = sendTelemetryToByteForce(sample);

if nargin < 2 || isempty(endpoint)
    endpoint = 'http://localhost:8000/api/ingest-telemetry';
end

if ~isstruct(telemetry)
    error('telemetry must be a struct');
end

if ~isfield(telemetry, 'timestamp')
    telemetry.timestamp = string(datetime('now', 'TimeZone', 'UTC', 'Format', "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

opts = weboptions('MediaType', 'application/json', 'Timeout', 5);
response = webwrite(endpoint, telemetry, opts);
end
