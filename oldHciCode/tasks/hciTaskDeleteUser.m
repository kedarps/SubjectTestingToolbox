classdef hciTaskDeleteUser < hciTask
    properties
        id = 'deleteUser';
        
        listDlgObj
        handleStruct
        
        isAdminSubTask = false;
    end
    methods
        function self = hciTaskDeleteUser(varargin)
            self = prtUtilAssignStringValuePairs(self, varargin{:});
            
            if ~self.hgIsValid
                create(self);
            end
            
            init(self);
        end
        
        function init(self)
            
            if self.isAdminSubTask
                self.isSubTask = true;
            end
            
            listStrs = hciUtilGetSubjectIds;
            
            self.handleStruct.overlayPanel = uipanel(self.managedHandle,...
                'units','normalized',...
                'BorderType','none',...
                'Position',[0 0 1 1]);
            
            self.listDlgObj = prtUiListDlg('managedHandle',self.handleStruct.overlayPanel,...
                'inputStruct',listStrs,...
                'tableFontSize',20,...
                'enableMultiSelect',true,...
                'titleStr','Select subject IDs to Delete.',...
                'messageStr','Select a subject IDs to Delete.');
            
            if isempty(self.listDlgObj.enteredSelection) || all(self.listDlgObj.enteredSelection==0)
                exit(self);
                return
            end
            
            set(self.handleStruct.overlayPanel,'visible','off');
            
            delIds = listStrs(self.listDlgObj.enteredSelection);
            
            yes = 'Yes (Delete)';
            no = 'No (Cancel)';
            button = self.motherApp.questdlg(sprintf('Are you sure you want to delete these (%d) users? This operation cannot be undone.',length(delIds)),'Delete?',yes,no,no);
            if isempty(button)
                exit(self)
                return;
            end
            switch button
                case yes
                    % Continue below
                case no
                    exit(self)
                    return;
                otherwise
                    self.motherApp.message('The selected users have no been deleted.', 'An issue was encountered and the users have not been deleted.');
                    exit(self)
                    return
            end
            
            hciUtilDeleteSubjectIds(delIds);
            
            self.motherApp.message('The selected users have been deleted.', 'The selected users have been deleted.');
            
            if ismember(self.motherApp.subject.id, delIds);
                % You deleted the current user
                % We have to close
                % We we don't have to but this is substantially easier.
                self.motherApp.message('You have deleted the current user.', 'You have deleted the current user. The program must now close. Please reopen the program and specify a user.');
                
                close(self.motherApp.handleStruct.figure);
            else
                exit(self)
            end
        end
    end
end