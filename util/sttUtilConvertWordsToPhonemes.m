
function phonemesList = sttUtilConvertWordsToPhonemes(wordList, dictionary)
%
% function phonemesList = sttUtilConvertWordsToPhonemes(wordList, dictionary)
%
% This function converts a cell array of words into a cell array of phoneme
% cell arrays.  Essentially each word is replaced by a cell array of
% phonemes.
%


for i = 1:length(wordList)
    % Remove punctuation, if any
    word = wordList{i};
    word(isstrprop(word, 'punct')) = [];

    % If the word is empty, return empty list
    if isempty(wordList)
        phonemes = {' '};
    else
        % Otherwise, look for a dictionary match
        wordMatch = strcmpi(word,[dictionary.word]);
        if any(wordMatch)
            % If there's a match, copy the phoneme list from the dictionary
            phonemes = dictionary(wordMatch).phonemeList;
        else
            % If there's no match, guess at the phonemes
            for w = 1:length(word)
                switch word(w)
                    case {'b','d','f','g','k','l','m','n','p','r','s',...
                            't','v','w','y','z'}
                        phonemes{w} = upper(word(w));
                    case 'a'
                        phonemes{w} = 'AE';
                    case {'c','q'}
                        phonemes{w} = 'K';
                    case 'e'
                        phonemes{w} = 'EH';
                    case 'h'
                        phonemes{w} = 'HH';
                    case 'i'
                        phonemes{w} = 'IH';
                    case 'j'
                        phonemes{w} = 'JH';
                    case 'o'
                        phonemes{w} = 'AA';
                    case 'u'
                        phonemes{w} = 'AH';
                    case 'x'
                        phonemes{w} = 'Z';
                    otherwise
                        phonemes{w} = [];
                end
            end
        end
    end
    
    % Add to the list
    phonemesList{i} = phonemes;
end
    
