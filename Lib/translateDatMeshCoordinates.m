function info = translateDatMeshCoordinates(inputDatFile, outputDatFile, translationVector)
%TRANSLATEDATMESHCOORDINATES Translate DAT coordinates and preserve all else.
%
%   info = TRANSLATEDATMESHCOORDINATES(inputDatFile, outputDatFile, vector)
%   adds the three-component vector to every coordinate. Connectivity,
%   labels, material properties, and unrelated DAT sections are copied
%   unchanged. This narrow helper supports Meshing-Mapper sensitivity
%   workflows. General DAT/MSH rotation and translation belongs to:
%   https://github.com/dorodriguezd/Mesh_Transformer

if ~(isnumeric(translationVector) && numel(translationVector) == 3 && ...
        all(isfinite(translationVector(:))))
    error('translateDatMeshCoordinates:InvalidTranslation', ...
        'translationVector must contain three finite numeric values.');
end
translationVector = double(translationVector(:).');

rawLines = readTextLines(inputDatFile);
coordinatesLine = findSection(rawLines, 'Coordinates', inputDatFile);
endCoordinatesLine = findSection(rawLines, 'end Coordinates', inputDatFile);
coordinateCount = parseCount(rawLines{coordinatesLine + 1}, ...
    'Coordinates', inputDatFile);
nodes = parseCoordinates(rawLines, coordinatesLine + 2, ...
    coordinateCount, inputDatFile);
translatedNodes = nodes + translationVector;

outputFolder = fileparts(outputDatFile);
if ~isempty(outputFolder) && exist(outputFolder, 'dir') ~= 7
    mkdir(outputFolder);
end
writeTranslatedDat(outputDatFile, rawLines, coordinatesLine, ...
    endCoordinatesLine, translatedNodes);

info = struct();
info.inputMeshFile = char(inputDatFile);
info.outputMeshFile = char(outputDatFile);
info.numberOfNodes = coordinateCount;
info.translationVector = translationVector;
info.originalBoundingBox = [min(nodes, [], 1); max(nodes, [], 1)];
info.transformedBoundingBox = [min(translatedNodes, [], 1); ...
    max(translatedNodes, [], 1)];
end

function rawLines = readTextLines(fileName)
fid = fopen(fileName, 'r');
if fid < 0
    error('translateDatMeshCoordinates:OpenFailed', ...
        'Could not open file: %s', fileName);
end
cleanup = onCleanup(@() fclose(fid));
rawLines = {};
line = fgetl(fid);
while ischar(line)
    rawLines{end + 1, 1} = line; %#ok<AGROW>
    line = fgetl(fid);
end
end

function lineNumber = findSection(rawLines, sectionName, fileName)
lineNumber = find(strcmpi(strtrim(rawLines), sectionName), 1, 'first');
if isempty(lineNumber)
    error('translateDatMeshCoordinates:MissingSection', ...
        'Could not find "%s" in %s.', sectionName, fileName);
end
end

function count = parseCount(line, sectionName, fileName)
count = sscanf(strtrim(line), '%d', 1);
if isempty(count) || count < 0
    error('translateDatMeshCoordinates:BadCount', ...
        'Invalid %s count in %s.', sectionName, fileName);
end
end

function nodes = parseCoordinates(rawLines, startLine, count, fileName)
nodes = zeros(count, 3);
for row = 1:count
    values = sscanf(strtrim(rawLines{startLine + row - 1}), '%f').';
    if numel(values) < 3 || any(~isfinite(values(1:3)))
        error('translateDatMeshCoordinates:BadCoordinate', ...
            'Invalid coordinate row %d in %s.', row, fileName);
    end
    nodes(row, :) = values(1:3);
end
end

function writeTranslatedDat(fileName, rawLines, coordinatesLine, ...
    endCoordinatesLine, nodes)
fid = fopen(fileName, 'w');
if fid < 0
    error('translateDatMeshCoordinates:WriteFailed', ...
        'Could not write file: %s', fileName);
end
cleanup = onCleanup(@() fclose(fid));

for index = 1:(coordinatesLine - 1)
    fprintf(fid, '%s\n', rawLines{index});
end
fprintf(fid, 'Coordinates\n%9d\n', size(nodes, 1));
fprintf(fid, '%16.9f %16.9f %16.9f\n', nodes.');
fprintf(fid, 'end Coordinates\n');
for index = (endCoordinatesLine + 1):numel(rawLines)
    fprintf(fid, '%s\n', rawLines{index});
end
end
