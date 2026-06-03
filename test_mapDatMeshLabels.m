%TEST_MAPDATMESHLABELS Map input .dat material volumes onto an output .dat mesh.
clear;
close all;
clc;

inputDatFile = fullfile(pwd, 'Input_mesh.dat');
targetDatFile = fullfile(pwd, 'Output_mesh.dat');
newDatFile = fullfile(pwd, 'Output_mesh_mapped_input.dat');
logFile = fullfile(pwd, 'Output_mesh_mapped_input_label_log.txt');

% Select the target subdomains where the input volume is allowed to project.
% Use [] to search all target labels.
targetLabelsToProject = [1 2];

[mappedLabels, mapInfo] = mapDatMeshLabels( ...
    inputDatFile, targetDatFile, ...
    'TargetLabels', targetLabelsToProject, ...
    'OutputDatFile', newDatFile, ...
    'LogFile', logFile);

fprintf('Input DAT mesh: %d nodes, %d tetrahedra\n', ...
    size(mapInfo.inputMesh.nodes, 1), size(mapInfo.inputMesh.elements, 1));
fprintf('Target DAT mesh: %d nodes, %d tetrahedra\n', ...
    size(mapInfo.targetMesh.nodes, 1), size(mapInfo.targetMesh.elements, 1));
fprintf('Target labels searched: %s\n', strjoin(compose('%g', mapInfo.targetLabelsToMap), ', '));
for row = 1:height(mapInfo.labelMap)
    fprintf('Input label %g -> output label %g: %d target tetrahedra\n', ...
        mapInfo.labelMap.InputLabel(row), ...
        mapInfo.labelMap.NewTargetLabel(row), ...
        mapInfo.labelMap.MappedTargetElements(row));
end
fprintf('Mapped DAT written to: %s\n', newDatFile);
fprintf('Label log written to: %s\n', logFile);

plotMappedDatLabels(mapInfo.targetMesh, mappedLabels, mapInfo.newLabels);

function plotMappedDatLabels(targetMesh, mappedLabels, newLabels)
nodes = targetMesh.nodes;
elements = targetMesh.elements;

targetTriangulation = triangulation(elements, nodes);
targetFaces = freeBoundary(targetTriangulation);

figure('Name', 'Input DAT volume mapped onto output DAT mesh', 'Color', 'w');
hold on;

patch( ...
    'Faces', targetFaces, ...
    'Vertices', nodes, ...
    'FaceColor', [0.76 0.78 0.80], ...
    'FaceAlpha', 0.10, ...
    'EdgeColor', 'none', ...
    'DisplayName', 'Output mesh');

labelColors = lines(numel(newLabels));
for labelIndex = 1:numel(newLabels)
    activeElements = mappedLabels == newLabels(labelIndex);
    if ~any(activeElements)
        continue;
    end

    activeConnectivity = elements(activeElements, :);
    [activeNodeIds, ~, compactConnectivity] = unique(activeConnectivity(:));
    compactConnectivity = reshape(compactConnectivity, size(activeConnectivity));
    activeNodes = nodes(activeNodeIds, :);
    activeTriangulation = triangulation(compactConnectivity, activeNodes);
    activeFaces = freeBoundary(activeTriangulation);

    patch( ...
        'Faces', activeFaces, ...
        'Vertices', activeNodes, ...
        'FaceColor', labelColors(labelIndex, :), ...
        'FaceAlpha', 0.90, ...
        'EdgeColor', 'none', ...
        'DisplayName', sprintf('New label %g', newLabels(labelIndex)));
end

axis equal;
axis tight;
grid on;
view(38, 24);
xlabel('X');
ylabel('Y');
zlabel('Z');
title('Input material volume projected onto selected output subdomains');
legend('Location', 'northeastoutside');
camlight('headlight');
lighting gouraud;
hold off;
end
