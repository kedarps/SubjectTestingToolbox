classdef (Abstract) sttTaskPregeneratedOpenSetSpeech < sttTask
    properties
        % Display panel and object handles
        taskPanel
        handleStruct
        
        % Stimuli for task
        stimulusList
        stimulusTokens
        
        % Hold typing if subject starts to type early
        heldTyping = []
    end
    
    methods
        %............................................................
        % Load task data.
        function loadTaskData(self, taskDataPath)
            try
                load(taskDataPath);
                
                % Check data
                if ...
                        ~exist('stimulusList', 'var') || ...
                        ~exist('stimulusTokens', 'var') || ...
                        ~exist('taskTitle', 'var')
                    ME = MException(...
                        'sttTask:LoadTaskData', ...
                        'Necessary data not contained in file.');
                    throw(ME);
                else
                    self.stimulusList = stimulusList;
                    self.stimulusTokens = stimulusTokens;
                    self.taskTitle = taskTitle;
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
                self.log.taskData.stimulusList = self.stimulusList;
                
                % Store presented stimuli and responses
                self.log.presentedStimuli = [];
                self.log.responses = [];
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
                'String', self.taskTitle,...
                'BackgroundColor', get(self.taskPanel, 'BackgroundColor'), ...
                'ForegroundColor', [0.3 0.5 0.05], ...
                'Units','normalized',...
                'Position',[0.01 0.85 0.7 0.1],...
                'FontUnits','normalized',...
                'FontSize',0.5, ...
                'HorizontalAlignment', 'left');
            
            % Set up indicator
            self.handleStruct.statusButton = uicontrol(self.taskPanel,...
                'Style', 'pushbutton', ...
                'String','Click Here to Start',...
                'Units','normalized',...
                'Position',[0.3 0.73 0.4 0.1],...
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
            figH = get(self.taskPanel, 'Parent');
            lastKey = get(figH, 'CurrentCharacter');
            if regexp(lastKey, '\r|\n|\r\n')
                self.logStimulusAndResponse();
            end
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
            presentToken(self, self.stimulusTokens(nextStimulusI));
            
            % Unlock UI after token presentation
            self.unlockUi();
            
            % update title status
            self.updateTitle(nextStimulusI-1);
            
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
            stimulus = self.stimulusList(nextStimulusI);
            response = {get(self.handleStruct.responseBox, 'String')};
            
            % Update log
            self.log.presentedStimuli = [self.log.presentedStimuli stimulus];
            self.log.responses = [self.log.responses response];
            
            % Clear response
            set(self.handleStruct.responseBox, 'String', [])
            self.heldTyping = [];
            
            % Run next token
            if (nextStimulusI + 1) > length(self.stimulusList)
                completeTask(self);
            else
                runTask(self);
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
                            'Stimuli', 'Responses'; ...
                            self.log.presentedStimuli(:), self.log.responses(:)};
                    else
                        self.log.previousResults = {...
                            'Stimuli', 'Responses'; ...
                            self.log.presentedStimuli(:), self.log.responses(:)};
                    end
                    self.log.presentedStimuli = {};
                    self.log.responses = {};
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
        % Update title status, to show task progress
        function updateTitle(self, id)
            % first get task title
            taskTitle = self.taskTitle;
            % calculate % done
            pcDone = round((100*id/length(self.stimulusList))*100)/100;
            % update UI title
            if ~isempty(self.handleStruct.taskTitle)
                set(self.handleStruct.taskTitle,'String',[taskTitle,' - ',num2str(pcDone),' % Done']);
            end
        end
    end
    
    methods (Abstract)
        presentToken(self, token);
        saveAndQuit(self);
    end
end
        