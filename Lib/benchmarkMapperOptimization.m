function results = benchmarkMapperOptimization
%BENCHMARKMAPPEROPTIMIZATION Compare mapper execution modes on this machine.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'Lib'));
files = resolveExampleMeshes( ...
    fullfile(repoRoot, 'examples', 'mapper', 'data'), "load");

caseNames = ["serial_matlab"; "serial_mex"; ...
    "threads_16"; "threads_32"; "threads_64"];
workerCounts = [0; 0; 16; 32; 64];
useMex = [false; true; false; false; false];
poolStartupSeconds = zeros(numel(caseNames), 1);
mappingSeconds = zeros(numel(caseNames), 1);
parallelEnabled = false(numel(caseNames), 1);
mexEnabled = false(numel(caseNames), 1);

for index = 1:numel(caseNames)
    pool = gcp('nocreate');
    if ~isempty(pool)
        delete(pool);
    end

    workers = workerCounts(index);
    if workers > 0
        timer = tic;
        parpool('threads', workers);
        poolStartupSeconds(index) = toc(timer);
    end

    setup = struct();
    setup.InputLabels = [1 2 3];
    setup.NewLabels = [71 72 73];
    setup.TargetLabels = [10 20];
    setup.OutputFile = fullfile(tempdir, ...
        ['meshing_mapper_benchmark_' char(caseNames(index)) '.dat']);
    setup.LogFile = fullfile(tempdir, ...
        ['meshing_mapper_benchmark_' char(caseNames(index)) '_log.txt']);
    setup.UseParallel = workers > 0;
    setup.ParallelPoolType = "threads";
    if workers > 0
        setup.ParallelWorkers = workers;
    end
    setup.ChunkSize = 500;
    setup.UseMex = useMex(index);
    setup.BuildMex = false;
    setup.MexRequired = useMex(index);

    timer = tic;
    result = remap(files.LayeredBaselineDat, files.MultiShapeDat, setup);
    mappingSeconds(index) = toc(timer);
    parallelEnabled(index) = result.MapInfo.optimizationInfo.useParallel;
    mexEnabled(index) = result.MapInfo.optimizationInfo.useMex;
end

pool = gcp('nocreate');
if ~isempty(pool)
    delete(pool);
end

totalSeconds = poolStartupSeconds + mappingSeconds;
results = table(caseNames, workerCounts, useMex, poolStartupSeconds, ...
    mappingSeconds, totalSeconds, parallelEnabled, mexEnabled);
disp(results);
end
