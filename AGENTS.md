# Meshing-Mapper Project Context

This file applies to the entire repository. Keep it updated when a validated
workflow, label convention, required input, performance result, or Git
milestone changes. Its purpose is to let Codex sessions on different machines
continue the project without reconstructing the full history.

## Project Goal

Meshing-Mapper is a MATLAB project for transferring labeled 3D tetrahedral
volumes from a source mesh to a target mesh.

The principal file format is a custom problem-type `.dat` format containing
sections such as:

- `Coordinates`
- `Elements`
- `Material properties`
- Additional solver/problem sections that must be preserved verbatim

The target mesh topology and coordinates are retained. Only target element
material labels are changed, and new material-property rows are appended for
the mapped source tissues.

Mesh coordinates in the current head workflows are expressed in meters.

## Shared Git Status

Status recorded on 2026-06-06:

- Remote: `https://github.com/dorodriguezd/Meshing-Mapper.git`
- Primary branch: `master`
- Validated implementation milestone before this context file: `4868a7a`
- Milestone title: `Add translated head remap sensitivity workflow`
- Visualization baseline tag: `baseline-visual-label-groups`
- Baseline tag commit: `c705d37`
- There are currently no shared long-lived branches other than `master`.

The baseline tag is a read-only reference point. Continue new work from
`master`, normally on a branch named `codex/<topic>`.

Recommended startup:

```powershell
git fetch --all --prune --tags
git switch master
git pull --ff-only
git status --short --branch
git switch -c codex/<topic>
```

Do not develop while checked out at the baseline tag because that produces a
detached HEAD and predates the parallel/MEX additions.

## Required Large Data

Large DAT meshes and generated figures are intentionally ignored by Git. A
fresh clone is not sufficient to run the main workflows.

Copy these required files from another project machine or shared storage while
preserving their relative paths:

```text
input/head_finer.dat
input/mesh_base.dat
```

Accepted current aliases:

```text
input/mesh__head.dat
input/mesh__baseline.dat
```

Generated inputs that can be copied or regenerated:

```text
input/head_finer_1mm_zUP.dat
input/head_finer_1mm_zDOWN.dat
```

Important generated outputs may be copied to avoid lengthy recomputation:

```text
result/base_finer/mesh_base_with_head_finer.dat
result/base_finer_translations/mesh_base_with_head_finer_1mm_zUP.dat
result/base_finer_translations/mesh_base_with_head_finer_1mm_zDOWN.dat
result/base_finer/**/*.png
result/base_finer/**/*.fig
result/base_finer_translations/**/*.png
result/base_finer_translations/**/*.fig
```

Do not copy a compiled MEX binary between machines unless the MATLAB release,
operating system, architecture, and compiler ABI are known to match. Rebuild
it locally instead.

## Current Head Mapping Definition

The source `head_finer.dat` contains five tissue labels:

| Source label | Tissue | Output label on `mesh_base.dat` |
|---:|---|---:|
| 1 | gray | 25 |
| 2 | CSF | 26 |
| 3 | FAT | 27 |
| 4 | SKIN | 28 |
| 5 | SKULL | 29 |

The current base/finer target search domain is:

```matlab
primaryTargetLabels = 20:24;
surfaceTargetLabels = 19;
mappingTargetLabels = [primaryTargetLabels, surfaceTargetLabels];
surfaceSearchDistance = 0.01; % 1 cm
```

The conservative workflow uses:

1. Target-element centroid containment in the source mesh.
2. Source-element centroid repair into the selected target domain.
3. A 1 cm source-surface distance filter for target label 19.

Neighbor-based hole repair and `HoleRepairTargetLabel` filling are disabled in
the validated base/finer workflow. Do not silently re-enable them because
previous runs showed sparse labels outside the source tissue volumes.

If target labels are not supplied to `mapDatMeshLabels`, it searches the full
target domain.

## Main Workflows

### Baseline Base/Finer Mapping

```powershell
matlab -batch "addpath('workflows/head'); main_head_mapping('map')"
matlab -batch "addpath('workflows/head'); main_head_mapping('check')"
matlab -batch "addpath('workflows/head'); main_head_mapping('visualize')"
```

Primary output:

```text
result/base_finer/mesh_base_with_head_finer.dat
```

The SKIN/antenna validation groups are:

```matlab
labelGroups = {28, 3:18};
legendNames = ["SKIN", "Antennas"];
```

Labels 3 through 18 are plotted as one transparent antenna group.

### Translation Sensitivity

`workflows/head/build_head_finer_translation_sensitivity.m` creates and maps:

```text
head_finer_1mm_zUP.dat    translation [0 0  0.001] m
head_finer_1mm_zDOWN.dat  translation [0 0 -0.001] m
head_finer_2mm_zDOWN.dat  translation [0 0 -0.002] m
```

Both translated sources are mapped onto `input/mesh_base.dat`, not onto
`head_finer.dat`. This preserves the base-mesh/antenna validation context.

Full run:

```powershell
matlab -batch "addpath('workflows/head'); build_head_finer_translation_sensitivity"
```

Run or resume one case:

```powershell
matlab -batch "addpath('workflows/head'); setenv('HEAD_TRANSLATION_CASES','1mm_zUP'); setenv('HEAD_TRANSLATION_COMPILE_MEX','false'); build_head_finer_translation_sensitivity"

matlab -batch "addpath('workflows/head'); setenv('HEAD_TRANSLATION_CASES','1mm_zDOWN'); setenv('HEAD_TRANSLATION_COMPILE_MEX','false'); build_head_finer_translation_sensitivity"
```

Add `workflows/head` to the MATLAB path before calling the moved script.
The release-facing entry point checks required inputs and tracked reports by
default. Use the `validate` action only when ignored remapped DAT files have
been copied locally:

```powershell
matlab -batch "addpath('workflows/head'); main_head_translation('check')"
matlab -batch "addpath('workflows/head'); main_head_translation('validate')"
```

The 2 mm downward remap is explicit because it is expensive:

```powershell
matlab -batch "addpath('workflows/head'); main_head_translation('map-2mm-down')"
```

Supported environment controls:

| Variable | Default | Meaning |
|---|---|---|
| `HEAD_TRANSLATION_CASES` | empty | Comma-separated cases to run |
| `HEAD_TRANSLATION_USE_PARALLEL` | true | Enable parallel chunks |
| `HEAD_TRANSLATION_COMPILE_MEX` | true | Build optional MEX first |
| `HEAD_TRANSLATION_SKIP_COMPLETED` | true | Skip cases with all outputs |

Results are saved under:

```text
result/base_finer_translations/
```

## Validated Translation Results

Both translated remapped DAT files passed coordinate, element, material-count,
numeric-block, and label-count syntax validation.

### 1 mm Z Up

- Mapping time: `4038.365 s`
- Located source elements: `2,126,409`
- Unlocated source elements: `0`
- Repaired target elements: `1,778,913`
- SKIN label 28 target elements: `1,373,120`

### 1 mm Z Down

- Mapping time: `4628.073 s`
- Located source elements: `2,126,409`
- Unlocated source elements: `0`
- Repaired target elements: `1,778,895`
- SKIN label 28 target elements: `1,437,349`

The detailed counts and file validation results are tracked in:

```text
result/base_finer_translations/*_summary.txt
result/base_finer_translations/*_validation.txt
result/base_finer_translations/*_label_log.txt
```

## Core Library

Important functions:

| File | Purpose |
|---|---|
| `Lib/mapDatMeshLabels.m` | Read DAT meshes, map labels, write DAT/log |
| `Lib/translateDatMeshCoordinates.m` | Narrow DAT translation helper for sensitivity workflows |
| `Lib/visualizeDatLabelGroups.m` | Plot grouped DAT labels |
| `Lib/plotDatMaterialLabels.m` | Plot requested individual labels |
| `Lib/plotDatLabels.m` | Resolve labels by index/name and plot |
| `Lib/buildMeshingMapperMex.m` | Compile optional C++ MEX helpers |
| `Lib/validateDatMeshFile.m` | Validate required DAT numeric blocks |
| `Lib/visualizeMshLabelGroups.m` | Plot grouped labels from GiD MSH files |
| `mex/locatePointsInTetsMex.cpp` | Fallback point-in-tetrahedron MEX |
| `meshingMapper.m` | Release-facing mapping configuration API |
| `remap.m` | Baseline-first public mapping entry point |

Release layout updated on 2026-06-07:

- `README.md` documents user workflows and options.
- `main.m` is a sectioned setup script containing DAT and GiD MSH examples.
- `examples/generateExampleMeshes.m` creates the committed centimeter-scale
  cube, layered-cube, sphere, and multi-shape fixtures.
- `examples/resolveExampleMeshes.m` supports explicit `"load"` and
  `"generate"` example-data modes.
- `examples/mapper` contains committed inputs and ignored generated outputs.
- `workflows/head` contains current project-specific entry points.
- Full DAT/MSH geometry transformation is maintained in
  `https://github.com/dorodriguezd/Mesh_Transformer`.

`mapDatMeshLabels` preserves the target file's non-coordinate/non-element
sections and rewrites material properties in the target DAT syntax. DAT syntax
validation is mandatory after mapper changes.

## Parallel and C++ Status

MATLAB R2026a with Parallel Computing Toolbox and MinGW64 was used for the
validated translation runs.

Build the optional helper on each machine:

```powershell
matlab -batch "addpath(fullfile(pwd,'Lib')); buildMeshingMapperMex"
```

The generated `mex/locatePointsInTetsMex.mexw64` is ignored by Git.

Current limitations:

- `UseParallel=true` parallelizes independent chunks.
- Public mapper settings include `ParallelPoolType`, `UseMex`, `BuildMex`,
  `MexRequired`, and `MexVerbose`.
- `BuildMex=true` compiles into a temporary folder to avoid overwriting a
  loaded Windows MEX binary.
- `UseMex="auto"` is the public mapper default. `mapDatMeshLabels` itself
  defaults to `UseMex=false` when called directly.
- DAT optimization examples in `main.m` are enabled with
  `runOptimizationExamples=true`; fresh compilation additionally requires
  `runMexBuildExample=true`.
- The current implementation tries a thread-based pool first.
- MATLAB thread workers cannot invoke this MEX helper.
- In a thread pool, each worker warns once and uses the MATLAB fallback.
- The MEX helper accelerates only the brute-force fallback locator. It does
  not replace MATLAB's main `triangulation/pointLocation` path.
- Parallel workers can increase memory pressure by broadcasting large mesh
  arrays.
- A previous full run showed very high peak memory use. Monitor RAM on new
  machines before increasing worker count or chunk size.

Optimization should be benchmark-driven. Record wall time, pool type, worker
count, chunk size, MATLAB release, and peak memory for every meaningful change.
Good next targets are DAT parsing/writing, target centroid location, and
source-centroid repair. A production C++ spatial index should replace the
current brute-force fallback before expecting major MEX speedups.

### 2026-06-07 Local Optimization Benchmark

Machine:

- 2 x Intel Xeon Gold 6338
- 64 physical cores total
- 1 TB RAM
- MATLAB R2026a Update 2
- Parallel Computing Toolbox, 64-worker local profile
- MinGW64 C++ 14.2
- Compatible `locatePointsInTetsMex.mexw64`

Benchmark case:

- `baseline_layered_cubes.dat`: 34,992 target tetrahedra
- `source_multishape.dat`: 5,520 source tetrahedra
- Three source labels mapped into target labels 10 and 20
- Parallel chunk size: 500

Measured wall times:

| Mode | Pool startup | Mapping |
|---|---:|---:|
| Serial MATLAB | 0 s | 4.790 s |
| Serial MEX enabled | 0 s | 3.292 s |
| 16 thread workers | 2.486 s | 6.038 s |
| 32 thread workers | 0.227 s | 4.234 s |
| 64 thread workers | 0.147 s | 10.610 s |
| 16 process workers + MEX | 18.299 s | 3.559 s |
| 32 process workers + MEX | 12.918 s | 3.001 s |

Recommended settings on this machine:

- Short/small mappings: serial with `UseMex=true`.
- Long production mappings: reuse a 32-worker process pool, set
  `UseParallel=true`, `ParallelPoolType="processes"`,
  `ParallelWorkers=32`, `UseMex=true`, and keep `ChunkSize` initially at
  100,000-250,000.
- Do not default to 64 workers; it was substantially slower in this benchmark.
- Use `BuildMex=false` while the compatible binary is present. Rebuild only
  after MATLAB/compiler/platform changes.

Run `tests/benchmarkMapperOptimization.m` to repeat the local benchmark.

## Validation Rules

After changing mapping or DAT writing:

1. Run MATLAB `checkcode` on edited `.m` files.
2. Run an existing small mapping test.
3. Validate coordinate, element, and material counts.
4. Parse every numeric DAT block.
5. Verify output labels and mapping counts.
6. Generate at least one visual validation.
7. Inspect the PNG, not only MATLAB's successful exit code.

Example analyzer command:

```powershell
matlab -batch "addpath(fullfile(pwd,'Lib')); files={'Lib/mapDatMeshLabels.m','Lib/visualizeDatLabelGroups.m'}; for k=1:numel(files), disp(checkcode(files{k},'-id')); end"
```

MEX smoke test:

```powershell
matlab -batch "addpath(fullfile(pwd,'Lib')); buildMeshingMapperMex; addpath(fullfile(pwd,'mex')); nodes=[0 0 0;1 0 0;0 1 0;0 0 1]; elements=[1 2 3 4]; points=[0.25 0.25 0.25;2 2 2]; idx=locatePointsInTetsMex(nodes,elements,points,1e-10); assert(idx(1)==1 && isnan(idx(2)))"
```

## Git and Artifact Policy

- Never commit large generated DAT, PNG, FIG, or machine-specific MEX files.
- Commit small text logs, summaries, and validation reports when they document
  a validated milestone.
- Do not revert unrelated working-tree changes.
- Always inspect `git status` before editing, staging, switching, or pulling.
- Stage files explicitly by path.
- Use `codex/<topic>` for new working branches.
- Merge validated work to `master` and push both the branch and `master` when
  appropriate.
- Do not force-push shared branches.
- Update this `AGENTS.md` in the same commit when project context changes.

Historical local-worktree note from the original workstation on 2026-06-06:

```text
Modified but unrelated:
  New_remap_baseline_visual_label_log.txt
  New_remap_rotated_translated_visual_label_log.txt
  plot_requested_dat_labels.m

Untracked and unrelated:
  visualize_tissues.m
```

These files were intentionally excluded from the translation workflow commit.
Treat similarly named local edits as user work unless explicitly requested.

## Cross-Machine Handoff Checklist

On a new machine:

1. Clone the repository and switch to `master`.
2. Copy required ignored DAT inputs into the exact relative folders.
3. Confirm `input/head_finer.dat` and `input/mesh_base.dat` exist.
4. Start MATLAB from the repository root.
5. Add `Lib` and `mex` to the MATLAB path as needed.
6. Configure a local C++ compiler with `mex -setup C++`.
7. Run `buildMeshingMapperMex`.
8. Run `git status` and preserve unrelated changes.
9. Read this file and the latest result summaries before modifying mapping
   behavior.
10. Create a `codex/<topic>` branch for substantial new work.

Quick verification:

```powershell
git log --oneline --decorate -5
git status --short --branch
matlab -batch "addpath(fullfile(pwd,'Lib')); buildMeshingMapperMex"
```
