classdef hciTaskClosedSetSpeechTest < hciTask
    properties
        id = 'closedSetSpeech';
        
        tokenList
        tokenDisplayList
        presentationList
        presentationTokenList
        responseList
        presentationCount
        
        taskMessage
        
        saveLoc
        scoreMatrix
        
        numTokenRepeatsPerTest = 3;
        tokenType
       
        stimulusPauseTimePre = 0.1; % in seconds
        stimulusPauseTimePost = 0; % in seconds
        
        noiseLevel;
        addReverb = false;

        phonemeResults
        phonemeList
        taskScore
        taskLabel
        
        saveResultsOnQualityExit = true;
        allowNonSettingExit = true;
        
        startTime
        endTime

        isLocked = false;
        handleStruct
    end
    
    methods
        function self = hciTaskClosedSetSpeechTest(varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
            
            if nargin~=0 && ~self.hgIsValid
                self.create();
            end
            
            setup(self);
        end
        
        function setup(self)
            setupUi(self);
            
            self.responseList = {};
            
            self.presentationCount = 0;
        end
        
        function setupUi(self)
            self.handleStruct.axes = axes('parent',self.managedHandle,...
                'units','normalized',...
                'position',[0.1 0.1 0.8 0.8],...
                'Visible','off');

            % Set up task selection
            self.handleStruct.taskListInstructions = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.2 0.55 0.6 0.2],...
                'String','Select Type of Speech',...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'HorizontalAlignment','left',...
                'Visible','off');
            self.handleStruct.taskList = uicontrol('Style','popupmenu',...
                'Parent',self.managedHandle,...
                'String',{' ','Vowels','Consonants'},...
                'Units','normalized','Position',[0.2 0.5 0.6 0.2],...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'Callback',@self.getTokenList,...
                'Visible','off');
            self.handleStruct.noiseListInstructions = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.2 0.35 0.6 0.2],...
                'String','Select Amount of Noise',...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'HorizontalAlignment','left',...
                'Visible','off');
            self.handleStruct.noiseList = uicontrol('Style','popupmenu',...
                'Parent',self.managedHandle,...
                'String',{  'None',...
                'A Little Noise',...
                'Lots of Noise'},...
                'Units','normalized','Position',[0.2 0.3 0.6 0.2],...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'Callback',@self.getNoiseLevel,...
                'Visible','off');
            self.handleStruct.reverbStatus = uicontrol('Style','checkbox',...
                'Parent',self.managedHandle,...
                'String','Add Reverberation?',...
                'Units','normalized','Position',[0.2 0.25 0.6 0.2],...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'Callback',@self.getReverbStatus,...
                'Visible','off');
            self.handleStruct.continueButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.1 0.01 0.15 0.08],...
                'String','Continue',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.goToTask,...
                'Enable','on');
            
            % Set up status indicator
            self.handleStruct.startButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.3 0.85 0.4 0.1],...
                'String','Ready',...
                'FontUnits','normalized',...
                'FontSize',0.5,...
                'Callback',@self.startTask,...
                'Visible','off',...
                'Enable','off');
            
            self.handleStruct.status = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.3 0.85 0.4 0.1],...
                'String','Select Speech Test',...
                'FontUnits','normalized',...
                'FontSize',0.5);
            
            % Allow partial completion and quitting
            self.handleStruct.quitButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.8 0.01 0.15 0.08],...
                'String','Quit',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.saveAndQuit);
            self.handleStruct.doneButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.8 0.01 0.15 0.08],...
                'String','Done',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.finishTask,...
                'Visible','off',...
                'Enable','off');
            
            resizeFunction(self)

            if ~isempty(self.presentationList)
                goToTask(self);
            else
                set(self.handleStruct.taskListInstructions,'Visible','on');
                set(self.handleStruct.taskList,'Visible','on','Enable','on');
                set(self.handleStruct.noiseListInstructions,'Visible','on');
                set(self.handleStruct.noiseList,'Visible','on','Enable','on');
                set(self.handleStruct.continueButton,'Visible','on');
                set(self.handleStruct.reverbStatus,'Visible','on','Enable','on');
                drawnow;
            end
            set(self.handleStruct.continueButton,'Enable','on');
            set(self.handleStruct.quitButton,'Enable','on');
        end

        function resizeFunction(self, varargin)
            pos = getpixelposition(self.managedHandle); pos = pos(3:4);
            border = 10;
            buttonSize = [200 50];
            buttonBottom = border;
            set(self.handleStruct.quitButton,'units','pixels');
            set(self.handleStruct.quitButton,'position',[border buttonBottom buttonSize])
            set(self.handleStruct.quitButton,'units','normalized');
            set(self.handleStruct.doneButton,'units','pixels');
            set(self.handleStruct.doneButton,'position',[border buttonBottom buttonSize])
            set(self.handleStruct.doneButton,'units','normalized');
            
            figSize = get(gcf,'Position');
            numPixels = figSize(3);
            buttonLeft = numPixels - buttonSize(1) - border;
            set(self.handleStruct.continueButton,'units','pixels');
            set(self.handleStruct.continueButton,'position',[buttonLeft buttonBottom buttonSize])
            set(self.handleStruct.continueButton,'units','normalized');
            
            textHeight = pos(2)*0.15;
            axesLeft = border;
            axesWidth = pos(1)-axesLeft;
            axesHeight = pos(2)-textHeight-border;
            
            set(self.handleStruct.axes,'units','pixels');
            set(self.handleStruct.axes,'outerposition',[axesLeft 5*border axesWidth, axesHeight])
            set(self.handleStruct.axes,'units','normalized');
        end
        
        function goToTask(self,varargin)
            if isempty(self.presentationList)
                warningStr = 'Please select a speech type before continuing.';
                self.handleStruct.warndlg = warndlg(warningStr,'Select Speech Type');
            else
                if ~isempty(self.taskMessage)
                    self.motherApp.message(self.taskMessage);
                end
                
                self.startTime = now;
                
                % Disable task selection
                set(self.handleStruct.taskListInstructions,'Visible','off');
                set(self.handleStruct.taskList,'Visible','off','Enable','off');
                set(self.handleStruct.noiseListInstructions,'Visible','off');
                set(self.handleStruct.noiseList,'Visible','off','Enable','off');
                set(self.handleStruct.continueButton,'Visible','off','Enable','off');
                set(self.handleStruct.reverbStatus,'Visible','off','Enable','off');
                
                % Enable task controls
                set(self.handleStruct.status,'Visible','off');
                set(self.handleStruct.startButton,...
                    'Visible','on',...
                    'Enable','on');
                
                % Set up closed set response buttons
                setupClosedSetButtons(self);
            end
        end
        function setupClosedSetButtons(self)
            % Set up response buttons
            topMargin = 0.15;
            bottomMargin = 0.15;
            colMargin = 0.1;
            numTokens = length(self.tokenDisplayList);
            numRows = floor(sqrt(numTokens));
            numCols = ceil(numTokens/numRows);
            horzSpacing = (1-(2*colMargin))/numCols;
            vertSpacing = (1-(topMargin+bottomMargin))/numRows;
            buttonWidth = 0.8*horzSpacing;
            buttonHeight = 0.5*vertSpacing;
            
            rowCounter = 1;
            colCounter = 1;
            for b = 1:numTokens
                % Create buttons
                leftPos = colMargin+((colCounter-1)*horzSpacing);
                bottomPos = 1 - topMargin - (rowCounter*vertSpacing);
                self.handleStruct.responseButtons(b) =...
                    uicontrol('Style','pushbutton',...
                    'Parent',self.managedHandle,...
                    'Units','normalized',...
                    'Position',[leftPos bottomPos buttonWidth buttonHeight],...
                    'String',self.tokenDisplayList{b},...
                    'FontUnits','normalized','FontSize',0.5,...
                    'Callback',{@recordSelection,self},...
                    'Enable','off');
                
                % Update button position
                if (colCounter < numCols)
                    colCounter = colCounter + 1;
                else
                    rowCounter = rowCounter + 1;
                    colCounter = 1;
                end
            end
        end

        function startTask(self,varargin)
            self.presentationCount = 1;
            set(self.handleStruct.startButton,'Enable','off','Visible','off')
            set(self.handleStruct.status,'Visible','on')
            
            % Enable all the response buttons
            for b = 1:length(self.handleStruct.responseButtons)
                set(self.handleStruct.responseButtons,'Enable','on');
            end
            
            presentToken(self)
        end
        function presentToken(self)
            cameInLocked = self.isLocked;
            if ~cameInLocked
                lockUi(self);
            end
            
            % Present stimulus
            set(self.handleStruct.status,'String','Presenting...')
            p = self.presentationCount;
            presentationToken = self.presentationList{p};
            
            pause(self.stimulusPauseTimePre)
            
            self.map.stimulateSpeechToken(...
                presentationToken,...
                self.noiseLevel,...
                self.addReverb);
            
            pause(self.stimulusPauseTimePost)

            if self.map.catestrophicFailure
                return
            end
            
            if ~cameInLocked
                unlockUi(self);                
            end
        end
        
        % Record button press
        function recordSelection(source,event,self)
            self.responseList{end+1} = get(source,'String');
            self.presentationCount = self.presentationCount + 1;
            if (self.presentationCount <= length(self.presentationList))
                presentToken(self)
            else
                scoreResults(self)
            end
        end
        
        % Score responses
        function scoreResults(self,varargin)
%             % Debug
%             self.responseList = self.presentationTokenList(randperm(length(self.presentationTokenList)));
% %             self.responseList = self.presentationTokenList;

            turnOffTask(self);
            
            [labels, occurrence, scores, taskScore] = scoreClosedSetResponses(self);
            presentResults(self,labels,occurrence,scores, taskScore);
        end
        function turnOffTask(self)
            % Disable task controls
            set(self.handleStruct.status,...
                'String','Calculating Score...',...
                'Visible','on');
            for b = 1:length(self.handleStruct.responseButtons)
                set(self.handleStruct.responseButtons(b),...
                    'Enable','off',...
                    'Visible','off')
            end
        end
        function [labels, occurrence, scores, taskScore] = scoreClosedSetResponses(self)
            % Compare response tokens to presentation tokens
            responseCorrect = strcmpi(self.responseList,self.presentationTokenList);
            
            % Return tested phonemes, their occurrence, and their scores
            labels = unique(self.presentationTokenList);
            occurrence = zeros(size(labels));
            scores = zeros(size(labels));
            for L = 1:length(labels)
                labelMatch = strcmp(labels{L},self.presentationTokenList);
                occurrence(L) = sum(labelMatch);
                scores(L) = sum(responseCorrect(labelMatch));
            end
            taskScore = 100*(sum(responseCorrect))/length(self.presentationTokenList);
        end
        function presentResults(self,labels,occurrence,scores,taskScore)
            % Update UI
            set(self.handleStruct.status,...
                'String','Your Scores',...
                'Visible','on');
            set(self.handleStruct.quitButton,...
                'Visible','off',...
                'Enable','off');
            set(self.handleStruct.doneButton,...
                'Visible','on',...
                'Enable','on');
            set(self.handleStruct.axes,'Visible','on')
            
            % Plot results
            self.handleStruct.results = bar(100*scores(:)./occurrence(:));
            set(self.handleStruct.results,'FaceColor',[0.7020 0.7804 1])
            hold all
            plot([0 (length(labels)+0.8)],taskScore*ones(1,2),'m--','LineWidth',5)
            taskLabel = [upper(self.tokenType(1)) lower(self.tokenType(2:end)) ...
                char(10) 'Score'];
            text((length(labels)+1),taskScore,taskLabel,...
                'FontSize',20,...
                'Color','m',...
                'FontWeight','bold')
            box on
            xlim([0 (length(labels)+2)])
            ylim([0 100])
            set(gca,'XTick',1:length(labels),'XTickLabel',labels)
            ylabel('Percent Correct')
            xlabel('Test Words')

            % Save results in object
            self.phonemeResults = 100*scores(:)./occurrence(:);
            self.phonemeList = labels;
            self.taskScore = taskScore;
            self.taskLabel = {taskLabel};
        end
            

        % Save and quit
        function saveResults(self,varargin)
        
        end
        function finishTask(self,varargin)
            self.endTime = now;
            if self.saveResultsOnQualityExit
                results = createResults(self);
                
                mes = self.motherApp.wait('Saving Results...');
                self.motherApp.subject.logResults(results);
                close(mes);
            end
            
            exit(self);            
        end
        function saveAndQuit(self,varargin)
            qu = 'Are you sure you want to discard all information and exit?';
            str1 = 'Yes. exit.';
            str2 = 'No, go back.';
            
            button = self.motherApp.questdlg(qu,'Really Exit?',str1,str2,str2);
            if strcmpi(button,str1)
                exit(self);
            end
        end
        function results = createResults(self)
            resultsStruct.tokenType = self.tokenType;
            resultsStruct.phonemeResults = self.phonemeResults;
            resultsStruct.phonemeList = self.phonemeList;
            resultsStruct.taskScore = self.taskScore;
            resultsStruct.taskLabel = self.taskLabel;
            resultsStruct.startTime = self.startTime;
            resultsStruct.endTime = self.endTime;
            
            results = hciResults('type',self.id,'results',resultsStruct);
        end


        function getTokenList(self,varargin)
            rng('shuffle')
            popupResponse = get(varargin{1});
            switch popupResponse.Value
                case 1
                    self.tokenList = [];
                    self.presentationList = [];
                case 2
                    % Get full token list
                    disp('Getting vowel list...')
                    self.taskMessage = (['<HTML><H1>Vowel Test</H1>'...
                        '<H2>The vowel sounds will be presented ' ...
                        'in a H-vowel-D format.  Concentrate on the central ' ...
                        'vowel and select what best matches what you hear.</H2></HTML>']);
                    self.tokenType = 'Vowel';
                    [self.tokenList,self.tokenDisplayList] = hciUtilGetTokenList(hciDirsDataVowels);
                case 3
                    % Get full token list
                    disp('Getting consonant list...')
                    self.taskMessage = (['<HTML><H1>Consonant Test</H1>'...
                        '<H2>The consonant sounds will be presented ' ...
                        'in an AH-consonant-AH format.  Concentrate on the central ' ...
                        'consonant and select what best matches what you hear.</H2></HTML>']);
                    self.tokenType = 'Consonant';
                    [self.tokenList,self.tokenDisplayList] = hciUtilGetTokenList(hciDirsDataConsonants);
            end
            if ~isempty(self.tokenList)
                tokenInd = repmat(1:length(self.tokenList),1,self.numTokenRepeatsPerTest);
                stimI = randperm(length(tokenInd));
                self.presentationList = self.tokenList(tokenInd(stimI));
                self.presentationTokenList = self.tokenDisplayList(tokenInd(stimI));
            end
        end
        function getNoiseLevel(self,varargin)
            popupResponse = get(varargin{1});
            switch popupResponse.Value
                case 1
                    disp('No noise...')
                    self.noiseLevel = 0;
                case 2
                    disp('A little noise...')
                    self.noiseLevel = 0.05;     % About 20 dB SNR
                case 3
                    disp('Lots of noise...')
                    self.noiseLevel = 0.15;     % About 10 dB SNR
            end
        end
        function getReverbStatus(self,varargin)
            reverbStatus = get(varargin{1});
            switch reverbStatus.Value
                case 0
                    disp('No reverberation added...')
                    self.addReverb = false;
                case 1
                    disp('Added reverberation...')
                    self.addReverb = true;
            end
        end
        
        function lockUi(self)
            if self.isLocked
                return
            end
            self.isLocked = true;
            
            % Disable response buttons
            for b = 1:length(self.handleStruct.responseButtons)
                set(self.handleStruct.responseButtons(b),'Enable','off')
            end
            set(self.handleStruct.quitButton,'Enable','off');
        end
        function unlockUi(self)
            if ~self.isLocked
                return
            end
            
            % Enable response buttons
            set(self.handleStruct.status,'String','Click on what you heard:')
            for b = 1:length(self.handleStruct.responseButtons)
                set(self.handleStruct.responseButtons(b),'Enable','on')
            end
            set(self.handleStruct.quitButton,'Enable','on');
            
            self.isLocked = false;
        end

    end
end
