function result = meshingMapper(config)
%MESHINGMAPPER User-facing configuration API for DAT label mapping.
%
%   result = MESHINGMAPPER(config) maps labeled source volumes onto a
%   baseline DAT or GiD MSH mesh. DAT optimization fields include
%   UseParallel, ParallelPoolType, UseMex, BuildMex, MexRequired, and
%   MexVerbose. See README.md for complete examples.

if nargin ~= 1 || ~isstruct(config) || ~isscalar(config)
    error('meshingMapper:InvalidConfiguration', ...
        'Configuration must be one scalar struct.');
end

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'Lib'));
mexFolder = fullfile(repoRoot, 'mex');
addpath(mexFolder);

sourceFile = requiredText(config, 'SourceFile');
if isfield(config, 'BaselineFile')
    targetFile = requiredText(config, 'BaselineFile');
else
    targetFile = requiredText(config, 'TargetFile');
end
outputFile = optionalText(config, 'OutputFile', defaultOutputFile(targetFile));
logFile = optionalText(config, 'LogFile', defaultLogFile(outputFile));

ensureInputFile(sourceFile, 'source');
ensureInputFile(targetFile, 'target');
ensureParentFolder(outputFile);
ensureParentFolder(logFile);

[~, ~, sourceExtension] = fileparts(sourceFile);
[~, ~, targetExtension] = fileparts(targetFile);
if strcmpi(sourceExtension, '.msh') && strcmpi(targetExtension, '.msh')
    result = mapMshFiles(config, sourceFile, targetFile, outputFile);
    return;
elseif ~strcmpi(sourceExtension, '.dat') || ~strcmpi(targetExtension, '.dat')
    error('meshingMapper:MixedOrUnsupportedFormats', ...
        'SourceFile and TargetFile must both be DAT files or both be GiD MSH files.');
end

optimization = prepareDatOptimization(config);
options = {'OutputDatFile', outputFile, 'LogFile', logFile};
optionFields = {
    'TargetLabels', 'TargetLabels'
    'InputLabels', 'InputLabels'
    'NewLabels', 'NewLabels'
    'TargetLabelNames', 'TargetLabelNames'
    'InputLabelNames', 'InputLabelNames'
    'NewLabelNames', 'NewLabelNames'
    'PromptForNewLabelNames', 'PromptForNewLabelNames'
    'Tolerance', 'Tolerance'
    'ChunkSize', 'ChunkSize'
    'SourceCentroidRepair', 'SourceCentroidRepair'
    'RepairFallbackTargetLabels', 'RepairFallbackTargetLabels'
    'FillUnmappedTargetLabels', 'FillUnmappedTargetLabels'
    'HoleRepairTargetLabels', 'HoleRepairTargetLabels'
    'HoleRepairMaxPasses', 'HoleRepairMaxPasses'
    'HoleRepairMinNodeVotes', 'HoleRepairMinNodeVotes'
    'TargetSurfaceDistanceFilterLabels', 'TargetSurfaceDistanceFilterLabels'
    'TargetSurfaceDistance', 'TargetSurfaceDistance'
    'UseParallel', 'UseParallel'
    'ParallelPoolType', 'ParallelPoolType'
    'ParallelWorkers', 'ParallelWorkers'};

for row = 1:size(optionFields, 1)
    fieldName = optionFields{row, 1};
    if isfield(config, fieldName)
        options(end + 1:end + 2) = {optionFields{row, 2}, config.(fieldName)};
    end
end
options(end + 1:end + 4) = { ...
    'UseMex', optimization.UseMex, ...
    'MexRequired', optimization.MexRequired};

[mappedLabels, info] = mapDatMeshLabels(sourceFile, targetFile, options{:});
info.optimizationInfo.mexBuildRequested = optimization.BuildMex;
info.optimizationInfo.mexBuildSucceeded = optimization.BuildSucceeded;
info.optimizationInfo.mexBuildOutputFiles = optimization.BuildOutputFiles;
validation = validateDatMeshFile(outputFile, 'ReferenceFile', targetFile, ...
    'ExpectedAddedMaterials', numel(info.newLabels));
figureHandle = createVisualization(config, outputFile, info);

result = struct();
result.OutputFile = outputFile;
result.LogFile = logFile;
result.MappedLabels = mappedLabels;
result.MapInfo = info;
result.Validation = validation;
result.Figure = figureHandle;

fprintf('Meshing-Mapper completed.\n');
fprintf('  Output DAT: %s\n', outputFile);
fprintf('  Label log:  %s\n', logFile);
fprintf('  Elements:   %d\n', validation.ElementCount);
fprintf('  Parallel:   requested=%d, enabled=%d\n', ...
    info.optimizationInfo.useParallelRequested, ...
    info.optimizationInfo.useParallel);
fprintf('  MEX:        requested=%d, enabled=%d, available=%d\n', ...
    info.optimizationInfo.useMexRequested, ...
    info.optimizationInfo.useMex, ...
    info.optimizationInfo.mexPointLocatorAvailable);
end

function optimization = prepareDatOptimization(config)
optimization = struct();
optimization.BuildMex = logicalField(config, 'BuildMex', false);
optimization.MexRequired = logicalField(config, 'MexRequired', false);
optimization.BuildSucceeded = false;
optimization.BuildOutputFiles = strings(0, 1);

if optimization.BuildMex
    verbose = logicalField(config, 'MexVerbose', false);
    buildFolder = tempname;
    mkdir(buildFolder);
    try
        optimization.BuildOutputFiles = buildMeshingMapperMex( ...
            'OutputFolder', buildFolder, 'Verbose', verbose);
        optimization.BuildSucceeded = true;
        addpath(buildFolder, '-begin');
        rehash;
    catch exception
        if optimization.MexRequired
            throwAsCaller(exception);
        end
        warning('meshingMapper:MexBuildFailed', ...
            'MEX build failed; continuing with MATLAB fallback: %s', ...
            exception.message);
    end
end

mexAvailable = exist('locatePointsInTetsMex', 'file') == 3;
useMexSetting = textOrLogicalField(config, 'UseMex', "auto");
if islogical(useMexSetting)
    useMexRequested = useMexSetting;
else
    switch lower(useMexSetting)
        case "auto"
            useMexRequested = mexAvailable;
        case {"on", "true"}
            useMexRequested = true;
        case {"off", "false"}
            useMexRequested = false;
        otherwise
            error('meshingMapper:InvalidUseMex', ...
                'UseMex must be true, false, "auto", "on", or "off".');
    end
end
if optimization.MexRequired
    explicitlyDisabled = (islogical(useMexSetting) && ~useMexSetting) || ...
        (~islogical(useMexSetting) && ismember(lower(useMexSetting), ["off", "false"]));
    if explicitlyDisabled
        error('meshingMapper:ConflictingMexSettings', ...
            'MexRequired=true cannot be combined with UseMex=false or "off".');
    end
    useMexRequested = true;
end

if useMexRequested && ~mexAvailable
    if optimization.MexRequired
        error('meshingMapper:MexRequiredUnavailable', ...
            ['MEX execution was required, but locatePointsInTetsMex.%s ' ...
            'is not available. Set BuildMex=true or configure a compiler.'], ...
            mexext);
    end
    warning('meshingMapper:MexUnavailable', ...
        'UseMex was requested, but no compatible MEX exists; using MATLAB fallback.');
end
optimization.UseMex = useMexRequested && mexAvailable;
end

function result = mapMshFiles(config, sourceFile, targetFile, outputFile)
requestedUnsupported = requestedMshOptimizationFields(config);
if ~isempty(requestedUnsupported)
    warning('meshingMapper:MshOptimizationUnsupported', ...
        ['Optimization settings %s apply to DAT mapping only. ' ...
        'The GiD MSH mapper currently runs with MATLAB serial execution.'], ...
        strjoin(requestedUnsupported, ', '));
end

options = {'WriteMappedMesh', outputFile};
if isfield(config, 'SourceLabels')
    options(end + 1:end + 2) = {'SourceLabels', config.SourceLabels};
end
if isfield(config, 'InputLabels')
    options(end + 1:end + 2) = {'InputLabels', config.InputLabels};
end
if isfield(config, 'NewLabels')
    options(end + 1:end + 2) = {'NewLabels', config.NewLabels};
end
if isfield(config, 'TargetLabels')
    options(end + 1:end + 2) = {'TargetLabels', config.TargetLabels};
end
if isfield(config, 'BackgroundLabel')
    options(end + 1:end + 2) = {'BackgroundLabel', config.BackgroundLabel};
end
if isfield(config, 'Tolerance')
    options(end + 1:end + 2) = {'Tolerance', config.Tolerance};
end

[mappedLabels, info] = map3DMeshLabels(sourceFile, targetFile, options{:});
result = struct();
result.OutputFile = outputFile;
result.LogFile = '';
result.MappedLabels = mappedLabels;
result.MapInfo = info;
result.Validation = struct('Valid', true, ...
    'AssignedFraction', info.assignedFraction);
result.Figure = gobjects(0);
result.MapInfo.optimizationInfo = struct( ...
    'useParallelRequested', false, ...
    'useParallel', false, ...
    'useMexRequested', false, ...
    'useMex', false, ...
    'note', 'GiD MSH mapping currently uses MATLAB serial execution.');

fprintf('Meshing-Mapper completed for GiD MSH files.\n');
fprintf('  Output MSH: %s\n', outputFile);
fprintf('  Assigned target fraction: %.6f\n', info.assignedFraction);
end

function names = requestedMshOptimizationFields(config)
names = strings(0, 1);
if isfield(config, 'UseParallel') && logical(config.UseParallel)
    names(end + 1, 1) = "UseParallel";
    if isfield(config, 'ParallelPoolType')
        names(end + 1, 1) = "ParallelPoolType";
    end
    if isfield(config, 'ParallelWorkers')
        names(end + 1, 1) = "ParallelWorkers";
    end
end
if isfield(config, 'UseMex')
    value = config.UseMex;
    requested = (islogical(value) && value) || ...
        (~islogical(value) && ~ismember(lower(string(value)), ["auto", "off", "false"]));
    if requested
        names(end + 1, 1) = "UseMex";
    end
end
for fieldName = ["BuildMex", "MexRequired", "MexVerbose"]
    if isfield(config, fieldName) && logical(config.(fieldName))
        names(end + 1, 1) = fieldName; %#ok<AGROW>
    end
end
names = cellstr(names);
end

function figureHandle = createVisualization(config, outputFile, info)
figureHandle = gobjects(0);
if ~isfield(config, 'Visualization') || isempty(config.Visualization)
    return;
end

visual = config.Visualization;
if islogical(visual)
    visual = struct('Enabled', visual);
end
if ~isstruct(visual) || ~isscalar(visual)
    error('meshingMapper:InvalidVisualization', ...
        'Visualization must be a logical value or scalar struct.');
end
if isfield(visual, 'Enabled') && ~logical(visual.Enabled)
    return;
end

labelGroups = num2cell(info.newLabels(:));
if isfield(visual, 'LabelGroups')
    labelGroups = visual.LabelGroups;
end

options = {};
fields = {
    'GroupNames', 'GroupNames'
    'Colors', 'Colors'
    'Alphas', 'Alphas'
    'OutputFolder', 'OutputFolder'
    'OutputName', 'OutputName'
    'OutputFormats', 'OutputFormats'
    'Visible', 'Visible'
    'Title', 'Title'
    'View', 'View'
    'Resolution', 'Resolution'};
for row = 1:size(fields, 1)
    if isfield(visual, fields{row, 1})
        options(end + 1:end + 2) = {fields{row, 2}, visual.(fields{row, 1})};
    end
end

figureHandle = visualizeDatLabelGroups(outputFile, labelGroups, options{:});
end

function value = requiredText(config, fieldName)
if ~isfield(config, fieldName)
    error('meshingMapper:MissingConfiguration', ...
        'Missing required configuration field "%s".', fieldName);
end
value = char(string(config.(fieldName)));
if isempty(strtrim(value))
    error('meshingMapper:EmptyConfiguration', ...
        'Configuration field "%s" must not be empty.', fieldName);
end
end

function value = optionalText(config, fieldName, defaultValue)
if isfield(config, fieldName) && strlength(string(config.(fieldName))) > 0
    value = char(string(config.(fieldName)));
else
    value = defaultValue;
end
end

function value = logicalField(config, fieldName, defaultValue)
if isfield(config, fieldName)
    value = config.(fieldName);
    if ~islogical(value) || ~isscalar(value)
        error('meshingMapper:InvalidLogicalSetting', ...
            '%s must be one logical scalar.', fieldName);
    end
else
    value = defaultValue;
end
end

function value = textOrLogicalField(config, fieldName, defaultValue)
if ~isfield(config, fieldName)
    value = defaultValue;
    return;
end
value = config.(fieldName);
if islogical(value) && isscalar(value)
    return;
end
if ischar(value) || (isstring(value) && isscalar(value))
    value = string(value);
    return;
end
error('meshingMapper:InvalidOptimizationSetting', ...
    '%s must be a logical scalar or text scalar.', fieldName);
end

function fileName = defaultOutputFile(targetFile)
[folder, name, extension] = fileparts(targetFile);
if strcmpi(extension, '.msh')
    fileName = fullfile(folder, [name '_mapped.msh']);
else
    fileName = fullfile(folder, [name '_mapped.dat']);
end
end

function fileName = defaultLogFile(outputFile)
[folder, name] = fileparts(outputFile);
fileName = fullfile(folder, [name '_label_log.txt']);
end

function ensureInputFile(fileName, role)
if exist(fileName, 'file') ~= 2
    error('meshingMapper:MissingInputFile', ...
        'The %s file does not exist: %s', role, fileName);
end
end

function ensureParentFolder(fileName)
folder = fileparts(fileName);
if ~isempty(folder) && exist(folder, 'dir') ~= 7
    mkdir(folder);
end
end
