
function [newMap,newMapCreatedFlag] = hciUtilCreateTemporaryMapForStimulation(origMap,varargin)
%
% This function uses map generation to make a new map.
%

p.implant.IC            = origMap.implant.IC;
p.num_bands             = origMap.num_bands;
p.electrodes            = origMap.electrodes;
p.modes					= origMap.modes;
p.threshold_levels      = origMap.threshold_levels;
p.comfort_levels        = origMap.comfort_levels;
p.phase_width			= origMap.phase_width;		% microseconds
p.phase_gap				= origMap.phase_gap;		% microseconds
p.num_selected			= origMap.num_selected;
p.channel_stim_rate     = origMap.channel_stim_rate;
p.Q                     = origMap.Q;

if ~isempty(varargin)
    for v = 1:2:length(varargin)
        parameterName = varargin{v};
        parameterValue = varargin{v+1};
        
        % Special action is required if the electrodes are changed
        if strcmpi(parameterName,'electrodes')
            warning('Changing active electrodes...');
            p.electrodes = [];
            p.threshold_levels = [];
            p.comfort_levels = [];
            for e = 1:length(parameterValue)
                eMatch = parameterValue(e) == origMap.electrodes;
                p.electrodes(e) = parameterValue(e);
                p.threshold_levels(e) = origMap.threshold_levels(eMatch);
                p.comfort_levels(e) = origMap.comfort_levels(eMatch);
            end
            p.num_bands = length(p.electrodes);
            if (p.num_selected > p.num_bands)
                warning(['Number of maxima too high for number of active ' ...
                    'electrodes.  Maxima set to number of electrodes.']);
                p.num_selected = p.num_bands;
            end
            % Otherwise, can just set new parameter value
        else
            p.(parameterName) = parameterValue;
        end
    end
end

% The NMT will not allow a map to be created that cannot send speech.
try
    if p.Q < 1
        error('Q is less than 1.');
    end
    
    pulseDuration = (2*p.phase_width) + p.phase_gap;    % In microseconds
    durationOfMaxima = pulseDuration*p.num_selected/10^6; % In seconds
    if ((1/p.channel_stim_rate) < durationOfMaxima)
        newMapCreatedFlag = 0;
        newMap = [];
    else
        newMapCreatedFlag = 1;
        newMap = ACE_map(p);
    end
    
    % Map debugging
    if (length(newMap.electrodes) ~= length(newMap.threshold_levels)) || ...
            (length(newMap.electrodes) ~= length(newMap.comfort_levels))
        error('The number of DR values does not equal the number of electrodes.')
    end
    
    if ~isempty(find([isnan(newMap.electrodes); isnan(newMap.threshold_levels); ...
            isnan(newMap.comfort_levels)]))
        error('There are NaNs in the new map.')
    end
catch mapError
    errorStruct.p = p;
    errorStruct.origMap = origMap;
    errorStruct.errorMsg = mapError.message;
    save(fullfile(hciRoot,'debuggingMatFiles','MapGenerationFailure'),'errorStruct');
    if isfield(errorStruct,'errorMsg')
        disp(errorStruct.errorMsg)
        msgbox('Please notify the test administrator of this error.','Map creation failed.','error');
    end
    newMapCreatedFlag = 0;
    newMap = p;
end    

