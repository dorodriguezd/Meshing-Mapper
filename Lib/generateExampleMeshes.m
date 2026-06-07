function files = generateExampleMeshes(outputFolder)
%GENERATEEXAMPLEMESHES Create the documented DAT and GiD MSH examples.
%
% Dimensions are expressed in centimeters.

if nargin < 1 || isempty(outputFolder)
    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    outputFolder = fullfile(repoRoot, 'examples', 'mapper', 'data');
end
if exist(outputFolder, 'dir') ~= 7
    mkdir(outputFolder);
end

uniformAxes = 0:0.5:5;
baseline = structuredTetraMesh(uniformAxes, uniformAxes, uniformAxes);
baseline.labels = repmat(10, size(baseline.elements, 1), 1);

sourceAxes = 1:0.25:4;
sourceGrid = structuredTetraMesh(sourceAxes, sourceAxes, sourceAxes);
sourceCentroids = tetraCentroids(sourceGrid.nodes, sourceGrid.elements);
largeSphere = sum((sourceCentroids - [2.5 2.5 2.5]).^2, 2) <= 1.5^2;
sphere = compactMesh(sourceGrid, largeSphere);
sphere.labels = ones(size(sphere.elements, 1), 1);

layerAxes = unique([0, 0.5:0.25:4.5, 5]);
layered = structuredTetraMesh(layerAxes, layerAxes, layerAxes);
layeredCentroids = tetraCentroids(layered.nodes, layered.elements);
insideInnerCube = all(layeredCentroids >= 0.5 & layeredCentroids <= 4.5, 2);
layered.labels = repmat(10, size(layered.elements, 1), 1);
layered.labels(insideInnerCube) = 20;

multiShape = compactMesh(sourceGrid, largeSphere);
multiCentroids = tetraCentroids(multiShape.nodes, multiShape.elements);
multiShape.labels = ones(size(multiShape.elements, 1), 1);
smallSphere = sum((multiCentroids - [1.9 2.5 2.5]).^2, 2) <= 0.5^2;
smallCube = all(abs(multiCentroids - [3.25 2.5 2.5]) <= 0.25, 2);
if any(smallSphere & smallCube)
    error('generateExampleMeshes:OverlappingInclusions', ...
        'The small sphere and cube must not overlap.');
end
multiShape.labels(smallSphere) = 2;
multiShape.labels(smallCube) = 3;

files = struct();
files.BaselineDat = fullfile(outputFolder, 'baseline_cube_5cm.dat');
files.SphereDat = fullfile(outputFolder, 'sphere_3cm.dat');
files.LayeredBaselineDat = fullfile(outputFolder, 'baseline_layered_cubes.dat');
files.MultiShapeDat = fullfile(outputFolder, 'source_multishape.dat');
files.BaselineMsh = fullfile(outputFolder, 'baseline_cube_5cm.msh');
files.SphereMsh = fullfile(outputFolder, 'sphere_3cm.msh');
files.LayeredBaselineMsh = fullfile(outputFolder, 'baseline_layered_cubes.msh');
files.MultiShapeMsh = fullfile(outputFolder, 'source_multishape.msh');

writeDat(files.BaselineDat, baseline, 10, "baseline");
writeDat(files.SphereDat, sphere, 1, "source");
writeDat(files.LayeredBaselineDat, layered, [10 20], "baseline");
writeDat(files.MultiShapeDat, multiShape, [1 2 3], "source");
writeMsh(files.BaselineMsh, baseline);
writeMsh(files.SphereMsh, sphere);
writeMsh(files.LayeredBaselineMsh, layered);
writeMsh(files.MultiShapeMsh, multiShape);

fprintf('Generated example meshes in %s\n', outputFolder);
end

function mesh = structuredTetraMesh(x, y, z)
[xGrid, yGrid, zGrid] = ndgrid(x, y, z);
nodes = [xGrid(:), yGrid(:), zGrid(:)];
nodeIndex = reshape(1:numel(xGrid), size(xGrid));
cellCount = (numel(x) - 1) * (numel(y) - 1) * (numel(z) - 1);
elements = zeros(cellCount * 6, 4);
row = 1;

for k = 1:(numel(z) - 1)
    for j = 1:(numel(y) - 1)
        for i = 1:(numel(x) - 1)
            n000 = nodeIndex(i, j, k);
            n100 = nodeIndex(i + 1, j, k);
            n010 = nodeIndex(i, j + 1, k);
            n110 = nodeIndex(i + 1, j + 1, k);
            n001 = nodeIndex(i, j, k + 1);
            n101 = nodeIndex(i + 1, j, k + 1);
            n011 = nodeIndex(i, j + 1, k + 1);
            n111 = nodeIndex(i + 1, j + 1, k + 1);
            elements(row:(row + 5), :) = [ ...
                n000 n100 n110 n111
                n000 n110 n010 n111
                n000 n010 n011 n111
                n000 n011 n001 n111
                n000 n001 n101 n111
                n000 n101 n100 n111];
            row = row + 6;
        end
    end
end

mesh = struct('nodes', nodes, 'elements', elements, 'labels', []);
end

function compact = compactMesh(mesh, selectedRows)
elements = mesh.elements(selectedRows, :);
[usedNodes, ~, compactConnectivity] = unique(elements(:), 'stable');
compact = struct();
compact.nodes = mesh.nodes(usedNodes, :);
compact.elements = reshape(compactConnectivity, size(elements));
compact.labels = [];
end

function centroids = tetraCentroids(nodes, elements)
centroids = (nodes(elements(:, 1), :) + nodes(elements(:, 2), :) + ...
    nodes(elements(:, 3), :) + nodes(elements(:, 4), :)) / 4;
end

function writeDat(fileName, mesh, materialLabels, meshRole)
fid = fopen(fileName, 'w');
if fid < 0
    error('generateExampleMeshes:WriteFailed', 'Could not write %s.', fileName);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# Meshing-Mapper generated release example\n');
fprintf(fid, '# Units: centimeters\n');
fprintf(fid, 'Problem type\n');
fprintf(fid, 'example_tetrahedral_problem\n\n');
fprintf(fid, 'Coordinates\n%9d\n', size(mesh.nodes, 1));
fprintf(fid, '%16.9f %16.9f %16.9f\n', mesh.nodes.');
fprintf(fid, 'end Coordinates\n\n');
fprintf(fid, 'Elements\n%9d\n', size(mesh.elements, 1));
elementRows = [mesh.elements, mesh.labels];
fprintf(fid, '%10d %10d %10d %10d %9d\n', elementRows.');
fprintf(fid, 'end Elements\n\n');
fprintf(fid, 'PEC Faces\n%9d\nend PEC Faces\n\n', 0);
fprintf(fid, 'Material properties\n%9d\n', numel(materialLabels));
fprintf(fid, '# mat  property_1      property_2      property_3      property_4      property_5\n');
for index = 1:numel(materialLabels)
    label = materialLabels(index);
    fprintf(fid, '%9d %15.9f %15.9f %15.9f %15.9f %15.9f\n', ...
        label, double(label), 1, 0, 1, 0);
end
fprintf(fid, '\nExample metadata\n%9d\n', 2);
fprintf(fid, 'role: %s\n', meshRole);
fprintf(fid, 'units: cm\n');
fprintf(fid, 'end Example metadata\n');
end

function writeMsh(fileName, mesh)
fid = fopen(fileName, 'w');
if fid < 0
    error('generateExampleMeshes:WriteFailed', 'Could not write %s.', fileName);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'MESH dimension 3 ElemType Tetrahedra Nnode 4\n');
fprintf(fid, 'Coordinates\n');
nodeRows = [(1:size(mesh.nodes, 1)).', mesh.nodes];
fprintf(fid, '%10d % .9f % .9f % .9f\n', nodeRows.');
fprintf(fid, 'End Coordinates\n\n');
fprintf(fid, 'Elements\n');
elementRows = [(1:size(mesh.elements, 1)).', mesh.elements, mesh.labels];
fprintf(fid, '%10d %10d %10d %10d %10d %9d\n', elementRows.');
fprintf(fid, 'End Elements\n');
end
