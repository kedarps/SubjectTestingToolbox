classdef hciSubject < hgsetget
    
    properties % Map is the only public property
        map
        
        verboseText = false;
        
        mapDeviceStimulationFailureCallback = [];
    end
    
    properties (SetAccess = 'protected')
        id
        displayName
        
        mapFileNameInitial
        mapFileNameDefault
        mapFileNameCurrent
        
        mapsDatabase
        activityDatabase
        results = repmat(hciResults,0,1);
    end
    
    methods
        function self = hciSubject(id,mapDeviceStimulationFailureCallback)
            
            self.id = id;
            if nargin > 1
                self.mapDeviceStimulationFailureCallback = mapDeviceStimulationFailureCallback;
            end
                
            init(self);
        end
        
        function init(self)
            assert(~isempty(self.id),'id must be specified');
            
            readSubjectInfo(self);
            
            self.mapsDatabase = hciUtilReadSubjectMapDatabse(self.id);
            
            self.activityDatabase = hciUtilReadSubjectActivity(self.id);
            
            self.results = hciUtilReadResults(self.id);
            
            % Read current map
            % To start out we read their current map
            resetMap(self)
        end
        
        function readSubjectInfo(self)
            % Read info from yaml file
            infoFromFile = hciUtilReadSubjectInfo(self.id);
            self.displayName = infoFromFile.displayName;
            self.mapFileNameInitial = infoFromFile.initialMapFilename;
            self.mapFileNameDefault = infoFromFile.defaultMapFilename;
            self.mapFileNameCurrent = infoFromFile.currentMapFilename;
        end
        
        function resetMap(self)
            self.map = hciMap(self.mapFileNameCurrent);
            self.map.deviceStimulationFailureCallback = self.mapDeviceStimulationFailureCallback;
        end
        
        function deleteMaps(self, mapsToDelete)
            
            maps = self.mapsDatabase;
            mapsFileNames = {maps.filename}';
            
            cannotBeDelete = false(size(mapsToDelete));
            mapsDbRowsToDelete = [];
            for iMap = 1:length(mapsToDelete)
                cMapInd = find(strcmpi(mapsToDelete(iMap).filename, mapsFileNames));
                
                isInit = strcmpi(mapsToDelete(iMap).filename,self.mapFileNameInitial);
                isDefault = strcmpi(mapsToDelete(iMap).filename,self.mapFileNameDefault); 
                isCurrent = strcmpi(mapsToDelete(iMap).filename,self.mapFileNameCurrent); 
                
                if isCurrent || isInit || isDefault
                    cannotBeDelete(iMap) = true;
                    continue
                end
                
                mapsDbRowsToDelete = cat(1,mapsDbRowsToDelete(:), cMapInd(:));
            end
            
            
            if any(cannotBeDelete)
                
                mapsToDeleteFileNames = {mapsToDelete.filename}';
                [~, justCannotDeleteFileNames] = cellfun(@fileparts,mapsToDeleteFileNames(cannotBeDelete),'uniformOutput',false);
            
                msg = sprintf('The following maps cannot be deleted because they are in use.\n%s',justCannotDeleteFileNames{:});
                msgH = msgbox(msg, 'Issues with Deleting.','warn','modal');
                waitfor(msgH);
            end
            
            if all(cannotBeDelete)
                return
            end
            
            % Open up the CSV File and read
            fid = fopen(fullfile(hciUtilSubjectDataDir(self.id),'maps.csv'));
            mapFileCell = textscan(fid,'%q','Delimiter',',','EndOfLine','\n');
            mapFileCell = mapFileCell{1};
            mapFileCell = reshape(mapFileCell,[],4)';
            fclose(fid);
            
            % Remove the rows and delete the files
            mapFileCell(mapsDbRowsToDelete+1,:) = [];
            for iMap = 1:length(mapsDbRowsToDelete)
                cMapInd = mapsDbRowsToDelete(iMap);
                delete(mapsFileNames{cMapInd});
            end
            
            % Rewrite the file
            fid = fopen(fullfile(hciUtilSubjectDataDir(self.id),'maps.csv'),'w');
            for iRow = 1:size(mapFileCell,1)
                for iCol = 1:size(mapFileCell,2)
                    fprintf(fid, '%s', mapFileCell{iRow, iCol});
                    if iCol ~= size(mapFileCell,2)
                        fprintf(fid, ',');
                    else
                        fprintf(fid, '\n');
                    end
                end
            end
            fclose(fid);
            
            % Log the deletions
            for iMap = 1:length(mapsDbRowsToDelete)
                cMap = maps(mapsDbRowsToDelete(iMap));
                
                logActivity(self, sprintf('Deleted map %s.',cMap.name));
            end
            
            
            % Reload the maps databse
            self.mapsDatabase = hciUtilReadSubjectMapDatabse(self.id);
            
        end
        
        function importMap(self, mapFileToImport, mapName, description)
            
            mapFileName = fullfile(hciUtilMapStorageDir(self.id),hciUtilMapFileName(mapName));
            
            copyfile(mapFileToImport, mapFileName);
            
            newEntry = hciUtilMapLog(self.id, mapFileName, mapName, description); % Log the map file
            self.mapsDatabase = cat(1,self.mapsDatabase,newEntry); % Keep the current DB up to date.
            
            logActivity(self, sprintf('Import of map (%s) completed and named %s', mapFileToImport, mapName)); % Log this as an activity
        end
        
        function saveAndLogCurrentMap(self, mapName, description)
            mapFileName = fullfile(hciUtilMapStorageDir(self.id),hciUtilMapFileName(mapName));
            
            self.map.saveMap(mapFileName); % Save the map file. 
            newEntry = hciUtilMapLog(self.id, mapFileName, mapName, description); % Log the map file
            self.mapsDatabase = cat(1,self.mapsDatabase,newEntry); % Keep the current DB up to date.
            
            self.mapFileNameCurrent = mapFileName;
            saveSubjectInfo(self);
            
            logActivity(self, sprintf('New map (%s) saved', mapName)); % Log this as an activity
        end

        function saveErrorStructure(self)
            fileName = hciUtilErrorFileName();
            fullFileName = fullfile(hciUtilSubjectDataDir(self.id),'errorLogs',fileName);
            
            self.map.saveError(fullFileName);
        end

        function logActivity(self, description)
            newEntry = hciUtilActivityLog(self.id, description); % Log the activity
            
            self.activityDatabase = cat(1,self.activityDatabase,newEntry); % Keep the current DB up to date.
            
            if self.verboseText
                disp(description);
            end
        end
        
        function logResults(self, results)
            fileName = hciUtilResultsFileName(results.type);
            fullFileName = fullfile(hciUtilSubjectDataDir(self.id),'results',fileName);
            
            saveStruct = results.results;
            saveStruct.type = results.type;
            
            prtExternal.yaml.WriteYaml(fullFileName, saveStruct);
            
            self.results = cat(1,self.results,results);
            
            logActivity(self, sprintf('Results for %s saved to %s',results.type, fileName))
        end
        
        function setDisplayName(self, val)
            self.displayName = val;
            saveSubjectInfo(self)
            
            logActivity(self, sprintf('Subject display name changed to (%s)', val))
        end
        
        function setDefaultMapToBeTheCurrent(self)
            self.mapFileNameCurrent = self.mapFileNameDefault;
            saveSubjectInfo(self);
            resetMap(self);
            
            logActivity(self, sprintf('Loaded default map (%s).', self.mapFileNameCurrent))
        end
        
        function setCurrentMapToBeTheDefault(self)
            self.mapFileNameDefault = self.mapFileNameCurrent;
            saveSubjectInfo(self);
            resetMap(self);
            
            logActivity(self, sprintf('Set current map (%s) as the default map.', self.mapFileNameCurrent))
        end
        
        function setInitialMapToBeTheCurrent(self)
            self.mapFileNameCurrent = self.mapFileNameInitial;
            saveSubjectInfo(self);
            resetMap(self);
            
            logActivity(self, sprintf('Loaded initial map (%s).', self.mapFileNameCurrent))
        end
        
        function saveSubjectInfo(self)
            hciUtilSaveSubjectInfo(self.id, self.displayName, self.mapFileNameInitial, self.mapFileNameDefault, self.mapFileNameCurrent);
        end
        
        function loadMapFromDatabaseEntry(self, dbEntry)
            self.mapFileNameCurrent = dbEntry.filename;
            saveSubjectInfo(self);
            resetMap(self);
            
            logActivity(self, sprintf('Loaded map (%s).', self.mapFileNameCurrent))
        end
    end
end