function mapsDb = hciUtilReadSubjectMapDatabse(id)

fid = fopen(fullfile(hciUtilSubjectDataDir(id),'maps.csv'));
mapFileCell = textscan(fid,'%q','Delimiter',',','EndOfLine','\n');
fclose(fid);

mapFileCell = reshape(mapFileCell{1},4,[])'; % We know there are 4 fields

structInputs = cell(1,8);
structInputs(1:2:end) = mapFileCell(1,:);

mapsDb = repmat(struct(structInputs{:}),size(mapFileCell,1)-1,1);

fnames = mapFileCell(1,:);

for iEntry = 1:size(mapsDb,1)
    for iField = 1:length(fnames)
        mapsDb(iEntry).(fnames{iField}) = mapFileCell{iEntry+1,iField};
    end
end
