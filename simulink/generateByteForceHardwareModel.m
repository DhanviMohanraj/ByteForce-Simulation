function modelName = generateByteForceHardwareModel(modelName)
% Programmatically generate a Simulink hardware-simulation model that
% publishes telemetry to ByteForce backend each step.
%
% Usage:
%   generateByteForceHardwareModel();
%   generateByteForceHardwareModel('MyByteForceHWModel');

if nargin < 1 || isempty(modelName)
    modelName = 'ByteForceHardwareModel';
end

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

new_system(modelName);
open_system(modelName);

set_param(modelName, 'StopTime', 'inf');
set_param(modelName, 'SolverType', 'Fixed-step');
set_param(modelName, 'Solver', 'FixedStepDiscrete');
set_param(modelName, 'FixedStep', '0.5');

% ---- Sources ----
add_block('simulink/Sources/Random Number', [modelName '/DistortionEvents'], ...
    'Position', [40 40 140 80], 'Seed', '11', 'Mean', '70', 'Variance', '400');
add_block('simulink/Sources/Random Number', [modelName '/PacketErrorRate'], ...
    'Position', [40 110 140 150], 'Seed', '12', 'Mean', '0.15', 'Variance', '0.01');
add_block('simulink/Sources/Random Number', [modelName '/RetryCount'], ...
    'Position', [40 180 140 220], 'Seed', '13', 'Mean', '40', 'Variance', '225');
add_block('simulink/Sources/Random Number', [modelName '/JunctionTempC'], ...
    'Position', [40 250 140 290], 'Seed', '14', 'Mean', '52', 'Variance', '16');
add_block('simulink/Sources/Random Number', [modelName '/StressPercent'], ...
    'Position', [40 320 140 360], 'Seed', '15', 'Mean', '28', 'Variance', '36');
add_block('simulink/Sources/Random Number', [modelName '/ProcessingLatencyMs'], ...
    'Position', [40 390 140 430], 'Seed', '16', 'Mean', '1.4', 'Variance', '0.09');

% Clamp packet error into [0,1]
add_block('simulink/Discontinuities/Saturation', [modelName '/ClampPER'], ...
    'Position', [190 110 250 150], 'UpperLimit', '1', 'LowerLimit', '0');

% ---- MATLAB Function publisher ----
add_block('simulink/User-Defined Functions/MATLAB Function', [modelName '/PublishToByteForce'], ...
    'Position', [320 140 570 340]);

publishCode = [ ...
"function status = fcn(distortionEvents, packetErrorRate, retryCount, junctionTempC, stressPercent, processingLatencyMs)", newline, ...
"status = simulinkPublishStep(distortionEvents, packetErrorRate, retryCount, junctionTempC, stressPercent, processingLatencyMs);", newline, ...
"end" ...
];
set_param([modelName '/PublishToByteForce'], 'Script', publishCode);

% ---- Visual outputs ----
add_block('simulink/Sinks/Scope', [modelName '/HardwareSignalsScope'], ...
    'Position', [650 80 820 230], 'NumInputPorts', '3');
add_block('simulink/Sinks/Display', [modelName '/PublishStatus'], ...
    'Position', [650 290 760 330]);

% ---- Wiring ----
add_line(modelName, 'PacketErrorRate/1', 'ClampPER/1', 'autorouting', 'on');

add_line(modelName, 'DistortionEvents/1', 'PublishToByteForce/1', 'autorouting', 'on');
add_line(modelName, 'ClampPER/1', 'PublishToByteForce/2', 'autorouting', 'on');
add_line(modelName, 'RetryCount/1', 'PublishToByteForce/3', 'autorouting', 'on');
add_line(modelName, 'JunctionTempC/1', 'PublishToByteForce/4', 'autorouting', 'on');
add_line(modelName, 'StressPercent/1', 'PublishToByteForce/5', 'autorouting', 'on');
add_line(modelName, 'ProcessingLatencyMs/1', 'PublishToByteForce/6', 'autorouting', 'on');

add_line(modelName, 'DistortionEvents/1', 'HardwareSignalsScope/1', 'autorouting', 'on');
add_line(modelName, 'JunctionTempC/1', 'HardwareSignalsScope/2', 'autorouting', 'on');
add_line(modelName, 'ProcessingLatencyMs/1', 'HardwareSignalsScope/3', 'autorouting', 'on');
add_line(modelName, 'PublishToByteForce/1', 'PublishStatus/1', 'autorouting', 'on');

save_system(modelName, fullfile(fileparts(mfilename('fullpath')), [modelName '.slx']));
open_system(modelName);

fprintf('Generated Simulink model: %s\\n', modelName);
fprintf('Saved at: %s\\n', fullfile(fileparts(mfilename('fullpath')), [modelName '.slx']));
end
