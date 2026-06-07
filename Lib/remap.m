function result = remap(baseline, source, setup)
%REMAP Transfer selected source labels onto selected baseline subdomains.
%
%   result = REMAP(baseline, source)
%   result = REMAP(baseline, source, setup)
%
%   baseline and source are DAT or GiD MSH file paths. The baseline mesh
%   keeps its coordinates and connectivity. setup is an optional scalar
%   struct using the fields documented for meshingMapper, including:
%       InputLabels   source labels to transfer
%       NewLabels     labels written to the output baseline
%       TargetLabels  baseline labels where replacement is allowed
%       UseParallel   enable DAT chunk-level parallel execution
%       ParallelPoolType
%                     "auto", "threads", or "processes"
%       ParallelWorkers
%                     worker count used when creating a parallel pool
%       UseMex        true, false, or "auto" for the DAT fallback locator
%       BuildMex      compile a temporary compatible MEX before mapping
%       MexRequired   fail instead of using the MATLAB fallback
%       MexVerbose    print verbose MEX compiler output

if nargin < 3 || isempty(setup)
    setup = struct();
end
if ~isstruct(setup) || ~isscalar(setup)
    error('remap:InvalidSetup', 'setup must be one scalar struct.');
end

config = setup;
config.BaselineFile = char(string(baseline));
config.SourceFile = char(string(source));
config.TargetFile = config.BaselineFile;
result = meshingMapper(config);
end
