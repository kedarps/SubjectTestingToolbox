classdef hciTaskDeleteMap < hciTask
    properties
        id = 'mapDelete';
        
        listDlgObj
        overlayPanel
        
        isAdminSubTask = false;
    end
    methods
        function self = hciTaskDeleteMap(varargin)
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
            
            self.overlayPanel = uipanel(self.managedHandle,...
                'units','normalized',...
                'BorderType','none',...
                'Position',[0 0 1 1]);
            
            mapsDb = self.subject.mapsDatabase;
            self.listDlgObj = prtUiListDlg('managedHandle',self.overlayPanel,...
                'inputStruct',mapsDb,...
                'titleStr','Select a Maps to Delete.',...
                'messageStr','Select a Map to Delete',...
                'enableMultiSelect',true);
            
            selected = self.listDlgObj.enteredSelection;
            if isempty(selected) || all(selected ==0)
                exit(self);
                return;
            end
            
            yes = 'Yes (Delete)';
            no = 'No (Cancel)';
            button = self.motherApp.questdlg(sprintf('Are you sure you want to delete these (%d) maps? This operation cannot be undone.',length(selected)),'Delete?',yes,no,no);
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
                    self.motherApp.message('The selected maps have NOT been deleted.', 'An issue was encountered and the maps have <b>NOT</b> been deleted.');
                    exit(self)
                    return
            end
            
            deleteMaps(self.subject, mapsDb(selected)); 
            
            %self.motherApp.message('The selected maps have been deleted.', 'The selected maps have been deleted.');
            
            exit(self);
        end
    end
end