classdef hciTaskSetTsAndCs < hciTask
    properties
        id = 'tsAndCs';
       
        saveResultsOnQualityExit = true;
        promptToSetOnExit = true;
        allowNonSettingExit = true;
        forceStimulatingAllTs = false;
        showPlayAllButton = false;
        showMessage = true;
        
        startTime
        endTime
        
        actionOrientation = 'right'; % Decide which side buttons are on (left or right)
        
        initT
        initC
        
        stimulateTsType = 'pulses'; % possibilities = {'pulses', 'sweep'};
        stimulateCsType = 'pulses'; % possibilities = {'pulses', 'sweep', 'speech'};

        t
        c
        electrodes
        measElectrodes      % List of electrodes with NaNs for turned off electrodes
        gap = 2;            % Gap between electrodes to set
        
        pulseRate
        tStimulusDuration = 0.5; % In seconds original lmc
        cStimulusDuration = 0.5; % In seconds
        sweepStimulusDuration = 1; % In seconds
        speechTokenList     % Play speech for c-level adjustment
        noiseLevel          % Used to test pulse train ts/cs
        
        markerSize = 12;
        
        nElectrodes = [];
        settableElectrodes
        
        maxTChange = 10; % In Current Steps
        maxCChange = 10;
        maxCChangeSteps = 1; % nSteps
        cStepSize = 2; % In Current Steps
        
        maxSetTChange =  1; % This is itertaive and things can drift a lot.
        maxSetCChange =  1;
        
        playAllInterStimPauseTime = 0.3; % In seconds
        
        tStartClick
        cStartClick
        
        maxVal = 255;
        minVal = 1;
        
        changeSmoothingFilter = fspecial('gaussian',[11,1],1); % These were hand tweaked
        
        modeIsT = true;
        
        beenModifiedCs = false;
        beenModifiedTs = false;
        hasBeenSetTValue = [];
        hasPlayedT = [];
        
        hasBeenSetT = [];
        hasBeenSetC = [];
        
        cRecentChange = [];
        
        textFontSize = 15;
        
        isLocked = false;
        handleStruct
    end
    properties (Access = 'private')
        currentlyDraggedElectrode = [];
        currentlyDraggedCElectrode = [];
    end
    properties (Hidden, Dependent, SetAccess='private')
        playAllButtonVisibility
    end

    methods
        function self = hciTaskSetTsAndCs(varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
                
            if nargin~=0 && ~self.hgIsValid
                self.create();
            end
            
            init(self);
        end
        
        function init(self)
            if isempty(self.noiseLevel)
                self.noiseLevel = 0;
            end
            
            self.handleStruct.axes = axes('parent',self.managedHandle,...
                'units','normalized',...
                'position',[0.1 0.1 0.8 0.8]);
            
            
            buttonFontSize = 0.25;
            buttonFontUnits = 'normalized';
            indicatorFontSize = 0.15;
            
            exitVisibility = {'off','on'};
            exitVisibility = exitVisibility{self.allowNonSettingExit+1};
            self.handleStruct.exitButton = uicontrol('style','pushbutton',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 10],...
                'fontUnits',buttonFontUnits,...
                'fontSize',buttonFontSize,...
                'String','Exit',...
                'SelectionHighlight','off',...
                'callback',@self.exitButtonCallback,...
                'visible',exitVisibility);
            
            self.handleStruct.switchToCsButton = uicontrol('style','pushbutton',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 20],...
                'String','Continue to Maximum Loudness',...
                'fontUnits',buttonFontUnits,...
                'fontSize',buttonFontSize,...
                'SelectionHighlight','off',...    
                'callback',@self.switchToCsButtonCallback,...
                'visible','off');
            
            self.handleStruct.playAllButton = uicontrol('style','pushbutton',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 10],...
                'String','Play All',...
                'fontUnits',buttonFontUnits,...
                'fontSize',buttonFontSize,...
                'SelectionHighlight','off',...
                'callback',@self.playAllButtonCallback,...
                'visible',self.playAllButtonVisibility);
            
            self.handleStruct.finishedButton = uicontrol('style','pushbutton',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 10],...
                'String','Finished',...
                'fontUnits',buttonFontUnits,...
                'fontSize',buttonFontSize,...
                'SelectionHighlight','off',...    
                'callback',@self.finishedButtonCallback,...
                'visible','off');
            
            self.handleStruct.switchToTsButton = uicontrol('style','pushbutton',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 10],...
                'String','Start Over',...
                'fontUnits',buttonFontUnits,...
                'fontSize',buttonFontSize,...
                'SelectionHighlight','off',...    
                'callback',@self.switchToTsButtonCallback,...
                'visible','off');
            
            % Test new Ts and Cs with speech
            self.handleStruct.playToken = uicontrol('style','pushbutton',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 10],...
                'String','Test With Speech',...
                'fontUnits',buttonFontUnits,...
                'fontSize',buttonFontSize,...
                'SelectionHighlight','off',...
                'callback',@self.playToken,...
                'visible','off',...
                'Enable','off');
            self.handleStruct.addNoiseStr = uicontrol('style','text',...
                'parent',self.managedHandle,...
                'units','pixels',...
                'position',[1 1 10 10],...
                'String','Add Noise:',...
                'FontUnits','normalized',...
                'FontSize',0.3,...
                'HorizontalAlignment','left',...
                'visible','off');
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
                'visible','off',...
                'Enable','off');
            
            [self.handleStruct.textHandle, self.handleStruct.textHandleContainer]  = javacomponent('javax.swing.JLabel',[1 1 1 1], self.managedHandle);
            backgroundColor = get(self.managedHandle,'BackgroundColor');
            set(self.handleStruct.textHandle,'Text',self.messageStrT,'Background',java.awt.Color(backgroundColor(1),backgroundColor(2),backgroundColor(3)),...
               'Font',java.awt.Font('sansserif',java.awt.Font.PLAIN,self.textFontSize));
            self.handleStruct.textHandle.setVerticalAlignment(javax.swing.JLabel.TOP);
            
            if self.showMessage
                self.motherApp.message(['<HTML><H1>Setting Threshold and Maximum Comfort Levels</H1>'...
                    '<H2>This task determines the quietest sounds that you can hear ' ...
                    'as well as the loudest sounds that are comfortable to listen to for a short time. ' ...
                    'These values will determine the loudness of sounds that you hear.</H2></HTML>']);
            end
            
            set(self.managedHandle,'ResizeFcn',@self.resizeFunction)
            self.resizeFunction();
            
            initTsAndCs(self);
        end
        function resizeFunction(self,varargin)

            pos = getpixelposition(self.managedHandle); pos = pos(3:4);
            
            border = 10;
            buttonSize = [200 50];
            buttonBorder = 10;
            
            buttonBottom = border;
            
            textHeight = pos(2)*0.16;
            
            if strcmp(self.actionOrientation,'left')
                axesLeft = border*2+buttonSize(1);
                axesWidth = pos(1)-axesLeft-border;
            else
                axesLeft = border;
                axesWidth = pos(1)-(border*3)-buttonSize(1);
            end
            axesHeight = pos(2)-textHeight-border*2;
            
            indicatorSize = [70 70];
            
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
                
            set(self.handleStruct.switchToCsButton,'units','pixels');
            set(self.handleStruct.switchToCsButton,'position',[buttonLeft buttonTop-buttonSize(2) buttonSize])
            set(self.handleStruct.switchToCsButton,'units','normalized');
            
            set(self.handleStruct.switchToTsButton,'units','pixels');
            set(self.handleStruct.switchToTsButton,'position',[buttonLeft buttonTop-buttonSize(2)*2-buttonBorder buttonSize])
            set(self.handleStruct.switchToTsButton,'units','normalized');
            
            set(self.handleStruct.finishedButton,'units','pixels');
            set(self.handleStruct.finishedButton,'position',[buttonLeft buttonTop-buttonSize(2) buttonSize])
            set(self.handleStruct.finishedButton,'units','normalized');

            set(self.handleStruct.playAllButton,'units','pixels');
            set(self.handleStruct.playAllButton,'position',[buttonLeft buttonTop-buttonSize(2)*2-buttonBorder buttonSize])
            set(self.handleStruct.playAllButton,'units','normalized');
            
%             set(self.handleStruct.playToken,'units','pixels');
%             set(self.handleStruct.playToken,'position',[buttonLeft buttonTop-5*buttonSize(2) buttonSize])
%             set(self.handleStruct.playToken,'units','normalized');            
%             set(self.handleStruct.addNoiseStr,'units','pixels');
%             set(self.handleStruct.addNoiseStr,'position',[checkboxLeft buttonTop-6.25*buttonSize(2) buttonSize])
%             set(self.handleStruct.addNoiseStr,'units','normalized');
%             set(self.handleStruct.addNoise,'units','pixels');
%             set(self.handleStruct.addNoise,'position',[checkboxLeft buttonTop-6.75*buttonSize(2) buttonSize])
%             set(self.handleStruct.addNoise,'units','normalized');

            set(self.handleStruct.textHandleContainer,'units','pixels');
            set(self.handleStruct.textHandleContainer,'position',[textLeft border*2+axesHeight axesWidth textHeight])
            set(self.handleStruct.textHandleContainer,'units','normalized');
            
        end
        
        function initTsAndCs(self)
            self.startTime = now;
            set(self.handleStruct.switchToCsButton,'Visible','on');
            
            if isempty(self.electrodes)
                self.electrodes = self.map.getElectrodes;
            end
            
            if isempty(self.nElectrodes)
                self.nElectrodes = max(self.electrodes);
            end
            
            if isempty(self.pulseRate)
                self.pulseRate = self.map.getRate;
            end
            
            tsAndCs = self.motherApp.map.getTsAndCs;
            
            self.t = nan(self.nElectrodes,1);
            self.c = nan(self.nElectrodes,1);
            self.measElectrodes = nan(self.nElectrodes,1);
            
            for iElec = 1:self.nElectrodes
                cInds = iElec == tsAndCs(:,1);
                
                switch sum(cInds)
                    case 0 
                        % Missing electrode
                    case 1 
                        cInd = find(cInds,1,'first');
                        self.measElectrodes(iElec) = tsAndCs(cInd,1);
                        self.t(iElec) = tsAndCs(cInd,2);
                        self.c(iElec) = tsAndCs(cInd,3);
                        
                    otherwise
                        error('There are weird electrodes specified in this map');
                end
            end
            
            self.initT = self.t;
            self.initC = self.c;
            
            if isempty(self.settableElectrodes)
                self.setSettableElectrodes();
            end
            
            self.hasPlayedT = ~self.settableElectrodes;
            self.hasBeenSetT = false(size(self.settableElectrodes));
            self.hasBeenSetC = false(size(self.settableElectrodes));
            self.hasBeenSetTValue = zeros(size(self.settableElectrodes));
            
            
            % Make sure the we show initial smoothing like we smooth when
            % you move. 
            % This is code duplication with lines in tLineDragFunction
            % Sorry.
            newTCurve = nan(size(self.t));
            newTCurve(self.settableElectrodes) = self.t(self.settableElectrodes);
            newTCurve(~self.settableElectrodes) = interp1(find(self.settableElectrodes),self.t(self.settableElectrodes),find(~self.settableElectrodes),'cubic');
            
            self.t = newTCurve;
            self.t(isnan(self.measElectrodes)) = NaN;
            self.c(isnan(self.measElectrodes)) = NaN;
            
            eVals = self.measElectrodes;
            self.handleStruct.tLine = line(eVals , self.t,...
                'HitTest','off',...
                'Color',self.resources.colors.grayDark,...
                'ButtonDownFcn',@self.tlineDragStartFunc);
            
            self.handleStruct.tLineMarkers = line(eVals(self.settableElectrodes), self.t(self.settableElectrodes),...
                 'HitTest','on',...
                 'Color',self.resources.colors.red,...
                 'LineStyle','none',...
                 'LineWidth',2,...
                 'Marker','^',...
                 'MarkerSize',self.markerSize,...
                 'MarkerFaceColor',self.resources.colors.red,...
                 'MarkerEdgeColor',self.resources.colors.red,...
                 'ButtonDownFcn',@self.tlineDragStartFunc);
            
            self.handleStruct.cLine = line(eVals , self.c,...
                 'HitTest','on',...
                 'LineWidth',5, ...
                 'Color',self.resources.colors.red,...
                 'ButtonDownFcn',@self.clineDragStartFunc);
            
            self.handleStruct.cLineMarkers = line(eVals(self.settableElectrodes), self.c(self.settableElectrodes),...
                 'HitTest','off',...
                 'Color',self.resources.colors.red,...
                 'LineStyle','none',...
                 'LineWidth',2,...
                 'Marker','v',...
                 'MarkerSize',self.markerSize,...
                 'MarkerFaceColor',self.resources.colors.red,...
                 'MarkerEdgeColor',self.resources.colors.red,...
                 'ButtonDownFcn',@self.clineDragStartFunc);
            
            set(self.handleStruct.axes,...
                'xlim',[min(eVals(~isnan(eVals)))-0.5, max(eVals(~isnan(eVals)))+0.5],...
                'ylim',[0 260],...
                'XTick',self.measElectrodes(~isnan(self.measElectrodes)),...
                'Box','on');
            grid(self.handleStruct.axes,'on');
            xlabel(self.handleStruct.axes,'Electrode Number','FontSize',12);
            ylabel(self.handleStruct.axes,'Loudness','FontSize',12);
            
            patchColor = self.resources.colors.gray;
            self.handleStruct.patch = patch([0 1 1 0],[0 0 1 1],patchColor,...
                'EdgeColor','none','LineWidth',3);
            
            self.setVisibleLine;
            
            redrawTsAndCs(self);
        end
        function setVisibleLine(self)
            if self.modeIsT
                switch self.stimulateTsType
                    case {'sweep','speech'}
                        % Choose which interface elements are visible
                        set(self.handleStruct.tLine,'visible','on');
                        set(self.handleStruct.tLineMarkers,'visible','off');
                        set(self.handleStruct.cLine,'visible','off');
                        set(self.handleStruct.cLineMarkers,'visible','off');
                        set(self.handleStruct.patch,'visible','off');
                        
                        % Set the interface elements that are active
                        set(self.handleStruct.tLine,...
                            'HitTest','on',...
                            'LineWidth',5, ...
                            'Color',self.resources.colors.green);
                        set(self.handleStruct.tLineMarkers,...
                            'HitTest','off');
                    case {'pulses'}
                        % Choose which interface elements are visible
                        set(self.handleStruct.tLine,'visible','on');
                        set(self.handleStruct.tLineMarkers,'visible','on');
                        set(self.handleStruct.cLine,'visible','off');
                        set(self.handleStruct.cLineMarkers,'visible','off');
                        set(self.handleStruct.patch,'visible','off');

                        % Set the interface elements that are active
                        set(self.handleStruct.tLine,...
                            'HitTest','off');
                        set(self.handleStruct.tLineMarkers,...
                            'HitTest','on');
                end
            else
                switch self.stimulateCsType
                    case {'sweep','speech'}
                        % Choose which interface elements are visible
                        set(self.handleStruct.tLine,'visible','on');
                        set(self.handleStruct.tLineMarkers,'visible','off');
                        set(self.handleStruct.cLine,'visible','on');
                        set(self.handleStruct.cLineMarkers,'visible','off');
                        set(self.handleStruct.patch,'visible','on');
                        
                        % Set the interface elements that are active
                        set(self.handleStruct.cLine,...
                            'HitTest','on',...
                            'LineWidth',5, ...
                            'Color',self.resources.colors.red);
                        set(self.handleStruct.cLineMarkers,...
                            'HitTest','off');
                    case {'pulses'}
                        % Choose which interface elements are visible
                        set(self.handleStruct.tLine,'visible','on');
                        set(self.handleStruct.tLineMarkers,'visible','off');
                        set(self.handleStruct.cLine,'visible','on');
                        set(self.handleStruct.cLineMarkers,'visible','on');
                        set(self.handleStruct.patch,'visible','on');

                        % Set the interface elements that are active
                        set(self.handleStruct.cLine,...
                            'HitTest','off',...
                            'Color',self.resources.colors.grayDark,...
                            'LineWidth',1);
                        set(self.handleStruct.cLineMarkers,...
                            'HitTest','on');
                end
            end
        end
        function setSettableElectrodes(self)
            isValid = ~isnan(self.t) & ~isnan(self.c);
            %self.settableElectrodes = isValid;
            
            self.settableElectrodes = false(size(isValid));
            
            if isempty(self.gap)
                gap = 2;
            else
                gap = self.gap;
            end
            %firstHalfInds = 1+floor(gap/2):gap:ceil(length(self.settableElectrodes)/2);
            firstHalfInds = 1:gap:ceil(length(self.settableElectrodes)/2);
            self.settableElectrodes(firstHalfInds) = true;
            self.settableElectrodes(self.nElectrodes-firstHalfInds+1) = true;
            
            %self.settableElectrodes(1:3:end) = true;
            
            settableFind = find(self.settableElectrodes);
            for iE = 1:length(settableFind)
                if ~isValid(settableFind(iE))
                    self.settableElectrodes(settableFind(iE)) = false;
                    if iE < self.nElectrodes/2
                        if isValid(settableFind(iE)+1)
                            self.settableElectrodes(settableFind(iE)+1) = true;
                        elseif settableFind(iE) > 1 && isValid(settableFind(iE)-1)
                            self.settableElectrodes(settableFind(iE)+1) = true;
                        end
                    else
                        if isValid(settableFind(iE)-1)
                            self.settableElectrodes(settableFind(iE)-1) = true;
                        elseif (settableFind(iE) < self.nElectrodes) && isValid(settableFind(iE)+1)
                            self.settableElectrodes(settableFind(iE)+1) = true;
                        end
                    end
                end
            end
        end
        
        function set.stimulateTsType(self, val)
            
            errorMessage = 'stimulateTsType must be one of the following. {''pulses'', ''sweep'', ''speech''}';
            assert(ischar(val) && ~isempty(val), errorMessage);
            assert(ismember(lower(val),{'pulses', 'sweep'}),errorMessage);
            
            self.stimulateTsType = val;
        end
        function set.stimulateCsType(self, val)
            
            errorMessage = 'stimulateTsType must be one of the following. {''pulses'', ''sweep'', ''speech''}';
            assert(ischar(val) && ~isempty(val), errorMessage);
            assert(ismember(lower(val),{'pulses', 'sweep', 'speech'}),errorMessage);

            self.stimulateCsType = val;
        end
        
        function tlineDragStartFunc(self,varargin)
            set(self.motherApp.handleStruct.figure,...
                'windowButtonMotionFcn',@self.tlineDragFunc);
            set(self.motherApp.handleStruct.figure,...
                'WindowButtonUpFcn',@self.tlineDragStopFunc);
        end
        function tlineDragStopFunc(self,varargin)
            set(self.motherApp.handleStruct.figure,...
                'windowButtonMotionFcn',[],...
                'WindowButtonUpFcn',[]);
            
            if isempty(self.currentlyDraggedElectrode)
                % Really quick click.
                % Never actually drug the electrode
                % So we should stimulate at the current level.
                % All we have to do is set currentlyDraggedElectrode
                
                cp = get(self.handleStruct.axes,'currentPoint');
                cp = cp(1,1:2);
                cElectrode = find(self.measElectrodes==round(cp(1)));
                if ~self.settableElectrodes(cElectrode)
                    return
                end
                self.currentlyDraggedElectrode = cElectrode;
            end
            
            % Play sound here
            sendTStimulus(self, self.currentlyDraggedElectrode);
            
            self.currentlyDraggedElectrode = [];
            self.tStartClick = [];
            self.cStartClick = [];
        end        
        function tlineDragFunc(self,varargin)
            % Get click position
            cp = get(self.handleStruct.axes,'currentPoint');
            cp = cp(1,1:2);
            
            switch self.stimulateTsType
                case {'sweep','speech'}
                    electrodeDiff = self.measElectrodes - cp(1);
                    [minDiff, cElectrode] = min(abs(electrodeDiff));
                case {'pulses'}
                    cElectrode = find(self.measElectrodes==round(cp(1)));
                    if ~self.settableElectrodes(cElectrode)
                        return
                    end
            end
            
            if isempty(self.currentlyDraggedElectrode)
                if isempty(cElectrode)
                    return
                else
                    self.currentlyDraggedElectrode = cElectrode;
                    self.tStartClick = self.t;
                    self.cStartClick = self.c;
                end
            end
            
            % Change T curve and/or electrode value
            tCurveInit = self.t;
            switch self.stimulateTsType
                case {'sweep'}
                    % Determine change
                    cp(2) = max(min(cp(2),self.maxVal),self.minVal);
                    tChangeTotal = cp(2)-self.tStartClick(self.currentlyDraggedElectrode);
                    if abs(tChangeTotal) > self.maxTChange
                        tChangeTotal = sign(tChangeTotal)*self.maxTChange;
                    end
                    cp(2) = tChangeTotal + self.tStartClick(self.currentlyDraggedElectrode);
                    
                    newTVal = cp(2);
                    tCurve = tCurveInit + newTVal-tCurveInit(self.currentlyDraggedElectrode);
                case {'pulses'}
                    tCurve = tCurveInit;
                    tCurve(isnan(tCurve)) = 0;
                    tChange = cp(2)-tCurveInit(self.currentlyDraggedElectrode);
                    tChangeTotal = cp(2)-self.tStartClick(self.currentlyDraggedElectrode);
                    if abs(tChangeTotal) > self.maxTChange
                        tChange = sign(tChangeTotal)*self.maxTChange + self.tStartClick(self.currentlyDraggedElectrode) -tCurveInit(self.currentlyDraggedElectrode);
                    end
                    tChangeVec = zeros(size(tCurveInit ));
                    tChangeVec(self.currentlyDraggedElectrode) = tChange;
                    tChangeVec = imfilter(tChangeVec, self.changeSmoothingFilter,'same','symmetric');
                    
                    self.hasBeenSetT(self.currentlyDraggedElectrode) = true;
                    self.hasBeenSetTValue(self.currentlyDraggedElectrode) = tCurve(self.currentlyDraggedElectrode);
            
                    if sum(self.hasBeenSetT) > 1
                        cFix = self.hasBeenSetT;
                        cFix(self.currentlyDraggedElectrode) = false;
                        
                        newTValuesAtFix = tCurve(cFix) + tChangeVec(cFix);
                        
                        changesFromStart = newTValuesAtFix-self.tStartClick(cFix);
                        signChangesFromStart = sign(changesFromStart);
                        enforceChangesFromStart = signChangesFromStart.*min(abs(changesFromStart),self.maxSetTChange);
                        
                        newTChangeVec = enforceChangesFromStart + self.tStartClick(cFix) - tCurve(cFix);
                        
                        tChangeVec(cFix) = newTChangeVec;
                    end

                    tCurve = tCurve + tChangeVec;
            
                    % This is code duplication with lines in initTsAndCs
                    % Sorry.
                    newTCurve = nan(size(tCurve));
                    newTCurve(self.settableElectrodes) = tCurve(self.settableElectrodes);
                    newTCurve(~self.settableElectrodes) = interp1(find(self.settableElectrodes),tCurve(self.settableElectrodes),find(~self.settableElectrodes),'cubic');
                    
                    tCurve = newTCurve;
            end
                    
            % Current levels should always be integers.
            tCurve = min(max(tCurve, self.minVal), self.maxVal);
            tCurve(isnan(tCurveInit)) = nan;
            
            self.t = tCurve;
            self.t(isnan(self.measElectrodes)) = NaN;
            self.beenModifiedTs = true;
            
            redrawTsAndCs(self)
        end
        
        function clineDragStartFunc(self,varargin)
            set(self.motherApp.handleStruct.figure,...
                'windowButtonMotionFcn',@self.clineDragFunc);
            set(self.motherApp.handleStruct.figure,...
                'WindowButtonUpFcn',@self.clineDragStopFunc);
        end
        function clineDragStopFunc(self,varargin)
            set(self.motherApp.handleStruct.figure,...
                'windowButtonMotionFcn',[],...
                'WindowButtonUpFcn',[]);
            
            self.cRecentChange = self.c(self.currentlyDraggedCElectrode) - ...
                self.cStartClick(self.currentlyDraggedCElectrode);
            
            if isempty(self.currentlyDraggedCElectrode)
                % Really quick click.
                % Never actually drug the electrode
                % So we should stimulate at the current level.
                % All we have to do is set currentlyDraggedElectrode
                
                cp = get(self.handleStruct.axes,'currentPoint');
                cp = cp(1,1:2);
                cElectrode = find(self.measElectrodes==round(cp(1)));
                if ~self.settableElectrodes(cElectrode)
                    return
                end
                self.currentlyDraggedCElectrode = cElectrode;
            end

            sendCStimulus(self,self.currentlyDraggedCElectrode);
            self.currentlyDraggedCElectrode = [];
            self.tStartClick = [];
            self.cStartClick = [];
        end        
        function clineDragFunc(self,varargin)
            % Get click position
            cp = get(self.handleStruct.axes,'currentPoint');
            cp = cp(1,1:2);
            switch self.stimulateCsType
                case {'sweep','speech'}
                    electrodeDiff = self.measElectrodes - cp(1);
                    [minDiff, cElectrode] = min(abs(electrodeDiff));
                case {'pulses'}
                    cElectrode = find(self.measElectrodes==round(cp(1)));
                    if ~self.settableElectrodes(cElectrode)
                        return
                    end
            end
            
            if isempty(self.currentlyDraggedCElectrode)
                if isempty(cElectrode)
                    return
                else
                    self.currentlyDraggedCElectrode = cElectrode;
                    self.tStartClick = self.t;
                    self.cStartClick = self.c;
                end
            end
            
            % Change C curve and/or electrode value
            cCurveStart = self.initC - min(self.initC - self.t) + 1;
%             cCurveStart = self.t + 1;
            cCurveInit = self.c;
            switch self.stimulateCsType
                case {'speech'}
                    % Determine whether a step has occurred
                    cp(2) = max(min(cp(2),self.maxVal),self.minVal);
                    cChangeTotal = cp(2)-self.cStartClick(self.currentlyDraggedCElectrode);
                    nSteps = fix((cChangeTotal-self.cStepSize/2)/self.cStepSize);
                    nSteps = min(nSteps,self.maxCChangeSteps); % abs removed so that you can move down as much as possible
                    
                    % Determine change, depending on whether step has occurred
                    cChangeTotal = nSteps*self.cStepSize;
                    cp(2) = cChangeTotal + self.cStartClick(self.currentlyDraggedCElectrode);
                    
                    % Adjust c-level curve by changed value
                    tCurve = self.t;
                    newCVal = cp(2);
                    cCurve = cCurveStart + newCVal-cCurveStart(self.currentlyDraggedCElectrode);
                case {'sweep'}
                    % Determine change in amplitude
                    cp(2) = max(min(cp(2),self.maxVal),self.minVal);
                    cChangeTotal = cp(2)-self.cStartClick(self.currentlyDraggedCElectrode);
                    if abs(cChangeTotal) > self.maxCChange
                        cChangeTotal = sign(cChangeTotal)*self.maxCChange;
                    end
                    cp(2) = cChangeTotal + self.cStartClick(self.currentlyDraggedCElectrode);
                    
                    % Adjust c-level curve by changed value
                    tCurve = self.t;
                    newCVal = cp(2);
                    cCurve = cCurveStart + newCVal-cCurveStart(self.currentlyDraggedCElectrode);
                case {'pulses'}
                    cCurve = cCurveInit;
                    cCurve(isnan(cCurve)) = 0;
                    cChange = cp(2)-cCurveInit(self.currentlyDraggedCElectrode);
                    cChangeTotal = cp(2)-self.cStartClick(self.currentlyDraggedCElectrode);
                    if abs(cChangeTotal) > self.maxCChange
                        cChange = sign(cChangeTotal)*self.maxCChange + self.cStartClick(self.currentlyDraggedCElectrode) - cCurveInit(self.currentlyDraggedCElectrode);
                    end
                    cChangeVec = zeros(size(cCurveInit ));
                    cChangeVec(self.currentlyDraggedCElectrode) = cChange;
                    cChangeVec = imfilter(cChangeVec, self.changeSmoothingFilter,'same','symmetric');
                    
                    self.hasBeenSetC(self.currentlyDraggedCElectrode) = true;
            
                    if sum(self.hasBeenSetC) > 1
                        cFix = self.hasBeenSetC;
                        cFix(self.currentlyDraggedCElectrode) = false;
                        
                        newCValuesAtFix = cCurve(cFix) + cChangeVec(cFix);
                        
                        changesFromStart = newCValuesAtFix-self.cStartClick(cFix);
                        signChangesFromStart = sign(changesFromStart);
                        enforceChangesFromStart = signChangesFromStart.*min(abs(changesFromStart),self.maxSetCChange);
                        
                        newCChangeVec = enforceChangesFromStart + self.cStartClick(cFix) - cCurve(cFix);
                        
                        cChangeVec(cFix) = newCChangeVec;
                    end
                    
                    cCurve = cChangeVec + cCurveInit;

                    % This is code duplication with lines in initTsAndCs
                    % Sorry.
                    newCCurve = nan(size(cCurve));
                    newCCurve(self.settableElectrodes) = cCurve(self.settableElectrodes);
                    newCCurve(~self.settableElectrodes) = interp1(find(self.settableElectrodes),cCurve(self.settableElectrodes),find(~self.settableElectrodes),'cubic');
                    
                    cCurve = newCCurve;
            end

            tCurve = self.t;
            cCurve = min(max(cCurve, tCurve + 1), self.maxVal);
            
            self.c = cCurve;
            self.c(isnan(self.measElectrodes)) = NaN;
            self.beenModifiedCs = true;
            
            redrawTsAndCs(self);
        end
        
        function redrawTsAndCs(self)
            cT = self.t; 
            cC = self.c;
            cE = self.measElectrodes;
            
            nanSpotsLogical = isnan(cT) | isnan(cC) | isnan(cE);
            nNansBefore = max(cumsum(nanSpotsLogical)-1,0);
            plotT = cT;
            plotC = cC;
            plotE = cE;
            for iE = 1:length(cE)
                if nanSpotsLogical(iE)
                    cLoc = (iE+nNansBefore(iE));
                    
                    plotT(cLoc) = 0;    
                    plotC(cLoc) = 0;
                    if iE > 1 && ~nanSpotsLogical(iE-1)
                        plotE(cLoc) = iE-1;
                    %elseif iE == 2
                    %    plotE(cLoc) = 0.5;
                    else
                        plotE(cLoc) = iE;
                    end
                    if cLoc < length(plotT)
                        plotT = cat(1,plotT(1:cLoc),0,plotT((cLoc+1):end));
                        plotC = cat(1,plotC(1:cLoc),0,plotC((cLoc+1):end));
                        plotE = cat(1,plotE(1:cLoc),iE+1,plotE((cLoc+1):end));
                    end
                end
            end
            
            % Make the edges look nice
            if self.nElectrodes > 1
                plotE = cat(1,plotE(1)-0.5,plotE,plotE(end)+0.5);
                tSlopeStart = -(plotT(2)-plotT(1))./(plotE(2)-plotE(1));
                tSlopeStop = (plotT(end)-plotT(end-1))./(plotE(end)-plotE(end-1));
                plotT = cat(1,plotT(1)+tSlopeStart*0.25,plotT,plotT(end)+tSlopeStop*0.25);
                cSlopeStart = -(plotC(2)-plotC(1))./(plotE(2)-plotE(1));
                cSlopeStop = (plotC(end)-plotC(end-1))./(plotE(end)-plotE(end-1));
                plotC = cat(1,plotC(1)+cSlopeStart*0.25,plotC,plotC(end)+cSlopeStop*0.25);
            end
            
            
            set(self.handleStruct.patch,...
                'YData',cat(1,plotT,flipud(plotC)),...
                'XData',cat(1,plotE,flipud(plotE)));
            
            plotC(plotC==0) = nan;
            plotT(plotT==0) = nan;
            
            set(self.handleStruct.cLine,'YData',plotC,'XData',plotE); % set(self.handleStruct.cLine,'YData',self.c);
            set(self.handleStruct.tLine,'YData',plotT,'XData',plotE); % set(self.handleStruct.tLine,'YData',self.t);
            set(self.handleStruct.cLineMarkers,'YData',self.c(self.settableElectrodes));
            set(self.handleStruct.tLineMarkers,'YData',self.t(self.settableElectrodes));
            
            set(self.handleStruct.axes,'children',cat(1,self.handleStruct.cLineMarkers, self.handleStruct.tLineMarkers, self.handleStruct.cLine,self.handleStruct.tLine,self.handleStruct.patch))
        end
        function playAllButtonCallback(self,varargin)
            lockUi(self);
            electrodesToStim = find(self.settableElectrodes);
            for iStim = 1:length(electrodesToStim)
                sendTStimulus(self, electrodesToStim(iStim));
                pause(self.playAllInterStimPauseTime)
            end
            unlockUi(self);
        end
        function playToken(self,varargin)
            cameInLocked = self.isLocked;
            if ~cameInLocked
                lockUi(self);
            end
            
            stimI = randperm(length(self.speechTokenList),1);
            self.map.stimulateSpeechToken(...
                self.speechTokenList{stimI},...
                self.noiseLevel,...
                false)
            
            if self.map.catestrophicFailure
                return
            end
            
            if ~cameInLocked
                unlockUi(self);                
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
            self.playToken();
        end
        
        function switchToCsButtonCallback(self,varargin)
            
            if self.forceStimulatingAllTs && any(~self.hasPlayedT)
                self.motherApp.message('Not Finished Yet!','<p>You haven''t listened to all of the electrodes yet.</p><p>Please go back and do so.</p>','textFontSize',30);
                return
            end
            
            set(self.handleStruct.switchToTsButton,'visible','on');
            set(self.handleStruct.switchToCsButton,'visible','off');
            set(self.handleStruct.finishedButton,'visible','on');
            
            if (~self.isSubTask && strcmp(self.stimulateCsType,'pulses'))
                set(self.handleStruct.playToken,'Visible','on','Enable','on');
                set(self.handleStruct.addNoiseStr,'Visible','on');
                set(self.handleStruct.addNoise,'Visible','on','Enable','on');
            end
            
            set(self.handleStruct.textHandle,'Text',self.messageStrC);
            set(self.handleStruct.playAllButton,'Visible','off');
            
            switch self.stimulateCsType
                case {'speech','sweep'}
                    self.c = self.initC - min(self.initC - self.t) + 1;
%                     self.c = self.t + 1;
                case {'pulses'}
                    self.c = self.t + 1;
                otherwise
                    error('Method for setting MCL is undefined.')
            end
            redrawTsAndCs(self);
            
            self.modeIsT = false;
            self.setVisibleLine;
            
            selectTokenList(self) 
        end
        
        function selectTokenList(self)
            %#FIXME! (eventually)
            % Eventually this should be a drop down box with which subjects
            % can select the speech that they would like to use to adjust
            % their maps.  For now, is hard coded.
            %tokenList = hciUtilGetTokenList([hciRoot '\dependencies\Sounds\sentences\']);
            tokenList = hciUtilGetTokenList(hciDirsDataQualitativeSentences);
            self.speechTokenList = tokenList;
        end
        
        function switchToTsButtonCallback(self,varargin)
            
            self.motherApp.message({'Resetting to original values.'});
            
            % Bug fix for the following bug:
            % 1/31/2013 16:35:29	TsAndCs:  Resetting	Resetting doesn't actually reset - it goes back to the last Ts (not original Ts)
            %
            % Make sure the we show initial smoothing like we smooth when
            % you move. 
            % This is code duplication with lines in initTsAndCs tLineDragFunction
            % Sorry.
            self.t = self.initT;
            newTCurve = nan(size(self.t));
            newTCurve(self.settableElectrodes) = self.t(self.settableElectrodes);
            newTCurve(~self.settableElectrodes) = interp1(find(self.settableElectrodes),self.t(self.settableElectrodes),find(~self.settableElectrodes),'cubic');
            
            self.t = newTCurve;
            self.t(isnan(self.initT)) = nan;
            self.c = self.t+1;
            redrawTsAndCs(self);
            
            set(self.handleStruct.switchToTsButton,'visible','off');
            set(self.handleStruct.switchToCsButton,'visible','on');
            set(self.handleStruct.finishedButton,'visible','off');
            set(self.handleStruct.playToken,'visible','off','enable','off');
            set(self.handleStruct.addNoiseStr,'visible','off');
            set(self.handleStruct.addNoise,'visible','off','enable','off');
            
            set(self.handleStruct.textHandle,'Text',self.messageStrT);
            set(self.handleStruct.playAllButton,'Visible',self.playAllButtonVisibility);
            self.beenModifiedCs = false;
            
            self.modeIsT = true;
            self.setVisibleLine;
        end
        
        function finishedButtonCallback(self, varargin)
            if ~tsAndCsAreValid(self)
                % Currently set Ts and Cs are valid. 
            end
            
            self.endTime = now;
            if self.saveResultsOnQualityExit
                results = createResults(self);
                
                if self.verboseText
                    disp(' ');
                    disp('Input T''s and C''s:');
                    resultsTable = struct('T',num2cell(round(results.results.t)),...
                        'C',num2cell(round(results.results.c)));
                    
                    prtExternal.struct2table.struct2table(resultsTable);
                    disp(' ');
                end
                
                mes = self.motherApp.wait('Saving Results...');
                self.motherApp.subject.logResults(results);
                close(mes);
            end
            
            if self.promptToSetOnExit
                qu = 'Would you like to use these Ts and Cs right now?';
                str1 = 'Yes';
                str2 = 'No';
                
                button = self.motherApp.questdlg(qu,'Set Now?',str1,str2,str1);
                if strcmpi(button,str1)
                    setAsMap(self);
                end
            end
            
            exit(self);
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
        
        function str = messageStrT(self)
            switch self.stimulateTsType
                case {'sweep','speech'}
                    str = ['<HTML><H1>Setting Thresholds</H1>' ...
                        '<p>Adjust the height of the line by clicking and ' ...
                        'dragging until you can just barely hear '...
                        'the sound.</p><p>When you are ' ...
                        'done click "Continue to Maximum Loudness".</p></HTML>'];
                case {'pulses'}
                    str = ['<HTML><H1>Setting Thresholds</H1>' ...
                        '<p>Adjust the height of each of the red triangles '...
                        'by clicking and dragging until you can just barely ' ...
                        'hear the sound.</p><p>When you are done ' ...
                        'with all the triangles click "Continue to Maximum Loudness".</p></HTML>'];
            end
        end
        function str = messageStrC(self)
            switch self.stimulateCsType
                case {'sweep','speech'}
                    str = ['<HTML><H1>Setting Maximum Loudness</H1>' ...
                        '<p>Adjust the height of the line by clicking and ' ...
                        'dragging until the loudness is very loud but you </p><p>' ...
                        'would be comfortable listening to it for short ' ...
                        'periods of time.  When you are done click ' ...
                        '"Finished".</p></HTML>'];
                case {'pulses'}
                    str = ['<HTML><H1>Setting Maximum Loudness</H1>' ...
                        '<p>Adjust the height of each of the red triangles '...
                        'by clicking and dragging until the loudness is very loud but you ' ...
                        'would be comfortable listening to it </p><p> for short ' ...
                        'periods of time.  When satisfied, click ' ...
                        '"Finished".</p></HTML>'];
            end
        end
        
        function setAsMap(self)
            badElectrodes = isnan(self.t) | isnan(self.c) | isnan(self.measElectrodes);
            for iE = 1:length(self.measElectrodes)
                if badElectrodes(iE)
                    continue
                end
                
                setTsAndCsJointly(self.map, self.measElectrodes(iE), self.t(iE), self.c(iE))
            end
            
            saveAndLogCurrentMap(self.subject, sprintf('modifiedTsAndCs_%s_%s',num2str(self.pulseRate),datestr(now,'yyyymmddHHMMSS')), sprintf('Manualy set Ts and Cs at pulse rate = %s.',num2str(self.pulseRate)));
            
            self.motherApp.message('New Map Set','New Ts and Cs are now in use.');
        end        
        function results = createResults(self)
            resultsStruct.initT = self.initT;
            resultsStruct.initC = self.initC;
            resultsStruct.t = self.t;
            resultsStruct.c = self.c;
            resultsStruct.electrodes = self.electrodes;
            resultsStruct.pulseRate = self.pulseRate;   
            resultsStruct.startTime = self.startTime;
            resultsStruct.endTime = self.endTime;
            
            
            results = hciResults('type',self.id,'results',resultsStruct);
        end        
        function val = tsAndCsAreValid(self)
            ts = self.t(~isnan(self.t));
            cs = self.c(~isnan(self.c));
            val = all(ts < cs);
        end
        
        function sendTStimulus(self, cElectrode)
            cameInLocked = self.isLocked;
            if ~cameInLocked
                lockUi(self);
            end
            
            switch self.stimulateTsType
                case {'sweep'}
                    set(self.handleStruct.tLine,'Color',self.resources.colors.greenLight);
                    drawnow;
                    self.map.stimulateThresholdWithSweep(...
                        self.t(~isnan(self.t)), ...
                        self.c(~isnan(self.c)), ...
                        self.measElectrodes,...
                        self.pulseRate,...
                        self.sweepStimulusDuration);
                case {'pulses'}
                    highLightLine = line(cElectrode, self.t(cElectrode),'HitTest','off',...
                        'Color',self.resources.colors.greenLight,...
                        'LineStyle','none',...
                        'Marker','^',...
                        'MarkerSize',self.markerSize,...
                        'MarkerFaceColor',self.resources.colors.greenLight,...
                        'MarkerEdgeColor',self.resources.colors.greenLight);
                    drawnow;
                    self.map.stimulateThreshold(round(self.t(cElectrode)), ...
                        cElectrode, self.pulseRate, self.tStimulusDuration);
                otherwise
                    error('hci:HciTaskSetTsAndCs','unknown stimulateTsType');
            end
            
            if self.map.catestrophicFailure
                return
            end
            
            self.hasPlayedT(cElectrode) = true;
            
            switch self.stimulateTsType
                case {'sweep','speech'}
                    set(self.handleStruct.tLine,'Color',self.resources.colors.green);
                case {'pulses'}
                    delete(highLightLine);
            end
            
            if ~cameInLocked
                unlockUi(self);                
            end
        end
        function sendCStimulus(self, cElectrode)
            cameInLocked = self.isLocked;
            if ~cameInLocked
                lockUi(self);
            end
            
            switch self.stimulateCsType
                case 'speech'
                    set(self.handleStruct.cLine,'Color',self.resources.colors.greenLight);
                    drawnow;
                    
                    % Select stimulus
                    stimI = randperm(length(self.speechTokenList));
                    
                    self.map.stimulateComfortableLoudnessWithSpeech(...
                        self.t(~isnan(self.t)), ...
                        self.c(~isnan(self.c)), ...
                        self.speechTokenList{stimI(1)},...
                        self.cStepSize,...
                        self.cRecentChange); %lmc 7/18/2012
                case 'sweep'
                    set(self.handleStruct.cLine,'Color',self.resources.colors.greenLight);
                    drawnow;
                    self.map.stimulateComfortableLoudnessWithSweep(...
                        self.t(~isnan(self.t)), ...
                        self.c(~isnan(self.c)), ...
                        self.measElectrodes,...
                        self.pulseRate,...
                        self.sweepStimulusDuration);
                case 'pulses'
                    highLightLine = line(cElectrode, self.c(cElectrode),'HitTest','off',...
                        'Color',self.resources.colors.greenLight,...
                        'LineStyle','none',...
                        'Marker','v',...
                        'MarkerSize',self.markerSize,...
                        'MarkerFaceColor',self.resources.colors.greenLight,...
                        'MarkerEdgeColor',self.resources.colors.greenLight);
                    drawnow;
                    self.map.stimulateComfortableLoudnessWithPulseTrain(...
                        round(self.c(cElectrode)), ...
                        cElectrode, ...
                        self.pulseRate, ...
                        self.cStimulusDuration);
                otherwise
                    error('hci:HciTaskSetTsAndCs','unknown stimulateTsType');
            end
            
            if self.map.catestrophicFailure
                return
            end
 
            switch self.stimulateCsType
                case {'sweep','speech'}
                    set(self.handleStruct.cLine,'Color',self.resources.colors.red);
                case {'pulses'}
                    delete(highLightLine);
            end
            
            if ~cameInLocked
                unlockUi(self);
            end
        end 
        
        function lockUi(self)
            if self.isLocked
                return
            end
            self.isLocked = true;
            
                        
            set(self.handleStruct.tLineMarkers,'ButtonDownFcn',[]);
            set(self.handleStruct.tLine,'ButtonDownFcn',[])
            set(self.handleStruct.cLine,'ButtonDownFcn',[])
            set(self.handleStruct.cLineMarkers,'ButtonDownFcn',[]);
            
            set(self.handleStruct.switchToTsButton,'Enable','off');
            set(self.handleStruct.switchToCsButton,'Enable','off');
            set(self.handleStruct.finishedButton,'Enable','off');
            set(self.handleStruct.exitButton,'Enable','off');
            set(self.handleStruct.playAllButton,'Enable','off');
            set(self.handleStruct.playToken,'Enable','off');
            set(self.handleStruct.addNoise,'Enable','off');
            
        end
        function unlockUi(self)
            if ~self.isLocked
                return
            end
            
                        
            set(self.handleStruct.tLineMarkers,'ButtonDownFcn',@self.tlineDragStartFunc);
            set(self.handleStruct.tLine,'ButtonDownFcn',@self.tlineDragStartFunc)
            set(self.handleStruct.cLine,'ButtonDownFcn',@self.clineDragStartFunc)
            set(self.handleStruct.cLineMarkers,'ButtonDownFcn',@self.clineDragStartFunc)
            
            set(self.handleStruct.switchToTsButton,'Enable','on');
            set(self.handleStruct.switchToCsButton,'Enable','on');
            set(self.handleStruct.finishedButton,'Enable','on');
            set(self.handleStruct.exitButton,'Enable','on');
            set(self.handleStruct.playAllButton,'Enable','on');
            if (~self.isSubTask && strcmp(self.stimulateCsType,'pulses'))
                set(self.handleStruct.playToken,'Enable','on');
                set(self.handleStruct.addNoise,'Enable','on');
            end
            self.isLocked = false;
        end
        
        
        function val = get.playAllButtonVisibility(self)
            if self.showPlayAllButton
                val = 'on';
            else
                val = 'off';
            end
        end
    end
end
