function [b, a] = hciUtilSpeechShapedNoiseFilterCoefficients(fs)
% [b a] = hciUtilSpeechShapedNoiseFilterCoefficients(fs)
%
% fs  should be > 44100
%
%
% I found this block of code on the internet
%  http://www.auditory.org/mhonarc/2005/msg00098.html
% 
% I then varified it and compared the results to a method I got from Josh.
%
% %
% % function y = ccitt_filter(sig)
% %
% % CCITT (ITU) standard G.227 defines a 'conventional
% % telephone signal' which equals the long-term spectrum
% % of speech. The standard defines a filter to simulate
% % the speech spectrum which is applied to the input signal
% % sig.
% %
% % sig    Input signal sig at 44100 Hz sampling rate
% % y      CCITT filtered signal sig
% %
% % Bernhard Seeber, 2005
% 
% fs = 44100;
% 
% %Generate filter coefficients
% %in S/Omega-plane
% %num_paper = [11638, 54050, 91238, 67280, 18400];
% %denom_paper = [1, 130, 4001, 36040, 400];
% 
% %make inverted freq-response and shift to 0dB @ 600Hz
% %num_coeff = ((2*pi*1000).^(-[4:-1:0])).*denom_paper;
% %denom_coeff = ((2*pi*1000).^(-[4:-1:0])).*num_paper;
% 
% %for comparison, converted to Omega
% %num_coeff = [7.46722e-12, 2.17899e-7, 2.311086e-3, 10.7079, 18400];
% %denom_coeff = [6.41624e-16, 5.24087e-10, 1.01347e-4, 5.7359, 400];
% 
% %scale coefficients
% %num_coeff = num_coeff / denom_coeff(1) * 10^(3.25/20);
% %denom_coeff = denom_coeff / denom_coeff(1);
% 
% %freqs(num_coeff, denom_coeff);
% 
% %convert to z-plane
% %[num_z, denom_z] = bilinear(num_coeff, denom_coeff, fs);
% 
% %freqz(num_z, denom_z, 1024, fs);
% 
% num_z = [0.00396790391508   0.00032556793042  -0.00314367152058  -0.00104604251859 -0.00008875919940];
% denom_z = [1.00000000000000  -3.39268359295324   4.31295903323020  -2.43473845585969  0.51493759484342];
% 
% y = filter(num_z, denom_z, sig);

if nargin < 1 || isempty(fs)
    fs = 44100;
end

% if fs<44100
%     warning('hci:hciUtilSpeechShapedNoiseFilterCoefficients','Speech shaped noise is potentially weird when fs < 44100. Talk to Kenny.');
% end

if fs == 44100
    % Short cut
    
    b = [0.00396790391508   0.00032556793042  -0.00314367152058  -0.00104604251859 -0.00008875919940];
    a = [1.00000000000000  -3.39268359295324   4.31295903323020  -2.43473845585969  0.51493759484342];
else
    num_paper = [11638, 54050, 91238, 67280, 18400];
    denom_paper = [1, 130, 4001, 36040, 400];
    
    num_coeff = ((2*pi*1000).^(-[4:-1:0])).*denom_paper; % ?
    denom_coeff = ((2*pi*1000).^(-[4:-1:0])).*num_paper;
    num_coeff = num_coeff / denom_coeff(1) * 10^(3.25/20); % ?
    denom_coeff = denom_coeff / denom_coeff(1);
    
    [b, a] = bilinear(num_coeff, denom_coeff, fs);
end



