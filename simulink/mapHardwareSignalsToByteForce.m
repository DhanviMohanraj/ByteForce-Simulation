function telemetry = mapHardwareSignalsToByteForce(signals)
% Maps hardware simulation signals to ByteForce telemetry struct.
% Supports 11 bridge signals (6 original + 5 new real simulation signals).
if ~isstruct(signals)
    error('signals must be a struct');
end

% ── Original 6 signals ────────────────────────────────────────────────────────
telemetry.ecc_count  = round(readNumeric(signals, {'ecc_count','distortion_events','error_bursts'}, 0));
telemetry.ecc_rate   = clamp01(readNumeric(signals, {'ecc_rate','packet_error_rate','evm_norm'}, 0));
telemetry.retries    = round(readNumeric(signals, {'retries','tx_retry_count','retransmissions'}, 0));
telemetry.temperature = readNumeric(signals, {'temperature','junction_temp_c','temp_c'}, 40);
telemetry.wear_level  = clampRange(readNumeric(signals, {'wear_level','stress_percent','runtime_wear_pct'}, 0), 0, 100);
telemetry.latency     = max(readNumeric(signals, {'latency','processing_latency_ms','loop_delay_ms'}, 1), 0);

% ── SMART Attributes — now mapped DIRECTLY from real simulation subsystems ───
% SMART 5  = Reallocated Sectors     ← BBM/dram_cnt   (real bad block count)
% SMART 187= Uncorrectable Errors    ← Health_Mon/uber_cnt (real UBER count)
% SMART 197= Current Pending Sectors ← derived from bad_block_count (blocks awaiting remap)
% SMART 198= Offline Uncorrectable   ← retirement_stage × 100 (permanent retirement metric)
badBlocks      = readNumeric(signals, {'bad_block_count','dram_cnt'}, telemetry.ecc_count);
uberCnt        = readNumeric(signals, {'uber_count','uber_cnt','uncorrectable_events'}, telemetry.retries);
retStage       = readNumeric(signals, {'retirement_stage','ret_stage'}, 0);

telemetry.smart_5_raw   = max(round(badBlocks), 0);               % SMART 5:  real bad blocks
telemetry.smart_187_raw = max(round(uberCnt), 0);                  % SMART 187: real UBER count
telemetry.smart_197_raw = max(round(badBlocks * 2), 0);            % SMART 197: pending (2× bad blocks)
telemetry.smart_198_raw = max(round(retStage * 100), 0);           % SMART 198: retirement severity

% ── New 5 real simulation signals ─────────────────────────────────────────────
telemetry.bad_block_count  = max(round(badBlocks), 0);
telemetry.journal_fill_pct = clampRange(readNumeric(signals, {'journal_fill_pct','journal_pct'}, 0), 0, 100);
telemetry.uber_count       = max(round(uberCnt), 0);
telemetry.retirement_stage = clampRange(round(retStage), 0, 3);
telemetry.event_code       = clampRange(round(readNumeric(signals, {'event_code'}, 0)), 0, 6);
end


function value = readNumeric(source, keys, defaultValue)
value = defaultValue;
for i = 1:numel(keys)
    key = keys{i};
    if isfield(source, key)
        candidate = source.(key);
        if isnumeric(candidate) && isscalar(candidate) && isfinite(candidate)
            value = double(candidate);
            return;
        end
    end
end
end

function out = clamp01(x)
out = min(max(x, 0), 1);
end

function out = clampRange(x, low, high)
out = min(max(x, low), high);
end
