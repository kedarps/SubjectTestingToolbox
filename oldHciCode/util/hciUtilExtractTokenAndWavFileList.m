
%
% Extract the list of tokens and their WAV files from a directory.
%

function [tokenList, wavFileList] = hciUtilExtractTokenAndWavFileList(tDir)

tokenFiles = dir([tDir '*.wav']);
tokenWavFiles = {tokenFiles.name};
for t = 1:length(tokenWavFiles)
    tokenList{t} = tokenWavFiles{t}(1:end-4);
    wavFileList{t} = [tDir tokenWavFiles{t}];
end
