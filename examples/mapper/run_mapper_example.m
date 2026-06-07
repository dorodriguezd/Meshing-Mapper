%RUN_MAPPER_EXAMPLE Run every documented mapper example.

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
figureVisibility = 'on';
exampleDataMode = "load";
run(fullfile(repoRoot, 'main.m'));
