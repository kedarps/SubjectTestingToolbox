classdef hciTaskSetPulseRate < hciTask
    properties
        id = 'setPulseRate';
        
        pulseRateRange = [];
        
        pulseRate = [];
        pulseRateRound = 100;
        maxPulseRateChange = inf;
        pulseRateLoudnessGrowthFcnT;
        pulseRateLoudnessGrowthFcnC;
        
        speechTokenList     % Play speech for c-level adjustment
        
        pulseRateStartDrag = [];
        
        normalizedSliderVal
        
        textFontSize = 15;
        
        actionOrientation = 'right'; % Decide which side buttons are on (left or right)
        
        startTime
        endTime
        
        saveResultsOnQualityExit = true;
        allowNonSettingExit = true;
        promptToSetOnExit = true;
                
        isLocked = false;
        images
        handleStruct
    end
    
    methods
        function self = hciTaskSetPulseRate(varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
            
            if nargin~=0 && ~self.hgIsValid
                self.create();
            end
            
            setup(self);
        end
        
        function setup(self)
            self.pulseRateRange = getPulseRateRange(self.map);
            self.pulseRate = self.map.getPulseRate;
            self.pulseRate = self.pulseRateRound*round(self.pulseRate/self.pulseRateRound); % Round initial value incase it wasn't rounded

            % Determine loudness growth by pulse rate
            measurePulseRateRangeTsAndCs(self);
            
            self.motherApp.message(['<HTML><H1>Setting Pulse Rate</H1>'...
                '<H2>Pulse rate can affect the pleasantness and clarity of ' ...
                'sound. Higher pulse rates may sound squeakier while low pulse ' ...
                'rates may sound deeper. No one pulse rate is best for everyone. This ' ...
                'task lets you select what sounds best to you.</H2></HTML>']);

            setupUi(self);
            
            setupAxes(self);
            
            selectTokenList(self);
            
            self.startTime = now;
        end
        
        function measurePulseRateRangeTsAndCs(self)
                
            self.motherApp.message(['<HTML><H1>Setting Pulse Rate</H1>'...
                '<H2>The effect of pulse rate on loudness must be measured ' ...
                'before adjusting pulse rate. To do this we will:</H2>' ...
                '<H2>1) Determine your comfortable loudness range for a low pulse rate</H2>' ...
                '<H2>2) Determine your comfortable loundess range for a high pulse rate</H2></HTML>']);
            
            measPulseRates = self.pulseRateRange;
            for iPulseRate = 1:length(measPulseRates)
                cRate = measPulseRates(iPulseRate);
                cTaskFun = @hciTaskSetTsAndCs;
                otherInputs = {...
                    'stimulateTsType','pulses',...
                    'stimulateCsType','pulses',...
                    'gap',4,...
                    'showMessage',false,...
                    'promptToSetOnExit',false,...
                    'allowNonSettingExit',false,...
                    'saveResultsOnQualityExit',false,...
                    'pulseRate',cRate};
                
                subTaskObj = self.subTask(cTaskFun, otherInputs);
                
                results = createResults(subTaskObj);
               
                validE = ~isnan(results.results.initT);
                deltaT(iPulseRate) = round(median(results.results.t(validE) - ...
                    results.results.initT(validE)));
                deltaC(iPulseRate) = round(median(results.results.c(validE) - ...
                    results.results.initC(validE)));
            end
            
            % Assume linear effect on T's and C's
            self.pulseRateLoudnessGrowthFcnT = polyfit(measPulseRates,...
                deltaT,1);
            self.pulseRateLoudnessGrowthFcnC = polyfit(measPulseRates,...
                deltaC,1);
%             % Debug without measuring T and C growth function
%             self.pulseRateLoudnessGrowthFcnT = polyfit(measPulseRates,...
%                 [-10 0],1);
%             self.pulseRateLoudnessGrowthFcnC = polyfit(measPulseRates,...
%                 [-10 0],1);
        end
        
        function setupAxes(self)

            %self.images.mouse = imfilter(self.resources.images.mouse,fspecial('unsharp'),'symmetric');
            %self.images.elephant = imfilter(self.resources.images.elephant,fspecial('gaussian',[31 31],15),'symmetric');
            
            self.images.mouse = self.resources.images.mouse;
            self.images.elephant = self.resources.images.elephant;
            
            transparentColor = get(self.managedHandle,'BackgroundColor')*255;
            whiteThresh = 10;
            makeTransparent = (abs(255-self.images.mouse(:,:,1))<whiteThresh) & (255-abs(self.images.mouse(:,:,2))<whiteThresh) &  (255-abs(self.images.mouse(:,:,3))<whiteThresh);
            for iChan = 1:3
                cIm = self.images.mouse(:,:,iChan);
                cIm(makeTransparent) = transparentColor(iChan);
                self.images.mouse(:,:,iChan) = cIm;
            end
                
            %makeTransparent = self.images.elephant(:,:,1)==255 & self.images.elephant(:,:,2)==255 & self.images.elephant(:,:,3)==255;
            makeTransparent = (abs(255-self.images.elephant(:,:,1))<whiteThresh) & (255-abs(self.images.elephant(:,:,2))<whiteThresh) &  (255-abs(self.images.elephant(:,:,3))<whiteThresh);
            for iChan = 1:3
                cIm = self.images.elephant(:,:,iChan);
                cIm(makeTransparent) = transparentColor(iChan);
                self.images.elephant(:,:,iChan) = cIm;
            end
            
            
            yMin = 0.15;
            yMax = 1;
            xMin = 0;
            xMax = 1;
            imSize = [size(self.images.mouse,1), size(self.images.mouse,2)];
            
            self.images.imX = linspace(xMin, xMax, imSize(2));
            self.images.imY = fliplr(linspace(yMin, yMax, imSize(1)));
            
            cAlpha = self.lineValueToNormalizedLineValue(self.pulseRate);
            
            self.handleStruct.imageHandle = image(self.images.imX,self.images.imY, self.images.mouse*cAlpha + (1-cAlpha)*self.images.elephant,'parent',self.handleStruct.axes);
            axis xy
            set(self.handleStruct.axes,'visible','off');
            
            xlim(self.handleStruct.axes,[0 1]);
            ylim(self.handleStruct.axes,[0 1]);
            
            settingWidth = 0.01;
            self.handleStruct.backgroundPatch = patch(...
                [0 1 1 0 0]+[-1 1 1 -1 -1]*settingWidth,...
                [-1 -1 1 1 -1]*0.05 + 0.1,...
                self.resources.colors.grayDark,...
                'parent',self.handleStruct.axes,...
                'edgeColor','none');
            self.handleStruct.backgroundPatch2 = patch(...
                [0 1 1 0 0]*0.5+[-1 1 1 -1 -1]*settingWidth,...
                [-1 -1 1 1 -1]*0.05 + 0.1,...
                self.resources.colors.blue,...
                'parent',self.handleStruct.axes,...
                'edgeColor','none');
            self.handleStruct.settingPatch = patch(...
                settingWidth*[-1 1 1 -1 -1] + 0.5,[-1 -1 1 1 -1]*0.05 + 0.1,...
                self.resources.colors.green,...
                'parent',self.handleStruct.axes,...
                'buttonDownFcn',@self.lineDragStartFunc,...
                'edgeColor','none');
            
            % Provide pulse rate indicators
            numPR = diff(self.pulseRateRange)/self.pulseRateRound;
            pulseRateLoc = linspace(0,1,numPR+1)-(0.5*settingWidth)-0.0025;
            yLoc = 0.025;
            self.handleStruct.pulseRateIndicators = text(...
                pulseRateLoc, yLoc*ones(size(pulseRateLoc)),'^',...
                'Parent',self.handleStruct.axes,...
                'FontSize',16,...
                'Interpreter','none');
            
            moveSettingPatch(self, self.pulseRate);
        end
        
        function moveSettingPatch(self, val)
            self.normalizedSliderVal = self.lineValueToNormalizedLineValue(val);
            
            moveSettingPatchNormalized(self, self.normalizedSliderVal);
        end
        
        function moveSettingPatchNormalized(self, val)
            settingWidth = 0.01;
            set(self.handleStruct.settingPatch,'XData',settingWidth*[-1 1 1 -1 -1] + val);
            set(self.handleStruct.backgroundPatch2,'XData',[0 1 1 0 0]*val+[-1 1 1 -1 -1]*settingWidth);
        end
        
        function lineDragStartFunc(self,varargin)
            set(self.motherApp.handleStruct.figure,...
                'windowButtonMotionFcn',@self.lineDragFunc);
            set(self.motherApp.handleStruct.figure,...
                'WindowButtonUpFcn',@self.lineDragStopFunc);
            
            self.pulseRateStartDrag = self.pulseRate;
        end
        function lineDragStopFunc(self,varargin)
            set(self.motherApp.handleStruct.figure,...
                'windowButtonMotionFcn',[],...
                'WindowButtonUpFcn',[]);
            
            self.pulseRate = self.normalizedLineValueToLineValue(self.normalizedSliderVal);
           
            stimulate(self);
        end
        function lineDragFunc(self,varargin)
            cp = get(self.handleStruct.axes,'currentPoint');
            cp = cp(1,1);
            cp = max(min(cp(1),1),0);
            
            unNormalizedVal = normalizedLineValueToLineValue(self, cp);
            unNormalizedVal = self.pulseRateRound*round(unNormalizedVal/self.pulseRateRound);
            
            cChange = unNormalizedVal-self.pulseRateStartDrag;
            
            if abs(cChange) > self.maxPulseRateChange
                unNormalizedVal = min(max(sign(cChange)*self.maxPulseRateChange + self.pulseRateStartDrag, self.pulseRateRange(1)),self.pulseRateRange(2));
            end
            
            self.normalizedSliderVal = lineValueToNormalizedLineValue(self, unNormalizedVal);
            
            set(self.handleStruct.imageHandle,'CData',self.images.mouse*self.normalizedSliderVal + (1-self.normalizedSliderVal)*self.images.elephant);
            
            moveSettingPatchNormalized(self, self.normalizedSliderVal);
        end
        function normVal = lineValueToNormalizedLineValue(self, val)
           normVal = (val-self.pulseRateRange(1))./(self.pulseRateRange(2)-self.pulseRateRange(1));
        end
        function val = normalizedLineValueToLineValue(self, normVal)
           val = self.pulseRateRange(1) + max(min(normVal,1),0)*(self.pulseRateRange(2)-self.pulseRateRange(1));
        end
        
        function selectTokenList(self)
            %#FIXME! (eventually)
            % Eventually this should be a drop down box with which subjects
            % can select the speech that they would like to use to adjust
            % their maps.  For now, is hard coded.
            tokenList = hciUtilGetTokenList(hciDirsDataQualitativeSentences);
            self.speechTokenList = tokenList;
        end

        function stimulate(self)
            cameInLocked = self.isLocked;
            if ~cameInLocked
                lockUi(self);
            end
            set(self.handleStruct.settingPatch,'FaceColor',self.resources.colors.greenLight);
            drawnow;
                         
            % Select stimulus
            stimI = randperm(length(self.speechTokenList),1);

            self.map.stimulatePulseRate(...
                self.pulseRate,...
                self.pulseRateLoudnessGrowthFcnT,...
                self.pulseRateLoudnessGrowthFcnC,...
                self.speechTokenList{stimI});
            
            if self.map.catestrophicFailure
                return
            end
            set(self.handleStruct.settingPatch,'FaceColor',self.resources.colors.green);
            if ~cameInLocked
                unlockUi(self);
            end
        end
        function setupUi(self)
            self.handleStruct.axes = axes('parent',self.managedHandle,...
                'units','normalized',...
                'position',[0.1 0.1 0.8 0.8],'visible','off');
            
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
            
            [self.handleStruct.textHandle, self.handleStruct.textHandleContainer]  = javacomponent('javax.swing.JLabel',[1 1 1 1], self.managedHandle);
            backgroundColor = get(self.managedHandle,'BackgroundColor');
            set(self.handleStruct.textHandle,'Text',self.messageStr,'Background',java.awt.Color(backgroundColor(1),backgroundColor(2),backgroundColor(3)),...
                'Font',java.awt.Font('sansserif',java.awt.Font.PLAIN,self.textFontSize));
            self.handleStruct.textHandle.setVerticalAlignment(javax.swing.JLabel.TOP);
            
            set(self.managedHandle,'ResizeFcn',@self.resizeFunction)
            self.resizeFunction();
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
            
            set(self.handleStruct.exitButton,'units','pixels');
            set(self.handleStruct.exitButton,'position',[buttonLeft buttonBottom buttonSize])
            set(self.handleStruct.exitButton,'units','normalized');
            
            set(self.handleStruct.finishedButton,'units','pixels');
            set(self.handleStruct.finishedButton,'position',[buttonLeft buttonTop-buttonSize(2) buttonSize])
            set(self.handleStruct.finishedButton,'units','normalized');
            
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
                    disp('Pulse Rate has been updated to %d', self.pulseRate);
                    disp(' ');
                end
                
                mes = self.motherApp.wait('Saving Results...');
                self.motherApp.subject.logResults(results);
                close(mes);
            end
            
            if self.promptToSetOnExit
                qu = 'Would you like to use this pulse rate now?';
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
            self.map.setPulseRate(...
                self.pulseRate,...
                self.pulseRateLoudnessGrowthFcnT,...
                self.pulseRateLoudnessGrowthFcnC);
            
            saveAndLogCurrentMap(self.subject, sprintf('setPulseRate_%d',self.pulseRate), sprintf('Manualy selected pulse rate = %d.',self.pulseRate));
            
            self.motherApp.message('New Map Set','New pulse rate is now in use.');
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
            resultsStruct.pulseRate = self.pulseRate;
            resultsStruct.startTime = self.startTime;
            resultsStruct.endTime = self.endTime;
            
            results = hciResults('type',self.id,'results',resultsStruct);
        end
        function str = messageStr(self) %#ok<MANU>
            str = '<HTML><H1>Setting Pulse Rate</H1><p>Use the slider below to select a new pulse rate.</p><p>When you find the one that sounds best to you, click "Save and Quit".</p></HTML>';
        end
        
        function lockUi(self)
            if self.isLocked
                return
            end
            self.isLocked = true;
            
            set(self.handleStruct.settingPatch,'buttonDownFcn',[]);
            set(self.handleStruct.finishedButton,'callback',[]);
            set(self.handleStruct.exitButton,'callback',[]);
        end
        function unlockUi(self)
            if ~self.isLocked
                return
            end
            set(self.handleStruct.settingPatch,'buttonDownFcn',@self.lineDragStartFunc);
            set(self.handleStruct.finishedButton,'callback',@self.finishedButtonCallback);
            set(self.handleStruct.exitButton,'callback',@self.exitButtonCallback);
            
            self.isLocked = false;
        end
    end
end


