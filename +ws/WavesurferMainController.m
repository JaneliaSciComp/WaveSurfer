classdef WavesurferMainController < ws.Controller
    % The controller for the main wavesurfer window.
    
%     properties (Constant)
%         NormalBackgroundColor = [1 1 1] ;  % White: For edits and popups, when value is a-ok
%         WarningBackgroundColor = [1 0.8 0.8] ;  % Pink: For edits and popups, when value is problematic
%     end
    
    properties
        FileMenu
        OpenProtocolMenuItem
        SaveProtocolMenuItem
        SaveProtocolAsMenuItem
        %LoadUserSettingsMenuItem
        %SaveUserSettingsMenuItem
        %SaveUserSettingsAsMenuItem
        ExportModelAndControllerToWorkspaceMenuItem
        QuitMenuItem
        
        ProtocolMenu
        GeneralSettingsMenuItem
        ChannelsMenuItem
        TriggersMenuItem
        StimulusLibraryMenuItem
        StimulusPreviewMenuItem
        UserCodeManagerMenuItem
        ElectrodesMenuItem
        TestPulseMenuItem
        %DisplayMenuItem
        YokeToScanimageMenuItem
        
        ProfileMenu
        ProfileMenuItems
        NewProfileMenuItem
        DeleteProfileMenuItem
        RenameProfileMenuItem
        
        HelpMenu
        AboutMenuItem

        PlayButton
        RecordButton
        StopButton
        %FastProtocolText
        FastProtocolButtons
        ManageFastProtocolsButton
        
        StatusText
        ProgressBarAxes
        ProgressBarPatch
    end  % properties

    properties (Access = protected)
        ScopePlots_ = ws.ScopePlot.empty(1,0)  % an array of type ws.ScopePlot
        
        ViewMenu_
        InvertColorsMenuItem_
        ShowGridMenuItem_
        DoShowZoomButtonsMenuItem_
        DoColorTracesMenuItem_
        PlotArrangementMenuItem_

%         % The (downsampled for display) data currently being shown.
%         XData_
%         YData_
        
        % Stuff below are cached resources that we use in all the scope plots
        NormalPlayIcon_
        NormalRecordIcon_
        NormalStopIcon_        
        NormalYScrollUpIcon_ 
        NormalYScrollDownIcon_ 
        NormalYTightToDataIcon_ 
        NormalYTightToDataLockedIcon_ 
        NormalYTightToDataUnlockedIcon_ 
        NormalYCaretIcon_         
        TraceColorSequence_
    end    
    
%     properties (Access=protected, Transient=true)
%         OriginalModelState_  % used to store the previous model state when model state is being set
%     end
        
    properties (Access = public)  % these are protected by gentleman's agreement
        % Individual controller instances for various tools/windows/dialogs.
        GeneralSettingsController
        ChannelsController
        StimulusLibraryController
        StimulusPreviewController
        TriggersController
        UserCodeManagerController
        ElectrodeManagerController
        TestPulserController
        FastProtocolsController
    end    
    
    properties (Access=protected, Transient)
        % Defines relationships between controller instances/names, window instances,
        % etc.  See createControllerSpecs() method
        %ControllerSpecifications_

        % An array of all the child controllers, which is sometimes handy
        %ChildControllers_ = {}
    end
    
    properties
        MyYLimDialogController=[]
    end

    properties (Access=protected)
        PlotArrangementDialogController_ = []
        MyRenameProfileDialogController_ = [] 
    end
    
    methods
        function self = WavesurferMainController(model)
            % Call the superclass constructor
            self = self@ws.Controller(model);            
            
            % Create all the child controllers
            self.GeneralSettingsController = ws.GeneralSettingsController(model) ;
            self.ChannelsController = ws.ChannelsController(model) ;
            self.StimulusLibraryController = ws.StimulusLibraryController(model) ;
            self.StimulusPreviewController = ws.StimulusPreviewController(model) ;
            self.TriggersController = ws.TriggersController(model) ;
            self.UserCodeManagerController = ws.UserCodeManagerController(model) ;
            self.ElectrodeManagerController = ws.ElectrodeManagerController(model, self) ;
            self.TestPulserController = ws.TestPulserController(model) ;
            self.FastProtocolsController = ws.FastProtocolsController(model) ;
            
            % % Set up XData_ and YData_
            %self.clearXDataAndYData_() ;
           
            % Set properties of the figure
            set(self.FigureGH_, ...
                'Units','Pixels', ...
                'Name',sprintf('WaveSurfer %s',ws.versionString()), ...
                'MenuBar','none', ...
                'DockControls','off', ...
                'NumberTitle','off', ...
                'Visible','off' );
           
            % Load in the needed icons from disk
            wavesurferDirName=fileparts(which('wavesurfer'));
            iconFileName = fullfile(wavesurferDirName, '+ws', 'icons', 'up_arrow.png');
            self.NormalYScrollUpIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'icons', 'down_arrow.png');
            self.NormalYScrollDownIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'icons', 'y_tight_to_data.png');
            self.NormalYTightToDataIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'icons', 'y_tight_to_data_locked.png');
            self.NormalYTightToDataLockedIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'icons', 'y_tight_to_data_unlocked.png');
            self.NormalYTightToDataUnlockedIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'icons', 'y_manual_set.png');
            self.NormalYCaretIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'icons', 'play.png') ;
            self.NormalPlayIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'icons', 'record.png') ;
            self.NormalRecordIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            iconFileName = fullfile(wavesurferDirName, '+ws', 'icons', 'stop.png') ;
            self.NormalStopIcon_ = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            
            % Create the trace color sequence
            self.TraceColorSequence_ = ws.makeColorSequence() ;
            
            % Create the fixed controls (which for this figure is all of them)
            self.createFixedControls_();

            % Set up the tags of the HG objects to match the property names
            self.setNonidiomaticProperties_();            
            
            % Set the initial figure position
            self.setInitialFigurePosition_() ;
            
            % Do an update to sync with model  (this will do layout)
            self.update();
            
            % Subscribe to stuff
            if ~isempty(model) ,
                model.subscribeMe(self, 'Update', '', 'update') ;
                model.subscribeMe(self, 'UpdateMain', '', 'update');
                %model.subscribeMe(self, 'WillSetState', '', 'willSetModelState');
                model.subscribeMe(self, 'DidSetState', '', 'update');
                model.subscribeMe(self, 'UpdateIsYokedToScanImage', '', 'updateControlProperties');
                model.subscribeMe(self, 'DidCompleteSweep', '', 'updateControlProperties');
                model.subscribeMe(self, 'UpdateForNewData', '', 'updateForNewData');
                model.subscribeMe(self, 'RequestLayoutForAllWindows', '', 'layoutForAllWindowsRequested');                
                model.subscribeMe(self, 'LayoutAllWindows', '', 'layoutAllWindows');                
                model.subscribeMe(self, 'RaiseDialogOnException', '', 'raiseDialogOnException');                                
                model.subscribeMe(self, 'DidMaybeChangeProtocol', '', 'didMaybeChangeProtocol');                                
                model.subscribeMe(self, 'UpdateChannels', '', 'didMaybeChangeProtocol');         
                model.subscribeMe(self, 'DidSetSingleFigureVisibility', '', 'updateFigureVisibilityMenuChecks') ;                
                model.subscribeMe(self, 'DidSetUpdateRate', '', 'updateControlProperties') ;
                model.subscribeMe(self, 'DidSetXOffset', '', 'updateXAxisLimits') ;
                model.subscribeMe(self, 'DidSetXSpan', '', 'updateXAxisLimits') ;
                model.subscribeMe(self, 'DidSetYAxisLimits', '', 'updateYAxisLimits') ;
                model.subscribeMe(self, 'UpdateTraces', '', 'updateTraces') ;
                model.subscribeMe(self, 'UpdateAfterDataAdded', '', 'updateTraces') ;
            end
            
            % Make the figure visible
            set(self.FigureGH_,'Visible','on');
        end  % constructor
        
        function delete(self)
            % This is the final common path for the Quit menu item and the
            % upper-right close button.

            % Delete the figure GHs for all the child controllers
            ws.deleteIfValidHandle(self.GeneralSettingsController) ;
            ws.deleteIfValidHandle(self.ChannelsController) ;
            ws.deleteIfValidHandle(self.StimulusLibraryController) ;
            ws.deleteIfValidHandle(self.StimulusPreviewController) ;
            ws.deleteIfValidHandle(self.TriggersController) ;
            ws.deleteIfValidHandle(self.UserCodeManagerController) ;
            ws.deleteIfValidHandle(self.ElectrodeManagerController) ;
            ws.deleteIfValidHandle(self.TestPulserController) ;
            ws.deleteIfValidHandle(self.FastProtocolsController) ;            

            % Remove ref to the scope plots
            self.ScopePlots_ = [] ;  % not really necessary
            
            % Delete the main figure
            figure = self.FigureGH_ ;
            if ~isempty(figure) && isvalid(figure) ,
                delete(figure) ;
            end
            
            % Finally, delete the model explicitly, b/c the model uses a
            % timer-like-thing for SI yoking, and don't want the model to stick around
            % just b/c of that timer.  Sadly, this means that the model may get deleted
            % in some situations where the user doesn't want it to, but this seems like
            % the best of a bad set of options.
            delete(self.Model_) ;
        end  % function        
    end
    
    methods (Access=protected)
%         function resize_(self)
%             fprintf('In WavesurferMainController::resize_()\n') ;
%             self.layout_() ;         
%             %self.updateTraces_() ;  % think this should happen via broadcast...
%         end        
        
        function setInitialFigurePosition_(self)
            % Set the initial figure size

            % Get the offset, which will stay the same
            %position = get(self.FigureGH_,'Position') ;
            %offset = position(1:2) ;            
            
            % Don't want the fig to be larger than the screen
            originalScreenUnits=get(0,'Units');
            set(0,'Units','pixels');
            screenPosition=get(0,'ScreenSize');
            set(0,'Units',originalScreenUnits);            
            screenSize=screenPosition(3:4);
            screenHeight = screenSize(2) ;
            maxInitialHeight = screenHeight - 50 ;  % pels

            % Some info shared with the layout methods
            figureWidth=750;            
            toolbarAreaHeight=36;
            statusBarAreaHeight=30;
            
            % Make this figure a good size for the number of plots
            nPlots = self.Model_.NPlots ;
            idealPlotAreaHeight = 250 * max(1,nPlots) ;
            idealFigureHeight = toolbarAreaHeight + idealPlotAreaHeight + statusBarAreaHeight ;            
            initialHeight = min(idealFigureHeight, maxInitialHeight) ;
            initialSize=[figureWidth initialHeight];
            
            % Compute the offset
            initialOffset = ws.figureOffsetToPositionOnRootRelativeToUpperLeft(initialSize,[30 30+40]) ;
            
            % Set the state
            figurePosition=[initialOffset initialSize];
            set(self.FigureGH_, 'Position', figurePosition) ;
        end  % function        
    end  % protected methods block    
    
    methods (Access = protected)
        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
            
            % File menu
            self.FileMenu=uimenu('Parent',self.FigureGH_, ...
                                 'Label','File');
            self.OpenProtocolMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Accelerator', 'o', ...
                       'Label','Open Protocol...');
            self.SaveProtocolMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Save Protocol', ...
                       'Accelerator', 's');
            self.SaveProtocolAsMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Save Protocol As...');
            self.ExportModelAndControllerToWorkspaceMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Label','Export Model and Controller to Workspace');
            self.QuitMenuItem = ...
                uimenu('Parent',self.FileMenu, ...
                       'Accelerator', 'q', ...
                       'Label','Quit');

            % Protocol menu
            self.ProtocolMenu=uimenu('Parent',self.FigureGH_, ...
                                     'Label','Protocol');
            self.GeneralSettingsMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Checked', 'off', ...
                       'Label','General...');
            self.ChannelsMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Checked', 'off', ...
                       'Label','Devices & Channels...');
            self.StimulusLibraryMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Checked', 'off', ...
                       'Label','Stimulus Library...');
            self.StimulusPreviewMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Checked', 'off', ...
                       'Visible', 'off', ...
                       'Label','Stimulus Preview...');
            self.TriggersMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Checked', 'off', ...
                       'Label','Triggers...');
%             self.DisplayMenuItem = ...
%                 uimenu('Parent',self.ProtocolMenu, ...
%                        'Label','Display...');
            self.UserCodeManagerMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Checked', 'off', ...
                       'Label','User Code...');
            self.ElectrodesMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Checked', 'off', ...
                       'Label','Electrodes...');
            self.TestPulseMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Checked', 'off', ...
                       'Label','Test Pulse...');
            self.YokeToScanimageMenuItem = ...
                uimenu('Parent',self.ProtocolMenu, ...
                       'Separator','on', ...
                       'Enable', 'off', ...
                       'Label','Yoked to ScanImage');

            % View menu
            self.ViewMenu_ = ...
                uimenu('Parent',self.FigureGH_, ...
                       'Label','View');
            self.InvertColorsMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Label','Green On Black', ...
                       'Callback',@(source,event)self.controlActuated('InvertColorsMenuItemGH',source,event));            
            self.ShowGridMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Label','Show Grid', ...
                       'Callback',@(source,event)self.controlActuated('ShowGridMenuItemGH',source,event));            
            self.DoShowZoomButtonsMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Label','Show Zoom Buttons', ...
                       'Callback',@(source,event)self.controlActuated('DoShowZoomButtonsMenuItemGH',source,event));            
            self.DoColorTracesMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Label','Color Traces', ...
                       'Callback',@(source,event)self.controlActuated('doColorTracesMenuItem',source,event));            
            self.PlotArrangementMenuItem_ = ...
                uimenu('Parent',self.ViewMenu_, ...
                       'Separator', 'on', ...
                       'Label','Plot Arrangement...', ...
                       'Callback',@(source,event)self.controlActuated('arrangementMenuItem',source,event));                                                  
                   
            % User menu
            self.ProfileMenu = ...
                uimenu('Parent',self.FigureGH_, ...
                       'Label','Profile');
%             self.LoadUserSettingsMenuItem = ...
%                 uimenu('Parent',self.ProfileMenu, ...
%                        'Label','ManageProfiles...');
%             self.SaveUserSettingsMenuItem = ...
%                 uimenu('Parent',self.ProfileMenu, ...
%                        'Label','Save User Settings');
%             self.SaveUserSettingsAsMenuItem = ...
%                 uimenu('Parent',self.ProfileMenu, ...
%                        'Label','Save User Settings As...');
                   
            % Help menu       
            self.HelpMenu=uimenu('Parent',self.FigureGH_, ...
                                 'Visible', 'off', ...
                                 'Label','Help');
            self.AboutMenuItem = ...
                uimenu('Parent',self.HelpMenu, ...
                       'Label','About WaveSurfer...');
                   
            % "Toolbar" buttons
            wavesurferDirName=fileparts(which('wavesurfer'));
            playIcon = ws.readPNGForToolbarIcon(fullfile(wavesurferDirName, '+ws', 'icons', 'play.png'));
            self.PlayButton = ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','pushbutton', ...
                          'TooltipString','Play', ...
                          'CData',playIcon);
            recordIcon = ws.readPNGForToolbarIcon(fullfile(wavesurferDirName, '+ws', 'icons', 'record.png'));
            self.RecordButton = ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','pushbutton', ...
                          'TooltipString','Record', ...
                          'CData',recordIcon);
            stopIcon = ws.readPNGForToolbarIcon(fullfile(wavesurferDirName, '+ws', 'icons', 'stop.png'));
            self.StopButton = ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','pushbutton', ...
                          'TooltipString','Stop', ...
                          'CData',stopIcon);                      
%             self.FastProtocolText = ...
%                 ws.uicontrol('Parent',self.FigureGH_, ...
%                           'Style','text', ...
%                           'String','');                
            nFastProtocolButtons=6;
            for i=1:nFastProtocolButtons ,
                self.FastProtocolButtons(i) = ...
                    ws.uicontrol('Parent',self.FigureGH_, ...
                                 'Style','pushbutton', ...
                                 'String',sprintf('%d',i));                
            end            
            self.ManageFastProtocolsButton = ...
                ws.uicontrol('Parent', self.FigureGH_, ...
                             'Style', 'pushbutton', ...
                             'TooltipString', 'Manage Fast Protocols', ...
                             'String', char(177)) ;  % unicode for plus-minus glyph
            
            % Stuff at the bottom of the window
            self.StatusText = ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','text', ...
                          'HorizontalAlignment','left', ...
                          'FontWeight','bold', ...
                          'String','Idle');
            self.ProgressBarAxes = ...
                axes('Parent',self.FigureGH_, ...
                     'Box','on', ...
                     'Layer','top', ...
                     'XTick',[], ...
                     'YTick',[], ...
                     'XLim',[0 1], ...
                     'YLim',[0 1], ...
                     'HandleVisibility','off', ...
                     'Visible','off');
            self.ProgressBarPatch = ...
                patch('Parent',self.ProgressBarAxes, ...
                      'EdgeColor','none', ...
                      'XData',[0 1 1 0 0], ...
                      'YData',[0 0 1 1 0], ...                      
                      'Visible','off');
%                     'FaceColor',[10 36 106]/255, ...
        end  % function
    end  % methods block
    
    methods (Access = protected)
        function setNonidiomaticProperties_(self)
            % For each object property, if it's an HG object, set the tag
            % based on the property name
            mc=metaclass(self);
            propertyNames={mc.PropertyList.Name};
            for i=1:length(propertyNames) ,
                propertyName=propertyNames{i};
                propertyThing=self.(propertyName);
                if ~isempty(propertyThing) && all(ishghandle(propertyThing(:))) && ~(isscalar(propertyThing) && isequal(get(propertyThing,'Type'),'figure')) ,
                    % Sometimes propertyThing is a vector, but if so
                    % they're all the same kind of control, so use the
                    % first one to check what kind of things they are
                    examplePropertyThing=propertyThing(1);
                    
                    % Set Tag
                    set(propertyThing,'Tag',propertyName);
                    
                    % Set Callback
                    if isequal(get(examplePropertyThing,'Type'),'uimenu') ,
                        if get(examplePropertyThing,'Parent')==self.FigureGH_ || get(examplePropertyThing,'Parent')==self.ViewMenu_ ,
                            % do nothing for top-level menus, or for menu items of the view menu
                        else
                            if isscalar(propertyThing)
                                set(propertyThing,'Callback',@(source,event)(self.controlActuated(propertyName,source,event)));
                            else
                                % For arrays, pass the index to the
                                % callback
                                for j = 1:length(propertyThing) ,
                                    set(propertyThing(j),'Callback',@(source,event)(self.controlActuated(propertyName,source,event,j)));
                                end                                    
                            end
                        end
                    elseif isequal(get(examplePropertyThing,'Type'),'uicontrol') && ~isequal(get(examplePropertyThing,'Style'),'text') ,
                        % set the callback for any uicontrol that is not a
                        % text
                        if isscalar(propertyThing)
                            set(propertyThing,'Callback',@(source,event)(self.controlActuated(propertyName,source,event)));
                        else
                            % For arrays, pass the index to the
                            % callback
                            for j = 1:length(propertyThing) ,
                                set(propertyThing(j),'Callback',@(source,event)(self.controlActuated(propertyName,source,event,j)));
                            end
                        end
                    end
                    
                    % Set Units
                    if isequal(get(examplePropertyThing,'Type'),'axes'),
                        set(propertyThing,'Units','pixels');
                    end
                end
            end
        end  % function        
    end  % protected methods block

    methods (Access = protected)
        function layout_(self)
            % This method should make sure all the controls are sized and placed
            % appropraitely given the current model state.
            
            % Get the figure dimensions
            figurePosition = get(self.FigureGH_, 'Position') ;
            figureSize = figurePosition(3:4) ;
            figureWidth = figureSize(1) ;
            figureHeight = figureSize(2) ;
            
            % Some dimensions
            minimumLayoutWidth = 500 ;
            minimumLayoutHeight = 300 ;
            toolbarAreaHeight=36;
            heightOfSpaceBetweenToolbarAndPlotArea = 4 ;
            statusBarAreaHeight=22;
            
            % Compute the layout size, and the layout y offset
            layoutWidth = max(minimumLayoutWidth, figureWidth) ;
            layoutHeight = max(minimumLayoutHeight, figureHeight) ;
            layoutYOffset = figureHeight - layoutHeight ;
            
            %
            % Layout the "toolbar"
            %
            vcrButtonsXOffset=11;
            vcrButtonWidth=26;
            vcrButtonHeight=26;
            spaceBetweenVCRButtons=5;
            widthFromFastProtocolButtonBarToEdge=5;
            %spaceFromVCRButtonsToFastProtocolButtons=40;
            fastProtocolButtonWidth=26;
            fastProtocolButtonHeight=26;
            spaceBetweenFastProtocolButtons=5;
            spaceBetweenFastProtocolButtonsAndManageButton = 10 ;
            %widthBetweenFastProtocolTextAndButtons=4;
            
            % VCR buttons
            vcrButtonsYOffset=layoutYOffset+layoutHeight-toolbarAreaHeight+(toolbarAreaHeight-vcrButtonHeight)/2;            
            xOffset=vcrButtonsXOffset;
            set(self.PlayButton,'Position',[xOffset vcrButtonsYOffset vcrButtonWidth vcrButtonHeight]);
            xOffset=xOffset+vcrButtonWidth+spaceBetweenVCRButtons;
            set(self.RecordButton,'Position',[xOffset vcrButtonsYOffset vcrButtonWidth vcrButtonHeight]);
            xOffset=xOffset+vcrButtonWidth+spaceBetweenVCRButtons;
            set(self.StopButton,'Position',[xOffset vcrButtonsYOffset vcrButtonWidth vcrButtonHeight]);
            
            % Fast Protocol text
            %fastProtocolTextExtent=get(self.FastProtocolText,'Extent');
            %fastProtocolTextWidth=fastProtocolTextExtent(3)+2;
            %fastProtocolTextPosition=get(self.FastProtocolText,'Position');
            %fastProtocolTextHeight=fastProtocolTextPosition(4);
            nFastProtocolButtons=length(self.FastProtocolButtons);
            widthOfFastProtocolButtonBar = nFastProtocolButtons*fastProtocolButtonWidth+(nFastProtocolButtons-1)*spaceBetweenFastProtocolButtons + ...
                                           spaceBetweenFastProtocolButtonsAndManageButton + fastProtocolButtonWidth ; 
            %xOffset=layoutWidth-widthFromFastProtocolButtonBarToEdge-widthOfFastProtocolButtonBar-widthBetweenFastProtocolTextAndButtons-fastProtocolTextWidth;
            fastProtocolButtonsYOffset=layoutYOffset+layoutHeight-toolbarAreaHeight+(toolbarAreaHeight-fastProtocolButtonHeight)/2;
            %yOffset=fastProtocolButtonsYOffset+(fastProtocolButtonHeight-fastProtocolTextHeight)/2-4;  % shim
            %set(self.FastProtocolText,'Position',[xOffset yOffset fastProtocolTextWidth fastProtocolTextHeight]);
            
            % Fast protocol buttons
            xOffset=layoutWidth-widthFromFastProtocolButtonBarToEdge-widthOfFastProtocolButtonBar;
            for i=1:nFastProtocolButtons ,
                set(self.FastProtocolButtons(i),'Position',[xOffset fastProtocolButtonsYOffset fastProtocolButtonWidth fastProtocolButtonHeight]);
                xOffset=xOffset+fastProtocolButtonWidth+spaceBetweenFastProtocolButtons;                
            end
            manageFastProtocolsButtonXOffset = layoutWidth-widthFromFastProtocolButtonBarToEdge-fastProtocolButtonWidth ;
            set(self.ManageFastProtocolsButton, ...
                'Position', [manageFastProtocolsButtonXOffset fastProtocolButtonsYOffset fastProtocolButtonWidth fastProtocolButtonHeight]) ;
            
            
            %
            % The plots
            %            
            % The height of the area for the x axis label on the bottom plot
            xAxisLabelAreaHeight = 34 ;
            
            plotHeightFromPlotIndex = self.Model_.PlotHeightFromPlotIndex ;
            normalizedPlotHeightFromPlotIndex = plotHeightFromPlotIndex/sum(plotHeightFromPlotIndex) ;
            totalNormalizedHeightOfPreviousPlotsFromPlotIndex = cumsum(normalizedPlotHeightFromPlotIndex) ;
            
            doesUserWantToSeeZoomButtons = self.Model_.DoShowZoomButtons ;
            isAnalogFromPlotIndex = self.Model_.IsAnalogFromPlotIndex ;
            nPlots = length(self.ScopePlots_) ;
            for iPlot=1:nPlots ,
                isThisPlotAnalog = isAnalogFromPlotIndex(iPlot) ;
                self.ScopePlots_(iPlot).setPositionAndLayout([layoutWidth layoutHeight], ...
                                                             layoutYOffset, ...
                                                             toolbarAreaHeight, ...
                                                             heightOfSpaceBetweenToolbarAndPlotArea, ...
                                                             statusBarAreaHeight, ...
                                                             xAxisLabelAreaHeight, ...
                                                             normalizedPlotHeightFromPlotIndex(iPlot) , ...
                                                             totalNormalizedHeightOfPreviousPlotsFromPlotIndex(iPlot) , ...                                                             
                                                             doesUserWantToSeeZoomButtons, ...
                                                             isThisPlotAnalog) ;
            end
            
            %
            % The status area
            %
            statusTextWidth=160;
            statusTextPosition=get(self.StatusText,'Position');
            statusTextHeight=statusTextPosition(4);
            statusTextXOffset=10;
            statusTextYOffset=layoutYOffset+(statusBarAreaHeight-statusTextHeight)/2-2;  % shim
            set(self.StatusText,'Position',[statusTextXOffset statusTextYOffset statusTextWidth statusTextHeight]);
                        
            %
            % The progress bar
            %
            widthFromProgressBarRightToFigureRight=10;
            progressBarWidth=240;
            progressBarHeight=12;
            progressBarXOffset = layoutWidth-widthFromProgressBarRightToFigureRight-progressBarWidth ;
            progressBarYOffset = layoutYOffset+(statusBarAreaHeight-progressBarHeight)/2 +1 ;  % shim
            set(self.ProgressBarAxes,'Position',[progressBarXOffset progressBarYOffset progressBarWidth progressBarHeight]);
            
            % Inform the model of the axes width in pixels.
            if nPlots > 0 ,
                widthInPixels = self.ScopePlots_(1).getAxesWidthInPixels() ;
                self.Model_.WidthOfPlotsInPixels = widthInPixels ;
            end            
        end  % function
        
    end  % protected methods    

    methods (Access = protected)
        function updateControlsInExistance_(self)
            % Make it so we have the same number of scopes as displayed channels,
            % adding/deleting them as needed.
            isChannelDisplayed = horzcat(self.Model_.IsAIChannelDisplayed, self.Model_.IsDIChannelDisplayed) ;
            nChannelsDisplayed = sum(isChannelDisplayed) ;
            nScopePlots = length(self.ScopePlots_) ;
            if nChannelsDisplayed>nScopePlots ,
                for i = nScopePlots+1:nChannelsDisplayed ,
                    newScopePlot = ws.ScopePlot(self, i, self.FigureGH_) ;
                    self.ScopePlots_ = horzcat(self.ScopePlots_, newScopePlot);
                end
            elseif nChannelsDisplayed<nScopePlots ,
                for i = nChannelsDisplayed+1:nScopePlots ,
                    self.ScopePlots_(i).delete() ;  % Have to delete "manually" to eliminate UI objects
                end
                self.ScopePlots_ = self.ScopePlots_(1:nChannelsDisplayed) ;
            else
                % do nothing --- we already have the right number of
                % ScopePlots
            end
            
            % Delete the items in the profile menu, re-make them
            delete(self.ProfileMenuItems) ;
            delete(self.NewProfileMenuItem) ;            
            delete(self.DeleteProfileMenuItem) ;            
            delete(self.RenameProfileMenuItem) ;            
            self.ProfileMenuItems = [] ;
            self.NewProfileMenuItem = [] ;
            self.DeleteProfileMenuItem = [] ;
            self.RenameProfileMenuItem = [] ;
            profileNames = self.Model_.ProfileNames ;  % is sorted
            %currentProfileName = self.Model_.CurrentProfileName ;
            %isProfileCurrent = strcmp(currentProfileName, profileNames) ;
            for i = 1 : length(profileNames) ,
                profileName = profileNames{i} ;
                self.ProfileMenuItems(i) = ...
                    uimenu('Parent', self.ProfileMenu, ...
                           'Label', profileName, ...
                           'Callback', @(source, event)(self.controlActuated('ProfileMenuItem', source, event, profileName))) ;                           
            end
            self.NewProfileMenuItem = ...
                uimenu('Parent', self.ProfileMenu, ...
                       'Label', 'New', ...
                       'Callback', @(source, event)(self.controlActuated('NewProfileMenuItem', source, event)), ...
                       'Separator', 'on') ;
            self.DeleteProfileMenuItem = ...
                uimenu('Parent', self.ProfileMenu, ...
                       'Label', 'Delete...', ...
                       'Callback', @(source, event)(self.controlActuated('DeleteProfileMenuItem', source, event))) ;
            self.RenameProfileMenuItem = ...
                uimenu('Parent', self.ProfileMenu, ...
                       'Label', 'Rename...', ...
                       'Callback', @(source, event)(self.controlActuated('RenameProfileMenuItem', source, event))) ;
        end
    end  % protected methods block
    
    methods (Access = protected)
        function updateControlPropertiesImplementation_(self) 
            % In subclass, this should make sure the properties of the
            % controls (besides Position and Enable) are in-sync with the
            % model.  It can assume that all the controls that should
            % exist, do exist.
            
            % Check for a valid model
            wsModel = self.Model_ ;
            if isempty(wsModel) ,
                return
            end            
            
            % Set the button colors and icons
            areColorsNormal = wsModel.AreColorsNormal ;
            defaultUIControlBackgroundColor = ws.getDefaultUIControlBackgroundColor() ;
            controlBackgroundColor  = ws.fif(areColorsNormal,defaultUIControlBackgroundColor,'k') ;
            controlForegroundColor = ws.fif(areColorsNormal,'k','w') ;
            if areColorsNormal ,
                playIcon   = self.NormalPlayIcon_   ;
                recordIcon = self.NormalRecordIcon_ ;
                stopIcon = self.NormalStopIcon_ ;
            else
                playIcon   = 1-self.NormalPlayIcon_   ;  % RGB images, so this inverts them, leaving nan's alone
                recordIcon = self.NormalRecordIcon_ ;  % looks OK in either case
                stopIcon = 1-self.NormalStopIcon_ ;
            end                
            set(self.PlayButton,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor,'CData',playIcon) ;
            set(self.RecordButton,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor,'CData',recordIcon) ;
            set(self.StopButton,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor,'CData',stopIcon) ;
            set(self.FastProtocolButtons,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor) ;
            set(self.ManageFastProtocolsButton,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor) ;
            
            % Fast config buttons
            nFastProtocolButtons=length(self.FastProtocolButtons);
            for i=1:nFastProtocolButtons ,
                %thisFastProtocol = wsModel.FastProtocols{i};
                thisProtocolFilePath = wsModel.getFastProtocolProperty(i, 'ProtocolFileName') ;
                thisProtocolFileName = ws.baseFileNameFromPath(thisProtocolFilePath) ;
                set(self.FastProtocolButtons(i),...
                    'TooltipString', thisProtocolFileName)
            end
            
            % Plots and such
            self.updateDisplayControlPropertiesImplementation_() ;
            
            % Status text
            if isequal(wsModel.State,'running') ,
                if wsModel.IsLoggingEnabled ,
                    statusString = 'Recording' ;
                else
                    statusString = 'Playing' ;
                end                    
            else
                statusString = ws.titleStringFromApplicationState(wsModel.State) ;
            end
            set(self.StatusText,'String',statusString,'ForegroundColor',controlForegroundColor,'BackgroundColor',controlBackgroundColor);
            
            % Progress bar
            self.updateProgressBarProperties_();
            
            % Menu checkboxes            
            self.updateFigureVisibilityMenuChecks() ;
            set(self.YokeToScanimageMenuItem,'Checked',ws.onIff(wsModel.IsYokedToScanImage));
            
            % The save menu items
            self.updateProfileMenu_();
            
            % Finally, the window title
            self.updateWindowTitle_();
        end
    end  % protected methods block
    
    methods
        function updateFigureVisibilityMenuChecks(self, varargin)
            wsModel = self.Model_ ;
            set(self.GeneralSettingsMenuItem, 'Checked', ws.onIff(wsModel.IsGeneralSettingsFigureVisible));
            set(self.ChannelsMenuItem, 'Checked', ws.onIff(wsModel.IsChannelsFigureVisible));
            set(self.StimulusLibraryMenuItem, 'Checked', ws.onIff(wsModel.IsStimulusLibraryFigureVisible));
            set(self.StimulusPreviewMenuItem, 'Checked', ws.onIff(wsModel.IsStimulusPreviewFigureVisible));
            set(self.TriggersMenuItem, 'Checked', ws.onIff(wsModel.IsTriggersFigureVisible));
            set(self.UserCodeManagerMenuItem, 'Checked', ws.onIff(wsModel.IsUserCodeManagerFigureVisible));
            set(self.ElectrodesMenuItem, 'Checked', ws.onIff(wsModel.IsElectrodeManagerFigureVisible));
            set(self.TestPulseMenuItem, 'Checked', ws.onIff(wsModel.IsTestPulserFigureVisible));            
        end
    end
    
    methods (Access=protected)    
        function updateDisplayControlPropertiesImplementation_(self)
            % If there are issues with the model, just return
            wsModel=self.Model_;
            if isempty(wsModel) || ~isvalid(wsModel) ,
                return
            end
            
            % Update the Show Grid togglemenu
            isGridOn = wsModel.IsGridOn ;
            set(self.ShowGridMenuItem_,'Checked',ws.onIff(isGridOn));

            % Update the Invert Colors togglemenu
            areColorsNormal = wsModel.AreColorsNormal ;
            set(self.InvertColorsMenuItem_,'Checked',ws.onIff(~areColorsNormal));

            % Update the Do Show Buttons togglemenu
            doShowZoomButtons = wsModel.DoShowZoomButtons ;
            set(self.DoShowZoomButtonsMenuItem_,'Checked',ws.onIff(doShowZoomButtons));

            % Update the Do Color Traces togglemenu
            doColorTraces = wsModel.DoColorTraces ;
            set(self.DoColorTracesMenuItem_,'Checked',ws.onIff(doColorTraces));

            % Compute the colors
            defaultUIControlBackgroundColor = ws.getDefaultUIControlBackgroundColor() ;
            controlBackgroundColor  = ws.fif(areColorsNormal,defaultUIControlBackgroundColor,'k') ;
            controlForegroundColor = ws.fif(areColorsNormal,'k','w') ;
            figureBackground = ws.fif(areColorsNormal,defaultUIControlBackgroundColor,'k') ;
            set(self.FigureGH_,'Color',figureBackground);
            axesBackgroundColor = ws.fif(areColorsNormal,'w','k') ;
            axesForegroundColor = ws.fif(areColorsNormal,'k','g') ;
            %traceLineColor = ws.fif(areColorsNormal,'k','w') ;

            % Compute the icons
            if areColorsNormal ,
                yScrollUpIcon   = self.NormalYScrollUpIcon_   ;
                yScrollDownIcon = self.NormalYScrollDownIcon_ ;
                yTightToDataIcon = self.NormalYTightToDataIcon_ ;
                yTightToDataLockedIcon = self.NormalYTightToDataLockedIcon_ ;
                yTightToDataUnlockedIcon = self.NormalYTightToDataUnlockedIcon_ ;
                yCaretIcon = self.NormalYCaretIcon_ ;
            else
                yScrollUpIcon   = 1-self.NormalYScrollUpIcon_   ;  % RGB images, so this inverts them, leaving nan's alone
                yScrollDownIcon = 1-self.NormalYScrollDownIcon_ ;                
                yTightToDataIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYTightToDataIcon_) ;  
                yTightToDataLockedIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYTightToDataLockedIcon_) ;
                yTightToDataUnlockedIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYTightToDataUnlockedIcon_) ;
                yCaretIcon = ws.whiteFromGreenGrayFromBlack(self.NormalYCaretIcon_) ;
            end                

            % Determine the common x-axis limits
            xl = wsModel.XOffset + [0 wsModel.XSpan] ;

            % Get the y-axis limits for all analog channels
            yLimitsPerAnalogChannel = wsModel.YLimitsPerAIChannel ;

            % Get the channel names and units for all channels
            %acq = wsModel.Acquisition ;
            aiChannelNames = wsModel.AIChannelNames ;            
            diChannelNames = wsModel.DIChannelNames ;
            aiChannelUnits = wsModel.AIChannelUnits ;            
            
            % Update the individual plot colors and icons
            %displayModel = wsModel.Display ;
            areYLimitsLockedTightToDataFromAIChannelIndex = wsModel.AreYLimitsLockedTightToDataForAIChannel ;
            channelIndexWithinTypeFromPlotIndex = wsModel.ChannelIndexWithinTypeFromPlotIndex ;
            isAnalogFromPlotIndex = wsModel.IsAnalogFromPlotIndex ;
            channelIndexFromPlotIndex = wsModel.ChannelIndexFromPlotIndex ;
            %[channelIndexWithinTypeFromPlotIndex, isAnalogFromPlotIndex] = self.getChannelIndexFromPlotIndexMapping() ;
            nPlots = length(self.ScopePlots_) ;
            for plotIndex=1:length(self.ScopePlots_) ,
                thisPlot = self.ScopePlots_(plotIndex) ;
                isThisChannelAnalog = isAnalogFromPlotIndex(plotIndex) ;
                indexOfThisChannelWithinType =  channelIndexWithinTypeFromPlotIndex(plotIndex) ;  % where "type" means analog or digital
                indexOfThisChannel = channelIndexFromPlotIndex(plotIndex) ;

                % Determine trace color for this plot
                if doColorTraces ,
                    normalTraceLineColor = self.TraceColorSequence_(indexOfThisChannel,:) ;
                else
                    normalTraceLineColor = [0 0 0] ;  % black
                end
                if areColorsNormal ,
                    traceLineColor = normalTraceLineColor ;
                else
                    traceLineColor = 1 - normalTraceLineColor ;
                end
                    
                if isThisChannelAnalog ,
                    areYLimitsLockedTightToDataForThisChannel = areYLimitsLockedTightToDataFromAIChannelIndex(indexOfThisChannelWithinType) ;
                    thisPlot.setColorsAndIcons(controlForegroundColor, controlBackgroundColor, ...
                                               axesForegroundColor, axesBackgroundColor, ...
                                               traceLineColor, ...
                                               yScrollUpIcon, yScrollDownIcon, yTightToDataIcon, yTightToDataLockedIcon, yTightToDataUnlockedIcon, yCaretIcon, ...
                                               areYLimitsLockedTightToDataForThisChannel) ;
                    thisPlot.IsGridOn = isGridOn ;                       
                    thisPlot.setXAxisLimits(xl) ;
                    thisPlot.setYAxisLimits(yLimitsPerAnalogChannel(:,indexOfThisChannelWithinType)') ;
                    thisPlot.setYAxisLabel(aiChannelNames{indexOfThisChannelWithinType}, ...
                                           true, ...
                                           aiChannelUnits{indexOfThisChannelWithinType}, ...
                                           axesForegroundColor) ;
                    if plotIndex==nPlots ,
                        thisPlot.setXAxisLabel(axesForegroundColor) ;
                    else
                        thisPlot.clearXAxisLabel() ;
                    end
                else
                    % this channel is digital
                    thisPlot.setColorsAndIcons(controlForegroundColor, controlBackgroundColor, ...
                                               axesForegroundColor, axesBackgroundColor, ...
                                               traceLineColor, ...
                                               yScrollUpIcon, yScrollDownIcon, yTightToDataIcon, yTightToDataLockedIcon, yTightToDataUnlockedIcon, yCaretIcon, ...
                                               true) ;
                    thisPlot.IsGridOn = isGridOn ;                       
                    thisPlot.setXAxisLimits(xl) ;
                    thisPlot.setYAxisLimits([-0.05 1.05]) ;
                    thisPlot.setYAxisLabel(diChannelNames{indexOfThisChannelWithinType}, false, [], axesForegroundColor) ;
                    if plotIndex==nPlots ,
                        thisPlot.setXAxisLabel(axesForegroundColor) ;
                    else
                        thisPlot.clearXAxisLabel() ;
                    end
                end
            end

            % Do this separately, although we could do it at same time if
            % speed is an issue...
            %self.syncLineXDataAndYData_();
            self.updateTraces_() ;
        end  % function        
        
        function updateControlEnablementImplementation_(self) 
            % This makes sure the Enable property of each control is in-sync with the
            % model.  It can assume that all the controls that should exist, do exist.

            % Updates the menu and button enablement to be appropriate for
            % the model state.

            % If no model, can't really do anything
            model=self.Model_;
            if isempty(model) ,
                % We can wait until there's actually a model
                return
            end
            
            isNoDevice = isequal(model.State,'no_device') ;
            isIdle=isequal(model.State,'idle');
            isAcquiring = isequal(model.State,'running') ;
            isDefaultProfileCurrent = isequal(model.CurrentProfileName, 'Default') ;
            
            % File menu items
            set(self.OpenProtocolMenuItem,'Enable',ws.onIff(isNoDevice||isIdle));            
            set(self.SaveProtocolMenuItem,'Enable',ws.onIff(isIdle));            
            set(self.SaveProtocolAsMenuItem,'Enable',ws.onIff(isIdle));            
            %set(self.LoadUserSettingsMenuItem,'Enable',ws.onIff(isIdle));            
            %set(self.SaveUserSettingsMenuItem,'Enable',ws.onIff(isIdle));            
            %set(self.SaveUserSettingsAsMenuItem,'Enable',ws.onIff(isIdle));            
            set(self.ExportModelAndControllerToWorkspaceMenuItem,'Enable',ws.onIff(isIdle||isNoDevice));
            %set(self.QuitMenuItem,'Enable',ws.onIff(true));  % always available          
                        
            % Protocol Menu
            set(self.GeneralSettingsMenuItem,'Enable',ws.onIff(isIdle));
            %set(self.DisplayMenuItem,'Enable',ws.onIff(isIdle));
            %set(self.ScopesMenuItem,'Enable',ws.onIff(isIdle && (model.Display.NScopes>0) && model.IsDisplayEnabled));
            set(self.ChannelsMenuItem,'Enable',ws.onIff(true));  
              % Device & Channels menu is always available so that
              % user can get at radiobutton for untimed DO channels,
              % if desired.
            set(self.StimulusLibraryMenuItem,'Enable',ws.onIff(isIdle));
            set(self.StimulusPreviewMenuItem,'Enable',ws.onIff(isIdle));
            set(self.TriggersMenuItem,'Enable',ws.onIff(isIdle));
            set(self.UserCodeManagerMenuItem,'Enable',ws.onIff(isIdle));            
            set(self.ElectrodesMenuItem,'Enable',ws.onIff(isIdle));
            set(self.TestPulseMenuItem,'Enable',ws.onIff(isIdle));
            %set(self.YokeToScanimageMenuItem,'Enable',ws.onIff(isIdle));

            % View menu
            % These things stay active all the time, so user can change them during
            % acquisition.
            
            % Profile menu
            set(self.ProfileMenuItems,'Enable',ws.onIff(isIdle));
            set(self.NewProfileMenuItem,'Enable',ws.onIff(isIdle));
            set(self.DeleteProfileMenuItem,'Enable',ws.onIff(isIdle && ~isDefaultProfileCurrent));
            set(self.RenameProfileMenuItem,'Enable',ws.onIff(isIdle && ~isDefaultProfileCurrent));
            
            % Help menu
            set(self.AboutMenuItem,'Enable',ws.onIff(isIdle||isNoDevice));
            
            % Toolbar buttons
            set(self.PlayButton,'Enable',ws.onIff(isIdle));
            set(self.RecordButton,'Enable',ws.onIff(isIdle));
            set(self.StopButton,'Enable',ws.onIff(isAcquiring));
            
            % Fast config buttons
            set(self.ManageFastProtocolsButton,'Enable',ws.onIff(isIdle));
            nFastProtocolButtons=length(self.FastProtocolButtons);
            for i=1:nFastProtocolButtons ,
                isNonempty = model.getFastProtocolProperty(i, 'IsNonempty') ;
                set(self.FastProtocolButtons(i),'Enable',ws.onIff( isIdle && isNonempty));
            end

            % Plots and such
            self.updateDisplayControlEnablementImplementation_(model) ;
            
            % Status bar controls
            if ~isAcquiring , 
                set(self.ProgressBarAxes,'Visible','off') ;
            end
        end
        
        function updateDisplayControlEnablementImplementation_(self, wsModel)
            % Update the enablement of buttons in the panels
            %display = wsModel.Display ;
            areYLimitsLockedTightToData = wsModel.AreYLimitsLockedTightToDataForAIChannel ;
            channelIndexWithinTypeFromPlotIndex = wsModel.ChannelIndexWithinTypeFromPlotIndex ;
            isAnalogFromPlotIndex = wsModel.IsAnalogFromPlotIndex ;
            for iPlot=1:length(self.ScopePlots_) ,
                isThisPlotAnalog = isAnalogFromPlotIndex(iPlot) ;
                thisChannelIndex = channelIndexWithinTypeFromPlotIndex(iPlot) ;
                if isThisPlotAnalog ,
                    self.ScopePlots_(iPlot).setControlEnablement(true, areYLimitsLockedTightToData(thisChannelIndex)) ;
                else
                    % this channel/plot is digital
                    self.ScopePlots_(iPlot).setControlEnablement(false) ;  % digital channels are always locked tight to data
                end
            end
        end  % function        
    end
    
%     methods
% %         function willSetModelState(self,varargin)
% %             % Used to inform the controller that the model run state is
% %             % about to be set
% %             self.OriginalModelState_=self.Model_.State;
% %         end
%         
% %         function didSetModelState(self,varargin)
% %             % Used to inform the controller that the model run state has
% %             % been set
% %             
% %             % Make a local copy of the original state, clear the cache
% %             originalModelState=self.OriginalModelState_;
% %             self.OriginalModelState_=[];
% %             
% %             % If we're switching out of the "no_device" mode, update the scope menu            
% %             if isequal(originalModelState,'no_device') && ~isequal(self.Model_.State,'no_device') ,
% %                 self.update();
% %             else
% %                 % More limited update is sufficient
% %                 self.updateControlProperties();
% %                 self.updateControlEnablement();
% %             end
% %         end
%     end     
    
    methods (Access=protected)
        function updateProgressBarProperties_(self)
            wsModel = self.Model_ ;
            state = wsModel.State ;
            
            brightGreen = [0 1 0] ;
            darkBlue = [10 36 106]/255 ;
            
            areColorsNormal = wsModel.AreColorsNormal ;
            axesBackgroundColor = ws.fif(areColorsNormal,'w','k') ;
            axesForegroundColor = ws.fif(areColorsNormal,'k','w') ;
            patchColor = ws.fif(areColorsNormal,darkBlue,brightGreen) ;
            
            if isequal(state,'running') ,
                if wsModel.AreSweepsFiniteDuration ,
                    if isfinite(wsModel.NSweepsPerRun) ,
                        nSweeps=wsModel.NSweepsPerRun;
                        nSweepsCompleted=wsModel.NSweepsCompletedInThisRun;
                        fractionCompleted=nSweepsCompleted/nSweeps;
                        set(self.ProgressBarPatch, ...
                            'XData',[0 fractionCompleted fractionCompleted 0 0], ...
                            'YData',[0 0 1 1 0], ...
                            'FaceColor', patchColor, ...
                            'Visible','on');
                        set(self.ProgressBarAxes, ...                
                            'Color',axesBackgroundColor, ...
                            'XColor',axesForegroundColor, ...
                            'YColor',axesForegroundColor, ...
                            'ZColor',axesForegroundColor, ...;
                            'Visible','on');
                    else
                        % number of sweeps is infinite
                        nSweepsPretend=20;
                        nSweepsCompleted = wsModel.NSweepsCompletedInThisRun ;
                        nSweepsCompletedModded=mod(nSweepsCompleted,nSweepsPretend);
                        if nSweepsCompletedModded==0 ,
                            if nSweepsCompleted==0 ,
                                nSweepsCompletedPretend = 0 ;
                            else
                                nSweepsCompletedPretend = nSweepsPretend ;                            
                            end
                        else
                            nSweepsCompletedPretend = nSweepsCompletedModded ;
                        end                    
                        fractionCompletedPretend=nSweepsCompletedPretend/nSweepsPretend;
                        set(self.ProgressBarPatch, ...
                            'XData',[0 fractionCompletedPretend fractionCompletedPretend 0 0], ...
                            'YData',[0 0 1 1 0], ...
                            'FaceColor', patchColor, ...
                            'Visible','on');
                        set(self.ProgressBarAxes, ...                
                            'Color',axesBackgroundColor, ...
                            'XColor',axesForegroundColor, ...
                            'YColor',axesForegroundColor, ...
                            'ZColor',axesForegroundColor, ...;
                            'Visible','on');
                    end
                else
                    % continuous acq
                    nTimesDataAvailableCalledSinceRunStart=wsModel.NTimesDataAvailableCalledSinceRunStart;
                    nSegments=10;
                    nPositions=2*nSegments;
                    barWidth=1/nSegments;
                    stepWidth=1/nPositions;
                    xOffset=stepWidth*mod(nTimesDataAvailableCalledSinceRunStart,nPositions);
                    set(self.ProgressBarPatch, ...
                        'XData',xOffset+[0 barWidth barWidth 0 0], ...
                        'YData',[0 0 1 1 0], ...
                        'FaceColor', patchColor, ...
                        'Visible','on');
                    set(self.ProgressBarAxes, ...                
                        'Color',axesBackgroundColor, ...
                        'XColor',axesForegroundColor, ...
                        'YColor',axesForegroundColor, ...
                        'ZColor',axesForegroundColor, ...;
                        'Visible','on');
                end
            else
                % If not running
                set(self.ProgressBarPatch, ...
                    'XData',[0 0 0 0 0], ...
                    'YData',[0 0 1 1 0], ...
                    'FaceColor', patchColor, ...
                    'Visible','off');
                set(self.ProgressBarAxes, ...                
                    'Color',axesBackgroundColor, ...
                    'XColor',axesForegroundColor, ...
                    'YColor',axesForegroundColor, ...
                    'ZColor',axesForegroundColor, ...;
                    'Visible','off');
            end
        end  % function
    end
    
    methods 
%         function layoutForAllWindowsRequested(self, varargin)
%             self.Controller.layoutForAllWindowsRequested(varargin{:}) ;
%         end                
%         
%         function layoutAllWindows(self, varargin)
%             self.Controller.layoutAllWindows() ;
%         end
        
        function updateForNewData(self,varargin)
            % Want this to be as fast as possible, so we just update the
            % bare minimum
            model=self.Model_;
            if model.AreSweepsContinuous ,
                self.updateProgressBarProperties_();
            end
        end
    end    
    
    methods (Access=protected)
        function updateWindowTitle_(self)
            absoluteProtocolFileName=self.Model_.AbsoluteProtocolFileName;
            if ~isempty(absoluteProtocolFileName) ,
                [~, name, ext] = fileparts(absoluteProtocolFileName);
                relativeFileName=[name ext];
                doesProtocolNeedSave = self.Model_.DoesProtocolNeedSave ;
                asteriskOrEmpty = ws.fif(doesProtocolNeedSave, '*', '') ;
                set(self.FigureGH_, 'Name', sprintf('WaveSurfer %s - %s%s', ws.versionString(), relativeFileName, asteriskOrEmpty)) ;                
            else
                set(self.FigureGH_, 'Name', sprintf('WaveSurfer %s', ws.versionString())) ;                
            end
        end    
    end
    
    methods (Access=protected)
        function updateProfileMenu_(self)
            profileNames = self.Model_.ProfileNames ;  % is sorted
            currentProfileName = self.Model_.CurrentProfileName ;
            isProfileCurrent = strcmp(currentProfileName, profileNames) ;
            for i = 1 : length(self.ProfileMenuItems) ,
                profileName = profileNames{i} ;
                set(self.ProfileMenuItems(i), ...
                    'Label', profileName, ...
                    'Checked', ws.onIff(isProfileCurrent(i))) ;
            end
        end        
    end    
    
    methods
%         function updateAfterDataAdded(self, broadcaster, eventName, propertyName, source, event)  %#ok<INUSD>
%             % Update the line graphics objects to reflect XData_, YData_
%             self.updateTraces_();
%             
%             % Change the y limits to match the data, if appropriate
%             %indicesOfAIChannelsNeedingYLimitUpdate = self.setYAxisLimitsInModelTightToDataIfAreYLimitsLockedTightToData_() ;            
%             %plotIndicesNeedingYLimitUpdate = wsModel.PlotIndexFromChannelIndex(indicesOfAIChannelsNeedingYLimitUpdate) ;
%             %self.updateYAxisLimits_(plotIndicesNeedingYLimitUpdate, indicesOfAIChannelsNeedingYLimitUpdate) ;
%         end
        
%         function clearData(self, broadcaster, eventName, propertyName, source, event)  %#ok<INUSD>
%             self.clearXDataAndYData_() ;
%             self.clearTraceData_() ;
%         end        

        function updateTraces(self, broadcaster, eventName, propertyName, source, event) %#ok<INUSD>
            self.updateTraces_() ;
        end
        
        function updateXAxisLimits(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            self.updateXAxisLimits_();
        end  % function
        
        function updateYAxisLimits(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSL>
            args = event.Args ;
            plotIndex = args{1} ;
            aiChannelIndex = args{2} ;
            self.updateYAxisLimits_(plotIndex, aiChannelIndex) ;
        end  % function
        
        function updateAreYLimitsLockedTightToData(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
            %self.updateAreYLimitsLockedTightToData_();
            %self.updateControlEnablement_();
            self.update() ;
        end  % function
        
%         function updateData(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
%             self.syncLineXDataAndYData_();
%         end  % function                
    end  % public methods block    
    
    methods (Access=protected)
%         function clearXDataAndYData_(self)
%             self.XData_ = zeros(0,1) ;
%             %acquisition = self.Model_.Acquisition ;
%             nActiveChannels = self.Model_.getNActiveAIChannels() + self.Model_.getNActiveDIChannels() ;
%             self.YData_ = zeros(0,nActiveChannels) ;
%         end
        
%         function clearTraceData_(self)
%             % Also clear the lines in the plots
%             nPlots = length(self.ScopePlots_) ;
%             for iPlot = 1:nPlots ,
%                 thisPlot = self.ScopePlots_(iPlot) ;
%                 thisPlot.setLineXDataAndYData([],[]) ;
%             end            
%         end

        function [channelIndexFromPlotIndex, cacheChannelIndexFromChannelIndex] = updateTraces_(self)
%             if isempty(self.YData_) ,
%                 % Make sure it's the right kind of empty
%                 self.clearXDataAndYData_() ;
%             end
            wsModel = self.Model_ ;
            xData = wsModel.XDataForDisplay ;
            yData = wsModel.YDataForDisplay ;
            %acq = wsModel.Acquisition ;
            isChannelInCacheFromChannelIndex = wsModel.IsInputChannelInCacheFromInputChannelIndex ;            
            cacheChannelIndexFromChannelIndex = wsModel.CacheInputChannelIndexFromInputChannelIndex ;            
            channelIndexFromPlotIndex = wsModel.ChannelIndexFromPlotIndex ;
            nPlots = length(self.ScopePlots_) ;
            for iPlot = 1:nPlots ,
                thisPlot = self.ScopePlots_(iPlot) ;
                channelIndex = channelIndexFromPlotIndex(iPlot) ;
                isChannelInCache = isChannelInCacheFromChannelIndex(channelIndex) ;
                if isChannelInCache ,
                    cacheChannelIndex = cacheChannelIndexFromChannelIndex(channelIndex) ;
                    yDataForThisChannel = yData(:,cacheChannelIndex) ;
                    thisPlot.setLineXDataAndYData(xData, yDataForThisChannel) ;
                else
                    thisPlot.setLineXDataAndYData([],[]) ;
                end
            end
        end  % function       
        
%         function updateTraces_(self)
%             % t is a scalar, the time stamp of the scan *just after* the
%             % most recent scan.  (I.e. it is one dt==1/fs into the future.
%             % Queue Doctor Who music.)
% 
% %             wsModel = self.Model_ ;
% %             scaledAnalogData = wsModel.getAIDataFromCache() ;
% %             [digitalDataAsUint, cachedDigitalSignalCount] = wsModel.getDIDataFromCache() ;
% %             t = wsModel.getTimestampsForDataInCache() ;
% %             
% %             % Get the uint8/uint16/uint32 data out of recentRawDigitalData
% %             % into a matrix of logical data, then convert it to doubles and
% %             % concat it with the recentScaledAnalogData, storing the result
% %             % in yRecent.
% %             %display = wsModel.Display ;
% %             digitalDataAsLogical = ws.logicalColumnsFromUintColumn(digitalDataAsUint, cachedDigitalSignalCount) ;
% %             y = horzcat(scaledAnalogData, digitalDataAsLogical) ;  % horzcat will convert logical to double
% %             
% %             % Figure out the downsampling ratio
% %             if isempty(self.ScopePlots_) ,
% %                 xSpanInPixels = 400 ;  % this is a reasonable value, and presumably it won't much matter
% %             else
% %                 xSpanInPixels=self.ScopePlots_(1).getAxesWidthInPixels() ;
% %             end            
% %             xSpan = wsModel.XSpan ;
% %             dt = 1/wsModel.AcquisitionSampleRate ;
% %             r = ws.ratioSubsampling(dt, xSpan, xSpanInPixels) ;
% %             
% %             % Downsample the new data
% %             %size_of_x = size(x)
% %             %size_of_y = size(y)
% %             %class_of_y = class(y)
% %             [xForPlotting, yForPlotting] = ws.minMaxDownsampleMex(t, y, r) ;            
% %             
% %             % Trim off scans that would be off the screen anyway
% %             doKeepScan = (wsModel.XOffset<=xForPlotting) ;
% %             xNew = xForPlotting(doKeepScan) ;
% %             yNew = yForPlotting(doKeepScan,:) ;
% % 
% %             % Commit the data to self
% %             self.XData_ = xNew ;
% %             self.YData_ = yNew ;
%             
%             % Update the line graphics objects to reflect XData_, YData_
%             self.updateTraces_();
%             
% %             % Change the y limits to match the data, if appropriate
% %             indicesOfAIChannelsNeedingYLimitUpdate = self.setYAxisLimitsInModelTightToDataIfAreYLimitsLockedTightToData_() ;            
% %             plotIndicesNeedingYLimitUpdate = self.Model_.PlotIndexFromChannelIndex(indicesOfAIChannelsNeedingYLimitUpdate) ;
% %             self.updateYAxisLimits_(plotIndicesNeedingYLimitUpdate, indicesOfAIChannelsNeedingYLimitUpdate) ;
%         end  % function        
        
%         function indicesOfAIChannelsNeedingYLimitUpdate = setYAxisLimitsInModelTightToDataIfAreYLimitsLockedTightToData_(self)
%             wsModel = self.Model_ ;
%             isChannelDisplayed = wsModel.IsAIChannelDisplayed ;
%             areYLimitsLockedTightToData = wsModel.AreYLimitsLockedTightToDataForAIChannel ;
%             doesAIChannelNeedYLimitUpdate = isChannelDisplayed & areYLimitsLockedTightToData ;
%             indicesOfAIChannelsNeedingYLimitUpdate = find(doesAIChannelNeedYLimitUpdate) ;
%             plotIndexFromChannelIndex = wsModel.PlotIndexFromChannelIndex ;  % for AI channels, the channel index is equal to the AI channel index
%             plotIndicesOfAIChannelsNeedingYLimitUpdate = plotIndexFromChannelIndex(indicesOfAIChannelsNeedingYLimitUpdate) ;
%             for i = 1:length(indicesOfAIChannelsNeedingYLimitUpdate) ,
%                 channelIndex = indicesOfAIChannelsNeedingYLimitUpdate(i) ;
%                 plotIndex = plotIndicesOfAIChannelsNeedingYLimitUpdate(i) ;
%                 self.setYAxisLimitsInModelTightToData_(plotIndex, channelIndex) ;
%             end               
%         end  % function        
        
        function updateAxisLabels_(self, axisForegroundColor)
            for i = 1:length(self.ScopePlots_) ,
                self.ScopePlots_(i).updateAxisLabels_(axisForegroundColor) ;
            end            
        end  % function
        
%         function updateYAxisLabel_(self, color)
%             % Updates the y axis label handle graphics to match the model state
%             % and that of the Acquisition subsystem.
%             %set(self.Axes_,'YLim',self.YOffset+[0 self.YRange]);
%             wsModel = self.Model_ ;
%             display = wsModel.Display ;
%             if display.NChannels==0 ,
%                 ylabel(self.Axes_,'Signal','Color',color,'FontSize',10,'Interpreter','none');
%             else
%                 firstChannelName = display.ChannelNames{1} ;
%                 units = display.YUnits ;
%                 if isempty(units) ,
%                     unitsString = 'pure' ;
%                 else
%                     unitsString = units ;
%                 end
%                 ylabel(self.Axes_,sprintf('%s (%s)',firstChannelName,unitsString),'Color',color,'FontSize',10,'Interpreter','none');
%             end
%         end  % function
        
        function updateXAxisLimits_(self)
            % Update the axes limits to match those in the model
            wsModel = self.Model_ ;
%             if isempty(wsModel) || ~isvalid(wsModel) ,
%                 return
%             end
            xl = wsModel.XOffset + [0 wsModel.XSpan] ;
            for i = 1:length(self.ScopePlots_) ,
                self.ScopePlots_(i).setXAxisLimits(xl) ;
            end
        end  % function        

        function updateYAxisLimits_(self, plotIndices, aiChannelIndices)
            % Update the axes limits to match those in the model
            wsModel = self.Model_ ;
            %model = wsModel.Display ;
            yLimitsFromAIChannelIndex = wsModel.YLimitsPerAIChannel ;
            for i = 1:length(plotIndices) ,
                plotIndex = plotIndices(i) ;
                aiChannelIndex = aiChannelIndices(i) ;
                yl = yLimitsFromAIChannelIndex(:,aiChannelIndex)' ;
                self.ScopePlots_(plotIndex).setYAxisLimits(yl) ;
            end
        end  % function        
        
%         function setYAxisLimitsInModelTightToData_(self, plotIndex, aiChannelIndex)            
%             % this core function does no arg checking and doesn't call
%             % .broadcast.  It just mutates the state.
%             yMinAndMax = self.Model_.plottedDataYMinAndMax(aiChannelIndex) ;
%             if any(~isfinite(yMinAndMax)) ,
%                 return
%             end
%             yCenter=mean(yMinAndMax);
%             yRadius=0.5*diff(yMinAndMax);
%             if yRadius==0 ,
%                 yRadius=0.001;
%             end
%             newYLimits = yCenter + 1.05*yRadius*[-1 +1] ;
%             self.Model_.setYLimitsForSinglePlot(plotIndex, newYLimits) ;
%         end        
    end  % protected methods block    
    
    methods
        function raiseDialogOnException(self, ~, ~, ~, ~, eventDataWithArgs)  %#ok<INUSL>
            exception = eventDataWithArgs.Args{1} ;
            ws.raiseDialogOnException(exception) ;
        end
        
        function didMaybeChangeProtocol(self, ~, ~, ~, ~, ~)
            self.updateWindowTitle_() ;
        end
    end  % public methods block   
        
    methods  % Control actuation methods, which are public
        function PlayButtonActuated(self, source, event)  %#ok<INUSD>
            %self.Model_.play();
            self.Model_.do('play') ;
        end
        
        function RecordButtonActuated(self, source, event)  %#ok<INUSD>
            %self.Model_.record();
            self.Model_.do('record') ;
        end
        
        function StopButtonActuated(self, source, event)  %#ok<INUSD>
            self.Model_.do('stop') ;
        end
        
        function OpenProtocolMenuItemActuated(self,source,event) %#ok<INUSD>
            isOKToCloseProtocol = self.checkIfOKToCloseProtocol_() ;
            if isOKToCloseProtocol ,
                if self.Model_.DoesProtocolNeedSave ,
                    % This is a hack to enable the opening of a new protocol without saving the
                    % current protocol first.  This is OK in this case b/c we know it's OK to
                    % "close" the current protocol.
                    self.Model_.pretendThatProtocolWasSaved_() ;
                end                
                initialFilePathForFilePicker = self.Model_.LastProtocolFilePath ;            
                isFileNameKnown = false ;
                absoluteFileName = ...
                    ws.WavesurferMainController.obtainAndVerifyAbsoluteFileName_(isFileNameKnown, '', 'protocol', 'load', initialFilePathForFilePicker);            
                if ~isempty(absoluteFileName)
                    %ws.Preferences.sharedPreferences().savePref('LastProtocolFilePath', absoluteFileName);
                    self.openProtocolFileGivenFileName_(absoluteFileName) ;
                end
            end
        end

        function OpenProtocolGivenFileNameFauxControlActuated(self, source, event, fileName)  %#ok<INUSL>
            self.openProtocolFileGivenFileName_(fileName) ;
        end

        function SaveProtocolGivenFileNameFauxControlActuated(self, source, event, fileName)  %#ok<INUSL>
            self.saveProtocolFileGivenFileName_(fileName) ;
        end
        
        function SaveProtocolMenuItemActuated(self,source,event) %#ok<INUSD>
            % This is the action for the File > Save menu item
            isSaveAs=false;
            self.saveOrSaveAsProtocolFile_(isSaveAs);
        end
        
        function SaveProtocolAsMenuItemActuated(self,source,event) %#ok<INUSD>
            % This is the action for the File > Save As... menu item
            isSaveAs=true;
            self.saveOrSaveAsProtocolFile_(isSaveAs);
        end

%         function LoadUserSettingsMenuItemActuated(self,source,event) %#ok<INUSD>
%             profileName = ws.getPreference('LastProfileName');       
%             initialFilePickerFolder = ws.userSettingsFileNameFromProfileName(profileName) ;
%             isFileNameKnown=false;
%             userSettingsAbsoluteFileName = ...
%                 ws.WavesurferMainController.obtainAndVerifyAbsoluteFileName_( ...
%                         isFileNameKnown, '', 'user-settings', 'load', initialFilePickerFolder);                
%             if ~isempty(userSettingsAbsoluteFileName) ,
%                 %ws.Preferences.sharedPreferences().savePref('LastUserFilePath', userSettingsAbsoluteFileName) ;
%                 self.Model_.do('openUserFileGivenFileName', userSettingsAbsoluteFileName) ;
%             end            
%         end
% 
%         function SaveUserSettingsMenuItemActuated(self,source,event) %#ok<INUSD>
%             isSaveAs = false ;
%             self.saveOrSaveAsUser_(isSaveAs) ;
%         end
%         
%         function SaveUserSettingsAsMenuItemActuated(self,source,event) %#ok<INUSD>
%             isSaveAs = true ;
%             self.saveOrSaveAsUser_(isSaveAs) ;
%         end
        
        function ExportModelAndControllerToWorkspaceMenuItemActuated(self,source,event) %#ok<INUSD>
            assignin('base', 'wsModel', self.Model_) ;
            assignin('base', 'wsController', self) ;
        end
        
        function QuitMenuItemActuated(self,source,event)
            self.closeRequested_(source, event);  % piggyback on the existing method for handling the upper-left window close button
        end
        
        % Tools menu
%         function FastProtocolsMenuItemActuated(self,source,event) %#ok<INUSD>
%             self.showAndRaiseChildFigure_('FastProtocolsController') ;
%         end        
        
        function ChannelsMenuItemActuated(self,source,event) %#ok<INUSD>
            %self.showAndRaiseChildFigure_('ChannelsController') ;
            self.Model_.IsChannelsFigureVisible = false ;  % do this to make it raise to top
            self.Model_.IsChannelsFigureVisible = true ;
        end
        
        function GeneralSettingsMenuItemActuated(self,source,event) %#ok<INUSD>
            %self.showAndRaiseChildFigure_('GeneralSettingsController') ;
            self.Model_.IsGeneralSettingsFigureVisible = false ;
            self.Model_.IsGeneralSettingsFigureVisible = true ;
        end
        
        function TriggersMenuItemActuated(self,source,event) %#ok<INUSD>
            %self.showAndRaiseChildFigure_('TriggersController') ;
            self.Model_.IsTriggersFigureVisible = false ;
            self.Model_.IsTriggersFigureVisible = true ;
        end
        
        function StimulusLibraryMenuItemActuated(self,source,event) %#ok<INUSD>
            %self.showAndRaiseChildFigure_('StimulusLibraryController') ;
            self.Model_.IsStimulusLibraryFigureVisible = false ;
            self.Model_.IsStimulusLibraryFigureVisible = true ;
        end
        
        function StimulusPreviewMenuItemActuated(self,source,event) %#ok<INUSD>
            self.Model_.IsStimulusPreviewFigureVisible = false ;
            self.Model_.IsStimulusPreviewFigureVisible = true ;
        end
        
        function UserCodeManagerMenuItemActuated(self,source,event) %#ok<INUSD>
            %self.showAndRaiseChildFigure_('UserCodeManagerController') ;
            self.Model_.IsUserCodeManagerFigureVisible = false ;
            self.Model_.IsUserCodeManagerFigureVisible = true ;
        end
        
        function ElectrodesMenuItemActuated(self,source,event) %#ok<INUSD>
            %self.showAndRaiseChildFigure_('ElectrodeManagerController') ;
            self.Model_.IsElectrodeManagerFigureVisible = false ;
            self.Model_.IsElectrodeManagerFigureVisible = true ;
        end
        
        function TestPulseMenuItemActuated(self,source,event) %#ok<INUSD>
            %self.showAndRaiseChildFigure_('TestPulserController') ;
            self.Model_.IsTestPulserFigureVisible = false ;
            self.Model_.IsTestPulserFigureVisible = true ;
        end
        
%         function DisplayMenuItemActuated(self, source, event)  %#ok<INUSD>
%             self.showAndRaiseChildFigure_('DisplayController');
%         end
        
        function YokeToScanimageMenuItemActuated(self,source,event) %#ok<INUSD>
%             wsModel = self.Model_ ;
%             if ~isempty(wsModel) ,
%                 try
%                     wsModel.do('set', 'IsYokedToScanImage', ~wsModel.IsYokedToScanImage) ;
%                 catch cause
%                     if isequal(cause.identifier, 'WavesurferModel:UnableToDeleteExistingYokeFiles') ,
%                         exception = MException('ws:cantEnableYokedMode', 'Can''t enable yoked mode: %s', cause.message) ;
%                         exception = addCause(exception, cause) ;
%                         throw(exception);
%                     else
%                         rethrow(cause);
%                     end
%                 end
%             end                        
        end  % function

        % Profile menu
        function ProfileMenuItemActuated(self, source, event, profileName)  %#ok<INUSL>
            self.Model_.do('set', 'CurrentProfileName', profileName) ;
        end        

        function NewProfileMenuItemActuated(self, source, event)  %#ok<INUSD>
            self.Model_.do('createNewProfile') ;
        end

        function DeleteProfileMenuItemActuated(self, source, event)  %#ok<INUSD>
            currentProfileName = self.Model_.CurrentProfileName ;
            if isequal(currentProfileName, 'Default') ,
               error('Sorry, you can''t delete the default profile') ;
            end
            
            choice = ws.questdlg(sprintf('Are you sure you want to delete the profile "%s"?', currentProfileName), ...
                                 'Delete Profile?', 'Delete', 'Don''t Delete', 'Don''t Delete') ;            
            if isequal(choice,'Delete') ,
                self.Model_.do('deleteCurrentProfile') ;
            end
        end

        function RenameProfileMenuItemActuated(self, source, event)  %#ok<INUSD>
            currentProfileName = self.Model_.CurrentProfileName ;            
            if isequal(currentProfileName, 'Default') ,
                error('You can''t rename the default profile') ;
            end
            self.MyRenameProfileDialogController_ = [] ;  % if not first call, this should cause the old controller to be garbage collectable
            myRenameProfileDialogModel = [] ;
            parentFigurePosition = get(self.FigureGH_,'Position') ;
            callbackFunction = @(newProfileName)(self.Model_.do('renameCurrentProfile', newProfileName)) ;
            self.MyRenameProfileDialogController_ = ...
                ws.RenameProfileDialogController(myRenameProfileDialogModel, parentFigurePosition, currentProfileName, callbackFunction) ;            
        end

        % Help menu
        function AboutMenuItemActuated(self,source,event) %#ok<INUSD>
            %self.showAndRaiseChildFigure_('ws.ui.controller.AboutWindow');
            msgbox(sprintf('This is WaveSurfer %s.',ws.versionString()),'About','modal');
        end        
        
        function FastProtocolButtonsActuated(self, source, event, fastProtocolIndex) %#ok<INUSL>
            if ~isempty(self.Model_) ,
                isOKToCloseProtocol = self.checkIfOKToCloseProtocol_() ;            
                if isOKToCloseProtocol ,                    
                    if self.Model_.DoesProtocolNeedSave ,
                        % This is a hack to enable the opening of a new protocol without saving the
                        % current protocol first.  This is OK in this case b/c we know it's OK to
                        % "close" the current protocol
                        self.Model_.pretendThatProtocolWasSaved_() ;
                    end
                    self.Model_.startLoggingWarnings() ;
                    self.Model_.openFastProtocolByIndex(fastProtocolIndex) ;
                    % % Restore the layout...
                    % layoutForAllWindows = self.Model_.LayoutForAllWindows ;
                    % monitorPositions = ws.Controller.getMonitorPositions() ;
                    % self.decodeMultiWindowLayout_(layoutForAllWindows, monitorPositions) ;
                    % % Done restoring layout
                    % Now do an auto-start, if called for by the fast protocol
                    self.Model_.performAutoStartForFastProtocolByIndex(fastProtocolIndex) ;
                    % Now throw if there were any warnings
                    warningExceptionMaybe = self.Model_.stopLoggingWarnings() ;
                    if ~isempty(warningExceptionMaybe) ,
                        warningException = warningExceptionMaybe{1} ;
                        throw(warningException) ;
                    end
                end
            end
        end  % method

        function ManageFastProtocolsButtonActuated(self, source, event)  %#ok<INUSD>
            %self.showAndRaiseChildFigure_('FastProtocols') ;
            self.Model_.IsFastProtocolsFigureVisible = true ;
        end  % method
        
        % View menu        
        function ShowGridMenuItemGHActuated(self, varargin)
            %self.Model_.toggleIsGridOn();
            self.Model_.do('toggleIsGridOn') ;
        end  % method        

        function DoShowZoomButtonsMenuItemGHActuated(self, varargin)
            self.Model_.do('toggleDoShowZoomButtons') ;
        end  % method        

        function doColorTracesMenuItemActuated(self, varargin)
            self.Model_.do('toggleDoColorTraces') ;
        end  % method        
        
        function InvertColorsMenuItemGHActuated(self, varargin)
            self.Model_.do('toggleAreColorsNormal');
        end  % method        

        function arrangementMenuItemActuated(self, varargin)
            self.PlotArrangementDialogController_ = [] ;  % if not first call, this should cause the old controller to be garbage collectable
            plotArrangementDialogModel = [] ;
            parentFigurePosition = get(self.FigureGH_,'Position') ;
            wsModel = self.Model_ ;
            %wsModel = wsModel.Display ;
            channelNames = horzcat(wsModel.AIChannelNames, wsModel.DIChannelNames) ;
            isDisplayed = horzcat(wsModel.IsAIChannelDisplayed, wsModel.IsDIChannelDisplayed) ;
            plotHeights = horzcat(wsModel.PlotHeightFromAIChannelIndex, wsModel.PlotHeightFromDIChannelIndex) ;
            rowIndexFromChannelIndex = horzcat(wsModel.RowIndexFromAIChannelIndex, wsModel.RowIndexFromDIChannelIndex) ;
            %callbackFunction = ...
            %    @(isDisplayed,plotHeights,rowIndexFromChannelIndex)(self.Model_.setPlotHeightsAndOrder(isDisplayed,plotHeights,rowIndexFromChannelIndex)) ;
            callbackFunction = ...
                @(isDisplayed,plotHeights,rowIndexFromChannelIndex)(wsModel.do('setPlotHeightsAndOrder',isDisplayed,plotHeights,rowIndexFromChannelIndex)) ;
            self.PlotArrangementDialogController_ = ...
                ws.PlotArrangementDialogController(plotArrangementDialogModel, ...
                                                   parentFigurePosition, ...
                                                   channelNames, isDisplayed, plotHeights, rowIndexFromChannelIndex, ...
                                                   callbackFunction) ;
        end  % method        

        % per-plot button methods
        function YScrollUpButtonGHActuated(self, source, event, plotIndex) %#ok<INUSL>
            %self.Model_.scrollUp(plotIndex);
            self.Model_.do('scrollUp', plotIndex) ;
        end
                
        function YScrollDownButtonGHActuated(self, source, event, plotIndex) %#ok<INUSL>
            %self.Model_.scrollDown(plotIndex);
            self.Model_.do('scrollDown', plotIndex) ;
        end
                
        function YZoomInButtonGHActuated(self, source, event, plotIndex) %#ok<INUSL>
            %self.Model_.zoomIn(plotIndex);
            self.Model_.do('zoomIn', plotIndex) ;
        end
                
        function YZoomOutButtonGHActuated(self, source, event, plotIndex) %#ok<INUSL>
            %self.Model_.zoomOut(plotIndex);
            self.Model_.do('zoomOut', plotIndex) ;
        end
                
        function SetYLimTightToDataButtonGHActuated(self, source, event, plotIndex)  %#ok<INUSL>
            self.Model_.do('setYLimitsTightToDataForSinglePlot', plotIndex) ;
%             aiChannelIndex = self.Model_.ChannelIndexWithinTypeFromPlotIndex(plotIndex) ;
%             yMinAndMax = self.Model_.plottedDataYMinAndMax(aiChannelIndex) ;
%             if any( ~isfinite(yMinAndMax) ) ,
%                 return
%             end
%             yCenter = mean(yMinAndMax) ;
%             yRadius = 0.5*diff(yMinAndMax) ;
%             if yRadius == 0 ,
%                 yRadius = 0.001 ;
%             end
%             newYLimits = yCenter + 1.05*yRadius*[-1 +1] ;
%             self.Model_.do('setYLimitsForSinglePlot', plotIndex, newYLimits) ;
        end  % method       
        
        function SetYLimTightToDataLockedButtonGHActuated(self, source, event, plotIndex) %#ok<INUSL>
            self.Model_.do('setAreYLimitsLockedTightToDataForSinglePlot', plotIndex) ;
%             wsModel = self.Model_ ;
%             channelIndex = wsModel.ChannelIndexWithinTypeFromPlotIndex(plotIndex) ;
%             currentValue = wsModel.AreYLimitsLockedTightToDataForAIChannel(channelIndex) ;
%             newValue = ~currentValue ;
%             wsModel.setAreYLimitsLockedTightToDataForSingleAIChannel_(channelIndex, newValue) ;
%             if newValue ,
%                 self.setYAxisLimitsInModelTightToData_(plotIndex, channelIndex) ;
%             end
%             self.update() ;  % update the button
        end  % method       

        function SetYLimButtonGHActuated(self, source, event, plotIndex)  %#ok<INUSL>
            self.MyYLimDialogController=[] ;  % if not first call, this should cause the old controller to be garbage collectable
            myYLimDialogModel = [] ;
            parentFigurePosition = get(self.FigureGH_,'Position') ;
            wsModel = self.Model_ ;
            %display = wsModel.Display ;            
            aiChannelIndex = wsModel.ChannelIndexWithinTypeFromPlotIndex(plotIndex) ;
            yLimits = wsModel.YLimitsPerAIChannel(:,aiChannelIndex)' ;
            yUnits = wsModel.AIChannelUnits{aiChannelIndex} ;
            %callbackFunction = @(newYLimits)(model.setYLimitsForSingleAnalogChannel(aiChannelIndex, newYLimits)) ;
            callbackFunction = @(newYLimits)(wsModel.do('setYLimitsForSinglePlot', plotIndex, newYLimits)) ;
            self.MyYLimDialogController = ...
                ws.YLimDialogController(myYLimDialogModel, parentFigurePosition, yLimits, yUnits, callbackFunction) ;
        end  % method                
    end  % Control actuation methods block
    
    methods  % these are convenience methods that mimic the effects of actuating controls, but have shorter names
        function play(self)
            self.PlayButtonActuated() ;
        end
        
        function record(self)
            self.RecordButtonActuated() ;
        end
        
        function stop(self)
            self.StopButtonActuated() ;
        end
        
        function quit(self)
            delete(self) ;
        end  % function
    end  % convenience methods block

    methods
        function setAreUpdatesEnabledForAllFigures(self, newValue)
            % This exists so that the ElectrodeManagerController just
            % diable all the figure updates while it does certain things, 
            % to eliminate a lot of redundant figure updates.  This is a
            % hack.
            self.GeneralSettingsController.setAreUpdatesEnabledForFigure(newValue) ;
            self.ChannelsController.setAreUpdatesEnabledForFigure(newValue) ;
            self.StimulusLibraryController.setAreUpdatesEnabledForFigure(newValue) ;
            self.StimulusPreviewController.setAreUpdatesEnabledForFigure(newValue) ;
            self.TriggersController.setAreUpdatesEnabledForFigure(newValue) ;
            self.UserCodeManagerController.setAreUpdatesEnabledForFigure(newValue) ;
            self.ElectrodeManagerController.setAreUpdatesEnabledForFigure(newValue) ;
            self.TestPulserController.setAreUpdatesEnabledForFigure(newValue) ;
            self.FastProtocolsController.setAreUpdatesEnabledForFigure(newValue) ;
        end
        
        function layoutForAllWindowsRequested(self, varargin)
            self.copyAllFigurePositionsToModel_() ;
        end        
        
        function layoutAllWindows(self, varargin)
            monitorPositions = ws.getMonitorPositions() ;
            self.syncFigurePositionFromModel(monitorPositions) ;            
            self.GeneralSettingsController.syncFigurePositionFromModel(monitorPositions) ;            
            self.ChannelsController.syncFigurePositionFromModel(monitorPositions) ;            
            self.StimulusLibraryController.syncFigurePositionFromModel(monitorPositions) ;            
            self.StimulusPreviewController.syncFigurePositionFromModel(monitorPositions) ;            
            self.TriggersController.syncFigurePositionFromModel(monitorPositions) ;            
            self.UserCodeManagerController.syncFigurePositionFromModel(monitorPositions) ;            
            self.ElectrodeManagerController.syncFigurePositionFromModel(monitorPositions) ;            
            self.TestPulserController.syncFigurePositionFromModel(monitorPositions) ;                        
        end        
    end  % public methods block             
    
    methods  (Access=protected)
        function openProtocolFileGivenFileName_(self, fileName)
            % Actually loads the named config file.  fileName should be an
            % file name referring to a file that is known to be
            % present, at least as of a few milliseconds ago.
            if ws.isFileNameAbsolute(fileName) ,
                absoluteFileName = fileName ;
            else
                absoluteFileName = fullfile(pwd(),fileName) ;
            end                        
            
%             % Can't use self.Model_.do() method, because if only warnings,
%             % still want to set the layout afterwards...  (I think we
%             *can* do this now.)
%             self.Model_.startLoggingWarnings() ;
%             self.Model_.openProtocolFileGivenFileName(absoluteFileName) ;
% %             % Restore the layout...  (This now happens when the model
% %             does a broadcast of LayoutAllWindows in
% %             openProtocolFileGivenFileName(), which results in
% %             self.layoutAllWindows() getting called.
% %             layoutForAllWindows = self.Model_.LayoutForAllWindows ;
% %             monitorPositions = ws.Controller.getMonitorPositions() ;
% %             self.decodeMultiWindowLayout_(layoutForAllWindows, monitorPositions) ;
%             % Now throw if there were any warnings
%             warningExceptionMaybe = self.Model_.stopLoggingWarnings() ;
%             if ~isempty(warningExceptionMaybe) ,
%                 warningException = warningExceptionMaybe{1} ;
%                 throw(warningException) ;
%             end
            
            self.Model_.do('openProtocolFileGivenFileName', absoluteFileName) ;
        end  % function
        
        function saveOrSaveAsProtocolFile_(self, isSaveAs)
            % Figure out the file name, or leave empty for save as
            if isSaveAs ,
                isFileNameKnown=false;
                fileName='';  % not used
                if self.Model_.HasUserSpecifiedProtocolFileName ,
                    fileChooserInitialFileName = self.Model_.AbsoluteProtocolFileName;
                else                    
                    %profileName = self.Model_.CurrentProfileName ;
                    fileChooserInitialFileName = self.Model_.LastProtocolFilePath ;
                end
            else
                % this is a plain-old save
                if self.Model_.HasUserSpecifiedProtocolFileName ,
                    isFileNameKnown = true ;
                    fileName = self.Model_.AbsoluteProtocolFileName ;
                    fileChooserInitialFileName = '' ;  % not used
                else
                    isFileNameKnown = false ;
                    fileName = '' ;  % not used
                    fileChooserInitialFileName = self.Model_.AbsoluteProtocolFileName ;
                end
            end

            % Prompt the user for a file name, if necessary, and save
            % the file
            absoluteFileName = ...
                ws.WavesurferMainController.obtainAndVerifyAbsoluteFileName_( ...
                    isFileNameKnown, ...
                    fileName, ...
                    'protocol', ...
                    'save', ...
                    fileChooserInitialFileName);
            
            if ~isempty(absoluteFileName) ,
                self.saveProtocolFileGivenFileName_(absoluteFileName) ;
            end            
        end  % method        
        
        function saveProtocolFileGivenFileName_(self, fileName)
            % Actually saves the named protocol file.
            self.Model_.do('saveProtocolFileGivenFileName', fileName) ;
        end  % function
        
%         function saveOrSaveAsUser_(self, isSaveAs)
%             % Figure out the file name, or leave empty for save as
%             profileName = self.Model_.CurrentProfileName ;
%             lastFileName = ws.getProfilePreference(profileName, 'LastUserFilePath');
%             if isSaveAs ,
%                 isFileNameKnown=false;
%                 fileName='';  % not used
%                 if self.Model_.HasUserSpecifiedUserSettingsFileName ,
%                     fileChooserInitialFileName = self.Model_.AbsoluteUserSettingsFileName;
%                 else                    
%                     fileChooserInitialFileName = ws.getPreference('LastUserFilePath');
%                 end
%             else
%                 % this is a plain-old save
%                 if self.Model_.HasUserSpecifiedUserSettingsFileName ,
%                     % this means that the user has already specified a
%                     % config file name
%                     isFileNameKnown=true;
%                     %fileName=ws.getPreference('LastProtocolFilePath');
%                     fileName=self.Model_.AbsoluteUserSettingsFileName;
%                     fileChooserInitialFileName = '';  % not used
%                 else
%                     % This means that the user has not yet specified a
%                     % config file name
%                     isFileNameKnown=false;
%                     fileName='';  % not used
%                     if isempty(lastFileName)
%                         fileChooserInitialFileName = fullfile(pwd(), 'unnamed.wsu');
%                     else
%                         fileChooserInitialFileName = lastFileName;
%                     end
%                 end
%             end
% 
%             % Prompt the user for a file name, if necessary, and save
%             % the file
%             %self.saveUserSettings(isFileNameKnown, fileName, fileChooserInitialFileName);
%             absoluteFileName = ...
%                 ws.WavesurferMainController.obtainAndVerifyAbsoluteFileName_( ...
%                     isFileNameKnown, ...
%                     fileName, ...
%                     'user-settings', ...
%                     'save', ...
%                     fileChooserInitialFileName);
% 
%             if ~isempty(absoluteFileName) ,
%                 %self.Model_.saveUserFileGivenAbsoluteFileName(absoluteFileName) ;
%                 self.Model_.do('saveUserFileGivenFileName', absoluteFileName) ;
%             end
%         end  % method                

        function copyAllFigurePositionsToModel_(self)
            % Save the layouts of all windows to the model state
            
            % Add the main window layout
            self.setFigurePositionInModel() ;
            
            % Add the child window layouts            
            self.GeneralSettingsController.setFigurePositionInModel() ;
            self.ChannelsController.setFigurePositionInModel() ;
            self.TriggersController.setFigurePositionInModel() ;
            self.StimulusLibraryController.setFigurePositionInModel() ;
            self.StimulusPreviewController.setFigurePositionInModel() ;
            self.FastProtocolsController.setFigurePositionInModel() ;
            self.UserCodeManagerController.setFigurePositionInModel() ;
            self.TestPulserController.setFigurePositionInModel() ;
            self.ElectrodeManagerController.setFigurePositionInModel() ;
        end  % function
        
%         function decodeMultiWindowLayout_(self, multiWindowLayout, monitorPositions)
%             % load the layout of the main window
%             self.extractAndDecodeLayoutFromMultipleWindowLayout_(multiWindowLayout, monitorPositions);
%                         
%             % Go through the list of possible controller types, see if any
%             % have layout information.  For each, take the appropriate
%             % action to make the current layout match that in
%             % multiWindowLayout.
%             controllerNames = { 'GeneralSettingsController' ...
%                                 'ChannelsController' ...
%                                 'TriggersController' ...
%                                 'StimulusLibraryController' ...
%                                 'FastProtocolsController' ...
%                                 'UserCodeManagerController' ...
%                                 'TestPulserController' ...
%                                 'ElectrodeManagerController'} ;
%             for i=1:length(controllerNames) ,
%                 controllerName = controllerNames{i} ;
%                 if isprop(self, controllerName) ,  
%                     % This should always be true now
%                     controller = self.(controllerName) ;
%                     %windowTypeName=self.ControllerSpecifications_.(controllerName).controlName;
%                     controllerClassName = ['ws.' controllerName] ;
%                     %layoutVarName = self.getLayoutVariableNameForClass(controllerClassName);
%                     layoutMaybe = ws.singleWindowLayoutMaybeFromMultiWindowLayout(multiWindowLayout, controllerClassName) ;
%                     
%                     % If the controller does not exist, check whether the configuration indicates
%                     % that it should visible.  If so, create it, otherwise it can remain empty until
%                     % needed.
%                     if isempty(controller) ,
%                         % The controller does not exist.  Check if it needs
%                         % to.
%                         if ~isempty(layoutMaybe) ,
%                             % The controller does not exist, but there's layout info in the multiWindowLayout.  So we
%                             % create the controller and then decode the
%                             % layout.
%                             controller = self.createChildControllerIfNonexistant_(controllerName) ;
%                             %controller.extractAndDecodeLayoutFromMultipleWindowLayout_(multiWindowLayout, monitorPositions);                            
%                             layout = layoutMaybe{1} ;
%                             controller.decodeWindowLayout(layout, monitorPositions);
%                         else
%                             % The controller doesn't exist, but there's no
%                             % layout info for it, so all is well.
%                         end                        
%                     else
%                         % The controller does exist.
%                         if ~isempty(layoutMaybe) ,
%                             % The controller exists, and there's layout
%                             % info for it, so lay it out
%                             %controller.extractAndDecodeLayoutFromMultipleWindowLayout_(multiWindowLayout, monitorPositions);                            
%                             layout = layoutMaybe{1} ;
%                             controller.decodeWindowLayout(layout, monitorPositions);
%                         else
%                             % The controller exists, but there's no layout
%                             % info for it in the multiWindowLayout.  This
%                             % means that the controller did not exist when
%                             % the layout was saved.  Maybe we should delete
%                             % the controller, but for now we just make it
%                             % invisible.
%                             figureObject=controller.Figure;
%                             figureObject.hide();
%                         end                        
%                     end
%                 end
%             end    
%         end  % function       
        
        function isOKToCloseProtocol = checkIfOKToCloseProtocol_(self)
            % If acquisition or test pulsing is happening, ignore the close window request
            model = self.Model_ ;
            isIdle = model.isIdleSensuLato() ;
            if ~isIdle ,
                isOKToCloseProtocol = false ;
                return
            end
            
            % Check to see if the protocol has been saved
            if model.DoesProtocolNeedSave ,
                absoluteProtocolFileName = model.AbsoluteProtocolFileName ;
                protocolFileName = ws.baseFileNameFromPath(absoluteProtocolFileName) ;
                
                choice = ws.questdlg(sprintf('Do you want to save changes to %s?', protocolFileName), ...
                                     'Protocol Has Unsaved Changes', ...
                                     'Save', 'Don''t Save', 'Cancel', 'Save');

                if isequal(choice, 'Save') ,
                    isSaveAs = false ;
                    self.saveOrSaveAsProtocolFile_(isSaveAs) ;
                    isOKToCloseProtocol = ~model.DoesProtocolNeedSave ;  % Check that the file got saved successfully
                elseif isequal(choice, 'Don''t Save') ,
                    isOKToCloseProtocol = true ;
                else
                    % Must have clicked on Cancel
                    isOKToCloseProtocol = false ;                    
                end               
            else
                % protocol doesn't need to be saved, so OK to quit
                isOKToCloseProtocol = true ;
            end
        end  % function
                
%         function showAndRaiseChildFigure_(self, className, varargin)
%             [controller, didCreate] = self.createChildControllerIfNonexistant_(className,varargin{:}) ;
%             % is a Controller
%             if didCreate ,
%                 % no need to update
%             else
%                 controller.update();  % figure might be out-of-date
%             end
%             controller.show() ;
%             controller.raise() ;
%         end  % function
        
%         function [controller, didCreate] = createChildControllerIfNonexistant_(self, figureName, varargin)
%             controllerClassName = sprintf('%sController', figureName) ;
%             if isempty(self.(controllerClassName)) ,
%                 fullControllerClassName=['ws.' controllerClassName];
%                 if isequal(fullControllerClassName, 'ws.GeneralSettingsController') ,
%                     controller = feval(fullControllerClassName, self.Model_, self.getPositionInPixels_() ) ;
%                 elseif isequal(fullControllerClassName, 'ws.ElectrodeManagerController') ,
%                     controller = feval(fullControllerClassName, self.Model_, self) ;
%                 elseif isequal(fullControllerClassName, 'ws.StimulusLibraryController') ,
%                     controller = feval(fullControllerClassName, self.Model_, self.FigureGH_) ;
%                 else
%                     controller = feval(fullControllerClassName, self.Model_) ;
%                 end
%                 self.ChildControllers_{end+1}=controller;
%                 self.(controllerClassName)=controller;
%                 didCreate = true ;
%             else
%                 controller = self.(controllerClassName);
%                 didCreate = false ;
%             end
%         end  % function
    end  % protected methods
    
    methods 
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  
        
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end        
    end  % protected methods
    
    methods (Static = true, Access = protected)
        function absoluteFileName = obtainAndVerifyAbsoluteFileName_(isFileNameKnown, fileName, fileTypeString, loadOrSave, fileChooserInitialFileName)
            % A function that tries to obtain a valid absolute file name
            % for the caller. If isFileNameKnown is true, the function
            % will try to use fileName, possibly adding a leading
            % path and a following cfgOrUsr if it lacks these things. If
            % isFileNameKnown is false, a file chooser dialog is raised.
            % Regardless of how the absolute file name was arrived at, the
            % absolute file name is then verified, and an exception thrown
            % if the named file is missing.  loadOrSave indicates whether
            % the file is going to be saved to or loaded from, which
            % affects what file chooser is used and how the resulting
            % absolute file name is verified.
            
            % Determine the file descriptor string for use in file choose
            % dialog titles
            if isequal(fileTypeString,'protocol') ,
                fileExtension = 'wsp' ;
                humanReadableTitleCaseFileTypeString = 'Protocol' ;
            elseif isequal(fileTypeString,'user-settings') ,
                fileExtension = 'wsu' ;
                humanReadableTitleCaseFileTypeString = 'User Settings' ;
            else
                % this should never happen, but in case it does...
                fileExtension = 'wsp' ;
                humanReadableTitleCaseFileTypeString = 'Protocol' ;
            end
            
            % Obtain an absolute file name
            %isFileNameKnown=~isempty(fileNameIfKnown);
            if isFileNameKnown ,
                % If caller provided a file name, so make sure it's
                % absolute
                %fileName=fileNameIfKnown;
                [p, f, e] = fileparts(fileName);
                if isempty(p)
                    p = pwd();
                end
                if isempty(e)
                    e = fileTypeString;
                end
                absoluteFileName = fullfile(p, [f e]);
            else                
                if isequal(loadOrSave,'load')
                    [f,p] = ...
                        uigetfile({sprintf('*.%s', fileExtension), sprintf('WaveSurfer %s Files',humanReadableTitleCaseFileTypeString) ; ...
                                   '*.*',  'All Files (*.*)'}, ...
                                  sprintf('Open %s...', humanReadableTitleCaseFileTypeString), ...
                                  fileChooserInitialFileName);
                elseif isequal(loadOrSave,'save')
                    [f,p] = ...
                        uiputfile({sprintf('*.%s', fileExtension), sprintf('WaveSurfer %s Files',humanReadableTitleCaseFileTypeString)  ; ...
                                   '*.*',  'All Files (*.*)'}, ...
                                  sprintf('Save %s As...', humanReadableTitleCaseFileTypeString), ...
                                  fileChooserInitialFileName);
                else
                    % this should never happen, but if it does...
                    absoluteFileName='';
                    return                    
                end
                if isnumeric(f) ,
                    absoluteFileName='';
                    return
                end
                absoluteFileName = fullfile(p, f);
            end

            % Verify the obtained absolute file name
            if isequal(loadOrSave,'load') ,
                assert(exist(absoluteFileName, 'file') == 2, ...
                       'The specified file does not exist.')
            elseif isequal(loadOrSave,'save') ,
                absoluteDirName=fileparts(absoluteFileName);
                assert(exist(absoluteDirName, 'dir') == 7, ...
                       'Parent directory of specified file does not exist.')
            else
                % this should really never happen, but if I am all wrong in my head...
                assert(false,'Internal error: Adam is a dummy');
            end
        end  % function        
    end  % static, protected methods block      

    methods (Access=protected)
        function position = getPositionInPixels_(self)
            figureGH = self.FigureGH_ ;
            % Get our position
            originalUnits=get(figureGH,'units');
            set(figureGH,'units','pixels');
            position = get(figureGH,'position') ;
            set(figureGH,'units',originalUnits);            
        end
    end
    
%     methods (Access=protected)
%         function extractAndDecodeLayoutFromMultipleWindowLayout_(self, multiWindowLayout, monitorPositions)
%             % Find a layout that applies to whatever subclass of controller
%             % self happens to be (if any), and use it to position self's
%             % figure's window.            
%             if isscalar(multiWindowLayout) && isstruct(multiWindowLayout) ,
%                 layoutMaybe = ws.singleWindowLayoutMaybeFromMultiWindowLayout(multiWindowLayout, class(self)) ;
%                 if ~isempty(layoutMaybe) ,
%                     layoutForThisClass = layoutMaybe{1} ;
%                     self.decodeWindowLayout(layoutForThisClass, monitorPositions);
%                 end
%             end
%         end  % function        
%     end
    
    methods (Access=protected)
        function closeRequested_(self, source, event)  %#ok<INUSD>
            % This is target method for pressing the close button in the
            % upper-right of the window.
            % TODO: Put in some checks here so that user doesn't quit
            % by being slightly clumsy.
            
            % See if we should stay put despite the request to close
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model) ,
                isOKToQuit = true ;
            else
                %shouldStayPut = ~model.isIdleSensuLato() ;
                isOKToQuit = self.checkIfOKToCloseProtocol_() ;
            end
            
            % delete ourselves, if called for
            if isOKToQuit ,
                delete(self) ;
            else
                % do nothing
            end
        end  % function        
    end
    
    methods
        function updateVisibility(self, varargin)  %#ok<INUSD>
            % ignore, for the main figure is always visible
        end                
    end    
    
end  % classdef
