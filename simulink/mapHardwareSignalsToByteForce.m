function telemetry = mapHardwareSignalsToByteForce(signals)
if ~isstruct(signals)
    error('signals must be a struct');
end

telemetry.ecc_count = round(readNumeric(signals, {'ecc_count','distortion_events','error_bursts'}, 0));
telemetry.ecc_rate = clamp01(readNumeric(signals, {'ecc_rate','packet_error_rate','evm_norm'}, 0));
telemetry.retries = round(readNumeric(signals, {'retries','tx_retry_count','retransmissions'}, 0));
telemetry.temperature = readNumeric(signals, {'temperature','junction_temp_c','temp_c'}, 40);
telemetry.wear_level = clampRange(readNumeric(signals, {'wear_level','stress_percent','runtime_wear_pct'}, 0), 0, 100);
telemetry.latency = max(readNumeric(signals, {'latency','processing_latency_ms','loop_delay_ms'}, 1), 0);

smart5 = readNumeric(signals, {'smart_5_raw','reallocated_blocks','hard_fault_events'}, telemetry.ecc_count);
smart187 = readNumeric(signals, {'smart_187_raw','uncorrectable_events','retry_failures'}, telemetry.retries);
smart197 = readNumeric(signals, {'smart_197_raw','pending_fault_events','instability_index'}, telemetry.ecc_rate * 1000);
smart198 = readNumeric(signals, {'smart_198_raw','offline_uncorrectable','offline_fault_events'}, telemetry.latency * 100);

telemetry.smart_5_raw = max(smart5, 0);
telemetry.smart_187_raw = max(smart187, 0);
telemetry.smart_197_raw = max(smart197, 0);
telemetry.smart_198_raw = max(smart198, 0);
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
