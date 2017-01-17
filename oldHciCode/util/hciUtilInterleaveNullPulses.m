function seq = hciUtilInterleaveNullPulses(seq)
%
% function seq = hciUtilInterleaveNullPulses(seq)
%
% This function is based off the non-modular function created by JD to
% interleave null pulses into single electrode pulse trains in order to
% ensure that the stimulation rate is at least 1 kHz.  This is necessary to
% keep the implant powered (see https://dukecilab.wikispaces.com/).
%
% Note:  This is not necessary for multi-electrode stimulation such as
% speech since it is the overall rate (how many pulses are sent per second)
% that determines if the implant is powered, not the channel stimulation
% rate (pulses on a single electrode per second).
%
% VARIABLES:
%   seq     -   A sequence structure (e.g. created by Gen_sequence or
%               Process) containing the fields: electrodes, current_levels,
%               modes, phase_gaps, phase_widths, and periods.  Note:  pulse
%               rate is assumed to be constant (i.e. seq.periods = scalar).
%
% OUTPUT:
%   seq     -   The sequence with null pulses interleaved to increase the
%               pulse rate, if required.  This will affect the fields
%               current_levels and possibly electrodes.
%


% If pulse rate is too low:
if(1e6/seq.periods < 1000)
    
    if(length(seq.periods) > 1)
        error('Pulse rate of stimuli must be constant')
    end

    % Calculate new stimulation rate
    channel_stim_rate = 1e6/seq.periods;
    nSpacers = floor(1000/channel_stim_rate);
    total_stim_rate = channel_stim_rate*(nSpacers+1);

    % Quantise stim_rate to RF frequency
    seq.periods = round(5e6 / total_stim_rate) / 5;		% microseconds
    
    % Calculate the number of zero pulses needed between each pulse
    nSpacers = round((1e6/seq.periods)/channel_stim_rate - 1);
    
    % Add null pulses
    orig_length = length(seq.current_levels);
    seq.current_levels = reshape(cat(1,seq.current_levels(:)',zeros(nSpacers,orig_length)),(nSpacers+1).*orig_length,1);
    if length(seq.electrodes) == 1
        seq.electrodes = reshape(cat(1,seq.electrodes*ones(1,orig_length),zeros(nSpacers,orig_length)),(nSpacers+1).*orig_length,1);
    else
        seq.electrodes = reshape(cat(1,seq.electrodes(:)',zeros(nSpacers,orig_length)),(nSpacers+1).*orig_length,1);
    end
end