classdef hciTaskLevittAdjustSpeechVolume < hciTask
    properties
        id = 'levittAdjustSpeechVolume';
        
        startStepSize = 0.1;    % Step size in proportion of dynamic range
        currentStepSize
        reduceStepSize = 0.1;   % Reduce step by this amount after each reversal
        adaptDirection = NaN;   % Indicate whether something is too loud (-1)
                                %   too quiet (1) or comfortable (0)
        reversal = false;       % Check for reversal
        comfortableCountQuiet = 0;
        comfortableCountNoise = 0;
        numComfortableSelToStop = 3;    % Select comfortable this often, then stop
        comfortableQuietSet = false;
        comfortableNoiseSet = false;
        numTrials = 0;
        maxTrials = 50;
        stopNow = false;
        
        tokenList
        tokenDisplayList
        presentationToken
        noisyToken
        stimulusPauseTimePre = 0.1; % in seconds
        stimulusPauseTimePost = 0; % in seconds
        adaptCs
        comfortableCs
        
        promptToSetOnExit=true;
        saveResultsOnQualityExit = true;
        allowNonSettingExit = true;
        
        startTime
        endTime
        
        textFontSize = 15;

        isLocked = false;
        handleStruct
    end
    
    methods
        function self = hciTaskLevittAdjustSpeechVolume(varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
                
            if nargin~=0 && ~self.hgIsValid
                self.create();
            end
            
            setup(self);
        end
        
        function setup(self)
            self.motherApp.message(['<HTML><H1>Setting Speech Volume</H1>'...
                '<H2>This task will determine a comfortable level at which ' ...
                'to listen to speech.</H2></HTML>']);

            setupUi(self);

            if isempty(self.adaptCs)
                tsAndCs = self.map.getTsAndCs;
                self.adaptCs = tsAndCs(:,3);
                self.comfortableCs = tsAndCs(:,3);
            end
            if isempty(self.currentStepSize)
                self.currentStepSize = self.startStepSize;
            end
            [self.tokenList,self.tokenDisplayList] = hciUtilGetTokenList(hciDirsDataQualitativeSentences);
        end
        
        function setupUi(self)
            buttonFontSize = 0.4;
            buttonFontUnits = 'normalized';
            exitVisibility = {'off','on'};
            exitVisibility = exitVisibility{self.allowNonSettingExit+1};

            % Task UI
            self.handleStruct.startButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[1 1 10 10],...
                'String','Ready',...
                'FontUnits','normalized',...
                'FontSize',0.5,...
                'Callback',@self.startTask,...
                'Visible','off',...
                'Enable','off');
            self.handleStruct.status = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[1 1 10 10],...
                'String','Presenting...',...
                'FontUnits','normalized',...
                'FontSize',0.5,...
                'HorizontalAlignment','left',...
                'Visible','off');
            self.handleStruct.tokenDisplay = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[1 1 10 10],...
                'String','Token Display',...
                'FontUnits','normalized',...
                'FontSize',0.5,...
                'HorizontalAlignment','left',...
                'Visible','off');
            self.handleStruct.loudButton = uicontrol('style','pushbutton',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 10],...
                'fontUnits',buttonFontUnits,...
                'fontSize',buttonFontSize,...
                'String','Too Loud',...
                'SelectionHighlight','off',...
                'callback',@self.tooLoudButtonCallback,...
                'visible','off');
            self.handleStruct.comfortableButton = uicontrol('style','pushbutton',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 10],...
                'fontUnits',buttonFontUnits,...
                'fontSize',buttonFontSize,...
                'String','Comfortable',...
                'SelectionHighlight','off',...
                'callback',@self.comfortableButtonCallback,...
                'visible','off');
            self.handleStruct.quietButton = uicontrol('style','pushbutton',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 10],...
                'fontUnits',buttonFontUnits,...
                'fontSize',buttonFontSize,...
                'String','Too Quiet',...
                'SelectionHighlight','off',...
                'callback',@self.tooQuietButtonCallback,...
                'visible','off');

            self.handleStruct.exitButton = uicontrol('style','pushbutton',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 10],...
                'fontUnits',buttonFontUnits,...
                'fontSize',buttonFontSize,...
                'String','Quit',...
                'SelectionHighlight','off',...
                'callback',@self.exitButtonCallback,...
                'visible',exitVisibility);
            

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
            
            set(self.handleStruct.startButton,'Enable','on','Visible','on');
        end
        function resizeFunction(self, varargin)
            pos = getpixelposition(self.managedHandle); pos = pos(3:4);
            border = 10;
            buttonSize = [200 50];
            buttonBottom = border;
            textHeight = pos(2)*0.15;
            textBorder = 0.5*round(pos(1)/2);

            bottom = pos(2)-textHeight-(3*buttonSize(2));
            set(self.handleStruct.startButton,'units','pixels');
            set(self.handleStruct.startButton,'position',...
                [textBorder bottom buttonSize])
            set(self.handleStruct.startButton,'units','normalized');
            set(self.handleStruct.status,'units','pixels');
            set(self.handleStruct.status,'position',...
                [textBorder bottom buttonSize])
            set(self.handleStruct.status,'units','normalized');
            bottom = bottom - buttonSize(2);
            set(self.handleStruct.tokenDisplay,'units','pixels');
            set(self.handleStruct.tokenDisplay,'position',...
                [textBorder bottom (pos(1)-textBorder-(2*border)) buttonSize(2)])
            set(self.handleStruct.tokenDisplay,'units','normalized');
            bottom = bottom - buttonSize(2) - (2*border);
            left = textBorder;
            set(self.handleStruct.loudButton,'units','pixels');
            set(self.handleStruct.loudButton,'position',...
                [left bottom buttonSize])
            set(self.handleStruct.loudButton,'units','normalized');
            left = left + buttonSize(1) + border;
            set(self.handleStruct.comfortableButton,'units','pixels');
            set(self.handleStruct.comfortableButton,'position',...
                [left bottom buttonSize])
            set(self.handleStruct.comfortableButton,'units','normalized');
            left = left + buttonSize(1) + border;
            set(self.handleStruct.quietButton,'units','pixels');
            set(self.handleStruct.quietButton,'position',...
                [left bottom buttonSize])
            set(self.handleStruct.quietButton,'units','normalized');

            set(self.handleStruct.exitButton,'units','pixels');
            set(self.handleStruct.exitButton,'position',[border buttonBottom buttonSize])
            set(self.handleStruct.exitButton,'units','normalized');
            
            set(self.handleStruct.textHandleContainer,'units','pixels');
            set(self.handleStruct.textHandleContainer,'position',...
                [textBorder (pos(2)-textHeight) (pos(1)-(2*border)) textHeight])
            set(self.handleStruct.textHandleContainer,'units','normalized');
            
            drawnow;
        end
        function str = messageStr(self) %#ok<MANU>
            str = ['<HTML><H1>Adjust Speech Volume</H1><p>Listen to speech and ' ...
                'indicate whether it is too loud, comfortable, or too quiet.</p><p>' ...
                'Note that some of the speech will be noisy.</p></HTML>'];
        end
        
        function startTask(self,varargin)
            rng('shuffle')
            self.startTime = now;
            
            set(self.handleStruct.startButton,'Enable','off','Visible','off')
            set(self.handleStruct.loudButton,'Visible','on')
            set(self.handleStruct.comfortableButton,'Visible','on')
            set(self.handleStruct.quietButton,'Visible','on')
            setupToken(self)
            presentToken(self)
        end
        function setupToken(self)
            % Get token
            stimI = randperm(length(self.tokenList),1);
            self.presentationToken = self.tokenList{stimI};
            [tokenPath,tokenName] = fileparts(self.presentationToken);
            
            % Convert token to display format
            displayToken = hciUtilConvertTokenToDisplay(tokenName,'sentence');
            set(self.handleStruct.tokenDisplay,'String',displayToken);
        end
        function presentToken(self,varargin)
            cameInLocked = self.isLocked;
            if ~cameInLocked
                lockUi(self);
            end
            set(self.handleStruct.tokenDisplay,'Visible','on');
            
            tsAndCs = self.map.getTsAndCs();
            
            pause(self.stimulusPauseTimePre)
            if (~self.comfortableQuietSet && ~self.comfortableNoiseSet)
                addNoise = rand(1)>0.5;
            elseif self.comfortableQuietSet
                addNoise = true;
            else
                addNoise = false;
            end
            if addNoise
                noiseLevel = 0.15;      % About 10 dB SNR
                addReverb = true;
                self.noisyToken = true;
            else
                noiseLevel = 0;
                addReverb = false;
                self.noisyToken = false;
            end
            self.map.stimulateSpeechTokenWithChangedDynamicRange(...
                self.presentationToken,noiseLevel,addReverb,tsAndCs(:,2), self.adaptCs)
            pause(self.stimulusPauseTimePost)

            if ~cameInLocked
                unlockUi(self);                
            end
        end
        
        function tooLoudButtonCallback(self,varargin)
            self.numTrials = self.numTrials + 1;
            if ~isnan(self.adaptDirection)
                switch self.adaptDirection
                    case -1
                        self.reversal = false;
                    case {1,0}
                        self.reversal = true;
                        disp('Reversal occurred.')
                end
            end
            self.adaptDirection = -1;
            disp(['Adapt direction: ' num2str(self.adaptDirection)])
            
            adaptComfortLevel(self);
        end
        function comfortableButtonCallback(self,varargin)
            self.numTrials = self.numTrials + 1;
            self.reversal = false;
            self.adaptDirection = 0;
            disp(['Adapt direction: ' num2str(self.adaptDirection)])
            
            % Set comfortable count
            if self.noisyToken
                self.comfortableCountNoise = self.comfortableCountNoise + 1;
            else
                self.comfortableCountQuiet = self.comfortableCountQuiet + 1;
            end
            
            % Set comfortable Cs
            if (self.comfortableCountQuiet >= self.numComfortableSelToStop) && ...
                    ~self.comfortableQuietSet
                self.comfortableCs = min([self.comfortableCs self.adaptCs],[],2);
                self.comfortableQuietSet = true;
                disp('Comfortable Cs set at: ')
                disp(self.comfortableCs)
            end
            if (self.comfortableCountNoise >= self.numComfortableSelToStop) && ...
                    ~self.comfortableNoiseSet
                self.comfortableCs = min([self.comfortableCs self.adaptCs],[],2);
                self.comfortableNoiseSet = true;
                disp('Comfortable Cs set at: ')
                disp(self.comfortableCs)
            end
            
            adaptComfortLevel(self);
        end
        function tooQuietButtonCallback(self,varargin)
            self.numTrials = self.numTrials + 1;
            if ~isnan(self.adaptDirection)
                switch self.adaptDirection
                    case 1
                        self.reversal = false;
                    case {-1,0}
                        self.reversal = true;
                        disp('Reversal occurred.')
                end
            end
            self.adaptDirection = 1;
            disp(['Adapt direction: ' num2str(self.adaptDirection)])
            
            adaptComfortLevel(self);
        end
        function adaptComfortLevel(self,varargin)
            % Adapt C's
            if self.reversal
                self.currentStepSize = (1-self.reduceStepSize)*self.currentStepSize;
                self.reversal = false;
            end
            tsAndCs = self.map.getTsAndCs;
            dynamicRange = tsAndCs(:,3) - tsAndCs(:,2);
            cChange = dynamicRange*self.currentStepSize;
            self.adaptCs = round(self.adaptCs + (self.adaptDirection*cChange));
            
            % Check C's
            self.adaptCs(self.adaptCs <= tsAndCs(:,2)) = tsAndCs(self.adaptCs <= tsAndCs(:,2),2)+1;
            self.adaptCs(self.adaptCs > self.map.maxCLevel) = self.map.maxCLevel;
            
            % Check stopping criteria
            self.checkStoppingCriteria();
            
            % Get new token
            set(self.handleStruct.tokenDisplay,'Visible','off');
            setupToken(self);
            
            % Check stopping criterion
            if self.stopNow
                endTask(self)
            else
                presentToken(self);
            end
        end
        function checkStoppingCriteria(self)
            tsAndCs = self.map.getTsAndCs;
            dynamicRange = tsAndCs(:,3) - tsAndCs(:,2);
            cChange = dynamicRange*self.currentStepSize;
            newDR = self.adaptCs - tsAndCs(:,2);
            
            % Stop if changes are so small that no changes are being made
            %   to the C level
            disp('Ts, Original Cs, new Cs:')
            disp([tsAndCs(:,1:3) self.adaptCs])
            disp('C-Level Change:')
            disp(cChange)
            if (max(cChange) <= 1) && (self.comfortableCountQuiet > 0) && ...
                    (self.comfortableCountNoise > 0)
                self.stopNow = true;
                
            % Stop if all the C levels are at their minimum value AND
            %   'Too Loud' was selected
            elseif (isempty(find(newDR > 1))) && (self.adaptDirection == -1)
                self.stopNow = true;
                
            % Stop if the maximum number of trials has been reached
            elseif self.numTrials > self.maxTrials
                self.stopNow = true;
                
            % Stop if comfortable has been selected multiple times
            elseif (self.comfortableQuietSet && self.comfortableNoiseSet)
                self.stopNow = true;
                
            else
                self.stopNow = false;
            end
        end

        
        function endTask(self,varargin)
            display('Task done.')

            % End task
            self.endTime = now;
            if self.saveResultsOnQualityExit
                results = createResults(self);
                
                mes = self.motherApp.wait('Saving Results...');
                self.motherApp.subject.logResults(results);
                close(mes);
            end
           
            if self.promptToSetOnExit
                qu = 'Would you like to use this volume right now?';
                str1 = 'Yes';
                str2 = 'No';
                
                button = self.motherApp.questdlg(qu,'Set Now?',str1,str2,str1);
                if strcmpi(button,str1)
                    setAsMap(self);
                end
            end

            exit(self);            
        end
        function setAsMap(self)
            self.map.nucleusMapStructure.comfort_levels = self.adaptCs;

            saveAndLogCurrentMap(self.subject, ...
                sprintf('modifiedSpeechVolume_%s',datestr(now,'yyyymmddHHMMSS')),...
                sprintf('Adjust C Level to comfortable volume for speech'));
            
            self.motherApp.message('New Volume Set','New Cs are now in use.');
        end
        function results = createResults(self)
            tsAndCs = self.map.getTsAndCs;
            resultsStruct.initT = tsAndCs(:,2);
            resultsStruct.initC = tsAndCs(:,3);
            resultsStruct.c = self.adaptCs;
            resultsStruct.electrodes = tsAndCs(:,1);
            resultsStruct.startTime = self.startTime;
            resultsStruct.endTime = self.endTime;
            
            results = hciResults('type',self.id,'results',resultsStruct);
        end
        function exitButtonCallback(self,varargin)
            qu = 'Are you sure you want to discard all information and exit?';
            str1 = 'Yes. exit.';
            str2 = 'No, go back.';
            
            button = self.motherApp.questdlg(qu,'Really Exit?',str1,str2,str2);
            if strcmpi(button,str1)
                exit(self);
            end
        end
        
        function lockUi(self)
            if self.isLocked
                return
            end
            self.isLocked = true;
            
            % Disable controls
            set(self.handleStruct.status,'Visible','on')
            set(self.handleStruct.loudButton,'Enable','off')
            set(self.handleStruct.comfortableButton,'Enable','off')
            set(self.handleStruct.quietButton,'Enable','off')
            set(self.handleStruct.exitButton,'Enable','off');
        end
        function unlockUi(self)
            if ~self.isLocked
                return
            end
            
            % Disable controls
            set(self.handleStruct.status,'Visible','off')
            set(self.handleStruct.loudButton,'Enable','on')
            set(self.handleStruct.comfortableButton,'Enable','on')
            set(self.handleStruct.quietButton,'Enable','on')
            set(self.handleStruct.exitButton,'Enable','on');

            self.isLocked = false;
        end

    end
end