classdef hciSubTaskSelectSpeechMaterial < prtUiManagerPanel
    properties
        speechMaterialLabels
        speechMaterialDirs
        
        materialIndex
        numTokensToPresent
        tokenList
        tokenWavFiles
        presentationList
        
        assignTokensCallbackFcn
        endTaskCallbackFcn

        handleStruct
    end
    
    methods
        function self = hciSubTaskSelectSpeechMaterial(varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
            
            init(self);
        end
        
        function init(self)
            bckgrndColor = [0.9 0.9 0.9];
            
            % Set up figure
            self.handleStruct.figure = figure;
            set(self.handleStruct.figure, ...
                'Toolbar','none',...
                'MenuBar','none',...
                'Color',[0.941176 0.941176 0.941176],...
                'Position',[700 300 500 450],...
                'Name','Select Speech Material',...
                'NumberTitle','off');
            
            % Set up instructions
            self.handleStruct.instructions = uicontrol('Style','text',...
                'Units','normalized','Position',[0.1 0.8 0.8 0.15],...
                'FontUnits','normalized','FontSize',0.3,...
                'String','Select speech material for map comparison.');
            
            % Set up choices
            self.handleStruct.choices = uibuttongroup('Visible','off',...
                'Units','normalized','Position',[0 0.125 1 0.8],...
                'BorderType','none',...
                'SelectionChangeFcn',{@selectSpeechMaterial,self},...
                'Parent',self.handleStruct.figure);
            rowMargin = 0.1;
            numChoices = length(self.speechMaterialLabels);
            vertSpacing = (1-(2*rowMargin))/numChoices;
            for c = 1:numChoices
                uicontrol('Style','radiobutton',...
                    'String',self.speechMaterialLabels{c},...
                    'Units','normalized',...
                    'Position',[0.1 ((c-1)*vertSpacing) 0.8 vertSpacing],...
                    'FontSize',12,...
                    'Parent',self.handleStruct.choices,...
                    'HandleVisibility','off');
            end
            set(self.handleStruct.choices,'SelectedObject',[]);  % No selection
            set(self.handleStruct.choices,'Visible','on');
            
            % Set up Done button
            self.handleStruct.done = uicontrol('Style','pushbutton',...
                'Units','normalized','Position',[0.65 0.05 0.15 0.075],...
                'FontUnits','normalized','FontSize',0.5,...
                'String','Done',...
                'Callback',{@doneButton,self});

            % Set up Cancel button
            self.handleStruct.done = uicontrol('Style','pushbutton',...
                'Units','normalized','Position',[0.83 0.05 0.15 0.075],...
                'FontUnits','normalized','FontSize',0.5,...
                'String','Cancel',...
                'Callback',{@cancelButton,self});
        end
        
        % Select speech material
        function selectSpeechMaterial(source,event,self)
            materialStr = get(event.NewValue,'String');
            self.materialIndex = find(strcmp(materialStr,self.speechMaterialLabels));
        end
        
        % Finalize selection
        function doneButton(source,event,self)
            % Make sure something has been selected
            if ~isempty(self.materialIndex)
                delete(self.handleStruct.figure)
                getTokens(self)
            else
                msgbox('Please select speech material for map comparison.','No Selection','error');
            end
        end
        
        % Get tokens for selected material
        function getTokens(self)
            [tList, wList] = hciUtilExtractTokenAndWavFileList(...
                self.speechMaterialDirs{self.materialIndex});
            randOrder = randperm(length(tList));
            if isempty(self.numTokensToPresent)
                self.numTokensToPresent = length(tList);
            elseif (self.numTokensToPresent > length(tList))
                self.numTokensToPresent = length(tList);
            end
            self.presentationList = tList(randOrder(1:self.numTokensToPresent));
            [self.tokenList, tListI] = sort(self.presentationList);
            subWList = wList(randOrder(1:self.numTokensToPresent));
            self.tokenWavFiles = subWList(tListI);
            self.assignTokensCallbackFcn(self.tokenList, self.tokenWavFiles,...
                self.presentationList)
        end
        
        % Quit task
        function cancelButton(source,event,self)
            delete(self.handleStruct.figure)
            if ~isempty(self.endTaskCallbackFcn)
                self.endTaskCallbackFcn()
            end
        end        
    end
end


