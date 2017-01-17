classdef hciTaskImportMap < hciTask
    properties
        id = 'mapImport';
        
        listDlgObj
        overlayPanel
        
        isAdminSubTask = false;
    end
    methods
        function self = hciTaskImportMap(varargin)
            self = prtUtilAssignStringValuePairs(self, varargin{:});
            
            if ~self.hgIsValid
                create(self);
            end
            
            init(self);
        end
        
        function init(self)
            
            s.MapName = 'Enter a name for this MAP';
            s.MapFile = '#<file>Select a MAP MAT File to import';
            s.Description = 'Enter a description for this MAP';
            
            done = false;
            while ~done
                dataInputObj = prtUiStructDlg('inputStruct',s,'managedHandle',self.managedHandle,...
                    'uiFontSize',16,'uitextheight',25,'uiheightunit',50,'dyunit',10,'uibuttonwidth',100,'uibuttonheight',40,'uisidebuttonwidth',50);
                
                % Check inputs
                newS = dataInputObj.outputStruct;
                
                if isequal(newS,s)
                    % User Cancel
                    if self.isAdminSubTask
                        self.isSubTask = true;
                    end
                    exit(self);
                    return
                end
                
                done = true;
            end
            
            importMap(self.subject, newS.MapFile, newS.MapName, newS.Description)

            
            if ~self.isAdminSubTask
                self.motherApp.message('The map has been imported.',sprintf('The map <b>%s</b> has been imported.',newS.MapName));
            else
                self.isSubTask = true;
            end
            exit(self);

        end
    end
end