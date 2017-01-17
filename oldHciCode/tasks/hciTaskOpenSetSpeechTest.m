classdef hciTaskOpenSetSpeechTest < hciTask
    properties
        id = 'openSetSpeech';
        
        tokenList
        tokenType
        presentationList
        responseList
        presentationCount
        saveLoc
        
        dictionary
        
        numSentenceTokensPerTest = 10;
        numWordTokensPerTest = 50;
       
        stimulusPauseTimePre = 0.1; % in seconds
        stimulusPauseTimePost = 0; % in seconds
        
        noiseLevel;
        addReverb = false;
        
        heldTyping = [];
%         finishedTyping = false; % Decided against letting people hit
%                                   return early
        
        phonemeResults
        phonemeList
        taskScore
        taskLabel
        
        saveResultsOnQualityExit = true;
        allowNonSettingExit = true;
        
        startTime
        endTime

        isLocked = false;
        handleStruct
    end
    
    methods
        function self = hciTaskOpenSetSpeechTest(varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
                
            if nargin~=0 && ~self.hgIsValid
                self.create();
            end
            
            setup(self);
        end
        
        function setup(self)
            setupUi(self);
            
            self.responseList = {};
            self.presentationCount = 0;
        end
        
        function setupUi(self)
            self.handleStruct.axes = axes('parent',self.managedHandle,...
                'units','normalized',...
                'position',[0.1 0.1 0.8 0.8],...
                'Visible','off');
            
            % Set up task selection
            self.handleStruct.taskListInstructions = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.2 0.55 0.6 0.2],...
                'String','Select Type of Speech',...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'HorizontalAlignment','left',...
                'Visible','off');
            self.handleStruct.taskList = uicontrol('Style','popupmenu',...
                'Parent',self.managedHandle,...
                'String',{' ','Sentences','Words'},...
                'Units','normalized','Position',[0.2 0.5 0.6 0.2],...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'Callback',@self.getTokenList,...
                'Visible','off');
            self.handleStruct.noiseListInstructions = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.2 0.35 0.6 0.2],...
                'String','Select Amount of Noise',...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'HorizontalAlignment','left',...
                'Visible','off');
            self.handleStruct.noiseList = uicontrol('Style','popupmenu',...
                'Parent',self.managedHandle,...
                'String',{  'None',...
                            'A Little Noise',...
                            'Lots of Noise'},...
                'Units','normalized','Position',[0.2 0.3 0.6 0.2],...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'Callback',@self.getNoiseLevel,...
                'Visible','off');
            self.handleStruct.reverbStatus = uicontrol('Style','checkbox',...
                'Parent',self.managedHandle,...
                'String','Add Reverberation?',...
                'Units','normalized','Position',[0.2 0.25 0.6 0.2],...
                'FontUnits','normalized',...
                'FontSize',0.15,...
                'Callback',@self.getReverbStatus,...
                'Visible','off');
            self.handleStruct.continueButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.1 0.01 0.15 0.08],...
                'String','Continue',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.goToTask,...
                'Enable','off',...
                'Visible','off');
            
            % Set up status indicator
            self.handleStruct.startButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.3 0.85 0.4 0.1],...
                'String','Ready',...
                'FontUnits','normalized',...
                'FontSize',0.5,...
                'Callback',@self.startTask,...
                'Visible','off',...
                'Enable','off');
            
            self.handleStruct.status = uicontrol('Style','text',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.3 0.85 0.4 0.1],...
                'String','Select Speech Test',...
                'FontUnits','normalized',...
                'FontSize',0.5);
            
            % Set up response box
            self.handleStruct.responseBox = uicontrol('Style','edit',...
                'Parent',self.managedHandle,...
                'Units','normalized','Position',[0.2 0.4 0.6 0.2],...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'TooltipString','Enter your response here.',...
                'Callback',@self.recordSelection,...
                'ButtonDownFcn',@(obj,event)self.noMouse(event),...
                'KeyPressFcn',@(obj,event)self.holdTyping(event),...
                'Enable','off',...
                'Visible','off');
            
            % Allow quitting and finishing
            self.handleStruct.quitButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.8 0.01 0.15 0.08],...
                'String','Quit',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.saveAndQuit,...
                'Enable','off');
            self.handleStruct.doneButton = uicontrol('Style','pushbutton',...
                'Parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0.8 0.01 0.15 0.08],...
                'String','Done',...
                'FontUnits','normalized',...
                'FontSize',0.25,...
                'Callback',@self.finishTask,...
                'Visible','off',...
                'Enable','off');
            
            resizeFunction(self)

            if ~isempty(self.presentationList)
                if isempty(self.dictionary)
                    load(fullfile(hciDirsDataDictionary, 'commonWordDictWithWordLengthFreq'));
                    self.dictionary = dict;
                end
                goToTask(self);
            else
                set(self.handleStruct.taskListInstructions,'Visible','on');
                set(self.handleStruct.taskList,'Visible','on','Enable','on');
                set(self.handleStruct.noiseListInstructions,'Visible','on');
                set(self.handleStruct.noiseList,'Visible','on','Enable','on');
                set(self.handleStruct.continueButton,'Visible','on');
                set(self.handleStruct.reverbStatus,'Visible','on','Enable','on');
                drawnow;
                if isempty(self.dictionary)
                    load(fullfile(hciDirsDataDictionary, 'commonWordDictWithWordLengthFreq'));
                    self.dictionary = dict;
                end
            end
            set(self.handleStruct.continueButton,'Enable','on');
            set(self.handleStruct.quitButton,'Enable','on');
        end
        
        function resizeFunction(self, varargin)
            pos = getpixelposition(self.managedHandle); pos = pos(3:4);
            border = 10;
            buttonSize = [200 50];
            buttonBottom = border;
            set(self.handleStruct.quitButton,'units','pixels');
            set(self.handleStruct.quitButton,'position',[border buttonBottom buttonSize])
            set(self.handleStruct.quitButton,'units','normalized');
            set(self.handleStruct.doneButton,'units','pixels');
            set(self.handleStruct.doneButton,'position',[border buttonBottom buttonSize])
            set(self.handleStruct.doneButton,'units','normalized');
            
            figSize = get(gcf,'Position');
            numPixels = figSize(3);
            buttonLeft = numPixels - buttonSize(1) - border;
            set(self.handleStruct.continueButton,'units','pixels');
            set(self.handleStruct.continueButton,'position',[buttonLeft buttonBottom buttonSize])
            set(self.handleStruct.continueButton,'units','normalized');
            
            textHeight = pos(2)*0.15;
            axesLeft = border;
            axesWidth = pos(1)-axesLeft;
            axesHeight = pos(2)-textHeight-border;
            
            set(self.handleStruct.axes,'units','pixels');
            set(self.handleStruct.axes,'outerposition',[axesLeft 5*border axesWidth, axesHeight])
            set(self.handleStruct.axes,'units','normalized');
        end
        
        function goToTask(self,varargin)
            if isempty(self.presentationList)
                warningStr = 'Please select a speech type before continuing.';
                self.handleStruct.warndlg = warndlg(warningStr,'Select Speech Type');
            else
                self.startTime = now;
                
                % Disable task selection
                set(self.handleStruct.taskListInstructions,'Visible','off');
                set(self.handleStruct.taskList,'Visible','off','Enable','off');
                set(self.handleStruct.noiseListInstructions,'Visible','off');
                set(self.handleStruct.noiseList,'Visible','off','Enable','off');
                set(self.handleStruct.continueButton,'Visible','off','Enable','off');
                set(self.handleStruct.reverbStatus,'Visible','off','Enable','off');
                
                % Enable task controls
                set(self.handleStruct.status,'Visible','off');
                set(self.handleStruct.startButton,...
                    'Visible','on',...
                    'Enable','on');
                set(self.handleStruct.responseBox,'Visible','on','Enable','on');
            end
            drawnow;
        end
        
        function startTask(self,varargin)
            self.presentationCount = 1;
            set(self.handleStruct.startButton,'Enable','off','Visible','off')
            set(self.handleStruct.status,'Visible','on')
            presentToken(self)
        end
        
        function presentToken(self)
            cameInLocked = self.isLocked;
            if ~cameInLocked
                lockUi(self);
            end
            
            % Present stimulus
            set(self.handleStruct.status,'String','Presenting...')
            p = self.presentationCount;
            presentationToken = self.presentationList{p};
            
            pause(self.stimulusPauseTimePre)
            
            self.map.stimulateSpeechToken(...
                presentationToken,...
                self.noiseLevel,...
                self.addReverb);
            
            pause(self.stimulusPauseTimePost)

            if self.map.catestrophicFailure
                return
            end
            
            if ~cameInLocked
                unlockUi(self);   
            end
            
            % Decided this was a bad idea - what if someone accidentally
            %   hits return before they've heard the whole thing?
%             if self.finishedTyping
%                 self.recordSelection();
%             end
        end
        
        % Record selection
        function recordSelection(self, varargin)
            self.responseList{end+1} = strtrim(get(self.handleStruct.responseBox,'String'));
%             self.finishedTyping = false;
%             set(self.handleStruct.responseBox,'String','');
            self.presentationCount = self.presentationCount + 1;
            if (self.presentationCount <= length(self.presentationList))
                presentToken(self)
            else
                scoreResults(self)
            end
        end
        
        function scoreResults(self)
            turnOffTask(self);
            drawnow;
            switch self.tokenType
                case 'word'
                    [labels, occurrence, scores, taskScore] = scoreWordResponses(self);
                    taskLabel = {['Word' char(10) 'Score']};
                case 'sentence'
                    [labels, occurrence, scores, taskScore] = scoreSentenceResponses(self);
                    if taskScore(1) == taskScore(2)
                        taskScore(1:end-1) = [];
                        taskLabel = {['Sentence' char(10) 'Score']};
                    else
                        taskLabel{1} = ['Word' char(10) 'Score'];
                        taskLabel{2} = ['Sentence' char(10) 'Score'];
                    end
            end
            presentResults(self,labels,occurrence,scores, taskScore, taskLabel);
        end
        function turnOffTask(self)
            % Disable task controls
            set(self.handleStruct.status,...
                'String','Calculating Score...',...
                'Visible','on');
            set(self.handleStruct.responseBox,'Visible','off','Enable','off');
        end            
        function [labels, occurrence, scores, taskScore] = scoreWordResponses(self)
            phonemeList = [];
            phonemeScoreList = [];
            wordList = [];
            taskScore = 0;
            for r = 1:length(self.responseList)
                % Convert words to phonemes
                [filepath,presentationWord] = fileparts(self.presentationList{r});
                presentationPhonemes = convertWordToPhonemes(self,presentationWord);
                responsePhonemes = convertWordToPhonemes(self,self.responseList{r});
                
                % Score response
                [phonemesPerWord, scorePerWord, wordScore] = scorePhonemes(self,...
                    presentationPhonemes,responsePhonemes);
                phonemeList = cat(1,phonemeList, phonemesPerWord);
                phonemeScoreList = cat(1,phonemeScoreList,scorePerWord);
                wordList = cat(1,wordList,wordScore);
                if wordScore
                    taskScore = taskScore + 1;
                end
                clear filepath presentationWord presentaitonPhonemes
                clear responsePhonemes phonemesPerWord scorePerWord
            end
            
            % Return tested phonemes, their occurrence, and their scores
            labels = unique(phonemeList);
            occurrence = zeros(size(labels));
            scores = zeros(size(labels));
            for L = 1:length(labels)
                labelMatch = strcmp(labels{L},phonemeList);
                occurrence(L) = sum(labelMatch);
                scores(L) = sum(phonemeScoreList(labelMatch));
            end
            taskScore = 100*taskScore/self.numWordTokensPerTest;
        end
        function [phonemeList, scoreList, wordMatch] = scorePhonemes(self,...
                presentationPhonemes,responsePhonemes)
            [numMatches,matchPresentationPhonemes,wordMatch] = hciUtilMatchPhonemes(...
                presentationPhonemes,responsePhonemes);

            phonemeList = presentationPhonemes(:);
            scoreList = matchPresentationPhonemes(:);
        end
        function [labels, occurrence, scores, taskScore] = scoreSentenceResponses(self)
            phonemeList = [];
            scoredPhonemeList = [];
            scoreList = [];
            taskScore = [0 0];
            wordCount = 0;
            for r = 1:length(self.responseList)
                % Convert sentences into words
                [filepath,presentationSentence] = fileparts(self.presentationList{r});
                presentationWords = extractWords(self,presentationSentence);
                responseWords = extractWords(self,self.responseList{r});
                
                % Convert words to phonemes
                for pw = 1:length(presentationWords)
                    presentationPhonemes{pw} = convertWordToPhonemes(self,...
                        presentationWords{pw});
                    phonemeList = cat(1,phonemeList,presentationPhonemes{pw}(:));
                end
                for rw = 1:length(responseWords)
                    responsePhonemes{rw} = convertWordToPhonemes(self,...
                        responseWords{rw});
                end
                
                % Match response words to presentation words
                [selectedResponseWordsI, matchToPresentationI] = ...
                    hciUtilMatchWords(presentationPhonemes,responsePhonemes);
                
                % Score matched words
                wordCorrect = zeros(length(selectedResponseWordsI),1);
                for s = 1:length(selectedResponseWordsI)
                    pPhonemes = presentationPhonemes{matchToPresentationI(s)};
                    rPhonemes = responsePhonemes{selectedResponseWordsI(s)};
                    [numMatches,matchPresentationPhonemes,wordMatch] = ...
                        hciUtilMatchPhonemes(pPhonemes,rPhonemes);
                    scoredPhonemeList = cat(1,scoredPhonemeList, pPhonemes(:));
                    scoreList = cat(1,scoreList,matchPresentationPhonemes(:));
                    if wordMatch
                        wordCorrect(s) = 1;
                    end
                    clear pPhonemes rPhonemes numMatches matchPresentationPhonemes
                    clear wordMatch
                end
                taskScore(1) = taskScore(1) + sum(wordCorrect);
                wordCount = wordCount + length(presentationWords);
                if sum(wordCorrect) == length(presentationWords)
                    taskScore(2) = taskScore(2) + 1;
                end
                clear filepath presentationSentence presentationWords responseWords
                clear presentationPhonemes responsePhonemes 
                clear selectedResponseWordsI matchToPresentationI wordCorrect
            end

            % Return tested phonemes, their occurrence, and their scores
            labels = unique(phonemeList);
            occurrence = zeros(size(labels));
            scores = zeros(size(labels));
            for L = 1:length(labels)
                labelMatchAll = strcmp(labels{L},phonemeList);
                labelMatchScored = strcmp(labels{L},scoredPhonemeList);
                occurrence(L) = sum(labelMatchAll);
                scores(L) = sum(scoreList(labelMatchScored));
            end
            taskScore = 100*taskScore./[wordCount self.numSentenceTokensPerTest];
        end
        function wordList = extractWords(self,sentence)
            locateSp = find(diff(isstrprop(strtrim(sentence),'wspace'))==1)+1;
            if isempty(locateSp)
                % Assume it is file name
                locateCap = find(isstrprop(sentence,'upper'));
                
                if isempty(locateCap)
                    wordList = {sentence};  % Must be a single word
                else
                    for L = 1:length(locateCap)
                        if L == length(locateCap)
                            wordList{L} = lower(sentence(locateCap(L):end));
                        else
                            wordList{L} = lower(sentence(locateCap(L):(locateCap(L+1)-1)));
                        end
                    end
                end
            else
                startI = 1;
                for L = 1:length(locateSp)+1
                    if L == length(locateSp)+1
                        endI = length(sentence);
                    else
                        endI = locateSp(L);
                    end
                    wordList{L} = lower(strtrim(sentence(startI:endI)));
                    
                    startI = endI + 1;
                end
            end
        end
        function phonemes = convertWordToPhonemes(self,word)
            if isempty(word)
                phonemes = {' '};
            else
                % Look for dictionary match
                word(isstrprop(word,'punct')) = [];
                if isempty(word)
                    phonemes = {' '};
                else
                    wordMatch = strcmpi(word,[self.dictionary.word]);
                    if isempty(find(wordMatch))
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
                    else
                        phonemes = self.dictionary(wordMatch).phonemeList;
                    end
                end
            end
        end
        
        function presentResults(self,labels,occurrence,scores,taskScore,taskLabel)
            % Convert labels to things that people can understand
            newLabels = labels;
            phonemeList = unique(labels);
            isvowel = zeros(size(phonemeList));
            for p = 1:length(phonemeList)
                switch phonemeList{p}
                    case {'AA','AO'}
                        newLabels(strcmpi(phonemeList{p},newLabels)) = ...
                            {'short O'};
                        isvowel(p) = 1;
                    case {'AE'}
                        newLabels(strcmpi(phonemeList{p},newLabels)) = ...
                            {'short A'};
                        isvowel(p) = 1;
                    case {'AH'}
                        newLabels(strcmpi(phonemeList{p},newLabels)) = ...
                            {'short U'};
                        isvowel(p) = 1;
                    case {'AW'}
                        newLabels(strcmpi(phonemeList{p},newLabels)) = ...
                            {'OW'};
                        isvowel(p) = 1;
                    case {'AY'}
                        newLabels(strcmpi(phonemeList{p},newLabels)) = ...
                            {'long I'};
                        isvowel(p) = 1;
                    case {'DH'}
                        newLabels(strcmpi(phonemeList{p},newLabels)) = ...
                            {'TH'};
                    case {'EH'}
                        newLabels(strcmpi(phonemeList{p},newLabels)) = ...
                            {'short E'};
                        isvowel(p) = 1;
                    case {'EY'}
                        newLabels(strcmpi(phonemeList{p},newLabels)) = ...
                            {'long A'};
                        isvowel(p) = 1;
                    case {'HH','JH','ZH'}
                        newLabels(strcmpi(phonemeList{p},newLabels)) = ...
                            {phonemeList{p}(1)};
                    case {'IH'}
                        newLabels(strcmpi(phonemeList{p},newLabels)) = ...
                            {'short I'};
                        isvowel(p) = 1;
                    case {'IY'}
                        newLabels(strcmpi(phonemeList{p},newLabels)) = ...
                            {'long E'};
                        isvowel(p) = 1;
                    case {'OW'}
                        newLabels(strcmpi(phonemeList{p},newLabels)) = ...
                            {'long O'};
                        isvowel(p) = 1;
                    case {'UH','UW'}
                        newLabels(strcmpi(phonemeList{p},newLabels)) = ...
                            {'long U'};
                        isvowel(p) = 1;
                    case {'OY','ER'}
                        isvowel(p) = 1;
                end
            end
            
            % Adjust scores/occurrences
            phonemeList = unique(newLabels);
            newOccurrences = zeros(length(phonemeList),1);
            newScores = zeros(length(phonemeList),1);
            vowelFlag = false(length(phonemeList),1);
            for p = 1:length(phonemeList)
                pMatch = strcmpi(phonemeList{p},newLabels);
                newOccurrences(p) = sum(occurrence(pMatch));
                newScores(p) = sum(scores(pMatch));
                vowelFlag(p) = max(isvowel(pMatch));
            end
            
            % Arrange by consonants and vowels:
            phonemeList = cat(1,phonemeList(~vowelFlag),phonemeList(vowelFlag));
            newOccurrences = cat(1,newOccurrences(~vowelFlag),newOccurrences(vowelFlag));
            newScores = cat(1,newScores(~vowelFlag),newScores(vowelFlag));
            
            % Update UI
            set(self.handleStruct.status,...
                'String','Your Scores',...
                'Visible','on');
            set(self.handleStruct.quitButton,...
                'Visible','off',...
                'Enable','off');
            set(self.handleStruct.doneButton,...
                'Visible','on',...
                'Enable','on');
            set(self.handleStruct.axes,'Visible','on')
            
            % Plot results
            self.handleStruct.results = bar(100*newScores(:)./newOccurrences(:));
            set(self.handleStruct.results,'FaceColor',[0.7020 0.7804 1])
            hold all
            for t = 1:length(taskScore)
                plot([0 (length(phonemeList)+0.8)],taskScore(t)*ones(1,2),...
                    'm--','LineWidth',5)
                text((length(phonemeList)+1),taskScore(t),taskLabel{t},...
                    'FontSize',20,...
                    'Color','m',...
                    'FontWeight','bold')
            end
            box on
            xlim([0 (length(phonemeList)+2)])
            ylim([0 100])
            set(self.handleStruct.axes,'XTick',1:length(phonemeList),'XTickLabel',phonemeList)
            self.handleStruct.tickLabels = rotateticklabel(self.handleStruct.axes,45);
            xLabelH = get(self.handleStruct.axes,'XLabel');
            xLabelPos = get(xLabelH,'Position');
            set(xLabelH,'Position',[xLabelPos(1) xLabelPos(2)-8 xLabelPos(3)])
            ylabel('Percent Correct')
            xlabel('Consonants and Vowels')
            
            % Save results in object
            self.phonemeResults = 100*newScores(:)./newOccurrences(:);
            self.phonemeList = phonemeList;
            self.taskScore = taskScore;
            self.taskLabel = taskLabel;
        end
        
        function finishTask(self,varargin)
            set(self.handleStruct.status,'Visible','off');
            set(self.handleStruct.doneButton,'Visible','off');
            set(self.handleStruct.axes,'Visible','off')

            self.endTime = now;
            if self.saveResultsOnQualityExit
                results = createResults(self);
                
                mes = self.motherApp.wait('Saving Results...');
                self.motherApp.subject.logResults(results);
                close(mes);
            end
            
            exit(self);            
        end
        function saveAndQuit(self,varargin)
            qu = 'Are you sure you want to discard all information and exit?';
            str1 = 'Yes. exit.';
            str2 = 'No, go back.';
            
            button = self.motherApp.questdlg(qu,'Really Exit?',str1,str2,str2);
            if strcmpi(button,str1)
                exit(self);
            end
        end
        function results = createResults(self)
            resultsStruct.tokenType = self.tokenType;
            resultsStruct.phonemeResults = self.phonemeResults;
            resultsStruct.phonemeList = self.phonemeList;
            resultsStruct.taskScore = self.taskScore;
            resultsStruct.taskLabel = self.taskLabel;
            resultsStruct.noiseLevel = self.noiseLevel;
            resultsStruct.addReverb = self.addReverb;
            resultsStruct.startTime = self.startTime;
            resultsStruct.endTime = self.endTime;
            
            results = hciResults('type',self.id,'results',resultsStruct);
        end
        
        function getTokenList(self,varargin)
            rng('shuffle')
            popupResponse = get(varargin{1});
            switch popupResponse.Value
                case 1
                    self.tokenList = [];
                    self.presentationList = [];
                    self.tokenType = [];
                case 2
                    % Get full token list
                    disp('Getting sentence token list...')
                    self.tokenList = hciUtilGetTokenList(hciDirsDataQuantitativeSentences);
                    self.tokenType = 'sentence';
                    
                    % Get presentation list
                    stimI = randperm(length(self.tokenList),self.numSentenceTokensPerTest);
                    self.presentationList = self.tokenList(stimI);
                case 3
                    % Get full token list
                    disp('Getting word token list...')
                    self.tokenList = hciUtilGetTokenList(hciDirsDataWords);
                    self.tokenType = 'word';
                    
                    % Get presentation list
                    stimI = randperm(length(self.tokenList),self.numWordTokensPerTest);
                    self.presentationList = self.tokenList(stimI);
            end
        end
        function getNoiseLevel(self,varargin)
            popupResponse = get(varargin{1});
            switch popupResponse.Value
                case 1
                    disp('No noise...')
                    self.noiseLevel = 0;
                case 2
                    disp('A little noise...')
                    self.noiseLevel = 0.05;     % About 20 dB SNR
                case 3
                    disp('Lots of noise...')
                    self.noiseLevel = 0.15;     % About 10 dB SNR
            end
        end
        function getReverbStatus(self,varargin)
            reverbStatus = get(varargin{1});
            switch reverbStatus.Value
                case 0
                    disp('No reverberation added...')
                    self.addReverb = false;
                case 1
                    disp('Added reverberation...')
                    self.addReverb = true;
            end
        end
            
        
        function holdTyping(self,event)
%             if ~self.finishedTyping
                switch event.Key
                    case 'backspace'
                        if length(self.heldTyping > 0)
                            self.heldTyping(end) = [];
                        end
%                     case 'return'
%                         self.finishedTyping = true;
                    otherwise
                        self.heldTyping = [self.heldTyping event.Character];
                end
%         end
            set(self.handleStruct.responseBox,'String',self.heldTyping);
        end
        function noMouse(self,event)
            % Do nothing
            disp('No response to mouse click.')
        end
            
        function lockUi(self)
            if self.isLocked
                return
            end
            self.isLocked = true;
            
            self.heldTyping = [];
            
            % Disable response box and quitting
            set(self.handleStruct.responseBox,...
                'String','',...
                'Enable','off')
            set(self.handleStruct.quitButton,'Enable','off');

            % Give window control
            if self.isSubTask
                figureH = get(get(self.managedHandle,'Parent'),'Parent');
            else
                figureH = get(self.managedHandle,'Parent');
            end
            set(figureH,...
                'WindowButtonDownFcn',@(obj,event)self.noMouse(event),...
                'WindowKeyPressFcn',@(obj,event)self.holdTyping(event));
        end
        function unlockUi(self)
            if ~self.isLocked
                return
            end
            
            % Reset window for access to uicontrols
            if self.isSubTask
                figureH = get(get(self.managedHandle,'Parent'),'Parent');
            else
                figureH = get(self.managedHandle,'Parent');
            end
            set(figureH,...
                'WindowButtonDownFcn',[],...
                'WindowKeyPressFcn',[]);
            
            % Enter any previously typed text
            if ~isempty(self.heldTyping)
                set(self.handleStruct.responseBox,'String',self.heldTyping);
            end
            
            % Enable response
            set(self.handleStruct.status,'String','Type what you heard:')
            set(self.handleStruct.responseBox,'Enable','on')
            set(self.handleStruct.quitButton,'Enable','on');
            uicontrol(self.handleStruct.responseBox)
            
            self.isLocked = false;
        end
    end
end