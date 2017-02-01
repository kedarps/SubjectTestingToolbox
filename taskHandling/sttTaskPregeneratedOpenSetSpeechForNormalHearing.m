classdef sttTaskPregeneratedOpenSetSpeechForNormalHearing < sttTaskPregeneratedOpenSetSpeech
    properties
    end
    
    methods
        %............................................................
        % Constructor
        function self = sttTaskPregeneratedOpenSetSpeechForNormalHearing(varargin)
            self = prtUtilAssignStringValuePairs(self, varargin{:});
        end
        
        %............................................................
        % Run entire task.
        function run(self, parentTaskList)
            try
                % Track parent task list
                %   Note:  there is really no difference between run modes
                %   for normal hearing subjects, so no reason to store it
                self.parentTaskList = parentTaskList;
                self.taskPanel = self.parentTaskList.handleStruct.taskPanel;
                
                % Check that all necessary data are filled in
                self.checkData();
                
                % If starting task from the beginning, create log and
                % check subject type
                if strcmp('Ready', self.returnStatus())
                    createLog(self);
                    checkSubjectType(self);
                end
                
                % Set up GUI
                initGui(self);
            catch ME
                % Create a base exception to indicate where this error 
                % occurred and append the cause to it.
                baseME = MException(...
                    'sttTask:Run', ...
                    'Error occurred while operating the task.');
                newME = addCause(baseME, ME);
                self.respondToError(newME);                
            end
        end
        
        %............................................................
        % Check for necessary data
        %   Used in function run
        function checkData(self)
            if isempty(self.taskTitle)
                ME = MException(...
                    'sttTask:CheckData', ...
                    'Task data contained no title.');
                throw(ME);
            elseif isempty(self.stimulusList)
                ME = MException(...
                    'sttTask:CheckData', ...
                    'Task data contained no stimulus list.');
                throw(ME);
            elseif isempty(self.stimulusTokens)
                ME = MException(...
                    'sttTask:CheckData', ...
                    'Task data contained no stimulus tokens.');
                throw(ME);
            end
        end
        
        %............................................................
        % Check subject and task match.
        %   Used in function run
        function checkSubjectType(self)
            % If no subject, error
            if isempty(self.subject)
                ME = MException(...
                    'sttTask:CheckSubjectType', ...
                    'No subject has been assigned to this task.');
                throw(ME);
            end
            
            % Check that subject is the correct class
            if ~isa(self.subject, 'sttNormalHearingSubject')
                ME = MException(...
                    'sttTask:CheckSubjectType', ...
                    'Task is intended for normal hearing but subject is not sttNormalHearingSubject class.');
                throw(ME);
            end
        end
        
        %............................................................
        % Present token
        function presentToken(self, token)
            self.playerObj = audioplayer(token.signal, token.Fs);
            playblocking(self.playerObj);
            
            while self.playerObj.isplaying
                drawnow;
            end
        end
        
        %............................................................
        % Respond to any errors
        function respondToError(self, ME)
            % Update status to indicate that an error occurred
            self.updateStatus('Error');
            
            % Notify researcher of task error
            errH = errordlg(['Error occurred during task: ' ME.message], ...
                'Task Error', 'modal');
            uiwait(errH);
            
            % Save whatever there is
            [errorFile, savePath] = uiputfile(...
                ['taskErrorFile' datestr(now, 'yyyymmdd') '.mat'],...
                'Save Error File');
            if (~isequal(errorFile, 0) && ~isequal(savePath,0))
                % Save copy of object without UI handles
                objAsByteArray = getByteStreamFromArray(self);
                taskObj = getArrayFromByteStream(objAsByteArray);
                taskObj.handleStruct = [];
                taskObj.taskPanel = [];

                save(fullfile(savePath, errorFile), 'taskObj');
            end

            % Rethrow error to task list
            throw(ME);
        end

        %............................................................
        % Save and quit.
        function saveAndQuit(self)
            self.logCompletionDateAndTime();
            clearTaskPanelAndExit(self);
        end
    end
end