function code = computeEventCode(is_bad, success, retry_flag, wear_stage, journal_pct)
% computeEventCode — Firmware event encoder for ByteForce bridge.
% Called every simulation timestep by the Event_Encoder Simulink block.
%
% Maps current simulation state to a single numeric event code (0-6).
% Priority: higher codes override lower ones.
%
% Inputs (from top-level Simulink signals):
%   is_bad      - BBM/1: 1 if current block is bad, 0 otherwise
%   success     - LDPC_Dec/3: 1 if decode succeeded, 0 = UBER event
%   retry_flag  - LDPC_Dec/5: 1 if read retry is active
%   wear_stage  - LDPC_Enc/2: wear stage 1-4
%   journal_pct - BBM/3: journal fill percentage 0-100
%
% Output event codes:
%   0 = Nominal — no significant event
%   1 = Journal fill >75% (approaching flush threshold)
%   2 = New bad block detected by DRAM hash table
%   3 = Read retry activated — ECC headroom low
%   4 = LDPC Stage 4 engaged — maximum wear correction mode
%   5 = Uncorrectable ECC error (UBER event)
%   6 = Journal capacity critical — flush triggered (>90%)

% Default: nominal
code = 0;

% Priority escalation (each if overrides the previous)
if journal_pct >= 75
    code = 1;
end

if is_bad > 0.5
    code = 2;
end

if retry_flag > 0.5
    code = 3;
end

if wear_stage >= 4
    code = 4;
end

if success < 0.5
    code = 5;   % UBER — highest non-fatal priority
end

if journal_pct >= 90
    code = 6;   % Journal critical — overrides all except UBER
    if success < 0.5
        code = 5;  % UBER still wins
    end
end

end
