classdef (Abstract) sttSubject < matlab.mixin.SetGet
    % Abstract class for creating subjects.  Every subject type must have
    % methods for handling the creation of new subjects, loading previous
    % subjects, editing subjects, saving current subjects, viewing the
    % current subject, and handling errors during tasks.
    
    properties
        % Every subject must have an ID.  This should not contain
        % personally identifiable information (e.g. a name).
        ID
    end
    
    methods (Abstract)
        isChanged = editSubject(self, taskPanel)
        viewSubject(self, taskPanel)
        subjectError(self, ME)
    end
    
    methods
        %............................................................
        % Return the subject's ID.
        function subjectID = returnSubjectID(self)
            subjectID = self.ID;
        end
        
        %............................................................
        % Save subject information.
        function saveSubject(self, saveDir)
            % Initial save directory
            if (nargin < 2)
                saveDir = pwd;
            elseif isempty(saveDir)
                saveDir = pwd;
            end
            
            % Create save name and get path
            saveName = ['subject' char(self.ID) '_' datestr(now, 30) '.mat'];
            saveLocation = fullfile(saveDir, saveName);
            [saveName, savePath] = uiputfile(saveLocation, 'Save Subject');
            
            % Check path selection
            isCancel = isequal(saveName, 0) || isequal(savePath,0);
            while isCancel
                answer = questdlg('Are you sure you want to quit without saving?', ...
                    'Save?', ...
                    'Yes', 'No', 'No');
                if strcmp(answer, 'No')
                    [saveName, savePath] = uiputfile(saveLocation, 'Save Subject');
                    isCancel = isequal(saveName, 0) || isequal(savePath,0);
                else
                    break;
                end
            end
            
            if ~isCancel
                % Save copy of object
                objAsByteArray = getByteStreamFromArray(self);
                subject = getArrayFromByteStream(objAsByteArray);
                save(fullfile(savePath, saveName), 'subject');
            end
        end
    end
end