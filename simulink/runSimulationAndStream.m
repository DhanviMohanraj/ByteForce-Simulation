%% =========================================================================
%  runSimulationAndStream.m
%  Standalone runner: build SSD model → run sim → stream telemetry to Flask
%
%  HOW TO USE (no Simulink GUI needed):
%    1. Start Flask backend:  python example_backend.py
%    2. cd to this folder in MATLAB or add it to path
%    3. run('runSimulationAndStream.m')
%
%  The script:
%    - Checks the Flask backend is reachable before starting
%    - Runs SSD_Simulation.m to (re)build the Simulink model
%    - Calls sim() to execute it (non-interactively)
%    - Streams the 6 telemetry signals logged during the sim
%    - Falls back gracefully if the backend is offline
% =========================================================================

clc;

BACKEND_URL  = 'http://localhost:8000';
INGEST_URL   = [BACKEND_URL '/api/ingest-telemetry'];
HEALTH_URL   = [BACKEND_URL '/api/health'];
SIM_TIME_S   = 200;   % must match p.sim_time in SSD_Simulation.m

fprintf('=================================================================\n');
fprintf('  ByteForce — Simulation + Stream Runner\n');
fprintf('=================================================================\n\n');

%% -------------------------------------------------------------------------
%  1. Verify backend is reachable
% -------------------------------------------------------------------------
fprintf('[1/4] Checking Flask backend at %s ...\n', BACKEND_URL);
backendOk = false;
try
    opts = weboptions('Timeout', 5);
    resp = webread(HEALTH_URL, opts);
    if isfield(resp, 'status') && strcmp(resp.status, 'ok')
        backendOk = true;
        fprintf('      ✓ Backend online (model_loaded=%d, features_loaded=%d)\n', ...
            resp.model_loaded, resp.features_loaded);
    end
catch ME
    fprintf('      ✗ Backend unreachable: %s\n', ME.message);
    fprintf('        → Start it with:  python example_backend.py\n\n');
end

if ~backendOk
    warning('Backend is offline. Simulation will run but NO telemetry will be sent.');
end

%% -------------------------------------------------------------------------
%  2. Build the Simulink model (runs SSD_Simulation.m)
% -------------------------------------------------------------------------
fprintf('\n[2/4] Building Simulink model ...\n');

% Locate SSD_Simulation.m relative to this script
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir)
    thisDir = pwd;
end

simScript = fullfile(thisDir, 'SSD_Simulation.m');
if ~isfile(simScript)
    error('Cannot find SSD_Simulation.m in: %s', thisDir);
end

% Run SSD_Simulation.m which builds SSD_Pro.slx
run(simScript);
fprintf('      ✓ Model SSD_Pro built successfully\n');

%% -------------------------------------------------------------------------
%  3. Run simulation (non-interactively)
% -------------------------------------------------------------------------
mdl = 'SSD_Pro';
fprintf('\n[3/4] Running simulation (StopTime=%ds) ...\n', SIM_TIME_S);

set_param(mdl, 'StopTime', num2str(SIM_TIME_S));

tic;
simOut = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
elapsed = toc;
fprintf('      ✓ Simulation finished in %.1f s\n', elapsed);

%% -------------------------------------------------------------------------
%  4. Extract logged signals and stream to backend
% -------------------------------------------------------------------------
fprintf('\n[4/4] Streaming telemetry to backend ...\n');

if ~backendOk
    fprintf('      ⚠ Backend offline — skipping stream step.\n');
    fprintf('=================================================================\n');
    fprintf('  Done. Re-run after starting the backend to stream data.\n');
    fprintf('=================================================================\n');
    return;
end

% Pull the logged dataset from sim output
try
    logsout = simOut.get('logsout');
catch
    logsout = [];
end

if isempty(logsout)
    fprintf('      ⚠ No logsout found — streaming synthetic snapshots instead.\n');
    _streamSyntheticSnapshots(INGEST_URL, SIM_TIME_S);
else
    _streamFromLogsout(logsout, INGEST_URL);
end

fprintf('\n=================================================================\n');
fprintf('  Stream complete. Open http://localhost:5173 to see the dashboard.\n');
fprintf('=================================================================\n');


%% =========================================================================
%  LOCAL HELPERS
% =========================================================================

function _streamFromLogsout(logsout, ingestUrl)
% Iterate over logsout signals, build telemetry structs, POST them.
nSamples = 0;
try
    % Try to get bridge signals by name
    sigNames = logsout.getElementNames();

    % Build a time-indexed table of signal values
    timeVec = [];
    sigData = struct();

    for k = 1:numel(sigNames)
        elem = logsout.getElement(sigNames{k});
        tv   = elem.Values.Time;
        vals = squeeze(elem.Values.Data);
        if isempty(timeVec)
            timeVec = tv;
        end
        sigData.(sigNames{k}) = vals;
    end

    if isempty(timeVec)
        fprintf('      ⚠ No time vector found in logsout.\n');
        return;
    end

    fprintf('      Found %d logged signals over %d time steps.\n', ...
        numel(sigNames), numel(timeVec));

    opts = weboptions('MediaType', 'application/json', 'Timeout', 3);
    for t = 1:numel(timeVec)
        tel = struct();
        tel.timestamp = sprintf('%sZ', ...
            datestr(now('utc') - seconds(numel(timeVec)-t)*0.1, ...
            'yyyy-mm-ddTHH:MM:SS.FFF'));

        % Map any logged bridge signals we recognise
        fields = fieldnames(sigData);
        for f = 1:numel(fields)
            fname = fields{f};
            val   = sigData.(fname);
            if numel(val) >= t
                tel.(lower(fname)) = double(val(t));
            end
        end

        try
            webwrite(ingestUrl, tel, opts);
            nSamples = nSamples + 1;
        catch
            % Ignore individual failed POSTs
        end

        % Throttle stream to ~20 samples/s so backend can keep up
        pause(0.05);
    end
catch ME
    fprintf('      ⚠ Error reading logsout: %s\n', ME.message);
end
fprintf('      ✓ Streamed %d telemetry samples.\n', nSamples);
end


function _streamSyntheticSnapshots(ingestUrl, simTimeSecs)
% Fallback: generate plausible time-series snapshots without logsout.
fprintf('      Generating synthetic snapshots from simulation parameters...\n');

nSteps   = min(simTimeSecs * 2, 400);   % ~2 samples/s
opts     = weboptions('MediaType', 'application/json', 'Timeout', 3);
maxPE    = 3000;
nSamples = 0;

for i = 1:nSteps
    t          = (i / nSteps) * simTimeSecs;
    peCount    = min(t * 15, maxPE);
    rber       = 0.0001 + 0.0003 * peCount / 1000;
    wearLevel  = min(100 * peCount / maxPE, 100);
    retries    = round(max(0, 3 * (rber > 0.02) + 0.35 * (10 + 90*rber/0.02) + abs(randn)*2));
    tempC      = min(95, 30 + 0.004*peCount + 18*rber + 0.01*retries);
    latencyMs  = min(20, 0.35 + 0.025*(10*rber/0.0001) + 0.01*retries + 4*rber);
    eccCount   = round(max(0, 0.25*512*rber + 0.02*peCount + 4*abs(randn)));

    tel = struct();
    tel.ecc_count   = eccCount;
    tel.ecc_rate    = min(1, 4*rber + 0.0015*retries);
    tel.retries     = retries;
    tel.temperature = tempC;
    tel.wear_level  = wearLevel;
    tel.latency     = latencyMs;
    tel.smart_5_raw   = eccCount;
    tel.smart_187_raw = retries;
    tel.smart_197_raw = rber * 1000;
    tel.smart_198_raw = latencyMs * 100;
    tel.timestamp   = datestr(now, 'yyyy-mm-ddTHH:MM:SS.FFFZ');

    try
        webwrite(ingestUrl, tel, opts);
        nSamples = nSamples + 1;
    catch
        % silent fail
    end
    pause(0.05);
end

fprintf('      ✓ Streamed %d synthetic samples.\n', nSamples);
end
