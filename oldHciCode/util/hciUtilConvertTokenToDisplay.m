
%
% Take a presentation token and convert it into a display string.
%

function displayStr = hciUtilConvertTokenToDisplay(presentationToken,tokenType)

switch lower(tokenType)
    case {'vowel','word'}
        displayStr = presentationToken;
    case 'consonant'
        displayStr = ['a' upper(presentationToken) 'a'];
    case 'sentence'
        locateCap = find(isstrprop(presentationToken,'upper'));
        
        if isempty(locateCap)
            displayStr = presentationToken;  % Must be a single word
        else
            for L = 1:length(locateCap)
                if L == length(locateCap)
                    displayStr = cat(2,displayStr, ...
                        [' ' lower(presentationToken(locateCap(L):end)) '.']);
                elseif L == 1
                    displayStr = lower(presentationToken(locateCap(L):(locateCap(L+1)-1)));
                    displayStr(1) = upper(displayStr(1));
                else
                    displayStr = cat(2,displayStr, ...
                        [' ' lower(presentationToken(locateCap(L):(locateCap(L+1)-1)))]);
                end
            end
        end
end
 