classdef sttTaskVocoderTrainingUsingPregeneratedOpenSetSpeech < sttTask
    % This task tests a listener acoustically with pregenerated, vocoded, 
    % open set speech, providing feedback after each response.  An initial
    % set of speech is presented for training and scored.  Additional tokens
    % are presented and scored until the desired score consistency is 
    % achieved. If consistent performance is achieved, the task ends
    % All tokens are scored automatically using Levenshtein distance.
    properties
        % Display panel and object handles
        taskPanel
        handleStruct
        
        % TASK DATA for this task should contain three items:
        %   taskTitle - a string identifying the task
        %   stimulusTokens - a structure for which each element corresponds
        %               to a token.  The fields are as follows:
        %               signal - the audio signal of the token
        %               Fs - the sampling frequency of the audio signal
        %               answer - a string specifying the correct response; 
        %                   answers can take the form of words separated by
        %                   spaces or words concatenated together with each
        %                   word capitalized (e.g. The boy went in the 
        %                   water, or TheBoyWentInTheWater).
        %   minimumTokens - an integer specifying the minimum number of
        %               training tokens that must be presented before the
        %               training score consistency can end the task (e.g.
        %               20 sentences)
        %   numTokensForScoring - an integer specifying the number of
        %               tokens used to generate a training score (e.g. 5)
        %   desiredConsistency - a number, [0, 100], specifying the range, in
        %               percentage points that is considered consistent,
        %               e.g. 5 percentage points
        %   numScoresToAssess - how many scores have to be consistent?
        %   pauseLength - a number specifying the number of seconds to
        %               display the feedback before continuing
        %   dictionary - a structure for which each element represents a
        %               word.  The fields should include 'word' which is a
        %               cell containing a word string, and 'phonemeList' which is
        %               a cell array of strings representing the phonemes,
        %               in word order, that make up the word.
        stimulusTokens
        minimumTokens
        numTokensForScoring
        desiredConsistency
        numScoresToAssess
        pauseLength
        dictionary
        
        % Hold typing if subject starts to type early
        heldTyping = []
        
        % Audioplayer object for token presentation
        playerObj
    end
    
    methods
        %............................................................
        % Constructor
        function self = sttTaskVocoderTrainingUsingPregeneratedOpenSetSpeech(varargin)
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
            elseif isempty(self.stimulusTokens)
                ME = MException(...
                    'sttTask:CheckData', ...
                    'Task data contained no stimulus tokens.');
                throw(ME);
            elseif isempty(self.minimumTokens)
                ME = MException(...
                    'sttTask:CheckData', ...
                    'Task data did not specify a number of tokens for initial training.');
                throw(ME);
            elseif isempty(self.numTokensForScoring)
                ME = MException(...
                    'sttTask:CheckData', ...
                    'Task data did not specify a number of tokens for scoring.');
                throw(ME);
            elseif isempty(self.desiredConsistency)
                ME = MException(...
                    'sttTask:CheckData', ...
                    'Task data did not specify desired consistency in scores.');
                throw(ME);
            elseif isempty(self.numScoresToAssess)
                ME = MException(...
                    'sttTask:CheckData', ...
                    'Task data did not specify how many scores need to be consistent.');
                throw(ME);
            elseif isempty(self.pauseLength)
                ME = MException(...
                    'sttTask:CheckData', ...
                    'Task data did not specify a pause length for feedback.');
                throw(ME);
            end
            
            % also check if stimulusTokens contains correct fields
            checkFields = {'signal'; 'Fs'};
            stimTokenFields = fieldnames(self.stimulusTokens);
            
            if length(checkFields) ~= length(stimTokenFields) || ...
                    ~all(strcmp(checkFields, stimTokenFields))
                ME = MException(...
                    'sttTask:CheckData', ...
                    'stimulusTokens struct is not right. Make sure it contains ''signal'' and ''Fs'' fields (case-sensitive)');
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
        % Load task data.
        function loadTaskData(self, taskDataPath)
            try
                load(taskDataPath);
                
                % Check data
                if ...
                        ~exist('stimulusTokens', 'var') || ...
                        ~exist('taskTitle', 'var') || ...
                        ~exist('minimumTokens', 'var') || ...
                        ~exist('numTokensForScoring', 'var') || ...
                        ~exist('desiredConsistency', 'var') || ...
                        ~exist('pauseLength', 'var') || ...
                        ~exist('dictionary', 'var')                      
                    ME = MException(...
                        'sttTask:LoadTaskData', ...
                        'Necessary data not contained in file.');
                    throw(ME);
                else
                    self.stimulusTokens = stimulusTokens;
                    self.taskTitle = taskTitle;
                    self.minimumTokens = minimumTokens;
                    self.numTokensForScoring = numTokensForScoring;
                    self.desiredConsistency = desiredConsistency;
                    self.numScoresToAssess = numScoresToAssess;
                    self.pauseLength = pauseLength;
                    self.dictionary = dictionary;
                end
            catch ME
                if ~strncmp(ME.identifier, 'sttTask', 7)
                    % If some unknown error occurs, create a base exception to
                    % indicate where this error occurred and append the cause
                    % to it.
                    baseME = MException(...
                        'sttTask:LoadTaskData', ...
                        'Error occurred during task data load.');
                    newME = addCause(baseME, ME);
                    self.respondToError(newME);
                else
                    % Otherwise, respond to original error
                    self.respondToError(ME);
                end
            end
        end
        
        %............................................................
        % Create log.
        function createLog(self)
            try
                % Store subject data
                self.log.subject = self.subject;
                
                % Store task data
                self.log.taskData.taskTitle = self.taskTitle;
                self.log.taskData.answers = {self.stimulusTokens.answer};
                
                % Store presented stimuli and responses
                self.log.presentedStimuli = [];
                self.log.responses = [];
                
                % Store scores used to decide on training
                self.log.numCorrectPhonemes = [];
                self.log.numTotalPhonemes = [];
            catch ME
                % Create a base exception to indicate where this error
                % occurred and append the cause to it.
                baseME = MException(...
                    'sttTask:CreateLog', ...
                    'Error occurred during log creation.');
                newME = addCause(baseME, ME);
                self.respondToError(newME);
            end
        end
        
        %............................................................
        % Set up task GUI.
        function initGui(self)
            % Display task name
            self.handleStruct.taskTitle = uicontrol(self.taskPanel,...
                'Style', 'text', ...
                'String', sprintf('%s [ Task %d of %d ]',self.taskTitle,self.parentTaskList.taskPointer,length(self.parentTaskList.taskList)),...
                'BackgroundColor', get(self.taskPanel, 'BackgroundColor'), ...
                'ForegroundColor', [0.3 0.5 0.05], ...
                'Units','normalized',...
                'Position',[0.01 0.9 0.9 0.1],...
                'FontUnits','normalized',...
                'FontSize',0.4, ...
                'HorizontalAlignment', 'left');
            
            % Set up indicator
            self.handleStruct.statusButton = uicontrol(self.taskPanel,...
                'Style', 'pushbutton', ...
                'String','Click Here to Start',...
                'Units','normalized',...
                'Position',[0.2 0.73 0.6 0.1],...
                'FontUnits','normalized',...
                'FontSize',0.5,...
                'Callback',@(h,e)self.startTask);
            
            % Set up text box
            self.handleStruct.responseText = uicontrol(self.taskPanel, ...
                'Style', 'text', ...
                'String', 'Type what you heard:', ...
                'Units', 'normalized', ...
                'Position', [0.1 0.6 0.4 0.06], ...
                'FontUnits', 'normalized', ...
                'FontSize', 0.6, ...
                'BackgroundColor', get(self.taskPanel, 'BackgroundColor'), ...
                'HorizontalAlignment', 'left', ...
                'Visible', 'off');
            self.handleStruct.responseBox = uicontrol(self.taskPanel, ...
                'Style', 'edit', ...
                'Units','normalized','Position',[0.2 0.4 0.6 0.2],...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'TooltipString','Enter your response here.',...
                'Callback',@(h,e)self.enterResponseOnlyOnKeyboardReturn,...
                'HorizontalAlignment', 'left', ...
                'Enable','off',...
                'Visible','off');

            % Set up feedback text
            self.handleStruct.feedbackText = uicontrol(self.taskPanel, ...
                'Style', 'text', ...
                'String', [], ...
                'Units', 'normalized', ...
                'Position', [0.2 0.33 0.6 0.06], ...
                'FontUnits', 'normalized', ...
                'FontSize', 0.6, ...
                'BackgroundColor', get(self.taskPanel, 'BackgroundColor'), ...
                'HorizontalAlignment', 'left', ...
                'Visible', 'off');

            % Allow quitting mid-task
            self.handleStruct.quitButton = uicontrol(self.taskPanel, ...
                'Style','pushbutton',...
                'Units','normalized',...
                'Position',[0.8 0.01 0.15 0.08],...
                'String','Quit',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@(h,e)self.quitTask,...
                'Enable','off');
        end
        
        %............................................................
        % Check event used to trigger responseBox callback.  If it is a
        % mouse click, ignore it.  Only a carriage return should trigger
        % the logging of the response.
        %   Callback for responseBox in initGUI.
        function enterResponseOnlyOnKeyboardReturn(self)
            if self.playerObj.isplaying
                return
            end
            response = get(self.handleStruct.responseBox,'String');
            if isempty(regexp(response,'\w','ONCE'))
                set(self.handleStruct.statusButton, ...
                    'String', 'You have to enter something...');
                return
            end
            figH = get(self.taskPanel, 'Parent');
            lastKey = get(figH, 'CurrentCharacter');
            if regexp(lastKey, '\r|\n|\r\n')
                self.displayFeedback();
                self.logStimulusAndResponse();
            end
        end
        
        %............................................................
        % Display feedback.
        %   Used in enterResponseOnlyOnKeyboardReturn.
        function displayFeedback(self)
            nextStimulusI = length(self.log.presentedStimuli) + 1;
            answer = self.stimulusTokens(nextStimulusI).answer;
            answerStr = sttUtilConvertAnswerToDisplayString(answer);
            
            set(self.handleStruct.feedbackText, ...
                'String', ['Correct Response: ' answerStr], ...
                'Visible', 'on');
            pause(self.pauseLength);
            set(self.handleStruct.feedbackText, ...
                'String', [], ...
                'Visible', 'off');
        end
        
        %............................................................
        % Start task.
        function startTask(self)
            % Update status
            self.updateStatus('In Progress');
            
            % Show response box
            set(self.handleStruct.responseText, 'Visible', 'on');
            set(self.handleStruct.responseBox, 'Visible', 'on');
            
            % Turn off status button
            set(self.handleStruct.statusButton, 'Enable', 'off');
            
            % Run task
            runTask(self);
        end
        
        %............................................................
        % Run task.
        function runTask(self)
            % Disable quit button
            set(self.handleStruct.quitButton, 'Enable', 'off')
            
            % Change status display
            origColor = get(self.handleStruct.statusButton, 'BackgroundColor');
            set(self.handleStruct.statusButton, ...
                'String', 'Playing...', ...
                'BackgroundColor', [0.85 0.95 0.75]);
            
            % Get stimulus pointer
            nextStimulusI = length(self.log.presentedStimuli) + 1;
            
            % Lock UI during token presentation
            self.lockUi();
            
            % Present token
            self.presentToken(self.stimulusTokens(nextStimulusI));
            
            % Unlock UI after token presentation
            self.unlockUi();
            
            % Enable response and reset status display
            self.enableBoxWithoutSelection();
            set(self.handleStruct.statusButton, ...
                'String', 'Enter Response...', ...
                'BackgroundColor', origColor);
            
            % Enable quit button
            set(self.handleStruct.quitButton, 'Enable', 'on');
        end
        
        %............................................................
        % Stop the user from typing or clicking things during presentation.
        %   Used in runTask.
        function lockUi(self)
            % Clear typing buffer
            self.heldTyping = [];
            
            % Give window control
            figureH = get(self.taskPanel,'Parent');
            set(figureH,...
                'WindowKeyPressFcn',@(obj,event)self.holdTyping(event));
        end
        
        %............................................................
        % Present token acoustically.
        %   Used in runTask.
        function presentToken(self, token)
            self.playerObj = audioplayer(token.signal, token.Fs);
            playblocking(self.playerObj);
            
            while self.playerObj.isplaying
                drawnow;
            end
        end

        %............................................................
        % Reinstate user control.
        %   Used in runTask.
        function unlockUi(self)
            % Reset window for access to uicontrols
            figureH = get(self.taskPanel,'Parent');
            set(figureH,...
                'WindowKeyPressFcn',[]);
            
            % Enter any previously typed text
            if ~isempty(self.heldTyping)
                set(self.handleStruct.responseBox,'String',self.heldTyping);
            end
        end
        
        %............................................................
        % Enable the text box without highlighting all the text.
        %   Used in runTask.
        function enableBoxWithoutSelection(self)
            jObj = findjobj(self.handleStruct.responseBox);
            jObj.setSelectAllOnFocus(false);
            
            uicontrol(self.handleStruct.responseBox);
            set(self.handleStruct.responseBox, 'Enable', 'on');
            jObj.setCaretPosition(jObj.getDocument.getLength);
        end
        
        %............................................................
        % If the subject starts typing early, hold the typing and input
        % into text box.
        %   Used by lockUi
        function holdTyping(self,event)
            switch event.Key
                case 'backspace'
                    if ~isempty(self.heldTyping)
                        self.heldTyping(end) = [];
                    end
                otherwise
                    self.heldTyping = [self.heldTyping event.Character];
            end
            set(self.handleStruct.responseBox,'String',self.heldTyping);
        end
        
        %............................................................
        % Complete task.
        function completeTask(self)
            % Set status display
            set(self.handleStruct.statusButton, ...
                'String', 'Done');
            
            % Update status
            self.updateStatus('Completed');
            
            % Save results
            saveAndQuit(self);
            
            % Return control to task list
            self.parentTaskList.run([], self.parentTaskList.runMode);
        end
        
        %............................................................
        % Quit in the middle of the task.
        function quitTask(self)
            % Save results
            saveAndQuit(self);
            
            % Return control to task list
            self.parentTaskList.saveAndClear(true);
        end
        
        %............................................................
        % Log stimulus and response.
        function logStimulusAndResponse(self)
            % Get presented stimulus and response
            nextStimulusI = length(self.log.presentedStimuli) + 1;
            stimulus = self.stimulusTokens(nextStimulusI).answer;
            response = get(self.handleStruct.responseBox, 'String');
            
            % Score response
            [numCorrect, numTotal] = sttUtilScoreOpenSetSpeech(...
                response, stimulus, self.dictionary);
            
            % Update log
            self.log.presentedStimuli = [self.log.presentedStimuli {stimulus}];
            self.log.responses = [self.log.responses {response}];
            self.log.numCorrectPhonemes = [self.log.numCorrectPhonemes numCorrect];
            self.log.numTotalPhonemes = [self.log.numTotalPhonemes numTotal];
            
            % Clear response
            set(self.handleStruct.responseBox, 'String', [])
            self.heldTyping = [];
            
            % Check whether quitting condition has been reached
            if (nextStimulusI >= self.minimumTokens)
                isDone = evaluatePerformance(self);
            else
                isDone = false;
            end
            if isDone || (nextStimulusI + 1) > length(self.stimulusTokens)
                completeTask(self);
            else
                runTask(self);
            end
        end
        
        %............................................................
        % Check to see whether performance has reached an acceptable level.
        %   Used by logStimulusAndResponse.
        function isDone = evaluatePerformance(self)
            numTokens = mod(length(self.log.presentedStimuli), ...
                self.numTokensForScoring);
            if (numTokens ~= 0)
                isDone = false;
            else
                scores = 100 * (self.log.numCorrectPhonemes ./ self.log.numTotalPhonemes);
                scoreSets = buffer(scores, self.numTokensForScoring);
                avgScores = mean(scoreSets);
                if length(avgScores) < self.numScoresToAssess
                    isDone = false;
                else
                    evalScores = avgScores((end - self.numScoresToAssess + 1):end);
                    isDone = all(abs(diff(evalScores)) < self.desiredConsistency);
                end
            end
        end
        
        %............................................................
        % Clear the task panel.
        function clearTaskPanelAndExit(self)
            taskChildren = get(self.taskPanel, 'Children');
            while ~isempty(taskChildren)
                delete(taskChildren(1));
                taskChildren(1) = [];
            end
        end
        
        %............................................................
        % Reset task.
        function resetTask(self)
            try
                % Set aside previous results in log
                if ~isempty(self.log)
                    if any(strcmp('previousResults', fieldnames(self.log)))
                        self.log.previousResults(:,:,end+1) = {...
                            'Stimuli', 'Responses', 'Number Correct', 'Number Tokens'; ...
                            self.log.presentedStimuli(:), self.log.responses(:), ...
                            self.log.numCorrectPhonemes(:), self.log.numTotalPhonemes(:)};
                    else
                        self.log.previousResults = {...
                            'Stimuli', 'Responses', 'Number Correct', 'Number Tokens'; ...
                            self.log.presentedStimuli(:), self.log.responses(:), ...
                            self.log.numCorrectPhonemes(:), self.log.numTotalPhonemes(:)};
                    end
                    self.log.presentedStimuli = {};
                    self.log.responses = {};
                    self.log.numCorrectPhonemes = [];
                    self.log.numTotalPhonemes = [];
                end
            catch ME
                % Create a base exception to indicate where this error
                % occurred and append the cause to it.
                baseME = MException(...
                    'sttTask:ResetTask', ...
                    'Error occurred while resetting task.');
                newME = addCause(baseME, ME);
                self.respondToError(newME);
            end
        end
        
        %............................................................
        % Save and quit.
        function saveAndQuit(self)
            self.logCompletionDateAndTime();
            clearTaskPanelAndExit(self);
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
    end
end
