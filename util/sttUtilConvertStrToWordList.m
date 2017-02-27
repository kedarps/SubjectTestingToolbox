
function words = sttUtilConvertStrToWordList(token)
%
% function words = sttUtilConvertStrToWordList(token)
%
% Convert a space-separated or capitals-concatenated string into a cell
% array of words.
%

% Remove any punctuation
token(isstrprop(token, 'punct')) = [];

if ~isempty(strfind(token, ' '))
    % Convert space-separated string.
    trimmedStr = strtrim(token);        % Remove leading/trailing spaces
    words = sttUtilParseStr(lower(trimmedStr), ' ');
elseif any(isstrprop(token, 'upper'))
    % Convert concatenated-capitals string
    capitals = find(isstrprop(token, 'upper'));
    for c = 1:length(capitals)-1
        words{c} = lower(token(capitals(c):capitals(c+1)-1));
    end
    words{end+1} = lower(token(capitals(end):end));
else
    % Return single word
    words = {token};
end
