classdef hciTaskChangeUser < hciTask
    properties
        id = 'changeUser';
        listDlgObj
        handleStruct
        
        isAdminSubTask = false;
    end
    methods
        function self = hciTaskChangeUser(varargin)
            self = prtUtilAssignStringValuePairs(self, varargin{:});
            
            if ~self.hgIsValid
                create(self);
            end
            
            init(self);
        end
        
        function init(self)
            
            listStrs = hciUtilGetSubjectIds;
            
            self.listDlgObj = prtUiListDlg('managedHandle',self.managedHandle,...
                'inputStruct',listStrs,...
                'tableFontSize',20,...
                'titleStr','Select a subject ID.',...
                'messageStr','Select a subject ID.');
            
            if isempty(self.listDlgObj.enteredSelection)
                if self.isAdminSubTask
                    self.isSubTask = true;
                end
                exit(self);
                return
            end            
            
            newId = listStrs{self.listDlgObj.enteredSelection};
            
            loadSubject(self.motherApp, newId);

            if ~self.isAdminSubTask
                self.motherApp.message('Welcome back',sprintf('Welcome back %s',self.motherApp.subject.displayName));
            else
                self.isSubTask = true;
            end
            exit(self);
        end
    end
end