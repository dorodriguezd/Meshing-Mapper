%VISUALIZE_HEAD_MAPPING_BASE_FINER Create validation plots for base/finer remap.
%
% Run build_head_mapping_base_finer first. All PNGs are saved under
% result/base_finer.

clear;
close all;
clc;

repoRoot = getRepoRoot();
resultDir = fullfile(repoRoot, 'result', 'base_finer');
headDatFile = fullfile(repoRoot, 'input', 'head_finer.dat');
remappedDatFile = fullfile(resultDir, 'mesh_base_with_head_finer.dat');

if exist(remappedDatFile, 'file') ~= 2
    error('visualizeHeadMappingBaseFiner:MissingResult', ...
        'Run build_head_mapping_base_finer first to create %s.', remappedDatFile);
end

if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end

headLabels = (1:5).';
remappedHeadLabels = (25:29).';
headNames = ["gray"; "CSF"; "FAT"; "SKIN"; "SKULL"];
headColors = [ ...
    0.00 0.90 0.00; ...
    1.00 0.95 0.00; ...
    0.05 0.05 1.00; ...
    1.00 0.00 0.95; ...
    0.00 0.86 0.90];
overlayAlphas = [0.55; 0.38; 0.62; 0.24; 0.34];
comparisonAlphas = [0.82; 0.72; 0.78; 0.42; 0.55];

fprintf('Reading finer source head tissues from:\n  %s\n', headDatFile);
headMesh = readSelectedDatLabels(headDatFile, headLabels);

fprintf('Reading remapped head tissues from:\n  %s\n', remappedDatFile);
remappedHeadMesh = readSelectedDatLabels(remappedDatFile, remappedHeadLabels);

figure('Name', 'Finer source head tissue mesh', 'Color', 'w');
plotSelectedLabelOverlay(gca, headMesh, headLabels, headNames, ...
    headColors, overlayAlphas, 'Finer Source Head Mesh');
savePng(gcf, fullfile(resultDir, 'head_finer_initial_tissues.png'));

figure('Name', 'Base mesh remapped finer head tissues', 'Color', 'w');
plotSelectedLabelOverlay(gca, remappedHeadMesh, remappedHeadLabels, headNames, ...
    headColors, overlayAlphas, 'Remapped Finer Head Tissues on Base Mesh');
savePng(gcf, fullfile(resultDir, 'head_finer_remapped_tissues.png'));

for tissueIndex = 1:numel(headLabels)
    tissueName = char(headNames(tissueIndex));
    figureName = sprintf('%s tissue: finer source vs base remap', tissueName);
    figure('Name', figureName, 'Color', 'w', 'Position', [100 100 1500 720]);
    comparisonLayout = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax = nexttile(comparisonLayout);
    plotSingleTissue(ax, headMesh, headLabels(tissueIndex), ...
        headColors(tissueIndex, :), comparisonAlphas(tissueIndex), ...
        sprintf('Source %s, label %g', tissueName, headLabels(tissueIndex)));

    ax = nexttile(comparisonLayout);
    plotSingleTissue(ax, remappedHeadMesh, remappedHeadLabels(tissueIndex), ...
        headColors(tissueIndex, :), comparisonAlphas(tissueIndex), ...
        sprintf('Remapped %s, label %g', tissueName, remappedHeadLabels(tissueIndex)));

    axesHandles = findall(gcf, 'Type', 'axes');
    linkObject = linkprop(axesHandles, ...
        {'CameraPosition', 'CameraTarget', 'CameraUpVector'});
    setappdata(gcf, 'LinkedAxes3d', linkObject);

    outputPng = fullfile(resultDir, sprintf('head_compare_%02d_%s.png', ...
        tissueIndex, sanitizeFileName(tissueName)));
    savePng(gcf, outputPng);
end

fprintf('Reading SKIN/context labels for base/finer validation...\n');
skinContextMesh = readSelectedDatLabels(remappedDatFile, [(1:19).'; 28]);
figure('Name', 'Base/finer SKIN with labels 1-19 context', 'Color', 'w');
plotSkinWithContext(gca, skinContextMesh);
savePng(gcf, fullfile(resultDir, 'remapped_skin28_with_labels_1_to_19.png'));

fprintf('Saved validation figures in:\n  %s\n', resultDir);

function mesh = readSelectedDatLabels(datFile, labelsToKeep)
fid = fopen(datFile, 'r');
if fid < 0
    error('visualizeHeadMappingBaseFiner:OpenFailed', ...
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

error('visualizeHeadMappingBaseFiner:MissingSection', ...
    'Could not find section "%s" in %s.', sectionName, fileName);
end

function count = parseCount(line, sectionName, fileName)
count = sscanf(strtrim(line), '%d', 1);
if isempty(count) || count < 0
    error('visualizeHeadMappingBaseFiner:BadCount', ...
        'Invalid %s count in %s: %s', sectionName, fileName, line);
end
end

function plotSelectedLabelOverlay(ax, mesh, labelsToPlot, labelNames, colors, alphas, plotTitle)
hold(ax, 'on');
for labelIndex = 1:numel(labelsToPlot)
    plotSingleTissue(ax, mesh, labelsToPlot(labelIndex), ...
        colors(labelIndex, :), alphas(labelIndex), ...
        sprintf('%g %s', labelsToPlot(labelIndex), char(labelNames(labelIndex))));
end
finishAxes(ax, plotTitle);
hold(ax, 'off');
end

function plotSingleTissue(ax, mesh, label, color, alphaValue, displayName)
activeElements = mesh.elements(mesh.elementLabels == label, :);
if isempty(activeElements)
    warning('visualizeHeadMappingBaseFiner:MissingLabel', ...
        'Label %g was not found in %s.', label, mesh.fileName);
    return;
end

[activeNodeIds, ~, compactConnectivity] = unique(activeElements(:));
compactConnectivity = reshape(compactConnectivity, size(activeElements));
activeNodes = mesh.nodes(activeNodeIds, :);
activeFaces = freeBoundary(triangulation(compactConnectivity, activeNodes));

patch(ax, ...
    'Faces', activeFaces, ...
    'Vertices', activeNodes, ...
    'FaceColor', color, ...
    'FaceAlpha', alphaValue, ...
    'EdgeColor', 'none', ...
    'DisplayName', displayName);

finishAxes(ax, displayName);
end

function plotSkinWithContext(ax, mesh)
hold(ax, 'on');
contextElements = mesh.elements(ismember(mesh.elementLabels, 1:19), :);
skinElements = mesh.elements(mesh.elementLabels == 28, :);

plotElementGroup(ax, mesh.nodes, contextElements, ...
    [0.58 0.61 0.64], 0.18, 'labels 1-19');
plotElementGroup(ax, mesh.nodes, skinElements, ...
    [1.00 0.00 0.78], 0.78, 'SKIN label 28');

finishAxes(ax, 'Remapped SKIN label 28 with labels 1-19 context');
hold(ax, 'off');
end

function plotElementGroup(ax, nodes, elements, color, alphaValue, displayName)
if isempty(elements)
    warning('visualizeHeadMappingBaseFiner:EmptyGroup', ...
        'No elements found for %s.', displayName);
    return;
end

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

function finishAxes(ax, plotTitle)
axis(ax, 'equal');
axis(ax, 'tight');
grid(ax, 'on');
view(ax, 38, 24);
xlabel(ax, 'X');
ylabel(ax, 'Y');
zlabel(ax, 'Z');
title(ax, plotTitle);
legend(ax, 'Location', 'northeastoutside');
camlight(ax, 'headlight');
lighting(ax, 'gouraud');
end

function savePng(figureHandle, outputPng)
exportgraphics(figureHandle, outputPng, 'Resolution', 180);
fprintf('Saved %s\n', outputPng);
end

function text = sanitizeFileName(text)
text = regexprep(char(text), '[^\w-]', '_');
text = regexprep(text, '_+', '_');
text = regexprep(text, '^_|_$', '');
if isempty(text)
    text = 'tissue';
end
end

function repoRoot = getRepoRoot()
scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    repoRoot = pwd;
else
    repoRoot = fileparts(fileparts(fileparts(scriptPath)));
end
end
