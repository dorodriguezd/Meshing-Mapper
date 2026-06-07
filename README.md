# Meshing-Mapper

Meshing-Mapper transfers labeled tetrahedral volumes from a source mesh onto
an existing baseline mesh.

The baseline coordinates and element connectivity are retained. Only selected
baseline element labels are replaced. For DAT files, unrelated problem
sections are preserved and material-property rows are appended for the mapped
labels.

Supported mapping formats:

- Custom problem-type tetrahedral `.dat`
- GiD tetrahedral `.msh`

Mesh translation and rotation are maintained separately:

```text
https://github.com/dorodriguezd/Mesh_Transformer
```

## Requirements

- MATLAB R2021b or newer
- MATLAB R2026a is used for the validated project workflows
- Parallel Computing Toolbox is optional
- A supported C++ compiler is optional for the fallback MEX locator

## Quick Start

Start MATLAB in the repository root and run:

```matlab
run("main.m");
```

`main.m` is a setup script, not a function. It contains independent MATLAB
sections for all DAT and MSH examples. Generated outputs and figures are
written to:

```text
examples/mapper/output/
```

`main.m` is the only MATLAB file exposed at the repository root. All
functions, including the mapper API, example-data helpers, validation,
visualization, benchmarks, and tests, are under `Lib/`.

## Public Mapping API

The recommended public call is:

```matlab
result = remap(baseline, source, setup);
```

- `baseline`: mesh whose coordinates and connectivity are retained
- `source`: labeled volume projected onto the baseline
- `setup`: mapping options
- `result.OutputFile`: generated remapped baseline
- `result.MappedLabels`: output label per baseline tetrahedron
- `result.MapInfo`: parsed meshes, label map, and mapping statistics
- `result.Validation`: output validation information

Basic example:

```matlab
baseline = "path/to/baseline.dat";
source = "path/to/source.dat";

setup = struct();
setup.InputLabels = [1 2];
setup.NewLabels = [21 22];
setup.TargetLabels = [10 11];
setup.InputLabelNames = ["core", "shell"];
setup.NewLabelNames = ["mapped core", "mapped shell"];
setup.OutputFile = "result/remapped_baseline.dat";
setup.LogFile = "result/remapped_baseline_log.txt";

result = remap(baseline, source, setup);
```

## Example Data

All example dimensions are expressed in centimeters.

The included geometry consists of:

- Homogeneous baseline: `5 x 5 x 5 cm`
- Layered baseline: outer `5 x 5 x 5 cm` cube and inner `4 x 4 x 4 cm` cube
- Inner baseline spacing: `0.25 cm`
- Outer baseline spacing: `0.5 cm`
- Main source sphere: `3 cm` diameter, centered at `[2.5 2.5 2.5]`
- Internal source sphere: `1 cm` diameter
- Internal source cube: `0.5 cm` side

The small sphere and cube use different positions and do not overlap.

### Load Existing Data

The committed DAT and MSH fixtures are used by default:

```matlab
exampleDataMode = "load";
run("main.m");
```

Load mode verifies that all required files exist. If one is missing, MATLAB
reports the missing paths and instructs you to use generation mode.

### Generate Data

Regenerate every DAT and MSH input from the geometry definitions:

```matlab
exampleDataMode = "generate";
run("main.m");
```

Generate the files without running the mapping examples:

```matlab
addpath("Lib");
files = generateExampleMeshes();
```

Resolve either mode programmatically:

```matlab
addpath("Lib");
files = resolveExampleMeshes("examples/mapper/data", "load");
files = resolveExampleMeshes("examples/mapper/data", "generate");
```

The returned `files` struct contains:

```text
BaselineDat
SphereDat
LayeredBaselineDat
MultiShapeDat
BaselineMsh
SphereMsh
LayeredBaselineMsh
MultiShapeMsh
```

## DAT Example 1: Sphere in Homogeneous Cube

This case maps source label `1`, representing the centered 3 cm sphere, into
baseline label `10`. The mapped sphere receives output label `11`.

```matlab
baseline = files.BaselineDat;
source = files.SphereDat;

setup = struct();
setup.InputLabels = 1;
setup.NewLabels = 11;
setup.TargetLabels = 10;
setup.InputLabelNames = "sphere";
setup.NewLabelNames = "mapped sphere";
setup.OutputFile = "examples/mapper/output/dat_1_sphere_remap.dat";
setup.LogFile = "examples/mapper/output/dat_1_sphere_remap_log.txt";

sphere_remap = remap(baseline, source, setup);
```

The corresponding `main.m` section produces:

- Starting homogeneous baseline figure
- Starting source-sphere figure
- Remapped baseline figure
- Remapped DAT
- Label log

## DAT Example 2: Map All Source Labels

The baseline has two labels:

| Baseline label | Region |
|---:|---|
| `10` | Outer cube layer |
| `20` | Denser inner cube |

The source has three labels:

| Source label | Shape | Output label |
|---:|---|---:|
| `1` | 3 cm sphere | `31` |
| `2` | 1 cm sphere | `32` |
| `3` | 0.5 cm cube | `33` |

All source labels may map into either baseline layer:

```matlab
setup = struct();
setup.InputLabels = [1 2 3];
setup.NewLabels = [31 32 33];
setup.TargetLabels = [10 20];
setup.InputLabelNames = ["large sphere", "small sphere", "small cube"];
setup.NewLabelNames = ["mapped large sphere", ...
    "mapped small sphere", "mapped small cube"];
setup.OutputFile = "examples/mapper/output/dat_2_all_labels_remap.dat";
setup.LogFile = "examples/mapper/output/dat_2_all_labels_remap_log.txt";

all_labels_remap = remap( ...
    files.LayeredBaselineDat, files.MultiShapeDat, setup);
```

The figures show the layered baseline, the three-label source, and the final
five-group remapped mesh.

## DAT Example 3: Selected Labels and Subdomain

This case demonstrates both source-label selection and baseline-domain
restriction:

- Source labels `2` and `3` are mapped.
- Source label `1` is ignored.
- Mapping is allowed only where the baseline originally has label `20`.
- Baseline label `10` remains unchanged.

```matlab
setup = struct();
setup.InputLabels = [2 3];
setup.NewLabels = [32 33];
setup.TargetLabels = 20;
setup.InputLabelNames = ["small sphere", "small cube"];
setup.NewLabelNames = ["mapped small sphere", "mapped small cube"];
setup.OutputFile = ...
    "examples/mapper/output/dat_3_internal_labels_inner_layer.dat";
setup.LogFile = ...
    "examples/mapper/output/dat_3_internal_labels_inner_layer_log.txt";

internal_only_remap = remap( ...
    files.LayeredBaselineDat, files.MultiShapeDat, setup);
```

Use this pattern when only selected source tissues should replace one baseline
subdomain.

## GiD MSH Example 1: Sphere in Homogeneous Cube

The same homogeneous case is available as GiD MSH:

```matlab
setup = struct();
setup.InputLabels = 1;
setup.NewLabels = 11;
setup.TargetLabels = 10;
setup.OutputFile = "examples/mapper/output/msh_1_sphere_remap.msh";

msh_sphere_remap = remap( ...
    files.BaselineMsh, files.SphereMsh, setup);
```

For MSH files, the first extra element column is treated as the material
label. The output replaces that label while preserving target coordinates and
connectivity.

## GiD MSH Example 2: Selected Internal Labels

This reproduces the selected-label DAT case in MSH:

```matlab
setup = struct();
setup.InputLabels = [2 3];
setup.NewLabels = [32 33];
setup.TargetLabels = 20;
setup.OutputFile = ...
    "examples/mapper/output/msh_2_internal_labels_inner_layer.msh";

msh_internal_remap = remap( ...
    files.LayeredBaselineMsh, files.MultiShapeMsh, setup);
```

Labels `2` and `3` can replace only inner-baseline label `20`. Outer label
`10` is preserved.

## Label Assignment Rules

### Explicit Labels

When `NewLabels` is supplied:

```matlab
setup.InputLabels = [1 2];
setup.NewLabels = [21 22];
```

the mapper requires:

- One output label per selected input label
- Every output label to be distinct
- No output label to already exist in the baseline

If a duplicate is found, mapping stops before writing output:

- Existing baseline collision: `NewLabelConflict`
- Duplicate values in `NewLabels`: `DuplicateNewLabels`

The mapper does not silently overwrite or renumber explicitly supplied
labels.

### Automatic Labels

Omit `NewLabels` to assign consecutive labels above the maximum baseline
label:

```matlab
setup = struct();
setup.InputLabels = [1 2 3];
setup.TargetLabels = [10 20];

result = remap(baseline, source, setup);
disp(result.MapInfo.newLabels);
```

For a baseline whose maximum label is `20`, the automatic labels are
`[21 22 23]`.

### Map All Source Labels

Omit `InputLabels`:

```matlab
setup = struct();
setup.TargetLabels = [10 20];
result = remap(baseline, source, setup);
```

Every source label is selected.

### Search All Baseline Labels

Omit `TargetLabels`:

```matlab
setup = struct();
setup.InputLabels = [1 2];
result = remap(baseline, source, setup);
```

Every baseline element is eligible for mapping.

## Mapping Options

| Field | Purpose |
|---|---|
| `InputLabels` | Source labels to transfer; omit for all |
| `NewLabels` | New output labels; omit for automatic assignment |
| `TargetLabels` | Existing baseline labels eligible for replacement |
| `OutputFile` | Output DAT or MSH path |
| `LogFile` | DAT mapping log path |
| `InputLabelNames` | Names for selected source labels |
| `NewLabelNames` | Names for mapped output labels |
| `TargetLabelNames` | Names for existing baseline labels |
| `Tolerance` | Point-in-tetrahedron tolerance |
| `ChunkSize` | Target elements processed per chunk |
| `UseParallel` | Enable supported parallel mapping chunks |
| `ParallelPoolType` | `"auto"`, `"threads"`, or `"processes"` |
| `ParallelWorkers` | Worker count used when creating a pool |
| `UseMex` | `true`, `false`, or `"auto"` for DAT fallback locator |
| `BuildMex` | Compile a temporary compatible MEX before mapping |
| `MexRequired` | Fail instead of falling back when MEX is unavailable/fails |
| `MexVerbose` | Show verbose compiler output when `BuildMex=true` |
| `SourceCentroidRepair` | Add source-centroid coverage repair |
| `RepairFallbackTargetLabels` | Extra baseline labels used only by repair |
| `FillUnmappedTargetLabels` | Baseline labels that must be completely filled |
| `HoleRepairTargetLabels` | Labels eligible for local node-vote filling |
| `HoleRepairMaxPasses` | Maximum local repair passes |
| `HoleRepairMinNodeVotes` | Required node votes for local repair |
| `TargetSurfaceDistanceFilterLabels` | Labels restricted near source surface |
| `TargetSurfaceDistance` | Maximum source-surface distance |

Repair and surface-distance controls apply to DAT mapping. Basic label
selection, output-label assignment, and baseline-domain restriction work for
both DAT and MSH.

## Parallel and MEX Optimization

Optimization settings are part of the normal `setup` passed to `remap`.
They currently apply to DAT mapping. GiD MSH mapping remains serial MATLAB
code and reports a warning if DAT-only optimization fields are supplied.

### Serial MATLAB

Disable both parallel execution and MEX:

```matlab
setup.UseParallel = false;
setup.UseMex = false;

serial_result = remap(baseline, source, setup);
```

This is the most portable mode and requires no optional toolbox or compiler.

### Parallel MATLAB

Enable chunk-level `parfor` execution:

```matlab
setup.UseParallel = true;
setup.ParallelPoolType = "auto";
setup.ParallelWorkers = 32;
setup.ChunkSize = 500;
setup.UseMex = false;

parallel_result = remap(baseline, source, setup);
```

Pool choices:

- `"auto"`: try a thread pool, then a process pool
- `"threads"`: request a thread-based pool
- `"processes"`: request a process-based pool

If a pool is already open, MATLAB keeps that pool and reports its actual type
in `optimizationInfo.parallelPoolType`. If its worker count differs from
`ParallelWorkers`, the mapper warns and uses the existing pool.

If Parallel Computing Toolbox or a usable pool is unavailable, the mapper
warns and continues serially. Check the actual behavior:

```matlab
parallel_result.MapInfo.optimizationInfo
```

Important: parallel execution is useful only when the selected target domain
is split into multiple chunks. Set `ChunkSize` below the number of candidate
target elements when demonstrating or benchmarking parallel execution.

### Use an Existing MEX

Use a compatible `locatePointsInTetsMex` if available:

```matlab
setup.UseParallel = false;
setup.UseMex = true;
setup.BuildMex = false;
setup.MexRequired = false;

mex_result = remap(baseline, source, setup);
```

With `MexRequired=false`, an unavailable or failing MEX produces a warning and
the mapper continues with the MATLAB fallback.

Use `"auto"` to enable MEX only when a compatible binary is discoverable:

```matlab
setup.UseMex = "auto";
```

`"auto"` is the default.

### Build and Require MEX

Compile from `mex/locatePointsInTetsMex.cpp` before mapping:

```matlab
setup.UseMex = true;
setup.BuildMex = true;
setup.MexRequired = true;
setup.MexVerbose = false;

mex_build_result = remap(baseline, source, setup);
```

The mapper builds into a temporary folder, avoiding replacement of a MEX file
that Windows may already have loaded. `MexRequired=true` makes compiler,
availability, or execution failures fatal. It cannot be combined with
`UseMex=false`.

Do not copy compiled MEX files between machines unless MATLAB release,
operating system, architecture, and compiler ABI are compatible.

### Parallel and MEX Together

The current MEX accelerates only the brute-force fallback point locator, not
MATLAB's primary `triangulation/pointLocation` path.

MATLAB thread workers cannot invoke this MEX helper. For a strict combined
configuration, use a process pool:

```matlab
setup.UseParallel = true;
setup.ParallelPoolType = "processes";
setup.UseMex = true;
setup.MexRequired = true;
```

With thread pools and `MexRequired=false`, workers fall back to MATLAB if the
MEX cannot execute.

### Run Included Optimization Examples

The final section of `main.m` contains serial, parallel, and MEX cases. Enable
them with:

```matlab
exampleDataMode = "load";
figureVisibility = "off";
runOptimizationExamples = true;
runMexBuildExample = false;
run("main.m");
```

Also compile and require a fresh MEX:

```matlab
exampleDataMode = "load";
figureVisibility = "off";
runOptimizationExamples = true;
runMexBuildExample = true;
run("main.m");
```

The resulting variables are:

```text
serial_result
parallel_result
mex_result
mex_build_result    only when runMexBuildExample=true
```

Inspect requested and actual execution:

```matlab
serial_result.MapInfo.optimizationInfo
parallel_result.MapInfo.optimizationInfo
mex_result.MapInfo.optimizationInfo
```

`useMex=true` in `optimizationInfo` means the helper was enabled and
available. The primary MATLAB point-location path may resolve every point, in
which case the fallback MEX does not need to be invoked.

## DAT Format Behavior

Required DAT sections:

- `Coordinates`
- `Elements`
- `Material properties`

Each element row contains four tetrahedral node indices followed by a material
label.

The output:

- Preserves baseline coordinates
- Preserves baseline connectivity
- Preserves unrelated baseline sections
- Rewrites selected element labels
- Appends material-property rows for mapped source labels

The examples include `PEC Faces` and `Example metadata` sections to verify
that unrelated target content is preserved.

Validate a DAT file:

```matlab
addpath("Lib");
report = validateDatMeshFile("result/remapped_baseline.dat");
assert(report.Valid);
```

Validate against the original baseline:

```matlab
report = validateDatMeshFile( ...
    "result/remapped_baseline.dat", ...
    "ReferenceFile", "input/baseline.dat", ...
    "ExpectedAddedMaterials", 3);
```

## Visualization

### DAT

```matlab
addpath("Lib");
visualizeDatLabelGroups( ...
    "result/remapped_baseline.dat", ...
    {10, 20, 31, 32, 33}, ...
    "GroupNames", ["outer", "inner", "large sphere", ...
        "small sphere", "small cube"], ...
    "Alphas", [0.08 0.12 0.18 0.95 0.95]);
```

Additional DAT plotting functions:

- `plotDatLabels`
- `plotDatMaterialLabels`
- `visualizeDatLabelGroups`

### GiD MSH

```matlab
addpath("Lib");
visualizeMshLabelGroups( ...
    "result/remapped_baseline.msh", ...
    {10, 20, 32, 33}, ...
    "GroupNames", ["outer", "inner", "small sphere", "small cube"]);
```

### Batch Figures

Set hidden figures before running `main.m`:

```matlab
figureVisibility = "off";
exampleDataMode = "load";
run("main.m");
```

PNG files are still exported to `examples/mapper/output`.

## Tests

Run the release suite:

```matlab
addpath("Lib");
run_release_tests;
```

The suite checks:

- Example generation mode
- Example load mode
- All DAT and MSH examples
- Selected source-label mapping
- Baseline-domain restriction
- DAT section preservation
- Automatic non-conflicting labels
- Baseline-label collision rejection
- Duplicate output-label rejection
- DAT coordinate translation helper

Benchmark serial, MEX, and thread-worker configurations:

```matlab
addpath("Lib");
results = benchmarkMapperOptimization;
```

## Repository Structure

```text
main.m                         Only user-facing setup and example script
Lib/                           All MATLAB functions
Lib/remap.m                    Baseline-first mapping API
Lib/meshingMapper.m            Format dispatch and configuration
Lib/generateExampleMeshes.m    Example fixture generator
Lib/resolveExampleMeshes.m     Load/generate example-data resolver
Lib/run_release_tests.m        Release test entry point
Lib/benchmarkMapperOptimization.m
mex/                           Optional C++ point-location fallback
examples/mapper/data/            Committed DAT and MSH fixtures
examples/mapper/output/          Ignored generated outputs and figures
```
