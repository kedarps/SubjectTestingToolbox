classdef sttSubjectTestingInterface < prtUiManagerPanel
    properties
        subject         % Subject object
        taskList        % Task List object
        
        handleStruct;   % All the ui control handles
        
        preferences     % Structure for user preferences
        
        modeOfOperation % Run or Debug - this allows special behavior for debug mode
        
        statusTimer     % allows periodic update of status UI
    end
    
    methods
        %............................................................
        % Constructor
        function self = sttSubjectTestingInterface(varargin)
            
            oldFig = findobj('type','figure','tag','sttSubjectTestingInterface');
            if ~isempty(oldFig)
                error('You cannot have two testing interfaces open at once.');
            end
            
            self = prtUtilAssignStringValuePairs(self,varargin{:});
            
            % Create the figure and what not
            if nargin~=0 && ~self.hgIsValid
                self.create();
            end
            
            init(self);
            self.preferences = struct([]);
        end
        
        %............................................................
        % Initialize the interface
        % 1.  Set up UI
        % 2.  Set up menus
        function init(self)
            % Initialize UI
            initUI(self);
            
            % Set up menus
            initSubjectMenu(self);
            initTaskMenu(self);
            initActionMenu(self);
            initPreferencesMenu(self);
            
            % status timer
            initStatusTimer(self);
        end
        
        %............................................................
        % Set up UI.
        %   Used in function init()
        function initUI(self)
            % Set up figure
            self.handleStruct.figure = gcf;
            set(self.managedHandle,'BackgroundColor',[0.6 0.6 0.6]);
            
            set(self.handleStruct.figure,...
                'Toolbar','none',...
                'MenuBar','none',...
                'Position',getWindowSize(self),...
                'Name','Subject Testing Interface',...
                'Tag','sttSubjectTestingInterface',...
                'NumberTitle','off',...
                'WindowStyle','Normal',...
                'DockControls','off');
            
            % Create task panel
            self.handleStruct.taskPanel =  uipanel(...
                'Units','normalized',...
                'Position',[0 0 1 1],...
                'BackgroundColor', [0.8 0.95 0.95], ...
                'visible','on',...
                'BorderType','none');
            
            % create status panel within the task panel
            self.handleStruct.statusPanel =  uipanel(self.handleStruct.figure,...
                'Units','normalized',...
                'Position',[0.191 0.586 0.6 0.372],...
                'BackgroundColor', [0.94 0.94 0.94], ...
                'visible','on',...
                'BorderType','etchedin');
            
            % create status buttons, save just the important ones in
            % handleStruct, need not save all of them
            self.handleStruct.status.subject = uicontrol(self.handleStruct.statusPanel,'Style','text','Units','normalized',...
                'Position',[0.250 0.9 0.417 0.075],...
                'BackgroundColor',[0.94 0.94 0.94],...
                'visible','on','String','Subject: <none>','FontSize',15);
            
            self.handleStruct.status.tasktable = uitable(self.handleStruct.statusPanel,'Units','normalized',...
                'Position',[0.017 0.465 0.97 0.362],'ColumnName',{'Task','Status','Completion Date & Time'},'RowName',{'1','2','3','4'},'ColumnWidth',{300,300,300});
            
            self.handleStruct.status.start = uicontrol(self.handleStruct.statusPanel,'Style','pushbutton','Units','normalized',...
                'Position',[0.844 0.194 0.142 0.162],'Enable','off',...
                'String','START','FontSize',15,'Callback', @(h,e) self.beginTaskList());
        end

        %............................................................
        % Set the window size to be good regardless of monitor.
        %   Used in function initUI()
        function pos = getWindowSize(self)
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
        
        %............................................................
        % Set up the subject menu.
        %   Used in function init()
        function initSubjectMenu(self)
            self.handleStruct.subjectMenu = uimenu(self.handleStruct.figure,...
                'Label','Subject');
            uimenu(self.handleStruct.subjectMenu,'Label', 'New Normal Hearing Subject',...
                'Callback',@(h,e)self.newNormalHearingSubject());
            uimenu(self.handleStruct.subjectMenu,'Label', 'Load Subject',...
                'Callback',@(h,e)self.selectSubject());
            uimenu(self.handleStruct.subjectMenu,'Label', 'Edit Subject',...
                'Callback',@(h,e)self.editSubject());
        end
        
        %............................................................
        % Create a new subject.
        %   Callback for initSubjectMenu()
        function newNormalHearingSubject(self)
            try
                % Check for starting directory
                if ~any(strcmp('saveDirectory', fieldnames(self.preferences)))
                    self.preferences(1).saveDirectory = [];
                end
                
                % Create new subject
                self.subject = sttNormalHearingSubject(self.preferences.saveDirectory);
%                 self.updateStatusPanel();
                % Check to see if a subject was created:
                if isempty(self.subject.returnSubjectID())
                    % If not, delete initialization.
                    self.clearSubject();
                else
                    % If it was, then delete any task list - by definition,
                    % a new subject cannot be the subject used in the task
                    % list.
                    if ~isempty(self.taskList)
                        self.clearTaskList();
                        warnH = warndlg(['The task list has been cleared ' ...
                            'since it was associated with a previous subject.'], ...
                            'Task List Cleared', 'modal');
                        uiwait(warnH)
                    end
                end
            catch ME
                self.subject.subjectError(ME);
                if ~isempty(self.subject)
                    self.clearSubject();
                end
                
                if ~isempty(self.taskList)
                    self.subject = self.taskList.returnSubject();
                end
            end
        end
        
        %............................................................
        % Load an existing subject.
        %   Callback for initSubjectMenu()
        function selectSubject(self)
            % Check for a starting direcotry
            if ~any(strcmp('subjectDirectory', fieldnames(self.preferences)))
                subjectDirectory = pwd;
            else
                subjectDirectory = self.preferences.subjectDirectory;
            end
            
            % Get subject file
            [subjectFile, subjectPath] = uigetfile(...
                subjectDirectory, 'Select subject to load.');
            
            % Try to load subject if user doesn't hit cancel
            if (~isequal(subjectFile, 0) && ~isequal(subjectPath, 0))
                try
                    load(fullfile(subjectPath, subjectFile));
                    
                    % Check for errors
                    if ~exist('subject')
                        % Does the variable 'subject' exist?
                        ME = MException(...
                            'sttSubjectTestingInterface:SubjectLoading', ...
                            '''Subject'' object is not stored in this file.');
                        throw(ME);
                    else
                        if ~isa(subject, 'sttSubject')
                            % Is it of type sttSubject?
                            ME = MException(...
                                'sttSubjectTestingInterface:SubjectLoading', ...
                                'Subject is not an sttSubject object.');
                            throw(ME);
                        end
                    end
                    
                    self.subject = subject;
%                     self.updateStatusPanel()
                    % If a subject has been loaded, and there is already a
                    % task list, and the subject does not match the task
                    % list (most likely), clear the task list
                    if ~isempty(self.taskList)
                        if (self.subject ~= self.taskList.subject)
                            self.clearTaskList();
                            warnH = warndlg(['The task list has been cleared ' ...
                                'since it was associated with a previous subject.'], ...
                                'Task List Cleared', 'modal');
                            uiwait(warnH)
                        end
                    end
                catch ME
                    % Acknowledge error
                    errH = errordlg({ME.identifier; ME.message}, 'Subject Error', 'modal');
                    uiwait(errH);
                end
            end
        end

        %............................................................
        % Edit current subject.
        %   Callback for initSubjectMenu()
        function editSubject(self)
            try
                if isempty(self.subject)
                    msgH = msgbox('No subject loaded.', 'No Subject', 'modal');
                    msgH_Pos = get(msgH, 'Position');
                    set(msgH, 'Position', [msgH_Pos(1:2) 150 msgH_Pos(end)]);
                    uiwait(msgH);
                else
                    isChanged = self.subject.editSubject(self.handleStruct.taskPanel);
                end
                
                % Subject has changed, so task list is no longer valid
                if ~isempty(self.taskList) && isChanged
                    self.clearTaskList();
                    warnH = warndlg(['The task list has been cleared ' ...
                        'since subject has changed.'], ...
                        'Task List Cleared', 'modal');
                    uiwait(warnH)
                end
%                 self.updateStatusPanel();
            catch ME
                self.subject.subjectError(ME);
                if ~isempty(self.subject)
                    self.clearSubject();
                end
                
                % Return previous subject
                if ~isempty(self.taskList)
                    self.subject = self.taskList.returnSubject();
                end
            end
        end

        %............................................................
        % View current subject.
        %   Callback for initSubjectMenu()
        % [deleted since no longer needed with status panel]

        %............................................................
        % Clear current subject.
        %   Callback for initSubjectMenu()
        function clearSubject(self)
            delete(self.subject);
            self.subject = [];
%             self.updateStatusPanel();
        end

        %............................................................
        % Set up the task menu.
        %   Used in function init()
        function initTaskMenu(self)
            self.handleStruct.taskMenu = uimenu(self.handleStruct.figure,...
                'Label','Tasks');
            uimenu(self.handleStruct.taskMenu,'Label','New Task List',...
                'Callback',@(h,e)self.newTaskList());
            uimenu(self.handleStruct.taskMenu,'Label','Load Task List',...
                'Callback',@(h,e)self.loadTaskList());
            uimenu(self.handleStruct.taskMenu,'Label','Edit Task List',...
                'Callback',@(h,e)self.editTaskList());
            uimenu(self.handleStruct.taskMenu,'Label','Reset Tasks in List',...
                'Callback',@(h,e)self.resetTaskList());
        end
        
        %............................................................
        % Create a task list.
        %   Callback for initTaskMenu()
        function newTaskList(self)
           try
               % Try to create new task list
               if isempty(self.subject)
                   errH = errordlg('Create or load a subject first.', ...
                       'Need subject information.', 'modal');
                   uiwait(errH);
               else
                   % Check for starting directory
                   if ~any(strcmp('saveDirectory', fieldnames(self.preferences)))
                       self.preferences(1).saveDirectory = [];
                   end
                   
                   % Create new task list
                   self.taskList = sttTaskList();
                   self.taskList.createTaskList(...
                       self.subject, ...
                       self.handleStruct.taskPanel, ...
                       self.preferences.saveDirectory);
               end
%                self.updateStatusPanel();
           catch ME
               self.clearTaskList();
               warnH = warndlg(...
                   {ME.identifier; ME.message; 'No task list created.'}, ...
                   'Task List Error', ...
                   'modal');
               uiwait(warnH);
           end
       end
        
        %............................................................
        % Load an existing subject.
        %   Callback for initTaskMenu()
        function loadTaskList(self)
            try
                % Create empty task list
                taskList = sttTaskList();
                
                % Load task list
                isLoaded = taskList.loadTaskList(self.handleStruct.taskPanel);
                
                % Check whether a list was loaded
                if isLoaded
                    % If loaded, set subject from task list
                    self.taskList = taskList;
                    self.subject = self.taskList.returnSubject();
%                     self.updateStatusPanel();
                end
            catch ME
                warnH = warndlg(...
                    {ME.identifier; ME.message; 'No task list loaded.'}, ...
                    'Task List Error', ...
                    'modal');
                uiwait(warnH);
            end
        end
        
        %............................................................
        % View current task list.
        %   Callback for initTaskMenu()
        % [deleted since no longer needed with new status panel]
        
        %............................................................
        % Edit the current task list.
        %   Callback for initTaskMenu()
        function editTaskList(self)
            try
                if isempty(self.taskList)
                    errH = errordlg('Create or load a subject first.', ...
                        'Need subject information.', 'modal');
                    uiwait(errH);
                else
                    self.disableStatusPanel();
                    self.taskList.editTaskList(self.handleStruct.taskPanel);
                    self.enableStatusPanel();
                end
            catch ME
               warnH = warndlg(...
                   {ME.identifier; ME.message; 'Error occurred during editing.'}, ...
                   'Task List Error', ...
                   'modal');
               uiwait(warnH);
            end
%             self.updateStatusPanel();
        end
        
        %............................................................
        % Reset task progress for tasks in the current task list.
        %   Callback for initTaskMenu()
        function resetTaskList(self)
            try
                if isempty(self.taskList)
                    errH = errordlg('Create or load a subject first.', ...
                        'Need subject information.', 'modal');
                    uiwait(errH);
                else
                    self.taskList.resetTaskList(self.handleStruct.taskPanel);
                end
%                 self.updateStatusPanel();
            catch ME
               warnH = warndlg(...
                   {ME.identifier; ME.message; 'Error occurred during reset.'}, ...
                   'Task List Error', ...
                   'modal');
               uiwait(warnH);
            end
        end
        
        %............................................................
        % Clear task list.
        function clearTaskList(self)
            delete(self.taskList);
            self.taskList = [];
%             self.updateStatusPanel();
        end
        
        %............................................................
        % Set up the actions menu.
        %   Used in function init()
        function initActionMenu(self)
            self.handleStruct.actionMenu = uimenu(self.handleStruct.figure,...
                'Label', 'Control Tasks');
            uimenu(self.handleStruct.actionMenu, 'Label', 'Start Tasks', ...
                'Callback', @(h,e) self.beginTaskList());
            uimenu(self.handleStruct.actionMenu, 'Label', 'Start Tasks in Debug Mode', ...
                'Callback', @(h,e) self.beginTaskListInDebugMode());
        end

        %............................................................
        % Start the task list.
        %   Callback for initActionMenu()
        function beginTaskList(self)
            try
                % Disable main UI controls
                self.disableMainUi();
                
                
                % Run task list
                if isempty(self.taskList)
                    errH = errordlg('Create or load a subject first.', ...
                        'Need subject information.', 'modal');
                    uiwait(errH);
                else
                    self.taskList.run(self, 'Run');
                end
            catch ME
                % If an error occurred mid-task, notify the subject object
                % for handling
                if strncmp('sttTask:', ME.identifier, 8)
                    self.subject.subjectError(ME);
                end
            end
        end

        %............................................................
        % Start the task list in debug mode.
        %   Callback for initActionMenu()
        function beginTaskListInDebugMode(self)
            try
                % Disable main UI controls
                self.disableMainUi();
                
                % Run task list
                if isempty(self.taskList)
                    errH = errordlg('Please create or load a task list.', ...
                        'Need list of tasks.');
                else
                    self.taskList.run(self, 'Debug');
                end
            catch ME
                % If an error occurred mid-task, notify the subject object
                % for handling
                if strncmp('sttTask:', ME.identifier, 8)
                    self.subject.subjectError(ME);
                end
            end
        end

        %............................................................
        % End the task list.
        function endTaskList(self)
            % Enable UI
            self.enableMainUi();
        end
        
        %............................................................
        % Disable main UI during task operation
        %   Used by beginTaskList and beginTaskListInDebugMode
        function disableMainUi(self)
%             % Turn off menus
%             set(self.handleStruct.subjectMenu, 'Enable', 'off');
%             set(self.handleStruct.taskMenu, 'Enable', 'off');
%             set(self.handleStruct.actionMenu, 'Enable', 'off');
%             set(self.handleStruct.preferencesMenu, 'Enable', 'off');
%             
%             % Do not let 'x' box close the figure
%             set(self.handleStruct.figure,...
%                 'CloseRequestFcn', @(h,e)self.doNotAllowClose());
            self.disableStatusPanel();
        end

        %............................................................
        % Enable main UI after task operation
        %   Used by endTaskList
        function enableMainUi(self)
            % Turn on menus
            set(self.handleStruct.subjectMenu, 'Enable', 'on');
            set(self.handleStruct.taskMenu, 'Enable', 'on');
            set(self.handleStruct.actionMenu, 'Enable', 'on');
            set(self.handleStruct.preferencesMenu, 'Enable', 'on');
            
            % Re-enable the 'x' box
            set(self.handleStruct.figure,...
                'CloseRequestFcn', 'closereq');
            self.enableStatusPanel();
        end

        %............................................................
        % Set up the preferences menu.
        %   Used in function init()
        function initPreferencesMenu(self)
            self.handleStruct.preferencesMenu = uimenu(self.handleStruct.figure,...
                'Label', 'Preferences');
            uimenu(self.handleStruct.preferencesMenu, 'Label', 'Set Save Directory', ...
                'Callback', @(h,e) self.selectSaveDir());
        end

        %............................................................
        % Set the subject starting directory.
        %   Callback for initPreferencesMenu()
        function selectSaveDir(self)
            self.preferences.saveDirectory = uigetdir(...
                pwd, 'Select directory for saving.');
        end
        
        %............................................................
        % Do not allow the figure to close during task operation.
        function doNotAllowClose(self)
            warnH = warndlg(...
                {'You cannot close the figure during task operation.', ...
                'Please exit tasks via quit buttons.'}, 'Quit Properly', 'modal');
            uiwait(warnH);
        end
        
        %............................................................
        % Update UI status based on subject and taskList info.
        function updateStatusPanel(self)
            if ~isempty(self.subject)
                subText = char(self.subject.ID);
            else
                subText = '<none>';
            end
            
            set(self.handleStruct.status.subject,'String',sprintf('Subject: %s',subText));
            
            if ~isempty(self.taskList)
                nTasks = length(self.taskList.taskList);
                taskTableData = cell(nTasks,3);
                
                for i = 1:nTasks
                    taskTableData{i,1} = self.taskList.taskList{i}.taskTitle;
                    taskTableData{i,2} = self.taskList.taskList{i}.status;
                    taskTableData{i,3} = char(self.taskList.taskList{i}.completionDateAndTime(end));
                end
                set(self.handleStruct.status.tasktable,'Data',taskTableData);
                set(self.handleStruct.status.start,'Enable','on');
            else
                set(self.handleStruct.status.tasktable,'Data',{});
                set(self.handleStruct.status.start,'Enable','off');
            end
        end
        
        function disableStatusPanel(self)
            set(self.handleStruct.statusPanel,'Visible','off');
        end
        
        function enableStatusPanel(self)
            set(self.handleStruct.statusPanel,'Visible','on');
        end
        
        %............................................................
        % Timer for timely updating status 
        function initStatusTimer(self)
            period = 10;
            self.statusTimer = timer('TimerFcn', {@(h,e) self.updateStatusPanel()}, 'Period', period, 'executionmode', 'fixedrate');
            start(self.statusTimer);
        end
        
    end
end