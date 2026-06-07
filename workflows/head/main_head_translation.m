function result = main_head_translation(action)
%MAIN_HEAD_TRANSLATION Validate existing translations or run the 2 mm case.
%
%   MAIN_HEAD_TRANSLATION() checks inputs and tracked validation reports.
%   MAIN_HEAD_TRANSLATION("validate") parses existing translated outputs.
%   MAIN_HEAD_TRANSLATION("map-2mm-down") creates and maps a -2 mm Z case.
%   MAIN_HEAD_TRANSLATION("visualize-2mm-down") visualizes that output.

if nargin < 1
    action = "check";
end
action = lower(string(action));

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(repoRoot);
addpath(fullfile(repoRoot, 'Lib'));

inputDir = fullfile(repoRoot, 'input');
resultDir = fullfile(repoRoot, 'result', 'base_finer_translations');
[sourceFile, targetFile] = resolveHeadInputFiles(inputDir);

switch action
    case "check"
        requireFile(sourceFile);
        requireFile(targetFile);
        cases = ["1mm_zUP", "1mm_zDOWN"];
        validationFiles = strings(numel(cases), 1);
        for index = 1:numel(cases)
            validationFiles(index) = fullfile(resultDir, ...
                ['mesh_base_with_head_finer_' char(cases(index)) ...
                '_validation.txt']);
            requirePassedReport(validationFiles(index));
            requireFile(fullfile(resultDir, ...
                ['mesh_base_with_head_finer_' char(cases(index)) ...
                '_summary.txt']));
        end
        result = struct('Action', action, 'Cases', cases, ...
            'ValidationFiles', validationFiles);
        fprintf('Translation inputs and tracked validations are present.\n');

    case "validate"
        requireFile(targetFile);
        cases = ["1mm_zUP", "1mm_zDOWN"];
        reports = cell(numel(cases), 1);
        for index = 1:numel(cases)
            outputFile = translatedOutput(resultDir, cases(index));
            requireFile(outputFile);
            reports{index} = validateDatMeshFile(outputFile, ...
                'ReferenceFile', targetFile, 'ExpectedAddedMaterials', 5);
            assert(all(ismember(25:29, unique(reports{index}.ElementLabels))), ...
                'mainHeadTranslation:MissingHeadLabels', ...
                'Output %s does not contain all expected labels 25-29.', outputFile);
            fprintf('Validated existing translation: %s\n', cases(index));
        end
        result = struct('Action', action, 'Cases', cases, 'Reports', {reports});

    case "map-2mm-down"
        requireFile(sourceFile);
        requireFile(targetFile);
        if exist(resultDir, 'dir') ~= 7
            mkdir(resultDir);
        end
        caseName = "2mm_zDOWN";
        translatedSource = fullfile(inputDir, 'head_finer_2mm_zDOWN.dat');
        translateDatMeshCoordinates( ...
            sourceFile, translatedSource, [0 0 -0.002]);
        outputFile = translatedOutput(resultDir, caseName);
        config = productionConfig(translatedSource, targetFile, outputFile, ...
            fullfile(resultDir, 'mesh_base_with_head_finer_2mm_zDOWN_label_log.txt'));
        result = meshingMapper(config);
        result.Action = action;

    case "visualize-2mm-down"
        outputFile = translatedOutput(resultDir, "2mm_zDOWN");
        requireFile(outputFile);
        figureHandle = visualizeDatLabelGroups( ...
            outputFile, {28, 3:18}, ...
            'GroupNames', ["SKIN", "Antennas"], ...
            'Colors', [1.00 0.00 0.78; 0.48 0.53 0.57], ...
            'Alphas', [0.82; 0.18], ...
            'OutputFolder', resultDir, ...
            'OutputName', 'skin28_antennas3_18_2mm_zDOWN', ...
            'OutputFormats', ["png", "fig"], ...
            'Title', 'Translated 2mm zDOWN: SKIN with antenna labels 3-18');
        result = struct('Action', action, 'OutputFile', outputFile, ...
            'Figure', figureHandle);

    otherwise
        error('mainHeadTranslation:UnknownAction', ...
            ['Action must be "check", "validate", "map-2mm-down", ' ...
            'or "visualize-2mm-down".']);
end

function requirePassedReport(fileName)
requireFile(fileName);
if ~contains(fileread(fileName), 'Validation passed.')
    error('mainHeadTranslation:ValidationNotPassed', ...
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
config.UseParallel = true;
config.Visualization = struct( ...
    'Enabled', true, ...
    'LabelGroups', {{28, 3:18}}, ...
    'GroupNames', ["SKIN", "Antennas"], ...
    'Colors', [1.00 0.00 0.78; 0.48 0.53 0.57], ...
    'Alphas', [0.82; 0.18], ...
    'Visible', 'off', ...
    'OutputFolder', fileparts(outputFile), ...
    'OutputName', 'skin28_antennas3_18_2mm_zDOWN', ...
    'OutputFormats', ["png", "fig"]);
end

function fileName = translatedOutput(resultDir, caseName)
fileName = fullfile(resultDir, ...
    ['mesh_base_with_head_finer_' char(caseName) '.dat']);
end

function requireFile(fileName)
if exist(fileName, 'file') ~= 2
    error('mainHeadTranslation:MissingFile', ...
        'Required file is missing: %s', fileName);
end
end
