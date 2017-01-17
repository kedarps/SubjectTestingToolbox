classdef hciTaskPersonalGuide < hciTask
    properties
        id = 'personalGuide';
        
        startTime
        endTime
        
        comparisonType = [];
        speechTask
        
        origMap
        newMap
        oldMapResults
        newMapResults
        qualMapResults
        
        isParameterTask
        parameterTaskId
        
        taskOrder = {...
            '@hciTaskSetPulseRate',...
            '@hciTaskSetTsAndCs',...
            '@hciTaskSetQ',...
            '@hciTaskLevittAdjustSpeechVolume'};
%         taskOrder = {...
%             '@hciTaskSetQ'};
        taskI;
        
        saveResultsOnQualityExit = true;
        allowNonSettingExit = true;
        promptToSetOnExit = true;
        
        isAdminSubTask;
        handleStruct
    end
    
    methods
        function self = hciTaskPersonalGuide(varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
            
            if nargin~=0 && ~self.hgIsValid
                self.create();
            end
            
            self.newMap = hciMap(self.map.nucleusMapStructure);
            self.origMap = hciMap(self.map.nucleusMapStructure);

            setupUi(self);
            setup(self);
        end
        
        function setupUi(self)
            % Speech Comparison Axes
            self.handleStruct.axesOldMap = axes('parent',self.managedHandle,...
                'units','normalized',...
                'position',[0.1 0.5 0.8 0.4],...
                'Visible','off');
            self.handleStruct.axesNewMap = axes('parent',self.managedHandle,...
                'units','normalized',...
                'position',[0.1 0.1 0.8 0.4],...
                'Visible','off');
            self.handleStruct.axesQual = axes('parent',self.managedHandle,...
                'units','normalized',...
                'position',[0.1 0.1 0.7 0.7],...
                'Visible','off');
            self.handleStruct.status = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.3 0.85 0.4 0.1],...
                'String','Your Speech Scores',...
                'FontUnits','normalized',...
                'FontSize',0.5,...
                'Visible','off');

            % Set up task selection
            self.handleStruct.comparisonTestTypeInstructions = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.2 0.65 0.6 0.2],...
                'String','Would you like to evaluate your new settings in terms of speech quality or speech test performance?',...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'HorizontalAlignment','left',...
                'Visible','off');
            self.handleStruct.comparisonTestType = uicontrol('Style','popupmenu',...
                'Parent',self.managedHandle,...
                'String',{' ','Compare Speech Quality','Take a Speech Test'},...
                'Units','normalized','Position',[0.2 0.5 0.6 0.2],...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'Callback',@self.selectComparisonType,...
                'Enable','off',...
                'Visible','off');
            self.handleStruct.taskListInstructions = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.2 0.55 0.6 0.2],...
                'String','What kind of speech would you like to use to evaluate your new settings?',...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'HorizontalAlignment','left',...
                'Visible','off');
            self.handleStruct.taskList = uicontrol('Style','popupmenu',...
                'Parent',self.managedHandle,...
                'String',{' ','Sentences and Words','Vowels and Consonants'},...
                'Units','normalized','Position',[0.2 0.5 0.6 0.2],...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'Callback',@self.selectSpeechTask,...
                'Enable','off',...
                'Visible','off');

            % Allow using new map without testing
            self.handleStruct.doneButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.8 0.01 0.15 0.08],...
                'String','Done',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.doneButton,...
                'Enable','off',...
                'Visible','off');
            self.handleStruct.moreSpeechButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.8 0.01 0.15 0.08],...
                'String','Test More Speech',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.returnToSpeech,...
                'Enable','off',...
                'Visible','off');
            
            resizeFunction(self)
        end
        function resizeFunction(self, varargin)
            pos = getpixelposition(self.managedHandle); pos = pos(3:4);
            border = 10;
            buttonSize = [200 50];
            buttonBottom = border;
            set(self.handleStruct.doneButton,'units','pixels');
            set(self.handleStruct.doneButton,'position',[border buttonBottom buttonSize])
            set(self.handleStruct.doneButton,'units','normalized');
            set(self.handleStruct.moreSpeechButton,'units','pixels');
            set(self.handleStruct.moreSpeechButton,'position',[(2*border)+buttonSize(1) buttonBottom buttonSize])
            set(self.handleStruct.moreSpeechButton,'units','normalized');
            
            textHeight = pos(2)*0.15;
            axesLeft = border;
            axesWidth = pos(1)-axesLeft;
            axesHeight = pos(2)-textHeight-border;
            
            set(self.handleStruct.axesQual,'units','pixels');
            set(self.handleStruct.axesQual,'outerposition',[axesLeft 5*border axesWidth, axesHeight])
            set(self.handleStruct.axesQual,'units','normalized');
            set(self.handleStruct.axesOldMap,'units','pixels');
            set(self.handleStruct.axesOldMap,'outerposition',...
                [axesLeft, ((5*border)+(0.5*axesHeight)), axesWidth, 0.5*axesHeight])
            set(self.handleStruct.axesOldMap,'units','normalized');
            set(self.handleStruct.axesNewMap,'units','pixels');
            set(self.handleStruct.axesNewMap,'outerposition',...
                [axesLeft, (5*border), axesWidth, 0.5*axesHeight])
            set(self.handleStruct.axesNewMap,'units','normalized');
        end
        function setup(self)            
            self.motherApp.message(self.guideDescriptionStr());
            
            self.startTime = now;
            
            self.taskI = 1;
            self.startTime = now;
            startTasks(self);
        end
        function str = guideDescriptionStr(self)
            header = 'Customize Device';
            genericLead = ['We''re going to walk you through the process of ' ...
                'customizing your settings.  You''ll complete the following ' ...
                'tasks and then have the opportunity to compare your old and ' ...
                'new settings with speech.'];
            fullTaskStr = [];
            for t = 1:length(self.taskOrder)
                switch char(self.taskOrder(t))
                    case '@hciTaskSetTsAndCs'
                        taskStr = [num2str(t) '. Set the quietest and ' ...
                            'loudest sounds that you can listen to comfortably.'];
                    case '@hciTaskLevittAdjustSpeechVolume'
                        taskStr = [num2str(t) '. Adjust volume so that speech ' ...
                            'is at a comfortable level.'];
                    case '@hciTaskSetQ'
                        taskStr = [num2str(t) '. Set how rapidly loudness grows.'];
                    case '@hciTaskSetPulseRate'
                        taskStr = [num2str(t) '. Set how rapidly your electrodes are stimulated (pulse rate).'];
                    otherwise
                        error(['Task ' char(self.taskOrder(self.taskI)) ' is unknown.']);
                end
                fullTaskStr = cat(2,fullTaskStr,'<BR>',taskStr);
            end
            
            str = ['<HTML><H1>' header '</H1>'...
                '<H2>' genericLead ...
                fullTaskStr '</H2></HTML>'];
        end
        
        function startTasks(self)
            if (self.taskI <= length(self.taskOrder))
                switch char(self.taskOrder(self.taskI))
                    case '@hciTaskSetTsAndCs'
                        taskFun = @hciTaskSetTsAndCs;
                        otherInputs = {...
                            'stimulateTsType','pulses',...
                            'stimulateCsType','pulses',...
                            'gap',2,...
                            'promptToSetOnExit',false,...
                            'allowNonSettingExit',false,...
                            'saveResultsOnQualityExit',false};
                    case '@hciTaskLevittAdjustSpeechVolume'
                        taskFun = @hciTaskLevittAdjustSpeechVolume;
                        otherInputs = {...
                            'promptToSetOnExit',false,...
                            'allowNonSettingExit',false,...
                            'saveResultsOnQualityExit',false};
                    case '@hciTaskSetQ'
                        taskFun = @hciTaskSetQ;
                        otherInputs = {...
                            'promptToSetOnExit',false,...
                            'allowNonSettingExit',false,...
                            'saveResultsOnQualityExit',false};
                    case '@hciTaskSetPulseRate'
                        taskFun = @hciTaskSetPulseRate;
                        otherInputs = {...
                            'promptToSetOnExit',false,...
                            'allowNonSettingExit',false,...
                            'saveResultsOnQualityExit',false};                            
                    otherwise
                        error(['Task ' char(self.taskOrder(self.taskI)) ' is unknown.']);
                end
                assignMapValues(self,'map','newMap');
                self.map.startProcessor();
                subTaskObj = self.subTask(taskFun, otherInputs);
                self.parameterTaskId = subTaskObj.id;
                self.map.stopProcessor();
                setNewMap(self, subTaskObj);
            else
                self.motherApp.message(['<HTML><H1>Compare Device Parameters</H1>'...
                    '<H2>Congratulations!  You''ve customized your device. ' ...
                    'The next step is to compare your previous and new settings ' ...
                    'using speech material of your choosing.</H2></HTML>']);
                setUpSpeechTesting(self)
            end
        end
        function setNewMap(self,subTaskObj)
            % Set temporary map with new values
            switch subTaskObj.id
                case 'tsAndCs'
                    badElectrodes = ...
                        isnan(subTaskObj.t) | isnan(subTaskObj.c) | isnan(subTaskObj.measElectrodes);
                    for iE = 1:length(subTaskObj.measElectrodes)
                        if badElectrodes(iE)
                            continue
                        end
                        
                        setTsAndCsJointly(self.newMap, subTaskObj.measElectrodes(iE), subTaskObj.t(iE), subTaskObj.c(iE))
                    end
                case 'levittAdjustSpeechVolume'
                    tsAndCs = self.map.getTsAndCs();
                    for e = 1:size(tsAndCs)
                        setTsAndCsJointly(self.newMap, tsAndCs(e,1), tsAndCs(e,2),subTaskObj.adaptCs(e));
                    end
                case 'setQ'
                    setQ(self.newMap, subTaskObj.Q);
                case 'setPulseRate'
                    setPulseRate(self.newMap, subTaskObj.pulseRate, ...
                        subTaskObj.pulseRateLoudnessGrowthFcnT, ...
                        subTaskObj.pulseRateLoudnessGrowthFcnC);
                otherwise
                    error('Task ID is unknown.')
            end
            
            checkBeforeContinue(self);
        end
        function goToNextTask(self)
            self.taskI = self.taskI + 1;
            startTasks(self);
        end
        
        function setUpSpeechTesting(self)
            % Turn off results display
            cla(self.handleStruct.axesOldMap);
            set(self.handleStruct.axesOldMap,'Visible','off');
            cla(self.handleStruct.axesNewMap);
            set(self.handleStruct.axesNewMap,'Visible','off');
            set(self.handleStruct.status,'Visible','off');
            set(self.handleStruct.moreSpeechButton','Visible','off','Enable','off');
            
            assignMapValues(self,'map','origMap');
            
            % Turn on task selection
            set(self.handleStruct.comparisonTestTypeInstructions,...
                'Visible','on')
            set(self.handleStruct.comparisonTestType,...
                'Value',1,...
                'Enable','on',...
                'Visible','on')
            set(self.handleStruct.doneButton,...
                'Enable','on',...
                'Visible','on')
        end
        function selectComparisonType(self,varargin)
            popupResponse = get(varargin{1});
            switch popupResponse.Value
                case 1
                    self.comparisonType=[];
                case 2
                    self.comparisonType='Qualitative';
                    set(self.handleStruct.comparisonTestTypeInstructions,...
                        'Visible','off')
                    set(self.handleStruct.comparisonTestType,...
                        'Enable','off',...
                        'Visible','off')
                    set(self.handleStruct.doneButton,...
                        'Enable','off',...
                        'Visible','off')
                    self.speechTask = 'Qualitative';
                    pause(0.3)
                    testMapsQualitative(self);
                case 3
                    self.comparisonType='Quantitative';
                    set(self.handleStruct.comparisonTestTypeInstructions,...
                        'Visible','off')
                    set(self.handleStruct.comparisonTestType,...
                        'Enable','off',...
                        'Visible','off')
                    set(self.handleStruct.doneButton,...
                        'Enable','off',...
                        'Visible','off')
                    set(self.handleStruct.taskListInstructions,...
                        'Visible','on')
                    set(self.handleStruct.taskList,...
                        'Value',1,...
                        'Enable','on',...
                        'Visible','on')
            end
            
            if isempty(self.comparisonType)
                warningStr = 'Please select a speech type before continuing.';
                self.handleStruct.warndlg = warndlg(warningStr,'Select Speech Type');
            end
        end            
        function selectSpeechTask(self,varargin)
            popupResponse = get(varargin{1});
            switch popupResponse.Value
                case 1
                    self.speechTask=[];
                case 2
                    self.speechTask='OpenSet';
                case 3
                    self.speechTask='ClosedSet';
            end
            
            if ~isempty(self.speechTask)
                set(self.handleStruct.taskListInstructions,...
                    'Visible','off')
                set(self.handleStruct.taskList,...
                    'Enable','off',...
                    'Visible','off')
                set(self.handleStruct.doneButton,...
                    'Enable','off',...
                    'Visible','off')
                pause(0.3)
                testMapsQuantitative(self);
            else
                warningStr = 'Please select a speech type before continuing.';
                self.handleStruct.warndlg = warndlg(warningStr,'Select Speech Type');
            end
        end
        function testMapsQuantitative(self)
            taskFun = eval(['@hciTask' self.speechTask 'SpeechTest']);
            switch self.speechTask
                case 'OpenSet'
                    otherInputs = {...
                        'numSentenceTokensPerTest',10,...
                        'numWordTokensPerTest', 50,...
                        'allowNonSettingExit',false,...
                        'saveResultsOnQualityExit',false};
                case 'ClosedSet'
                    otherInputs = {...
                        'numTokenRepeatsPerTest', 3,...
                        'allowNonSettingExit',false,...
                        'saveResultsOnQualityExit',false};
            end
            
            % Test original map
            self.motherApp.message(['<HTML><H1>First we''ll test your old settings.</H1></HTML>']);
            pause(0.3);
            self.map.startProcessor();
            oldMapSubTaskObj = self.subTask(taskFun,otherInputs);
            self.map.stopProcessor();
            
            % Check to see if speech was tested
            if ~isempty(oldMapSubTaskObj.phonemeResults)
                self.motherApp.message(['<HTML><H1>Now we''ll test your new settings.</H1></HTML>']);
                pause(0.3);
                
                % Get new presentation list
                switch oldMapSubTaskObj.id
                    case 'openSetSpeech'
                        tokenType = oldMapSubTaskObj.tokenType;
                        numTokens = eval(['oldMapSubTaskObj.num' upper(tokenType(1)) ...
                            lower(tokenType(2:end)) 'TokensPerTest']);
                        stimI = randperm(length(oldMapSubTaskObj.tokenList),numTokens);
                        presentationList = oldMapSubTaskObj.tokenList(stimI);
                        otherInputs = cat(2,otherInputs,...
                            {'tokenList',oldMapSubTaskObj.tokenList,...
                            'tokenType',oldMapSubTaskObj.tokenType,...
                            'presentationList',presentationList,...
                            'noiseLevel',oldMapSubTaskObj.noiseLevel,...
                            'addReverb',oldMapSubTaskObj.addReverb,...
                            'dictionary',oldMapSubTaskObj.dictionary,...
                            'allowNonSettingExit',false,...
                            'saveResultsOnQualityExit',false});
                    case 'closedSetSpeech'
                        tokenInd = repmat(1:length(oldMapSubTaskObj.tokenList),1,...
                            oldMapSubTaskObj.numTokenRepeatsPerTest);
                        stimI = randperm(length(tokenInd));
                        presentationList = oldMapSubTaskObj.tokenList(tokenInd(stimI));
                        presentationTokenList = oldMapSubTaskObj.tokenDisplayList(tokenInd(stimI));
                        otherInputs = cat(2,otherInputs,...
                            {'tokenList',oldMapSubTaskObj.tokenList,...
                            'tokenType',oldMapSubTaskObj.tokenType,...
                            'tokenDisplayList',oldMapSubTaskObj.tokenDisplayList,...
                            'presentationList',presentationList,...
                            'presentationTokenList',presentationTokenList,...
                            'noiseLevel',oldMapSubTaskObj.noiseLevel,...
                            'addReverb',oldMapSubTaskObj.addReverb,...
                            'allowNonSettingExit',false,...
                            'saveResultsOnQualityExit',false});
                end
            
                assignMapValues(self,'map','newMap');
                self.map.startProcessor();
                newMapSubTaskObj = self.subTask(taskFun,otherInputs);
                self.map.stopProcessor();
                assignMapValues(self,'map','origMap');
                
                if ~isempty(newMapSubTaskObj.phonemeResults)
                    compareMapsQuantitative(self,oldMapSubTaskObj,newMapSubTaskObj);
                else
                    setUpSpeechTesting(self);
                end
            else
                setUpSpeechTesting(self);
            end
        end        
        function testMapsQualitative(self)
            taskFun = eval(['@hciTask' self.speechTask 'SpeechTest']);
            otherInputs = {...
                'map1Struct',self.map.nucleusMapStructure,...
                'map2Struct',self.newMap.nucleusMapStructure,...
                'map1SetFlag',true,...
                'map2SetFlag',true,...
                'origMapStruct',self.map.nucleusMapStructure,...
                'allowNonSettingExit',false,...
                'saveResultsOnQualityExit',false};
            
            % Compare maps
            pause(0.3);
            qualComparisonSubTaskObj = self.subTask(taskFun,otherInputs);
 
            self.qualMapResults = struct(...
                'map1',qualComparisonSubTaskObj.map1.nucleusMapStructure,...
                'map2',qualComparisonSubTaskObj.map2.nucleusMapStructure,...
                'mapPreferences',qualComparisonSubTaskObj.mapPreferences,...
                'mapLabels',{[qualComparisonSubTaskObj.mapLabels]},...
                'tokenType',{[qualComparisonSubTaskObj.tokenType]},...
                'noiseLevel',qualComparisonSubTaskObj.noiseLevel,...
                'addReverb',qualComparisonSubTaskObj.addReverb);

            continueSpeech(self)
        end        
        function plotResultsQuantitative(self,axisHandle,resultsStruct,resultsTokenType)
            axes(axisHandle)
            results = bar(resultsStruct.phonemeResults);
            set(results,'FaceColor',[0.7020 0.7804 1])
            hold all
            for t = 1:length(resultsStruct.taskScore)
                plot([0 (length(resultsStruct.phonemeList)+0.8)],...
                    resultsStruct.taskScore(t)*ones(1,2),...
                    'm--','LineWidth',2)
                text((length(resultsStruct.phonemeList)+1),...
                    resultsStruct.taskScore(t),...
                    resultsStruct.taskLabel{t},...
                    'FontSize',12,...
                    'Color','m',...
                    'FontWeight','bold')
            end
            box on
            xlim([0 (length(resultsStruct.phonemeList)+2)])
            ylim([0 100])
            set(axisHandle,...
                'XTick',1:length(resultsStruct.phonemeList),...
                'XTickLabel',resultsStruct.phonemeList)
            tickLabels = rotateticklabel(axisHandle,45);
            xLabelH = get(axisHandle,'XLabel');
            xLabelPos = get(xLabelH,'Position');
            set(xLabelH,'Position',[xLabelPos(1) xLabelPos(2)-20 xLabelPos(3)])
            ylabel('Percent Correct')
            xlabel(resultsTokenType)
            hold off
        end
        function compareMapsQuantitative(self,oldMapStruct,newMapStruct)
            % Set up display
            set(self.handleStruct.axesOldMap,'Visible','on');
            set(self.handleStruct.axesNewMap,'Visible','on');
            set(self.handleStruct.status,'Visible','on');
            set(self.handleStruct.doneButton,'Visible','on','Enable','on');
            set(self.handleStruct.moreSpeechButton,'Visible','on','Enable','on');

            switch oldMapStruct.id
                case 'openSetSpeech'
                    resultsTokenType = 'Consonants and Vowels';
                case 'closedSetSpeech'
                    resultsTokenType = 'Test Words';
            end
                            
            % Plot old results
            plotResultsQuantitative(self,...
                self.handleStruct.axesOldMap,...
                oldMapStruct,...
                resultsTokenType);
            
            % Plot new results
            plotResultsQuantitative(self,...
                self.handleStruct.axesNewMap,...
                newMapStruct,...
                resultsTokenType);
            
            self.oldMapResults = struct(...
                'phonemeResults',oldMapStruct.phonemeResults,...
                'phonemeList',{[oldMapStruct.phonemeList]},...
                'taskScore',oldMapStruct.taskScore,...
                'taskLabel',{[oldMapStruct.taskLabel]},...
                'tokenType',{[oldMapStruct.tokenType]},...
                'noiseLevel',qualComparisonSubTaskObj.noiseLevel,...
                'addReverb',qualComparisonSubTaskObj.addReverb);
            self.newMapResults = struct(...
                'phonemeResults',newMapStruct.phonemeResults,...
                'phonemeList',{[newMapStruct.phonemeList]},...
                'taskScore',newMapStruct.taskScore,...
                'taskLabel',{[newMapStruct.taskLabel]},...
                'tokenType',{[newMapStruct.tokenType]},...
                'noiseLevel',qualComparisonSubTaskObj.noiseLevel,...
                'addReverb',qualComparisonSubTaskObj.addReverb);
        end
        function continueSpeech(self)
            turnOffSpeechTask(self);

            self.endTime = now;
            if self.saveResultsOnQualityExit
                results = createResults(self);
                mes = self.motherApp.wait('Saving Results...');
                self.motherApp.subject.logResults(results);
                close(mes);
            end
            
            if self.promptToSetOnExit
                qu = 'Are you done comparing settings?';
                str2 = 'Yes. Use new settings.';
                str1 = 'Yes. Use old settings.';
                str3 = 'No. I''d like to test more speech.';
                
                button = self.motherApp.questdlg(qu,'Done?',str1,str2,str3,str3);
                if strcmpi(button,str2)
                    setAsMap(self);
                    exit(self);
                elseif strcmpi(button,str1)
                    assignMapValues(self,'map','origMap');
                    exit(self);
                else
                    assignMapValues(self,'map','origMap');
                    setUpSpeechTesting(self);
                end
            end
        end
        
        function checkBeforeContinue(self)
            self.endTime = now;
            self.isParameterTask = true;
            if self.saveResultsOnQualityExit
                results = createResults(self);
                mes = self.motherApp.wait('Saving Results...');
                self.motherApp.subject.logResults(results);
                close(mes);
            end
            self.isParameterTask = false;
           
            qu = 'Would you like to continue?';
            str1 = 'Yes';
            str2 = 'No. End customization.';
            
            button = self.motherApp.questdlg(qu,'Continue?',str1,str2,str1);
            if strcmpi(button,str2)
                exit(self);
            else
                goToNextTask(self);
            end
        end
        function turnOffSpeechTask(self)
            if ~isempty(self.comparisonType)
                switch self.comparisonType
                    case 'Qualitative'
                    case 'Quantitative'
                        cla(self.handleStruct.axesOldMap);
                        cla(self.handleStruct.axesNewMap);
                        set(self.handleStruct.axesOldMap,'Visible','off');
                        set(self.handleStruct.axesNewMap,'Visible','off');
                        set(self.handleStruct.status,'Visible','off');
                        set(self.handleStruct.doneButton,'Visible','off','Enable','off');
                        set(self.handleStruct.moreSpeechButton,'Visible','off','Enable','off');
                end
            end
        end
        
        function doneButton(self,varargin)
            self.endTime = now;
            if self.saveResultsOnQualityExit
                results = createResults(self);
                mes = self.motherApp.wait('Saving Results...');
                self.motherApp.subject.logResults(results);
                close(mes);
            end
            
            if self.promptToSetOnExit
                qu = 'Are you done comparing settings?';
                str2 = 'Yes. Use new settings.';
                str1 = 'Yes. Use old settings.';
                str3 = 'Cancel.';
                
                button = self.motherApp.questdlg(qu,'Done?',str1,str2,str3,str3);
                if strcmpi(button,str2)
                    turnOffSpeechTask(self);
                    setAsMap(self);
                    exit(self);
                elseif strcmpi(button,str1)
                    turnOffSpeechTask(self);
                    assignMapValues(self,'map','origMap');
                    exit(self);
                end
            end
        end
        function assignMapValues(self,toMapName,fromMapName)
%             if strcmp(toMapName,'map')
%                 keyboard
%             end
            
            % Set map with new values
            mapFields = fieldnames(self.(fromMapName).nucleusMapStructure);
            for m = 1:length(mapFields)
                self.(toMapName).nucleusMapStructure.(mapFields{m}) = ...
                    self.(fromMapName).nucleusMapStructure.(mapFields{m});
            end
            
            if strcmp(toMapName,'map')
                disp('Changing map to: ')
                self.map.nucleusMapStructure
            end
        end
        function setAsMap(self)
            % Set map with new values
            assignMapValues(self,'map','newMap');
            
            saveAndLogCurrentMap(self.subject, sprintf('customizeParameters_%f',now), sprintf('Customized parameters at time = %f.',now));
            
            self.motherApp.message('New Map Set','New parameters are now in use.');
        end
        function returnToSpeech(self,varargin)
            turnOffSpeechTask(self);

            self.endTime = now;
            if self.saveResultsOnQualityExit
                results = createResults(self);
                mes = self.motherApp.wait('Saving Results...');
                self.motherApp.subject.logResults(results);
                close(mes);
            end
            setUpSpeechTesting(self);
        end
        
        function results = createResults(self)
            resultsStruct.newMap = self.newMap.nucleusMapStructure;
            resultsStruct.startTime = self.startTime;
            resultsStruct.endTime = self.endTime;
            if ~isempty(self.comparisonType)
                switch self.comparisonType
                    case 'Qualitative'
                        resultsStruct.qualMapResults = self.qualMapResults;
                    case 'Quantitative'
                        resultsStruct.origMap = self.origMap.nucleusMapStructure;
                        resultsStruct.newMapResults = self.newMapResults;
                        resultsStruct.oldMapResults = self.oldMapResults;
                end
            else
                if self.isParameterTask
                    resultsStruct.message = ['Parameter task ' self.parameterTaskId ' completed.'];
                else
                    resultsStruct.message = 'No speech comparison was conducted.';
                end
            end
            
            results = hciResults('type',self.id,'results',resultsStruct);
        end
    end
end
