function activityDb = hciUtilReadSubjectActivity(id)

fid = fopen(fullfile(hciUtilSubjectDataDir(id),'activity.csv'));
activityCell = textscan(fid,'%q','Delimiter',',','EndOfLine','\n');
fclose(fid);

activityCell = reshape(activityCell{1},2,[])'; % We know there are 2 fields, date and description

structInputs = cell(1,4);
structInputs(1:2:end) = activityCell(1,:);

activityDb = repmat(struct(structInputs{:}),size(activityCell,1)-1,1);

fnames = activityCell(1,:);

for iEntry = 1:size(activityDb,1)
    for iField = 1:length(fnames)
        activityDb(iEntry).(fnames{iField}) = activityCell{iEntry+1,iField};
    end
end