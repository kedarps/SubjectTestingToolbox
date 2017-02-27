
function [numCorrect, numTotal] = sttUtilScoreOpenSetSpeech(...
    guess, truth, dictionary)
%
% function [numCorrect, numTotal] = sttUtilScoreOpenSetSpeech(...
%    guess, truth, dictionary)
%
% This function automatically scores a set of words against a true set of
% words and returns the number of correct and total number of phonemes.
%
% VARIABLES:
%   guess       -   A string with words separated either by spaces or
%                   concatenated without white space, with each word
%                   capitalized.  This is the string that will be scored
%                   for its match to the truth.
%   truth       -   A string as above, used to score the guess string
%   dictionary  -   A structure for which each element represents a
%                   word.  The fields should include 'word' which is a
%                   cell containing a word string, and 'phonemeList' which
%                   is a cell array of strings representing the phonemes,
%                   in word order, that make up the word.
%   
% OUTPUT
%   numCorrect  -   Number of phonemes in 'guess' that match the phonemes
%                   in 'truth'
%   numTotal    -   Total number of phonemes in 'truth'
%


% First separate the guess and answer into cell arrays of words
guessList = sttUtilConvertStrToWordList(guess);
truthList = sttUtilConvertStrToWordList(truth);

% Convert each word into a list of phonemes
guessListPhonemes = sttUtilConvertWordsToPhonemes(guessList, dictionary);
truthListPhonemes = sttUtilConvertWordsToPhonemes(truthList, dictionary);

% Based on the phonemes, try to find the best matches between the two word
% lists.  The outputs are the indices of the truth and guess words that
% were matched.
[matchedGuessWordsI, matchedTruthWordsI] = ...
    sttUtilMatchWords(truthListPhonemes, guessListPhonemes);

% Determine the number of matching phonemes for each of the matched word 
% pairs
truthWords = truthListPhonemes(matchedTruthWordsI);
guessWords = guessListPhonemes(matchedGuessWordsI);
numCorrect = 0;
for w = 1:length(truthWords)
   numCorrect = numCorrect + sttUtilMatchPhonemes(truthWords{w}, guessWords{w}); 
end

% Determine the total number of phonemes
numTotal = 0;
for t = 1:length(truthListPhonemes)
    numTotal = numTotal + length(truthListPhonemes{t});
end

