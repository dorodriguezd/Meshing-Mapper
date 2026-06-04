%BUILD_HEAD_MAPPING_BIGGER_DOMAIN Map head tissues using the enlarged sfera domain.
%
% This version keeps the previous general workflow intact and writes all
% outputs under result/bigger_sfera. The target mesh is the enlarged bowl
% mesh in input/mesh_bowls_bigger.dat. The STEP geometry in geometry/sfera.stp
% is used to document and validate the enlarged label-20 domain.

clear;
clc;

repoRoot = getRepoRoot();
addpath(fullfile(repoRoot, 'Lib'));

headDir = fullfile(repoRoot, 'HeadMapping');
targetDir = fullfile(repoRoot, 'input');
geometryDir = fullfile(repoRoot, 'geometry');
resultDir = fullfile(repoRoot, 'result', 'bigger_sfera');
if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end

headDatFile = fullfile(headDir, 'mesh_head.dat');
biggerBowlDatFile = fullfile(targetDir, 'mesh_bowls_bigger.dat');
geometryFile = fullfile(geometryDir, 'sfera.stp');
outputDatFile = fullfile(resultDir, 'mesh_bowls_bigger_with_head.dat');
logFile = fullfile(resultDir, 'mesh_bowls_bigger_with_head_label_log.txt');
summaryFile = fullfile(resultDir, 'mesh_bowls_bigger_mapping_summary.txt');

headLabels = (1:5).';
headNames = ["gray"; "CSF"; "FAT"; "SKIN"; "SKULL"];

% Label 20 is the enlarged/scaled sfera and label 21 is the inner sfera.
% Together they define the target subdomain for the head remap. The local
% hole-repair pass fills thin unmapped islands, especially in SKIN, from
% nearby mapped tissues without relabeling the whole enlarged ellipsoid.
targetLabelsToMap = [20 21];
holeRepairTargetLabels = [20 21];
holeRepairMaxPasses = 2;
holeRepairMinNodeVotes = 4;
fillUnmappedTargetLabels = 21;

geometryBounds = readStepCartesianPointBounds(geometryFile);

fprintf('Mapping head tissues with enlarged sfera domain...\n');
fprintf('  Source head: %s\n', headDatFile);
fprintf('  Target mesh: %s\n', biggerBowlDatFile);
fprintf('  Sfera STEP:  %s\n', geometryFile);
fprintf('  Output mesh: %s\n', outputDatFile);
fprintf('  STEP center: [%g %g %g]\n', geometryBounds.center);
fprintf('  STEP radii:  [%g %g %g]\n', geometryBounds.radii);

[~, mapInfo] = mapDatMeshLabels( ...
    headDatFile, ...
    biggerBowlDatFile, ...
    'InputLabels', headLabels, ...
    'TargetLabels', targetLabelsToMap, ...
    'InputLabelNames', headNames, ...
    'NewLabelNames', headNames, ...
    'OutputDatFile', outputDatFile, ...
    'LogFile', logFile, ...
    'ChunkSize', 250000, ...
    'SourceCentroidRepair', true, ...
    'HoleRepairTargetLabels', holeRepairTargetLabels, ...
    'HoleRepairMaxPasses', holeRepairMaxPasses, ...
    'HoleRepairMinNodeVotes', holeRepairMinNodeVotes, ...
    'FillUnmappedTargetLabels', fillUnmappedTargetLabels);

label20Bounds = meshLabelBounds(mapInfo.targetMesh, 20);
writeSummary(summaryFile, mapInfo, geometryBounds, label20Bounds, ...
    targetLabelsToMap, holeRepairTargetLabels);

fprintf('\nHead tissue remap summary:\n');
for row = 1:height(mapInfo.labelMap)
    fprintf('  Head label %g (%s) -> target label %g (%s): %d tetrahedra\n', ...
        mapInfo.labelMap.InputLabel(row), ...
        char(mapInfo.labelMap.InputLabelName(row)), ...
        mapInfo.labelMap.NewTargetLabel(row), ...
        char(mapInfo.labelMap.NewTargetLabelName(row)), ...
        mapInfo.labelMap.MappedTargetElements(row));
end

fprintf('\nSource-centroid repair:\n');
fprintf('  Located source elements: %d\n', mapInfo.repairInfo.locatedSourceElements);
fprintf('  Unlocated source elements: %d\n', mapInfo.repairInfo.unlocatedSourceElements);

fprintf('\nLocal hole repair:\n');
fprintf('  Initial unmapped candidates: %d\n', ...
    mapInfo.holeRepairInfo.initialUnmappedTargetElements);
fprintf('  Filled target elements: %d\n', ...
    mapInfo.holeRepairInfo.filledTargetElements);

fprintf('\nFinal unmapped-target fill:\n');
fprintf('  Required target labels: %s\n', mat2str(mapInfo.fillInfo.requestedTargetLabels(:).'));
fprintf('  Initially unmapped target elements: %d\n', ...
    mapInfo.fillInfo.initialUnmappedTargetElements);
fprintf('  Filled target elements: %d\n', mapInfo.fillInfo.filledTargetElements);

fprintf('\nDone.\n');
fprintf('  Remapped DAT: %s\n', outputDatFile);
fprintf('  Label log:    %s\n', logFile);
fprintf('  Summary:      %s\n', summaryFile);

function bounds = meshLabelBounds(mesh, label)
rows = find(mesh.elementLabels == label);
if isempty(rows)
    bounds = struct('label', label, 'elementCount', 0, ...
        'min', [nan nan nan], 'max', [nan nan nan], ...
        'center', [nan nan nan], 'radii', [nan nan nan]);
    return;
end

nodeIds = unique(mesh.elements(rows, :));
bounds = struct();
bounds.label = label;
bounds.elementCount = numel(rows);
bounds.min = min(mesh.nodes(nodeIds, :), [], 1);
bounds.max = max(mesh.nodes(nodeIds, :), [], 1);
bounds.center = (bounds.min + bounds.max) / 2;
bounds.radii = (bounds.max - bounds.min) / 2;
end

function writeSummary(summaryFile, mapInfo, geometryBounds, label20Bounds, ...
    targetLabelsToMap, holeRepairTargetLabels)
fid = fopen(summaryFile, 'w');
if fid < 0
    error('buildHeadMappingBiggerDomain:SummaryWriteFailed', ...
        'Could not write summary file: %s', summaryFile);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'Bigger sfera head mapping summary\n');
fprintf(fid, 'Created: %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
fprintf(fid, 'Output DAT: %s\n', mapInfo.outputDatFile);
fprintf(fid, 'Target labels searched: %s\n', joinNumbers(targetLabelsToMap));
fprintf(fid, 'Hole-repair target labels: %s\n', joinNumbers(holeRepairTargetLabels));

fprintf(fid, '\nSTEP geometry domain\n');
fprintf(fid, '  File: %s\n', geometryBounds.file);
fprintf(fid, '  Cartesian points: %d\n', geometryBounds.pointCount);
fprintf(fid, '  Bounds X: [%g, %g]\n', geometryBounds.min(1), geometryBounds.max(1));
fprintf(fid, '  Bounds Y: [%g, %g]\n', geometryBounds.min(2), geometryBounds.max(2));
fprintf(fid, '  Bounds Z: [%g, %g]\n', geometryBounds.min(3), geometryBounds.max(3));
fprintf(fid, '  Center: [%g, %g, %g]\n', geometryBounds.center);
fprintf(fid, '  Radii: [%g, %g, %g]\n', geometryBounds.radii);

fprintf(fid, '\nTarget label 20 mesh domain\n');
fprintf(fid, '  Elements: %d\n', label20Bounds.elementCount);
fprintf(fid, '  Bounds X: [%g, %g]\n', label20Bounds.min(1), label20Bounds.max(1));
fprintf(fid, '  Bounds Y: [%g, %g]\n', label20Bounds.min(2), label20Bounds.max(2));
fprintf(fid, '  Bounds Z: [%g, %g]\n', label20Bounds.min(3), label20Bounds.max(3));
fprintf(fid, '  Center: [%g, %g, %g]\n', label20Bounds.center);
fprintf(fid, '  Radii: [%g, %g, %g]\n', label20Bounds.radii);

fprintf(fid, '\nMapping counts\n');
for row = 1:height(mapInfo.labelMap)
    fprintf(fid, '  %g (%s) -> %g (%s): %d target elements\n', ...
        mapInfo.labelMap.InputLabel(row), ...
        char(mapInfo.labelMap.InputLabelName(row)), ...
        mapInfo.labelMap.NewTargetLabel(row), ...
        char(mapInfo.labelMap.NewTargetLabelName(row)), ...
        mapInfo.labelMap.MappedTargetElements(row));
end

fprintf(fid, '\nSource-centroid repair\n');
fprintf(fid, '  Located source elements: %d\n', ...
    mapInfo.repairInfo.locatedSourceElements);
fprintf(fid, '  Unlocated source elements: %d\n', ...
    mapInfo.repairInfo.unlocatedSourceElements);

fprintf(fid, '\nLocal hole repair\n');
fprintf(fid, '  Initial unmapped target elements: %d\n', ...
    mapInfo.holeRepairInfo.initialUnmappedTargetElements);
fprintf(fid, '  Filled target elements: %d\n', ...
    mapInfo.holeRepairInfo.filledTargetElements);

fprintf(fid, '\nFinal unmapped-target fill\n');
fprintf(fid, '  Initial unmapped target elements: %d\n', ...
    mapInfo.fillInfo.initialUnmappedTargetElements);
fprintf(fid, '  Filled target elements: %d\n', ...
    mapInfo.fillInfo.filledTargetElements);
end

function text = joinNumbers(values)
text = strjoin(compose('%.15g', values(:).'), ', ');
end

function repoRoot = getRepoRoot()
scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    repoRoot = pwd;
else
    repoRoot = fileparts(scriptPath);
end
end
