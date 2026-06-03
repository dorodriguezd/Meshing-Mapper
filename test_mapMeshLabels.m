%TEST_MAPMESHLABELS Map the ellipse volume onto the cylinder tetra mesh.
clear;
close all;
clc;

sourceFile = fullfile(pwd, 'Mesh_elipse.msh');
targetFile = fullfile(pwd, 'Mesh__cylinder.msh');
mappedMeshFile = fullfile(pwd, 'Mesh__cylinder_mapped_elipse.msh');

[targetLabels, mapInfo] = map3DMeshLabels( ...
    sourceFile, targetFile, ...
    'BackgroundLabel', 0, ...
    'WriteMappedMesh', mappedMeshFile);

fprintf('Source mesh: %d nodes, %d tetrahedra\n', ...
    size(mapInfo.sourceMesh.nodes, 1), size(mapInfo.sourceMesh.elements, 1));
fprintf('Target mesh: %d nodes, %d tetrahedra\n', ...
    size(mapInfo.targetMesh.nodes, 1), size(mapInfo.targetMesh.elements, 1));
fprintf('Mapped elements: %d of %d (%.2f%%)\n', ...
    nnz(mapInfo.insideSource), numel(targetLabels), 100 * mapInfo.assignedFraction);
fprintf('Mapped mesh written to: %s\n', mappedMeshFile);

plotMappedCylinder(mapInfo.targetMesh, targetLabels, mapInfo.backgroundLabel);

function plotMappedCylinder(targetMesh, targetLabels, backgroundLabel)
nodes = targetMesh.nodes;
elements = targetMesh.elements;

targetTriangulation = triangulation(elements, nodes);
cylinderFaces = freeBoundary(targetTriangulation);

figure('Name', 'Ellipse mapped onto cylinder mesh', 'Color', 'w');
hold on;

patch( ...
    'Faces', cylinderFaces, ...
    'Vertices', nodes, ...
    'FaceColor', [0.78 0.80 0.82], ...
    'FaceAlpha', 0.12, ...
    'EdgeColor', 'none', ...
    'DisplayName', 'Cylinder mesh');

mappedLabels = unique(targetLabels(targetLabels ~= backgroundLabel));
if isempty(mappedLabels)
    warning('No target tetrahedra were mapped inside the source volume.');
else
    labelColors = lines(numel(mappedLabels));
    for labelId = 1:numel(mappedLabels)
        activeElements = targetLabels == mappedLabels(labelId);
        activeConnectivity = elements(activeElements, :);
        [activeNodeIds, ~, compactConnectivity] = unique(activeConnectivity(:));
        compactConnectivity = reshape(compactConnectivity, size(activeConnectivity));
        activeNodes = nodes(activeNodeIds, :);
        activeTriangulation = triangulation(compactConnectivity, activeNodes);
        activeFaces = freeBoundary(activeTriangulation);

        patch( ...
            'Faces', activeFaces, ...
            'Vertices', activeNodes, ...
            'FaceColor', labelColors(labelId, :), ...
            'FaceAlpha', 0.86, ...
            'EdgeColor', 'none', ...
            'DisplayName', sprintf('Mapped label %.15g', mappedLabels(labelId)));
    end
end

axis equal;
axis tight;
grid on;
view(38, 24);
xlabel('X');
ylabel('Y');
zlabel('Z');
title('Ellipse volume projected onto the cylinder mesh');
legend('Location', 'northeastoutside');
camlight('headlight');
lighting gouraud;
hold off;
end
