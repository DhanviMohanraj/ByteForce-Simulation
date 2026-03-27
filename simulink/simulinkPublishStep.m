function statusCode = simulinkPublishStep( ...
    distortionEvents, packetErrorRate, retryCount, junctionTempC, stressPercent, processingLatencyMs, ...
    badBlockCount, journalFillPct, uberCount, retirementStage, eventCode)
% MATLAB Fcn block entry-point — called every simulation timestep.
% FAULT-TOLERANT: never crashes the simulation. Returns 1=success, 0=offline.
%
% Rate-limited to POST at most once every 0.5 s of real-time clock so the
% backend is not flooded when the simulation runs at a fast fixed-step rate.
%
% Parameters (11 total — expanded from original 6):
%   Original 6:
%     distortionEvents     - ecc_count (bit_errors + pe_count derived)
%     packetErrorRate      - ecc_rate  (RBER + retry pressure, 0-1)
%     retryCount           - retries   (read retry count, 0-250)
%     junctionTempC        - temperature (RC-filtered thermal model, °C)
%     stressPercent        - wear_level  (P/E normalized, 0-100%)
%     processingLatencyMs  - latency     (ms)
%   New 5 (real BBM/Health/Event signals):
%     badBlockCount        - bad_block_count   (BBM/dram_cnt, SMART 5)
%     journalFillPct       - journal_fill_pct  (BBM/journal_pct, 0-100)
%     uberCount            - uber_count        (Health_Mon/uber_cnt, SMART 187)
%     retirementStage      - retirement_stage  (Retire/ret_stage, 0-3)
%     eventCode            - event_code        (computeEventCode.m, 0-6)
%
% Returns: 1 = published, 0 = skipped (rate-limit) or backend offline.

if ~isempty(coder.target)
    coder.extrinsic('sendTelemetryToByteForce');
    coder.extrinsic('mapHardwareSignalsToByteForce');
    coder.extrinsic('tic');
    coder.extrinsic('toc');
end

persistent lastPublishTic;
PUBLISH_INTERVAL_S = 0.5;   % real-time seconds between HTTP POSTs

statusCode = 0;
try
    % --- Rate gate -------------------------------------------
    nowTic = tic;
    if ~isempty(lastPublishTic)
        elapsed = toc(lastPublishTic);
        if elapsed < PUBLISH_INTERVAL_S
            statusCode = 0;   % skip this step, too soon
            return;
        end
    end
    lastPublishTic = nowTic;

    % --- Build telemetry struct ------------------------------
    signals = struct();
    % Original 6
    signals.distortion_events     = distortionEvents;
    signals.packet_error_rate     = packetErrorRate;
    signals.tx_retry_count        = retryCount;
    signals.junction_temp_c       = junctionTempC;   % now RC-filtered
    signals.stress_percent        = stressPercent;
    signals.processing_latency_ms = processingLatencyMs;
    % New 5 — real simulation signals
    signals.bad_block_count       = badBlockCount;
    signals.journal_fill_pct      = journalFillPct;
    signals.uber_count            = uberCount;
    signals.retirement_stage      = retirementStage;
    signals.event_code            = eventCode;

    telemetry = mapHardwareSignalsToByteForce(signals);
    response  = sendTelemetryToByteForce(telemetry, 'http://localhost:8000/api/ingest-telemetry'); %#ok<NASGU>
    statusCode = 1;
catch
    statusCode = 0;
end
end
