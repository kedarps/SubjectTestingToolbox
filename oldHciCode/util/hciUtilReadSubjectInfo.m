function info = hciUtilReadSubjectInfo(id)

infoFile = fullfile(hciUtilSubjectDataDir(id),'info.yaml');
info = prtExternal.yaml.ReadYaml(infoFile);