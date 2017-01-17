classdef hciFittingProgram < prtUiManagerPanel
    properties
        subjectId % Must be set by specifying it to the constructor
        
        subject % Will be set in init() from subjectId
        
        currentTask % Handle to the current task
        
        handleStruct % All the ui control handles
        resources = hciResources;
        
        showFileMenu = false;
        showFileMenuAdvanced = false;
        showToolbar = false;
        
        % List of tasks for which the processor should not be turned on
        adminFcnList = {...
            'hciTaskGuide',...
            'hciTaskStart',...
            'hciTaskChangeUser',...
            'hciTaskNewUser',...
            'hciTaskSelectMap',...
            'hciTaskDeleteMap',...
            'hciTaskDeleteUser',...
            'hciTaskImportMap',...
            'hciTaskPersonalGuide',...
            'hciTaskQualitativeSpeechTest'};
    end
    
    properties (Dependent)
        map % direct link to subject.map
    end
        
    methods
        function self = hciFittingProgram(varargin)
            
            oldFig = findobj('type','figure','tag','hciFittingProgram');
            if ~isempty(oldFig)
                error('Close yer old one first!');
            end
            
            self = prtUtilAssignStringValuePairs(self,varargin{:});
            
            % Create the figure and what not
            if nargin~=0 && ~self.hgIsValid 
                self.create();
            end
            
            init(self);
        end
        
        function init(self)
            if isempty(self.subjectId)
                error('subjectId must be specified (for now)');
                
                % No subject ID specified so we must ask for it.
            
%                 button = [];
%                 while isempty(button)
%                     button = questdlg('Are you a new user?','title','Yes','No','No');
%                 end
%                 isNewUser = strcmpi(button,'yes');
%                 
%                 if isNewUser
%                     newUser(self,false)
%                 else
%                     selectUser(self,false);
%                 end
                
            else % Load the specified ID
                loadSubject(self,self.subjectId); % Create the subject
            end
            
            initUi(self);
        end
        
        function initUi(self)
            % Set up figure
            self.handleStruct.figure = gcf;
            set(self.managedHandle,'BackgroundColor',[0.6 0.6 0.6])
            set(self.handleStruct.figure,...
                'Toolbar','none',...
                'MenuBar','none',...
                'Position',getWindowSize(self),...
                'Name','Fit Your Device',...
                'Tag','hciFittingProgram',...
                'NumberTitle','off',...
                'WindowStyle','Normal',...
                'DockControls','off');
            setFigureName(self)
            
            % This is how you would change the logo in the top left. This
            % is apparently not a great idea. It violates MATLAB license
            % rules.
            %
            %warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            %jframe = get(handles.fig,'javaframe');
            %jIcon = javax.swing.ImageIcon('C:\program files\matlab\r2007b\icons\icon.gif');
            %jframe.setFigureIcon(jIcon);
            
            % Setup File Menu
            if self.showFileMenu
                initFileMenu(self)
            end
                
            % Set up toolbar
            initToolbar(self)
            
            % Create message panel
            createMessagePanel(self)
            
            % Start a task
            startTask(self, @hciTaskGuide);
        end

        function initFileMenu(self)
            
            % Set up menu bar
            self.handleStruct.fileMenu = uimenu(self.handleStruct.figure,...
                'Label','File');
            if self.showFileMenuAdvanced
                uimenu(self.handleStruct.fileMenu,'Label','New User',...
                    'Callback',@(h,e)self.newUser());
                uimenu(self.handleStruct.fileMenu,'Label','Change User',...
                    'Callback',@(h,e)self.selectUser());
                uimenu(self.handleStruct.fileMenu,'Label','Change Map',...
                    'Callback',@(h,e)self.subject.uiLoadMapFromDatabase());
            end

            uimenu(self.handleStruct.fileMenu,'Label','Quit',...
                'Callback',@self.saveAndQuit);

        end

        function initToolbar(self)
            if self.showToolbar
                self.handleStruct.toolbar.toolbar = uitoolbar(self.handleStruct.figure);
                
                % Handle name, tooltip, callback, icon id
                toolbarSetup = {'new','New User',@(h,e)self.newUser(), 'user_new_3';
                    'change','Change User',@(h,e)self.selectUser(), 'user_properties';
                    'select','Select Map', @(h,e)self.subject.uiLoadMapFromDatabase(), 'mail_mark_task'};
                
                for i = 1:size(toolbarSetup,1)
                    self.handleStruct.toolbar.(toolbarSetup{i,1}) = uipushtool(...
                        self.handleStruct.toolbar.toolbar,...
                        'CData',self.resources.icons.size16.(toolbarSetup{i,4}),...
                        'TooltipString',toolbarSetup{i,2},...
                        'HandleVisibility','off',...
                        'ClickedCallback',toolbarSetup{i,3});
                end
            end
        end
        
        function newUser(self)
           self.startTask(@hciTaskNewUser);
        end
        
        function selectUser(self)
            self.startTask(@hciTaskChangeUser);
        end
        
        function selectMap(self)
            self.startTask(@hciTaskSelectMap);
        end
        
        function loadSubject(self, subjectId)
            self.subjectId = subjectId;
            self.subject = hciSubject(subjectId,@()self.endTask(@hciTaskStart)); % Load the subject
            
            setFigureName(self)
        end
        function setFigureName(self)
            if isfield(self.handleStruct,'figure') && ishandle(self.handleStruct.figure)
                set(self.handleStruct.figure,'Name', cat(2,'HCI - ',self.subject.displayName));
            end
        end
            
        function startTask(self, taskFun, extraInputs)
            try
                delete(self.handleStruct.taskPanel);
            end
            createTaskPanel(self);
            
            if nargin < 2
                taskFun = @hciTaskStart;
            end
            
            if nargin < 3
                extraInputs = {};
            end
            
            nextFunctionDetails = functions(taskFun);
            if (sum(strcmp(nextFunctionDetails.function,self.adminFcnList)) || ...
                    strncmp(nextFunctionDetails.function,'hciSubTask',10))
                if ~isempty(self.map.NMTclient)
                    self.map.stopProcessor();
                end
            else
                if isempty(self.map.NMTclient)
                    self.map.startProcessor();
                end
            end
            
            self.currentTask = feval(taskFun,'motherApp', self, 'managedHandle', self.handleStruct.taskPanel,extraInputs{:});
        end
        
        function endTask(self, nextTaskFun)
            if ~isempty(self.subject.map.stimulusErrorStructure)
                self.subject.saveErrorStructure();
            end
            if ~isempty(self.subject.map.NMTclient)
                self.subject.map.stopProcessor();
            end
            if nargin < 2
                nextTaskFun = self.currentTask.nextTask;
            end

            startTask(self, nextTaskFun);
        end
        
        function createTaskPanel(self)
            self.handleStruct.taskPanel =  uipanel('Units','normalized',...
                'Position',[0 0 1 1],'visible','on','BorderType','none');
        end
        function createMessagePanel(self)
            self.handleStruct.messagePanel =  uipanel('Units','normalized',...
                'Position',[0 0 1 1],'visible','on','BorderType','none');
        end
        
        function messageObj = message(self, titleStrs, messageStrs, varargin)
            
            if ~mod(nargin,2) % Even number of inputs should mean titleStr was skipped
                if nargin > 2
                    varargin = cat(2,{messageStrs},varargin{:});
                end
                
                messageStrs = titleStrs;
                titleStrs = 'Dont Need';
            end
            try
                set(self.handleStruct.taskPanel,'visible','off');
            catch
                return
            end
            messageObj = hciMessage(titleStrs, messageStrs,...
                'managedHandle',self.handleStruct.messagePanel,...
                'onCloseCallback',@self.messageClose,varargin{:});
            
            set(self.handleStruct.messagePanel,'visible','on');
            drawnow;
            
            waitfor(self.handleStruct.taskPanel,'visible','on'); % Wait for someone (hopefully us) to turn the taskPanel visible again.
            delete(messageObj);
        end
        function messageClose(self)
            set(self.handleStruct.messagePanel,'visible','off');
            set(self.handleStruct.taskPanel,'visible','on');
        end
        function messageObj = wait(self, titleStrs, messageStrs, varargin)
            
            if ~mod(nargin,2) % Even number of inputs should mean titleStr was skipped
                if nargin > 2
                    varargin = cat(2,{messageStrs},varargin{:});
                end
                
                messageStrs = titleStrs;
                titleStrs = 'Dont Need';
            end
            
            set(self.handleStruct.messagePanel,'visible','on');
            set(self.handleStruct.taskPanel,'visible','off');
            messageObj = hciMessage(titleStrs, messageStrs,...
                'managedHandle',self.handleStruct.messagePanel,...
                'onCloseCallback',@self.messageClose,...
                'showCloseButton',false,...
                varargin{:});
            drawnow;
        end
        
        function varargout = questdlg(self, varargin) %#ok<MANU>
            varargout = cell(nargout,1);
            
            % Testing software on dual monitor system ends up with these
            % question dialogs on the proctor monitor while the GUI is on
            % the subject monitor.  Want to change that so that subjects
            % control all interactions.
            defaultFigPos = get(0,'DefaultFigurePosition');
            guiPos = get(self.handleStruct.figure,'Position');
            upperGuiPos = [(guiPos(1)+(0.5*(guiPos(3)-267))) ...
                (guiPos(2)+(0.66*(guiPos(4)-70))) guiPos(3:4)];
            set(0,'DefaultFigurePosition',upperGuiPos); 
            [varargout{:}] = questdlg(varargin{:});
            set(0,'DefaultFigurePosition',defaultFigPos);
        end
        
        
        function set.map(self,val)
            self.subject.map = val;
        end
        function val = get.map(self)
            val = self.subject.map;
        end
        
        function pos = getWindowSize(self) %#ok<MANU>
            
            ss = get(0,'screensize');
            aspectRatio = [16 9];
            maxSize = ss(3:4);
            pixPad = [50 200]; % Just so we don't butt up to the edges.
            
            if any(maxSize > ss(3:4)-pixPad)
                maxSize = maxSize - pixPad;
            end
            
            % There are four ways to make this work
            possibleSizes = [aspectRatio./aspectRatio(1) .* maxSize(1);
                aspectRatio./aspectRatio(1) .* maxSize(2);
                aspectRatio./aspectRatio(2) .* maxSize(1);
                aspectRatio./aspectRatio(2) .* maxSize(2);];
            
            % But only some of them work.
            acceptableSizes = and(possibleSizes(:,1) <= maxSize(1), possibleSizes(:,2) <= maxSize(2));
            
            possibleSizes = possibleSizes(acceptableSizes,:);
            
            % In the event that more than one work (is that possible (i think so)) we
            % take the one with max area
            [~, maxInd] = max(prod(possibleSizes,2));
            proposedSize = possibleSizes(maxInd,:);
            
            % Center the window
            % I think MATLAB does not count the menu bar and the borders of the figure
            % window so if you use a large window it may get too close to the top. To
            % compensate you can use a larger pixPad in the vertical direction
            
            sizePads = round((ss(3:4)-proposedSize));
            sizePads(1) = sizePads(1)/2; % We should use 2 right?
            sizePads(2) = sizePads(2)/2;
            
            pos = cat(2,sizePads,proposedSize);
        end
    end
end
