function figureHandles = plotDatMaterialLabels(meshOrDatFile, varargin)
%PLOTDATMATERIALLABELS Plot requested material labels from a tetrahedral .dat mesh.
%
%   plotDatMaterialLabels(datFile) plots every material label found in a
%   custom problem-type .dat file.
%
%   plotDatMaterialLabels(mesh, 'ElementLabels', labels) plots labels using
%   a mesh struct with fields nodes and elements, such as info.targetMesh
%   returned by mapDatMeshLabels.
%
%   Name-value options:
%       'ElementLabels'  Label per tetrahedron. Required when plotting a
%                        remapped label vector from a mesh struct.
%       'LabelsToPlot'   Material labels to plot. Default: all labels.
%       'LabelNames'     Names for LabelsToPlot, in the same order.
%       'PlotMode'       'separate' or 'overlay'. Default: 'separate'.
%       'SaveFolder'     Optional folder where PNG validation plots are saved.
%       'Visible'        Figure visibility: 'on' or 'off'. Default: 'on'.
%       'ShowContext'    Plot the whole mesh as a transparent context.
%                        Default: true.

parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, 'meshOrDatFile');
addParameter(parser, 'ElementLabels', [], @(x) isnumeric(x) || islogical(x));
addParameter(parser, 'LabelsToPlot', [], @(x) isnumeric(x) || islogical(x));
addParameter(parser, 'LabelNames', strings(0, 1), @isTextVector);
addParameter(parser, 'PlotMode', 'separate', @isTextScalar);
addParameter(parser, 'SaveFolder', '', @isTextScalar);
addParameter(parser, 'Visible', 'on', @isTextScalar);
addParameter(parser, 'ShowContext', true, @(x) islogical(x) && isscalar(x));
parse(parser, meshOrDatFile, varargin{:});

mesh = loadDatPlotMesh(meshOrDatFile);
elementLabels = numericColumn(parser.Results.ElementLabels);
if isempty(elementLabels)
    if isfield(mesh, 'elementLabels')
        elementLabels = mesh.elementLabels;
    else
        error('plotDatMaterialLabels:MissingLabels', ...
            'ElementLabels must be supplied when the mesh has no elementLabels field.');
    end
end

if numel(elementLabels) ~= size(mesh.elements, 1)
    error('plotDatMaterialLabels:LabelCountMismatch', ...
        'ElementLabels must contain one value per tetrahedron.');
end

labelsToPlot = numericColumn(parser.Results.LabelsToPlot);
if isempty(labelsToPlot)
    labelsToPlot = unique(elementLabels, 'stable');
end

labelNames = textColumn(parser.Results.LabelNames);
if isempty(labelNames)
    labelNames = defaultLabelNames(labelsToPlot);
elseif numel(labelNames) ~= numel(labelsToPlot)
    error('plotDatMaterialLabels:LabelNameCountMismatch', ...
        'LabelNames must contain one name per requested label.');
end

plotMode = lower(char(parser.Results.PlotMode));
saveFolder = char(parser.Results.SaveFolder);
visible = char(parser.Results.Visible);
showContext = parser.Results.ShowContext;

if ~isempty(saveFolder) && ~exist(saveFolder, 'dir')
    mkdir(saveFolder);
end

nodes = mesh.nodes;
elements = mesh.elements;
targetFaces = [];
if showContext
    targetFaces = freeBoundary(triangulation(elements, nodes));
end

switch plotMode
    case 'separate'
        figureHandles = plotSeparateLabels( ...
            nodes, elements, elementLabels, labelsToPlot, labelNames, ...
            targetFaces, saveFolder, visible);
    case 'overlay'
        figureHandles = plotOverlayLabels( ...
            nodes, elements, elementLabels, labelsToPlot, labelNames, ...
            targetFaces, saveFolder, visible);
    otherwise
        error('plotDatMaterialLabels:UnsupportedPlotMode', ...
            'PlotMode must be "separate" or "overlay".');
end
end

function figureHandles = plotSeparateLabels(nodes, elements, elementLabels, labelsToPlot, ...
    labelNames, targetFaces, saveFolder, visible)
figureHandles = gobjects(numel(labelsToPlot), 1);
labelColors = lines(numel(labelsToPlot));

for labelIndex = 1:numel(labelsToPlot)
    label = labelsToPlot(labelIndex);
    labelName = char(labelNames(labelIndex));
    activeElements = elementLabels == label;

    figureHandles(labelIndex) = figure( ...
        'Name', sprintf('Material %.15g - %s', label, labelName), ...
        'Color', 'w', ...
        'Visible', visible);
    hold on;
    plotContext(nodes, targetFaces);

    if any(activeElements)
        plotActiveLabel(nodes, elements(activeElements, :), labelColors(labelIndex, :), ...
            sprintf('%.15g - %s', label, labelName));
    else
        warning('plotDatMaterialLabels:MissingRequestedLabel', ...
            'Requested label %.15g was not found in the element labels.', label);
    end

    finishAxes(sprintf('Material %.15g - %s', label, labelName));
    if ~isempty(saveFolder)
        exportgraphics(figureHandles(labelIndex), ...
            fullfile(saveFolder, sprintf('label_%s_%s.png', ...
            sanitizeNumber(label), sanitizeFileName(labelName))), ...
            'Resolution', 160);
    end
end
end

function figureHandles = plotOverlayLabels(nodes, elements, elementLabels, labelsToPlot, ...
    labelNames, targetFaces, saveFolder, visible)
figureHandles = figure('Name', 'Requested material labels', 'Color', 'w', 'Visible', visible);
hold on;
plotContext(nodes, targetFaces);
labelColors = lines(numel(labelsToPlot));

for labelIndex = 1:numel(labelsToPlot)
    label = labelsToPlot(labelIndex);
    labelName = char(labelNames(labelIndex));
    activeElements = elementLabels == label;
    if any(activeElements)
        plotActiveLabel(nodes, elements(activeElements, :), labelColors(labelIndex, :), ...
            sprintf('%.15g - %s', label, labelName));
    else
        warning('plotDatMaterialLabels:MissingRequestedLabel', ...
            'Requested label %.15g was not found in the element labels.', label);
    end
end

finishAxes('Requested material labels');
if ~isempty(saveFolder)
    exportgraphics(figureHandles, fullfile(saveFolder, 'requested_labels_overlay.png'), ...
        'Resolution', 160);
end
end

function plotContext(nodes, targetFaces)
if isempty(targetFaces)
    return;
end

patch( ...
    'Faces', targetFaces, ...
    'Vertices', nodes, ...
    'FaceColor', [0.76 0.78 0.80], ...
    'FaceAlpha', 0.08, ...
    'EdgeColor', 'none', ...
    'DisplayName', 'mesh context');
end

function plotActiveLabel(nodes, activeConnectivity, faceColor, displayName)
[activeNodeIds, ~, compactConnectivity] = unique(activeConnectivity(:));
compactConnectivity = reshape(compactConnectivity, size(activeConnectivity));
activeNodes = nodes(activeNodeIds, :);
activeTriangulation = triangulation(compactConnectivity, activeNodes);
activeFaces = freeBoundary(activeTriangulation);

patch( ...
    'Faces', activeFaces, ...
    'Vertices', activeNodes, ...
    'FaceColor', faceColor, ...
    'FaceAlpha', 0.90, ...
    'EdgeColor', 'none', ...
    'DisplayName', displayName);
end

function finishAxes(plotTitle)
axis equal;
axis tight;
grid on;
view(38, 24);
xlabel('X');
ylabel('Y');
zlabel('Z');
title(plotTitle);
legend('Location', 'northeastoutside');
camlight('headlight');
lighting gouraud;
hold off;
end

function mesh = loadDatPlotMesh(meshOrDatFile)
if isstruct(meshOrDatFile)
    mesh = meshOrDatFile;
    if ~isfield(mesh, 'nodes') || ~isfield(mesh, 'elements')
        error('plotDatMaterialLabels:InvalidMeshStruct', ...
            'Mesh structs must contain nodes and elements fields.');
    end
    return;
end

datFile = char(meshOrDatFile);
rawLines = readTextLines(datFile);
coordinatesLine = findSection(rawLines, 'Coordinates', datFile);
elementsLine = findSection(rawLines, 'Elements', datFile);

coordinateCount = parseCount(rawLines{coordinatesLine + 1}, 'Coordinates', datFile);
nodes = parseNumericBlock(rawLines, coordinatesLine + 2, coordinateCount, 3, 'coordinate', datFile);

elementCount = parseCount(rawLines{elementsLine + 1}, 'Elements', datFile);
elementRows = parseNumericBlock(rawLines, elementsLine + 2, elementCount, 5, 'element', datFile);

mesh = struct();
mesh.fileName = datFile;
mesh.nodes = nodes;
mesh.elements = elementRows(:, 1:4);
mesh.elementLabels = elementRows(:, end);
end

function rawLines = readTextLines(fileName)
fid = fopen(fileName, 'r');
if fid < 0
    error('plotDatMaterialLabels:OpenFailed', 'Could not open file: %s', fileName);
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
    error('plotDatMaterialLabels:MissingSection', ...
        'Could not find section "%s" in %s.', sectionName, fileName);
end
lineNumber = matches;
end

function count = parseCount(line, sectionName, fileName)
count = sscanf(strtrim(line), '%d', 1);
if isempty(count) || count < 0
    error('plotDatMaterialLabels:BadCount', ...
        'Invalid %s count in %s: %s', sectionName, fileName, line);
end
end

function values = parseNumericBlock(rawLines, startLine, rowCount, minColumns, blockName, fileName)
values = zeros(rowCount, minColumns);
for row = 1:rowCount
    lineNumber = startLine + row - 1;
    rowValues = sscanf(strtrim(rawLines{lineNumber}), '%f').';
    if numel(rowValues) < minColumns
        error('plotDatMaterialLabels:BadNumericRow', ...
            'Invalid %s row in %s: %s', blockName, fileName, rawLines{lineNumber});
    end
    if row == 1 && numel(rowValues) > minColumns
        values = zeros(rowCount, numel(rowValues));
    elseif numel(rowValues) ~= size(values, 2)
        error('plotDatMaterialLabels:InconsistentColumns', ...
            'Inconsistent %s column count in %s at line %d.', blockName, fileName, lineNumber);
    end
    values(row, :) = rowValues;
end
end

function values = numericColumn(values)
values = double(values(:));
values = values(~isnan(values));
end

function names = defaultLabelNames(labels)
names = strings(numel(labels), 1);
for labelIndex = 1:numel(labels)
    names(labelIndex) = sprintf('label_%.15g', labels(labelIndex));
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

function tf = isTextScalar(value)
tf = (ischar(value) && (isrow(value) || isempty(value))) || ...
     (isstring(value) && isscalar(value));
end

function tf = isTextVector(value)
tf = isempty(value) || ischar(value) || isstring(value) || iscellstr(value);
end

function text = sanitizeNumber(value)
text = regexprep(sprintf('%.15g', value), '[^\w-]', '_');
end

function text = sanitizeFileName(text)
text = regexprep(char(text), '[^\w-]', '_');
text = regexprep(text, '_+', '_');
text = regexprep(text, '^_|_$', '');
if isempty(text)
    text = 'material';
end
end
