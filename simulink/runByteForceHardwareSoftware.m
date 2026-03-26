function runByteForceHardwareSoftware()
% Create and run the generated Simulink hardware model.
% Keep backend and frontend running separately:
%   Backend: python example_backend.py
%   Frontend: npm run dev

baseDir = fileparts(mfilename('fullpath'));
addpath(baseDir);

requiredFiles = {
    'simulinkPublishStep.m',
    'mapHardwareSignalsToByteForce.m',
    'sendTelemetryToByteForce.m'
};

for i = 1:numel(requiredFiles)
    if ~isfile(fullfile(baseDir, requiredFiles{i}))
        error('Missing required file: %s', requiredFiles{i});
    end
end

modelName = 'ByteForceHardwareModel';
modelPath = fullfile(baseDir, [modelName '.slx']);
if ~isfile(modelPath)
    generateByteForceHardwareModel(modelName);
else
    load_system(modelPath);
    open_system(modelName);
end

set_param(modelName, 'SimulationCommand', 'start');

disp('Simulink hardware model started.');
disp('Software dashboard: http://localhost:5173');
disp('Backend health: http://localhost:8000/api/health');
disp('Feature vector: http://localhost:8000/api/feature-vector');
end
