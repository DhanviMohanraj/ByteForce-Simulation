%% =========================================================================
%  SSD PROFESSIONAL SIMULATION — University Project Grade
%  Adaptive LDPC + Three-Tier Bad Block Management
%
%  COMPONENTS:
%    1. I/O Request Generator
%    2. NAND Flash Degradation Model
%    3. Adaptive LDPC Encoder (4 wear stages)
%    4. Min-Sum Belief Propagation Decoder
%    5. ECC Health Monitor
%    6. Three-Tier Bad Block Manager (DRAM + Journal + B-Tree)
%    7. Predictive Retirement Engine
%    8. Professional Dashboard (Live Scopes + Numeric Displays)
%
%  HOW TO RUN:
%    1. Place this file in a folder e.g. C:\SSD_Project\
%    2. cd to that folder in MATLAB
%    3. run('SSD_Simulation.m')
%    4. Press RUN in Simulink
%    5. After sim: run('SSD_Analysis.m')
% =========================================================================

clc; clear; close all;

scriptFullPath = mfilename('fullpath');
if isempty(scriptFullPath)
    scriptFullPath = which('SSD_Simulation');
end

scriptDir = '';
if ~isempty(scriptFullPath)
    scriptDir = fileparts(scriptFullPath);
end

candidateDirs = {};
if ~isempty(scriptDir), candidateDirs{end+1} = scriptDir; end %#ok<AGROW>
candidateDirs{end+1} = pwd;
candidateDirs{end+1} = fullfile(pwd, 'simulink');
if ~isempty(scriptDir)
    candidateDirs{end+1} = fileparts(scriptDir);
    candidateDirs{end+1} = fullfile(fileparts(scriptDir), 'simulink');
end

for i = 1:numel(candidateDirs)
    if isfolder(candidateDirs{i})
        addpath(candidateDirs{i});
    end
end
rehash;

requiredBridgeFiles = {
    'simulinkPublishStep.m',
    'mapHardwareSignalsToByteForce.m',
    'sendTelemetryToByteForce.m'
};

simulinkDir = '';
for i = 1:numel(candidateDirs)
    d = candidateDirs{i};
    if ~isfolder(d)
        continue;
    end
    hasAll = true;
    for j = 1:numel(requiredBridgeFiles)
        if ~isfile(fullfile(d, requiredBridgeFiles{j}))
            hasAll = false;
            break;
        end
    end
    if hasAll
        simulinkDir = d;
        break;
    end
end

if isempty(simulinkDir)
    error('Missing required bridge files. Run this script from the simulink folder or ensure simulink/ is present on MATLAB path.');
end

for i = 1:numel(requiredBridgeFiles)
    if ~isfile(fullfile(simulinkDir, requiredBridgeFiles{i}))
        error('Missing required bridge file: %s', requiredBridgeFiles{i});
    end
end

if exist('simulinkPublishStep', 'file') ~= 2
    error('Bridge function simulinkPublishStep.m is not on MATLAB path. Current bridge dir: %s', simulinkDir);
end

fprintf('=================================================================\n');
fprintf('  SSD PROFESSIONAL SIMULATION — Starting Build\n');
fprintf('=================================================================\n\n');

%% =========================================================================
%  PARAMETERS — Tune these to change simulation behaviour
% =========================================================================
p.sim_time          = 200;       % Simulation time (seconds)
p.num_blocks        = 512;       % Total NAND blocks
p.page_bits         = 512;       % Bits per page
p.max_pe            = 65;        % Max P/E cycles (Scaled down so the drive fails within ~180 sec)
p.spare_blocks      = 32;        % Spare block pool
p.io_rate           = 10;        % I/Os per second

% LDPC — parity bits and max iterations per wear stage
p.parity            = [10, 20, 40, 100];
p.max_iter          = [10, 20,  50, 100];
p.rber_thresh       = [0.02, 0.10, 0.50, 1.00];

% Bad Block Manager
p.journal_cap       = 64;        % Journal capacity (entries)
p.flush_pct         = 75;        % Flush journal at this % full
p.flush_interval    = 15;        % Periodic flush every N seconds

% Health thresholds
p.watch_thresh      = 70;
p.migrate_thresh    = 50;
p.retire_thresh     = 20;

% NAND degradation
p.rber_base         = 0.0001;
p.rber_slope        = 0.0150;    % Massively accelerated Slope so Bad Blocks spawn in < 3 mins
p.retention         = 0.00002;

%% =========================================================================
%  CREATE MODEL
% =========================================================================
mdl = 'SSD_Pro';
if bdIsLoaded(mdl), close_system(mdl,0); end
if exist([mdl '.slx'],'file'), delete([mdl '.slx']); end

new_system(mdl);
open_system(mdl);

set_param(mdl, ...
    'StopTime',            num2str(p.sim_time), ...
    'Solver',              'FixedStepDiscrete', ...
    'FixedStep',           '0.1', ...
    'DataTypeOverride',    'Double', ...
    'DataTypeOverrideAppliesTo', 'AllNumericTypes', ...
    'SimulationMode',      'normal', ...
    'SaveTime',            'on', ...
    'SaveOutput',          'on', ...
    'SignalLogging',       'on', ...
    'SignalLoggingName',   'logsout', ...
    'EnablePacing',        'on', ...
    'PacingRate',          '1');

% Build InitFcn callback string with proper single-quote escaping.
% The callback is evaluated DIRECTLY by Simulink, so we must emit real
% single-quotes (not '' escape sequences) into the stored string.
initFcnStr = ['addpath(''' simulinkDir '''); rehash;'];
set_param(mdl, 'InitFcn', initFcnStr);

% Canvas background colour (dark theme feel via annotations)
fprintf('  [1/9] Setting up model canvas...\n');

%% =========================================================================
%  HELPER — add a visible annotation label on canvas
% =========================================================================
% Local helper functions are defined at the end of this file.

%% =========================================================================
%  SUBSYSTEM POSITIONS  (canvas layout — left to right, top to bottom)
%   Row 1:  IO_Gen  →  NAND  →  LDPC_ENC  →  LDPC_DEC
%   Row 2:  RETIRE  ←  HEALTH ←  (wired up)
%   Row 3:  BBM (spans full width)
%   Row 4:  Dashboard displays
% =========================================================================
% [left top right bottom]
POS.io      = [80,   120, 230,  220];
POS.nand    = [310,  120, 490,  220];
POS.enc     = [560,  120, 730,  220];
POS.dec     = [800,  120, 970,  220];
POS.health  = [800,  310, 970,  410];
POS.retire  = [560,  310, 730,  410];
POS.bbm     = [80,   480, 970,  580];

% Display positions (Row 4)
POS.d_rber      = [80,  640,  230, 690];
POS.d_stage     = [260, 640,  410, 690];
POS.d_health    = [440, 640,  590, 690];
POS.d_journal   = [620, 640,  770, 690];
POS.d_badblk    = [800, 640,  950, 690];
POS.d_retired   = [80,  710,  230, 760];
POS.d_score     = [260, 710,  410, 760];
POS.d_btree     = [440, 710,  590, 760];

% Scope positions (Row 5)
POS.sc_nand     = [80,  800,  280, 900];
POS.sc_ldpc     = [310, 800,  510, 900];
POS.sc_health   = [540, 800,  740, 900];
POS.sc_bbm      = [770, 800,  970, 900];

%% =========================================================================
%  SUBSYSTEM 1 — I/O REQUEST GENERATOR
% =========================================================================
fprintf('  [2/9] Building I/O Request Generator...\n');
s = [mdl '/IO_Gen'];
add_block('built-in/Subsystem', s, 'Position', POS.io, ...
    'ForegroundColor','blue','BackgroundColor','lightBlue');
set_param(s,'MaskDisplay','disp(''I/O\nRequest\nGen'')');

% Outports
add_block('built-in/Outport',[s '/blk_addr'],  'Position',[380,100,410,120],'Port','1');
add_block('built-in/Outport',[s '/is_write'],   'Position',[380,160,410,180],'Port','2');
add_block('built-in/Outport',[s '/io_active'],  'Position',[380,220,410,240],'Port','3');

% Random block address
add_block('simulink/Sources/Random Number',[s '/RndAddr'],...
    'Position',[60,90,170,130],...
    'Mean',num2str(p.num_blocks/2),...
    'Variance',num2str((p.num_blocks/3)^2),...
    'Seed', num2str(randi(10000)), ...
    'SampleTime','0.1');
add_block('simulink/Math Operations/Abs',[s '/AbsAddr'],...
    'Position',[210,90,260,130]);
add_block('simulink/Math Operations/Rounding Function',[s '/FloorAddr'],...
    'Position',[290,90,350,130],'Operator','floor');
add_line(s,'RndAddr/1','AbsAddr/1');
add_line(s,'AbsAddr/1','FloorAddr/1');
add_line(s,'FloorAddr/1','blk_addr/1');

% Write flag (Bernoulli ~30% writes)
add_block('simulink/Sources/Random Number',[s '/RndWrite'],...
    'Position',[60,150,170,190],...
    'Mean','0.3','Variance','0.21', ...
    'Seed', num2str(randi(10000)), ...
    'SampleTime','0.1');
add_block('simulink/Logic and Bit Operations/Compare To Constant',...
    [s '/WriteCmp'],'Position',[210,150,320,190],...
    'relop','>=','const','0.5');
add_line(s,'RndWrite/1','WriteCmp/1');
add_line(s,'WriteCmp/1','is_write/1');

% IO active pulse (always 1 during sim)
add_block('simulink/Sources/Constant',[s '/Active'],...
    'Position',[210,210,270,250],'Value','1');
add_line(s,'Active/1','io_active/1');

%% =========================================================================
%  SUBSYSTEM 2 — NAND FLASH DEGRADATION MODEL
% =========================================================================
fprintf('  [3/9] Building NAND Flash Model...\n');
s = [mdl '/NAND_Model'];
add_block('built-in/Subsystem', s, 'Position', POS.nand,...
    'ForegroundColor','black','BackgroundColor','orange');
set_param(s,'MaskDisplay','disp(''NAND\nFlash\nModel'')');

add_block('built-in/Inport', [s '/blk_addr'],  'Position',[40, 80, 70,100],'Port','1');
add_block('built-in/Inport', [s '/is_write'],  'Position',[40,140, 70,160],'Port','2');

add_block('built-in/Outport',[s '/rber'],       'Position',[470, 80,500,100],'Port','1');
add_block('built-in/Outport',[s '/pe_count'],   'Position',[470,140,500,160],'Port','2');
add_block('built-in/Outport',[s '/bit_errors'], 'Position',[470,200,500,220],'Port','3');
add_block('built-in/Outport',[s '/retention'],  'Position',[470,260,500,280],'Port','4');

% PE cycle counter
add_block('simulink/Discrete/Discrete-Time Integrator',[s '/PE_Cnt'],...
    'Position',[150,130,260,170],'SampleTime','0.1',...
    'UpperSaturationLimit',num2str(p.max_pe));
add_line(s,'is_write/1','PE_Cnt/1');
add_line(s,'PE_Cnt/1','pe_count/1');

% RBER = base + slope * PE/1000
add_block('simulink/Math Operations/Gain',[s '/PE_Scale'],...
    'Position',[300,130,380,170],...
    'Gain',num2str(p.rber_slope/1000));
add_block('simulink/Sources/Constant',[s '/RBER_B'],...
    'Position',[300, 80,370,110],'Value',num2str(p.rber_base));
add_block('simulink/Math Operations/Sum',[s '/RBER_Add'],...
    'Position',[410, 75,455,175]);
add_line(s,'PE_Cnt/1','PE_Scale/1');
add_line(s,'RBER_B/1','RBER_Add/1');
add_line(s,'PE_Scale/1','RBER_Add/2');
add_line(s,'RBER_Add/1','rber/1');

% Bit errors = page_bits * rber
add_block('simulink/Sources/Constant',[s '/PageBits'],...
    'Position',[300,190,370,220],'Value',num2str(p.page_bits));
add_block('simulink/Math Operations/Product',[s '/ErrCalc'],...
    'Position',[410,185,455,235]);
add_line(s,'PageBits/1','ErrCalc/1');
add_line(s,'RBER_Add/1','ErrCalc/2');
add_line(s,'ErrCalc/1','bit_errors/1');

% Retention errors
add_block('simulink/Sources/Clock',[s '/Clk'],'Position',[150,250,210,280]);
add_block('simulink/Math Operations/Gain',[s '/RetGain'],...
    'Position',[270,250,360,280],'Gain',num2str(p.retention));
add_line(s,'Clk/1','RetGain/1');
add_line(s,'RetGain/1','retention/1');

% Connect IO_Gen → NAND_Model
add_line(mdl,'IO_Gen/1','NAND_Model/1');
add_line(mdl,'IO_Gen/2','NAND_Model/2');

%% =========================================================================
%  SUBSYSTEM 3 — ADAPTIVE LDPC ENCODER
% =========================================================================
fprintf('  [4/9] Building Adaptive LDPC Encoder...\n');
s = [mdl '/LDPC_Enc'];
add_block('built-in/Subsystem', s,'Position',POS.enc,...
    'ForegroundColor','black','BackgroundColor','green');
set_param(s,'MaskDisplay','disp(''Adaptive\nLDPC\nEncoder'')');

add_block('built-in/Inport',[s '/raw_bits'], 'Position',[40, 80, 70,100],'Port','1');
add_block('built-in/Inport',[s '/pe_count'], 'Position',[40,140, 70,160],'Port','2');

add_block('built-in/Outport',[s '/enc_bits'],    'Position',[460, 80,490,100],'Port','1');
add_block('built-in/Outport',[s '/wear_stage'],  'Position',[460,140,490,160],'Port','2');
add_block('built-in/Outport',[s '/parity_bits'], 'Position',[460,200,490,220],'Port','3');
add_block('built-in/Outport',[s '/code_rate'],   'Position',[460,260,490,280],'Port','4');

% Wear stage LUT
add_block('simulink/Lookup Tables/1-D Lookup Table',[s '/Stage_LUT'],...
    'Position',[150,130,310,170],...
    'BreakpointsForDimension1', sprintf('[0, %d, %d, %d]', round(p.max_pe*0.25), round(p.max_pe*0.5), round(p.max_pe*0.75)),...
    'Table','[1, 2, 3, 4]');
add_line(s,'pe_count/1','Stage_LUT/1');
add_line(s,'Stage_LUT/1','wear_stage/1');

% Parity bits LUT
add_block('simulink/Lookup Tables/1-D Lookup Table',[s '/Parity_LUT'],...
    'Position',[150,190,310,230],...
    'BreakpointsForDimension1','[1, 2, 3, 4]',...
    'Table',sprintf('[%d,%d,%d,%d]',p.parity(1),p.parity(2),p.parity(3),p.parity(4)));
add_line(s,'Stage_LUT/1','Parity_LUT/1');
add_line(s,'Parity_LUT/1','parity_bits/1');

% Encoded bits = raw + parity
add_block('simulink/Math Operations/Sum',[s '/EncSum'],...
    'Position',[370, 70,430,110]);
add_line(s,'raw_bits/1','EncSum/1');
add_line(s,'Parity_LUT/1','EncSum/2');
add_line(s,'EncSum/1','enc_bits/1');

% Code rate = data/(data+parity)
add_block('simulink/Math Operations/Sum',[s '/TotalBits'],...
    'Position',[150,250,230,290]);
add_block('simulink/Sources/Constant',[s '/DataBits'],...
    'Position',[60,240,130,270],'Value',num2str(p.page_bits));
add_block('simulink/Math Operations/Divide',[s '/CodeRate'],...
    'Position',[280,250,360,290]);
add_line(s,'DataBits/1','TotalBits/1');
add_line(s,'Parity_LUT/1','TotalBits/2');
add_line(s,'DataBits/1','CodeRate/1');
add_line(s,'TotalBits/1','CodeRate/2');
add_line(s,'CodeRate/1','code_rate/1');

% Connect NAND → Encoder
add_line(mdl,'NAND_Model/3','LDPC_Enc/1');
add_line(mdl,'NAND_Model/2','LDPC_Enc/2');

%% =========================================================================
%  SUBSYSTEM 4 — MIN-SUM BELIEF PROPAGATION DECODER
% =========================================================================
fprintf('  [5/9] Building Min-Sum BP Decoder...\n');
s = [mdl '/LDPC_Dec'];
add_block('built-in/Subsystem', s,'Position',POS.dec,...
    'ForegroundColor','black','BackgroundColor','cyan');
set_param(s,'MaskDisplay','disp(''Min-Sum\nBP\nDecoder'')');

add_block('built-in/Inport',[s '/enc_bits'],   'Position',[40, 70, 70, 90],'Port','1');
add_block('built-in/Inport',[s '/wear_stage'], 'Position',[40,130, 70,150],'Port','2');
add_block('built-in/Inport',[s '/rber'],       'Position',[40,190, 70,210],'Port','3');

add_block('built-in/Outport',[s '/corr_bits'],  'Position',[520, 70,550, 90],'Port','1');
add_block('built-in/Outport',[s '/iter_used'],  'Position',[520,130,550,150],'Port','2');
add_block('built-in/Outport',[s '/success'],    'Position',[520,190,550,210],'Port','3');
add_block('built-in/Outport',[s '/headroom'],   'Position',[520,250,550,270],'Port','4');
add_block('built-in/Outport',[s '/retry_flag'], 'Position',[520,310,550,330],'Port','5');

% Max iterations LUT by stage
add_block('simulink/Lookup Tables/1-D Lookup Table',[s '/MaxIter_LUT'],...
    'Position',[140,120,300,160],...
    'BreakpointsForDimension1','[1,2,3,4]',...
    'Table',sprintf('[%d,%d,%d,%d]',...
    p.max_iter(1),p.max_iter(2),p.max_iter(3),p.max_iter(4)));
add_line(s,'wear_stage/1','MaxIter_LUT/1');

% Threshold LUT by stage
add_block('simulink/Lookup Tables/1-D Lookup Table',[s '/Thresh_LUT'],...
    'Position',[140,180,300,220],...
    'BreakpointsForDimension1','[1,2,3,4]',...
    'Table',sprintf('[%f,%f,%f,%f]',...
    p.rber_thresh(1),p.rber_thresh(2),p.rber_thresh(3),p.rber_thresh(4)));
add_line(s,'wear_stage/1','Thresh_LUT/1');

% RBER ratio = rber / threshold (clamped 0-1 via Saturation)
add_block('simulink/Math Operations/Divide',[s '/RatioDiv'],...
    'Position',[350,180,410,220]);
add_block('simulink/Discontinuities/Saturation',[s '/RatioClamp'],...
    'Position',[430,180,490,220],...
    'UpperLimit','1','LowerLimit','0');
add_line(s,'rber/1','RatioDiv/1');
add_line(s,'Thresh_LUT/1','RatioDiv/2');
add_line(s,'RatioDiv/1','RatioClamp/1');

% Iterations used = max_iter * ratio
add_block('simulink/Math Operations/Product',[s '/IterProd'],...
    'Position',[350,120,410,160]);
add_line(s,'MaxIter_LUT/1','IterProd/1');
add_line(s,'RatioClamp/1','IterProd/2');
add_line(s,'IterProd/1','iter_used/1');

% Success = rber < threshold
add_block('simulink/Math Operations/Sum',[s '/ErrDiff'],...
    'Position',[340,260,390,300],'Inputs','+-');
add_block('simulink/Logic and Bit Operations/Compare To Zero',...
    [s '/SuccessCmp'],'Position',[420,260,490,300],'relop','<');
add_line(s,'rber/1','ErrDiff/1');
add_line(s,'Thresh_LUT/1','ErrDiff/2');
add_line(s,'ErrDiff/1','SuccessCmp/1');
add_line(s,'SuccessCmp/1','success/1');

% Headroom % = (thresh - rber)/thresh * 100
add_block('simulink/Math Operations/Sum',[s '/HdDiff'],...
    'Position',[340,320,390,360],'Inputs','-+');
add_block('simulink/Math Operations/Divide',[s '/HdDiv'],...
    'Position',[410,320,460,360]);
add_block('simulink/Math Operations/Gain',[s '/HdPct'],...
    'Position',[480,320,530,360],'Gain','100');
add_line(s,'rber/1','HdDiff/1');
add_line(s,'Thresh_LUT/1','HdDiff/2');
add_line(s,'HdDiff/1','HdDiv/1');
add_line(s,'Thresh_LUT/1','HdDiv/2');
add_line(s,'HdDiv/1','HdPct/1');
add_line(s,'HdPct/1','headroom/1');

% Read retry flag = headroom < 20
add_block('simulink/Logic and Bit Operations/Compare To Constant',...
    [s '/RetryCmp'],'Position',[420,380,500,420],'relop','<','const','20');
add_line(s,'HdPct/1','RetryCmp/1');
add_line(s,'RetryCmp/1','retry_flag/1');

% Corrected bits
add_block('simulink/Math Operations/Product',[s '/CorrProd'],...
    'Position',[350, 65,410,100]);
add_line(s,'enc_bits/1','CorrProd/1');
add_line(s,'SuccessCmp/1','CorrProd/2');
add_line(s,'CorrProd/1','corr_bits/1');

% Connect Encoder → Decoder
add_line(mdl,'LDPC_Enc/1','LDPC_Dec/1');
add_line(mdl,'LDPC_Enc/2','LDPC_Dec/2');
add_line(mdl,'NAND_Model/1','LDPC_Dec/3');

%% =========================================================================
%  SUBSYSTEM 5 — ECC HEALTH MONITOR
% =========================================================================
fprintf('  [6/9] Building ECC Health Monitor...\n');
s = [mdl '/Health_Mon'];
add_block('built-in/Subsystem', s,'Position',POS.health,...
    'ForegroundColor','black','BackgroundColor','yellow');
set_param(s,'MaskDisplay','disp(''ECC\nHealth\nMonitor'')');

add_block('built-in/Inport',[s '/rber'],       'Position',[40, 70, 70, 90],'Port','1');
add_block('built-in/Inport',[s '/iter_used'],  'Position',[40,130, 70,150],'Port','2');
add_block('built-in/Inport',[s '/success'],    'Position',[40,190, 70,210],'Port','3');
add_block('built-in/Inport',[s '/headroom'],   'Position',[40,250, 70,270],'Port','4');
add_block('built-in/Inport',[s '/pe_count'],   'Position',[40,310, 70,330],'Port','5');
add_block('built-in/Inport',[s '/retry_flag'], 'Position',[40,370, 70,390],'Port','6');

add_block('built-in/Outport',[s '/health_score'],'Position',[520, 70,550, 90],'Port','1');
add_block('built-in/Outport',[s '/rber_trend'],  'Position',[520,130,550,150],'Port','2');
add_block('built-in/Outport',[s '/uber_cnt'],    'Position',[520,190,550,210],'Port','3');
add_block('built-in/Outport',[s '/retry_cnt'],   'Position',[520,250,550,270],'Port','4');

% RBER exponential moving average
add_block('simulink/Discrete/Discrete Filter',[s '/RBER_EMA'],...
    'Position',[150,60,320,100],...
    'Numerator','[0.1]','Denominator','[1,-0.9]','SampleTime','0.1');
add_line(s,'rber/1','RBER_EMA/1');
add_line(s,'RBER_EMA/1','rber_trend/1');

% UBER counter
add_block('simulink/Logic and Bit Operations/Logical Operator',...
    [s '/NotSuccess'],'Position',[150,180,230,220],'Operator','NOT');
add_block('simulink/Discrete/Discrete-Time Integrator',[s '/UBER_Int'],...
    'Position',[270,180,380,220],'SampleTime','0.1');
add_line(s,'success/1','NotSuccess/1');
add_line(s,'NotSuccess/1','UBER_Int/1');
add_line(s,'UBER_Int/1','uber_cnt/1');

% Retry counter
add_block('simulink/Discrete/Discrete-Time Integrator',[s '/Retry_Int'],...
    'Position',[270,360,380,400],'SampleTime','0.1');
add_line(s,'retry_flag/1','Retry_Int/1');
add_line(s,'Retry_Int/1','retry_cnt/1');

% Health score = 100 - penalties
add_block('simulink/Sources/Constant',[s '/Base100'],...
    'Position',[150,430,210,460],'Value','100');
add_block('simulink/Math Operations/Gain',[s '/RBER_Pen'],...
    'Position',[150,470,250,500],'Gain','-300');
add_block('simulink/Math Operations/Gain',[s '/UBER_Pen'],...
    'Position',[150,510,250,540],'Gain','-20');
add_block('simulink/Math Operations/Gain',[s '/Retry_Pen'],...
    'Position',[150,550,250,580],'Gain','-5');
add_block('simulink/Math Operations/Sum',[s '/ScoreRaw'],...
    'Position',[310,425,370,585],'Inputs','++++');
add_block('simulink/Discontinuities/Saturation',[s '/ScoreClamp'],...
    'Position',[410,470,480,510],...
    'UpperLimit','100','LowerLimit','0');

add_line(s,'Base100/1','ScoreRaw/1');
add_line(s,'RBER_EMA/1','RBER_Pen/1');
add_line(s,'RBER_Pen/1','ScoreRaw/2');
add_line(s,'UBER_Int/1','UBER_Pen/1');
add_line(s,'UBER_Pen/1','ScoreRaw/3');
add_line(s,'Retry_Int/1','Retry_Pen/1');
add_line(s,'Retry_Pen/1','ScoreRaw/4');
add_line(s,'ScoreRaw/1','ScoreClamp/1');
add_line(s,'ScoreClamp/1','health_score/1');

% Connect Decoder + NAND → Health Monitor
add_line(mdl,'NAND_Model/1','Health_Mon/1');
add_line(mdl,'LDPC_Dec/2', 'Health_Mon/2');
add_line(mdl,'LDPC_Dec/3', 'Health_Mon/3');
add_line(mdl,'LDPC_Dec/4', 'Health_Mon/4');
add_line(mdl,'NAND_Model/2','Health_Mon/5');
add_line(mdl,'LDPC_Dec/5', 'Health_Mon/6');

%% =========================================================================
%  SUBSYSTEM 6 — THREE-TIER BAD BLOCK MANAGER
% =========================================================================
fprintf('  [7/9] Building Three-Tier Bad Block Manager...\n');
s = [mdl '/BBM'];
add_block('built-in/Subsystem', s,'Position',POS.bbm,...
    'ForegroundColor','white','BackgroundColor','red');
set_param(s,'MaskDisplay',...
    'disp(''THREE-TIER BAD BLOCK MANAGER  |  DRAM Hash Table  +  Circular Journal  +  Zone B-Tree'')');

add_block('built-in/Inport',[s '/blk_addr'],  'Position',[40, 80, 70,100],'Port','1');
add_block('built-in/Inport',[s '/success'],   'Position',[40,140, 70,160],'Port','2');
add_block('built-in/Inport',[s '/h_score'],   'Position',[40,200, 70,220],'Port','3');

add_block('built-in/Outport',[s '/is_bad'],      'Position',[560, 80,590,100],'Port','1');
add_block('built-in/Outport',[s '/dram_cnt'],    'Position',[560,140,590,160],'Port','2');
add_block('built-in/Outport',[s '/journal_pct'], 'Position',[560,200,590,220],'Port','3');
add_block('built-in/Outport',[s '/btree_sz'],    'Position',[560,260,590,280],'Port','4');

% TIER 1 — DRAM: detect bad block (correction failed)
add_block('simulink/Logic and Bit Operations/Logical Operator',...
    [s '/IsBad'],'Position',[150,130,230,170],'Operator','NOT');
add_line(s,'success/1','IsBad/1');
add_line(s,'IsBad/1','is_bad/1');

% DRAM counter
add_block('simulink/Discrete/Discrete-Time Integrator',[s '/DRAM_Cnt'],...
    'Position',[290,130,400,170],'SampleTime','0.1',...
    'UpperSaturationLimit',num2str(p.num_blocks));
add_line(s,'IsBad/1','DRAM_Cnt/1');
add_line(s,'DRAM_Cnt/1','dram_cnt/1');

% TIER 2 — Journal fill level
add_block('simulink/Discrete/Discrete-Time Integrator',[s '/J_Fill'],...
    'Position',[290,190,400,240],'SampleTime','0.1',...
    'UpperSaturationLimit',num2str(p.journal_cap),...
    'LowerSaturationLimit','0');
add_line(s,'IsBad/1','J_Fill/1');

add_block('simulink/Math Operations/Gain',[s '/J_Pct'],...
    'Position',[430,190,510,240],...
    'Gain',num2str(100/p.journal_cap));
add_line(s,'J_Fill/1','J_Pct/1');
add_line(s,'J_Pct/1','journal_pct/1');

% Force floating-point before threshold compare to avoid fixed-point overflow
add_block('simulink/Signal Attributes/Data Type Conversion', [s '/J_Pct_Double'], ...
    'Position', [430,195,510,235], ...
    'OutDataTypeStr', 'double', ...
    'RndMeth', 'Floor', ...
    'SaturateOnIntegerOverflow', 'on');
add_line(s,'J_Pct/1','J_Pct_Double/1');

% Flush trigger at configured threshold (default 75%)
add_block('simulink/Logic and Bit Operations/Compare To Constant',...
    [s '/FlushTrig'],'Position',[545,195,625,235],...
    'relop','>=','const',num2str(double(p.flush_pct)));
add_line(s,'J_Pct_Double/1','FlushTrig/1');

% Periodic time-based flush trigger (every flush_interval seconds) using Pulse Generator
add_block('simulink/Sources/Pulse Generator', [s '/TimedFlush'], ...
    'Position', [430,255,510,295], ...
    'PulseType',   'Time based', ...
    'Period',      num2str(p.flush_interval), ...
    'PulseWidth',  '10', ...
    'PhaseDelay',  '0', ...
    'Amplitude',   '1');

% OR: flush if percent-full OR periodic timer fires
add_block('simulink/Logic and Bit Operations/Logical Operator', [s '/FlushOR'], ...
    'Position', [640,195,690,285], ...
    'Operator', 'OR', ...
    'Inputs',   '2');
add_line(s,'FlushTrig/1', 'FlushOR/1');
add_line(s,'TimedFlush/1','FlushOR/2');

% TIER 3 — B-Tree size (grows on flush from either trigger)
add_block('simulink/Discrete/Discrete-Time Integrator',[s '/BTree'],...
    'Position',[290,310,400,360],'SampleTime','0.1',...
    'UpperSaturationLimit',num2str(p.num_blocks));
add_line(s,'FlushOR/1','BTree/1');
add_line(s,'BTree/1','btree_sz/1');

% Connect everything to BBM
add_line(mdl,'IO_Gen/1',     'BBM/1');
add_line(mdl,'LDPC_Dec/3',   'BBM/2');
add_line(mdl,'Health_Mon/1', 'BBM/3');

%% =========================================================================
%  SUBSYSTEM 7 — PREDICTIVE RETIREMENT ENGINE
% =========================================================================
fprintf('  [8/9] Building Predictive Retirement Engine...\n');
s = [mdl '/Retire'];
add_block('built-in/Subsystem', s,'Position',POS.retire,...
    'ForegroundColor','white','BackgroundColor','magenta');
set_param(s,'MaskDisplay','disp(''Predictive\nRetirement\nEngine'')');

add_block('built-in/Inport',[s '/h_score'],   'Position',[40, 70, 70, 90],'Port','1');
add_block('built-in/Inport',[s '/rber_trend'],'Position',[40,130, 70,150],'Port','2');
add_block('built-in/Inport',[s '/uber_cnt'],  'Position',[40,190, 70,210],'Port','3');
add_block('built-in/Inport',[s '/dram_cnt'],  'Position',[40,250, 70,270],'Port','4');

add_block('built-in/Outport',[s '/ret_stage'],     'Position',[460, 70,490, 90],'Port','1');
add_block('built-in/Outport',[s '/blks_retired'],  'Position',[460,130,490,150],'Port','2');
add_block('built-in/Outport',[s '/mig_active'],    'Position',[460,190,490,210],'Port','3');
add_block('built-in/Outport',[s '/drv_health'],    'Position',[460,250,490,270],'Port','4');

% Retirement stage LUT
add_block('simulink/Lookup Tables/1-D Lookup Table',[s '/Stage_LUT'],...
    'Position',[150,60,350,100],...
    'BreakpointsForDimension1',...
    sprintf('[0,%d,%d,%d,100]',p.retire_thresh,p.migrate_thresh,p.watch_thresh),...
    'Table','[3,3,2,1,0]');
add_line(s,'h_score/1','Stage_LUT/1');
add_line(s,'Stage_LUT/1','ret_stage/1');

% Migration active flag (stage >= 2)
add_block('simulink/Logic and Bit Operations/Compare To Constant',...
    [s '/MigCmp'],'Position',[390,60,460,100],'relop','>=','const','2');
add_line(s,'Stage_LUT/1','MigCmp/1');
add_line(s,'MigCmp/1','mig_active/1');

% Blocks retired counter
add_block('simulink/Logic and Bit Operations/Compare To Constant',...
    [s '/RetireCmp'],'Position',[150,120,280,160],'relop','==','const','3');
add_block('simulink/Discrete/Discrete-Time Integrator',[s '/RetCnt'],...
    'Position',[310,120,410,160],'SampleTime','0.1',...
    'UpperSaturationLimit',num2str(p.num_blocks));
add_line(s,'Stage_LUT/1','RetireCmp/1');
add_line(s,'RetireCmp/1','RetCnt/1');
add_line(s,'RetCnt/1','blks_retired/1');

% Drive health %
add_block('simulink/Sources/Constant',[s '/TotalBlk'],...
    'Position',[60,240,130,270],'Value',num2str(p.num_blocks));
add_block('simulink/Math Operations/Sum',[s '/HlthDiff'],...
    'Position',[180,235,240,275],'Inputs','+-');
add_block('simulink/Math Operations/Divide',[s '/HlthDiv'],...
    'Position',[280,235,350,275]);
add_block('simulink/Math Operations/Gain',[s '/HlthPct'],...
    'Position',[380,235,440,275],'Gain','100');
add_line(s,'TotalBlk/1','HlthDiff/1');
add_line(s,'dram_cnt/1','HlthDiff/2');
add_line(s,'HlthDiff/1','HlthDiv/1');
add_line(s,'TotalBlk/1','HlthDiv/2');
add_line(s,'HlthDiv/1','HlthPct/1');
add_line(s,'HlthPct/1','drv_health/1');

% Connect Health + BBM → Retire
add_line(mdl,'Health_Mon/1','Retire/1');
add_line(mdl,'Health_Mon/2','Retire/2');
add_line(mdl,'Health_Mon/3','Retire/3');
add_line(mdl,'BBM/2',       'Retire/4');

%% =========================================================================
%  SECTION 7.5 — BYTEFORCE SOFTWARE BRIDGE (Simulink -> Flask API)
% =========================================================================
fprintf('  [8.5/9] Wiring ByteForce software bridge...\n');

% Top-level publisher block (version-safe): Mux 6 signals into MATLAB Fcn
add_block('simulink/Signal Routing/Mux', [mdl '/Bridge_Publish_Mux'], ...
    'Position', [920, 300, 960, 700], ...
    'Inputs', '11');  % 6 original + 5 new real signals

add_block('simulink/User-Defined Functions/MATLAB Fcn', [mdl '/Publish_To_ByteForce'], ...
    'Position', [1000, 300, 1320, 400], ...
    'MATLABFcn', 'simulinkPublishStep(u(1),u(2),u(3),u(4),u(5),u(6),u(7),u(8),u(9),u(10),u(11))');

add_block('simulink/Sinks/Display', [mdl '/Bridge_Status'], ...
    'Position', [1280, 330, 1400, 370], ...
    'Format', 'short');

add_block('built-in/Note', [mdl '/Lbl_Bridge_Status'], ...
    'Position', [1280, 305, 1400, 325], ...
    'Text', 'Bridge Publish Status', ...
    'FontSize', '9', ...
    'FontWeight', 'bold');

% -------------------------------------------------------------------------
% Realistic SSD telemetry synthesis for ML inputs
%   ecc_count    ~ cumulative distortion from bit-errors, wear, and burst noise
%   ecc_rate     ~ packet/error rate driven by RBER + retry pressure
%   retries      ~ read-retry demand from decoder iterations and retry flags
%   temperature  ~ thermal rise from wear + error activity + queue pressure
%   wear_level   ~ normalized P/E cycle usage
%   latency      ~ latency inflation from decoder complexity and retries
% -------------------------------------------------------------------------

% retries = clamp(3*retry_flag + 0.35*iter_used + burst_jitter, 0..250)
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_RetryFlag_to_Num'], ...
    'Position', [980, 130, 1070, 170], ...
    'Gain', '3');
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_Iter_to_Retry'], ...
    'Position', [980, 180, 1070, 220], ...
    'Gain', '0.35');
add_block('simulink/Sources/Random Number', [mdl '/Bridge_Retry_Jitter'], ...
    'Position', [980, 230, 1070, 270], ...
    'Mean', '0', ...
    'Variance', '4', ...
    'Seed', num2str(randi(10000)), ...
    'SampleTime', '0.1');
add_block('simulink/Math Operations/Abs', [mdl '/Bridge_Retry_JitterAbs'], ...
    'Position', [1090, 230, 1135, 270]);
add_block('simulink/Math Operations/Sum', [mdl '/Bridge_Retry_Sum'], ...
    'Position', [1160, 155, 1220, 235], ...
    'Inputs', '+++');
add_block('simulink/Discontinuities/Saturation', [mdl '/Bridge_Retry_Clamp'], ...
    'Position', [1240, 175, 1320, 215], ...
    'UpperLimit', '250', ...
    'LowerLimit', '0');

% packetErrorRate = clamp(4*rber + 0.0015*retries, 0..1)
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_RBER_to_Packet'], ...
    'Position', [980, 290, 1070, 330], ...
    'Gain', '4');
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_Retry_to_Packet'], ...
    'Position', [1090, 290, 1185, 330], ...
    'Gain', '0.0015');
add_block('simulink/Math Operations/Sum', [mdl '/Bridge_Packet_Sum'], ...
    'Position', [1205, 290, 1260, 330], ...
    'Inputs', '++');
add_block('simulink/Discontinuities/Saturation', [mdl '/Bridge_Packet_Clamp'], ...
    'Position', [1280, 290, 1360, 330], ...
    'UpperLimit', '1', ...
    'LowerLimit', '0');

% ecc_count (distortionEvents) = clamp(0.25*bit_errors + 0.02*pe_count + 4*|noise|, 0..1e6)
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_BitErr_to_Dist'], ...
    'Position', [980, 360, 1085, 400], ...
    'Gain', '0.25');
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_PE_to_Dist'], ...
    'Position', [980, 410, 1085, 450], ...
    'Gain', '0.02');
add_block('simulink/Sources/Random Number', [mdl '/Bridge_Dist_Noise'], ...
    'Position', [980, 460, 1085, 500], ...
    'Mean', '0', ...
    'Variance', '1', ...
    'Seed', num2str(randi(10000)), ...
    'SampleTime', '0.1');
add_block('simulink/Math Operations/Abs', [mdl '/Bridge_Dist_NoiseAbs'], ...
    'Position', [1105, 460, 1150, 500]);
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_Dist_NoiseGain'], ...
    'Position', [1170, 460, 1260, 500], ...
    'Gain', '4');
add_block('simulink/Math Operations/Sum', [mdl '/Bridge_Distortion_Sum'], ...
    'Position', [1170, 390, 1240, 450], ...
    'Inputs', '+++');
add_block('simulink/Discontinuities/Saturation', [mdl '/Bridge_Distortion_Clamp'], ...
    'Position', [1265, 400, 1360, 440], ...
    'UpperLimit', '1e6', ...
    'LowerLimit', '0');

% junctionTempC = clamp(30 + 0.004*pe_count + 18*ecc_rate + 0.01*retries, 20..95)
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_PE_to_Temp'], ...
    'Position', [980, 550, 1080, 590], ...
    'Gain', '0.004');
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_Err_to_Temp'], ...
    'Position', [980, 600, 1080, 640], ...
    'Gain', '18');
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_Retry_to_Temp'], ...
    'Position', [980, 650, 1080, 690], ...
    'Gain', '0.01');
add_block('simulink/Sources/Random Number', [mdl '/Bridge_Temp_Base'], ...
    'Position', [980, 700, 1080, 730], ...
    'Mean', '30', ...
    'Variance', '25', ...
    'Seed', num2str(randi(10000)), ...
    'SampleTime', '0.1');
add_block('simulink/Math Operations/Sum', [mdl '/Bridge_Temp_Sum'], ...
    'Position', [1110, 585, 1180, 735], ...
    'Inputs', '++++');
add_block('simulink/Discontinuities/Saturation', [mdl '/Bridge_Temp_Clamp'], ...
    'Position', [1210, 635, 1290, 675], ...
    'UpperLimit', '95', ...
    'LowerLimit', '20');

% wear_level = clamp(100 * pe_count / max_pe, 0..100)
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_PE_to_Wear'], ...
    'Position', [980, 760, 1085, 800], ...
    'Gain', num2str(100 / p.max_pe));
add_block('simulink/Discontinuities/Saturation', [mdl '/Bridge_Wear_Clamp'], ...
    'Position', [1110, 760, 1190, 800], ...
    'UpperLimit', '100', ...
    'LowerLimit', '0');

% processingLatencyMs = clamp(0.35 + 0.025*iter + 0.01*retries + 4*ecc_rate, 0.1..20)
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_Iter_to_Lat'], ...
    'Position', [980, 840, 1080, 880], ...
    'Gain', '0.025');
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_Retry_to_Lat'], ...
    'Position', [980, 890, 1080, 930], ...
    'Gain', '0.01');
add_block('simulink/Math Operations/Gain', [mdl '/Bridge_Err_to_Lat'], ...
    'Position', [980, 940, 1080, 980], ...
    'Gain', '4');
add_block('simulink/Sources/Constant', [mdl '/Bridge_Lat_Base'], ...
    'Position', [980, 990, 1080, 1020], ...
    'Value', '0.35');
add_block('simulink/Math Operations/Sum', [mdl '/Bridge_Lat_Sum'], ...
    'Position', [1110, 875, 1180, 1025], ...
    'Inputs', '++++');
add_block('simulink/Discontinuities/Saturation', [mdl '/Bridge_Lat_Clamp'], ...
    'Position', [1210, 935, 1290, 975], ...
    'UpperLimit', '20', ...
    'LowerLimit', '0.1');

% Bridge wiring from existing model signals
% retries path
add_line(mdl, 'LDPC_Dec/5', 'Bridge_RetryFlag_to_Num/1', 'autorouting', 'on');
add_line(mdl, 'LDPC_Dec/2', 'Bridge_Iter_to_Retry/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_Retry_Jitter/1', 'Bridge_Retry_JitterAbs/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_RetryFlag_to_Num/1', 'Bridge_Retry_Sum/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_Iter_to_Retry/1', 'Bridge_Retry_Sum/2', 'autorouting', 'on');
add_line(mdl, 'Bridge_Retry_JitterAbs/1', 'Bridge_Retry_Sum/3', 'autorouting', 'on');
add_line(mdl, 'Bridge_Retry_Sum/1', 'Bridge_Retry_Clamp/1', 'autorouting', 'on');

% packet error rate path
add_line(mdl, 'NAND_Model/1', 'Bridge_RBER_to_Packet/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_Retry_Clamp/1', 'Bridge_Retry_to_Packet/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_RBER_to_Packet/1', 'Bridge_Packet_Sum/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_Retry_to_Packet/1', 'Bridge_Packet_Sum/2', 'autorouting', 'on');
add_line(mdl, 'Bridge_Packet_Sum/1', 'Bridge_Packet_Clamp/1', 'autorouting', 'on');

% distortion / ecc count path
add_line(mdl, 'NAND_Model/3', 'Bridge_BitErr_to_Dist/1', 'autorouting', 'on');
add_line(mdl, 'NAND_Model/2', 'Bridge_PE_to_Dist/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_Dist_Noise/1', 'Bridge_Dist_NoiseAbs/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_Dist_NoiseAbs/1', 'Bridge_Dist_NoiseGain/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_BitErr_to_Dist/1', 'Bridge_Distortion_Sum/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_PE_to_Dist/1', 'Bridge_Distortion_Sum/2', 'autorouting', 'on');
add_line(mdl, 'Bridge_Dist_NoiseGain/1', 'Bridge_Distortion_Sum/3', 'autorouting', 'on');
add_line(mdl, 'Bridge_Distortion_Sum/1', 'Bridge_Distortion_Clamp/1', 'autorouting', 'on');

% temperature path
add_line(mdl, 'NAND_Model/2', 'Bridge_PE_to_Temp/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_Packet_Clamp/1', 'Bridge_Err_to_Temp/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_Retry_Clamp/1', 'Bridge_Retry_to_Temp/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_PE_to_Temp/1', 'Bridge_Temp_Sum/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_Err_to_Temp/1', 'Bridge_Temp_Sum/2', 'autorouting', 'on');
add_line(mdl, 'Bridge_Retry_to_Temp/1', 'Bridge_Temp_Sum/3', 'autorouting', 'on');
add_line(mdl, 'Bridge_Temp_Base/1', 'Bridge_Temp_Sum/4', 'autorouting', 'on');
add_line(mdl, 'Bridge_Temp_Sum/1', 'Bridge_Temp_Clamp/1', 'autorouting', 'on');

% wear level path
add_line(mdl, 'NAND_Model/2', 'Bridge_PE_to_Wear/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_PE_to_Wear/1', 'Bridge_Wear_Clamp/1', 'autorouting', 'on');

% latency path
add_line(mdl, 'LDPC_Dec/2', 'Bridge_Iter_to_Lat/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_Retry_Clamp/1', 'Bridge_Retry_to_Lat/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_Packet_Clamp/1', 'Bridge_Err_to_Lat/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_Iter_to_Lat/1', 'Bridge_Lat_Sum/1', 'autorouting', 'on');
add_line(mdl, 'Bridge_Retry_to_Lat/1', 'Bridge_Lat_Sum/2', 'autorouting', 'on');
add_line(mdl, 'Bridge_Err_to_Lat/1', 'Bridge_Lat_Sum/3', 'autorouting', 'on');
add_line(mdl, 'Bridge_Lat_Base/1', 'Bridge_Lat_Sum/4', 'autorouting', 'on');
add_line(mdl, 'Bridge_Lat_Sum/1', 'Bridge_Lat_Clamp/1', 'autorouting', 'on');

% ── SECTION 7.6 — THERMAL RC FILTER (replaces instant formula with physics) ──
% H(z) = 0.005 / (1 - 0.995*z^-1)  where alpha = exp(-0.1s / 20s) ≈ 0.995
% This gives temperature a 20-second thermal time constant (realistic lag)
fprintf('  [8.6/9] Adding thermal RC filter...\n');
add_block('simulink/Discrete/Discrete Filter', [mdl '/Bridge_Thermal_Filter'], ...
    'Position', [1340, 635, 1460, 675], ...
    'Numerator', '[0.005]', ...
    'Denominator', '[1, -0.995]', ...
    'SampleTime', '0.1');
add_line(mdl, 'Bridge_Temp_Clamp/1', 'Bridge_Thermal_Filter/1', 'autorouting', 'on');

% ── SECTION 7.7 — EVENT ENCODER (state transitions → firmware event codes) ──
% Signals: BBM/is_bad, LDPC/success, LDPC/retry_flag, LDPC_Enc/wear_stage, BBM/journal_pct
% computeEventCode() returns 0-6 (see simulink/computeEventCode.m for legend)
fprintf('  [8.7/9] Adding firmware event encoder...\n');
add_block('simulink/Signal Routing/Mux', [mdl '/Event_Encoder_Mux'], ...
    'Position', [1340, 700, 1380, 870], ...
    'Inputs', '5');
add_block('simulink/User-Defined Functions/MATLAB Fcn', [mdl '/Event_Encoder'], ...
    'Position', [1400, 750, 1580, 820], ...
    'MATLABFcn', 'computeEventCode(u(1),u(2),u(3),u(4),u(5))');
add_block('simulink/Signal Attributes/Data Type Conversion', [mdl '/Conv_Event1'], ...
    'Position', [1280, 710, 1310, 730], 'OutDataTypeStr', 'double');
add_block('simulink/Signal Attributes/Data Type Conversion', [mdl '/Conv_Event2'], ...
    'Position', [1280, 740, 1310, 760], 'OutDataTypeStr', 'double');
add_block('simulink/Signal Attributes/Data Type Conversion', [mdl '/Conv_Event3'], ...
    'Position', [1280, 770, 1310, 790], 'OutDataTypeStr', 'double');

add_line(mdl, 'BBM/1',      'Conv_Event1/1', 'autorouting', 'on');  % is_bad -> double
add_line(mdl, 'LDPC_Dec/3', 'Conv_Event2/1', 'autorouting', 'on');  % success -> double
add_line(mdl, 'LDPC_Dec/5', 'Conv_Event3/1', 'autorouting', 'on');  % retry_flag -> double

add_line(mdl, 'Conv_Event1/1', 'Event_Encoder_Mux/1', 'autorouting', 'on');
add_line(mdl, 'Conv_Event2/1', 'Event_Encoder_Mux/2', 'autorouting', 'on');
add_line(mdl, 'Conv_Event3/1', 'Event_Encoder_Mux/3', 'autorouting', 'on');
add_line(mdl, 'LDPC_Enc/2', 'Event_Encoder_Mux/4', 'autorouting', 'on');  % wear_stage (double)
add_line(mdl, 'BBM/3',      'Event_Encoder_Mux/5', 'autorouting', 'on');  % journal_pct (double)

add_line(mdl, 'Event_Encoder_Mux/1', 'Event_Encoder/1', 'autorouting', 'on');
add_line(mdl, 'Event_Encoder/1', 'Bridge_Publish_Mux/11', 'autorouting', 'on');


% Final bridge inputs expected by simulinkPublishStep(...)
% u(1)-u(6): original 6 signals
add_line(mdl, 'Bridge_Distortion_Clamp/1', 'Bridge_Publish_Mux/1',  'autorouting', 'on');  % ecc_count
add_line(mdl, 'Bridge_Packet_Clamp/1',     'Bridge_Publish_Mux/2',  'autorouting', 'on');  % ecc_rate
add_line(mdl, 'Bridge_Retry_Clamp/1',      'Bridge_Publish_Mux/3',  'autorouting', 'on');  % retries
add_line(mdl, 'Bridge_Thermal_Filter/1',   'Bridge_Publish_Mux/4',  'autorouting', 'on');  % temperature (RC-filtered)
add_line(mdl, 'Bridge_Wear_Clamp/1',       'Bridge_Publish_Mux/5',  'autorouting', 'on');  % wear_level
add_line(mdl, 'Bridge_Lat_Clamp/1',        'Bridge_Publish_Mux/6',  'autorouting', 'on');  % latency_ms
% u(7)-u(11): NEW real simulation signals
add_line(mdl, 'BBM/2',         'Bridge_Publish_Mux/7',  'autorouting', 'on');  % bad_block_count (dram_cnt)
add_line(mdl, 'BBM/3',         'Bridge_Publish_Mux/8',  'autorouting', 'on');  % journal_fill_pct
add_line(mdl, 'Health_Mon/3',  'Bridge_Publish_Mux/9',  'autorouting', 'on');  % uber_count
add_line(mdl, 'Retire/1',      'Bridge_Publish_Mux/10', 'autorouting', 'on');  % retirement_stage
% u(11) = event_code, already wired via Event_Encoder → Bridge_Publish_Mux/11
add_line(mdl, 'Bridge_Publish_Mux/1', 'Publish_To_ByteForce/1', 'autorouting', 'on');
add_line(mdl, 'Publish_To_ByteForce/1', 'Bridge_Status/1', 'autorouting', 'on');

%% =========================================================================
%  SECTION 8 — LIVE NUMERIC DISPLAYS
% =========================================================================
fprintf('  [9/9] Building Dashboard displays and scopes...\n');

% Helper to add a labelled display
% Local helper functions are defined at the end of this file.

addDisplay(mdl,'Disp_RBER',     'NAND_Model/1', POS.d_rber,    'RBER');
addDisplay(mdl,'Disp_Stage',    'LDPC_Enc/2',   POS.d_stage,   'Wear Stage');
addDisplay(mdl,'Disp_Score',    'Health_Mon/1', POS.d_health,  'Health Score');
addDisplay(mdl,'Disp_JrnPct',   'BBM/3',        POS.d_journal, 'Journal Fill %');
addDisplay(mdl,'Disp_BadBlk',   'BBM/2',        POS.d_badblk,  'DRAM Bad Blocks');
addDisplay(mdl,'Disp_Retired',  'Retire/2',     POS.d_retired, 'Blocks Retired');
addDisplay(mdl,'Disp_DrvHlth',  'Retire/4',     POS.d_score,   'Drive Health %');
addDisplay(mdl,'Disp_BTree',    'BBM/4',        POS.d_btree,   'B-Tree Size');

%% =========================================================================
%  SECTION 9 — LIVE SCOPES (4 scopes, multi-channel)
% =========================================================================

% Scope 1 — NAND Degradation
add_block('simulink/Sinks/Scope',[mdl '/Scope_NAND'],...
    'Position',POS.sc_nand,'NumInputPorts','2');
set_param([mdl '/Scope_NAND'],...
    'Title',  'NAND Degradation: RBER & PE Count',...
    'YLabel', 'Value');
add_line(mdl,'NAND_Model/1','Scope_NAND/1','autorouting','on');
add_line(mdl,'NAND_Model/2','Scope_NAND/2','autorouting','on');

% Scope 2 — LDPC Decoder Performance
add_block('simulink/Sinks/Scope',[mdl '/Scope_LDPC'],...
    'Position',POS.sc_ldpc,'NumInputPorts','3');
set_param([mdl '/Scope_LDPC'],...
    'Title',  'LDPC Decoder: Iterations | Success | Headroom %',...
    'YLabel', 'Value');
add_line(mdl,'LDPC_Dec/2','Scope_LDPC/1','autorouting','on');
add_line(mdl,'LDPC_Dec/3','Scope_LDPC/2','autorouting','on');
add_line(mdl,'LDPC_Dec/4','Scope_LDPC/3','autorouting','on');

% Scope 3 — Health & Retirement
add_block('simulink/Sinks/Scope',[mdl '/Scope_Health'],...
    'Position',POS.sc_health,'NumInputPorts','3');
set_param([mdl '/Scope_Health'],...
    'Title',  'Block Health Score | UBER Count | Retirement Stage',...
    'YLabel', 'Value');
add_line(mdl,'Health_Mon/1','Scope_Health/1','autorouting','on');
add_line(mdl,'Health_Mon/3','Scope_Health/2','autorouting','on');
add_line(mdl,'Retire/1',    'Scope_Health/3','autorouting','on');

% Scope 4 — Three-Tier Bad Block Manager
add_block('simulink/Sinks/Scope',[mdl '/Scope_BBM'],...
    'Position',POS.sc_bbm,'NumInputPorts','3');
set_param([mdl '/Scope_BBM'],...
    'Title',  'Three-Tier BBM: DRAM Count | Journal % | B-Tree Size',...
    'YLabel', 'Count / %');
add_line(mdl,'BBM/2','Scope_BBM/1','autorouting','on');
add_line(mdl,'BBM/3','Scope_BBM/2','autorouting','on');
add_line(mdl,'BBM/4','Scope_BBM/3','autorouting','on');

%% =========================================================================
%  SECTION 10 — TO WORKSPACE (for post-sim analysis)
% =========================================================================
ws_signals = {
    'NAND_Model/1',  'ws_rber';
    'NAND_Model/2',  'ws_pe';
    'LDPC_Enc/2',    'ws_stage';
    'LDPC_Dec/2',    'ws_iter';
    'LDPC_Dec/3',    'ws_success';
    'LDPC_Dec/4',    'ws_headroom';
    'Health_Mon/1',  'ws_score';
    'Health_Mon/3',  'ws_uber';
    'BBM/2',         'ws_dram';
    'BBM/3',         'ws_journal';
    'BBM/4',         'ws_btree';
    'Retire/1',      'ws_ret_stage';
    'Retire/2',      'ws_retired';
    'Retire/4',      'ws_drv_health';
    'Bridge_Distortion_Clamp/1', 'ws_ecc_count';
    'Bridge_Packet_Clamp/1',     'ws_ecc_rate';
    'Bridge_Retry_Clamp/1',      'ws_retries';
    'Bridge_Temp_Clamp/1',       'ws_temperature';
    'Bridge_Wear_Clamp/1',       'ws_wear_level';
    'Bridge_Lat_Clamp/1',        'ws_latency';
};

ws_base_pos = [1100, 50];
for i = 1:size(ws_signals,1)
    blk_name = ['WS_' num2str(i)];
    pos_ws = [ws_base_pos(1), ws_base_pos(2)+(i-1)*55, ...
              ws_base_pos(1)+160, ws_base_pos(2)+(i-1)*55+40];
    add_block('simulink/Sinks/To Workspace',[mdl '/' blk_name],...
        'Position',     pos_ws,...
        'VariableName', ws_signals{i,2},...
        'SampleTime',   '0.1',...
        'SaveFormat',   'Structure With Time');
    add_line(mdl, ws_signals{i,1}, [blk_name '/1'], 'autorouting','on');
end

%% =========================================================================
%  SECTION 11 — CANVAS ANNOTATIONS (signal flow labels)
% =========================================================================
% Row 1 arrows and labels
add_block('built-in/Note',[mdl '/Ann_IOtoNAND'],...
    'Position',[240,160,300,180],...
    'Text','blk_addr, is_write →',...
    'FontSize','8','ForegroundColor','blue');

add_block('built-in/Note',[mdl '/Ann_NANDtoENC'],...
    'Position',[500,160,555,180],...
    'Text','bit_errors, pe_count →',...
    'FontSize','8','ForegroundColor','black');

add_block('built-in/Note',[mdl '/Ann_ENCtoDEC'],...
    'Position',[740,160,796,180],...
    'Text','enc_bits, stage →',...
    'FontSize','8','ForegroundColor','black');

% Section title annotations
add_block('built-in/Note',[mdl '/Title_Main'],...
    'Position',[80,40,970,75],...
    'Text','SSD ADAPTIVE LDPC + THREE-TIER BAD BLOCK MANAGEMENT SIMULATION',...
    'FontSize','14','FontWeight','bold',...
    'ForegroundColor','black','BackgroundColor','white');

add_block('built-in/Note',[mdl '/Title_BBM'],...
    'Position',[80,455,970,478],...
    'Text','▼  THREE-TIER BAD BLOCK MANAGER  |  TIER 1: DRAM Hash Table  |  TIER 2: Circular Journal  |  TIER 3: Zone B-Tree  ▼',...
    'FontSize','10','FontWeight','bold',...
    'ForegroundColor','white','BackgroundColor','red');

add_block('built-in/Note',[mdl '/Title_Display'],...
    'Position',[80,615,970,635],...
    'Text','LIVE NUMERIC DISPLAYS',...
    'FontSize','10','FontWeight','bold',...
    'ForegroundColor','black','BackgroundColor','lightBlue');

add_block('built-in/Note',[mdl '/Title_Scopes'],...
    'Position',[80,775,970,795],...
    'Text','LIVE SCOPE DISPLAYS',...
    'FontSize','10','FontWeight','bold',...
    'ForegroundColor','black','BackgroundColor','lightBlue');

%% =========================================================================
%  SAVE
% =========================================================================
save_system(mdl, [mdl '.slx']);
fprintf('\n');
fprintf('=================================================================\n');
fprintf('  MODEL BUILT SUCCESSFULLY: SSD_Pro.slx\n');
fprintf('=================================================================\n');
fprintf('\n');
fprintf('  NEXT STEPS:\n');
fprintf('  1. Simulink model is now open\n');
fprintf('  2. Press the green RUN button (Stop Time = 100)\n');
fprintf('  3. Double-click any scope to watch live signals\n');
fprintf('  4. After sim completes, run: SSD_Analysis.m\n');
fprintf('  5. Start software dashboard at: http://localhost:5173\n');
fprintf('  6. Bridge target endpoint: http://localhost:8000/api/ingest-telemetry\n');
fprintf('\n');
fprintf('  LIVE DISPLAYS (update every timestep):\n');
fprintf('  RBER            Raw bit error rate\n');
fprintf('  Wear Stage      LDPC stage 1-4\n');
fprintf('  Health Score    Block health 0-100\n');
fprintf('  Journal Fill%%   Circular journal fill level\n');
fprintf('  DRAM Bad Blocks Bad blocks in DRAM hash table\n');
fprintf('  Blocks Retired  Predictively retired blocks\n');
fprintf('  Drive Health%%   Overall drive health\n');
fprintf('  B-Tree Size     Zone B-Tree entry count\n');
fprintf('\n');
fprintf('  SCOPES:\n');
fprintf('  Scope_NAND      RBER + PE count over time\n');
fprintf('  Scope_LDPC      Iterations + Success + Headroom\n');
fprintf('  Scope_Health    Health score + UBER + Retire stage\n');
fprintf('  Scope_BBM       DRAM + Journal%% + B-Tree\n');
fprintf('=================================================================\n');


function h = addNote(mdl, txt, pos, fg, bg)
h = add_block('built-in/Note', [mdl '/' txt], ...
    'Position',        pos, ...
    'ForegroundColor', fg, ...
    'BackgroundColor', bg, ...
    'FontSize',        '10', ...
    'FontWeight',      'bold');
end


function addDisplay(mdl, name, src_port, pos, label)
blk = [mdl '/' name];
add_block('simulink/Sinks/Display', blk, ...
    'Position', pos, ...
    'Format',   'short');
add_block('built-in/Note', [mdl '/Lbl_' name], ...
    'Position', [pos(1), pos(2)-22, pos(3), pos(2)-2], ...
    'Text',      label, ...
    'FontSize', '9', ...
    'FontWeight','bold');
add_line(mdl, src_port, [name '/1'], 'autorouting', 'on');
end