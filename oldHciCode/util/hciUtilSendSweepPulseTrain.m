function [seq,testResults,pulseSentFlag] = hciUtilSendSweepPulseTrain(map,...
    sweepMagnitudes,electrodes, stim_rate,duration)
%
% function [seq,testResults,pulseSentFlag] = hciUtilSendSweepPulseTrain(map,
%       sweepMagnitudes,electrodes, stim_rate,duration)
%
% This function is based off of hciUtilSendPulseTrain.  The difference is
%   that a pulse train is sent on each electrode at sweepMagnitudes current
%   level.  Duration refers to the duration of the sweep, not the duration
%   of indivdual pulse trains.
%
% VARIABLES:
%   map                 -   NMT structure containing all the map parameters
%   sweepMagnitudes     -   (array) Level of stimulation for each electrode
%                           pulse train
%   stim_rate           -   (scalar) Pulse rate for pulse trains (pps)
%   duration            -   (scalar) Duration of the entire sweep in
%                           seconds
%
% OUTPUT:
%   seq                 -   Sequence structure expected by NMT for
%                           streaming
%   testResults         -   Structure indicating which error checks were
%                           successful
%   pulseSentFlag       -   Flag indicating whether pulse train passed all
%                           error checks
%
%
% KDM 02/03/2013    Added check for debug mode

if hciUtilNoHardwareDebugMode
    seq = [];
    testResults = [];
    pulseSentFlag = true; % A lie
    return
end

if length(electrodes(~isnan(electrodes))) ~= length(sweepMagnitudes)
    error(['The number of electrodes (' num2str(length(electrodes(~isnan(electrodes)))) ...
        ') does not equal the number of stimulation magnitudes (' ...
        num2str(length(sweepMagnitudes)) ').'])
end
electrodes(isnan(electrodes)) = [];

% Make certain that duration is long enough that each electrode receives at
%   least one pulse
durationPerElectrode = duration/length(electrodes);
numberOfPulsesPerElectrode = durationPerElectrode * stim_rate;
if (numberOfPulsesPerElectrode < 1)
    testResults.validDuration = false;
    pulseSentFlag = false;
    return
else
    testResults.validDuration = true;
end

try
    % Generate sweep sequence structure
    for e = 1:length(electrodes)
        electrode = electrodes(e);
        electrodeI = map.channel_order(map.electrodes==electrode);
        magnitude = sweepMagnitudes(electrodeI);
        
        % Generate pulse train for electrode
        seq = Gen_sequence(electrode, magnitude, stim_rate, durationPerElectrode); %NMT function
        
        % Check for valid magnitude
        if ((0<magnitude) && (magnitude<=255))
            testResults(e).validMagnitude = true;
        else
            testResults(e).validMagnitude = false;
            pulseSentFlag = false;
            return
        end
        
        % Indicate whether magnitude is between T's and C's
        if ((map.threshold_levels(electrodeI)<=magnitude) && (magnitude<=map.comfort_levels(electrodeI)))
            testResults(e).inRangeMagnitude = true;
        else
            testResults(e).inRangeMagnitude = false;
        end
        
        % Check that stimulation possible for phase_width and phase_gap
        if ((2*map.phase_width/1000 + map.phase_gap/1000) > (1/stim_rate)*1000)
            testResults(e).validRate = false;
            pulseSentFlag = false;
            return
        else
            testResults(e).validRate = true;
            pulseSentFlag = true;
        end
        
        % Expand relevant fields when NMT gives a single value
        if (length(seq.channels) == 1)
            seq.channels = seq.channels*ones(size(seq.magnitudes));
        end
        
        % If no errors, append sequence onto previous sequence
        if e == 1
            totalSeq = seq;
        else
            totalSeq.channels = vertcat(totalSeq.channels,seq.channels);
            totalSeq.magnitudes = vertcat(totalSeq.magnitudes,...
                seq.magnitudes);
        end
        clear seq electrode magnitude
    end
    
    
    %per Sara, and PrepStim, these are need to let the sequence structure
    %have all of the fields that it needs
    
    seq.electrodes = totalSeq.channels;
    seq.current_levels = totalSeq.magnitudes;
    seq.periods = totalSeq.periods;
    seq.modes = map.modes;
    seq.phase_gaps = map.phase_gap;
    seq.phase_widths = map.phase_width;
    
    % Interleave null pulses if the pulse rate is too low (< 1000 pps)
    seq = hciUtilInterleaveNullPulses(seq);
    
    % Add starting nulls to turn on processor
    seq = startingNulls(seq);
catch seqError
    errorStruct.map = map;
    errorStruct.electrodes = electrodes;
    errorStruct.sweepMagnitudes = sweepMagnitudes;
    errorStruct.stim_rate = stim_rate;
    errorStruct.duration = duration;
    errorStruct.errorMsg = seqError.message;
    save(fullfile(hciRoot,'debuggingMatFiles','SweepSequenceGenerationFailure'),'errorStruct');
    if isfield(errorStruct,'errorMsg')
        disp(errorStruct.errorMsg)
        msgbox('Please notify the test administrator of this error.','Sequence creation failed.','error');
    end
    pulseSentFlag = 0;
    seq = [];
end
    
    
