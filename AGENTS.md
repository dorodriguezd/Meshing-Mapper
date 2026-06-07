# Meshing-Mapper Project Context

This file applies to the entire repository. Keep it current when the public
workflow, label rules, performance guidance, validation, or repository layout
changes.

## Scope

Meshing-Mapper transfers labeled tetrahedral volumes from a source DAT or GiD
MSH mesh onto a baseline mesh. Baseline coordinates and connectivity are
preserved; selected baseline element labels are replaced.

Rigid mesh translation and rotation belong in the separate repository:

```text
https://github.com/dorodriguezd/Mesh_Transformer
```

## Public Layout

- `main.m` is the only MATLAB file at the repository root and the only setup
  script intended for direct user interaction.
- Every MATLAB function is under `Lib/`.
- `examples/mapper/data/` contains small committed DAT and MSH fixtures.
- `examples/mapper/output/` contains ignored generated outputs and figures.
- `mex/` contains the optional C++ point-location source.
- `backup/` is local-only and must not be committed.

Start the examples from the repository root:

```matlab
run("main.m");
```

For direct API use:

```matlab
addpath("Lib");
result = remap(baselineFile, sourceFile, setup);
```

## Mapping Rules

- `InputLabels` selects source labels; omission selects all source labels.
- `TargetLabels` selects baseline labels eligible for replacement; omission
  searches the full baseline.
- `NewLabels` controls output labels. Explicit labels must be unique and must
  not already exist in the baseline.
- When `NewLabels` is omitted, labels are assigned consecutively above the
  maximum baseline label.
- Duplicate explicit output labels or collisions with baseline labels fail
  before output is written.
- DAT output preserves unrelated target sections and appends mapped material
  rows.

## Example Geometry

- Homogeneous baseline: `5 x 5 x 5 cm`.
- Layered baseline: outer `5 cm` cube and denser inner `4 cm` cube.
- Source cases: centered `3 cm` sphere, plus non-overlapping `1 cm` sphere
  and `0.5 cm` cube.
- `main.m` demonstrates DAT and MSH mapping, selected labels, selected
  baseline subdomains, visualization, serial execution, parallel execution,
  and optional MEX use.
- Set `exampleDataMode="load"` to use committed fixtures or `"generate"` to
  recreate them.

## Optimization

Validated machine guidance from the 2026-06-07 benchmark:

- Small mappings: serial with `UseMex=true`.
- Large mappings: reuse a 32-worker process pool with
  `UseParallel=true`, `ParallelPoolType="processes"`,
  `ParallelWorkers=32`, and `UseMex=true`.
- Start production `ChunkSize` around `100000` to `250000` and benchmark.
- Do not default to 64 workers; it was slower in the measured small case.
- Build MEX locally after MATLAB, compiler, OS, or architecture changes.

The MEX helper accelerates the brute-force fallback locator. It does not
replace MATLAB's primary `triangulation/pointLocation` path. Thread workers
cannot invoke this helper; use process workers for strict parallel plus MEX.

## Validation

After mapper changes:

```matlab
addpath("Lib");
run_release_tests;
```

The release suite covers generated and committed examples, DAT and MSH
mapping, subdomain restrictions, section preservation, label collision
protection, optimization configuration, and DAT translation.

Repeat the local optimization benchmark with:

```matlab
addpath("Lib");
results = benchmarkMapperOptimization;
```

Run `checkcode` on edited MATLAB files and inspect at least one generated
visualization when mapping or plotting behavior changes.

## Git Policy

- Preserve user changes and deletions.
- Do not commit generated DAT, PNG, FIG, MEX, output, or backup content.
- Inspect `git status` before staging.
- Update this file when repository conventions or validated behavior changes.
