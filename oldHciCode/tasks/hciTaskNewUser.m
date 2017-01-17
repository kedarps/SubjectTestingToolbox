classdef hciTaskNewUser < hciTask
    properties
        id = 'newTask';
        
        overlayPanel
        
        isAdminSubTask = false;
    end
    methods
        function self = hciTaskNewUser(varargin)
            self = prtUtilAssignStringValuePairs(self, varargin{:});
            
            if ~self.hgIsValid
                create(self);
            end
            
            run(self);
        end
        
        function run(self)
            
            s.DisplayName = 'Enter a Display Name';
            s.SubjectID = 'Enter a single string subjectId (must be a valid MATLAB variable name)';
            s.MapFile = '#<file>Select an initial a MAP MAT File';
            
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
                
                try
                    hciUtilNewSubject(newS.SubjectID, newS.DisplayName, newS.MapFile);
                    done = true;
                catch  %#ok<CTCH>
                    self.motherApp.message(sprintf('Unable to create new user.<br>Perhaps the ID "%s" is already in use or<br>"%s"<br> is not a valid MAP MAT file.', newS.SubjectID, newS.MapFile));
                end
            end
            
            % Switch to the new user
            loadSubject(self.motherApp, newS.SubjectID);
            
            if ~self.isAdminSubTask
                self.motherApp.message(sprintf('Hello %s.',self.subject.displayName));
            else
                self.isSubTask = true;
            end
            exit(self);
        end
    end
end