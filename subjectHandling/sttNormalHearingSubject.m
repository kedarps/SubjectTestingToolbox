classdef sttNormalHearingSubject < sttSubject
    properties
    end
    
    methods
        %............................................................
        % Constructor - create a new subject.
        %   Normal hearing subjects are incredibly easy to create - they
        %   consist of a subject ID and nothing else.  No need for an
        %   elaborate GUI in order to enter information.
        function self = sttNormalHearingSubject(saveDir)
            % Get subject ID
            id = inputdlg('Enter subject ID:');
            if isempty(id)
                msgH = msgbox('No subject created.', '', 'modal');
                uiwait(msgH)
            else
                self.ID = id;
                self.saveSubject(saveDir);
            end
        end
        
        %............................................................
        % Normal hearing subjects don't have any parameters that can be
        % changed - if you change the ID, then it isn't the same subject.
        function isChanged = editSubject(self, taskPanel)
            msgH = msgbox(...
                'There are no parameters to edit for a normal hearing subject.', ...
                '', ...
                'modal');
            uiwait(msgH);
            isChanged = false;
        end
        
        %............................................................
        % View the current subject
        function viewSubject(self, taskPanel)
            msgH = msgbox(['Subject ID: ' char(self.ID)], 'Current Subject', 'modal');
            uiwait(msgH);
        end
                
        %............................................................
        % For normal hearing subjects, there really isn't anything
        % that needs to be done if an error occurs.
        function subjectError(self, ME)
            % Acknowledge error
            errH = errordlg({ME.identifier; ME.message},'Subject Error', 'modal');
            uiwait(errH);
        end
    end
end
