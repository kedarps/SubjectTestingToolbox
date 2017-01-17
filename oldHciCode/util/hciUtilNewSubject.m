function hciUtilNewSubject(id, displayName, initMap)
% hciUtilNewSubject('test', 'Testy McTester', 'C:\Users\KDM\Documents\New Folder\MATLAB\hci\subjects\maps\XYmap.mat')

assert(ischar(id),'id must be a string');
assert(ischar(displayName),'displayName must be a string');
assert(ischar(initMap) && exist(initMap,'file'),'initMap must be a string specifying a map saved in a mat file.');

newSubjectDir = hciUtilSubjectDataDir(id);
if ~isdir(newSubjectDir)
    mkdir(newSubjectDir)
else
    error('hci:hciUtilNewSubject:idInUse','The specified subject id (%s) may already be in use. Please specify another id', id);
end

% Create the maps directory and copy the original map into the directory.
mapsDir = fullfile(newSubjectDir, 'maps');
mkdir(mapsDir);

mapFileName = fullfile(mapsDir,hciUtilMapFileName('initial'));
copyfile(initMap,mapFileName);

% Create the initial maps databse file
hciUtilMapLog(id, mapFileName, 'initial', 'Initial map when subject first used the program.');

% Cretae the initial activity database file
hciUtilActivityLog(id, 'Subject profile created.');

% Create the subject file
hciUtilSaveSubjectInfo(id, displayName, mapFileName, mapFileName, mapFileName);

% Create the subject results
mkdir(fullfile(newSubjectDir,'results'));

% Create a place to save potential error logs
mkdir(fullfile(newSubjectDir,'errorLogs'));

