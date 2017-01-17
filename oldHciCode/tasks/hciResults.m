classdef hciResults 
    properties
        type = 'Unknown';
        results = struct([]);
    end
    methods
        function self = hciResults(varargin)
            self = prtUtilAssignStringValuePairs(self, varargin{:});
        end
        function export(self, fileName)
            keyboard
        end
    end
end