function varargout = hciUtilMapLog(id, mapFilename, mapName, description)

filename = fullfile(hciUtilSubjectDataDir(id),'maps.csv');

if ~exist(filename,'file');
    % First entry, create databse
    fid = fopen(filename,'w');
    
    fileHeaders = {'filename','date','name','description'};
    for iHeader = 1:length(fileHeaders)
        fprintf(fid,'%s',fileHeaders{iHeader});
        if iHeader < length(fileHeaders)
            fprintf(fid,',');
        end
    end
    fprintf(fid,'\n');
    
else
    fid = fopen(filename,'a'); % Open
end

mapInfoCell = {mapFilename, datestr(now,'yyyymmddHHMMSS') ,mapName, description};

for iField = 1:length(mapInfoCell)
    fprintf(fid,'%s',mapInfoCell{iField});
    if iField < length(mapInfoCell)
        fprintf(fid,',');
    end
end
fprintf(fid,'\n');

fclose(fid);

varargout = {};
if nargout
    newEntry.filename = mapInfoCell{1};
    newEntry.date = mapInfoCell{2};
    newEntry.name = mapInfoCell{3};
    newEntry.description = mapInfoCell{4};
    
    varargout = {newEntry};
end