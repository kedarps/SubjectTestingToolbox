
%
% Convert a sentence into a string without white space and punctuation.
%

function wordStr = hciUtilConvertSentenceToStr(wordStr)

% Make each new word start with a capital letter
wordStr(find(isstrprop(wordStr,'wspace'))+1) = ...
    upper(wordStr(find(isstrprop(wordStr,'wspace'))+1));

% Remove spaces and punctuation
wordStr(isstrprop(wordStr,'wspace')) = [];
wordStr(isstrprop(wordStr,'punct')) = [];
