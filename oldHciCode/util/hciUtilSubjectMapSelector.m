classdef hciUtilSubjectMapSelector < prtUiManagerPanel
    properties
        inputStruct
        tableFieldNames = {};
        dataCell = {};
        
        enteredSelection = [];
        
        handleStruct
    end
    methods 
        function self = hciUtilSubjectMapSelector(varargin)
            if nargin == 1
                assert(isstruct(varargin{1}),'Single input must be a structure array');

                self.inputStruct = varargin{1};
            else
                self = prtUtilAssignStringValuePairs(self,varargin{:});
            end
            
            if nargin~=0 && ~self.hgIsValid
               self.create()
            end
            
            init(self);
        end
        function init(self)
            
            self.handleStruct.table = uitable('parent',self.managedHandle,...
                'units','pixels','position',[1 1 50 50]); % Dummy position
            self.handleStruct.figure = gcf; %Is this ok? It depens how we use this.
            drawnow;
            
            self.handleStruct.jScrollPane = findjobj(self.handleStruct.table);
            self.handleStruct.jTable = self.handleStruct.jScrollPane.getViewport.getView;
            
            % Set the actual data in the cell
            structArrayToCell(self);
            set(self.handleStruct.table,'data',self.dataCell,...
                'columnName',self.tableFieldNames,...
                'RearrangeableColumns','on',...
                'RowName',{},...
                'TooltipString','Available Map Files',...
                'ColumnEditable',false(1,length(self.tableFieldNames)),...
                'KeyPressFcn',@self.tableKeyPressFcn,...
                'CellSelectionCallback',@self.cellCelectionFcn);
           
            % Force selection of full rows only
            self.handleStruct.jTable.setNonContiguousCellSelection(false)
            
            % Force selection of a single row only
            self.handleStruct.jTable.setSelectionMode(javax.swing.ListSelectionModel.SINGLE_SELECTION);
            
            % Set the column widths to take up the whole area
            self.handleStruct.jTable.setAutoResizeMode(self.handleStruct.jTable.AUTO_RESIZE_SUBSEQUENT_COLUMNS);
            
            % Set and call the resize function to set the element positions
            set(self.managedHandle,'ResizeFcn',@self.resizeFunction);
            resizeFunction(self);
        end
        
        function structArrayToCell(self)
            self.tableFieldNames = fieldnames(self.inputStruct)';
            self.dataCell = struct2cell(self.inputStruct)';
        end

        function setPixelPositions(self)
            panelPosition = getpixelposition(self.managedHandle);
            
            border = 5;
            
            left = border+1;
            width = panelPosition(3);
            bottom = border+1;
            height= panelPosition(4);
                       
            tablePos = [left bottom width-border*2-2 height-2*border-2];
            
            set(self.handleStruct.table,'units','pixels');
            set(self.handleStruct.table,'position',tablePos);
            set(self.handleStruct.table,'units','normalized');
            
        end
        function resizeFunction(self, varargin)
            setPixelPositions(self)
            drawnow;
        end
        
        function tableKeyPressFcn(self, varargin)
            event = varargin{2};
            
            if strcmpi(event.Key,'Return')
                
                % They hit return, so select this entry and exit
                % When you hit return MATLAB (I think), moves the selection
                % to the "next" cell. If you have the last one selected it
                % goes back around to zero. 
                reportedSelection = self.handleStruct.jTable.getSelectedRow()+1;% Java is 0 referenced
                reportedSelection = reportedSelection - 1; % undo the wrap arround
                if reportedSelection==0 % We actually selected the end and they wrapped us around to 1
                    reportedSelection = length(self.inputStruct);
                end
                
                self.enteredSelection = reportedSelection; 
                
                close(self.handleStruct.figure);
                
            elseif strcmpi(event.Key,'Escape')
                % Leave with an empty selection
                close(self.handleStruct.figure);
            else
                % Nada, probably an arrow
            end
            
            %self.handleStruct.jTable.setRowSelectionInterval(self.handleStruct.jTable.getSelectedRow,self.handleStruct.jTable.getSelectedRow);
            
        end
    end
end