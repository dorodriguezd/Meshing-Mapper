%COMPARE_HEAD_TISSUE_REMAP Compare each original head tissue with its remapped version.
%
% For each of the five tissues, this script creates one figure:
%   left  subplot: original/baseline tissue from HeadMapping/mesh_head.dat
%   right subplot: remapped tissue from result/mesh_bowls_with_head.dat
%
% Run build_head_mapping first if result/mesh_bowls_with_head.dat is not
% available.

clear;
close all;
clc;

repoRoot = getRepoRoot();
addpath(fullfile(repoRoot, 'Lib'));

headDatFile = fullfile(repoRoot, 'HeadMapping', 'mesh_head.dat');
remappedDatFile = fullfile(repoRoot, 'result', 'mesh_bowls_with_head.dat');
resultDir = fullfile(repoRoot, 'result');

if exist(remappedDatFile, 'file') ~= 2
    error('compareHeadTissueRemap:MissingResult', ...
        'Run build_head_mapping first to create %s.', remappedDatFile);
end

headLabels = (1:5).';
remappedHeadLabels = (22:26).';
headNames = ["gray"; "CSF"; "FAT"; "SKIN"; "SKULL"];
headColors = [ ...
    0.00 0.90 0.00; ... % gray, legend color
    1.00 0.95 0.00; ... % CSF
    0.05 0.05 1.00; ... % FAT
    1.00 0.00 0.95; ... % SKIN
    0.00 0.86 0.90];    % SKULL
headAlphas = [0.82; 0.72; 0.78; 0.42; 0.55];

fprintf('Reading original head tissues from:\n  %s\n', headDatFile);
baselineMesh = readSelectedDatLabels(headDatFile, headLabels);

fprintf('Reading remapped head tissues from:\n  %s\n', remappedDatFile);
remappedMesh = readSelectedDatLabels(remappedDatFile, remappedHeadLabels);

for tissueIndex = 1:numel(headLabels)
    tissueName = char(headNames(tissueIndex));
    baselineLabel = headLabels(tissueIndex);
    remappedLabel = remappedHeadLabels(tissueIndex);
    color = headColors(tissueIndex, :);
    alphaValue = headAlphas(tissueIndex);

    figureName = sprintf('%s tissue: original vs remapped', tissueName);
    figure('Name', figureName, 'Color', 'w');
    comparisonLayout = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(comparisonLayout, figureName);

    ax = nexttile(comparisonLayout);
    plotSingleTissue(ax, baselineMesh, baselineLabel, color, alphaValue, ...
        sprintf('Original %s, label %g', tissueName, baselineLabel));

    ax = nexttile(comparisonLayout);
    plotSingleTissue(ax, remappedMesh, remappedLabel, color, alphaValue, ...
        sprintf('Remapped %s, label %g', tissueName, remappedLabel));

    axesHandles = findall(gcf, 'Type', 'axes');
    linkObject = linkprop(axesHandles, ...
        {'CameraPosition', 'CameraTarget', 'CameraUpVector'});
    setappdata(gcf, 'LinkedAxes3d', linkObject);

    outputPng = fullfile(resultDir, sprintf('head_compare_%02d_%s.png', ...
        tissueIndex, sanitizeFileName(tissueName)));
    exportgraphics(gcf, outputPng, 'Resolution', 180);
    fprintf('Saved %s\n', outputPng);
end

function mesh = readSelectedDatLabels(datFile, labelsToKeep)
fid = fopen(datFile, 'r');
if fid < 0
    error('compareHeadTissueRemap:OpenFailed', 'Could not open file: %s', datFile);
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

error('compareHeadTissueRemap:MissingSection', ...
    'Could not find section "%s" in %s.', sectionName, fileName);
end

function count = parseCount(line, sectionName, fileName)
count = sscanf(strtrim(line), '%d', 1);
if isempty(count) || count < 0
    error('compareHeadTissueRemap:BadCount', ...
        'Invalid %s count in %s: %s', sectionName, fileName, line);
end
end

function plotSingleTissue(ax, mesh, label, color, alphaValue, plotTitle)
activeElements = mesh.elements(mesh.elementLabels == label, :);
if isempty(activeElements)
    warning('compareHeadTissueRemap:MissingLabel', ...
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
    'DisplayName', plotTitle);

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
    repoRoot = fileparts(scriptPath);
end
end
