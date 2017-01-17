
%
% This function looks for the best match between two groups, splits the
%   groups based on this match, and returns the match and its index.
%

function [splitTrueGroup,splitResponseGroup, match, matchI] = ...
    hciUtilFindMatchAndSplit(trueGroup, responseGroup, Options)

%------------------------------------------------------------------
% Determine matches between members of groups.
numT = length(trueGroup);
numR = length(responseGroup);

% Compare each response word to every presentation word
matchScore = NaN(numT,numR);
for r = 1:numR
    rVal = responseGroup{r};
    for t = 1:numT
        tVal = trueGroup{t};
        numMatches = Options.matchFcn(tVal,rVal);
        matchScore(r,t) = ...
            numMatches/length(tVal);
        clear numMatches tVal
    end
    clear rVal
end

