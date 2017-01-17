
%
% function [numMatches,trueMatched,exactMatch] = ...
%   hciUtilMatchPhonemes(trueGroup, responseGroup)
%
% This function finds phoneme matches.  
%
% Note:  This function enforces order, e.g. if the true word is 'dark' and
% the response is 'keeper', the 'k' would be considered a match, but the
% 'r' would not since it is out of order.
%   

function [numMatches,trueMatched,exactMatch] = ...
    hciUtilMatchPhonemes(trueGroup, responseGroup)

numT = length(trueGroup);
numR = length(responseGroup);

% Check for exact match
exactMatch = false;
if (numT == numR)
    if (sum(strcmp(responseGroup,trueGroup))==numT)
        exactMatch = true;
        trueMatched = true(numT,1);
        numMatches = numT;
    end
end

% If not an exact match, determine how many matches
if ~exactMatch
    % Compute distance between phonemes
    [distBetweenPhonemes,editPath] = ...
        edit_distance_levenshtein_phonemes(trueGroup,responseGroup);
    
    % Best phoneme match
    numMatches = length(trueGroup) - distBetweenPhonemes;
    if numMatches < 0
        numMatches = 0;
        trueMatched = false(numT,1);
    else
        editResponsePhonemes = hciUtilEditDistancePath(editPath,responseGroup);
        trueMatched = strcmp(trueGroup,editResponsePhonemes);
        numMatches = sum(trueMatched);
    end
end




