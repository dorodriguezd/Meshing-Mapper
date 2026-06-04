function info = transformMeshGeometry(inputMeshFile, outputMeshFile, varargin)
%TRANSFORMMESHGEOMETRY Rotate and translate mesh coordinates without changing topology.
%
%   info = TRANSFORMMESHGEOMETRY(inputMeshFile, outputMeshFile) reads a
%   custom problem-type .dat mesh or GiD-style tetrahedral .msh mesh and
%   writes a new file with transformed node coordinates. Connectivity,
%   labels, material tables, and all non-coordinate sections are preserved.
%
%   Name-value options:
%       'TranslationInitialPoint'  Initial point for translation. Default:
%                                  [0 0 0].
%       'TranslationFinalPoint'    Final point for translation. The
%                                  translation vector is final - initial.
%                                  Default: [0 0 0].
%       'TranslationVector'        Optional direct translation vector. When
%                                  supplied, it overrides the two points.
%       'RotationAxis'             Rotation vector. Default: [0 0 1].
%       'RotationAngle'            Rotation angle. Default: 0.
%       'AngleUnit'                'degrees' or 'radians'. Default:
%                                  'degrees'.
%       'RotationCenter'           Point about which rotation is applied.
%                                  Default: [0 0 0].
%       'TransformOrder'           Order of operations: ["rotation"
%                                  "translation"] by default.

parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, 'inputMeshFile', @isTextScalar);
addRequired(parser, 'outputMeshFile', @isTextScalar);
addParameter(parser, 'TranslationInitialPoint', [0 0 0], @isThreeVector);
addParameter(parser, 'TranslationFinalPoint', [0 0 0], @isThreeVector);
addParameter(parser, 'TranslationVector', [], @(x) isempty(x) || isThreeVector(x));
addParameter(parser, 'RotationAxis', [0 0 1], @isThreeVector);
addParameter(parser, 'RotationAngle', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(parser, 'AngleUnit', 'degrees', @isTextScalar);
addParameter(parser, 'RotationCenter', [0 0 0], @isThreeVector);
addParameter(parser, 'TransformOrder', {'rotation', 'translation'}, @isTextVector);
parse(parser, inputMeshFile, outputMeshFile, varargin{:});

inputMeshFile = char(parser.Results.inputMeshFile);
outputMeshFile = char(parser.Results.outputMeshFile);

mesh = readMeshCoordinateBlock(inputMeshFile);
translationVector = resolveTranslationVector( ...
    parser.Results.TranslationInitialPoint, ...
    parser.Results.TranslationFinalPoint, ...
    parser.Results.TranslationVector);
rotationMatrix = axisAngleRotationMatrix( ...
    parser.Results.RotationAxis, parser.Results.RotationAngle, parser.Results.AngleUnit);
rotationCenter = rowVector3(parser.Results.RotationCenter);
transformOrder = normalizeTransformOrder(parser.Results.TransformOrder);

rotation4x4 = rotationAboutPointMatrix(rotationMatrix, rotationCenter);
translation4x4 = translationMatrix(translationVector);
transform4x4 = composeTransform(rotation4x4, translation4x4, transformOrder);

transformedNodes = applyHomogeneousTransform(mesh.nodes, transform4x4);
writeTransformedMesh(outputMeshFile, mesh, transformedNodes);

info = struct();
info.inputMeshFile = inputMeshFile;
info.outputMeshFile = outputMeshFile;
info.meshFormat = mesh.format;
info.numberOfNodes = size(mesh.nodes, 1);
info.numberOfElements = mesh.numberOfElements;
info.originalBoundingBox = boundingBox(mesh.nodes);
info.transformedBoundingBox = boundingBox(transformedNodes);
info.translationVector = translationVector;
info.rotationAxis = rowVector3(parser.Results.RotationAxis);
info.rotationAngle = parser.Results.RotationAngle;
info.angleUnit = char(parser.Results.AngleUnit);
info.rotationCenter = rotationCenter;
info.transformOrder = transformOrder;
info.rotationMatrix3x3 = rotationMatrix;
info.rotationMatrix4x4 = rotation4x4;
info.translationMatrix4x4 = translation4x4;
info.transformMatrix4x4 = transform4x4;
end

function tf = isTextScalar(value)
tf = (ischar(value) && (isrow(value) || isempty(value))) || ...
     (isstring(value) && isscalar(value));
end

function tf = isTextVector(value)
tf = isempty(value) || ischar(value) || isstring(value) || iscellstr(value);
end

function tf = isThreeVector(value)
tf = isnumeric(value) && numel(value) == 3 && all(isfinite(value(:)));
end

function vector = rowVector3(value)
vector = double(value(:).');
end

function vector = resolveTranslationVector(initialPoint, finalPoint, translationVector)
if isempty(translationVector)
    vector = rowVector3(finalPoint) - rowVector3(initialPoint);
else
    vector = rowVector3(translationVector);
end
end

function order = normalizeTransformOrder(order)
order = textColumn(order);
if isempty(order)
    order = ["rotation"; "translation"];
end
order = lower(order(:));

validOperations = ["rotation"; "translation"];
for operationIndex = 1:numel(order)
    if ~any(order(operationIndex) == validOperations)
        error('transformMeshGeometry:UnsupportedTransformOperation', ...
            'TransformOrder can only contain "rotation" and "translation".');
    end
end

if numel(unique(order)) ~= numel(order)
    error('transformMeshGeometry:RepeatedTransformOperation', ...
        'TransformOrder cannot repeat an operation.');
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

function rotationMatrix = axisAngleRotationMatrix(axis, angle, angleUnit)
axis = rowVector3(axis);
axisNorm = norm(axis);
if axisNorm == 0
    error('transformMeshGeometry:ZeroRotationAxis', ...
        'RotationAxis must not be the zero vector.');
end
axis = axis / axisNorm;

switch lower(char(angleUnit))
    case {'degree', 'degrees', 'deg'}
        angleRadians = deg2rad(angle);
    case {'radian', 'radians', 'rad'}
        angleRadians = angle;
    otherwise
        error('transformMeshGeometry:UnsupportedAngleUnit', ...
            'AngleUnit must be "degrees" or "radians".');
end

kx = axis(1);
ky = axis(2);
kz = axis(3);
kCross = [  0, -kz,  ky; ...
           kz,   0, -kx; ...
          -ky,  kx,   0];
rotationMatrix = eye(3) + sin(angleRadians) * kCross + ...
    (1 - cos(angleRadians)) * (kCross * kCross);
end

function matrix = rotationAboutPointMatrix(rotationMatrix, center)
matrix = eye(4);
matrix(1:3, 1:3) = rotationMatrix;
matrix(1:3, 4) = center(:) - rotationMatrix * center(:);
end

function matrix = translationMatrix(translationVector)
matrix = eye(4);
matrix(1:3, 4) = rowVector3(translationVector).';
end

function matrix = composeTransform(rotation4x4, translation4x4, transformOrder)
matrix = eye(4);
for operationIndex = 1:numel(transformOrder)
    switch transformOrder(operationIndex)
        case "rotation"
            matrix = rotation4x4 * matrix;
        case "translation"
            matrix = translation4x4 * matrix;
    end
end
end

function nodes = applyHomogeneousTransform(nodes, matrix)
homogeneousNodes = [nodes, ones(size(nodes, 1), 1)] * matrix.';
nodes = homogeneousNodes(:, 1:3);
end

function box = boundingBox(nodes)
box = [min(nodes, [], 1); max(nodes, [], 1)];
end

function mesh = readMeshCoordinateBlock(fileName)
rawLines = readTextLines(fileName);
format = detectMeshFormat(fileName, rawLines);
coordinatesLine = findSection(rawLines, 'Coordinates', fileName);
endCoordinatesLine = findSection(rawLines, 'End Coordinates', fileName);

switch format
    case 'dat'
        nodeCount = parseCount(rawLines{coordinatesLine + 1}, 'Coordinates', fileName);
        nodes = parseNumericBlock(rawLines, coordinatesLine + 2, nodeCount, 3, 'coordinate', fileName);
        nodeIds = [];
    case 'msh'
        coordinateLines = rawLines((coordinatesLine + 1):(endCoordinatesLine - 1));
        [nodeIds, nodes] = parseMshCoordinates(coordinateLines, fileName);
    otherwise
        error('transformMeshGeometry:UnsupportedMeshFormat', ...
            'Unsupported mesh format: %s', format);
end

mesh = struct();
mesh.fileName = fileName;
mesh.rawLines = rawLines;
mesh.format = format;
mesh.coordinatesLine = coordinatesLine;
mesh.endCoordinatesLine = endCoordinatesLine;
mesh.nodeIds = nodeIds;
mesh.nodes = nodes;
mesh.numberOfElements = countElements(rawLines, format, fileName);
end

function format = detectMeshFormat(fileName, rawLines)
[~, ~, extension] = fileparts(fileName);
extension = lower(extension);
firstTextLine = '';
for lineIndex = 1:numel(rawLines)
    stripped = strtrim(rawLines{lineIndex});
    if ~isempty(stripped)
        firstTextLine = stripped;
        break;
    end
end

if strcmp(extension, '.dat')
    format = 'dat';
elseif strcmp(extension, '.msh') || startsWith(firstTextLine, 'MESH', 'IgnoreCase', true)
    format = 'msh';
else
    error('transformMeshGeometry:UnknownMeshFormat', ...
        'Could not infer mesh format for %s.', fileName);
end
end

function rawLines = readTextLines(fileName)
fid = fopen(fileName, 'r');
if fid < 0
    error('transformMeshGeometry:OpenFailed', 'Could not open file: %s', fileName);
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
lineNumber = find(strcmpi(strtrim(rawLines), sectionName), 1, 'first');
if isempty(lineNumber)
    error('transformMeshGeometry:MissingSection', ...
        'Could not find section "%s" in %s.', sectionName, fileName);
end
end

function count = parseCount(line, sectionName, fileName)
count = sscanf(strtrim(line), '%d', 1);
if isempty(count) || count < 0
    error('transformMeshGeometry:BadCount', ...
        'Invalid %s count in %s: %s', sectionName, fileName, line);
end
end

function values = parseNumericBlock(rawLines, startLine, rowCount, minColumns, blockName, fileName)
values = zeros(rowCount, minColumns);
for row = 1:rowCount
    lineNumber = startLine + row - 1;
    if lineNumber > numel(rawLines)
        error('transformMeshGeometry:UnexpectedEndOfFile', ...
            'Unexpected end of file while reading %s rows in %s.', blockName, fileName);
    end

    rowValues = sscanf(strtrim(rawLines{lineNumber}), '%f').';
    if numel(rowValues) < minColumns
        error('transformMeshGeometry:BadNumericRow', ...
            'Invalid %s row in %s: %s', blockName, fileName, rawLines{lineNumber});
    end
    values(row, :) = rowValues(1:minColumns);
end
end

function [nodeIds, nodes] = parseMshCoordinates(coordinateLines, fileName)
nodeIds = zeros(numel(coordinateLines), 1);
nodes = zeros(numel(coordinateLines), 3);
for row = 1:numel(coordinateLines)
    rowValues = sscanf(strtrim(coordinateLines{row}), '%f').';
    if numel(rowValues) < 4
        error('transformMeshGeometry:BadMshCoordinateRow', ...
            'Invalid .msh coordinate row in %s: %s', fileName, coordinateLines{row});
    end
    nodeIds(row) = rowValues(1);
    nodes(row, :) = rowValues(2:4);
end
end

function numberOfElements = countElements(rawLines, format, fileName)
elementsLine = find(strcmpi(strtrim(rawLines), 'Elements'), 1, 'first');
endElementsLine = find(strcmpi(strtrim(rawLines), 'End Elements'), 1, 'first');
if isempty(elementsLine)
    numberOfElements = 0;
    return;
end

switch format
    case 'dat'
        numberOfElements = parseCount(rawLines{elementsLine + 1}, 'Elements', fileName);
    case 'msh'
        if isempty(endElementsLine)
            numberOfElements = 0;
        else
            elementLines = rawLines((elementsLine + 1):(endElementsLine - 1));
            numberOfElements = nnz(cellfun(@(line) ~isempty(strtrim(line)), elementLines));
        end
end
end

function writeTransformedMesh(fileName, mesh, transformedNodes)
fid = fopen(fileName, 'w');
if fid < 0
    error('transformMeshGeometry:WriteFailed', 'Could not write file: %s', fileName);
end
cleanup = onCleanup(@() fclose(fid));

for lineIndex = 1:(mesh.coordinatesLine - 1)
    fprintf(fid, '%s\n', mesh.rawLines{lineIndex});
end

switch mesh.format
    case 'dat'
        fprintf(fid, 'Coordinates\n');
        fprintf(fid, '%9d\n', size(transformedNodes, 1));
        for node = 1:size(transformedNodes, 1)
            fprintf(fid, '%16.9f %16.9f %16.9f\n', ...
                transformedNodes(node, 1), transformedNodes(node, 2), transformedNodes(node, 3));
        end
        fprintf(fid, 'end Coordinates\n');
    case 'msh'
        fprintf(fid, 'Coordinates\n');
        for node = 1:size(transformedNodes, 1)
            fprintf(fid, '%10d % .16g % .16g % .16g\n', ...
                mesh.nodeIds(node), transformedNodes(node, 1), ...
                transformedNodes(node, 2), transformedNodes(node, 3));
        end
        fprintf(fid, 'End Coordinates\n');
end

for lineIndex = (mesh.endCoordinatesLine + 1):numel(mesh.rawLines)
    fprintf(fid, '%s\n', mesh.rawLines{lineIndex});
end
end
