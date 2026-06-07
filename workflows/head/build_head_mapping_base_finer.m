%BUILD_HEAD_MAPPING_BASE_FINER Map head_finer onto mesh_base conservatively.
%
% This workflow uses only direct evidence from the source mesh:
%   1. target centroids located inside head_finer elements;
%   2. source centroids located inside target elements.
%
% Neighbor-based hole repair is intentionally disabled. Label 19 is searched
% only near the external surface of head_finer to avoid scanning the full bowl.
% Set mappingTargetLabels = [] to search the whole target domain.

clear;
clc;

repoRoot = getRepoRoot();
addpath(fullfile(repoRoot, 'Lib'));

inputDir = fullfile(repoRoot, 'input');
resultDir = fullfile(repoRoot, 'result', 'base_finer');
if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end

[headDatFile, baseDatFile] = resolveHeadInputFiles(inputDir);
outputDatFile = fullfile(resultDir, 'mesh_base_with_head_finer.dat');
logFile = fullfile(resultDir, 'mesh_base_with_head_finer_label_log.txt');
summaryFile = fullfile(resultDir, 'mesh_base_with_head_finer_summary.txt');

headLabels = (1:5).';
headNames = ["gray"; "CSF"; "FAT"; "SKIN"; "SKULL"];

% Main user-adjustable search-domain parameters. Leave mappingTargetLabels
% empty to map against the whole target mesh.
primaryTargetLabels = 20:24;
surfaceTargetLabels = 19;
mappingTargetLabels = [primaryTargetLabels, surfaceTargetLabels];
surfaceSearchDistance = 0.01; % 1 cm in the mesh units used by these DATs.

fprintf('Mapping finer head onto base mesh...\n');
fprintf('  Source head: %s\n', headDatFile);
fprintf('  Target base: %s\n', baseDatFile);
fprintf('  Output mesh: %s\n', outputDatFile);
if isempty(mappingTargetLabels)
    fprintf('  Target labels: all target labels\n');
else
    fprintf('  Target labels: %s\n', mat2str(mappingTargetLabels));
end
fprintf('  Surface-filter labels: %s within %.4g\n', ...
    mat2str(surfaceTargetLabels), surfaceSearchDistance);

mapOptions = { ...
    'InputLabels', headLabels, ...
    'InputLabelNames', headNames, ...
    'NewLabelNames', headNames, ...
    'OutputDatFile', outputDatFile, ...
    'LogFile', logFile, ...
    'ChunkSize', 250000, ...
    'SourceCentroidRepair', true};

if ~isempty(mappingTargetLabels)
    mapOptions = [mapOptions, {'TargetLabels', mappingTargetLabels}];
end
if ~isempty(surfaceTargetLabels) && isfinite(surfaceSearchDistance)
    mapOptions = [mapOptions, { ...
        'TargetSurfaceDistanceFilterLabels', surfaceTargetLabels, ...
        'TargetSurfaceDistance', surfaceSearchDistance}];
end

[~, mapInfo] = mapDatMeshLabels(headDatFile, baseDatFile, mapOptions{:});
writeSummary(summaryFile, mapInfo, primaryTargetLabels, surfaceTargetLabels, ...
    mappingTargetLabels, surfaceSearchDistance);

fprintf('\nFiner head remap summary:\n');
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
fprintf('  Repaired target elements: %d\n', mapInfo.repairInfo.repairedTargetElements);

if mapInfo.surfaceFilterInfo.enabled
    fprintf('\nSurface-distance target filter:\n');
    fprintf('  Filtered-label candidates: %d\n', ...
        mapInfo.surfaceFilterInfo.filteredLabelCandidateElements);
    fprintf('  Kept filtered-label elements: %d\n', ...
        mapInfo.surfaceFilterInfo.keptFilteredLabelElements);
    fprintf('  Removed filtered-label elements: %d\n', ...
        mapInfo.surfaceFilterInfo.removedFilteredLabelElements);
end

fprintf('\nDone.\n');
fprintf('  Remapped DAT: %s\n', outputDatFile);
fprintf('  Label log:    %s\n', logFile);
fprintf('  Summary:      %s\n', summaryFile);

function writeSummary(summaryFile, mapInfo, primaryTargetLabels, surfaceTargetLabels, ...
    mappingTargetLabels, surfaceSearchDistance)
fid = fopen(summaryFile, 'w');
if fid < 0
    error('buildHeadMappingBaseFiner:SummaryWriteFailed', ...
        'Could not write summary file: %s', summaryFile);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'Base mesh / finer head mapping summary\n');
fprintf(fid, 'Created: %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
fprintf(fid, 'Output DAT: %s\n', mapInfo.outputDatFile);
if isempty(mappingTargetLabels)
    fprintf(fid, 'Target labels searched: all target labels\n');
else
    fprintf(fid, 'Target labels searched: %s\n', joinNumbers(mappingTargetLabels));
end
fprintf(fid, 'Primary target labels: %s\n', joinNumbers(primaryTargetLabels));
fprintf(fid, 'Surface-filter target labels: %s\n', joinNumbers(surfaceTargetLabels));
fprintf(fid, 'Surface-filter distance: %.15g\n', surfaceSearchDistance);

if mapInfo.surfaceFilterInfo.enabled
    fprintf(fid, '\nSurface-distance target filter\n');
    fprintf(fid, '  Initial candidate target elements: %d\n', ...
        mapInfo.surfaceFilterInfo.initialCandidateElements);
    fprintf(fid, '  Filtered-label candidate elements: %d\n', ...
        mapInfo.surfaceFilterInfo.filteredLabelCandidateElements);
    fprintf(fid, '  Kept filtered-label elements: %d\n', ...
        mapInfo.surfaceFilterInfo.keptFilteredLabelElements);
    fprintf(fid, '  Removed filtered-label elements: %d\n', ...
        mapInfo.surfaceFilterInfo.removedFilteredLabelElements);
    fprintf(fid, '  Input surface nodes: %d\n', ...
        mapInfo.surfaceFilterInfo.surfaceNodeCount);
end

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
fprintf(fid, '  Repaired target elements: %d\n', ...
    mapInfo.repairInfo.repairedTargetElements);
end

function text = joinNumbers(values)
text = strjoin(compose('%.15g', values(:).'), ', ');
end

function repoRoot = getRepoRoot()
scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    repoRoot = pwd;
else
    repoRoot = fileparts(fileparts(fileparts(scriptPath)));
end
end
