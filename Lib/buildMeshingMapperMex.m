function outputFiles = buildMeshingMapperMex(varargin)
%BUILDMESHINGMAPPERMEX Compile optional C++ MEX accelerators.
%
%   outputFiles = buildMeshingMapperMex() compiles the optional C++ helper
%   used by mapDatMeshLabels for fallback point-in-tetrahedron searches.
%
%   Name-value options:
%       'SourceFolder'  Folder containing C++ sources. Default: repo/mex.
%       'OutputFolder'  Folder for compiled MEX files. Default: repo/mex.
%       'Verbose'       Print compiler details. Default: false.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'SourceFolder', '', @isTextScalar);
addParameter(parser, 'OutputFolder', '', @isTextScalar);
addParameter(parser, 'Verbose', false, @(x) islogical(x) && isscalar(x));
parse(parser, varargin{:});

repoRoot = getRepoRoot();
sourceFolder = char(parser.Results.SourceFolder);
if isempty(sourceFolder)
    sourceFolder = fullfile(repoRoot, 'mex');
end

outputFolder = char(parser.Results.OutputFolder);
if isempty(outputFolder)
    outputFolder = sourceFolder;
end
if exist(outputFolder, 'dir') ~= 7
    mkdir(outputFolder);
end

sources = fullfile(sourceFolder, "locatePointsInTetsMex.cpp");
outputFiles = strings(numel(sources), 1);
for sourceIndex = 1:numel(sources)
    sourceFile = char(sources(sourceIndex));
    if exist(sourceFile, 'file') ~= 2
        error('buildMeshingMapperMex:MissingSource', ...
            'Could not find MEX source file: %s', sourceFile);
    end

    [~, sourceName] = fileparts(sourceFile);
    fprintf('Compiling %s...\n', sourceFile);
    if parser.Results.Verbose
        mex('-v', '-outdir', outputFolder, sourceFile);
    else
        mex('-outdir', outputFolder, sourceFile);
    end
    outputFiles(sourceIndex) = fullfile(outputFolder, [sourceName '.' mexext]);
    fprintf('Built %s\n', outputFiles(sourceIndex));
end

addpath(outputFolder);
end

function tf = isTextScalar(value)
tf = (ischar(value) && (isrow(value) || isempty(value))) || ...
     (isstring(value) && isscalar(value));
end

function repoRoot = getRepoRoot()
scriptPath = mfilename('fullpath');
if isempty(scriptPath)
    repoRoot = pwd;
else
    repoRoot = fileparts(fileparts(scriptPath));
end
end
