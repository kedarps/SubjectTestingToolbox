
function numPhonemeMatches = sttUtilMatchPhonemes(originalWord, comparisonWord)
%
% function numPhonemeMatches = sttUtilMatchPhonemes(originalWord, comparisonWord)
%
% This function returns the number of phoneme matches between the original
%   word and comparison word using Levenshtein edit distance.  Words are
%   assumed to be cell arrays of phonemes.
%
% VARIABLES:
%   originalWord    -   Cell array of strings representing the word's
%                       phonemes
%   comparisonWord  -   Cell array of strings representing the word's
%                       phonemes.  This word is compared to the original
%                       word to determine the number of phonemes that match
%   
% OUTPUT
%   numPhonemeMatches   -   Integer count of the number of phonemes that
%                       match between words
%


% Check for an exact match betwen words
if length(originalWord) == length(comparisonWord)
    exactMatch = all(strcmp(originalWord, comparisonWord));
else
    exactMatch = false;
end

% Determine the number of phoneme matches
if exactMatch
    % If an exact match, the number of phoneme matches = number of phonemes
    numPhonemeMatches = length(originalWord);
else
    % If not an exact match, determine how many phonemes match
    %
    % NOTE:  Order is enforced, e.g. if the original word is 'cool'
    % and the comparison word is 'look', only the 'l' phoneme will be
    % matched since the 'k' phoneme is out of order
    matchWord = originalWord;
    numPhonemeMatches = 0;
    for p = 1:length(comparisonWord)
        phonemeMatch = find(strcmp(comparisonWord{p}, matchWord), 1, 'first');
        numPhonemeMatches = numPhonemeMatches + length(phonemeMatch);
        if ~isempty(phonemeMatch)
            matchWord(1:phonemeMatch) = [];
        end
    end
end




