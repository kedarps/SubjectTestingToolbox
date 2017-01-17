
[noiseSignal, noiseFs] = wavread(fullfile(hciRoot, 'dependencies','Sounds','sounds','ccitt.wav'));
noiseSignalResample = resample(noiseSignal, 11025, 44100);

%%

n = size(noiseSignal);
fs = noiseFs;
%fs = 48200;

fs_paper = 44100;
num_paper = [11638, 54050, 91238, 67280, 18400];
denom_paper = [1, 130, 4001, 36040, 400];

num_coeff = ((2*pi*1000).^(-[4:-1:0])).*denom_paper; % 1000?
denom_coeff = ((2*pi*1000).^(-[4:-1:0])).*num_paper;

num_coeff = num_coeff / denom_coeff(1) * 10^(3.25/20); % This 10^(3.25/20) appears to be a magic constant that makes the scaling work out (I think)
denom_coeff = denom_coeff / denom_coeff(1);

% Convert to a digital filter;
[num_z, denom_z] = bilinear(num_coeff, denom_coeff, fs);

ssn = filter(num_z, denom_z, randn(n));

ssnResample = resample(ssn, noiseFs, fs);
%%

[aFile, gFile] = lpc(noiseSignal,78);
[aSynth, gSynth] = lpc(ssnResample,78);

[hFile, w] = freqz(1,aFile);
hFile = hFile./max(abs(hFile));
[hSynth, w] = freqz(1, aSynth);
hSynth = hSynth./max(abs(hSynth));

f = linspace(0, noiseFs/2, length(w)); % I think this is a sample or two off
plotHs = plot(f, abs(hFile),f, abs(hSynth),'r');
legend(plotHs, {'File -> Learn Filter', 'Paper Coefficients -> Generate -> Learn Filter'});


%%
fs = 44100;
ssn = hciUtilSpeechShapedNoise(fs, 2*fs);

sound(ssn, fs);