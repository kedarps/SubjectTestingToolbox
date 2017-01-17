classdef hciTaskSelectMap < hciTask
    properties
        id = 'mapSelect';
        
        listDlgObj
        overlayPanel
        
        isAdminSubTask = false;
    end
    methods
        function self = hciTaskSelectMap(varargin)
            self = prtUtilAssignStringValuePairs(self, varargin{:});
            
            if ~self.hgIsValid
                create(self);
            end
            
            init(self);
        end
        
        function init(self)
            self.listDlgObj = prtUiListDlg('managedHandle',self.managedHandle,...
                'inputStruct',self.subject.mapsDatabase,...
                'titleStr','Select a Map.',...
                'messageStr','Select a Map');

            selected = self.listDlgObj.enteredSelection;
            if isempty(selected) || all(selected ==0)
                if self.isAdminSubTask
                    self.isSubTask = true;
                end
                exit(self);
                return;
            end
            
            selectedEntry = self.subject.mapsDatabase(selected);
            loadMapFromDatabaseEntry(self.subject, selectedEntry);
            
            if ~self.isAdminSubTask
                self.motherApp.message('Your map has been changed.',sprintf('Your current map has been set to<br><b>%s</b>.',selectedEntry.name));
            else
                self.isSubTask = true;
            end
            exit(self);

        end
    end
end