function run_release_tests
%RUN_RELEASE_TESTS Run the documented examples and verify mapping behavior.

testRoot = fileparts(mfilename('fullpath'));
repoRoot = fileparts(testRoot);
addpath(repoRoot);
addpath(fullfile(repoRoot, 'Lib'));
addpath(fullfile(repoRoot, 'examples'));

fprintf('Running sectioned DAT and MSH examples...\n');
figureVisibility = 'off'; %#ok<NASGU>
exampleDataMode = "generate"; %#ok<NASGU>
run(fullfile(repoRoot, 'main.m'));

assert(sphere_remap.Validation.Valid);
assert(nnz(sphere_remap.MappedLabels == 11) > 0);
assert(contains(fileread(sphere_remap.OutputFile), 'Example metadata'));

assert(all(ismember([31 32 33], unique(all_labels_remap.MappedLabels))));
assert(all(ismember([32 33], unique(internal_only_remap.MappedLabels))));
outerRows = internal_only_remap.MapInfo.targetMesh.elementLabels == 10;
assert(~any(ismember(internal_only_remap.MappedLabels(outerRows), [32 33])));

assert(msh_sphere_remap.Validation.Valid);
assert(any(msh_sphere_remap.MappedLabels == 11));
assert(all(ismember([32 33], unique(msh_internal_remap.MappedLabels))));
mshOuterRows = msh_internal_remap.MapInfo.targetMesh.elementData(:, 1) == 10;
assert(~any(ismember(msh_internal_remap.MappedLabels(mshOuterRows), [32 33])));
close all;

fprintf('Checking committed example-data load mode...\n');
loadedFiles = resolveExampleMeshes( ...
    fullfile(repoRoot, 'examples', 'mapper', 'data'), "load");
assert(isequal(files, loadedFiles));

fprintf('Checking output-label conflict protection...\n');
automaticMshSetup = struct();
automaticMshSetup.InputLabels = 1;
automaticMshSetup.TargetLabels = 10;
automaticMshSetup.OutputFile = fullfile(exampleOutput, ...
    'automatic_nonconflicting_labels.msh');
automaticMsh = remap(files.BaselineMsh, files.SphereMsh, automaticMshSetup);
assert(isequal(automaticMsh.MapInfo.newLabels, 11));
assert(any(automaticMsh.MappedLabels == 11));

fprintf('Checking DAT optimization settings...\n');
optimizationSetup = sphereSetup;
optimizationSetup.NewLabels = 61;
optimizationSetup.OutputFile = fullfile(exampleOutput, ...
    'optimization_serial_test.dat');
optimizationSetup.LogFile = fullfile(exampleOutput, ...
    'optimization_serial_test_log.txt');
optimizationSetup.UseParallel = false;
optimizationSetup.UseMex = false;
serialOptimization = remap(files.BaselineDat, files.SphereDat, optimizationSetup);
assert(~serialOptimization.MapInfo.optimizationInfo.useParallel);
assert(~serialOptimization.MapInfo.optimizationInfo.useMex);

if exist('parpool', 'file') == 2 && license('test', 'Distrib_Computing_Toolbox') == 1
    optimizationSetup.NewLabels = 62;
    optimizationSetup.OutputFile = fullfile(exampleOutput, ...
        'optimization_parallel_test.dat');
    optimizationSetup.LogFile = fullfile(exampleOutput, ...
        'optimization_parallel_test_log.txt');
    optimizationSetup.UseParallel = true;
    optimizationSetup.ParallelPoolType = "threads";
    optimizationSetup.ChunkSize = 1000;
    parallelOptimization = remap( ...
        files.BaselineDat, files.SphereDat, optimizationSetup);
    assert(parallelOptimization.MapInfo.optimizationInfo.useParallel);
    pool = gcp('nocreate');
    if ~isempty(pool)
        delete(pool);
    end
end

if exist('locatePointsInTetsMex', 'file') == 3
    optimizationSetup.NewLabels = 63;
    optimizationSetup.OutputFile = fullfile(exampleOutput, ...
        'optimization_mex_test.dat');
    optimizationSetup.LogFile = fullfile(exampleOutput, ...
        'optimization_mex_test_log.txt');
    optimizationSetup.UseParallel = false;
    optimizationSetup.UseMex = true;
    optimizationSetup.BuildMex = false;
    optimizationSetup.MexRequired = true;
    mexOptimization = remap( ...
        files.BaselineDat, files.SphereDat, optimizationSetup);
    assert(mexOptimization.MapInfo.optimizationInfo.useMex);
end

conflictingMex = optimizationSetup;
conflictingMex.UseMex = false;
conflictingMex.MexRequired = true;
assertError(@() remap(files.BaselineDat, files.SphereDat, conflictingMex), ...
    'meshingMapper:ConflictingMexSettings');

datConflict = sphereSetup;
datConflict.NewLabels = 10;
datConflict.OutputFile = fullfile(exampleOutput, 'must_not_write_conflict.dat');
assertError(@() remap(files.BaselineDat, files.SphereDat, datConflict), ...
    'mapDatMeshLabels:NewLabelConflict');

datDuplicate = allLabelsSetup;
datDuplicate.NewLabels = [31 31 33];
datDuplicate.OutputFile = fullfile(exampleOutput, 'must_not_write_duplicate.dat');
assertError(@() remap(files.LayeredBaselineDat, files.MultiShapeDat, datDuplicate), ...
    'mapDatMeshLabels:DuplicateNewLabels');

mshConflict = mshSphereSetup;
mshConflict.NewLabels = 10;
mshConflict.OutputFile = fullfile(exampleOutput, 'must_not_write_conflict.msh');
assertError(@() remap(files.BaselineMsh, files.SphereMsh, mshConflict), ...
    'map3DMeshLabels:NewLabelConflict');

mshDuplicate = mshInternalSetup;
mshDuplicate.NewLabels = [32 32];
mshDuplicate.OutputFile = fullfile(exampleOutput, 'must_not_write_duplicate.msh');
assertError(@() remap(files.LayeredBaselineMsh, files.MultiShapeMsh, ...
    mshDuplicate), 'map3DMeshLabels:DuplicateNewLabels');

fprintf('Checking production DAT translation helper...\n');
translatedDat = fullfile(exampleOutput, 'translated_source_test.dat');
translation = [0.1 -0.2 0.3];
translationInfo = translateDatMeshCoordinates( ...
    files.SphereDat, translatedDat, translation);
translatedValidation = validateDatMeshFile( ...
    translatedDat, 'ReferenceFile', files.SphereDat);
assert(translatedValidation.Valid);
assert(max(abs((translationInfo.transformedBoundingBox - ...
    translationInfo.originalBoundingBox) - repmat(translation, 2, 1)), ...
    [], 'all') < 1e-9);

fprintf('Release tests passed.\n');
end

function assertError(functionHandle, expectedIdentifier)
try
    functionHandle();
catch exception
    assert(strcmp(exception.identifier, expectedIdentifier), ...
        'Expected error %s, received %s.', ...
        expectedIdentifier, exception.identifier);
    return;
end
error('runReleaseTests:ExpectedErrorNotThrown', ...
    'Expected error %s was not thrown.', expectedIdentifier);
end
