%VISUAL_VALIDATE_TRANSFORM_PROJECTION Plot mask transforms and remap examples.
%
% This script creates visual validation data from the baseline input mask:
%   1. baseline input mesh
%   2. z-rotation by 30 degrees
%   3. translation in x/y/z
%   4. z-rotation by 30 degrees, then translation
%
% It then projects two input cases onto the output mesh:
%   1. baseline input mask
%   2. rotated-translated input mask
%
% All transformed meshes keep the same node count, connectivity, and labels;
% only node coordinates are changed.

clear;
close all;
clc;

inputDatFile = fullfile(pwd, 'Input_mesh.dat');
outputDatFile = fullfile(pwd, 'Output_mesh.dat');

rotatedDatFile = fullfile(pwd, 'Input_mesh_rotated_z30.dat');
translatedDatFile = fullfile(pwd, 'Input_mesh_translated.dat');
rotatedTranslatedDatFile = fullfile(pwd, 'Input_mesh_rotated_z30_translated.dat');

baselineRemapDatFile = fullfile(pwd, 'New_remap_baseline_visual.dat');
baselineRemapLogFile = fullfile(pwd, 'New_remap_baseline_visual_label_log.txt');
rotatedTranslatedRemapDatFile = fullfile(pwd, 'New_remap_rotated_translated_visual.dat');
rotatedTranslatedRemapLogFile = fullfile(pwd, 'New_remap_rotated_translated_visual_label_log.txt');
visualPlotFolder = fullfile(pwd, 'visual_validation_plots');
if ~exist(visualPlotFolder, 'dir')
    mkdir(visualPlotFolder);
end

targetLabelsToProject = [1 2];
targetLabelNames = ["air"; "cylinder"];

fprintf('Creating transformed input masks for visual validation...\n');
transformMeshGeometry( ...
    inputDatFile, ...
    rotatedDatFile, ...
    'RotationAxis', [0 0 1], ...
    'RotationAngle', 30, ...
    'TransformOrder', {'rotation'});

transformMeshGeometry( ...
    inputDatFile, ...
    translatedDatFile, ...
    'TranslationInitialPoint', [0 0 0], ...
    'TranslationFinalPoint', [1.00 -0.75 0.25], ...
    'TransformOrder', {'translation'});

transformMeshGeometry( ...
    inputDatFile, ...
    rotatedTranslatedDatFile, ...
    'RotationAxis', [0 0 1], ...
    'RotationAngle', 30, ...
    'TranslationInitialPoint', [0 0 0], ...
    'TranslationFinalPoint', [1.25 0.75 0.10], ...
    'TransformOrder', {'rotation', 'translation'});

inputCases = struct( ...
    'file', {inputDatFile, rotatedDatFile, translatedDatFile, rotatedTranslatedDatFile}, ...
    'title', {'Baseline input', 'Rotated z30', 'Translated', 'Rotated z30 + translated'}, ...
    'color', {[0.20 0.45 0.85], [0.88 0.32 0.24], [0.12 0.62 0.42], [0.62 0.35 0.78]});

inputFigure = figure('Name', 'Input mask geometry variations', 'Color', 'w');
inputAxes = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(inputAxes, 'Input Mask Variations');
for caseIndex = 1:numel(inputCases)
    ax = nexttile(inputAxes);
    mesh = readDatMeshForVisual(inputCases(caseIndex).file);
    plotDatLabelSurface(ax, mesh, 1, inputCases(caseIndex).color, 0.72, ...
        inputCases(caseIndex).title);
    title(ax, inputCases(caseIndex).title);
end
linkAxes3d(findall(gcf, 'Type', 'axes'));
exportgraphics(inputFigure, fullfile(visualPlotFolder, 'input_mask_variations.png'), ...
    'Resolution', 180);

fprintf('Projecting baseline input mask onto output mesh...\n');
[baselineLabels, baselineInfo] = mapDatMeshLabels( ...
    inputDatFile, ...
    outputDatFile, ...
    'TargetLabels', targetLabelsToProject, ...
    'TargetLabelNames', targetLabelNames, ...
    'InputLabelNames', "target_baseline", ...
    'NewLabelNames', "target_baseline", ...
    'OutputDatFile', baselineRemapDatFile, ...
    'LogFile', baselineRemapLogFile);

fprintf('Projecting rotated-translated input mask onto output mesh...\n');
[rotatedTranslatedLabels, rotatedTranslatedInfo] = mapDatMeshLabels( ...
    rotatedTranslatedDatFile, ...
    outputDatFile, ...
    'TargetLabels', targetLabelsToProject, ...
    'TargetLabelNames', targetLabelNames, ...
    'InputLabelNames', "target_rotated_translated", ...
    'NewLabelNames', "target_rotated_translated", ...
    'OutputDatFile', rotatedTranslatedRemapDatFile, ...
    'LogFile', rotatedTranslatedRemapLogFile);

fprintf('\nProjection summary:\n');
printProjectionSummary('Baseline', baselineInfo);
printProjectionSummary('Rotated-translated', rotatedTranslatedInfo);

projectionFigure = figure('Name', 'Projected labels on output mesh', 'Color', 'w');
projectionAxes = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(projectionAxes, 'Projected Input Masks on Output Mesh');

ax = nexttile(projectionAxes);
plotRemappedOutputLabels(ax, baselineInfo.targetMesh, baselineLabels, ...
    baselineInfo.outputLabelTable, 'Baseline projection');

ax = nexttile(projectionAxes);
plotRemappedOutputLabels(ax, rotatedTranslatedInfo.targetMesh, rotatedTranslatedLabels, ...
    rotatedTranslatedInfo.outputLabelTable, 'Rotated-translated projection');
linkAxes3d(findall(gcf, 'Type', 'axes'));
exportgraphics(projectionFigure, fullfile(visualPlotFolder, 'projected_output_labels.png'), ...
    'Resolution', 180);

fprintf('\nCreated visual remap DAT files:\n');
fprintf('  %s\n', baselineRemapDatFile);
fprintf('  %s\n', rotatedTranslatedRemapDatFile);
fprintf('Created visual remap logs:\n');
fprintf('  %s\n', baselineRemapLogFile);
fprintf('  %s\n', rotatedTranslatedRemapLogFile);
fprintf('Saved visual validation figures:\n');
fprintf('  %s\n', fullfile(visualPlotFolder, 'input_mask_variations.png'));
fprintf('  %s\n', fullfile(visualPlotFolder, 'projected_output_labels.png'));

function printProjectionSummary(caseName, mapInfo)
for row = 1:height(mapInfo.labelMap)
    fprintf('  %s: input label %g (%s) -> output label %g (%s), %d tetrahedra\n', ...
        caseName, ...
        mapInfo.labelMap.InputLabel(row), ...
        char(mapInfo.labelMap.InputLabelName(row)), ...
        mapInfo.labelMap.NewTargetLabel(row), ...
        char(mapInfo.labelMap.NewTargetLabelName(row)), ...
        mapInfo.labelMap.MappedTargetElements(row));
end
end

function mesh = readDatMeshForVisual(datFile)
fid = fopen(datFile, 'r');
if fid < 0
    error('visualValidate:OpenFailed', 'Could not open file: %s', datFile);
end
cleanup = onCleanup(@() fclose(fid));

rawLines = {};
line = fgetl(fid);
while ischar(line)
    rawLines{end + 1, 1} = line; %#ok<AGROW>
    line = fgetl(fid);
end

coordinatesLine = find(strcmpi(strtrim(rawLines), 'Coordinates'), 1, 'first');
elementsLine = find(strcmpi(strtrim(rawLines), 'Elements'), 1, 'first');
if isempty(coordinatesLine) || isempty(elementsLine)
    error('visualValidate:MissingSection', ...
        'Could not find Coordinates or Elements in %s.', datFile);
end

nodeCount = sscanf(strtrim(rawLines{coordinatesLine + 1}), '%d', 1);
elementCount = sscanf(strtrim(rawLines{elementsLine + 1}), '%d', 1);

nodes = zeros(nodeCount, 3);
for node = 1:nodeCount
    nodes(node, :) = sscanf(strtrim(rawLines{coordinatesLine + 1 + node}), '%f').';
end

elementRows = zeros(elementCount, 5);
for elem = 1:elementCount
    elementRows(elem, :) = sscanf(strtrim(rawLines{elementsLine + 1 + elem}), '%f').';
end

mesh = struct();
mesh.nodes = nodes;
mesh.elements = elementRows(:, 1:4);
mesh.elementLabels = elementRows(:, 5);
end

function plotDatLabelSurface(ax, mesh, label, color, alphaValue, displayName)
hold(ax, 'on');
activeElements = mesh.elementLabels == label;
if any(activeElements)
    plotElementSurface(ax, mesh.nodes, mesh.elements(activeElements, :), color, ...
        alphaValue, displayName);
end
finishAxes(ax);
hold(ax, 'off');
end

function plotRemappedOutputLabels(ax, mesh, labels, labelTable, plotTitle)
hold(ax, 'on');
contextFaces = freeBoundary(triangulation(mesh.elements, mesh.nodes));
patch(ax, ...
    'Faces', contextFaces, ...
    'Vertices', mesh.nodes, ...
    'FaceColor', [0.82 0.84 0.86], ...
    'FaceAlpha', 0.035, ...
    'EdgeColor', 'none', ...
    'DisplayName', 'output boundary');

for row = 1:height(labelTable)
    label = labelTable.Label(row);
    labelName = char(labelTable.Name(row));
    activeElements = labels == label;
    if ~any(activeElements)
        continue;
    end

    [color, alphaValue] = materialStyle(labelName, row);
    plotElementSurface(ax, mesh.nodes, mesh.elements(activeElements, :), color, ...
        alphaValue, sprintf('%g %s', label, labelName));
end

title(ax, plotTitle);
finishAxes(ax);
legend(ax, 'Location', 'northeastoutside');
hold(ax, 'off');
end

function plotElementSurface(ax, nodes, elements, color, alphaValue, displayName)
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

function [color, alphaValue] = materialStyle(labelName, row)
switch lower(labelName)
    case 'air'
        color = [0.38 0.62 0.95];
        alphaValue = 0.12;
    case 'cylinder'
        color = [0.95 0.62 0.25];
        alphaValue = 0.20;
    otherwise
        palette = [ ...
            0.74 0.22 0.34; ...
            0.36 0.64 0.36; ...
            0.58 0.38 0.78; ...
            0.15 0.58 0.70];
        color = palette(1 + mod(row - 1, size(palette, 1)), :);
        alphaValue = 0.82;
end
end

function finishAxes(ax)
axis(ax, 'equal');
axis(ax, 'tight');
grid(ax, 'on');
view(ax, 38, 24);
xlabel(ax, 'X');
ylabel(ax, 'Y');
zlabel(ax, 'Z');
camlight(ax, 'headlight');
lighting(ax, 'gouraud');
end

function linkAxes3d(axesHandles)
if isempty(axesHandles)
    return;
end
linkObject = linkprop(axesHandles, ...
    {'XLim', 'YLim', 'ZLim', 'CameraPosition', 'CameraTarget', 'CameraUpVector'});
setappdata(ancestor(axesHandles(1), 'figure'), 'LinkedAxes3d', linkObject);
end
