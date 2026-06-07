function [targetLabels, info] = map3DMeshLabels(sourceMshFile, targetMshFile, varargin)
%MAP3DMESHLABELS Transfer volumetric tetra labels from one 3-D mesh to another.
%
%   targetLabels = MAP3DMESHLABELS(sourceMshFile, targetMshFile) reads two
%   GiD-style tetrahedral .msh files and assigns each target tetrahedron the
%   label of the source tetrahedron that contains its centroid. Target
%   tetrahedra outside the source volume receive the background label 0.
%
%   [targetLabels, info] = MAP3DMESHLABELS(...) also returns the parsed
%   source/target meshes, target centroids, and source element indices used
%   for the mapping.
%
%   Name-value options:
%       'SourceLabels'     Numeric label per source element. If omitted, the
%                          first extra source element column is used. If the
%                          source has no extra column, all source elements
%                          are assigned label 1.
%       'InputLabels'      Source labels to transfer. Default: all.
%       'NewLabels'        Output label for each InputLabels value. Default:
%                          consecutive labels above the maximum baseline
%                          label.
%       'TargetLabels'     Existing target labels where replacement is
%                          allowed. Default: all target elements.
%       'BackgroundLabel'  Label for target elements outside the source
%                          volume when the target has no labels. Default: 0.
%       'WriteMappedMesh'  Output .msh path. When provided, the target mesh
%                          is written with the mapped label appended to each
%                          element row.
%       'Tolerance'        Barycentric tolerance for the fallback point
%                          locator. Default: 1e-10.

parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, 'sourceMshFile', @isTextScalar);
addRequired(parser, 'targetMshFile', @isTextScalar);
addParameter(parser, 'SourceLabels', [], @(x) isnumeric(x) || islogical(x));
addParameter(parser, 'InputLabels', [], @(x) isnumeric(x) || islogical(x));
addParameter(parser, 'NewLabels', [], @(x) isnumeric(x) || islogical(x));
addParameter(parser, 'TargetLabels', [], @(x) isnumeric(x) || islogical(x));
addParameter(parser, 'BackgroundLabel', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(parser, 'WriteMappedMesh', '', @isTextScalar);
addParameter(parser, 'Tolerance', 1e-10, @(x) isnumeric(x) && isscalar(x) && x >= 0);
parse(parser, sourceMshFile, targetMshFile, varargin{:});

sourceMshFile = char(parser.Results.sourceMshFile);
targetMshFile = char(parser.Results.targetMshFile);
outputMshFile = char(parser.Results.WriteMappedMesh);

sourceMesh = readGidTetraMesh(sourceMshFile);
targetMesh = readGidTetraMesh(targetMshFile);

assert(sourceMesh.nnode == 4, 'map3DMeshLabels:SourceNotTetra', ...
    'Source mesh must use tetrahedral elements with 4 nodes.');
assert(targetMesh.nnode == 4, 'map3DMeshLabels:TargetNotTetra', ...
    'Target mesh must use tetrahedral elements with 4 nodes.');

sourceLabels = chooseSourceLabels(sourceMesh, parser.Results.SourceLabels);
inputLabels = numericColumn(parser.Results.InputLabels);
if isempty(inputLabels)
    inputLabels = unique(sourceLabels, 'stable');
end
missingInputLabels = setdiff(inputLabels, unique(sourceLabels));
if ~isempty(missingInputLabels)
    error('map3DMeshLabels:MissingInputLabels', ...
        'Requested source labels are not present: %s', mat2str(missingInputLabels.'));
end

targetOriginalLabels = chooseTargetLabels(targetMesh, parser.Results.BackgroundLabel);
existingTargetLabels = unique(targetOriginalLabels);
newLabels = numericColumn(parser.Results.NewLabels);
if isempty(newLabels)
    firstNewLabel = max([existingTargetLabels; 0]) + 1;
    newLabels = (firstNewLabel:(firstNewLabel + numel(inputLabels) - 1)).';
elseif numel(newLabels) ~= numel(inputLabels)
    error('map3DMeshLabels:NewLabelCountMismatch', ...
        'NewLabels must contain one value per InputLabels value.');
end

if any(ismember(newLabels, existingTargetLabels))
    error('map3DMeshLabels:NewLabelConflict', ...
        ['NewLabels must not already exist in the baseline mesh. ' ...
        'Existing labels: %s'], mat2str(existingTargetLabels.'));
end
if numel(unique(newLabels)) ~= numel(newLabels)
    error('map3DMeshLabels:DuplicateNewLabels', ...
        'NewLabels must contain one distinct output label per selected input label.');
end
targetLabelsToMap = numericColumn(parser.Results.TargetLabels);
if isempty(targetLabelsToMap)
    candidateTargetRows = (1:size(targetMesh.elements, 1)).';
else
    missingTargetLabels = setdiff(targetLabelsToMap, unique(targetOriginalLabels));
    if ~isempty(missingTargetLabels)
        error('map3DMeshLabels:MissingTargetLabels', ...
            'Requested target labels are not present: %s', mat2str(missingTargetLabels.'));
    end
    candidateTargetRows = find(ismember(targetOriginalLabels, targetLabelsToMap));
end

selectedSourceRows = find(ismember(sourceLabels, inputLabels));
targetCentroids = tetraCentroids( ...
    targetMesh.nodes, targetMesh.elements(candidateTargetRows, :));
sourceElementIndex = locatePointsInTets( ...
    sourceMesh.nodes, sourceMesh.elements(selectedSourceRows, :), ...
    targetCentroids, parser.Results.Tolerance);

insideSource = ~isnan(sourceElementIndex);
targetLabels = targetOriginalLabels;
locatedSourceRows = selectedSourceRows(sourceElementIndex(insideSource));
locatedSourceLabels = sourceLabels(locatedSourceRows);
candidateMappedLabels = zeros(nnz(insideSource), 1);
for labelIndex = 1:numel(inputLabels)
    candidateMappedLabels(locatedSourceLabels == inputLabels(labelIndex)) = ...
        newLabels(labelIndex);
end
mappedTargetRows = candidateTargetRows(insideSource);
targetLabels(mappedTargetRows) = candidateMappedLabels;

info = struct();
info.sourceMesh = sourceMesh;
info.targetMesh = targetMesh;
info.targetCentroids = targetCentroids;
info.sourceElementIndex = sourceElementIndex;
info.insideSource = insideSource;
info.backgroundLabel = parser.Results.BackgroundLabel;
info.inputLabels = inputLabels;
info.newLabels = newLabels;
info.targetLabelsToMap = targetLabelsToMap;
info.candidateTargetRows = candidateTargetRows;
info.mappedTargetRows = mappedTargetRows;
info.assignedFraction = nnz(insideSource) / max(1, numel(insideSource));
info.outputMshFile = outputMshFile;

if ~isempty(outputMshFile)
    writeGidTetraMeshWithLabels(outputMshFile, targetMesh, targetLabels);
end

function labels = chooseTargetLabels(mesh, backgroundLabel)
if isempty(mesh.elementData)
    labels = repmat(backgroundLabel, size(mesh.elements, 1), 1);
else
    labels = mesh.elementData(:, 1);
end
end

function values = numericColumn(values)
values = double(values(:));
values = values(~isnan(values));
end
end

function tf = isTextScalar(value)
tf = (ischar(value) && (isrow(value) || isempty(value))) || ...
     (isstring(value) && isscalar(value));
end

function labels = chooseSourceLabels(mesh, userLabels)
if isempty(userLabels)
    if ~isempty(mesh.elementData)
        labels = mesh.elementData(:, 1);
    else
        labels = ones(size(mesh.elements, 1), 1);
    end
else
    labels = userLabels(:);
end

if numel(labels) ~= size(mesh.elements, 1)
    error('map3DMeshLabels:LabelCountMismatch', ...
        'SourceLabels must contain one value per source element.');
end
end

function mesh = readGidTetraMesh(fileName)
fid = fopen(fileName, 'r');
if fid < 0
    error('map3DMeshLabels:OpenFailed', 'Could not open mesh file: %s', fileName);
end
cleanup = onCleanup(@() fclose(fid));

header = '';
line = fgetl(fid);
while ischar(line)
    if ~isempty(strtrim(line))
        header = strtrim(line);
        break;
    end
    line = fgetl(fid);
end

if isempty(header)
    error('map3DMeshLabels:EmptyMesh', 'Mesh file is empty: %s', fileName);
end

tokens = regexp(header, ...
    'MESH\s+dimension\s+(\d+)\s+ElemType\s+(\w+)\s+Nnode\s+(\d+)', ...
    'tokens', 'once');
if isempty(tokens)
    error('map3DMeshLabels:UnsupportedHeader', ...
        'Unsupported mesh header in %s: %s', fileName, header);
end

dimension = str2double(tokens{1});
elemType = tokens{2};
nnode = str2double(tokens{3});
if dimension ~= 3 || ~strcmpi(elemType, 'Tetrahedra') || nnode ~= 4
    error('map3DMeshLabels:UnsupportedMesh', ...
        'Only 3-D Tetrahedra meshes with Nnode 4 are supported.');
end

seekSection(fid, 'Coordinates', fileName);
[nodeIds, nodes] = readCoordinates(fid, fileName);

seekSection(fid, 'Elements', fileName);
[elementIds, elementNodeIds, elementData] = readElements(fid, nnode, fileName);

[isKnownNode, elements] = ismember(elementNodeIds, nodeIds);
if ~all(isKnownNode(:))
    error('map3DMeshLabels:UnknownNodeId', ...
        'Element connectivity in %s references a node ID that is not in Coordinates.', fileName);
end

mesh = struct();
mesh.fileName = fileName;
mesh.header = header;
mesh.dimension = dimension;
mesh.elemType = elemType;
mesh.nnode = nnode;
mesh.nodeIds = nodeIds;
mesh.nodes = nodes;
mesh.elementIds = elementIds;
mesh.elementNodeIds = elementNodeIds;
mesh.elements = elements;
mesh.elementData = elementData;
end

function seekSection(fid, sectionName, fileName)
line = fgetl(fid);
while ischar(line)
    if strcmpi(strtrim(line), sectionName)
        return;
    end
    line = fgetl(fid);
end

error('map3DMeshLabels:MissingSection', ...
    'Could not find section "%s" in %s.', sectionName, fileName);
end

function [nodeIds, nodes] = readCoordinates(fid, fileName)
nodeIds = zeros(0, 1);
nodes = zeros(0, 3);

line = fgetl(fid);
while ischar(line)
    stripped = strtrim(line);
    if strcmpi(stripped, 'End Coordinates')
        return;
    end

    if ~isempty(stripped)
        values = sscanf(stripped, '%f').';
        if numel(values) < 4
            error('map3DMeshLabels:BadCoordinateLine', ...
                'Invalid coordinate line in %s: %s', fileName, line);
        end
        nodeIds(end + 1, 1) = values(1); %#ok<AGROW>
        nodes(end + 1, :) = values(2:4); %#ok<AGROW>
    end

    line = fgetl(fid);
end

error('map3DMeshLabels:MissingEndCoordinates', ...
    'Could not find "End Coordinates" in %s.', fileName);
end

function [elementIds, elementNodeIds, elementData] = readElements(fid, nnode, fileName)
elementIds = zeros(0, 1);
elementNodeIds = zeros(0, nnode);
extraColumns = {};

line = fgetl(fid);
while ischar(line)
    stripped = strtrim(line);
    if strcmpi(stripped, 'End Elements')
        elementData = packExtraColumns(extraColumns);
        return;
    end

    if ~isempty(stripped)
        values = sscanf(stripped, '%f').';
        if numel(values) < nnode + 1
            error('map3DMeshLabels:BadElementLine', ...
                'Invalid element line in %s: %s', fileName, line);
        end
        elementIds(end + 1, 1) = values(1); %#ok<AGROW>
        elementNodeIds(end + 1, :) = values(2:(nnode + 1)); %#ok<AGROW>
        extraColumns{end + 1, 1} = values((nnode + 2):end); %#ok<AGROW>
    end

    line = fgetl(fid);
end

error('map3DMeshLabels:MissingEndElements', ...
    'Could not find "End Elements" in %s.', fileName);
end

function elementData = packExtraColumns(extraColumns)
if isempty(extraColumns)
    elementData = zeros(0, 0);
    return;
end

widths = cellfun(@numel, extraColumns);
maxWidth = max(widths);
if maxWidth == 0
    elementData = zeros(numel(extraColumns), 0);
    return;
end

elementData = nan(numel(extraColumns), maxWidth);
for row = 1:numel(extraColumns)
    rowValues = extraColumns{row};
    elementData(row, 1:numel(rowValues)) = rowValues;
end
end

function centroids = tetraCentroids(nodes, elements)
centroids = (nodes(elements(:, 1), :) + nodes(elements(:, 2), :) + ...
    nodes(elements(:, 3), :) + nodes(elements(:, 4), :)) / 4;
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

function writeGidTetraMeshWithLabels(fileName, mesh, labels)
if numel(labels) ~= size(mesh.elements, 1)
    error('map3DMeshLabels:WriteLabelCountMismatch', ...
        'Cannot write mapped mesh: label count does not match target element count.');
end

fid = fopen(fileName, 'w');
if fid < 0
    error('map3DMeshLabels:WriteFailed', 'Could not write mesh file: %s', fileName);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '%s\n', mesh.header);
fprintf(fid, 'Coordinates\n');
for node = 1:size(mesh.nodes, 1)
    fprintf(fid, '%10d % .16g % .16g % .16g\n', ...
        mesh.nodeIds(node), mesh.nodes(node, 1), mesh.nodes(node, 2), mesh.nodes(node, 3));
end
fprintf(fid, 'End Coordinates\n\n');
fprintf(fid, 'Elements\n');
for elem = 1:size(mesh.elements, 1)
    fprintf(fid, '%d', mesh.elementIds(elem));
    fprintf(fid, ' %d', mesh.elementNodeIds(elem, :));
    fprintf(fid, ' %.16g', labels(elem));
    if size(mesh.elementData, 2) > 1
        for extra = 2:size(mesh.elementData, 2)
            if ~isnan(mesh.elementData(elem, extra))
                fprintf(fid, ' %.16g', mesh.elementData(elem, extra));
            end
        end
    end
    fprintf(fid, '\n');
end
fprintf(fid, 'End Elements\n');
end
