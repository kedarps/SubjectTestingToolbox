classdef hciTaskQualitativeSpeechTest < hciTask
    properties
        id = 'qualitativeSpeech';
        
        origMap
        origMapStruct
        map1
        map1Struct
        map1SetFlag = false;
        map2
        map2Struct
        map2SetFlag = false;
        mapOrder
        mapPreferences
        mapLabels
        
        
        tokenList
        tokenDisplayList
        presentationList
        presentationTokenList
        responseList
        presentationCount
        
        numPhonemeTokenRepeatsPerTest = 2;
        numSentenceTokensPerTest = 20;
        numWordTokensPerTest = 25;

        taskMessage
        
        saveLoc
        scoreMatrix
        
        tokenType
       
        stimulusPauseTimePre = 0.1; % in seconds
        stimulusPauseTimePost = 0; % in seconds
        
        noiseLevel;
        addReverb = false;

        saveResultsOnQualityExit = true;
        allowNonSettingExit = true;
        
        startTime
        endTime
        
        textFontSize = 15;
        
        clientMismatch = false;

        isLocked = false;
        isAdminSubTask;
        handleStruct
    end
    
    methods
        function self = hciTaskQualitativeSpeechTest(varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
            
            if nargin~=0 && ~self.hgIsValid
                self.create();
            end
            
            setup(self);
        end
        
        function setup(self)
            if ~isempty(self.origMapStruct)
                self.origMap = hciMap(self.origMapStruct);
            else
                self.origMap = hciMap(self.map.nucleusMapStructure);
            end
            if ~isempty(self.map1Struct)
                self.map1 = hciMap(self.map1Struct);
            else
                self.map1 = hciMap(self.map.nucleusMapStructure);
            end
            if ~isempty(self.map1Struct)
                self.map2 = hciMap(self.map2Struct);
            else
                self.map2 = hciMap(self.map.nucleusMapStructure);
            end
            
            setupUi(self);
            
            self.presentationCount = 0;
        end
        
        function setupUi(self)
            self.handleStruct.axes = axes('parent',self.managedHandle,...
                'units','normalized',...
                'position',[0.1 0.1 0.7 0.7],...
                'Visible','off');
            self.handleStruct.status = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.2 0.85 0.6 0.1],...
                'String','Your Preferences',...
                'FontUnits','normalized',...
                'FontSize',0.5,...
                'Visible','off');

            % Set up task selection
            self.handleStruct.mapLoadingInstructions = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.2 0.55 0.6 0.2],...
                'String','Select Processor Settings for Comparison',...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'HorizontalAlignment','left',...
                'Visible','off');
            self.handleStruct.loadFirstMap = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.2 0.6 0.15 0.08],...
                'String','Settings 1',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.setMapForComparison,...
                'Enable','on',...
                'Visible','off');
            self.handleStruct.loadSecondMap = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.4 0.6 0.15 0.08],...
                'String','Settings 2',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.setMapForComparison,...
                'Enable','on',...
                'Visible','off');
            self.handleStruct.continueButtonToTaskSelection = uicontrol(...
                'Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.1 0.01 0.15 0.08],...
                'String','Continue',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.goToTaskSelection,...
                'Enable','on',...
                'Visible','off');
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
                'String',{' ','Vowels','Consonants','Words','Sentences'},...
                'Units','normalized','Position',[0.2 0.5 0.6 0.2],...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'Callback',@self.getTokenList,...
                'Enable','off',...
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
                'Enable','off',...
                'Visible','off');
            self.handleStruct.reverbStatus = uicontrol('Style','checkbox',...
                'Parent',self.managedHandle,...
                'String','Add Reverberation?',...
                'Units','normalized','Position',[0.2 0.25 0.6 0.2],...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'Callback',@self.getReverbStatus,...
                'Enable','off',...
                'Visible','off');
            self.handleStruct.continueButtonToTask = uicontrol(...
                'Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.1 0.01 0.15 0.08],...
                'String','Continue',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.goToTask,...
                'Enable','off',...
                'Visible','off');
            
            % Task Buttons
            self.handleStruct.tokenDisplay = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.2 0.6 0.6 0.1],...
                'String',' ',...
                'FontUnits','normalized',...
                'FontSize',0.5,...
                'HorizontalAlignment','center',...
                'Visible','off');
            self.handleStruct.versionOneButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.3 0.5 0.15 0.08],...
                'String','Version 1',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.presentToken,...
                'Visible','off',...
                'Enable','off');
            self.handleStruct.versionTwoButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.5 0.5 0.15 0.08],...
                'String','Version 2',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.presentToken,...
                'Visible','off',...
                'Enable','off');
            self.handleStruct.bestIs = uibuttongroup(...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.3 0.4 0.4 0.08],...
                'BorderType','none',...
                'Visible','off');
            self.handleStruct.bestIsOne = uicontrol('Style','radiobutton',...
                'Parent',self.handleStruct.bestIs,...
                'Units','normalized',...
                'Position',[0.01 0.01 0.45 0.7],...
                'String','Version 1 is Best',...
                'FontUnits','normalized',...
                'FontSize',0.5);
            self.handleStruct.bestIsTwo = uicontrol('Style','radiobutton',...
                'Parent',self.handleStruct.bestIs,...
                'Units','normalized',...
                'Position',[0.5 0.01 0.45 0.7],...
                'String','Version 2 is Best',...
                'FontUnits','normalized',...
                'FontSize',0.5);
            set(self.handleStruct.bestIs,...
                'SelectionChangeFcn',@self.recordSelection,...
                'SelectedObject',[]);
            
            % Allow partial completion and quitting
            self.handleStruct.quitButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.8 0.01 0.15 0.08],...
                'String','Quit',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.saveAndQuit,...
                'Visible','off');
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

            [self.handleStruct.textHandle, self.handleStruct.textHandleContainer]  = ...
                javacomponent('javax.swing.JLabel',[1 1 1 1], self.managedHandle);
            backgroundColor = get(self.managedHandle,'BackgroundColor');
            set(self.handleStruct.textHandle,...
                'Text',self.messageStr,...
                'Background',java.awt.Color(backgroundColor(1),backgroundColor(2),backgroundColor(3)),...
                'Font',java.awt.Font('sansserif',java.awt.Font.PLAIN,self.textFontSize));
            self.handleStruct.textHandle.setVerticalAlignment(javax.swing.JLabel.TOP);
            
            set(self.managedHandle,'ResizeFcn',@self.resizeFunction)
            self.resizeFunction();

            resizeFunction(self)
            
            if (self.map1SetFlag && self.map2SetFlag) 
                goToTaskSelection(self)
            else
                set(self.handleStruct.mapLoadingInstructions,'Visible','on');
                set(self.handleStruct.loadFirstMap,'Visible','on','Enable','on');
                set(self.handleStruct.loadSecondMap,'Visible','on','Enable','on');
                set(self.handleStruct.continueButtonToTaskSelection,'Visible','on','Enable','on');
                drawnow;
            end
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
            set(self.handleStruct.continueButtonToTaskSelection,'units','pixels');
            set(self.handleStruct.continueButtonToTaskSelection,'position',[buttonLeft buttonBottom buttonSize])
            set(self.handleStruct.continueButtonToTaskSelection,'units','normalized');
            set(self.handleStruct.continueButtonToTask,'units','pixels');
            set(self.handleStruct.continueButtonToTask,'position',[buttonLeft buttonBottom buttonSize])
            set(self.handleStruct.continueButtonToTask,'units','normalized');
            
            textHeight = pos(2)*0.15;
            axesLeft = border;
            axesWidth = pos(1)-axesLeft;
            axesHeight = pos(2)-textHeight-border;
            
            set(self.handleStruct.axes,'units','pixels');
            set(self.handleStruct.axes,'outerposition',[axesLeft 5*border axesWidth, axesHeight])
            set(self.handleStruct.axes,'units','normalized');

            textLeft = border+((pos(1)-(2*border))/3);
            set(self.handleStruct.textHandleContainer,'units','pixels');
            set(self.handleStruct.textHandleContainer,'position',[textLeft border*2+axesHeight axesWidth textHeight])
            set(self.handleStruct.textHandleContainer,'units','normalized');
            set(self.handleStruct.textHandleContainer,'Visible','off');
        end
        function str = messageStr(self) %#ok<MANU>
            str = '<HTML><H1>Speech Quality Comparison</H1><p>Listen to each version and select the one that sounds best to you.</p></HTML>';
        end
        
        function setMapForComparison(self,varargin)
            set(self.handleStruct.mapLoadingInstructions,'Visible','off');
            set(self.handleStruct.loadFirstMap,...
                'Enable','off','Visible','off');
            set(self.handleStruct.loadSecondMap,...
                'Enable','off','Visible','off');
            set(self.handleStruct.continueButtonToTaskSelection,...
                'Enable','off','Visible','off');
            set(self.handleStruct.quitButton,...
                'Enable','off','Visible','off');
            mapLabel = get(varargin{1},'String');
            taskFun = @hciTaskSelectMap;
            mapSelectionSubTask = self.subTask(taskFun);
            switch mapLabel
                case 'Settings 1'
                    setAsMap(self,1);
                    self.map1SetFlag = true;
                case 'Settings 2'
                    setAsMap(self,2);
                    self.map2SetFlag = true;
                otherwise
                    msgbox('Please notify the test administrator of this error.','Task failed.','error');
                    exit(self)
            end
            set(self.handleStruct.mapLoadingInstructions,'Visible','on');
            set(self.handleStruct.loadFirstMap,...
                'Enable','on','Visible','on');
            set(self.handleStruct.loadSecondMap,...
                'Enable','on','Visible','on');
            set(self.handleStruct.continueButtonToTaskSelection,...
                'Enable','on','Visible','on');
            set(self.handleStruct.quitButton,...
                'Enable','on','Visible','on');
        end
        function setAsMap(self,mapNumber)
            % Set map with new values
            mapFields = fieldnames(self.map.nucleusMapStructure);
            for m = 1:length(mapFields)
                switch mapNumber
                    case 0
                        self.origMap.nucleusMapStructure.(mapFields{m}) = ...
                            self.map.nucleusMapStructure.(mapFields{m});
                    case 1
                        self.map1.nucleusMapStructure.(mapFields{m}) = ...
                            self.map.nucleusMapStructure.(mapFields{m});
                    case 2
                        self.map2.nucleusMapStructure.(mapFields{m}) = ...
                            self.map.nucleusMapStructure.(mapFields{m});
                end
            end
        end
        function selectMap(self,mapNumber)
            % Set map with new values
            mapFields = fieldnames(self.map.nucleusMapStructure);
            for m = 1:length(mapFields)
                switch mapNumber
                    case 0
                        self.map.nucleusMapStructure.(mapFields{m}) = ...
                            self.origMap.nucleusMapStructure.(mapFields{m});
                    case 1
                        self.map.nucleusMapStructure.(mapFields{m}) = ...
                            self.map1.nucleusMapStructure.(mapFields{m});
                    case 2
                        self.map.nucleusMapStructure.(mapFields{m}) = ...
                            self.map2.nucleusMapStructure.(mapFields{m});
                end
            end
            
            disp('Changing map to: ')
            self.map.nucleusMapStructure
        end
        
        function verifyMaps(self)
            % Make sure both MAPs use the same client as the original
            %   map
            if (~strcmp(self.map1.nucleusMapStructure.implant.IC,...
                    self.origMap.nucleusMapStructure.implant.IC)) || ...
                    (~strcmp(self.map2.nucleusMapStructure.implant.IC,...
                    self.origMap.nucleusMapStructure.implant.IC))
                mapFailure(self);
            end
        end
        function goToTaskSelection(self,varargin)
            if ~self.map1SetFlag
                warningStr = 'Please select first set of processor settings for comparison.';
                self.handleStruct.warndlg = warndlg(warningStr,'Select Settings 1');
            elseif ~self.map2SetFlag
                warningStr = 'Please select second set of processor settings for comparison.';
                self.handleStruct.warndlg = warndlg(warningStr,'Select Settings 2');
            else                
                % Turn off map selection
                set(self.handleStruct.mapLoadingInstructions,'Visible','off');
                set(self.handleStruct.loadFirstMap,...
                    'Enable','off','Visible','off');
                set(self.handleStruct.loadSecondMap,...
                    'Enable','off','Visible','off');
                set(self.handleStruct.continueButtonToTaskSelection,...
                    'Enable','off','Visible','off');
                
                % Turn on task selection
                set(self.handleStruct.taskListInstructions,'Visible','on');
                set(self.handleStruct.taskList,'Visible','on','Enable','on');
                set(self.handleStruct.noiseListInstructions,'Visible','on');
                set(self.handleStruct.noiseList,'Visible','on','Enable','on');
                set(self.handleStruct.continueButtonToTask,'Visible','on','Enable','on');
                set(self.handleStruct.reverbStatus,'Visible','on','Enable','on');
            end
            
            drawnow;
            if (~isempty(self.presentationList))
                goToTask(self);
            end
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
                set(self.handleStruct.continueButtonToTask,'Visible','off','Enable','off');
                set(self.handleStruct.reverbStatus,'Visible','off','Enable','off');
                
                % Enable task controls
                set(self.handleStruct.textHandleContainer,'Visible','on');
                set(self.handleStruct.tokenDisplay,'Visible','on');
                set(self.handleStruct.versionOneButton,'Visible','on','Enable','on');
                set(self.handleStruct.versionTwoButton,'Visible','on','Enable','on');
                set(self.handleStruct.bestIs,'Visible','on');
                
                % Enable task controls
                verifyMaps(self);
                self.presentationCount = 1;
                setupDisplay(self);
            end
        end
        function setupDisplay(self)
            % Clear selection
            set(self.handleStruct.bestIs,...
                'SelectedObject',[]);

            % Get token
            presentationToken = self.presentationList{self.presentationCount};
            [tokenPath,tokenName] = fileparts(presentationToken);
            
            % Convert token to display format
            displayToken = hciUtilConvertTokenToDisplay(tokenName,self.tokenType);
            set(self.handleStruct.tokenDisplay,'String',displayToken)

            if self.clientMismatch
                exit(self)
            end
        end
            
        function presentToken(self,varargin)
            cameInLocked = self.isLocked;
            if ~cameInLocked
                lockUi(self);
            end

            % Present stimulus
            p = self.presentationCount;
            presentationToken = self.presentationList{p};

            pause(self.stimulusPauseTimePre)

            % Select map
            mapOrder = self.mapOrder(p,:);
            switch lower(get(varargin{1},'String'))
                case 'version 1'
                    selMap = mapOrder(1);
                case 'version 2'
                    selMap = mapOrder(2);
            end
            selectMap(self,selMap);
            
            % Manually get client
            self.map.startProcessor();
            
            % Present token with selected map
            self.map.stimulateSpeechToken(...
                presentationToken,...
                self.noiseLevel,...
                self.addReverb);
            
            % Manually shutdown client
            self.map.stopProcessor();
            
            pause(self.stimulusPauseTimePost)

            if self.map.catestrophicFailure
                selectMap(self,0);
                return
            end
            
            if ~cameInLocked
                unlockUi(self);                
            end
        end
        
        % Record button press
        function recordSelection(self,source,event)
            % Get selection
            p = self.presentationCount;
            trialMapOrder = self.mapOrder(p,:);
            selection = get(get(source,'SelectedObject'),'String');
            switch lower(selection)
                case 'version 1 is best'
                    self.responseList(p) = trialMapOrder(1);
                case 'version 2 is best'
                    self.responseList(p) = trialMapOrder(2);
            end
            
            self.presentationCount = self.presentationCount + 1;
            if (self.presentationCount <= length(self.presentationList))
                setupDisplay(self)
            else
                scoreResults(self)
            end
        end
        
        % Score responses
        function scoreResults(self,varargin)
            turnOffTask(self);
            
            presentResults(self);
        end
        function turnOffTask(self)
            % Disable task controls
            set(self.handleStruct.status,...
                'String','Aggregating Selections...',...
                'Visible','on');
            set(self.handleStruct.tokenDisplay,...
                'Visible','off');
            set(self.handleStruct.versionOneButton,'Visible','off','Enable','off');
            set(self.handleStruct.versionTwoButton,'Visible','off','Enable','off');
            set(self.handleStruct.bestIs,'Visible','off');
            set(self.handleStruct.bestIsOne,'Enable','off');
            set(self.handleStruct.bestIsTwo,'Enable','off');
            set(self.handleStruct.quitButton,'Enable','off');
            set(self.handleStruct.textHandleContainer,'Visible','off');
        end
        function presentResults(self)
            % Update UI
            set(self.handleStruct.status,...
                'String',['Aggregated Preferences For ' ...
                upper(self.tokenType(1)) lower(self.tokenType(2:end)) 's'],...
                'Visible','on');
            set(self.handleStruct.quitButton,'Visible','off','Enable','off');
            set(self.handleStruct.doneButton,'Visible','on','Enable','on');
            set(self.handleStruct.axes,'Visible','on')
            
            % Plot results
            numOptions = unique(self.mapOrder(:));
            for n = 1:length(numOptions)
                optionSelCount(n) = length(find(self.responseList == numOptions(n)));
                labels{n} = ['Settings ' num2str(numOptions(n))];
            end
            self.handleStruct.results = bar(optionSelCount./length(self.responseList));
            set(self.handleStruct.results,'FaceColor',[0.7020 0.7804 1])
            hold all
            box on
            xlim([0 (length(labels)+1)])
            ylim([0 1])
            set(gca,'XTick',1:length(numOptions),'XTickLabel',labels)
            ylabel('Proportion of Times Selected as Best')

            % Save results in object
            self.mapPreferences = 100*optionSelCount./length(self.responseList);
            self.mapLabels = labels;
        end
            

        % Save and quit
        function finishTask(self,varargin)
            % Reset map
            selectMap(self,0);
            set(self.handleStruct.status,'Visible','off');
            set(self.handleStruct.doneButton,'Visible','off');
            set(self.handleStruct.axes,'Visible','off')
            
            % End task
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
                selectMap(self,0);
                exit(self);
            end
        end
        function results = createResults(self)
            resultsStruct.tokenType = self.tokenType;
            resultsStruct.mapPreferences = self.mapPreferences;
            resultsStruct.mapLabels = self.mapLabels;
            resultsStruct.map1 = self.map1.nucleusMapStructure;
            resultsStruct.map2 = self.map2.nucleusMapStructure;
            resultsStruct.mapOrder = self.mapOrder;
            resultsStruct.responseList = self.responseList;
            resultsStruct.noiseLevel = self.noiseLevel;
            resultsStruct.addReverb = self.addReverb;
            resultsStruct.startTime = self.startTime;
            resultsStruct.endTime = self.endTime;
            
            results = hciResults('type',self.id,'results',resultsStruct);
        end


        function getTokenList(self,varargin)
            rng('shuffle')
            popupResponse = get(varargin{1});
            % Get full token list
            switch popupResponse.Value
                case 1
                    self.tokenList = [];
                    self.presentationList = [];
                    self.mapOrder = [];
                case 2
                    disp('Getting vowel list...')
                    self.tokenType = 'Vowel';
                    [self.tokenList,self.tokenDisplayList] = hciUtilGetTokenList(hciDirsDataVowels);
                    
                    tokenInd = repmat(1:length(self.tokenList),1,self.numPhonemeTokenRepeatsPerTest);
                    stimI = randperm(length(tokenInd));
                    self.presentationList = self.tokenList(tokenInd(stimI));
                case 3
                    disp('Getting consonant list...')
                    self.tokenType = 'Consonant';
                    [self.tokenList,self.tokenDisplayList] = hciUtilGetTokenList(hciDirsDataConsonants);

                    tokenInd = repmat(1:length(self.tokenList),1,self.numPhonemeTokenRepeatsPerTest);
                    stimI = randperm(length(tokenInd));
                    self.presentationList = self.tokenList(tokenInd(stimI));
                case 4
                    disp('Getting word list...')
                    self.tokenType = 'word';
                    [self.tokenList,self.tokenDisplayList] = hciUtilGetTokenList(hciDirsDataWords);

                    stimI = randperm(length(self.tokenList),self.numWordTokensPerTest);
                    self.presentationList = self.tokenList(stimI);
                case 5
                    disp('Getting sentence list...')
                    self.tokenType = 'sentence';
                    [self.tokenList,self.tokenDisplayList] = hciUtilGetTokenList(hciDirsDataQualitativeSentences);

                    stimI = randperm(length(self.tokenList),self.numSentenceTokensPerTest);
                    self.presentationList = self.tokenList(stimI);
            end
            orderOptions = [1 2; 2 1];
            self.mapOrder = orderOptions(randi(2,1,length(self.presentationList)),:);
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
        
        function mapFailure(self)
            selectMap(self,0);
            errorStruct.map1 = self.map1.nucleusMapStructure;
            errorStruct.map2 = self.map2.nucleusMapStructure;
            errorStruct.origMap = self.origMap.nucleusMapStructure;
            save(fullfile(hciRoot,'debuggingMatFiles','QualitativeSpeechTaskFailure'),'errorStruct');
            m = msgbox('Please notify the test administrator of this error.','Implant IC not matched.','error');
            waitfor(m);
            self.clientMismatch = true;
        end
        function lockUi(self)
            if self.isLocked
                return
            end
            self.isLocked = true;
            
            % Disable controls
            set(self.handleStruct.tokenDisplay,...
                'String',['Presenting: ' get(self.handleStruct.tokenDisplay,'String')]);
            set(self.handleStruct.versionOneButton,'Enable','off');
            set(self.handleStruct.versionTwoButton,'Enable','off');
            set(self.handleStruct.bestIsOne,'Enable','off');
            set(self.handleStruct.bestIsTwo,'Enable','off');
            set(self.handleStruct.quitButton,'Enable','off');
        end
        function unlockUi(self)
            if ~self.isLocked
                return
            end
            
            % Enable response buttons
            displayStr = get(self.handleStruct.tokenDisplay,'String');
            set(self.handleStruct.tokenDisplay,...
                'String',displayStr(13:end));
            set(self.handleStruct.versionOneButton,'Enable','on');
            set(self.handleStruct.versionTwoButton,'Enable','on');
            set(self.handleStruct.bestIsOne,'Enable','on');
            set(self.handleStruct.bestIsTwo,'Enable','on');
            set(self.handleStruct.quitButton,'Enable','on');
            
            self.isLocked = false;
        end

    end
end
