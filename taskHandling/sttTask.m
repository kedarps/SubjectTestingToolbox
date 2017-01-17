classdef (Abstract) sttTask < matlab.mixin.SetGet
    % Abstract class for creating tasks.  Tasks are responsible for
    % presenting appropriate stimuli and logging responses to stimuli.
    % Tasks should be able to quit mid-task and restart.  If an error
    % occurs, they need to save the current progress and pass the error on
    % up for the main testing interface to handle.
    
    properties
        % Every task needs to keep track of the task list in which they are
        % contained
        parentTaskList
        
        % Every task should have a instantiation of a subject 
        subject
        
        % Every task should have a title
        taskTitle
        
        % Every task needs a status that can be pinged
        status = 'Ready';
        
        % Every task needs a completion date/time
        completionDateAndTime = {};
        
        % Every task needs a log in which the results of the experiment
        % should be stored
        log
    end
    
    properties (Hidden, Transient)
        % There are a limited number of possible statuses
        statusSet = matlab.system.StringSet({'Ready', 'In Progress', ...
            'Completed', 'Error'});
    end
    
    methods (Abstract)
        run(self, parentTaskList);
        respondToError(self);
        logStimulusAndResponse(self);   % Use to update log
        resetTask(self);
    end
    
    methods
        %............................................................
        % Update task status.
        function updateStatus(self, status)
            self.status = status;
        end
        
        %............................................................
        % Return task status.
        function status = returnStatus(self)
            status = self.status;
        end
        
        %............................................................
        % Log task completion time.
        function logCompletionDateAndTime(self)
            self.completionDateAndTime = vertcat(...
                self.completionDateAndTime, ...
                {datestr(now)});
        end
    end
end
