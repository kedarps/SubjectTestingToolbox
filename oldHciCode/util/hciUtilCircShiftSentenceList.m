
%
% Circ shift sentence list.
%

function hciUtilCircShiftSentenceList(sentenceFile, gender)

% Find matching subjects
subjectDir = fullfile(hciRoot,'recorder','db');
dirContents = dir(subjectDir);
dirContents = dirContents(~ismember({dirContents.name}',{'.','..','.svn'}) & cat(1,dirContents.isdir));
users = {dirContents.name}';

if ~isempty(users)
    switch lower(gender)
        case {'female','f'}
            genderMatch = strncmpi(users,'f',1);
        case {'male','m'}
            genderMatch = strncmpi(users,'m',1);
        case {'unknown'}
            genderMatch = true(size(users));
    end
    genderUsers = users(genderMatch);
    
    % Figure out the last sentence spelled
    latestDate = 0;
    for g = 1:length(genderUsers)
        [sentencePath,sentenceName] = fileparts(sentenceFile);
        sentenceDir = fullfile(subjectDir,genderUsers{g},sentenceName);
        if exist(sentenceDir,'dir')
            sentenceDirContents = dir(sentenceDir);
            sentenceDirContents = sentenceDirContents(~cat(1,sentenceDirContents.isdir));
            fileDates = cat(1,sentenceDirContents.datenum);
            [maxDate, maxDateI] = max(fileDates);
            if (maxDate > latestDate)
                latestDate = maxDate;
                [~,latestSentence] = fileparts(sentenceDirContents(maxDateI).name);
            end
        end
    end
    
    % If there was a sentence spelled, circularly shift file
    if latestDate > 0
        % Read in sentences
        fid = fopen(sentenceFile,'r');
        textScanOutput = textscan(fid,'%q','delimiter','\n');
        wordList = textScanOutput{1};
        fclose(fid);
        
        % Find matching sentence
        for w = 1:length(wordList)
            convertedSentences{w} = hciUtilConvertSentenceToStr(wordList{w});
        end
        sentenceMatch = find(strcmp(latestSentence,convertedSentences));
        if sentenceMatch > 1
            sentenceMatch = sentenceMatch(end);
        elseif sentenceMatch < 1
            sentenceMatch = 0;
        end
        
        % Reorder sentences
        wordList = cat(1,wordList(sentenceMatch+1:end),wordList(1:sentenceMatch));
        
        % Rewrite list
        fid = fopen(sentenceFile,'w');
        for w = 1:length(wordList)
            fprintf(fid,[wordList{w} '\r\n']);
        end
        fclose all;
    end
end