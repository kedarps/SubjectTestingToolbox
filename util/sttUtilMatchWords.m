
function [comparisonMatchesI, originalMatchesI] = ...
    sttUtilMatchWords(originalList, comparisonList)
%
% function [comparisonMatchesI, originalMatchesI] = ...
%    sttUtilMatchWords(originalList, comparisonList)
%
% This function tries to find the best word match between two word lists.
%   Each word is scored against all the other words, and the highest
%   scoring pair is considered the first match.  From there, the lists 
%   are recursively split on matches such that the best match between
%   remaining list segments is determined.  This allows for scoring
%   sentences that may have omissions or additions.
%
% VARIABLES:
%   originalList    -   Cell array containing cell arrays of strings.  Each
%                       element represents a list of phonemes for a word.
%   comparisonList  -   Another list of words represented by their
%                       phonemes. These words are matched to the original
%                       list.
%   
% OUTPUT
%   comparisonMatchesI   -   A list of indices indicating which words in
%                       the comparison list were matched to the original
%                       list
%   originalMatchesI   -   A list of indices indicating which words in
%                       the original list were matched
%


%--------------------------------------------------------------------
% First determine match scores between all words.
numT = length(originalList);
numR = length(comparisonList);

matchScore = NaN(numR,numT);
for r = 1:numR
    for t = 1:numT
        numMatches = sttUtilMatchPhonemes(originalList{t},comparisonList{r});
        matchScore(r,t) = numMatches;
        clear numMatches
    end
end


%------------------------------------------------------------------
% Recursively select best match.
match(1).matrix = matchScore;
match(1).matched = false;
match(1).matchPairI = NaN(1,2);
match(1).rowI = 1:numR;
match(1).colI = 1:numT;

while (sum([match.matched]) < length(match))
    splitMatrices = struct([]);
    for m = 1:length(match)
        if ~match(m).matched
            matchPair = findBestMatch(match(m).matrix);
            [updatedMatrix, newMatrices] = splitMatrixOnMatch(match(m),matchPair);
            match(m) = updatedMatrix;
            if ~isempty(newMatrices)
                splitMatrices = cat(1,splitMatrices,newMatrices(:));
            end
            clear matchPair updatedMatrix newMatrices
        end
    end
    match = cat(1,match,splitMatrices);
end


%--------------------------------------------------------------------
% Extract indices of selected response words and their match to
% presentation.
responseTruePair = sortrows(vertcat(match.matchPairI));
comparisonMatchesI = responseTruePair(:,1);
originalMatchesI = responseTruePair(:,2);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Additional functions.

%.....................................................................
% Find best match.
function matchPair = findBestMatch(matchScore)

[maxScorePerResponse, maxScorePerResponseI] = max(matchScore,[],2);

maxScoreAcrossResponse = max(maxScorePerResponse);
bestMatches = find(maxScorePerResponse==maxScoreAcrossResponse);
matchI = bestMatches(1);
matchPair = [matchI maxScorePerResponseI(matchI)];
            

%.....................................................................
% Split matrices based on best match.
function [match, newMatrices] = splitMatrixOnMatch(match,matchPair)

% Update old matrix
match.matched = true;
match.matchPairI = [match.rowI(matchPair(1)) match.colI(matchPair(2))];

% Split old matrix
matchScore = match.matrix;
newMatrix{1} = matchScore(1:matchPair(1)-1,1:matchPair(2)-1);
newMatrix{2} = matchScore(matchPair(1)+1:end,matchPair(2)+1:end);

% Create new matrix structure elements
newMatrices = struct([]);
for n = 1:length(newMatrix)
    if ~isempty(newMatrix{n})
        newMatrices(end+1).matrix = newMatrix{n};
        newMatrices(end).matched = false;
        newMatrices(end).matchPairI = NaN(1,2);
        
        if n == 1
            newMatrices(end).rowI = match.rowI(1):match.matchPairI(1)-1;
            newMatrices(end).colI = match.colI(1):match.matchPairI(2)-1;
        else
            newMatrices(end).rowI = match.matchPairI(1)+1:match.rowI(end);
            newMatrices(end).colI = match.matchPairI(2)+1:match.colI(end);
        end
    end
end




