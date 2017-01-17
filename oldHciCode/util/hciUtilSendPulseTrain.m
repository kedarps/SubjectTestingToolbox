function [seq,testResults,pulseSentFlag] = hciUtilSendPulseTrain(map,electrode,magnitude,stim_rate,duration)

%LMC, 5/30/2012
%Error checking added.... testing complete 6/19/2012
%
%client is the structure returned by initialiseClient
%map is NMT map structure
%electrode is the electrode on which to present the pulse train
%magnitude is the amplitude in current steps - could do error checking with
%  Ts and Cs in map, but not currently done
%stim_rate is the pulse rate, pps
%duration is the duration of the stimulus in seconds
%
%on return, 
%seq is the sequence that was transmitted
%client is the client
%testResults is a structure of the outcome of the error checks
%pulseSentFlag indicates whether the pulse was actually sent - 
%initially only NOT sent if the rate is in error
%
% CST 9/27/2012     Add null pulses
% CST 10/24/2012    Add interleaved null pulses
% KDM 02/03/2013    Added check for debug mode

if hciUtilNoHardwareDebugMode
    seq = [];
    testResults = [];
    pulseSentFlag = true; % A lie
    return
end

if ((0<magnitude) && (magnitude<=255))
    testResults.validMagnitude = true;
else
    testResults.validMagnitude = false;
    pulseSentFlag = false;
    return
end

if ~isempty(find(map.electrodes==electrode,1))
    testResults.validElectrode = true;
else
    testResults.validElectrode = false;
    pulseSentFlag = false;
    return
end

electrodeI = map.channel_order(map.electrodes==electrode);
if ((map.threshold_levels(electrodeI)<=magnitude) && (magnitude<=map.comfort_levels(electrodeI)))
    testResults.inRangeMagnitude = true;
else
    testResults.inRangeMagnitude = false;
end

% 1 cycle of the given rate occurs in 1/rate seconds or
% (1/rate)*1000 ms
% need to verify units of phase_width and phase_gap
if ((2*map.phase_width/1000 + map.phase_gap/1000) > (1/stim_rate)*1000)
    testResults.validRate = false;
    pulseSentFlag = false;
    return
else
    testResults.validRate = true;
    pulseSentFlag = true;
end

try
    %per Sara, and PrepStim, these are need to let the sequence structure
    %have all of the fields that it needs
    seq = Gen_sequence(electrode, magnitude, stim_rate, duration); %NMT function
    seq.electrodes = seq.channels;
    seq.current_levels = seq.magnitudes;
    seq = rmfield(seq, 'channels');
    seq = rmfield(seq, 'magnitudes');
    seq.modes = map.modes;
    seq.phase_gaps = map.phase_gap;
    seq.phase_widths = map.phase_width;
    
    % Interleave null pulses if the pulse rate is too low (< 1000 pps)
    seq = hciUtilInterleaveNullPulses(seq);
    
    % Add starting nulls to turn on processor
    seq = startingNulls(seq);
catch seqError
    errorStruct.map = map;
    errorStruct.electrode = electrode;
    errorStruct.magnitude = magnitude;
    errorStruct.stim_rate = stim_rate;
    errorStruct.duration = duration;
    errorStruct.errorMsg = seqError.message;
    save(fullfile(hciRoot,'debuggingMatFiles','PulseTrainGenerationFailure'),'errorStruct');
    if isfield(errorStruct,'errorMsg')
        disp(errorStruct.errorMsg)
        msgbox('Please notify the test administrator of this error.','Sequence creation failed.','error');
    end
    pulseSentFlag = 0;
    seq = [];
end



