classdef hciSubTaskSelectTwoMaps < prtUiManagerPanel
    properties
        currentMap
        mapDir
        map1
        map2
        
        assignMapsCallbackFcn
        endTaskCallbackFcn

        handleStruct
    end
    
    methods
        function self = hciSubTaskSelectTwoMaps(varargin)
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
                'Name','Choose Maps',...
                'NumberTitle','off');
            
            % Set up instructions
            self.handleStruct.instructions = uicontrol('Style','text',...
                'Units','normalized','Position',[0.1 0.8 0.8 0.15],...
                'FontUnits','normalized','FontSize',0.3,...
                'String','Select two maps for comparison.');
            
            % Set up map selection
            self.handleStruct.mapPanel = [];
            setupMapSelectionPanel(self,[0 0.4 1 0.4]);
            setupMapSelectionPanel(self,[0 0 1 0.4]);
            
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
        
        % Set up multiple map selection button groups
        function setupMapSelectionPanel(self, positionVec)
            mapNum = length(self.handleStruct.mapPanel)+1;
            self.handleStruct.mapPanel(mapNum) = uipanel(...
                'Position',positionVec,...
                'BorderType','none');
            self.handleStruct.mapID(mapNum) = uicontrol(...
                'Style','text',...
                'Parent',self.handleStruct.mapPanel(end),...
                'Units','normalized','Position',[0 0.8 0.25 0.2],...
                'FontUnits','normalized','FontSize',0.5,...
                'String',['Select map ' num2str(mapNum)]);
            self.handleStruct.mapSelectionOptions(mapNum) = uibuttongroup(...
                'Visible','off',...
                'BorderType','none',...
                'Units','normalized','Position',[0 0 1 0.8],...
                'Parent',self.handleStruct.mapPanel(mapNum),...
                'SelectionChangeFcn',{@selectMap, self});
            uicontrol('Style','radiobutton',...
                'String','Current Map',...
                'Units','normalized','Position',[0.05 0.65 0.95 0.3],...
                'FontUnits','normalized','FontSize',0.4,...
                'Parent',self.handleStruct.mapSelectionOptions(mapNum),...
                'HandleVisibility','off');
            uicontrol('Style','radiobutton',...
                'String','Select From File',...
                'Units','normalized','Position',[0.05 0.3 0.95 0.3],...
                'FontUnits','normalized','FontSize',0.4,...
                'Parent',self.handleStruct.mapSelectionOptions(mapNum),...
                'HandleVisibility','off');       
            set(self.handleStruct.mapSelectionOptions(mapNum),'SelectedObject',[]);  % No selection
            set(self.handleStruct.mapSelectionOptions(mapNum),'Visible','on');
        end
        
        % Select a map
        function selectMap(source,event,self)
            getMapStr = get(event.NewValue,'String');
            whichMap = find(source == self.handleStruct.mapSelectionOptions);
            switch getMapStr
                case 'Current Map'
                    self.(['map' num2str(whichMap)]) = self.currentMap;
                case 'Select From File'
                    [mapName, selMapDir] = uigetfile(...
                        'C:\Users\cst\Documents\NFWork\NIH STTR\hciSoftware\maps\*.mat','Select a Map');
                    if (mapName ~= 0)
                        load([selMapDir mapName])
                        self.(['map' num2str(whichMap)]) = hciMap;
                        self.(['map' num2str(whichMap)]).importMap(map);
                    end
            end
        end
        
        % Finish
        function doneButton(source,event,self)
            % Make sure two maps have been selected
            if (~isempty(self.map1) && ~isempty(self.map2))
                % Make sure the maps are two different maps
                if ~isequal(self.map1.NMTmap,self.map2.NMTmap)
                    delete(self.handleStruct.figure)
                    self.assignMapsCallbackFcn(self.map1,self.map2)
                else
                    msgbox('Please select two different maps.','Identical Maps','error');
                    for i = 1:length(self.handleStruct.mapSelectionOptions)
                        set(self.handleStruct.mapSelectionOptions(i),'SelectedObject',[]);
                    end
                    self.map1 = [];
                    self.map2 = [];
                end
            else
                msgbox('Please select two maps.','Less Than Two Maps','error');
            end
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


