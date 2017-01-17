
function [tokenList, tokenListNames] = hciUtilGetTokenList(tokenDir)
%
% This function extracts a list of all .WAV files from a specified
%   directory.
%

tokenDirContents = dir(tokenDir);
tokenFiles = [tokenDirContents.isdir] == 0;
tokenDirContents(~tokenFiles) = [];
tokenCount = 1;
for t = 1:length(tokenDirContents)
    if ~isempty(strfind(lower(tokenDirContents(t).name),'.wav'));
        tokenName = tokenDirContents(t).name;
        tokenListNames{tokenCount} = tokenName(1:end-4);    % Discard extension
        tokenList(tokenCount) = {fullfile(tokenDir,tokenName)};
        tokenCount = tokenCount + 1;
    end
end
