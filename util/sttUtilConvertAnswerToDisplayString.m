
function displayStr = sttUtilConvertAnswerToDisplayString(answerStr)
%
% function displayStr = sttUtilConvertAnswerToDisplayString(answerStr)
%
% This function converts a space-separated or concatenated-capitals string
% into a typical string for display.
%


if ~isempty(strfind(answerStr, ' '))
    % Convert space-separated string.
    trimmedStr = strtrim(answerStr);
    displayStr = upper(trimmedStr(1));
    displayStr = [displayStr lower(trimmedStr(2:end)) '.'];
elseif any(isstrprop(answerStr, 'upper'))
    % Convert concatenated-capitals string
    capitals = find(isstrprop(answerStr, 'upper'));
    displayStr = answerStr(1:capitals(2)-1);
    for c = 3:length(capitals)
        displayStr = [displayStr ' ' lower(answerStr(capitals(c-1):capitals(c)-1))];
    end
    displayStr = [displayStr ' ' lower(answerStr(capitals(end):end)) '.'];
else
    % Return single word
    displayStr = answerStr;
end
    