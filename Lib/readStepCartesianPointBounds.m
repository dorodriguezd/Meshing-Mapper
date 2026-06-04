function bounds = readStepCartesianPointBounds(stepFile)
%READSTEPCARTESIANPOINTBOUNDS Estimate geometry bounds from STEP points.
%
%   bounds = READSTEPCARTESIANPOINTBOUNDS(stepFile) reads CARTESIAN_POINT
%   entries from a STEP file and returns the point count, axis-aligned
%   bounds, center, and radii. This is intended as a lightweight geometry
%   summary for selecting/validating a meshed domain.

stepFile = char(stepFile);
if exist(stepFile, 'file') ~= 2
    error('readStepCartesianPointBounds:MissingFile', ...
        'STEP file not found: %s', stepFile);
end

text = fileread(stepFile);
tokens = regexp(text, ...
    'CARTESIAN_POINT\(''[^'']*'',\(([-+0-9.Ee, ]+)\)\)', ...
    'tokens');
if isempty(tokens)
    error('readStepCartesianPointBounds:NoCartesianPoints', ...
        'No CARTESIAN_POINT entries were found in %s.', stepFile);
end

points = zeros(numel(tokens), 3);
for pointIndex = 1:numel(tokens)
    point = sscanf(tokens{pointIndex}{1}, '%f,%f,%f').';
    if numel(point) ~= 3
        error('readStepCartesianPointBounds:BadCartesianPoint', ...
            'Could not parse CARTESIAN_POINT %d in %s.', pointIndex, stepFile);
    end
    points(pointIndex, :) = point;
end

bounds = struct();
bounds.file = stepFile;
bounds.pointCount = size(points, 1);
bounds.min = min(points, [], 1);
bounds.max = max(points, [], 1);
bounds.center = (bounds.min + bounds.max) / 2;
bounds.radii = (bounds.max - bounds.min) / 2;
end
