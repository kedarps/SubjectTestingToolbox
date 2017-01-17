function [seq,speechSampleSentFlag] = hciUtilSendSpeech(map, audio, fs)

%LMC, 5/30/2012
%client is the structure returned by initialiseClient
%map is NMT map structure
%stim_rate is pulse rate, pps
%audio is the vector of sound samples
%fs is the sampling rate of the sound samples
%
% CST 9/27/2012 Adding null pulses to beginning
% CST 10/1/2012 The audio sample rate had to be coded to 16kHz in order to
%               get stimuli that were the correct duration and looked like
%               speech...
% CST 10/24/2012 The 16kHz frequency is the device sampling rate.  This can
%                be changed, but it might result in strange changes to the
%                FFT bins used to assign freq information to the channels.
% KDM 02/03/2013 Added check for debug modes
% CST 03/12/2013 Added error checking for speech (function of pulse width,
%                pulse gap, number of maxima, and stimulation rate)

if hciUtilNoHardwareDebugMode
    seq = [];
    speechSampleSentFlag = true; % A lie
    return
end

seq.audio_sample_rate = 16000;
map.audio_sample_rate = seq.audio_sample_rate;
seq.stimuli=resample(audio,seq.audio_sample_rate,fs);

try
    seq.output_stimuli = Process(map,seq.stimuli);
    
    % Add null pulses
    seq.output_stimuli = startingNulls(seq.output_stimuli);
    
    % In order to send speech, it has to be physically possible to sequentially
    % stimulate the desired number of pulses at the rate specified.
    pulseDuration = (2*map.phase_width) + map.phase_gap;    % In microseconds
    durationOfMaxima = pulseDuration*map.num_selected/10^6; % In seconds
    if ((1/map.channel_stim_rate) < durationOfMaxima)
        speechSampleSentFlag = 0;
    else
        speechSampleSentFlag = 1;
    end
catch seqError
    errorStruct.audio = audio;
    errorStruct.Fs = fs;
    errorStruct.map = map;
    errorStruct.errorMsg = seqError.message;
    save(fullfile(hciRoot,'debuggingMatFiles','SpeechSequenceGenerationFailure'),'errorStruct');
    if isfield(errorStruct,'errorMsg')
        disp(errorStruct.errorMsg)
        msgbox('Please notify the test administrator of this error.','Sequence creation failed.','error');
    end
    speechSampleSentFlag = 0;
    seq = [];
end
    
