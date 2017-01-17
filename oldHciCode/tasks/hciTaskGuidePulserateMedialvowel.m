classdef hciTaskGuidePulserateMedialvowel < hciTaskGuide
    properties
    end
    
    methods
        function self = hciTaskGuidePulserateMedialvowel(varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
                
            if nargin~=0 && ~self.hgIsValid
                self.create();
            end
            
            init(self)
        end
        
        function init(self)
            self.uiTaskList = {...
                'hciTaskSetPulseRate',...
                'hciTaskClosedSetSpeechTestMedialVowel'};
            
            setup(self)
        end

    end
end