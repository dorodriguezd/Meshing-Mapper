function figureHandle = visualizeDatLabelGroups(datFile, labelGroups, varargin)
%VISUALIZEDATLABELGROUPS Plot selected DAT material labels as visual groups.
%
%   visualizeDatLabelGroups(datFile, {28, 3:18}) plots label 28 as one
%   group and labels 3 through 18 as a second group.
%
%   visualizeDatLabelGroups(datFile, [1 2 3]) plots labels 1, 2, and 3 as
%   separate groups.
%
%   Name-value options:
%       'GroupNames'     Legend names, one per group. Default: label names.
%       'Colors'         RGB color per group. Default: lines().
%       'Alphas'         Face alpha per group. Default: 0.75.
%       'OutputFolder'   Folder where outputs are saved. Default: no save.
%       'OutputName'     Output file stem. Default: DAT name plus labels.
%       'OutputFormats'  Formats to save, e.g. ["png" "fig"]. Default: "png".
%       'Visible'        Figure visibility: 'on' or 'off'. Default: 'on'.
%       'Title'          Figure title. Default: selected label groups.
%       'View'           Two-element view angle. Default: [38 24].
%       'Resolution'     Raster export resolution. Default: 180.
%
%   If labelGroups is omitted or empty, every material label found in the
%   DAT file is plotted as an independent group.

if nargin < 2
    labelGroups = {};
end

parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, 'datFile', @isTextScalar);
addRequired(parser, 'labelGroups', @(x) isempty(x) || isnumeric(x) || islogical(x) || iscell(x));
addParameter(parser, 'GroupNames', strings(0, 1), @isTextVector);
addParameter(parser, 'Colors', [], @(x) isempty(x) || (isnumeric(x) && size(x, 2) == 3));
addParameter(parser, 'Alphas', [], @(x) isempty(x) || isnumeric(x));
addParameter(parser, 'OutputFolder', '', @isTextScalar);
addParameter(parser, 'OutputName', '', @isTextScalar);
addParameter(parser, 'OutputFormats', "png", @isTextVector);
addParameter(parser, 'Visible', 'on', @isTextScalar);
addParameter(parser, 'Title', '', @isTextScalar);
addParameter(parser, 'View', [38 24], @(x) isnumeric(x) && numel(x) == 2);
addParameter(parser, 'Resolution', 180, @(x) isnumeric(x) && isscalar(x) && x > 0);
parse(parser, datFile, labelGroups, varargin{:});

datFile = char(parser.Results.datFile);
requestedGroups = normalizeLabelGroups(parser.Results.labelGroups);
if isempty(requestedGroups)
    labelsToKeep = [];
else
    labelsToKeep = unique(vertcat(requestedGroups{:}), 'stable');
end

mesh = readDatLabelSubset(datFile, labelsToKeep);
if isempty(requestedGroups)
    requestedGroups = makeSingleLabelGroups(unique(mesh.elementLabels, 'stable'));
end

groupCount = numel(requestedGroups);
if groupCount == 0
    error('visualizeDatLabelGroups:NoLabelsFound', ...
        'No material labels were found in %s.', datFile);
end

groupNames = textColumn(parser.Results.GroupNames);
if isempty(groupNames)
    groupNames = defaultGroupNames(requestedGroups);
elseif numel(groupNames) ~= groupCount
    error('visualizeDatLabelGroups:GroupNameCountMismatch', ...
        'GroupNames must contain one value per label group.');
end

groupColors = parser.Results.Colors;
if isempty(groupColors)
    groupColors = lines(groupCount);
elseif size(groupColors, 1) ~= groupCount
    error('visualizeDatLabelGroups:ColorCountMismatch', ...
        'Colors must contain one RGB row per label group.');
end

groupAlphas = double(parser.Results.Alphas(:));
if isempty(groupAlphas)
    groupAlphas = repmat(0.75, groupCount, 1);
elseif isscalar(groupAlphas)
    groupAlphas = repmat(groupAlphas, groupCount, 1);
elseif numel(groupAlphas) ~= groupCount
    error('visualizeDatLabelGroups:AlphaCountMismatch', ...
        'Alphas must contain one value per label group, or a scalar.');
end
groupAlphas = max(0, min(1, groupAlphas));

figureTitle = char(parser.Results.Title);
if isempty(figureTitle)
    figureTitle = 'Selected DAT label groups';
end

figureHandle = figure( ...
    'Name', figureTitle, ...
    'Color', 'w', ...
    'Visible', char(parser.Results.Visible));
ax = axes(figureHandle);
hold(ax, 'on');

for groupIndex = 1:groupCount
    activeLabels = requestedGroups{groupIndex};
    activeElements = mesh.elements(ismember(mesh.elementLabels, activeLabels), :);
    displayName = char(groupNames(groupIndex));
    if isempty(activeElements)
        warning('visualizeDatLabelGroups:EmptyGroup', ...
            'No elements found for group "%s".', displayName);
        continue;
    end

    plotElementGroup(ax, mesh.nodes, activeElements, ...
        groupColors(groupIndex, :), groupAlphas(groupIndex), displayName);
end

finishAxes(ax, figureTitle, parser.Results.View);
hold(ax, 'off');

saveRequestedOutputs(figureHandle, parser.Results.OutputFolder, ...
    parser.Results.OutputName, parser.Results.OutputFormats, datFile, requestedGroups, ...
    parser.Results.Resolution);
end

function mesh = readDatLabelSubset(datFile, labelsToKeep)
fid = fopen(datFile, 'r');
if fid < 0
    error('visualizeDatLabelGroups:OpenFailed', ...
        'Could not open file: %s', datFile);
end
cleanup = onCleanup(@() fclose(fid));

seekSection(fid, 'Coordinates', datFile);
nodeCount = parseCount(fgetl(fid), 'Coordinates', datFile);
nodeData = textscan(fid, '%f %f %f', nodeCount, 'CollectOutput', true);
nodes = nodeData{1};

seekSection(fid, 'Elements', datFile);
elementCount = parseCount(fgetl(fid), 'Elements', datFile);

elementChunks = {};
labelChunks = {};
chunkSize = 250000;
keepAllLabels = isempty(labelsToKeep);
remaining = elementCount;
while remaining > 0
    rowsToRead = min(chunkSize, remaining);
    elementData = textscan(fid, '%f %f %f %f %f', rowsToRead, 'CollectOutput', true);
    elementData = elementData{1};
    if isempty(elementData)
        break;
    end

    if keepAllLabels
        keepRows = true(size(elementData, 1), 1);
    else
        keepRows = ismember(elementData(:, 5), labelsToKeep);
    end

    if any(keepRows)
        elementChunks{end + 1, 1} = elementData(keepRows, 1:4); %#ok<AGROW>
        labelChunks{end + 1, 1} = elementData(keepRows, 5); %#ok<AGROW>
    end
    remaining = remaining - rowsToRead;
end

if isempty(elementChunks)
    elements = zeros(0, 4);
    labels = zeros(0, 1);
else
    elements = vertcat(elementChunks{:});
    labels = vertcat(labelChunks{:});
end

mesh = struct();
mesh.fileName = datFile;
mesh.nodes = nodes;
mesh.elements = elements;
mesh.elementLabels = labels;
end

function seekSection(fid, sectionName, fileName)
line = fgetl(fid);
while ischar(line)
    if strcmpi(strtrim(line), sectionName)
        return;
    end
    line = fgetl(fid);
end

error('visualizeDatLabelGroups:MissingSection', ...
    'Could not find section "%s" in %s.', sectionName, fileName);
end

function count = parseCount(line, sectionName, fileName)
count = sscanf(strtrim(line), '%d', 1);
if isempty(count) || count < 0
    error('visualizeDatLabelGroups:BadCount', ...
        'Invalid %s count in %s: %s', sectionName, fileName, line);
end
end

function labelGroups = normalizeLabelGroups(labelGroups)
if isempty(labelGroups)
    labelGroups = {};
    return;
end

if isnumeric(labelGroups) || islogical(labelGroups)
    labels = double(labelGroups(:));
    labelGroups = makeSingleLabelGroups(labels);
    return;
end

for groupIndex = 1:numel(labelGroups)
    labels = double(labelGroups{groupIndex}(:));
    labels = labels(~isnan(labels));
    labelGroups{groupIndex} = labels;
end
labelGroups = labelGroups(:);
end

function labelGroups = makeSingleLabelGroups(labels)
labels = double(labels(:));
labels = labels(~isnan(labels));
labelGroups = cell(numel(labels), 1);
for labelIndex = 1:numel(labels)
    labelGroups{labelIndex} = labels(labelIndex);
end
end

function names = defaultGroupNames(labelGroups)
names = strings(numel(labelGroups), 1);
for groupIndex = 1:numel(labelGroups)
    labels = labelGroups{groupIndex};
    if isscalar(labels)
        names(groupIndex) = sprintf('label %.15g', labels);
    else
        names(groupIndex) = sprintf('labels %.15g-%.15g', min(labels), max(labels));
    end
end
end

function plotElementGroup(ax, nodes, elements, color, alphaValue, displayName)
[activeNodeIds, ~, compactConnectivity] = unique(elements(:));
compactConnectivity = reshape(compactConnectivity, size(elements));
activeNodes = nodes(activeNodeIds, :);
activeFaces = freeBoundary(triangulation(compactConnectivity, activeNodes));

patch(ax, ...
    'Faces', activeFaces, ...
    'Vertices', activeNodes, ...
    'FaceColor', color, ...
    'FaceAlpha', alphaValue, ...
    'EdgeColor', 'none', ...
    'DisplayName', displayName);
end

function finishAxes(ax, plotTitle, viewAngle)
axis(ax, 'equal');
axis(ax, 'tight');
grid(ax, 'on');
view(ax, viewAngle(1), viewAngle(2));
xlabel(ax, 'X');
ylabel(ax, 'Y');
zlabel(ax, 'Z');
title(ax, plotTitle);
legend(ax, 'Location', 'northeastoutside');
camlight(ax, 'headlight');
lighting(ax, 'gouraud');
end

function saveRequestedOutputs(figureHandle, outputFolder, outputName, outputFormats, ...
    datFile, labelGroups, resolution)
outputFolder = char(outputFolder);
if isempty(outputFolder)
    return;
end

if exist(outputFolder, 'dir') ~= 7
    mkdir(outputFolder);
end

outputName = char(outputName);
if isempty(outputName)
    [~, datName] = fileparts(datFile);
    outputName = [datName '_' labelGroupSuffix(labelGroups)];
end
outputName = sanitizeFileName(outputName);

formats = lower(textColumn(outputFormats));
for formatIndex = 1:numel(formats)
    formatName = char(formats(formatIndex));
    outputFile = fullfile(outputFolder, [outputName '.' formatName]);
    switch formatName
        case 'fig'
            savefig(figureHandle, outputFile);
        case {'png', 'pdf', 'jpg', 'jpeg', 'tif', 'tiff'}
            exportgraphics(figureHandle, outputFile, 'Resolution', resolution);
        otherwise
            error('visualizeDatLabelGroups:UnsupportedOutputFormat', ...
                'Unsupported output format "%s".', formatName);
    end
    fprintf('Saved %s\n', outputFile);
end
end

function suffix = labelGroupSuffix(labelGroups)
parts = strings(numel(labelGroups), 1);
for groupIndex = 1:numel(labelGroups)
    labels = labelGroups{groupIndex};
    if isscalar(labels)
        parts(groupIndex) = sprintf('label_%s', sanitizeNumber(labels));
    else
        parts(groupIndex) = sprintf('labels_%s_to_%s', ...
            sanitizeNumber(min(labels)), sanitizeNumber(max(labels)));
    end
end
suffix = char(strjoin(parts, '_'));
end

function values = textColumn(values)
if isempty(values)
    values = strings(0, 1);
elseif ischar(values)
    values = string({values});
elseif iscell(values)
    values = string(values(:));
else
    values = string(values(:));
end
values = strtrim(values);
values = values(values ~= "");
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
    text = 'dat_label_groups';
end
end
