%VALIDATE_HEAD_MAPPING_BASE_FINER Validate the base/finer remapped DAT syntax.

clear;
clc;

repoRoot = getRepoRoot();
resultDir = fullfile(repoRoot, 'result', 'base_finer');
originalDatFile = fullfile(repoRoot, 'input', 'mesh_base.dat');
remappedDatFile = fullfile(resultDir, 'mesh_base_with_head_finer.dat');
reportFile = fullfile(resultDir, 'mesh_base_with_head_finer_validation.txt');

if exist(remappedDatFile, 'file') ~= 2
    error('validateHeadMappingBaseFiner:MissingResult', ...
        'Run build_head_mapping_base_finer first to create %s.', remappedDatFile);
end

if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end

reportId = fopen(reportFile, 'w');
if reportId < 0
    error('validateHeadMappingBaseFiner:ReportOpenFailed', ...
        'Could not write validation report: %s', reportFile);
end
cleanupReport = onCleanup(@() fclose(reportId));

logLine(reportId, 'Base mesh / finer head mapping validation');
logLine(reportId, 'Original DAT: %s', originalDatFile);
logLine(reportId, 'Remapped DAT: %s', remappedDatFile);
logLine(reportId, '');

originalInfo = readDatBlockInfo(originalDatFile);
remappedInfo = readDatBlockInfo(remappedDatFile);

logLine(reportId, 'Block counts');
logLine(reportId, '  Coordinates: original %d, remapped %d', ...
    originalInfo.coordinateCount, remappedInfo.coordinateCount);
logLine(reportId, '  Elements:    original %d, remapped %d', ...
    originalInfo.elementCount, remappedInfo.elementCount);
logLine(reportId, '  Materials:   original %d, remapped %d', ...
    originalInfo.materialCount, remappedInfo.materialCount);

assert(originalInfo.coordinateCount == remappedInfo.coordinateCount, ...
    'Coordinate count changed between original and remapped DAT files.');
assert(originalInfo.elementCount == remappedInfo.elementCount, ...
    'Element count changed between original and remapped DAT files.');
assert(remappedInfo.materialCount == originalInfo.materialCount + 5, ...
    'Expected remapped material count to be original count plus five head labels.');

logLine(reportId, '');
logLine(reportId, 'Parsing numeric blocks in remapped DAT...');
validateCoordinates(remappedDatFile, remappedInfo.coordinateCount);
[labels, counts] = validateElementsAndCountLabels(remappedDatFile, remappedInfo.elementCount);
validateMaterialProperties(remappedDatFile, remappedInfo.materialCount);
logLine(reportId, '  Coordinate, element, and material numeric blocks parsed successfully.');

logLine(reportId, '');
logLine(reportId, 'Remapped element label counts');
for row = 1:numel(labels)
    logLine(reportId, '  Label %g: %d', labels(row), counts(row));
end

logLine(reportId, '');
logLine(reportId, 'Search-domain labels still present');
for label = 19:24
    logLine(reportId, '  Label %d: %d', label, labelCount(labels, counts, label));
end

logLine(reportId, '');
logLine(reportId, 'New head labels');
for label = 25:29
    logLine(reportId, '  Label %d: %d', label, labelCount(labels, counts, label));
end

logLine(reportId, '');
logLine(reportId, 'Validation passed.');
logLine(reportId, 'Report saved to: %s', reportFile);

function info = readDatBlockInfo(datFile)
fid = fopen(datFile, 'r');
if fid < 0
    error('validateHeadMappingBaseFiner:OpenFailed', ...
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
    error('validateHeadMappingBaseFiner:OpenFailed', ...
        'Could not open file: %s', datFile);
end
cleanup = onCleanup(@() fclose(fid));

seekSection(fid, 'Coordinates', datFile);
coordinateCount = parseCount(fgetl(fid), 'Coordinates', datFile);
assert(coordinateCount == expectedCount, 'Unexpected coordinate count.');

coordinateData = textscan(fid, '%f %f %f', coordinateCount, 'CollectOutput', true);
if size(coordinateData{1}, 1) ~= coordinateCount
    error('validateHeadMappingBaseFiner:BadCoordinates', ...
        'Could not parse all coordinate rows in %s.', datFile);
end

endLine = readNextNonemptyLine(fid);
assert(strcmpi(endLine, 'end Coordinates'), ...
    'Expected "end Coordinates" after coordinate block.');
end

function [labels, counts] = validateElementsAndCountLabels(datFile, expectedCount)
fid = fopen(datFile, 'r');
if fid < 0
    error('validateHeadMappingBaseFiner:OpenFailed', ...
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
        error('validateHeadMappingBaseFiner:BadElements', ...
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
    error('validateHeadMappingBaseFiner:OpenFailed', ...
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
        error('validateHeadMappingBaseFiner:BadMaterialRow', ...
            'Invalid material-property row %d in %s.', row, datFile);
    end
    if row < materialCount
        line = fgetl(fid);
    end
end
end

function count = labelCount(labels, counts, label)
match = labels == label;
if any(match)
    count = counts(match);
else
    count = 0;
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

error('validateHeadMappingBaseFiner:MissingSection', ...
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
    error('validateHeadMappingBaseFiner:BadCount', ...
        'Invalid %s count in %s: %s', sectionName, datFile, line);
end
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

function repoRoot = getRepoRoot()
scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    repoRoot = pwd;
else
    repoRoot = fileparts(scriptPath);
end
end
