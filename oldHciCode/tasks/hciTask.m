classdef hciTask < prtUiManagerPanel
    properties (Abstract)
        id
    end
    properties
        motherApp
        nextTask = @hciTaskStart;
        
        verboseText = false;
        
        
    end
    properties (Dependent)
        resources
        subject
        map
    end
    properties (Access = 'protected')
        isSubTask = false;
    end
        
    methods
        function self = hciTask(varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
        end
        function exit(self)
            if self.isSubTask
                % Sub tasks don't start the "next task" property
                % Instead they just die by deleting their uipanel (that is
                % covering the uipanel of the parent task)
                delete(self.managedHandle);
            else
                % Regular old task in the main app, let the main app decide
                % how to kill you and start the nextTask
                
                delete(self.managedHandle);
                endTask(self.motherApp,self.nextTask);
            end
        end
        
        function subTask = subTask(self, subTaskHandle, otherInputs)
            if nargin < 3
                otherInputs = {};
            end
            subTaskPanel = uipanel('parent',self.managedHandle,...
                'Units','normalized','Position',[0 0 1 1],...
                'visible','on','BorderType','none');
            isAdminFcn = strcmp(func2str(subTaskHandle),self.motherApp.adminFcnList);
            if sum(isAdminFcn) > 0
                otherInputs = [otherInputs, {'isAdminSubTask',true}];
            end
            subTask = feval(...
                subTaskHandle,...
                'managedHandle',subTaskPanel,...
                'motherApp',self.motherApp,...
                otherInputs{:});
            subTask.isSubTask = true;
            
            waitfor(subTaskPanel,'BeingDeleted','on');
        end
    end  
    
	methods % Dependent property methods
        function set.resources(self,val)
            self.motherApp.resources = val;
        end
        function val = get.resources(self)
            val = self.motherApp.resources;
        end
        function set.subject(self,val)
            self.motherApp.subject = val;
        end
        function val = get.subject(self)
            val = self.motherApp.subject;
        end
        function set.map(self,val)
            self.motherApp.map = val;
        end
        function val = get.map(self)
            val = self.motherApp.map;
        end
    end
end