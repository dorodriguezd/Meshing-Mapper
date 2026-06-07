function [headDatFile, baseDatFile] = resolveHeadInputFiles(inputFolder)
%RESOLVEHEADINPUTFILES Find supported local head-workflow DAT names.

headDatFile = firstExisting(inputFolder, ...
    {'head_finer.dat', 'mesh__head.dat'});
baseDatFile = firstExisting(inputFolder, ...
    {'mesh_base.dat', 'mesh__baseline.dat'});
end

function fileName = firstExisting(folder, candidates)
for index = 1:numel(candidates)
    candidate = fullfile(folder, candidates{index});
    if exist(candidate, 'file') == 2
        fileName = candidate;
        return;
    end
end
fileName = fullfile(folder, candidates{1});
end
