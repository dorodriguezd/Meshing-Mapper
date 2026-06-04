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

% Bowl label 21 corresponds to "sfera interna" in Legends_bowls.png and is
% the intended containing subdomain for the head. Set this to [] to search
% every target label, but that is much slower for this 6.75M-element mesh.
targetLabelsToMap = 21;

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
    'ChunkSize', 250000);

fprintf('\nHead tissue remap summary:\n');
for row = 1:height(mapInfo.labelMap)
    fprintf('  Head label %g (%s) -> bowl label %g (%s): %d tetrahedra\n', ...
        mapInfo.labelMap.InputLabel(row), ...
        char(mapInfo.labelMap.InputLabelName(row)), ...
        mapInfo.labelMap.NewTargetLabel(row), ...
        char(mapInfo.labelMap.NewTargetLabelName(row)), ...
        mapInfo.labelMap.MappedTargetElements(row));
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
