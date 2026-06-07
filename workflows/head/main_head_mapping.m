function result = main_head_mapping(action)
%MAIN_HEAD_MAPPING Validate, visualize, or run the production head mapping.
%
%   MAIN_HEAD_MAPPING() checks required inputs and the tracked validation.
%   MAIN_HEAD_MAPPING("validate") parses the existing output without remapping.
%   MAIN_HEAD_MAPPING("visualize") renders the validated SKIN/antenna view.
%   MAIN_HEAD_MAPPING("map") runs the expensive production mapping.

if nargin < 1
    action = "check";
end
action = lower(string(action));

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(repoRoot);
addpath(fullfile(repoRoot, 'Lib'));

[sourceFile, targetFile] = resolveHeadInputFiles(fullfile(repoRoot, 'input'));
resultDir = fullfile(repoRoot, 'result', 'base_finer');
outputFile = fullfile(resultDir, 'mesh_base_with_head_finer.dat');
logFile = fullfile(resultDir, 'mesh_base_with_head_finer_label_log.txt');

switch action
    case "check"
        requireFile(sourceFile);
        requireFile(targetFile);
        validationFile = fullfile(resultDir, ...
            'mesh_base_with_head_finer_validation.txt');
        summaryFile = fullfile(resultDir, ...
            'mesh_base_with_head_finer_summary.txt');
        requirePassedReport(validationFile);
        requireFile(summaryFile);
        result = struct('Action', action, 'SourceFile', sourceFile, ...
            'TargetFile', targetFile, 'ValidationFile', validationFile, ...
            'SummaryFile', summaryFile);
        fprintf('Head workflow inputs and tracked validation are present.\n');

    case "validate"
        requireFile(targetFile);
        requireFile(outputFile);
        validation = validateDatMeshFile(outputFile, ...
            'ReferenceFile', targetFile, 'ExpectedAddedMaterials', 5);
        assert(all(ismember(25:29, unique(validation.ElementLabels))), ...
            'mainHeadMapping:MissingHeadLabels', ...
            'The existing output does not contain all expected labels 25-29.');
        result = struct('Action', action, 'OutputFile', outputFile, ...
            'Validation', validation);
        fprintf('Existing head mapping is valid: %s\n', outputFile);

    case "visualize"
        requireFile(outputFile);
        figureHandle = visualizeDatLabelGroups( ...
            outputFile, {28, 3:18}, ...
            'GroupNames', ["SKIN", "Antennas"], ...
            'Colors', [1.00 0.00 0.78; 0.48 0.53 0.57], ...
            'Alphas', [0.82; 0.18], ...
            'OutputFolder', resultDir, ...
            'OutputName', 'skin28_antennas3_18', ...
            'OutputFormats', ["png", "fig"], ...
            'Title', 'Base/finer SKIN with antenna labels 3-18');
        result = struct('Action', action, 'OutputFile', outputFile, ...
            'Figure', figureHandle);

    case "map"
        config = productionConfig(sourceFile, targetFile, outputFile, logFile);
        result = meshingMapper(config);

    otherwise
        error('mainHeadMapping:UnknownAction', ...
            'Action must be "check", "validate", "visualize", or "map".');
end

function requirePassedReport(fileName)
requireFile(fileName);
if ~contains(fileread(fileName), 'Validation passed.')
    error('mainHeadMapping:ValidationNotPassed', ...
        'Tracked validation report does not contain "Validation passed.": %s', ...
        fileName);
end
end
end

function config = productionConfig(sourceFile, targetFile, outputFile, logFile)
config = struct();
config.SourceFile = sourceFile;
config.TargetFile = targetFile;
config.OutputFile = outputFile;
config.LogFile = logFile;
config.TargetLabels = [20:24, 19];
config.InputLabels = 1:5;
config.NewLabels = 25:29;
config.InputLabelNames = ["gray", "CSF", "FAT", "SKIN", "SKULL"];
config.NewLabelNames = ["gray", "CSF", "FAT", "SKIN", "SKULL"];
config.TargetSurfaceDistanceFilterLabels = 19;
config.TargetSurfaceDistance = 0.01;
config.SourceCentroidRepair = true;
config.ChunkSize = 250000;
config.UseParallel = false;
end

function requireFile(fileName)
if exist(fileName, 'file') ~= 2
    error('mainHeadMapping:MissingFile', 'Required file is missing: %s', fileName);
end
end
