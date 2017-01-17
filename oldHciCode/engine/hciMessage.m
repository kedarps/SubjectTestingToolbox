classdef hciMessage < prtUiManagerPanel
    % hciMessage({''First Title''; ''Second Title''},{''First Message'',''Second Message''})
    properties
        figureHandle
        bottomTextHandle
        bottomTextPanelHandle
        textHandle
        textHandleContainer

        windowSize = [500 300];
        textFontSize = 40;
        
        messageInd = 1;
        
        titleStrCell
        messageStrCell
        
        onCloseCallback
        
        madeThisWindow = false;
        
        showCloseButton = true;
        
        colors = hciUtilResourceColors;
        
    end
    properties (SetAccess='protected',GetAccess='protected')
        multipleTitles
    end
    properties (Dependent)
        messageStr
        titleStr
    end
    
    methods
        function self = hciMessage(varargin)
            if nargin < 2 && nargin > 0
                error('usage: hciMessage({''First Title''; ''Second Title''},{''First Message'',''Second Message''})');
            else
                if ~iscell(varargin{1})
                    self.titleStrCell = cellstr(varargin{1});
                else
                    self.titleStrCell = varargin{1};
                end
                if ~iscell(varargin{2})
                    self.messageStrCell = cellstr(varargin{2});
                else
                    self.messageStrCell = varargin{2};
                end
                
                self.multipleTitles = length(self.titleStrCell)>1;
                if self.multipleTitles
                    assert(length(self.messageStrCell)==length(self.titleStrCell),'When specifying multiple titles, the number of titles must match the number of messages') 
                end
                
                if nargin > 2
                    self = prtUtilAssignStringValuePairs(self,varargin{3:end});
                end
            end
                
            if ~self.hgIsValid
                createWindow(self);
            end
            
            init(self);
            
            self.titleStr = self.titleStrCell{1};
            self.messageStr = self.messageStrCell{1};
            
        end
        function createWindow(self)
            ss = get(0,'ScreenSize');
            screenCenter = ss(3:4)/2;
            
            self.figureHandle = figure('units','pixels',...
                'position',[screenCenter(1)-self.windowSize(1)/2 screenCenter(2)-self.windowSize(2)/2 self.windowSize],...
                'menubar','none',...
                'toolbar','none',...
                'numberTitle','off',...
                'Name',self.titleStr,...
                'tag','hciMessage',...
                'Interruptible','off',...
                'BusyAction','cancel',...
                'DockControls','off');
            
            self.managedHandle = uipanel(self.figureHandle, ...
                'units','normalized',...
                'BorderType','none',...
                'Position',[0 0 1 1]);
            
            self.madeThisWindow = true;
        end
        function init(self)
            
            [self.textHandle, self.textHandleContainer]  = javacomponent('javax.swing.JLabel',[1 1 1 1], self.managedHandle);
            backgroundColor = get(self.managedHandle,'BackgroundColor');
            set(self.textHandle,'Text',self.messageStr,'Background',java.awt.Color(backgroundColor(1),backgroundColor(2),backgroundColor(3)));
            set(self.textHandle,'Font',java.awt.Font('sansserif',java.awt.Font.PLAIN,self.textFontSize));
            self.textHandle.setVerticalAlignment(javax.swing.JLabel.TOP);
            
            self.bottomTextPanelHandle = uipanel(self.managedHandle,...
                'BorderType','None',...
                'units','pixels',...
                'position',[1 1 1 1],...
                'ButtonDownFcn',@self.clickCallback);
            
            self.bottomTextHandle = uicontrol('style','pushbutton',...
                'parent',self.bottomTextPanelHandle,...
                'string','Click Here To Continue',...
                'units','normalized',...
                'position',[0 0 1 1],...
                'Callback',@self.clickCallback,...
                'FontSize',15,...
                'HitTest','on',...
                'BackgroundColor',self.colors.grayLight,...
                'SelectionHighlight','off',...
                'selected','on',...
                'KeyPressFcn',@self.clickCallback);
                %'BackgroundColor',get(self.bottomTextPanelHandle,'BackgroundColor'));
            
            if ~self.showCloseButton
                set(self.bottomTextHandle,'visible','off');
            end
                
            set(self.managedHandle,'ResizeFcn',@self.resizeFunction);
            self.resizeFunction();
            
            %set(self.textHandleContainer,'HitTest','off','ButtonDownFcn',@self.clickCallback);
            %set(self.managedHandle,'ButtonDownFcn',@self.clickCallback);
            
            %textWeirdHandle = handle(self.textHandle,'callbackproperties');
            %set(textWeirdHandle,'MouseClickedCallbackData',@self.clickCallback);
            
            set(self.bottomTextHandle,'selected','On');
        end
        
        function resizeFunction(self,varargin)
            parentWindowSize = getpixelposition(self.managedHandle);
            parentWindowSize = parentWindowSize(3:4);
            
            leftBorder = 0.1*parentWindowSize(1);%25;
            rightBorder = 0.1*parentWindowSize(1);%25;
            topBorder = 0.1*parentWindowSize(2);%25;
            bottomTextSize = 0.1*parentWindowSize(2);
            
            bottomTextPos = [1 1 parentWindowSize(1) bottomTextSize];
            textPos = [leftBorder bottomTextPos(4) parentWindowSize(1)-leftBorder-rightBorder parentWindowSize(2)-topBorder-bottomTextPos(4)];
            
            set(self.textHandleContainer,'units','pixels');
            set(self.textHandleContainer,'position',textPos);
            set(self.textHandleContainer,'units','normalized');
            
            set(self.bottomTextPanelHandle,'units','pixels');
            set(self.bottomTextPanelHandle,'position',bottomTextPos);
            set(self.bottomTextPanelHandle,'units','normalized');
        end
        
        function clickCallback(self,varargin)
            self.messageInd = self.messageInd + 1;
            
            
            if self.messageInd > length(self.messageStrCell)
                close(self);
            else
                if self.multipleTitles
                    self.titleStr = self.titleStrCell{self.messageInd};
                end
                self.messageStr = self.messageStrCell{self.messageInd};
            end
        end
        function val = get.messageStr(self)
            if isempty(self.messageStrCell)
                val = '';
            else
                val = self.messageStrCell{self.messageInd};
            end
        end
        function val = get.titleStr(self)
            if isempty(self.titleStrCell)
                val = '';
            else
                if self.multipleTitles
                    val = self.titleStrCell{self.messageInd};
                else
                    val = self.titleStrCell{1};
                end
            end
        end
        function set.titleStr(self,val)
            if self.madeThisWindow && ishandle(self.figureHandle)
                set(self.figureHandle,'Name',val);
            end
        end
        function set.messageStr(self,val)
            if ishandle(self.textHandle)
                set(self.textHandle,'Text',cat(2,'<HTML>',val,'</HTML>'));
            end
        end
        
        function set.showCloseButton(self,val)
            self.showCloseButton = val;
            if ~self.showCloseButton && ~isempty(self.bottomTextHandle) && ishandle(self.bottomTextHandle) %#ok<MCSUP>
                set(self.bottomTextHandle,'visible','off'); %#ok<MCSUP>
            end
        end
        
        function uiwait(self)
            uiwait(self.figureHandle)
        end
        function close(self)
            if self.madeThisWindow
                try %#ok<TRYNC>
                    close(self.figureHandle);
                end
            end
            % Running in a uipanel
            if ~isempty(self.onCloseCallback)
                feval(self.onCloseCallback)
            end
        end
    end
end