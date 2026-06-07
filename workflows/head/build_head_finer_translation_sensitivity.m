%BUILD_HEAD_FINER_TRANSLATION_SENSITIVITY Map 1 mm translated head variants.
%
% The source mesh coordinates are translated only in Z. Topology, element
% labels, and material properties are kept unchanged. Each translated source
% is then mapped onto mesh_base.dat using the conservative base/finer setup.

clear;
clc;

repoRoot = getRepoRoot();
addpath(fullfile(repoRoot, 'Lib'));
addpath(fullfile(repoRoot, 'mex'));

inputDir = fullfile(repoRoot, 'input');
resultDir = fullfile(repoRoot, 'result', 'base_finer_translations');
if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end

[baselineHeadDatFile, targetDatFile] = resolveHeadInputFiles(inputDir);

headLabels = (1:5).';
headNames = ["gray"; "CSF"; "FAT"; "SKIN"; "SKULL"];
mappingTargetLabels = [20:24, 19];
surfaceTargetLabels = 19;
surfaceSearchDistance = 0.01; % 1 cm in mesh units.
chunkSize = 250000;
useParallel = logicalEnv('HEAD_TRANSLATION_USE_PARALLEL', true);
compileMex = logicalEnv('HEAD_TRANSLATION_COMPILE_MEX', true);
skipCompleted = logicalEnv('HEAD_TRANSLATION_SKIP_COMPLETED', true);
requestedCases = requestedCaseNames();
outputFormats = ["png", "fig"];

if compileMex
    try
        buildMeshingMapperMex;
    catch exception
        warning('buildHeadFinerTranslationSensitivity:MexBuildFailed', ...
            'Optional C++ MEX build failed; continuing with MATLAB fallback: %s', ...
            exception.message);
    end
end

cases = struct( ...
    'Name', {'1mm_zUP', '1mm_zDOWN', '2mm_zDOWN'}, ...
    'TranslationVector', {[0 0 0.001], [0 0 -0.001], [0 0 -0.002]});

for caseIndex = 1:numel(cases)
    caseName = cases(caseIndex).Name;
    if ~isempty(requestedCases) && ~ismember(string(caseName), requestedCases)
        fprintf('\nSkipping %s because it is not in HEAD_TRANSLATION_CASES.\n', caseName);
        continue;
    end

    translationVector = cases(caseIndex).TranslationVector;
    translatedDatFile = fullfile(inputDir, ['head_finer_' caseName '.dat']);
    outputDatFile = fullfile(resultDir, ['mesh_base_with_head_finer_' caseName '.dat']);
    logFile = fullfile(resultDir, ['mesh_base_with_head_finer_' caseName '_label_log.txt']);
    summaryFile = fullfile(resultDir, ['mesh_base_with_head_finer_' caseName '_summary.txt']);
    validationFile = fullfile(resultDir, ['mesh_base_with_head_finer_' caseName '_validation.txt']);
    visualizationStem = ['skin28_antennas3_18_' caseName];

    if skipCompleted && caseOutputsComplete(resultDir, outputDatFile, logFile, ...
            summaryFile, validationFile, visualizationStem, outputFormats)
        fprintf('\nSkipping completed case %s.\n', caseName);
        continue;
    end

    fprintf('\nCreating translated source %s...\n', caseName);
    transformInfo = translateDatMeshCoordinates( ...
        baselineHeadDatFile, ...
        translatedDatFile, ...
        translationVector);
    fprintf('  Translation vector [m]: %s\n', mat2str(translationVector));
    fprintf('  Translated DAT: %s\n', translatedDatFile);

    fprintf('\nMapping %s onto base mesh...\n', caseName);
    timer = tic;
    [~, mapInfo] = mapDatMeshLabels( ...
        translatedDatFile, ...
        targetDatFile, ...
        'InputLabels', headLabels, ...
        'InputLabelNames', headNames, ...
        'NewLabelNames', headNames, ...
        'TargetLabels', mappingTargetLabels, ...
        'TargetSurfaceDistanceFilterLabels', surfaceTargetLabels, ...
        'TargetSurfaceDistance', surfaceSearchDistance, ...
        'SourceCentroidRepair', true, ...
        'OutputDatFile', outputDatFile, ...
        'LogFile', logFile, ...
        'ChunkSize', chunkSize, ...
        'UseParallel', useParallel);
    elapsedSeconds = toc(timer);

    writeTranslationSummary(summaryFile, caseName, transformInfo, mapInfo, ...
        mappingTargetLabels, surfaceTargetLabels, surfaceSearchDistance, elapsedSeconds);
    validateRemappedDatSyntax(targetDatFile, outputDatFile, validationFile, numel(headLabels));

    figureHandle = visualizeDatLabelGroups( ...
        outputDatFile, ...
        {28, 3:18}, ...
        'GroupNames', ["SKIN", "Antennas"], ...
        'Colors', [1.00 0.00 0.78; 0.48 0.53 0.57], ...
        'Alphas', [0.82; 0.18], ...
        'OutputFolder', resultDir, ...
        'OutputName', visualizationStem, ...
        'OutputFormats', outputFormats, ...
        'Visible', 'off', ...
        'Title', ['Translated ' caseName ': SKIN with antenna labels 3-18']);
    close(figureHandle);

    fprintf('Finished %s in %.1f seconds.\n', caseName, elapsedSeconds);
    fprintf('  Remapped DAT: %s\n', outputDatFile);
    fprintf('  Summary:      %s\n', summaryFile);
    fprintf('  Validation:   %s\n', validationFile);
end

fprintf('\nTranslation sensitivity results saved in:\n  %s\n', resultDir);

function writeTranslationSummary(summaryFile, caseName, transformInfo, mapInfo, ...
    mappingTargetLabels, surfaceTargetLabels, surfaceSearchDistance, elapsedSeconds)
fid = fopen(summaryFile, 'w');
if fid < 0
    error('buildHeadFinerTranslationSensitivity:SummaryWriteFailed', ...
        'Could not write summary file: %s', summaryFile);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'Base/finer translated head mapping summary\n');
fprintf(fid, 'Case: %s\n', caseName);
fprintf(fid, 'Created: %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
fprintf(fid, 'Source DAT: %s\n', transformInfo.outputMeshFile);
fprintf(fid, 'Target DAT: %s\n', mapInfo.targetMesh.fileName);
fprintf(fid, 'Output DAT: %s\n', mapInfo.outputDatFile);
fprintf(fid, 'Translation vector [m]: %s\n', mat2str(transformInfo.translationVector));
fprintf(fid, 'Original source bounding box:\n');
fprintf(fid, '  min: %s\n', mat2str(transformInfo.originalBoundingBox(1, :), 9));
fprintf(fid, '  max: %s\n', mat2str(transformInfo.originalBoundingBox(2, :), 9));
fprintf(fid, 'Translated source bounding box:\n');
fprintf(fid, '  min: %s\n', mat2str(transformInfo.transformedBoundingBox(1, :), 9));
fprintf(fid, '  max: %s\n', mat2str(transformInfo.transformedBoundingBox(2, :), 9));
fprintf(fid, 'Target labels searched: %s\n', joinNumbers(mappingTargetLabels));
fprintf(fid, 'Surface-filter target labels: %s\n', joinNumbers(surfaceTargetLabels));
fprintf(fid, 'Surface-filter distance: %.15g\n', surfaceSearchDistance);
fprintf(fid, 'Elapsed mapping time [s]: %.3f\n', elapsedSeconds);
fprintf(fid, 'Parallel requested: %d\n', mapInfo.optimizationInfo.useParallelRequested);
fprintf(fid, 'Parallel enabled: %d\n', mapInfo.optimizationInfo.useParallel);
fprintf(fid, 'MEX point locator available: %d\n', ...
    mapInfo.optimizationInfo.mexPointLocatorAvailable);

fprintf(fid, '\nMapping counts\n');
for row = 1:height(mapInfo.labelMap)
    fprintf(fid, '  %g (%s) -> %g (%s): %d target elements\n', ...
        mapInfo.labelMap.InputLabel(row), ...
        char(mapInfo.labelMap.InputLabelName(row)), ...
        mapInfo.labelMap.NewTargetLabel(row), ...
        char(mapInfo.labelMap.NewTargetLabelName(row)), ...
        mapInfo.labelMap.MappedTargetElements(row));
end

fprintf(fid, '\nSource-centroid repair\n');
fprintf(fid, '  Located source elements: %d\n', mapInfo.repairInfo.locatedSourceElements);
fprintf(fid, '  Unlocated source elements: %d\n', mapInfo.repairInfo.unlocatedSourceElements);
fprintf(fid, '  Repaired target elements: %d\n', mapInfo.repairInfo.repairedTargetElements);

if mapInfo.surfaceFilterInfo.enabled
    fprintf(fid, '\nSurface-distance target filter\n');
    fprintf(fid, '  Initial candidate target elements: %d\n', ...
        mapInfo.surfaceFilterInfo.initialCandidateElements);
    fprintf(fid, '  Kept filtered-label elements: %d\n', ...
        mapInfo.surfaceFilterInfo.keptFilteredLabelElements);
    fprintf(fid, '  Removed filtered-label elements: %d\n', ...
        mapInfo.surfaceFilterInfo.removedFilteredLabelElements);
end
end

function validateRemappedDatSyntax(referenceDatFile, remappedDatFile, reportFile, addedMaterialCount)
reportId = fopen(reportFile, 'w');
if reportId < 0
    error('buildHeadFinerTranslationSensitivity:ValidationWriteFailed', ...
        'Could not write validation report: %s', reportFile);
end
cleanupReport = onCleanup(@() fclose(reportId));

referenceInfo = readDatBlockInfo(referenceDatFile);
remappedInfo = readDatBlockInfo(remappedDatFile);

logLine(reportId, 'Translated head remap DAT validation');
logLine(reportId, 'Reference DAT: %s', referenceDatFile);
logLine(reportId, 'Remapped DAT:  %s', remappedDatFile);
logLine(reportId, '');
logLine(reportId, 'Block counts');
logLine(reportId, '  Coordinates: reference %d, remapped %d', ...
    referenceInfo.coordinateCount, remappedInfo.coordinateCount);
logLine(reportId, '  Elements:    reference %d, remapped %d', ...
    referenceInfo.elementCount, remappedInfo.elementCount);
logLine(reportId, '  Materials:   reference %d, remapped %d', ...
    referenceInfo.materialCount, remappedInfo.materialCount);

assert(referenceInfo.coordinateCount == remappedInfo.coordinateCount, ...
    'Coordinate count changed between reference and remapped DAT files.');
assert(referenceInfo.elementCount == remappedInfo.elementCount, ...
    'Element count changed between reference and remapped DAT files.');
assert(remappedInfo.materialCount == referenceInfo.materialCount + addedMaterialCount, ...
    'Unexpected remapped material-property count.');

[labels, counts] = validateElementsAndCountLabels(remappedDatFile, remappedInfo.elementCount);
validateCoordinates(remappedDatFile, remappedInfo.coordinateCount);
validateMaterialProperties(remappedDatFile, remappedInfo.materialCount);

logLine(reportId, '');
logLine(reportId, 'Remapped element label counts');
for row = 1:numel(labels)
    logLine(reportId, '  Label %g: %d', labels(row), counts(row));
end

logLine(reportId, '');
logLine(reportId, 'Validation passed.');
end

function info = readDatBlockInfo(datFile)
fid = fopen(datFile, 'r');
if fid < 0
    error('buildHeadFinerTranslationSensitivity:OpenFailed', ...
        'Could not open file: %s', datFile);
end
cleanup = onCleanup(@() fclose(fid));

seekSection(fid, 'Coordinates', datFile);
info.coordinateCount = parseCount(fgetl(fid), 'Coordinates', datFile);

seekSection(fid, 'Elements', datFile);
info.elementCount = parseCount(fgetl(fid), 'Elements', datFile);

seekSection(fid, 'Material properties', datFile);
info.materialCount = parseCount(fgetl(fid), 'Material properties', datFile);
end

function validateCoordinates(datFile, expectedCount)
fid = fopen(datFile, 'r');
if fid < 0
    error('buildHeadFinerTranslationSensitivity:OpenFailed', ...
        'Could not open file: %s', datFile);
end
cleanup = onCleanup(@() fclose(fid));

seekSection(fid, 'Coordinates', datFile);
coordinateCount = parseCount(fgetl(fid), 'Coordinates', datFile);
assert(coordinateCount == expectedCount, 'Unexpected coordinate count.');

coordinateData = textscan(fid, '%f %f %f', coordinateCount, 'CollectOutput', true);
if size(coordinateData{1}, 1) ~= coordinateCount
    error('buildHeadFinerTranslationSensitivity:BadCoordinates', ...
        'Could not parse all coordinate rows in %s.', datFile);
end

endLine = readNextNonemptyLine(fid);
assert(strcmpi(endLine, 'end Coordinates'), ...
    'Expected "end Coordinates" after coordinate block.');
end

function [labels, counts] = validateElementsAndCountLabels(datFile, expectedCount)
fid = fopen(datFile, 'r');
if fid < 0
    error('buildHeadFinerTranslationSensitivity:OpenFailed', ...
        'Could not open file: %s', datFile);
end
cleanup = onCleanup(@() fclose(fid));

seekSection(fid, 'Elements', datFile);
elementCount = parseCount(fgetl(fid), 'Elements', datFile);
assert(elementCount == expectedCount, 'Unexpected element count.');

labelCounts = containers.Map('KeyType', 'double', 'ValueType', 'double');
chunkSize = 250000;
remaining = elementCount;
while remaining > 0
    rowsToRead = min(chunkSize, remaining);
    elementData = textscan(fid, '%f %f %f %f %f', rowsToRead, 'CollectOutput', true);
    elementData = elementData{1};
    if size(elementData, 1) ~= rowsToRead
        error('buildHeadFinerTranslationSensitivity:BadElements', ...
            'Could not parse all element rows in %s.', datFile);
    end

    chunkLabels = elementData(:, 5);
    uniqueLabels = unique(chunkLabels);
    for labelIndex = 1:numel(uniqueLabels)
        label = uniqueLabels(labelIndex);
        count = nnz(chunkLabels == label);
        if isKey(labelCounts, label)
            labelCounts(label) = labelCounts(label) + count;
        else
            labelCounts(label) = count;
        end
    end
    remaining = remaining - rowsToRead;
end

endLine = readNextNonemptyLine(fid);
assert(strcmpi(endLine, 'end Elements'), ...
    'Expected "end Elements" after element block.');

labels = sort(cell2mat(labelCounts.keys)).';
counts = zeros(size(labels));
for labelIndex = 1:numel(labels)
    counts(labelIndex) = labelCounts(labels(labelIndex));
end
end

function validateMaterialProperties(datFile, expectedCount)
fid = fopen(datFile, 'r');
if fid < 0
    error('buildHeadFinerTranslationSensitivity:OpenFailed', ...
        'Could not open file: %s', datFile);
end
cleanup = onCleanup(@() fclose(fid));

seekSection(fid, 'Material properties', datFile);
materialCount = parseCount(fgetl(fid), 'Material properties', datFile);
assert(materialCount == expectedCount, 'Unexpected material-property count.');

line = fgetl(fid);
if ischar(line) && startsWith(strtrim(line), '#')
    line = fgetl(fid);
end

for row = 1:materialCount
    rowValues = sscanf(strtrim(line), '%f').';
    if numel(rowValues) < 6
        error('buildHeadFinerTranslationSensitivity:BadMaterialRow', ...
            'Invalid material-property row %d in %s.', row, datFile);
    end
    if row < materialCount
        line = fgetl(fid);
    end
end
end

function seekSection(fid, sectionName, datFile)
line = fgetl(fid);
while ischar(line)
    if strcmpi(strtrim(line), sectionName)
        return;
    end
    line = fgetl(fid);
end

error('buildHeadFinerTranslationSensitivity:MissingSection', ...
    'Could not find section "%s" in %s.', sectionName, datFile);
end

function line = readNextNonemptyLine(fid)
line = strtrim(fgetl(fid));
while ischar(line) && strlength(line) == 0
    line = strtrim(fgetl(fid));
end
end

function count = parseCount(line, sectionName, datFile)
count = sscanf(strtrim(line), '%d', 1);
if isempty(count) || count < 0
    error('buildHeadFinerTranslationSensitivity:BadCount', ...
        'Invalid %s count in %s: %s', sectionName, datFile, line);
end
end

function text = joinNumbers(values)
text = strjoin(compose('%.15g', values(:).'), ', ');
end

function logLine(fid, varargin)
if nargin == 1
    text = '';
else
    text = sprintf(varargin{:});
end
fprintf('%s\n', text);
fprintf(fid, '%s\n', text);
end

function value = logicalEnv(name, defaultValue)
rawValue = strtrim(string(getenv(name)));
if rawValue == ""
    value = defaultValue;
    return;
end

value = any(strcmpi(rawValue, ["1", "true", "yes", "on"]));
end

function names = requestedCaseNames()
rawValue = strtrim(string(getenv('HEAD_TRANSLATION_CASES')));
if rawValue == ""
    names = strings(0, 1);
    return;
end

names = strtrim(split(rawValue, ','));
names = names(names ~= "");
end

function tf = caseOutputsComplete(resultDir, outputDatFile, logFile, ...
    summaryFile, validationFile, visualizationStem, outputFormats)
requiredFiles = string({outputDatFile; logFile; summaryFile; validationFile});
for formatIndex = 1:numel(outputFormats)
    requiredFiles(end + 1, 1) = string(fullfile(resultDir, ...
        [visualizationStem '.' char(outputFormats(formatIndex))])); %#ok<AGROW>
end

tf = all(arrayfun(@(fileName) exist(char(fileName), 'file') == 2, requiredFiles));
end

function repoRoot = getRepoRoot()
scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    repoRoot = pwd;
else
    repoRoot = fileparts(fileparts(fileparts(scriptPath)));
end
end
