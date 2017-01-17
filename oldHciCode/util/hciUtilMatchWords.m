
%
% This function tries to find the best word match for a sentence.
%

function [respI, matchedI] = hciUtilMatchWords(trueGroup, responseGroup)

%--------------------------------------------------------------------
% First determine match scores between all words.
numT = length(trueGroup);
numR = length(responseGroup);

matchScore = NaN(numR,numT);
for r = 1:numR
    for t = 1:numT
        numMatches = hciUtilMatchPhonemes(trueGroup{t},responseGroup{r});
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
respI = responseTruePair(:,1);
matchedI = responseTruePair(:,2);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Find best match and split matrices.
function matchPair = findBestMatch(matchScore)

[maxScorePerResponse, maxScorePerResponseI] = max(matchScore,[],2);

maxScoreAcrossResponse = max(maxScorePerResponse);
bestMatches = find(maxScorePerResponse==maxScoreAcrossResponse);
matchI = bestMatches(1);
matchPair = [matchI maxScorePerResponseI(matchI)];
            


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Find best match and split matrices.
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




