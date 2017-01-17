function subjectIds = hciUtilGetSubjectIds

rootSubjDir = hciUtilSubjectDataDir;
dirContents = dir(rootSubjDir);

potentials = dirContents(cat(1,dirContents.isdir));

isOk = false(length(potentials),1);
for iDir = 1:length(potentials)
    isOk(iDir) = exist(fullfile(rootSubjDir,potentials(iDir).name,'info.yaml'),'file');
end

subjDirs = potentials(isOk);

subjectIds = sort({subjDirs.name})'; % Make it alphabetical