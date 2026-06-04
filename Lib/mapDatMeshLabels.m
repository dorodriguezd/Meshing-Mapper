function [mappedTargetLabels, info] = mapDatMeshLabels(inputDatFile, targetDatFile, varargin)
%MAPDATMESHLABELS Project labeled volumes from an input .dat mesh to a target .dat mesh.
%
%   mappedTargetLabels = MAPDATMESHLABELS(inputDatFile, targetDatFile)
%   reads two custom problem-type .dat tetrahedral meshes. Target elements
%   whose centroids are inside an input volume receive new material labels;
%   all other target labels are preserved.
%
%   [mappedTargetLabels, info] = MAPDATMESHLABELS(...) also returns parsed
%   meshes, old-to-new label pairs, and mapping statistics.
%
%   Name-value options:
%       'TargetLabels'   Existing target material labels allowed to be
%                        remapped. Default: all target labels.
%       'InputLabels'    Input material labels to project. Default: all
%                        input labels.
%       'NewLabels'      New target labels for each selected input label.
%                        Default: max(existing target label) + 1, +2, ...
%       'TargetLabelNames'
%                        Names for the existing target labels, in sorted
%                        label order. Used in logs and plots.
%       'InputLabelNames'
%                        Names for selected input labels, in InputLabels
%                        order. Used in the remap log.
%       'NewLabelNames'  Names for each new output label, in NewLabels
%                        order. When omitted, default names are generated.
%       'PromptForNewLabelNames'
%                        Prompt in the MATLAB Command Window for missing
%                        new label names. Default: false.
%       'OutputDatFile'  Name/path for the remapped .dat file. Default:
%                        <target name>_mapped.dat.
%       'LogFile'        Name/path for the label mapping log. Default:
%                        <output name>_label_log.txt.
%       'Tolerance'      Barycentric tolerance for the fallback point
%                        locator. Default: 1e-10.
%       'ChunkSize'      Number of target elements processed at a time for
%                        centroid point-location. Default: 250000.
%       'SourceCentroidRepair'
%                        Also locate source element centroids inside the
%                        selected target subdomains and label the containing
%                        target elements by source-label majority. This
%                        improves source-volume coverage for large/remeshed
%                        targets. Default: false.
%       'RepairFallbackTargetLabels'
%                        Extra target labels used only by the source-centroid
%                        repair pass. They are not part of the regular
%                        target-centroid projection. Default: [].
%       'FillUnmappedTargetLabels'
%                        Existing target labels that must not remain after
%                        mapping. Any still-unmapped elements with these
%                        labels are assigned from the containing source
%                        element, or the nearest source centroid when they
%                        fall outside the source mesh. Default: [].

parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, 'inputDatFile', @isTextScalar);
addRequired(parser, 'targetDatFile', @isTextScalar);
addParameter(parser, 'TargetLabels', [], @(x) isnumeric(x) || islogical(x));
addParameter(parser, 'InputLabels', [], @(x) isnumeric(x) || islogical(x));
addParameter(parser, 'NewLabels', [], @(x) isnumeric(x) || islogical(x));
addParameter(parser, 'TargetLabelNames', strings(0, 1), @isTextVector);
addParameter(parser, 'InputLabelNames', strings(0, 1), @isTextVector);
addParameter(parser, 'NewLabelNames', strings(0, 1), @isTextVector);
addParameter(parser, 'PromptForNewLabelNames', false, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'OutputDatFile', '', @isTextScalar);
addParameter(parser, 'LogFile', '', @isTextScalar);
addParameter(parser, 'Tolerance', 1e-10, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(parser, 'ChunkSize', 250000, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(parser, 'SourceCentroidRepair', false, @(x) islogical(x) && isscalar(x));
addParameter(parser, 'RepairFallbackTargetLabels', [], @(x) isnumeric(x) || islogical(x));
addParameter(parser, 'FillUnmappedTargetLabels', [], @(x) isnumeric(x) || islogical(x));
parse(parser, inputDatFile, targetDatFile, varargin{:});

inputDatFile = char(parser.Results.inputDatFile);
targetDatFile = char(parser.Results.targetDatFile);

inputMesh = readProblemDatMesh(inputDatFile);
targetMesh = readProblemDatMesh(targetDatFile);

inputLabels = numericColumn(parser.Results.InputLabels);
if isempty(inputLabels)
    inputLabels = unique(inputMesh.elementLabels, 'stable');
else
    missingInputLabels = setdiff(inputLabels, unique(inputMesh.elementLabels));
    if ~isempty(missingInputLabels)
        error('mapDatMeshLabels:MissingInputLabels', ...
            'Input labels not found in %s: %s', inputDatFile, joinNumbers(missingInputLabels));
    end
end

targetLabelsToMap = numericColumn(parser.Results.TargetLabels);
if isempty(targetLabelsToMap)
    targetLabelsToMap = unique(targetMesh.elementLabels, 'stable');
else
    missingTargetLabels = setdiff(targetLabelsToMap, unique(targetMesh.elementLabels));
    if ~isempty(missingTargetLabels)
        error('mapDatMeshLabels:MissingTargetLabels', ...
            'Target labels not found in %s: %s', targetDatFile, joinNumbers(missingTargetLabels));
    end
end

repairFallbackTargetLabels = numericColumn(parser.Results.RepairFallbackTargetLabels);
if ~isempty(repairFallbackTargetLabels)
    missingFallbackLabels = setdiff(repairFallbackTargetLabels, unique(targetMesh.elementLabels));
    if ~isempty(missingFallbackLabels)
        error('mapDatMeshLabels:MissingFallbackTargetLabels', ...
            'Repair fallback target labels not found in %s: %s', ...
            targetDatFile, joinNumbers(missingFallbackLabels));
    end
end

fillUnmappedTargetLabels = numericColumn(parser.Results.FillUnmappedTargetLabels);
if ~isempty(fillUnmappedTargetLabels)
    missingFillLabels = setdiff(fillUnmappedTargetLabels, unique(targetMesh.elementLabels));
    if ~isempty(missingFillLabels)
        error('mapDatMeshLabels:MissingFillTargetLabels', ...
            'Fill-unmapped target labels not found in %s: %s', ...
            targetDatFile, joinNumbers(missingFillLabels));
    end
end

newLabels = numericColumn(parser.Results.NewLabels);
if isempty(newLabels)
    existingLabels = unique([targetMesh.elementLabels; targetMesh.materialLabels]);
    nextLabel = max(existingLabels) + 1;
    newLabels = nextLabel:(nextLabel + numel(inputLabels) - 1);
    newLabels = newLabels(:);
elseif numel(newLabels) ~= numel(inputLabels)
    error('mapDatMeshLabels:NewLabelCountMismatch', ...
        'NewLabels must contain one value per selected input label.');
else
    newLabels = newLabels(:);
end

if any(ismember(newLabels, targetMesh.elementLabels)) || any(ismember(newLabels, targetMesh.materialLabels))
    error('mapDatMeshLabels:NewLabelConflict', ...
        'NewLabels must not already exist in the target mesh/material table.');
end

existingOutputLabels = sort(unique([targetMesh.elementLabels; targetMesh.materialLabels]));
targetLabelNames = normalizeLabelNames( ...
    parser.Results.TargetLabelNames, existingOutputLabels, 'target');
inputLabelNames = normalizeLabelNames( ...
    parser.Results.InputLabelNames, inputLabels, 'input');
if isempty(inputLabelNames)
    inputLabelNames = defaultLabelNames(inputLabels, 'input_label');
end
newLabelNames = normalizeLabelNames( ...
    parser.Results.NewLabelNames, newLabels, 'new');
if isempty(newLabelNames) && parser.Results.PromptForNewLabelNames
    newLabelNames = promptForLabelNames(inputLabels, newLabels);
end
if isempty(newLabelNames)
    newLabelNames = defaultLabelNames(newLabels, 'mapped_label');
end
outputLabelTable = makeOutputLabelTable( ...
    existingOutputLabels, targetLabelNames, newLabels, newLabelNames);

outputDatFile = char(parser.Results.OutputDatFile);
if isempty(outputDatFile)
    [folder, name] = fileparts(targetDatFile);
    outputDatFile = fullfile(folder, [name '_mapped.dat']);
end

logFile = char(parser.Results.LogFile);
if isempty(logFile)
    [folder, name] = fileparts(outputDatFile);
    logFile = fullfile(folder, [name '_label_log.txt']);
end

mappedTargetLabels = targetMesh.elementLabels;
candidateTargetRows = find(ismember(targetMesh.elementLabels, targetLabelsToMap));
[locatedInputElements, candidateInputLabels] = locateTargetRowsInInputMesh( ...
    inputMesh, targetMesh, candidateTargetRows, parser.Results.Tolerance, parser.Results.ChunkSize);

mappedRowsByInputLabel = zeros(numel(inputLabels), 1);
for labelIndex = 1:numel(inputLabels)
    oldLabel = inputLabels(labelIndex);
    newLabel = newLabels(labelIndex);
    rowsForLabel = candidateTargetRows(candidateInputLabels == oldLabel);
    mappedTargetLabels(rowsForLabel) = newLabel;
    mappedRowsByInputLabel(labelIndex) = numel(rowsForLabel);
end

repairInfo = struct();
repairInfo.enabled = parser.Results.SourceCentroidRepair;
repairInfo.locatedSourceElements = 0;
repairInfo.unlocatedSourceElements = 0;
repairInfo.repairedTargetElements = 0;
repairInfo.repairedRowsByInputLabel = zeros(numel(inputLabels), 1);
repairInfo.primaryTargetLabels = targetLabelsToMap;
repairInfo.fallbackTargetLabels = repairFallbackTargetLabels;
repairInfo.primaryLocatedSourceElements = 0;
repairInfo.fallbackLocatedSourceElements = 0;
repairInfo.fallbackNewLocatedSourceElements = 0;
repairInfo.fallbackRepairedTargetElements = 0;
if parser.Results.SourceCentroidRepair
    selectedSourceRows = find(ismember(inputMesh.elementLabels, inputLabels));
    repairInfo.totalSourceElements = numel(selectedSourceRows);
    [repairTargetRows, repairInputLabels, repairInfo, locatedSourceRows] = repairBySourceCentroids( ...
        inputMesh, targetMesh, candidateTargetRows, inputLabels, parser.Results.Tolerance, repairInfo);
    repairInfo.primaryLocatedSourceElements = repairInfo.locatedSourceElements;
    repairInfo.primaryRepairedTargetElements = repairInfo.repairedTargetElements;

    if ~isempty(repairFallbackTargetLabels) && repairInfo.unlocatedSourceElements > 0
        fallbackTargetRows = find(ismember(targetMesh.elementLabels, repairFallbackTargetLabels));
        missingSourceRows = setdiff(selectedSourceRows, locatedSourceRows);
        fallbackInfo = repairInfo;
        [fallbackTargetRows, fallbackInputLabels, fallbackInfo, fallbackLocatedSourceRows] = ...
            repairBySourceCentroids(inputMesh, targetMesh, fallbackTargetRows, ...
            inputLabels, parser.Results.Tolerance, fallbackInfo, missingSourceRows);

        repairTargetRows = [repairTargetRows; fallbackTargetRows];
        repairInputLabels = [repairInputLabels; fallbackInputLabels];
        repairInfo.fallbackLocatedSourceElements = fallbackInfo.locatedSourceElements;
        repairInfo.fallbackRepairedTargetElements = fallbackInfo.repairedTargetElements;
        repairInfo.fallbackNewLocatedSourceElements = numel(fallbackLocatedSourceRows);
        locatedSourceRows = unique([locatedSourceRows; fallbackLocatedSourceRows]);
        repairInfo.locatedSourceElements = numel(locatedSourceRows);
        repairInfo.unlocatedSourceElements = repairInfo.totalSourceElements - ...
            repairInfo.locatedSourceElements;
        repairInfo.repairedTargetElements = numel(unique(repairTargetRows));
    end

    for labelIndex = 1:numel(inputLabels)
        rowsForLabel = repairTargetRows(repairInputLabels == inputLabels(labelIndex));
        mappedTargetLabels(rowsForLabel) = newLabels(labelIndex);
        repairInfo.repairedRowsByInputLabel(labelIndex) = numel(rowsForLabel);
    end

    for labelIndex = 1:numel(inputLabels)
        mappedRowsByInputLabel(labelIndex) = nnz(mappedTargetLabels == newLabels(labelIndex));
    end
end

fillInfo = struct();
fillInfo.enabled = ~isempty(fillUnmappedTargetLabels);
fillInfo.requestedTargetLabels = fillUnmappedTargetLabels;
fillInfo.candidateTargetElements = 0;
fillInfo.initialUnmappedTargetElements = 0;
fillInfo.filledTargetElements = 0;
fillInfo.assignedBySourceContainment = 0;
fillInfo.assignedByNearestSource = 0;
fillInfo.filledRowsByInputLabel = zeros(numel(inputLabels), 1);
if ~isempty(fillUnmappedTargetLabels)
    fillCandidateRows = find(ismember(targetMesh.elementLabels, fillUnmappedTargetLabels));
    fillRows = fillCandidateRows(mappedTargetLabels(fillCandidateRows) == ...
        targetMesh.elementLabels(fillCandidateRows));
    fillInfo.candidateTargetElements = numel(fillCandidateRows);
    fillInfo.initialUnmappedTargetElements = numel(fillRows);

    if ~isempty(fillRows)
        [fillInputLabels, fillInfo] = fillTargetRowsBySourceLabels( ...
            inputMesh, targetMesh, fillRows, inputLabels, fillInfo);
        for labelIndex = 1:numel(inputLabels)
            rowsForLabel = fillRows(fillInputLabels == inputLabels(labelIndex));
            mappedTargetLabels(rowsForLabel) = newLabels(labelIndex);
            fillInfo.filledRowsByInputLabel(labelIndex) = numel(rowsForLabel);
        end

        for labelIndex = 1:numel(inputLabels)
            mappedRowsByInputLabel(labelIndex) = nnz(mappedTargetLabels == newLabels(labelIndex));
        end
    end
end

writeProblemDatMesh(outputDatFile, targetMesh, mappedTargetLabels, inputMesh, inputLabels, newLabels);
writeLabelLog(logFile, inputDatFile, targetDatFile, outputDatFile, ...
    targetLabelsToMap, inputLabels, inputLabelNames, newLabels, newLabelNames, ...
    mappedRowsByInputLabel, outputLabelTable, repairInfo, fillInfo);

info = struct();
info.inputMesh = inputMesh;
info.targetMesh = targetMesh;
info.inputLabels = inputLabels;
info.targetLabelsToMap = targetLabelsToMap;
info.repairFallbackTargetLabels = repairFallbackTargetLabels;
info.fillUnmappedTargetLabels = fillUnmappedTargetLabels;
info.newLabels = newLabels;
info.targetLabelNames = targetLabelNames;
info.inputLabelNames = inputLabelNames;
info.newLabelNames = newLabelNames;
info.outputLabelTable = outputLabelTable;
info.labelMap = table(inputLabels, inputLabelNames, newLabels, newLabelNames, mappedRowsByInputLabel, ...
    'VariableNames', {'InputLabel', 'InputLabelName', 'NewTargetLabel', ...
    'NewTargetLabelName', 'MappedTargetElements'});
info.candidateTargetRows = candidateTargetRows;
info.locatedInputElements = locatedInputElements;
info.candidateInputLabels = candidateInputLabels;
info.repairInfo = repairInfo;
info.fillInfo = fillInfo;
info.mappedRows = find(mappedTargetLabels ~= targetMesh.elementLabels);
info.outputDatFile = outputDatFile;
info.logFile = logFile;
end

function tf = isTextScalar(value)
tf = (ischar(value) && (isrow(value) || isempty(value))) || ...
     (isstring(value) && isscalar(value));
end

function tf = isTextVector(value)
tf = isempty(value) || ischar(value) || isstring(value) || iscellstr(value);
end

function values = numericColumn(values)
values = double(values(:));
values = values(~isnan(values));
end

function names = normalizeLabelNames(names, labels, labelKind)
names = textColumn(names);
if isempty(names)
    return;
end

if numel(names) ~= numel(labels)
    error('mapDatMeshLabels:LabelNameCountMismatch', ...
        '%s label names must contain one name per label.', upperFirst(labelKind));
end

fallbackNames = defaultLabelNames(labels, [labelKind '_label']);
emptyNames = strlength(strtrim(names)) == 0;
names(emptyNames) = fallbackNames(emptyNames);
end

function names = promptForLabelNames(inputLabels, newLabels)
names = strings(numel(newLabels), 1);
for labelIndex = 1:numel(newLabels)
    prompt = sprintf('Name for new output label %.15g from input label %.15g: ', ...
        newLabels(labelIndex), inputLabels(labelIndex));
    answer = string(input(prompt, 's'));
    if strlength(strtrim(answer)) == 0
        answer = defaultLabelNames(newLabels(labelIndex), 'mapped_label');
    end
    names(labelIndex) = strtrim(answer);
end
end

function names = defaultLabelNames(labels, prefix)
names = strings(numel(labels), 1);
for labelIndex = 1:numel(labels)
    names(labelIndex) = sprintf('%s_%.15g', prefix, labels(labelIndex));
end
end

function names = textColumn(names)
if isempty(names)
    names = strings(0, 1);
elseif ischar(names)
    names = string({names});
elseif iscell(names)
    names = string(names(:));
else
    names = string(names(:));
end
names = strtrim(names);
end

function text = upperFirst(text)
text = char(text);
text(1) = upper(text(1));
end

function outputLabelTable = makeOutputLabelTable(existingLabels, existingNames, newLabels, newNames)
if isempty(existingNames)
    existingNames = defaultLabelNames(existingLabels, 'target_label');
end

labels = [existingLabels(:); newLabels(:)];
names = [existingNames(:); newNames(:)];
[labels, order] = sort(labels);
names = names(order);

outputLabelTable = table(labels, names, 'VariableNames', {'Label', 'Name'});
end

function text = joinNumbers(values)
text = strjoin(compose('%.15g', values(:).'), ', ');
end

function mesh = readProblemDatMesh(fileName)
rawLines = readTextLines(fileName);
coordinatesLine = findSection(rawLines, 'Coordinates', fileName);
endCoordinatesLine = findSection(rawLines, 'end Coordinates', fileName);
elementsLine = findSection(rawLines, 'Elements', fileName);
endElementsLine = findSection(rawLines, 'end Elements', fileName);

coordinateCount = parseCount(rawLines{coordinatesLine + 1}, 'Coordinates', fileName);
nodes = parseNumericBlock(rawLines, coordinatesLine + 2, coordinateCount, 3, 'coordinate', fileName);

elementCount = parseCount(rawLines{elementsLine + 1}, 'Elements', fileName);
elementRows = parseNumericBlock(rawLines, elementsLine + 2, elementCount, 5, 'element', fileName);
elementPrefixColumns = elementRows(:, 1:(end - 1));
elements = elementPrefixColumns(:, 1:4);
elementLabels = elementRows(:, end);

if any(elements(:) < 1) || any(elements(:) > size(nodes, 1))
    error('mapDatMeshLabels:BadConnectivity', ...
        'Element connectivity in %s references nodes outside the coordinate block.', fileName);
end

material = parseMaterialProperties(rawLines);

mesh = struct();
mesh.fileName = fileName;
mesh.rawLines = rawLines;
mesh.coordinatesLine = coordinatesLine;
mesh.endCoordinatesLine = endCoordinatesLine;
mesh.elementsLine = elementsLine;
mesh.endElementsLine = endElementsLine;
mesh.nodes = nodes;
mesh.elementPrefixColumns = elementPrefixColumns;
mesh.elements = elements;
mesh.elementLabels = elementLabels;
mesh.materialLabels = material.labels;
mesh.materialRows = material.rows;
mesh.materialComment = material.comment;
mesh.materialLine = material.startLine;
mesh.endMaterialLine = material.endLine;
end

function rawLines = readTextLines(fileName)
fid = fopen(fileName, 'r');
if fid < 0
    error('mapDatMeshLabels:OpenFailed', 'Could not open file: %s', fileName);
end
cleanup = onCleanup(@() fclose(fid));

rawLines = {};
line = fgetl(fid);
while ischar(line)
    rawLines{end + 1, 1} = line; %#ok<AGROW>
    line = fgetl(fid);
end
end

function lineNumber = findSection(rawLines, sectionName, fileName)
matches = find(strcmpi(strtrim(rawLines), sectionName), 1, 'first');
if isempty(matches)
    error('mapDatMeshLabels:MissingSection', ...
        'Could not find section "%s" in %s.', sectionName, fileName);
end
lineNumber = matches;
end

function count = parseCount(line, sectionName, fileName)
count = sscanf(strtrim(line), '%d', 1);
if isempty(count) || count < 0
    error('mapDatMeshLabels:BadCount', ...
        'Invalid %s count in %s: %s', sectionName, fileName, line);
end
end

function values = parseNumericBlock(rawLines, startLine, rowCount, minColumns, blockName, fileName)
values = zeros(rowCount, minColumns);
for row = 1:rowCount
    lineNumber = startLine + row - 1;
    if lineNumber > numel(rawLines)
        error('mapDatMeshLabels:UnexpectedEndOfFile', ...
            'Unexpected end of file while reading %s rows in %s.', blockName, fileName);
    end
    rowValues = sscanf(strtrim(rawLines{lineNumber}), '%f').';
    if numel(rowValues) < minColumns
        error('mapDatMeshLabels:BadNumericRow', ...
            'Invalid %s row in %s: %s', blockName, fileName, rawLines{lineNumber});
    end
    if row == 1 && numel(rowValues) > minColumns
        values = zeros(rowCount, numel(rowValues));
    elseif numel(rowValues) ~= size(values, 2)
        error('mapDatMeshLabels:InconsistentColumns', ...
            'Inconsistent %s column count in %s at line %d.', blockName, fileName, lineNumber);
    end
    values(row, :) = rowValues;
end
end

function material = parseMaterialProperties(rawLines)
material.startLine = find(strcmpi(strtrim(rawLines), 'Material properties'), 1, 'first');
material.endLine = [];
material.labels = zeros(0, 1);
material.rows = zeros(0, 6);
material.comment = '# LABEL | Conductivity | REAL(eps) | IMAG(eps) | REAL(mu) | IMAG(mu) ';

if isempty(material.startLine)
    return;
end

count = parseCount(rawLines{material.startLine + 1}, 'Material properties', 'dat file');
cursor = material.startLine + 2;
if cursor <= numel(rawLines) && startsWith(strtrim(rawLines{cursor}), '#')
    material.comment = rawLines{cursor};
    cursor = cursor + 1;
end

material.rows = zeros(count, 6);
for row = 1:count
    rowValues = sscanf(strtrim(rawLines{cursor + row - 1}), '%f').';
    if numel(rowValues) < 6
        error('mapDatMeshLabels:BadMaterialRow', ...
            'Invalid material property row at line %d.', cursor + row - 1);
    end
    material.rows(row, :) = rowValues(1:6);
end
material.labels = material.rows(:, 1);
material.endLine = cursor + count - 1;
end

function centroids = tetraCentroids(nodes, elements)
centroids = (nodes(elements(:, 1), :) + nodes(elements(:, 2), :) + ...
    nodes(elements(:, 3), :) + nodes(elements(:, 4), :)) / 4;
end

function [locatedInputElements, candidateInputLabels] = locateTargetRowsInInputMesh( ...
    inputMesh, targetMesh, candidateTargetRows, tolerance, chunkSize)
locatedInputElements = nan(numel(candidateTargetRows), 1);
candidateInputLabels = nan(numel(candidateTargetRows), 1);
if isempty(candidateTargetRows)
    return;
end

chunkSize = max(1, floor(chunkSize));
sourceBoxMin = min(inputMesh.nodes, [], 1) - tolerance;
sourceBoxMax = max(inputMesh.nodes, [], 1) + tolerance;

usePointLocation = true;
try
    sourceTriangulation = triangulation(inputMesh.elements, inputMesh.nodes);
catch
    usePointLocation = false;
    sourceTriangulation = [];
end

for firstRow = 1:chunkSize:numel(candidateTargetRows)
    lastRow = min(firstRow + chunkSize - 1, numel(candidateTargetRows));
    chunkTargetRows = candidateTargetRows(firstRow:lastRow);
    centroids = tetraCentroids(targetMesh.nodes, targetMesh.elements(chunkTargetRows, :));
    insideSourceBox = all(centroids >= sourceBoxMin & centroids <= sourceBoxMax, 2);
    if ~any(insideSourceBox)
        continue;
    end

    pointsToLocate = centroids(insideSourceBox, :);
    if usePointLocation
        located = pointLocation(sourceTriangulation, pointsToLocate);
        located = located(:);
        unresolved = isnan(located);
        if tolerance > 0 && any(unresolved)
            located(unresolved) = locatePointsInTets( ...
                inputMesh.nodes, inputMesh.elements, pointsToLocate(unresolved, :), tolerance);
        end
    else
        located = locatePointsInTets( ...
            inputMesh.nodes, inputMesh.elements, pointsToLocate, tolerance);
    end

    localRowsInsideBox = find(insideSourceBox);
    found = ~isnan(located);
    if any(found)
        localRowsFound = localRowsInsideBox(found);
        candidateRowsFound = firstRow + localRowsFound - 1;
        locatedInputElements(candidateRowsFound) = located(found);
        candidateInputLabels(candidateRowsFound) = inputMesh.elementLabels(located(found));
    end
end
end

function [repairTargetRows, repairInputLabels, repairInfo, locatedSourceRows] = repairBySourceCentroids( ...
    inputMesh, targetMesh, candidateTargetRows, inputLabels, ~, repairInfo, selectedSourceRows)
repairTargetRows = zeros(0, 1);
repairInputLabels = zeros(0, 1);
locatedSourceRows = zeros(0, 1);

if nargin < 7 || isempty(selectedSourceRows)
    selectedSourceRows = find(ismember(inputMesh.elementLabels, inputLabels));
else
    selectedSourceRows = selectedSourceRows(:);
end

if isempty(selectedSourceRows) || isempty(candidateTargetRows)
    repairInfo.unlocatedSourceElements = numel(selectedSourceRows);
    return;
end

sourceCentroids = tetraCentroids(inputMesh.nodes, inputMesh.elements(selectedSourceRows, :));
sourceLabels = inputMesh.elementLabels(selectedSourceRows);

try
    targetTriangulation = triangulation( ...
        targetMesh.elements(candidateTargetRows, :), targetMesh.nodes);
    localTargetRows = pointLocation(targetTriangulation, sourceCentroids);
catch exception
    error('mapDatMeshLabels:SourceCentroidRepairFailed', ...
        ['Could not build/use the selected target triangulation for ' ...
        'SourceCentroidRepair: %s'], exception.message);
end

located = ~isnan(localTargetRows);
repairInfo.locatedSourceElements = nnz(located);
repairInfo.unlocatedSourceElements = nnz(~located);
if ~any(located)
    return;
end

locatedSourceRows = selectedSourceRows(located);
targetRowsForSource = candidateTargetRows(localTargetRows(located));
sourceLabelsForTarget = sourceLabels(located);
[uniqueTargetRows, ~, targetGroup] = unique(targetRowsForSource);
labelIndices = labelToIndex(sourceLabelsForTarget, inputLabels);

voteCounts = accumarray([targetGroup, labelIndices], 1, ...
    [numel(uniqueTargetRows), numel(inputLabels)], @sum, 0);
[~, winningLabelIndex] = max(voteCounts, [], 2);

repairTargetRows = uniqueTargetRows;
repairInputLabels = inputLabels(winningLabelIndex);
repairInfo.repairedTargetElements = numel(repairTargetRows);
end

function indices = labelToIndex(labels, labelSet)
indices = zeros(numel(labels), 1);
for labelIndex = 1:numel(labelSet)
    indices(labels == labelSet(labelIndex)) = labelIndex;
end
if any(indices == 0)
    error('mapDatMeshLabels:UnexpectedRepairLabel', ...
        'Source-centroid repair found a label outside InputLabels.');
end
end

function [fillInputLabels, fillInfo] = fillTargetRowsBySourceLabels( ...
    inputMesh, targetMesh, targetRows, inputLabels, fillInfo)
fillInputLabels = zeros(numel(targetRows), 1);
if isempty(targetRows)
    return;
end

sourceRows = find(ismember(inputMesh.elementLabels, inputLabels));
if isempty(sourceRows)
    error('mapDatMeshLabels:NoFillSourceElements', ...
        'Cannot fill target labels because no source elements match InputLabels.');
end

sourceCentroids = tetraCentroids(inputMesh.nodes, inputMesh.elements(sourceRows, :));
sourceLabels = inputMesh.elementLabels(sourceRows);
targetCentroids = tetraCentroids(targetMesh.nodes, targetMesh.elements(targetRows, :));

try
    sourceTriangulation = triangulation(inputMesh.elements(sourceRows, :), inputMesh.nodes);
    sourceContainingRows = pointLocation(sourceTriangulation, targetCentroids);
    sourceContainingRows = sourceContainingRows(:);
catch
    sourceContainingRows = nan(numel(targetRows), 1);
end

insideSource = ~isnan(sourceContainingRows);
if any(insideSource)
    fillInputLabels(insideSource) = sourceLabels(sourceContainingRows(insideSource));
end

needsNearest = find(fillInputLabels == 0);
if ~isempty(needsNearest)
    nearestSourceRows = nearestSourceCentroidRows( ...
        sourceCentroids, targetCentroids(needsNearest, :));
    fillInputLabels(needsNearest) = sourceLabels(nearestSourceRows);
end

fillInfo.filledTargetElements = numel(targetRows);
fillInfo.assignedBySourceContainment = nnz(insideSource);
fillInfo.assignedByNearestSource = numel(needsNearest);
end

function nearestRows = nearestSourceCentroidRows(sourceCentroids, queryCentroids)
if exist('KDTreeSearcher', 'file') == 2
    searcher = KDTreeSearcher(sourceCentroids);
    nearestRows = knnsearch(searcher, queryCentroids);
elseif exist('dsearchn', 'file') == 2
    nearestRows = dsearchn(sourceCentroids, queryCentroids);
else
    nearestRows = nearestRowsByChunks(sourceCentroids, queryCentroids, 100);
end
nearestRows = nearestRows(:);
end

function nearestRows = nearestRowsByChunks(sourceCentroids, queryCentroids, chunkSize)
nearestRows = zeros(size(queryCentroids, 1), 1);
for firstRow = 1:chunkSize:size(queryCentroids, 1)
    lastRow = min(firstRow + chunkSize - 1, size(queryCentroids, 1));
    queryChunk = queryCentroids(firstRow:lastRow, :);
    for queryIndex = 1:size(queryChunk, 1)
        deltas = sourceCentroids - queryChunk(queryIndex, :);
        [~, nearestRows(firstRow + queryIndex - 1)] = min(sum(deltas.^2, 2));
    end
end
end

function elementIndex = locatePointsInTets(nodes, elements, points, tolerance)
elementIndex = nan(size(points, 1), 1);
if isempty(points)
    return;
end

boxMin = min(nodes, [], 1) - tolerance;
boxMax = max(nodes, [], 1) + tolerance;
candidatePoint = all(points >= boxMin & points <= boxMax, 2);
candidateRows = find(candidatePoint);
if isempty(candidateRows)
    return;
end

usedTsearchn = false;
if exist('tsearchn', 'file') == 2 || exist('tsearchn', 'builtin') == 5
    try
        located = tsearchn(nodes, elements, points(candidateRows, :));
        elementIndex(candidateRows) = located(:);
        usedTsearchn = true;
    catch
        usedTsearchn = false;
    end
end

if ~usedTsearchn || (tolerance > 0 && any(isnan(elementIndex(candidateRows))))
    unresolvedRows = candidateRows(isnan(elementIndex(candidateRows)));
    fallbackIndex = bruteForcePointLocation(nodes, elements, points(unresolvedRows, :), tolerance);
    found = ~isnan(fallbackIndex);
    elementIndex(unresolvedRows(found)) = fallbackIndex(found);
end
end

function pointElementIndex = bruteForcePointLocation(nodes, elements, points, tolerance)
pointElementIndex = nan(size(points, 1), 1);
if isempty(points)
    return;
end

unresolved = true(size(points, 1), 1);
for elem = 1:size(elements, 1)
    if ~any(unresolved)
        break;
    end

    vertices = nodes(elements(elem, :), :);
    boxMin = min(vertices, [], 1) - tolerance;
    boxMax = max(vertices, [], 1) + tolerance;
    candidates = find(unresolved & all(points >= boxMin & points <= boxMax, 2));
    if isempty(candidates)
        continue;
    end

    transform = [vertices(2, :) - vertices(1, :); ...
                 vertices(3, :) - vertices(1, :); ...
                 vertices(4, :) - vertices(1, :)].';
    if abs(det(transform)) < eps
        continue;
    end

    local = (transform \ (points(candidates, :) - vertices(1, :)).').';
    barycentric = [1 - sum(local, 2), local];
    inside = all(barycentric >= -tolerance & barycentric <= 1 + tolerance, 2);
    foundRows = candidates(inside);
    pointElementIndex(foundRows) = elem;
    unresolved(foundRows) = false;
end
end

function writeProblemDatMesh(fileName, targetMesh, labels, inputMesh, inputLabels, newLabels)
fid = fopen(fileName, 'w');
if fid < 0
    error('mapDatMeshLabels:WriteFailed', 'Could not write file: %s', fileName);
end
cleanup = onCleanup(@() fclose(fid));

for lineNumber = 1:(targetMesh.coordinatesLine - 1)
    fprintf(fid, '%s\n', targetMesh.rawLines{lineNumber});
end

fprintf(fid, 'Coordinates\n');
fprintf(fid, '%9d\n', size(targetMesh.nodes, 1));
for node = 1:size(targetMesh.nodes, 1)
    fprintf(fid, '%16.9f %16.9f %16.9f\n', ...
        targetMesh.nodes(node, 1), targetMesh.nodes(node, 2), targetMesh.nodes(node, 3));
end
fprintf(fid, 'end Coordinates\n\n');

fprintf(fid, 'Elements\n');
fprintf(fid, '%9d\n', size(targetMesh.elements, 1));
for elem = 1:size(targetMesh.elements, 1)
    fprintf(fid, '%10.0f', targetMesh.elementPrefixColumns(elem, :));
    fprintf(fid, ' %9.0f\n', labels(elem));
end
fprintf(fid, 'end Elements\n');

suffixLines = targetMesh.rawLines((targetMesh.endElementsLine + 1):end);
suffixLines = replaceMaterialProperties(suffixLines, targetMesh, inputMesh, inputLabels, newLabels);
for lineNumber = 1:numel(suffixLines)
    fprintf(fid, '%s\n', suffixLines{lineNumber});
end
end

function suffixLines = replaceMaterialProperties(suffixLines, targetMesh, inputMesh, inputLabels, newLabels)
startLine = find(strcmpi(strtrim(suffixLines), 'Material properties'), 1, 'first');
if isempty(startLine)
    suffixLines = [suffixLines; {''}; ...
        buildMaterialPropertyLines(targetMesh, inputMesh, inputLabels, newLabels)];
    return;
end

count = parseCount(suffixLines{startLine + 1}, 'Material properties', 'target suffix');
cursor = startLine + 2;
if cursor <= numel(suffixLines) && startsWith(strtrim(suffixLines{cursor}), '#')
    cursor = cursor + 1;
end
endLine = cursor + count - 1;

replacement = buildMaterialPropertyLines(targetMesh, inputMesh, inputLabels, newLabels);
suffixLines = [suffixLines(1:startLine - 1); replacement; suffixLines(endLine + 1:end)];
end

function lines = buildMaterialPropertyLines(targetMesh, inputMesh, inputLabels, newLabels)
rows = targetMesh.materialRows;
if isempty(rows)
    rows = unique(targetMesh.elementLabels, 'stable');
    rows = [rows, zeros(numel(rows), 1), ones(numel(rows), 1), ...
        zeros(numel(rows), 1), ones(numel(rows), 1), zeros(numel(rows), 1)];
end

newRows = zeros(numel(inputLabels), 6);
for labelIndex = 1:numel(inputLabels)
    sourceRow = inputMesh.materialRows(inputMesh.materialLabels == inputLabels(labelIndex), :);
    if isempty(sourceRow)
        sourceRow = rows(1, :);
    end
    newRows(labelIndex, :) = sourceRow(1, :);
    newRows(labelIndex, 1) = newLabels(labelIndex);
end

rows = [rows; newRows];
lines = cell(size(rows, 1) + 3, 1);
lines{1} = 'Material properties';
lines{2} = sprintf('%9d', size(rows, 1));
lines{3} = targetMesh.materialComment;
for row = 1:size(rows, 1)
    lines{row + 3} = sprintf('%9d %15.9f %15.9f %15.9f %15.9f %15.9f', ...
        rows(row, 1), rows(row, 2), rows(row, 3), rows(row, 4), rows(row, 5), rows(row, 6));
end
end

function writeLabelLog(logFile, inputDatFile, targetDatFile, outputDatFile, ...
    targetLabelsToMap, inputLabels, inputLabelNames, newLabels, newLabelNames, ...
    mappedRowsByInputLabel, outputLabelTable, repairInfo, fillInfo)
fid = fopen(logFile, 'w');
if fid < 0
    error('mapDatMeshLabels:LogWriteFailed', 'Could not write log file: %s', logFile);
end
cleanup = onCleanup(@() fclose(fid));
timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

fprintf(fid, 'Mesh label remapping log\n');
fprintf(fid, 'Created: %s\n', timestamp);
fprintf(fid, 'Input DAT: %s\n', inputDatFile);
fprintf(fid, 'Target DAT: %s\n', targetDatFile);
fprintf(fid, 'Output DAT: %s\n', outputDatFile);
fprintf(fid, 'Target labels searched: %s\n', joinNumbers(targetLabelsToMap));

fprintf(fid, '\nOutput material labels\n');
fprintf(fid, 'Index | Name\n');
for labelIndex = 1:height(outputLabelTable)
    fprintf(fid, '  %.15g | %s\n', ...
        outputLabelTable.Label(labelIndex), char(outputLabelTable.Name(labelIndex)));
end

fprintf(fid, '\nOld input label -> new output label\n');
for labelIndex = 1:numel(inputLabels)
    fprintf(fid, '  %.15g (%s) -> %.15g (%s), mapped target elements: %d\n', ...
        inputLabels(labelIndex), char(inputLabelNames(labelIndex)), ...
        newLabels(labelIndex), char(newLabelNames(labelIndex)), ...
        mappedRowsByInputLabel(labelIndex));
end

if isfield(repairInfo, 'enabled') && repairInfo.enabled
    fprintf(fid, '\nSource-centroid repair\n');
    if isfield(repairInfo, 'totalSourceElements')
        fprintf(fid, '  Total selected source elements: %d\n', repairInfo.totalSourceElements);
    end
    if isfield(repairInfo, 'primaryTargetLabels')
        fprintf(fid, '  Primary target labels: %s\n', joinNumbers(repairInfo.primaryTargetLabels));
    end
    if isfield(repairInfo, 'fallbackTargetLabels') && ~isempty(repairInfo.fallbackTargetLabels)
        fprintf(fid, '  Fallback target labels: %s\n', joinNumbers(repairInfo.fallbackTargetLabels));
    end
    fprintf(fid, '  Located source elements: %d\n', repairInfo.locatedSourceElements);
    fprintf(fid, '  Unlocated source elements: %d\n', repairInfo.unlocatedSourceElements);
    fprintf(fid, '  Repaired target elements: %d\n', repairInfo.repairedTargetElements);
    if isfield(repairInfo, 'primaryLocatedSourceElements')
        fprintf(fid, '  Primary located source elements: %d\n', ...
            repairInfo.primaryLocatedSourceElements);
    end
    if isfield(repairInfo, 'primaryRepairedTargetElements')
        fprintf(fid, '  Primary repaired target elements: %d\n', ...
            repairInfo.primaryRepairedTargetElements);
    end
    if isfield(repairInfo, 'fallbackLocatedSourceElements') && ...
            repairInfo.fallbackLocatedSourceElements > 0
        fprintf(fid, '  Fallback located source elements: %d\n', ...
            repairInfo.fallbackLocatedSourceElements);
        fprintf(fid, '  Fallback newly located source elements: %d\n', ...
            repairInfo.fallbackNewLocatedSourceElements);
        fprintf(fid, '  Fallback repaired target elements: %d\n', ...
            repairInfo.fallbackRepairedTargetElements);
    end
    for labelIndex = 1:numel(inputLabels)
        fprintf(fid, '  %.15g (%s) repair target elements: %d\n', ...
            inputLabels(labelIndex), char(inputLabelNames(labelIndex)), ...
            repairInfo.repairedRowsByInputLabel(labelIndex));
    end
end

if isfield(fillInfo, 'enabled') && fillInfo.enabled
    fprintf(fid, '\nFinal unmapped-target fill\n');
    fprintf(fid, '  Required target labels: %s\n', ...
        joinNumbers(fillInfo.requestedTargetLabels));
    fprintf(fid, '  Candidate target elements: %d\n', ...
        fillInfo.candidateTargetElements);
    fprintf(fid, '  Initially unmapped target elements: %d\n', ...
        fillInfo.initialUnmappedTargetElements);
    fprintf(fid, '  Filled target elements: %d\n', ...
        fillInfo.filledTargetElements);
    fprintf(fid, '  Assigned by source containment: %d\n', ...
        fillInfo.assignedBySourceContainment);
    fprintf(fid, '  Assigned by nearest source centroid: %d\n', ...
        fillInfo.assignedByNearestSource);
    for labelIndex = 1:numel(inputLabels)
        fprintf(fid, '  %.15g (%s) fill target elements: %d\n', ...
            inputLabels(labelIndex), char(inputLabelNames(labelIndex)), ...
            fillInfo.filledRowsByInputLabel(labelIndex));
    end
end
end
