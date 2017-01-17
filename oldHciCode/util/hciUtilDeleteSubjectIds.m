function hciUtilDeleteSubjectIds(ids)

rootSubjDir = hciUtilSubjectDataDir;

if ischar(ids)
    ids = cellstr(ids);
end

for iId = 1:length(ids)
    if isdir(fullfile(rootSubjDir,ids{iId}))
        rmdir(fullfile(rootSubjDir,ids{iId}),'s');
    end
end