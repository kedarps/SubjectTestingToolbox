
%
% Find an optimal path in edit distance.
%

function matchedPhonemes = hciUtilEditDistancePath(editPath,phonemeList)

done = false;
p = 1;
pathLoc(p,:) = size(editPath);
matchedPhonemes = {};
phonemeI = length(phonemeList);
while ~done    
    % Find next step
    if pathLoc(p,2) == 1
        left = NaN;
    else
        left = editPath(pathLoc(p,1), pathLoc(p,2)-1);
    end
    if (pathLoc(p,2) == 1) || (pathLoc(p,1) == 1)
        diag = NaN;
    else
        diag = editPath(pathLoc(p,1)-1, pathLoc(p,2)-1);
    end
    if pathLoc(p,1) == 1
        up = NaN;
    else
        up = editPath(pathLoc(p,1)-1, pathLoc(p,2));
    end
    
    [pathVal, minValI] = min([left,diag,up]);

    switch minValI
        case 1
            pathLoc(p+1,:) = [pathLoc(p,1), pathLoc(p,2)-1];
            phonemeI = phonemeI - 1;
        case 2
            pathLoc(p+1,:) = [pathLoc(p,1)-1, pathLoc(p,2)-1];
            matchedPhonemes(end+1) = phonemeList(phonemeI);
            phonemeI = phonemeI - 1;
        case 3
            pathLoc(p+1,:) = [pathLoc(p,1)-1, pathLoc(p,2)];
            matchedPhonemes(end+1) = {' '};
    end
    
    if (sum(pathLoc(p+1,:)) == 2)
        done = true;
    end
    p = p+1;
end

matchedPhonemes = fliplr(matchedPhonemes);
            
    