
%
% Randomize some speech.
%

function [stimulusList, stimulusTokens] = randomizeTokens(speechDir)

% Get all files
wavFiles = sttUtilGetFilesInDirectory(speechDir, '.wav');

% Read in files
for w = 1:length(wavFiles)
    stimulusList{w} = sttUtilReplaceStr(wavFiles{w}, [], '.wav');
%     [stimulusTokens(w).signal, stimulusTokens(w).Fs] = audioread([speechDir wavFiles{w}]);
    [stimulusTokens(w).signal, stimulusTokens(w).Fs] = wavread([speechDir wavFiles{w}]);
end

% Randomize
randOrder = randperm(length(wavFiles));
stimulusList = stimulusList(randOrder);
stimulusTokens = stimulusTokens(randOrder);

