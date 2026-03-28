function code = computeEventCode(is_bad, success, retry_flag, wear_stage, journal_pct)
% computeEventCode — QMC-optimised firmware event encoder (ByteForce bridge).
%
% This function implements the SAME priority logic as the original if-chain,
% but executes via a 64-entry pre-computed lookup table generated offline by
% qmc_minimize.m using the Quine-McCluskey algorithm + Petrick's method.
%
% On real NVMe silicon the equivalent ROM lookup executes in a single clock
% cycle. Here it replaces 6 nested conditional branches with one array index.
%
% INPUT ENCODING  (6 binary variables → 6-bit index → 64-entry LUT)
%   bit5 (MSB) : is_bad       — BBM flagged current block as bad
%   bit4       : uber_event   — NOT success (uncorrectable ECC error)
%   bit3       : retry_flag   — read retry active (LDPC headroom < 20%)
%   bit2       : stage4       — wear_stage >= 4 (max correction mode)
%   bit1       : journal_hi   — journal_pct >= 90 (critical flush)
%   bit0 (LSB) : journal_lo   — journal_pct >= 75 (pending flush)
%
% Output event codes  (identical to original):
%   0 = Nominal
%   1 = Journal fill > 75%   (approaching flush threshold)
%   2 = New bad block         (DRAM hash table hit)
%   3 = Read retry active     (ECC headroom exhausted)
%   4 = LDPC Stage 4          (maximum wear correction mode)
%   5 = UBER event            (uncorrectable — highest non-fatal)
%   6 = Journal critical >90% (overrides all except UBER)

% ── Cache the 64-entry LUT so it is built once per simulation run ────────────
persistent EVENT_LUT
if isempty(EVENT_LUT)
    lut_path = fullfile(fileparts(mfilename('fullpath')), 'event_code_lut.mat');
    if exist(lut_path, 'file')
        % Fast path: load pre-built LUT from qmc_minimize output
        S = load(lut_path, 'LUT');
        EVENT_LUT = S.LUT;
    else
        % Fallback: build LUT inline (same logic, no file I/O dependency)
        EVENT_LUT = build_lut_inline();
    end
end

% ── Encode the 5 continuous inputs into the 6-bit binary index ────────────
b5 = double(is_bad    > 0.5);          % bit 5
b4 = double(success   < 0.5);          % bit 4 (UBER = NOT success)
b3 = double(retry_flag > 0.5);         % bit 3
b2 = double(wear_stage >= 4);          % bit 2
b1 = double(journal_pct >= 90);        % bit 1  (journal critical)
b0 = double(journal_pct >= 75);        % bit 0  (journal pending)

% Single-instruction O(1) table lookup  ──────────────────────────────────────
idx  = b5*32 + b4*16 + b3*8 + b2*4 + b1*2 + b0;   % 0..63
code = double(EVENT_LUT(idx + 1));                   % +1: MATLAB 1-based index

end


%% ── INLINE FALLBACK LUT BUILDER ─────────────────────────────────────────────
%  Identical priority logic to the original if-chain; executes only once
%  (or if event_code_lut.mat has not been generated yet by qmc_minimize.m).
function LUT = build_lut_inline()
LUT = zeros(64, 1, 'uint8');
for idx = 0 : 63
    % Extract each bit using bitand — no Communications Toolbox required
    is_b  = bitand(idx, 32) > 0;   % bit 5 (MSB)
    uber  = bitand(idx, 16) > 0;   % bit 4
    retry = bitand(idx,  8) > 0;   % bit 3
    st4   = bitand(idx,  4) > 0;   % bit 2
    j_hi  = bitand(idx,  2) > 0;   % bit 1
    j_lo  = bitand(idx,  1) > 0;   % bit 0 (LSB)

    c = 0;
    if j_lo,  c = 1; end
    if is_b,  c = 2; end
    if retry, c = 3; end
    if st4,   c = 4; end
    if uber,  c = 5; end
    if j_hi
        c = 6;
        if uber, c = 5; end
    end
    LUT(idx + 1) = uint8(c);
end
end
