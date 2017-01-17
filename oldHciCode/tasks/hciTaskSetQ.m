classdef hciTaskSetQ < hciTask
    properties
        id = 'setQ';
        
        currentInd = [];
        electrode = [];
        Q = 20;
        alpha = [];

        speechTokenList     % Play speech for Q adjustment
        seqsForQs           % Generate sequence for each Q
        noisySeqsForQs      % Generate noisy equivalents for sequences
        veryNoisySeqsForQs  % Generate very noisy equivalents for sequences
        noiseLevel          % Selected noise level
        
        possibleQs = [10:5:25 30:10:50];
%         possibleQs = [10:10:50];
        possibleAlphas = [];
        
        lineHandles 
        
        actionOrientation = 'right'; % Decide which side buttons are on (left or right)
        
        textFontSize = 15;
        
        startTime
        endTime
        
        saveResultsOnQualityExit = true;
        allowNonSettingExit = true;
        promptToSetOnExit = true;
        
        isLocked = false;
        handleStruct
    end
    
    methods
        function self = hciTaskSetQ(varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
                
            if nargin~=0 && ~self.hgIsValid
                self.create();
            end
            
            setup(self);
        end
        
        function setup(self)
            if isempty(self.noiseLevel)
                self.noiseLevel = 'none';
            end
            
            setupUi(self);
            
            if isempty(self.electrode)
                tsAndCs = self.map.getTsAndCs;
                self.electrode = round(median(tsAndCs(:,1)));
            end
            
            self.lineHandles = zeros(length(self.possibleQs),1);
            self.possibleAlphas = zeros(length(self.possibleQs),1);
            for iQ = 1:length(self.possibleQs)
                cQ = self.possibleQs(iQ);
                [x,y, self.possibleAlphas(iQ)] = self.map.getLoudnessGrowthCurve(cQ);
                self.lineHandles(iQ) = line(...
                    'parent',self.handleStruct.axes,...
                    'XData',x,...
                    'YData',y,...
                    'linewidth',1,...
                    'color',self.resources.colors.grayDark,...
                    'ButtonDownFcn',@(h,e)self.lineCallback(iQ));
            end
            
            [~, self.currentInd] = min(abs(self.Q - self.possibleQs));
            self.lineCallback(self.currentInd);
            xlabel(self.handleStruct.axes,'Input','FontSize',self.textFontSize);
            ylabel(self.handleStruct.axes,'Output','FontSize',self.textFontSize);
            grid(self.handleStruct.axes,'on');

            % Choose a token and process for all Q's
            selectTokenList(self)
            stimI = randperm(length(self.speechTokenList),1);
            generateSequences(self,self.speechTokenList{stimI})
            [tokenPath, tokenFile] = fileparts(self.speechTokenList{stimI});
            disp(['Selected token: ' tokenFile])

            self.startTime = now;
        end
        function lineCallback(self, ind)
            % Disable clicking until sound is complete
            cameInLocked = self.isLocked;
            if ~cameInLocked
                lockUi(self);
            end
            
            % Unhighlight previous line
            unhighlightLine(self, self.currentInd);
            
            % Indicate that stimulation is happening on new line
            indicateStimulationLine(self, ind);
            drawnow
            
            self.Q = self.possibleQs(ind);
            self.alpha = self.possibleAlphas(ind);
            self.currentInd = ind;
            
            if ~isempty(self.seqsForQs)
                switch self.noiseLevel
                    case 'none'
                        self.map.stimulateLoudnessGrowth(self.Q, self.seqsForQs(ind));
                    case 'little'
                        self.map.stimulateLoudnessGrowth(self.Q, self.noisySeqsForQs(ind));
                    case 'lots'
                        self.map.stimulateLoudnessGrowth(self.Q, self.veryNoisySeqsForQs(ind));
                end
            end
            
            if self.map.catestrophicFailure
                return
            end
            
            % Change line to selection indication
            highlightLine(self, ind);

            % Re-enable clicking
            if ~cameInLocked
                unlockUi(self);
            end
        end
        function unhighlightLine(self, ind)
            set(self.lineHandles(ind),'LineWidth',1,'color',self.resources.colors.grayDark);
        end
        function highlightLine(self, ind)
            set(self.lineHandles(ind),'LineWidth',4,'color',self.resources.colors.red);
        end
        function indicateStimulationLine(self, ind)
            set(self.lineHandles(ind),'LineWidth',4,'color',self.resources.colors.greenLight);
        end
        function generateSequences(self,token)
            % Preprocess token for each Q value
            [self.seqsForQs, self.noisySeqsForQs, self.veryNoisySeqsForQs] = ...
                self.map.generateLoudnessGrowthStimuli(self.possibleQs,token);
        end
        
        function selectTokenList(self)
            %#FIXME! (eventually)
            % Eventually this should be a drop down box with which subjects
            % can select the speech that they would like to use to adjust
            % their maps.  For now, is hard coded.
            tokenList = hciUtilGetTokenList(hciDirsDataQualitativeSentences);
            self.speechTokenList = tokenList;
        end
            
        function setupUi(self)
            self.handleStruct.axes = axes('parent',self.managedHandle,...
                'units','normalized',...
                'position',[0.1 0.1 0.8 0.8]);
            
            buttonFontSize = 0.25;
            buttonFontUnits = 'normalized';
            
            exitVisibility = {'off','on'};
            exitVisibility = exitVisibility{self.allowNonSettingExit+1};
            
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
            
            self.handleStruct.finishedButton = uicontrol('style','pushbutton',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 10],...
                'String','Save and Quit',...
                'fontUnits',buttonFontUnits,...
                'fontSize',buttonFontSize,...
                'SelectionHighlight','off',...    
                'callback',@self.finishedButtonCallback,...
                'visible','on');

            self.handleStruct.selectNewToken = uicontrol('style','pushbutton',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 10],...
                'String','Play New Speech',...
                'fontUnits',buttonFontUnits,...
                'fontSize',buttonFontSize,...
                'SelectionHighlight','off',...
                'callback',@self.selectNewToken,...
                'visible','on');

            self.handleStruct.addNoiseStr = uicontrol('style','text',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 10],...
                'String','Add Noise to Speech',...
                'FontUnits','normalized',...
                'FontSize',0.35,...
                'HorizontalAlignment','left',...
                'visible','on');
            self.handleStruct.addNoise = uicontrol('Style','popupmenu',...
                'Parent',self.managedHandle,...
                'String',{  'None',...
                            'A Little Noise',...
                            'Lots of Noise'},...
                'units','pixels',...
                'position',[1 1 10 10],...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.getNoiseLevel,...
                'Value',2,...               % Force user to listen to noise
                'visible','on');

            [self.handleStruct.textHandle, self.handleStruct.textHandleContainer]  = javacomponent('javax.swing.JLabel',[1 1 1 1], self.managedHandle);
            backgroundColor = get(self.managedHandle,'BackgroundColor');
            set(self.handleStruct.textHandle,'Text',self.messageStr,'Background',java.awt.Color(backgroundColor(1),backgroundColor(2),backgroundColor(3)),...
                'Font',java.awt.Font('sansserif',java.awt.Font.PLAIN,self.textFontSize));
            self.handleStruct.textHandle.setVerticalAlignment(javax.swing.JLabel.TOP);
            
            self.motherApp.message(['<HTML><H1>Setting Loudness Growth</H1>'...
                '<H2>Choosing how loudness grows is a trade off between how ' ...
                'clearly you understand speech in quiet and speech in noise.</H2></HTML>']);
            drawnow;
            
            set(self.managedHandle,'ResizeFcn',@self.resizeFunction)
            self.resizeFunction();
            
%             set(self.handleStruct.finishedButton,'Visible','on');
            
        end
        function resizeFunction(self,varargin)
   
            pos = getpixelposition(self.managedHandle); pos = pos(3:4);
            
            border = 10;
            buttonSize = [200 50];
            
            buttonBottom = border;
            
            textHeight = pos(2)*0.15;
            
            if strcmp(self.actionOrientation,'left')
                axesLeft = border*2+buttonSize(1);
                axesWidth = pos(1)-axesLeft-border;
            else
                axesLeft = border;
                axesWidth = pos(1)-(border*3)-buttonSize(1);
            end
            axesHeight = pos(2)-textHeight-border*2;
            
            set(self.handleStruct.axes,'units','pixels');
            set(self.handleStruct.axes,'outerposition',[axesLeft border axesWidth, axesHeight])
            axesPos = get(self.handleStruct.axes,'position');
            set(self.handleStruct.axes,'units','normalized');
            
            buttonTop = axesPos(2)+axesPos(4);
            textLeft = axesPos(1);
            
            if strcmp(self.actionOrientation,'left')
                buttonLeft = border;
            else
                buttonLeft = axesWidth+border;
            end
            checkboxLeft = buttonLeft + border;
            
            set(self.handleStruct.exitButton,'units','pixels');
            set(self.handleStruct.exitButton,'position',[buttonLeft buttonBottom buttonSize])
            set(self.handleStruct.exitButton,'units','normalized');
            
            set(self.handleStruct.finishedButton,'units','pixels');
            set(self.handleStruct.finishedButton,'position',[buttonLeft buttonTop-buttonSize(2) buttonSize])
            set(self.handleStruct.finishedButton,'units','normalized');

            set(self.handleStruct.selectNewToken,'units','pixels');
            set(self.handleStruct.selectNewToken,'position',[buttonLeft buttonTop-3*buttonSize(2) buttonSize])
            set(self.handleStruct.selectNewToken,'units','normalized');

            set(self.handleStruct.addNoiseStr,'units','pixels');
            set(self.handleStruct.addNoiseStr,'position',[checkboxLeft buttonTop-5*buttonSize(2) buttonSize])
            set(self.handleStruct.addNoiseStr,'units','normalized');
            set(self.handleStruct.addNoise,'units','pixels');
            set(self.handleStruct.addNoise,'position',[checkboxLeft buttonTop-5.5*buttonSize(2) buttonSize])
            set(self.handleStruct.addNoise,'units','normalized');

            set(self.handleStruct.textHandleContainer,'units','pixels');
            set(self.handleStruct.textHandleContainer,'position',[textLeft border*2+axesHeight axesWidth textHeight])
            set(self.handleStruct.textHandleContainer,'units','normalized');
        end
        function finishedButtonCallback(self, varargin)
           
            self.endTime = now;
            if self.saveResultsOnQualityExit
                results = createResults(self);
                
                if self.verboseText
                    disp(' ');
                    disp('Q has been updated to %d', self.Q);
                    disp(' ');
                end
                
                mes = self.motherApp.wait('Saving Results...');
                self.motherApp.subject.logResults(results);
                close(mes);
            end
            
            if self.promptToSetOnExit
                qu = 'Would you like to use this loudness growth function now?';
                str1 = 'Yes';
                str2 = 'No';
           
                button = self.motherApp.questdlg(qu,'Set Now?',str1,str2,str1);
                if strcmpi(button,str1)
                    setAsMap(self);
                end
            end
            
            exit(self);
        end
        function selectNewToken(self,varargin)
            % Choose a token and process for all Q's
            selectTokenList(self)
            stimI = randperm(length(self.speechTokenList),1);
            generateSequences(self,self.speechTokenList{stimI});
            
            [tokenPath, tokenFile] = fileparts(self.speechTokenList{stimI});
            disp(['Selected token: ' tokenFile])
            
            [~, self.currentInd] = min(abs(self.Q - self.possibleQs));
            self.lineCallback(self.currentInd);
        end
        function getNoiseLevel(self,varargin)
            popupResponse = get(varargin{1});
            switch popupResponse.Value
                case 1
                    disp('No noise...')
                    self.noiseLevel = 'none';
                case 2
                    disp('A little noise...')
                    self.noiseLevel = 'little';     % About 20 dB SNR
                case 3
                    disp('Lots of noise...')
                    self.noiseLevel = 'lots';     % About 10 dB SNR
            end
            self.lineCallback(self.currentInd);
        end
        
        function setAsMap(self)
            self.map.setQ(self.Q);
            
            saveAndLogCurrentMap(self.subject, sprintf('setQ_%d',self.Q), sprintf('Manualy selected loudness growth function Q=%d.',self.Q));
            
            self.motherApp.message('New Map Set','New loudness growth function is now in use.');
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
        
        function results = createResults(self)
            resultsStruct.Q = self.Q;
            resultsStruct.alpha = self.alpha;
            resultsStruct.startTime = self.startTime;
            resultsStruct.endTime = self.endTime;
            
            results = hciResults('type',self.id,'results',resultsStruct);
        end        
        function str = messageStr(self) %#ok<MANU>
            str = ['<HTML><H1>Setting Loudness Growth</H1>' ...
                '<p>Select the line that makes the speech sound the clearest.</p><p>' ...
                'When you are done click "Save and Quit".</p></HTML>'];
        end
        
        function lockUi(self)
            if self.isLocked
                return
            end
            self.isLocked = true;
            
            for iQ = 1:length(self.possibleQs)
                set(self.lineHandles(iQ),'ButtonDownFcn',[]);
            end
            
            set(self.handleStruct.exitButton,'callback',[]);
            set(self.handleStruct.finishedButton,'callback',[]);
            set(self.handleStruct.selectNewToken,'callback',[]);
        end
        function unlockUi(self)
            if ~self.isLocked
                return
            end
            
            for iQ = 1:length(self.possibleQs)
                set(self.lineHandles(iQ),'ButtonDownFcn',@(h,e)self.lineCallback(iQ));
            end
            
            set(self.handleStruct.finishedButton,'callback',@self.finishedButtonCallback);
            set(self.handleStruct.exitButton,'callback',@self.exitButtonCallback);
            set(self.handleStruct.selectNewToken,'callback',@self.selectNewToken);
            
            self.isLocked = false;
        end
    end
end