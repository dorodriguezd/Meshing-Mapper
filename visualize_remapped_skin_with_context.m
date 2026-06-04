%VISUALIZE_REMAPPED_SKIN_WITH_CONTEXT Plot SKIN label 25 with labels 1-19.
%
% The labels 1 through 19 are plotted as one contextual material group with
% a shared color. The remapped SKIN tissue, label 25, is overlaid in magenta.
% Results are saved in the result folder.

clear;
close all;
clc;

repoRoot = getRepoRoot();
resultDir = fullfile(repoRoot, 'result');
remappedDatFile = fullfile(resultDir, 'mesh_bowls_with_head.dat');

if exist(remappedDatFile, 'file') ~= 2
    error('visualizeRemappedSkinWithContext:MissingResult', ...
        'Run build_head_mapping first to create %s.', remappedDatFile);
end

if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end

contextLabels = (1:19).';
skinLabel = 25;
labelsToRead = [contextLabels; skinLabel];

fprintf('Reading selected labels from:\n  %s\n', remappedDatFile);
mesh = readSelectedDatLabels(remappedDatFile, labelsToRead);

contextElements = mesh.elements(ismember(mesh.elementLabels, contextLabels), :);
skinElements = mesh.elements(mesh.elementLabels == skinLabel, :);

fprintf('  Labels 1-19 elements: %d\n', size(contextElements, 1));
fprintf('  SKIN label 25 elements: %d\n', size(skinElements, 1));

figureHandle = figure( ...
    'Name', 'Remapped SKIN with labels 1-19 context', ...
    'Color', 'w');
axesHandle = axes(figureHandle);
hold(axesHandle, 'on');

plotElementGroup(axesHandle, mesh.nodes, contextElements, ...
    [0.58 0.61 0.64], 0.18, 'labels 1-19');
plotElementGroup(axesHandle, mesh.nodes, skinElements, ...
    [1.00 0.00 0.78], 0.78, 'SKIN label 25');

axis(axesHandle, 'equal');
axis(axesHandle, 'tight');
grid(axesHandle, 'on');
view(axesHandle, 38, 24);
xlabel(axesHandle, 'X');
ylabel(axesHandle, 'Y');
zlabel(axesHandle, 'Z');
title(axesHandle, 'Remapped SKIN label 25 with labels 1-19 context');
legend(axesHandle, 'Location', 'northeastoutside');
camlight(axesHandle, 'headlight');
lighting(axesHandle, 'gouraud');
hold(axesHandle, 'off');

outputPng = fullfile(resultDir, 'remapped_skin25_with_labels_1_to_19.png');
outputFig = fullfile(resultDir, 'remapped_skin25_with_labels_1_to_19.fig');
exportgraphics(figureHandle, outputPng, 'Resolution', 220);
savefig(figureHandle, outputFig);

fprintf('Saved %s\n', outputPng);
fprintf('Saved %s\n', outputFig);

function mesh = readSelectedDatLabels(datFile, labelsToKeep)
fid = fopen(datFile, 'r');
if fid < 0
    error('visualizeRemappedSkinWithContext:OpenFailed', ...
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
remaining = elementCount;
while remaining > 0
    rowsToRead = min(chunkSize, remaining);
    elementData = textscan(fid, '%f %f %f %f %f', rowsToRead, 'CollectOutput', true);
    elementData = elementData{1};
    keepRows = ismember(elementData(:, 5), labelsToKeep);
    if any(keepRows)
        elementChunks{end + 1, 1} = elementData(keepRows, 1:4); %#ok<AGROW>
        labelChunks{end + 1, 1} = elementData(keepRows, 5); %#ok<AGROW>
    end
    remaining = remaining - rowsToRead;
end

if isempty(elementChunks)
    elements = zeros(0, 4);
    elementLabels = zeros(0, 1);
else
    elements = vertcat(elementChunks{:});
    elementLabels = vertcat(labelChunks{:});
end

mesh = struct();
mesh.fileName = datFile;
mesh.nodes = nodes;
mesh.elements = elements;
mesh.elementLabels = elementLabels;
end

function seekSection(fid, sectionName, fileName)
line = fgetl(fid);
while ischar(line)
    if strcmpi(strtrim(line), sectionName)
        return;
    end
    line = fgetl(fid);
end

error('visualizeRemappedSkinWithContext:MissingSection', ...
    'Could not find section "%s" in %s.', sectionName, fileName);
end

function count = parseCount(line, sectionName, fileName)
count = sscanf(strtrim(line), '%d', 1);
if isempty(count) || count < 0
    error('visualizeRemappedSkinWithContext:BadCount', ...
        'Invalid %s count in %s: %s', sectionName, fileName, line);
end
end

function plotElementGroup(axesHandle, nodes, elements, color, alphaValue, displayName)
if isempty(elements)
    warning('visualizeRemappedSkinWithContext:EmptyGroup', ...
        'No elements found for %s.', displayName);
    return;
end

[activeNodeIds, ~, compactConnectivity] = unique(elements(:));
compactConnectivity = reshape(compactConnectivity, size(elements));
activeNodes = nodes(activeNodeIds, :);
activeFaces = freeBoundary(triangulation(compactConnectivity, activeNodes));

patch(axesHandle, ...
    'Faces', activeFaces, ...
    'Vertices', activeNodes, ...
    'FaceColor', color, ...
    'FaceAlpha', alphaValue, ...
    'EdgeColor', 'none', ...
    'DisplayName', displayName);
end

function repoRoot = getRepoRoot()
scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    repoRoot = pwd;
else
    repoRoot = fileparts(scriptPath);
end
end
