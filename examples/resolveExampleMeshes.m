function files = resolveExampleMeshes(dataFolder, mode)
%RESOLVEEXAMPLEMESHES Generate or load the documented example mesh files.
%
%   files = RESOLVEEXAMPLEMESHES(dataFolder, "load")
%   files = RESOLVEEXAMPLEMESHES(dataFolder, "generate")

if nargin < 1 || isempty(dataFolder)
    exampleRoot = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(exampleRoot, 'mapper', 'data');
end
if nargin < 2 || strlength(string(mode)) == 0
    mode = "load";
end

mode = lower(string(mode));
if ~isscalar(mode)
    error('resolveExampleMeshes:InvalidMode', ...
        'Mode must be "load" or "generate".');
end

switch mode
    case "generate"
        files = generateExampleMeshes(dataFolder);
    case "load"
        files = exampleFilePaths(dataFolder);
        verifyExampleFiles(files);
        fprintf('Loaded committed example meshes from %s\n', dataFolder);
    otherwise
        error('resolveExampleMeshes:InvalidMode', ...
            'Mode must be "load" or "generate", not "%s".', mode);
end
end

function files = exampleFilePaths(dataFolder)
files = struct();
files.BaselineDat = fullfile(dataFolder, 'baseline_cube_5cm.dat');
files.SphereDat = fullfile(dataFolder, 'sphere_3cm.dat');
files.LayeredBaselineDat = fullfile(dataFolder, 'baseline_layered_cubes.dat');
files.MultiShapeDat = fullfile(dataFolder, 'source_multishape.dat');
files.BaselineMsh = fullfile(dataFolder, 'baseline_cube_5cm.msh');
files.SphereMsh = fullfile(dataFolder, 'sphere_3cm.msh');
files.LayeredBaselineMsh = fullfile(dataFolder, 'baseline_layered_cubes.msh');
files.MultiShapeMsh = fullfile(dataFolder, 'source_multishape.msh');
end

function verifyExampleFiles(files)
names = fieldnames(files);
missing = strings(0, 1);
for index = 1:numel(names)
    fileName = files.(names{index});
    if exist(fileName, 'file') ~= 2
        missing(end + 1, 1) = string(fileName); %#ok<AGROW>
    end
end
if ~isempty(missing)
    error('resolveExampleMeshes:MissingExampleFiles', ...
        ['Example data mode is "load", but these files are missing:\n  %s\n' ...
        'Use exampleDataMode = "generate" to recreate them.'], ...
        strjoin(missing, newline + "  "));
end
end
