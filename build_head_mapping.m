%BUILD_HEAD_MAPPING Map the five-tissue head mesh onto the bowl mesh.
%
% Inputs:
%   HeadMapping/mesh_head.dat   - source mask with five tissue labels
%   HeadMapping/mesh_bowls.dat  - target mesh to keep
%
% Output:
%   result/mesh_bowls_with_head.dat
%   result/mesh_bowls_with_head_label_log.txt

clear;
clc;

repoRoot = getRepoRoot();
addpath(fullfile(repoRoot, 'Lib'));

inputDir = fullfile(repoRoot, 'HeadMapping');
resultDir = fullfile(repoRoot, 'result');
if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end

headDatFile = fullfile(inputDir, 'mesh_head.dat');
bowlDatFile = fullfile(inputDir, 'mesh_bowls.dat');
outputDatFile = fullfile(resultDir, 'mesh_bowls_with_head.dat');
logFile = fullfile(resultDir, 'mesh_bowls_with_head_label_log.txt');

headLabels = (1:5).';
headNames = ["gray"; "CSF"; "FAT"; "SKIN"; "SKULL"];

% Bowl labels 20 and 21 correspond to "sfera" and "sfera interna" in
% Legends_bowls.png. They are the primary domain for the target-centroid
% projection. Label 19 is used only as a source-centroid repair fallback for
% remaining head elements near the lower/boundary region, so every source
% head element has a chance to be represented without broadly remapping the
% whole bowl.
targetLabelsToMap = [20 21];
repairFallbackTargetLabels = 19;

fprintf('Mapping head tissues onto bowl mesh...\n');
fprintf('  Source head: %s\n', headDatFile);
fprintf('  Target bowl: %s\n', bowlDatFile);
fprintf('  Output mesh: %s\n', outputDatFile);

[~, mapInfo] = mapDatMeshLabels( ...
    headDatFile, ...
    bowlDatFile, ...
    'InputLabels', headLabels, ...
    'TargetLabels', targetLabelsToMap, ...
    'InputLabelNames', headNames, ...
    'NewLabelNames', headNames, ...
    'OutputDatFile', outputDatFile, ...
    'LogFile', logFile, ...
    'ChunkSize', 250000, ...
    'SourceCentroidRepair', true, ...
    'RepairFallbackTargetLabels', repairFallbackTargetLabels);

fprintf('\nHead tissue remap summary:\n');
for row = 1:height(mapInfo.labelMap)
    fprintf('  Head label %g (%s) -> bowl label %g (%s): %d tetrahedra\n', ...
        mapInfo.labelMap.InputLabel(row), ...
        char(mapInfo.labelMap.InputLabelName(row)), ...
        mapInfo.labelMap.NewTargetLabel(row), ...
        char(mapInfo.labelMap.NewTargetLabelName(row)), ...
        mapInfo.labelMap.MappedTargetElements(row));
end
if isfield(mapInfo, 'repairInfo') && mapInfo.repairInfo.enabled
    fprintf('\nSource-centroid repair:\n');
    fprintf('  Primary target labels: %s\n', mat2str(mapInfo.repairInfo.primaryTargetLabels(:).'));
    if ~isempty(mapInfo.repairInfo.fallbackTargetLabels)
        fprintf('  Fallback target labels: %s\n', mat2str(mapInfo.repairInfo.fallbackTargetLabels(:).'));
    end
    fprintf('  Total selected source elements: %d\n', mapInfo.repairInfo.totalSourceElements);
    fprintf('  Located source elements: %d\n', mapInfo.repairInfo.locatedSourceElements);
    fprintf('  Unlocated source elements: %d\n', mapInfo.repairInfo.unlocatedSourceElements);
    fprintf('  Repaired target elements: %d\n', mapInfo.repairInfo.repairedTargetElements);
    fprintf('  Primary located source elements: %d\n', mapInfo.repairInfo.primaryLocatedSourceElements);
    fprintf('  Fallback newly located source elements: %d\n', ...
        mapInfo.repairInfo.fallbackNewLocatedSourceElements);
end

fprintf('\nDone.\n');
fprintf('  Remapped DAT: %s\n', outputDatFile);
fprintf('  Label log:    %s\n', logFile);

function repoRoot = getRepoRoot()
scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    repoRoot = pwd;
else
    repoRoot = fileparts(scriptPath);
end
end
