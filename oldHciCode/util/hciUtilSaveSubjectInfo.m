function hciUtilSaveSubjectInfo(id, displayName, initialMapFilename, defaultMapFilename, currentMapFilename)

subjectInfo.id = id;
subjectInfo.displayName = displayName;
subjectInfo.initialMapFilename = initialMapFilename;
subjectInfo.defaultMapFilename = defaultMapFilename;
subjectInfo.currentMapFilename = currentMapFilename;

infoFileName = fullfile(hciUtilSubjectDataDir(id),'info.yaml');

prtExternal.yaml.WriteYaml(infoFileName, subjectInfo);