%TEST_HEAD_MAPPING_VISUALS Plot the original and remapped head tissues.
%
% Run build_head_mapping first if result/mesh_bowls_with_head.dat does not
% exist yet. This script plots only the five head tissue labels so that the
% bowl/container materials do not hide the result.

clear;
close all;
clc;

repoRoot = getRepoRoot();
addpath(fullfile(repoRoot, 'Lib'));

headDatFile = fullfile(repoRoot, 'HeadMapping', 'mesh_head.dat');
remappedDatFile = fullfile(repoRoot, 'result', 'mesh_bowls_with_head.dat');
resultDir = fullfile(repoRoot, 'result');
if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end

if exist(remappedDatFile, 'file') ~= 2
    error('testHeadMapping:MissingResult', ...
        'Run build_head_mapping first to create %s.', remappedDatFile);
end

headLabels = (1:5).';
headNames = ["gray"; "CSF"; "FAT"; "SKIN"; "SKULL"];
headColors = [ ...
    0.00 0.90 0.00; ... % gray, legend color
    1.00 0.95 0.00; ... % CSF
    0.05 0.05 1.00; ... % FAT
    1.00 0.00 0.95; ... % SKIN
    0.00 0.86 0.90];    % SKULL
headAlphas = [0.55; 0.38; 0.62; 0.24; 0.34];

% mapDatMeshLabels appends the five head tissues after the 21 bowl labels.
remappedHeadLabels = (22:26).';

fprintf('Reading and plotting initial head mesh...\n');
headMesh = readSelectedDatLabels(headDatFile, headLabels);
figure('Name', 'Initial head tissue mesh', 'Color', 'w');
plotSelectedLabelOverlay(gca, headMesh, headLabels, headNames, headColors, headAlphas, ...
    'Initial Head Mesh');
exportgraphics(gcf, fullfile(resultDir, 'head_initial_tissues.png'), 'Resolution', 180);

fprintf('Reading and plotting remapped head tissues on bowl mesh...\n');
remappedHeadMesh = readSelectedDatLabels(remappedDatFile, remappedHeadLabels);
figure('Name', 'Remapped head tissues on bowl mesh', 'Color', 'w');
plotSelectedLabelOverlay(gca, remappedHeadMesh, remappedHeadLabels, headNames, headColors, headAlphas, ...
    'Remapped Head Tissues on Bowl Mesh');
exportgraphics(gcf, fullfile(resultDir, 'head_remapped_tissues.png'), 'Resolution', 180);

fprintf('Saved validation figures:\n');
fprintf('  %s\n', fullfile(resultDir, 'head_initial_tissues.png'));
fprintf('  %s\n', fullfile(resultDir, 'head_remapped_tissues.png'));

function mesh = readSelectedDatLabels(datFile, labelsToKeep)
fid = fopen(datFile, 'r');
if fid < 0
    error('testHeadMapping:OpenFailed', 'Could not open file: %s', datFile);
end
cleanup = onCleanup(@() fclose(fid));

seekSection(fid, 'Coordinates', datFile);
nodeCount = parseCount(fgetl(fid), 'Coordinates', datFile);
nodeData = textscan(fid, '%f %f %f', nodeCount, 'CollectOutput', true);
nodes = nodeData{1};

seekSection(fid, 'Elements', datFile);
elementCount = parseCount(fgetl(fid), 'Elements', datFile);

elements = zeros(0, 4);
labels = zeros(0, 1);
chunkSize = 250000;
remaining = elementCount;
while remaining > 0
    rowsToRead = min(chunkSize, remaining);
    elementData = textscan(fid, '%f %f %f %f %f', rowsToRead, 'CollectOutput', true);
    elementData = elementData{1};
    keepRows = ismember(elementData(:, 5), labelsToKeep);
    elements = [elements; elementData(keepRows, 1:4)]; %#ok<AGROW>
    labels = [labels; elementData(keepRows, 5)]; %#ok<AGROW>
    remaining = remaining - rowsToRead;
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

error('testHeadMapping:MissingSection', ...
    'Could not find section "%s" in %s.', sectionName, fileName);
end

function count = parseCount(line, sectionName, fileName)
count = sscanf(strtrim(line), '%d', 1);
if isempty(count) || count < 0
    error('testHeadMapping:BadCount', ...
        'Invalid %s count in %s: %s', sectionName, fileName, line);
end
end

function plotSelectedLabelOverlay(ax, mesh, labelsToPlot, labelNames, colors, alphas, plotTitle)
hold(ax, 'on');
for labelIndex = 1:numel(labelsToPlot)
    label = labelsToPlot(labelIndex);
    activeElements = mesh.elements(mesh.elementLabels == label, :);
    if isempty(activeElements)
        warning('testHeadMapping:MissingLabel', ...
            'Label %g (%s) was not found in %s.', ...
            label, char(labelNames(labelIndex)), mesh.fileName);
        continue;
    end

    [activeNodeIds, ~, compactConnectivity] = unique(activeElements(:));
    compactConnectivity = reshape(compactConnectivity, size(activeElements));
    activeNodes = mesh.nodes(activeNodeIds, :);
    activeFaces = freeBoundary(triangulation(compactConnectivity, activeNodes));

    patch(ax, ...
        'Faces', activeFaces, ...
        'Vertices', activeNodes, ...
        'FaceColor', colors(labelIndex, :), ...
        'FaceAlpha', alphas(labelIndex), ...
        'EdgeColor', 'none', ...
        'DisplayName', sprintf('%g %s', label, char(labelNames(labelIndex))));
end

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
hold(ax, 'off');
end

function repoRoot = getRepoRoot()
scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    repoRoot = pwd;
else
    repoRoot = fileparts(scriptPath);
end
end
