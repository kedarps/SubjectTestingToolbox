function results = hciUtilReadResults(id)

resDir = fullfile(hciUtilSubjectDataDir(id),'results');

yamlFiles = dir(fullfile(resDir,'*.yaml'));

results = repmat(hciResults,0,1); % Empty hciResults array

for iFile = 1:length(yamlFiles)
    cFile = fullfile(resDir,cat(2,yamlFiles(iFile).name));

    cStruct = prtExternal.yaml.ReadYaml(cFile);
    
    cResults = hciResults('type',cStruct.type,'results',rmfield(cStruct,'type'));
    
    results = cat(1,results, cResults);
end