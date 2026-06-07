function figureHandle = visualizeMshLabelGroups(mshFile, labelGroups, varargin)
%VISUALIZEMSHLABELGROUPS Plot selected GiD MSH tetrahedral label groups.

if nargin < 2
    labelGroups = {};
end
parser = inputParser;
addRequired(parser, 'mshFile', @isTextScalar);
addRequired(parser, 'labelGroups', @(x) isempty(x) || isnumeric(x) || iscell(x));
addParameter(parser, 'GroupNames', strings(0, 1), @isTextVector);
addParameter(parser, 'Colors', [], @(x) isempty(x) || (isnumeric(x) && size(x, 2) == 3));
addParameter(parser, 'Alphas', [], @(x) isempty(x) || isnumeric(x));
addParameter(parser, 'OutputFolder', '', @isTextScalar);
addParameter(parser, 'OutputName', '', @isTextScalar);
addParameter(parser, 'OutputFormats', "png", @isTextVector);
addParameter(parser, 'Visible', 'on', @isTextScalar);
addParameter(parser, 'Title', 'GiD MSH label groups', @isTextScalar);
addParameter(parser, 'View', [38 24], @(x) isnumeric(x) && numel(x) == 2);
addParameter(parser, 'Resolution', 180, @(x) isnumeric(x) && isscalar(x));
parse(parser, mshFile, labelGroups, varargin{:});

mesh = readMsh(char(parser.Results.mshFile));
groups = normalizeGroups(labelGroups, mesh.labels);
names = textColumn(parser.Results.GroupNames);
if isempty(names)
    names = strings(numel(groups), 1);
    for index = 1:numel(groups)
        names(index) = "labels " + strjoin(string(groups{index}), ",");
    end
elseif numel(names) ~= numel(groups)
    error('visualizeMshLabelGroups:GroupNameCountMismatch', ...
        'GroupNames must contain one value per label group.');
end
colors = parser.Results.Colors;
if isempty(colors)
    colors = lines(numel(groups));
elseif size(colors, 1) ~= numel(groups)
    error('visualizeMshLabelGroups:ColorCountMismatch', ...
        'Colors must contain one RGB row per label group.');
end
alphas = parser.Results.Alphas(:);
if isempty(alphas)
    alphas = repmat(0.75, numel(groups), 1);
elseif isscalar(alphas)
    alphas = repmat(alphas, numel(groups), 1);
elseif numel(alphas) ~= numel(groups)
    error('visualizeMshLabelGroups:AlphaCountMismatch', ...
        'Alphas must contain one value per label group or one scalar.');
end

figureHandle = figure('Color', 'w', 'Visible', char(parser.Results.Visible));
ax = axes(figureHandle);
hold(ax, 'on');
for index = 1:numel(groups)
    active = ismember(mesh.labels, groups{index});
    if ~any(active)
        continue;
    end
    plotGroup(ax, mesh.nodes, mesh.elements(active, :), colors(index, :), ...
        alphas(index), char(names(index)));
end
axis(ax, 'equal');
axis(ax, 'tight');
grid(ax, 'on');
view(ax, parser.Results.View);
xlabel(ax, 'X [cm]');
ylabel(ax, 'Y [cm]');
zlabel(ax, 'Z [cm]');
title(ax, char(parser.Results.Title), 'Interpreter', 'none');
legend(ax, 'Location', 'northeastoutside');
camlight(ax, 'headlight');
lighting(ax, 'gouraud');
hold(ax, 'off');

saveOutputs(figureHandle, parser.Results.OutputFolder, parser.Results.OutputName, ...
    parser.Results.OutputFormats, parser.Results.Resolution);
end

function mesh = readMsh(fileName)
fid = fopen(fileName, 'r');
if fid < 0
    error('visualizeMshLabelGroups:OpenFailed', 'Could not open %s.', fileName);
end
cleanup = onCleanup(@() fclose(fid));
seek(fid, 'Coordinates', fileName);
nodeRows = readUntil(fid, 'End Coordinates', 4, fileName);
seek(fid, 'Elements', fileName);
elementRows = readUntil(fid, 'End Elements', 6, fileName);
[known, connectivity] = ismember(elementRows(:, 2:5), nodeRows(:, 1));
if ~all(known, 'all')
    error('visualizeMshLabelGroups:UnknownNode', ...
        'Element connectivity references an unknown node in %s.', fileName);
end
mesh = struct('nodes', nodeRows(:, 2:4), 'elements', connectivity, ...
    'labels', elementRows(:, 6));
end

function seek(fid, sectionName, fileName)
line = fgetl(fid);
while ischar(line)
    if strcmpi(strtrim(line), sectionName)
        return;
    end
    line = fgetl(fid);
end
error('visualizeMshLabelGroups:MissingSection', ...
    'Could not find %s in %s.', sectionName, fileName);
end

function rows = readUntil(fid, endText, minColumns, fileName)
rows = zeros(0, minColumns);
line = fgetl(fid);
while ischar(line)
    if strcmpi(strtrim(line), endText)
        return;
    end
    if ~isempty(strtrim(line))
        values = sscanf(line, '%f').';
        if numel(values) < minColumns
            error('visualizeMshLabelGroups:BadRow', ...
                'Invalid numeric row in %s.', fileName);
        end
        rows(end + 1, :) = values(1:minColumns); %#ok<AGROW>
    end
    line = fgetl(fid);
end
error('visualizeMshLabelGroups:MissingSectionEnd', ...
    'Could not find %s in %s.', endText, fileName);
end

function groups = normalizeGroups(groups, labels)
if isempty(groups)
    values = unique(labels, 'stable');
    groups = num2cell(values);
elseif isnumeric(groups)
    groups = num2cell(groups(:));
else
    groups = groups(:);
end
end

function plotGroup(ax, nodes, elements, color, alpha, name)
[nodeIds, ~, connectivity] = unique(elements(:));
connectivity = reshape(connectivity, size(elements));
activeNodes = nodes(nodeIds, :);
faces = freeBoundary(triangulation(connectivity, activeNodes));
patch(ax, 'Faces', faces, 'Vertices', activeNodes, 'FaceColor', color, ...
    'FaceAlpha', alpha, 'EdgeColor', 'none', 'DisplayName', name);
end

function saveOutputs(figureHandle, folder, name, formats, resolution)
folder = char(folder);
if isempty(folder)
    return;
end
if exist(folder, 'dir') ~= 7
    mkdir(folder);
end
if strlength(string(name)) == 0
    name = 'msh_label_groups';
end
formats = textColumn(formats);
for index = 1:numel(formats)
    format = lower(char(formats(index)));
    outputFile = fullfile(folder, [char(name) '.' format]);
    if strcmp(format, 'fig')
        savefig(figureHandle, outputFile);
    else
        exportgraphics(figureHandle, outputFile, 'Resolution', resolution);
    end
end
end

function values = textColumn(values)
if isempty(values)
    values = strings(0, 1);
elseif ischar(values)
    values = string({values});
else
    values = string(values(:));
end
end

function tf = isTextScalar(value)
tf = (ischar(value) && (isrow(value) || isempty(value))) || ...
    (isstring(value) && isscalar(value));
end

function tf = isTextVector(value)
tf = isempty(value) || ischar(value) || isstring(value) || iscellstr(value);
end
