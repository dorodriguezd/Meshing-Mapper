function report = validateDatMeshFile(datFile, varargin)
%VALIDATEDATMESHFILE Validate required numeric blocks in a tetrahedral DAT.
%
%   report = VALIDATEDATMESHFILE(datFile)
%   report = VALIDATEDATMESHFILE(datFile, 'ReferenceFile', referenceDat)
%
%   When a reference is supplied, coordinate and element counts must match.
%   ExpectedAddedMaterials optionally checks the material-table growth.

parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, 'datFile', @isTextScalar);
addParameter(parser, 'ReferenceFile', '', @isTextScalar);
addParameter(parser, 'ExpectedAddedMaterials', [], ...
    @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
parse(parser, datFile, varargin{:});

datFile = char(parser.Results.datFile);
mesh = parseDat(datFile);

referenceFile = char(parser.Results.ReferenceFile);
if ~isempty(referenceFile)
    reference = parseDat(referenceFile);
    assert(mesh.CoordinateCount == reference.CoordinateCount, ...
        'validateDatMeshFile:CoordinateCountChanged', ...
        'Coordinate count differs from the reference DAT.');
    assert(mesh.ElementCount == reference.ElementCount, ...
        'validateDatMeshFile:ElementCountChanged', ...
        'Element count differs from the reference DAT.');
    expectedAdded = parser.Results.ExpectedAddedMaterials;
    if ~isempty(expectedAdded)
        assert(mesh.MaterialCount == reference.MaterialCount + expectedAdded, ...
            'validateDatMeshFile:MaterialCountMismatch', ...
            'Material count does not match the expected reference increase.');
    else
        assert(mesh.MaterialCount == reference.MaterialCount, ...
            'validateDatMeshFile:MaterialCountChanged', ...
            'Material count differs from the reference DAT.');
        assert(isequal(mesh.ElementLabels, reference.ElementLabels), ...
            'validateDatMeshFile:ElementLabelsChanged', ...
            'Element labels differ from the reference DAT.');
        assert(isequal(mesh.MaterialLabels, reference.MaterialLabels), ...
            'validateDatMeshFile:MaterialLabelsChanged', ...
            'Material labels differ from the reference DAT.');
    end
else
    reference = struct();
end

report = mesh;
report.File = datFile;
report.ReferenceFile = referenceFile;
report.Reference = reference;
report.Valid = true;
end

function report = parseDat(fileName)
[coordinateCount, boundingBox] = readCoordinates(fileName);
[elementCount, elementLabels] = readElements(fileName, coordinateCount);
[materialCount, materialLabels] = readMaterials(fileName);

report = struct();
report.CoordinateCount = coordinateCount;
report.ElementCount = elementCount;
report.MaterialCount = materialCount;
report.ElementLabels = elementLabels;
report.MaterialLabels = materialLabels;
report.BoundingBox = boundingBox;
end

function [count, boundingBox] = readCoordinates(fileName)
fid = fopen(fileName, 'r');
if fid < 0
    error('validateDatMeshFile:OpenFailed', 'Could not open file: %s', fileName);
end
cleanup = onCleanup(@() fclose(fid));
seekSection(fid, 'Coordinates', fileName);
count = parseCount(fgetl(fid), 'Coordinates', fileName);

minimum = [inf inf inf];
maximum = [-inf -inf -inf];
remaining = count;
chunkSize = 250000;
while remaining > 0
    rowsToRead = min(chunkSize, remaining);
    data = textscan(fid, '%f %f %f', rowsToRead, 'CollectOutput', true);
    data = data{1};
    if size(data, 1) ~= rowsToRead || any(~isfinite(data), 'all')
        error('validateDatMeshFile:BadCoordinates', ...
            'Could not parse all coordinate rows in %s.', fileName);
    end
    minimum = min(minimum, min(data, [], 1));
    maximum = max(maximum, max(data, [], 1));
    remaining = remaining - rowsToRead;
end
assertNextSectionEnd(fid, 'end Coordinates', fileName);
boundingBox = [minimum; maximum];
end

function [count, labels] = readElements(fileName, coordinateCount)
fid = fopen(fileName, 'r');
if fid < 0
    error('validateDatMeshFile:OpenFailed', 'Could not open file: %s', fileName);
end
cleanup = onCleanup(@() fclose(fid));
seekSection(fid, 'Elements', fileName);
count = parseCount(fgetl(fid), 'Elements', fileName);

labels = zeros(count, 1);
remaining = count;
firstRow = 1;
chunkSize = 250000;
while remaining > 0
    rowsToRead = min(chunkSize, remaining);
    data = textscan(fid, '%f %f %f %f %f', rowsToRead, 'CollectOutput', true);
    data = data{1};
    if size(data, 1) ~= rowsToRead || any(~isfinite(data), 'all')
        error('validateDatMeshFile:BadElements', ...
            'Could not parse all element rows in %s.', fileName);
    end
    nodeIds = data(:, 1:4);
    if any(nodeIds < 1, 'all') || any(nodeIds > coordinateCount, 'all') || ...
            any(nodeIds ~= fix(nodeIds), 'all')
        error('validateDatMeshFile:InvalidConnectivity', ...
            'Element connectivity contains invalid node indices in %s.', fileName);
    end
    lastRow = firstRow + rowsToRead - 1;
    labels(firstRow:lastRow) = data(:, 5);
    firstRow = lastRow + 1;
    remaining = remaining - rowsToRead;
end
assertNextSectionEnd(fid, 'end Elements', fileName);
end

function [count, labels] = readMaterials(fileName)
fid = fopen(fileName, 'r');
if fid < 0
    error('validateDatMeshFile:OpenFailed', 'Could not open file: %s', fileName);
end
cleanup = onCleanup(@() fclose(fid));
seekSection(fid, 'Material properties', fileName);
count = parseCount(fgetl(fid), 'Material properties', fileName);

line = fgetl(fid);
if ischar(line) && startsWith(strtrim(line), '#')
    line = fgetl(fid);
end
labels = zeros(count, 1);
for row = 1:count
    values = sscanf(strtrim(line), '%f').';
    if numel(values) < 6 || any(~isfinite(values(1:6)))
        error('validateDatMeshFile:BadMaterialRow', ...
            'Invalid material-property row %d in %s.', row, fileName);
    end
    labels(row) = values(1);
    if row < count
        line = fgetl(fid);
    end
end
end

function seekSection(fid, sectionName, fileName)
line = fgetl(fid);
while ischar(line)
    if strcmpi(strtrim(line), sectionName)
        return;
    end
    line = fgetl(fid);
end
error('validateDatMeshFile:MissingSection', ...
    'Could not find section "%s" in %s.', sectionName, fileName);
end

function count = parseCount(line, sectionName, fileName)
count = sscanf(strtrim(line), '%d', 1);
if isempty(count) || count < 0
    error('validateDatMeshFile:BadCount', ...
        'Invalid %s count in %s.', sectionName, fileName);
end
end

function assertNextSectionEnd(fid, expectedText, fileName)
line = fgetl(fid);
while ischar(line) && isempty(strtrim(line))
    line = fgetl(fid);
end
if ~ischar(line) || ~strcmpi(strtrim(line), expectedText)
    error('validateDatMeshFile:MissingSectionEnd', ...
        'Expected "%s" in %s.', expectedText, fileName);
end
end

function tf = isTextScalar(value)
tf = (ischar(value) && (isrow(value) || isempty(value))) || ...
    (isstring(value) && isscalar(value));
end
