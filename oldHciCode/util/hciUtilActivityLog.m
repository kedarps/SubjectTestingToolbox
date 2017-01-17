function varargout = hciUtilActivityLog(id, description)

filename = fullfile(hciUtilSubjectDataDir(id),'activity.csv');

if ~exist(filename,'file');
    % First entry, create databse
    fid = fopen(filename,'w');
    
    fileHeaders = {'date','description'};
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

activityCell = {datestr(now,'yyyymmddHHMMSS') description};

for iField = 1:length(activityCell)
    fprintf(fid,'%s',activityCell{iField});
    if iField < length(activityCell)
        fprintf(fid,',');
    end
end
fprintf(fid,'\n');

fclose(fid);

varargout = {};
if nargout
    newEntry.date = activityCell{1};
    newEntry.description = activityCell{2};
    varargout = {newEntry};
end