classdef hciTaskStart < hciTask
    properties
        id = 'start';
        
        topString
        buttonSetup
        
        textFontSize = 20;
        
        handleStruct
    end
    methods
        function self = hciTaskStart(varargin)
            self = prtUtilAssignStringValuePairs(self, varargin{:});
            
            if nargin~=0 && ~self.hgIsValid
                self.create();
            end
            if isempty(self.topString)
                getTopStr(self);
            end
            if isempty(self.buttonSetup)
                getButtonSetup(self);
            end
            
            init(self);
        end
        function init(self)

            self.handleStruct.topPanel = uipanel('parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0 0.5 1 0.5],...
                'visible','on',...
                'BorderType','none');
            
            [self.handleStruct.textHandle, self.handleStruct.textHandleContainer]  = javacomponent('javax.swing.JLabel',[1 1 1 1], self.handleStruct.topPanel);
            backgroundColor = get(self.managedHandle,'BackgroundColor');
            set(self.handleStruct.textHandle,'Text',self.topString,'Background',java.awt.Color(backgroundColor(1),backgroundColor(2),backgroundColor(3)),...
                'Font',java.awt.Font('sansserif',java.awt.Font.PLAIN,self.textFontSize));
            h = self.handleStruct.textHandle;
            h.setVerticalAlignment(javax.swing.JLabel.TOP);
                        
            self.handleStruct.bottomPanel = uipanel('parent',self.managedHandle,...
                'Units','normalized',...
                'Position',[0 0 1 0.5],...
                'visible','on',...
                'BorderType','none');
            
            for iButton = 1:size(self.buttonSetup,1)
                cPos = [1 1 75 75];
                
                self.handleStruct.(self.buttonSetup{iButton,3}) = uicontrol(...
                    self.handleStruct.bottomPanel,...
                    'style','pushbutton',...
                    'units','pixels',...
                    'position',cPos,...
                    'CData',self.resources.icons.size64.(self.buttonSetup{iButton,6}),...
                    'TooltipString',self.buttonSetup{iButton,4},...
                    'HandleVisibility','off',...
                    'Callback',self.buttonSetup{iButton,5});
            end
            set(self.handleStruct.textHandleContainer, 'units','normalized','position',[0 0 1 1]);
            
            self.handleStruct.bugTracker = uicontrol(...
                    self.handleStruct.bottomPanel,...
                    'style','pushbutton',...
                    'units','pixels',...
                    'position',[1 1 1 1],...
                    'HandleVisibility','off',...
                    'Callback',@self.bugTracker,...
                    'String','Report a Bug');
            
            
            set(self.managedHandle,'ResizeFcn',@self.resizeFunction)
            self.resizeFunction();
        end
        
        function getButtonSetup(self)
            self.buttonSetup = {1,1,'changeUser','Change User',@(h,e)self.motherApp.startTask(@hciTaskChangeUser), 'user_properties';
                           1,2,'newUser','New User',@(h,e)self.motherApp.startTask(@hciTaskNewUser), 'user_new_3';
                           1,3,'deleteUser','Delete User',@(h,e)self.motherApp.startTask(@hciTaskDeleteUser), 'user_delete_2';
                           2,1,'selectMap','Select Map',@(h,e)self.motherApp.startTask(@hciTaskSelectMap), 'mail_mark_task';
                           2,2,'importMap','Import Map',@(h,e)self.motherApp.startTask(@hciTaskImportMap), 'archive_insert_2';
                           2,3,'deleteMap','Delete Map',@(h,e)self.motherApp.startTask(@hciTaskDeleteMap), 'edit_delete_3';
                           3,1,'dynamicRange4','Set Dynamic Range (Ts: pulses, Cs: pulses)',@(h,e)self.motherApp.startTask(@hciTaskSetTsAndCs,{'stimulateTsType','pulses','stimulateCsType','pulses'}), 'office_chart_area_stacked';
                           3,2,'pulseRate','Set Pulse Rate',@(h,e)self.motherApp.startTask(@hciTaskSetPulseRate), 'office_chart_bar';
                           3,3,'loudnessGrowth','Set Loudness Growth Function',@(h,e)self.motherApp.startTask(@hciTaskSetQ), 'office_chart_line_stacked';
                           3,4,'personalGuide','Guide to Customizing Your Device',@(h,e)self.motherApp.startTask(@hciTaskPersonalGuide), 'people_xbill';
                           4,1,'openSetSpeechRecognition','Open Set Speech Recognition',@(h,e)self.motherApp.startTask(@hciTaskOpenSetSpeechTest), 'tools_check_spelling_5';
                           4,2,'closedSetSpeechRecognition','Closed Set Speech Recognition',@(h,e)self.motherApp.startTask(@hciTaskClosedSetSpeechTest), 'tools_check_spelling';...
                           4,3,'qualitativeSpeechRecognition','Compare Speech Quality',@(h,e)self.motherApp.startTask(@hciTaskQualitativeSpeechTest), 'preferences_desktop_font_6'};
        end
        function resizeFunction(self, varargin)
            border = 10;
            buttonSize = 100;
            nButtonsRows = max(cat(1,self.buttonSetup{:,1}));
            nButtonsCols = max(cat(1,self.buttonSetup{:,2}));
            
            leftSides = (border):(border+buttonSize):((border+buttonSize)*nButtonsCols+border);
            %rightSides = leftSides + buttonSize;
            
            bottomSides = (border):(border+buttonSize):((border+buttonSize)*nButtonsRows+border);
            topSides = bottomSides+buttonSize;
            % Shift it to ij vs xy coordinates
            parentPos = getpixelposition(self.handleStruct.bottomPanel);
            
            bottomSides = (parentPos(1)+parentPos(4)-1)-topSides;
            
            % Shift it down to the bottom
            bottomSides = bottomSides-(bottomSides(nButtonsRows)-border);
            
            for iButton = 1:size(self.buttonSetup,1)
                cPos = [leftSides(self.buttonSetup{iButton,2}) bottomSides(self.buttonSetup{iButton,1}), buttonSize, buttonSize];
                
                set(self.handleStruct.(self.buttonSetup{iButton,3}),'position',cPos);
            end
            
            % textPos = getpixelposition(self.handleStruct.topPanel);
            % textBorder = [25 25];
            % textPos(1) = textBorder(1);
            % textPos(3) = textPos(3)-textBorder(1);
            % textPos(4) = textPos(4)-textBorder(2);
            % set(self.handleStruct.textHandleContainer, 'units','pixels','position',textPos);
            
            panelPos = getpixelposition(self.handleStruct.bottomPanel);
            
            bugTrackerBorder = border;
            bugTrackerButtonWidth = 150;
            bugTrackerButtonHeight = 20;
            
            set(self.handleStruct.bugTracker,'position', [panelPos(3)-bugTrackerButtonWidth-bugTrackerBorder+1 bugTrackerBorder bugTrackerButtonWidth bugTrackerButtonHeight])
            
        end
        
        function getTopStr(self)
            [~, mapFileName] = fileparts(self.subject.mapFileNameCurrent);
            
             self.topString = cat(2,'<HTML><H1 style="padding-left: 10px; padding-top: 10px;">', self.subject.displayName,'</H1>',...
                                    '<table style="padding-left: 10px;">',...
                                    '<tr><td>Current Map:</td><td>',mapFileName,'</td></tr>',...
                                    '</table>',...
                                    '</HTML>');
        end
        function bugTracker(self, h, e)
            bugFormUrl = 'https://docs.google.com/spreadsheet/viewform?fromEmail=true&formkey=dEFuMFBvc19yeWpYRUtYLU1BME90M2c6MQ';
            
            try
                d = java.awt.Desktop.getDesktop;
                d.browse(java.net.URI(bugFormUrl))
            catch
                if ispc
                    system(cat(2,'start ', bugFormUrl));
                else
                    msgbox('An issue was encountered with the bug tracker. How meta.','Bug within the Bug Tracker');
                end
            end
            
        end
    end
end