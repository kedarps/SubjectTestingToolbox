classdef sttTaskList < matlab.mixin.SetGet
    % An array list of task objects.  This class checks each Task class
    % instantiation's status to move the list pointer.
    
    properties
        parentTestingInterface
        
        subject
        taskList
        taskDataList    % Used for display purposes - just so the 
                        % researcher knows what data files they are using

        handleStruct    % All the ui control handles
        
        saveDir         % Starting directory for file/directory selections
        
        runMode         % Provide the option for a debug mode (this is 
                        % important for CI subjects - you probably are not
                        % going to do development with the CI research
                        % interface connected
        
        taskPointer = 1;
        
        taskListPath    % If the list comes from a loaded file, the file name
                        % gets saved for overwriting as tasks are completed
                        
        listCopy        % Used to store original during editing - canceling will
                        % revert to this copy
    end
    
    properties (Hidden, Transient)
        % There are a limited number of possible run modes
        runModeSet = matlab.system.StringSet({'Run', 'Debug'});
    end

    methods
        %............................................................
        % Constructor - create a task list.
        function self = sttTaskList(varargin)
            self = prtUtilAssignStringValuePairs(self, varargin{:});
        end
        
        %............................................................
        % Create a task list.
        function createTaskList(self, subject, taskPanel, saveDir)
            % Set initial data
            self.subject = subject;
            self.handleStruct.taskPanel = taskPanel;
            self.saveDir = saveDir;
            
            % Create blank GUI
            taskListGui(self);
        end
        
        %............................................................
        % Load a task list.
        function isLoaded = loadTaskList(self, taskPanel)
            isLoaded = false;
            
            % Select a task list file
            if isempty(self.saveDir)
                self.saveDir = pwd;
            end
            [listFile, listPath] = uigetfile(self.saveDir, 'Select a task list.');
            
            % Attempt to load is user does not cancel
            if (~isequal(listFile, 0) && ~isequal(listPath, 0))
                try
                    load(fullfile(listPath, listFile))
                    
                    % Verify file contains necessary information
                    if ~exist('taskListObj', 'var')
                        ME = MException(...
                            'sttTaskList:ListLoading', ...
                            'The file did not contain the variable ''taskListObj''.');
                        throw(ME);
                    else
                        if ~isa(taskListObj, 'sttTaskList')
                            ME = MException(...
                                'sttTaskList:ListLoading', ...
                                'The variable ''taskListObj'' was not a task list object.');
                            throw(ME);
                        end
                    end
                    
                    % Fill in fields
                    taskListFields = fieldnames(taskListObj);
                    for t = 1:length(taskListFields)
                        self.(taskListFields{t}) = taskListObj.(taskListFields{t});
                    end
                    self.handleStruct.taskPanel = taskPanel;
                    self.taskListPath = fullfile(listPath, listFile);
                    self.saveDir = listPath;
                    
                    % Verify that objects are of the correct type
                    if ~isa(self.subject, 'sttSubject')
                        ME = MException(...
                            'sttTaskList:ListLoading', ...
                            'Subject is not a sttSubject object.');
                        throw(ME);
                    end
                    for t = 1:length(self.taskList)
                        if ~isa(self.taskList{t}, 'sttTask')
                            ME = MException(...
                                'sttTaskList:ListLoading', ...
                                'List contains objects that are not tasks.');
                            throw(ME);
                        end
                    end
                catch ME
                    self.taskListError();
                    throw(ME);
                end
                isLoaded = true;
            end
        end
        
        %............................................................
        % View the task list.
        function viewTaskList(self, taskPanel)
            % Create blank GUI
            self.handleStruct.taskPanel = taskPanel;
            taskListGui(self);
            
            % Disable all functions
            set(self.handleStruct.addTaskButton, 'Visible', 'off');
            set(self.handleStruct.deleteTaskButton, 'Visible', 'off');
            set(self.handleStruct.reorderTaskButton, 'Visible', 'off');
            set(self.handleStruct.doneButton, 'Visible', 'off');
            
            % Add some display features
            set(self.handleStruct.cancelButton, 'String', 'Done');
            self.handleStruct.subjectDisplay = uicontrol(self.handleStruct.taskPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.8 0.9 0.4 0.06], ...
                'FontUnits', 'normalized', ...
                'FontSize', 0.6, ...
                'BackgroundColor', get(self.handleStruct.taskPanel, 'BackgroundColor'), ...
                'HorizontalAlignment', 'left');
            set(self.handleStruct.subjectDisplay, ...
                'String', ['Subject: ' char(self.subject.ID)]);
            
            % Fill in list
            self.fillInList();
        end
        
        %............................................................
        % Edit the task list.
        function editTaskList(self, taskPanel)
            % Create blank GUI
            self.handleStruct.taskPanel = taskPanel;
            taskListGui(self);
            
            % Fill in list
            self.fillInList();
            
            % Create temporary copy that can be reverted to if the user
            % decides to cancel
            if ~isempty(self.parentTestingInterface)
                self.parentTestingInterface = [];
            end
            objAsByteArray = getByteStreamFromArray(self);
            self.listCopy = getArrayFromByteStream(objAsByteArray);
            set(self.handleStruct.cancelButton, ...
                'Callback',@(h,e)self.revertListAndExit);
        end
        
        %............................................................
        % Load list and display to user for selection of tasks to reset.
        function resetTaskList(self, taskPanel)
            % Create blank GUI
            self.handleStruct.taskPanel = taskPanel;
            taskListGui(self);
            
            % Disable all functions
            set(self.handleStruct.addTaskButton, 'Visible', 'off');
            set(self.handleStruct.deleteTaskButton, 'Visible', 'off');
            set(self.handleStruct.reorderTaskButton, 'Visible', 'off');

            % Fill in list
            self.fillInList();
            set(self.handleStruct.list, 'Value', []);
            
            % Edit add button to be reset button
            set(self.handleStruct.addTaskButton, ...
                'String', 'Reset Tasks', ...
                'Callback', @(h,e)self.resetTasks(), ...
                'Visible', 'on');
            
            % Set up 'Done' button
            set(self.handleStruct.doneButton, 'Callback', @(h,e)self.saveAndClear(true));
        end
        
        %............................................................
        % Reset progress of tasks in the task list.
        %   Used in function resetTaskList
        function resetTasks(self)
            selectedItems = get(self.handleStruct.list, 'Value');
            if isempty(selectedItems)
                m = msgbox('No tasks have been selected.','modal');
                uiwait(m);
            else
                % Reset tasks
                for s = 1:length(selectedItems)
                    self.taskList{selectedItems(s)}.updateStatus('Ready');
                    self.taskList{selectedItems(s)}.resetTask();
                end
                
                % Update view
                self.fillInList();
            end
        end
        
        %............................................................
        % Task List GUI.
        function taskListGui(self)
            % Create list box for tasks
            self.handleStruct.listLabel = uicontrol(self.handleStruct.taskPanel, ...
                'Style', 'text', ...
                'String', 'TASK LIST', ...
                'Units', 'normalized', ...
                'Position', [0.45 0.4 0.2 0.1], ...
                'FontUnits', 'normalized', ...
                'FontSize', 0.3, ...
                'BackgroundColor', get(self.handleStruct.taskPanel, 'BackgroundColor'), ...
                'HorizontalAlignment', 'left');
            self.handleStruct.list = uicontrol(self.handleStruct.taskPanel, ...
                'Style', 'listbox', ...
                'String', [], ...
                'Units', 'normalized', ...
                'Position', [0.191 0.2 0.6 0.25], ...
                'FontUnits', 'normalized', ...
                'FontSize', 0.075, ...
                'Max', 2);
            
            % Buttons for adding, editing, and deleting items in the list
            self.handleStruct.addTaskButton = uicontrol(self.handleStruct.taskPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Add Task', ...
                'Units', 'normalized', ...
                'Position', [0.241 0.1 0.15 0.06], ...
                'FontUnits', 'normalized', ...
                'FontSize', 0.6, ...
                'HorizontalAlignment', 'left', ...
                'Callback',@(h,e)self.addTaskToList());
            self.handleStruct.deleteTaskButton = uicontrol(self.handleStruct.taskPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Delete Task(s)', ...
                'Units', 'normalized', ...
                'Position', [0.416 0.1 0.15 0.06], ...
                'FontUnits', 'normalized', ...
                'FontSize', 0.6, ...
                'HorizontalAlignment', 'left', ...
                'Callback',@(h,e)self.deleteTasksFromList());
            self.handleStruct.reorderTaskButton = uicontrol(self.handleStruct.taskPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Reorder Tasks', ...
                'Units', 'normalized', ...
                'Position', [0.591 0.1 0.15 0.06], ...
                'FontUnits', 'normalized', ...
                'FontSize', 0.6, ...
                'HorizontalAlignment', 'left', ...
                'Callback',@(h,e)self.reorderTasksInList());
            
            % Return to testing interface
            self.handleStruct.cancelButton = uicontrol(self.handleStruct.taskPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Cancel', ...
                'Units', 'normalized', ...
                'Position', [0.8 0.3 0.15 0.06], ...
                'FontUnits', 'normalized', ...
                'FontSize', 0.6, ...
                'HorizontalAlignment', 'left', ...
                'Callback',@(h,e)self.exitGuiWithoutSaving());
            self.handleStruct.doneButton = uicontrol(self.handleStruct.taskPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Done', ...
                'Units', 'normalized', ...
                'Position', [0.8 0.2 0.15 0.06], ...
                'FontUnits', 'normalized', ...
                'FontSize', 0.6, ...
                'HorizontalAlignment', 'left', ...
                'Callback',@(h,e)self.saveAndClear(true));
        end
        
        %............................................................
        % Add task to list.
        %   Callback for task list GUI.
        function addTaskToList(self)
            % Select task
            if isempty(self.saveDir)
                self.saveDir = pwd;
            end
            [taskFile, taskPath] = uigetfile(self.saveDir, 'Select a task.');
            
            % If user switched paths and the starting directory was pwd,
            % then reassign starting directory
            if strcmp(self.saveDir, pwd)
                self.saveDir = taskPath;
            end
            
            % Select task data file
            [taskDataFile, taskDataDir] = uigetfile(self.saveDir, 'Select data for the task.');
            
            % Create task
            try
                % Check for cancelations
                if (isequal(taskFile, 0) || isequal(taskPath, 0))
                    ME = MException(...
                        'sttTaskList:AddTask', ...
                        'No task selected.');
                    throw(ME);
                elseif (isequal(taskDataFile, 0) || isequal(taskDataDir, 0))
                    ME = MException(...
                        'sttTaskList:AddTask', ...
                        'No task data selected.');
                    throw(ME);
                end

                % Try to create a new task
                taskName = sttUtilReplaceStr(taskFile,[],'.m');
                newTask = eval([taskName '(''subject'', self.subject);']);
                if ~isa(newTask, 'sttTask')
                    ME = MException(...
                        'sttTaskList:AddTask', ...
                        'Selected class is not a task.');
                    throw(ME);
                end
                
                % Try to add task data
                if isempty(strfind(taskDataFile, '.mat'))
                    ME = MException(...
                        'sttTaskList:AddTask', ...
                        'Task data file was not a .MAT file.');
                    throw(ME);
                end
                newTask.loadTaskData(fullfile(taskDataDir, taskDataFile));
                
                % Add new task to the list
                if isempty(self.taskList)
                    self.taskList = {newTask};
                    self.taskDataList = {taskDataFile};
                else
                    self.taskList(end+1) = {newTask};
                    self.taskDataList(end+1) = {taskDataFile};
                end
                
                % Create display string
                taskStr = ['Task ' sttUtilReplaceStr(taskFile,[],'.m') ' using ' ...
                    taskDataFile];
                set(self.handleStruct.list, 'String', [...
                    get(self.handleStruct.list, 'String'); {taskStr}]);
            catch ME
                errH = errordlg(...
                    {ME.identifier; ME.message; 'No new task added.'}, ...
                    'No New Task', ...
                    'modal');
                uiwait(errH);
            end
        end

        %............................................................
        % Delete task(s) from list.
        %   Callback for task list GUI.
        function deleteTasksFromList(self)
            try
                % Edit display
                selectedItems = get(self.handleStruct.list, 'Value');
                listItems = get(self.handleStruct.list, 'String');
                listItems(selectedItems) = [];
                set(self.handleStruct.list, 'Value', [], 'String', listItems);
                
                % Edit list
                self.taskList(selectedItems) = [];
                self.taskDataList(selectedItems) = [];
            catch ME
                errH = errordlg(...
                    {ME.identifier; ME.message}, ...
                    'Deletion Error', ...
                    'modal');
                uiwait(errH);
            end
        end

        %............................................................
        % Select a new order for tasks in the list.
        %   Callback for task list GUI.
        function reorderTasksInList(self)
            try
                % Get new order
                prompt = cell(1,length(self.taskList));
                defaultAnswer = cell(1,length(self.taskList));
                for p = 1:length(prompt)
                    % Get task and task data file
                    className = class(self.taskList{p});
                    taskDataFile = self.taskDataList{p};
                    
                    % Get status
                    status = self.taskList{p}.returnStatus();
                    
                    prompt{p} = ['Task ' className ' using ' taskDataFile ' - ' status];
                    defaultAnswer{p} = num2str(p);
                    clear className fullPathTaskDataFile path taskDataFile status
                end
                answer = inputdlg(prompt,'Enter task order',1,defaultAnswer);
                
                % Convert new order to indices
                for a = 1:length(answer)
                    newOrder(a) = str2num(answer{a});
                end
                [sortOrder, sortOrderI] = sort(newOrder);
                
                if length(unique(sortOrderI)) < length(sortOrderI)
                    ME = MException(...
                        'sttTaskList:ReorderTasksInList', ...
                        'Each position in the list must be unique.');
                    throw(ME);
                elseif any(sortOrderI > length(sortOrderI))
                    ME = MException(...
                        'sttTaskList:ReorderTasksInList', ...
                        'At least one specified position is outside the list range.');
                    throw(ME);                    
                elseif any(sortOrderI < 1)
                    ME = MException(...
                        'sttTaskList:ReorderTasksInList', ...
                        'The index of the first position in the list must equal one.');
                    throw(ME);                    
                end
                
                % Reorder
                self.taskList = self.taskList(sortOrderI);
                self.taskDataList = self.taskDataList(sortOrderI);
                self.fillInList();
            catch ME
                errH = errordlg(...
                    {ME.identifier; ME.message}, ...
                    'Reorder Error', ...
                    'modal');
                uiwait(errH);
            end
        end

        %............................................................
        % Fill in task list display.
        function fillInList(self)
            % Create list of tasks
            taskListStr = {};
            for t = 1:length(self.taskList)
                % Get task and task data file
                className = class(self.taskList{t});
                taskDataFile = self.taskDataList{t};
                
                % Get status
                status = self.taskList{t}.returnStatus();
                
                taskListStr{t,1} = ['Task ' className ' using ' taskDataFile ' - ' status];
                clear className fullPathTaskDataFile path taskDataFile status
            end
            
            % Put list in list box
            set(self.handleStruct.list, 'String', taskListStr);
        end
        
        %............................................................
        % Run task in list.
        function run(self, parentTestingInterface, runMode)
            try
                if ~isempty(parentTestingInterface)
                    self.parentTestingInterface = parentTestingInterface;
                    self.handleStruct.taskPanel = parentTestingInterface.handleStruct.taskPanel;
                end
                self.runMode = runMode;
                self.taskPointer = pointToNextTask(self);
                if ~isempty(self.taskPointer)
                    % Set up next task
                    self.handleStruct.nextTaskButton = uicontrol(self.handleStruct.taskPanel,...
                        'Style', 'pushbutton', ...
                        'String','Click Here to Start Next Task',...
                        'Units','normalized',...
                        'Position',[0.2 0.73 0.6 0.1],...
                        'FontUnits','normalized',...
                        'FontSize',0.5,...
                        'Callback',@(h,e)self.clearPanelAndBegin());
                    self.handleStruct.quitButton = uicontrol(self.handleStruct.taskPanel, ...
                        'Style','pushbutton',...
                        'Units','normalized',...
                        'Position',[0.8 0.01 0.15 0.08],...
                        'String','Quit',...
                        'FontUnits','normalized',...
                        'FontSize',0.25, ...
                        'Callback', @(h,e)self.saveAndClear(true));
                else
                    m = msgbox('All tasks complete!','Task List Complete','modal');
                    currentPos = get(m, 'Position');
                    set(m, 'Position', [currentPos(1:2) 200 currentPos(4)]);
                    uiwait(m);
                    self.saveAndClear(true);
                end
            catch ME
                if strncmp('sttTask:', ME.identifier, 8)
                    response = questdlg(...
                        {'An error occurred during the last task.' ...
                        'Would you like to save progress up to that task?'}, ...
                        'Save List Progress?', 'Yes');
                    if strcmp('Yes', response)
                        self.resetErrorTask();
                        self.saveAndClear();
                    end
                    
                    % Rethrow error to testing interface
                    throw(ME);
                else
                    % Create a base exception to indicate where this error
                    % occurred and append the cause to it.
                    baseME = MException(...
                        'sttTaskList:Run', ...
                        'Error occurred while running the task list.');
                    newME = addCause(baseME, ME);
                    self.taskListError(newME);
                end
            end
        end

        %............................................................
        % Determine the pointer to the next non-complete task
        %   Used in function run
        function taskPointer = pointToNextTask(self)
            taskPointer = [];
            for t = 1:length(self.taskList)
                status = self.taskList{t}.returnStatus();
                if strcmp(status, 'Error')
                    warnH = warndlg([...
                        'Skipping ' self.taskList{t}.taskTitle ' due to its ' ...
                        'error status.'], 'Task Status is Error', 'modal');
                    uiwait(warnH);
                elseif ~strcmp(status, 'Completed')
                    taskPointer = t;
                    break;
                end
                clear status
            end
        end

        %............................................................
        % Reset error task
        %   Used in function run
        function resetErrorTask(self)
            self.taskList{self.taskPointer}.updateStatus('Ready');
            self.taskList{self.taskPointer}.resetTask();
        end
        
        %............................................................
        % Clear the panel and run the next task
        function clearPanelAndBegin(self)
            % Clear panel
            exitGuiWithoutSaving(self)
            
            % Begin task
            self.taskList{self.taskPointer}.run(self);
        end
        
        %............................................................
        % Return subject.
        function subject = returnSubject(self)
            subject = self.subject;
        end

        %............................................................
        % Revert list back to old copy and exit.
        %   Used in function editTaskList
        function revertListAndExit(self)
            % Revert list
            self.taskList = self.listCopy.taskList;
            self.taskDataList = self.listCopy.taskDataList;
            self.listCopy = [];
            
            % Exit
            exitGuiWithoutSaving(self)
        end

        %............................................................
        % Save and exit GUI.
        function saveAndClear(self, clearDisplay)
            % Reset task pointer
            self.taskPointer = 1;
            
            % Save
            if ~isempty(self.taskListPath)
                self.overwriteList();
            else
                self.saveList();
            end
            
            % Clear
            if clearDisplay
                exitGuiWithoutSaving(self)
            end
            
            % Return control to parent testing interface
            if ~isempty(self.parentTestingInterface)
                self.parentTestingInterface.endTaskList();
            end
        end
        
        %............................................................
        % Overwrite task list and exit GUI.
        %   Used in function saveAndClear
        function overwriteList(self)
            % Save
            [filename, pathname] = uiputfile(self.taskListPath, 'Save Task Progress');
            isCancel = isequal(filename, 0) || isequal(pathname,0);
            while isCancel
                answer = questdlg('Are you sure you want to quit without saving?', ...
                    'Save?', ...
                    'Yes', 'No', 'No');
                if strcmp(answer, 'No')
                    [filename, pathname] = uiputfile(self.taskListPath, 'Save Task Progress');
                    isCancel = isequal(filename, 0) || isequal(pathname,0);
                else
                    break;
                end
            end
            
            if ~isCancel
                % Save copy of object without UI handles
                objAsByteArray = getByteStreamFromArray(self);
                taskListObj = getArrayFromByteStream(objAsByteArray);
                taskListObj.handleStruct = [];
                if ~isempty(taskListObj.parentTestingInterface)
                    close(taskListObj.parentTestingInterface.handleStruct.figure);
                    taskListObj.parentTestingInterface = [];
                end
                
                save(fullfile(pathname, filename), 'taskListObj')
                self.saveDir = pathname;
            end
        end

        %............................................................
        % Save task list and exit GUI.
        %   Used in function saveAndClear
        function saveList(self)
            % Save
            [fileName, filePath] = uiputfile(...
                fullfile(self.saveDir, ['taskList' datestr(now, 'yyyymmdd') '.mat']),...
                'Save Task List');
            isCancel = isequal(fileName, 0) || isequal(filePath,0);
            while isCancel
                answer = questdlg('Are you sure you want to quit without saving?', ...
                    'Save?', ...
                    'Yes', 'No', 'No');
                if strcmp(answer, 'No')
                    [fileName, filePath] = uiputfile(...
                        fullfile(self.saveDir, ['taskList' datestr(now, 'yyyymmdd') '.mat']),...
                        'Save Task List');
                    isCancel = isequal(fileName, 0) || isequal(filePath,0);
                else
                    break;
                end
            end
            
            if ~isCancel
                % Save copy of object without UI handles
                objAsByteArray = getByteStreamFromArray(self);
                taskListObj = getArrayFromByteStream(objAsByteArray);
                taskListObj.handleStruct = [];
                if ~isempty(taskListObj.parentTestingInterface)
                    close(taskListObj.parentTestingInterface.handleStruct.figure);
                    taskListObj.parentTestingInterface = [];
                end
                
                save(fullfile(filePath, fileName), 'taskListObj')
                self.saveDir = filePath;
            end
        end

        %............................................................
        % Handle errors.
        function taskListError(self, ME)
            % Notify researcher of task list error
            errH = errordlg(['Error occurred during task list operation: ' ...
                ME.cause{1}.message], ...
                'Task List Error', 'modal');
            uiwait(errH);
            
            % Save whatever there is
            [errorFile, savePath] = uiputfile(...
                ['taskListErrorFile' datestr(now, 'yyyymmdd') '.mat'],...
                'Save Error File');
            if (~isequal(errorFile, 0) && ~isequal(savePath,0))
                % Save copy of object without UI handles
                objAsByteArray = getByteStreamFromArray(self);
                taskListObj = getArrayFromByteStream(objAsByteArray);
                taskListObj.handleStruct = [];

                save(fullfile(savePath, errorFile), 'taskListObj');
            end

            % Rethrow error to testing interface
            throw(ME);
        end
        
        %............................................................
        % Exit task list GUI without saving.
        function exitGuiWithoutSaving(self)
            % Clear task panel
            if ~isempty(self.handleStruct)
                taskChildren = get(self.handleStruct.taskPanel, 'Children');
                while ~isempty(taskChildren)
                    delete(taskChildren(1));
                    taskChildren(1) = [];
                end
            end
        end
    end
end