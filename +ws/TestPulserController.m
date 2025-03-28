classdef TestPulserController < ws.Controller
    properties  (SetAccess=protected)
        StartStopButton
        ElectrodePopupMenuLabelText
        ElectrodePopupMenu
        AmplitudeEditLabelText
        AmplitudeEdit
        AmplitudeEditUnitsText
        DurationEditLabelText
        DurationEdit
        DurationEditUnitsText
        SubtractBaselineCheckbox
        AutoYCheckbox
        AutoYRepeatingCheckbox
        VCToggle
        CCToggle
        TraceAxes
        XAxisLabel
        YAxisLabel
        TraceLine
        UpdateRateTextLabelText
        UpdateRateText
        UpdateRateTextUnitsText
        GainLabelTexts
        GainTexts
        GainUnitsTexts
        ZoomInButton
        ZoomOutButton
        ScrollUpButton
        ScrollDownButton
        YLimitsButton
    end  % properties
    
    properties (Access=protected)
        %IsMinimumSizeSet_ = false
        YLimits_ = [-10 +10]   % the current y limits
    end
    
    properties
        MyYLimDialogController=[]
    end
    
    methods
        function self = TestPulserController(wsModel)
            self = self@ws.Controller(wsModel);
            
            % Create the widgets (except figure, created in superclass
            % constructor)
            set(self.FigureGH_,'Tag','TestPulserFigure', ...
                              'Units','pixels', ...
                              'Resize','on', ...
                              'Name','Test Pulse', ...
                              'NumberTitle','off', ...
                              'Menubar','none', ...
                              'Toolbar','none', ...
                              'Visible','off');
            
            % Create the controls that will persist throughout the lifetime of the window              
            self.createFixedControls_();
            
            % Set the initial figure position
            self.setInitialFigurePosition_();

            % Sync with the model
            self.update();            
            
            % Subscribe to model events
            if ~isempty(wsModel) ,
                wsModel.subscribeMe(self,'Update','','update');
                wsModel.subscribeMe(self,'UpdateTestPulser','','update') ;                
                wsModel.subscribeMe(self,'DidSetState','','updateControlProperties') ;
                wsModel.subscribeMe(self,'UpdateElectrodeManager','','update') ;
                wsModel.subscribeMe(self,'TPUpdateTrace','','updateTrace') ;
                wsModel.subscribeMe(self,'TPDidSetIsInputChannelActive','','update') ;
                wsModel.subscribeMe(self, 'DidSetSingleFigureVisibility', '', 'updateVisibility') ;
            end
            
            % Make visible
            %set(self.FigureGH_, 'Visible', 'on') ;
        end  % constructor
        
        function delete(self)
            if ~isempty(self.MyYLimDialogController) && ishandle(self.MyYLimDialogController) ,
                delete(self.MyYLimDialogController) ;
            end
            delete@ws.Controller(self) ;
        end  % function
        
        function updateTrace(self,varargin)
            % If there are issues with either the host or the model, just return
            %fprintf('updateTrace!\n');
            if ~self.AreUpdatesEnabled ,
                return
            end
            if isempty(self.Model_) || ~isvalid(self.Model_) ,
                return
            end
            wsModel = self.Model_ ;
            %ephys = wsModel.Ephys ;
            %testPulser = ephys.TestPulser ;
            
            %fprintf('here -1\n');
            % draw the trace line
            %monitor=self.Model_.Monitor;
            %t=self.Model_.Time;  % s            
            %set(self.TraceLine,'YData',monitor);
            
            % If y range hasn't been set yet, and Y Auto is engaged, set
            % the y range.
            if wsModel.isTestPulsing() && wsModel.IsAutoYInTestPulseView ,   %&& testPulser.AreYLimitsForRunDetermined ,
                yLimitsInModel = wsModel.TestPulseYLimits ;
                yLimits=self.YLimits_;
                %if all(isfinite(yLimits)) && ~isequal(yLimits,yLimitsInModel) ,
                if ~isequal(yLimits,yLimitsInModel) ,
                    self.YLimits_ = yLimitsInModel;  % causes axes ylim to be changed
                    set(self.TraceAxes,'YLim',yLimitsInModel);
                    %self.layout();  % Need to update the whole layout, b/c '^10^-3' might have appeared above the y axis
                    %self.updateControlProperties();  % Now do a near-full update, which will call updateTrace(), but this block will be
                    %                                 % skipped b/c isequal(self.YLimits,yLimitsNominal)
                    %return  % no need to do anything else
                end
            end
            
            % Update the graphics objects to match the model and/or host
            % Extra spaces b/c right-align cuts of last char a bit
            updateRate = wsModel.getUpdateRateInTestPulseView() ;
            set(self.UpdateRateText,'String',ws.fif(isnan(updateRate),'? ',sprintf('%0.1f ',updateRate)));
            %fprintf('here\n');
            %rawGainOrResistance=testPulser.GainOrResistancePerElectrode;
            %rawGainOrResistanceUnits = testPulser.GainOrResistanceUnitsPerElectrode ;
            %[gainOrResistanceUnits,gainOrResistance] = rawGainOrResistanceUnits.convertToEngineering(rawGainOrResistance) ;
            [gainOrResistance, gainOrResistanceUnits] = wsModel.getGainOrResistancePerTestPulseElectrodeWithNiceUnits() ;
            %fprintf('here 2\n');
            nElectrodes=length(gainOrResistance);
            for j=1:nElectrodes ,
                gainOrResistanceThis = gainOrResistance(j) ;
                if isnan(gainOrResistanceThis) ,
                    set(self.GainTexts(j),'String','? ');
                    set(self.GainUnitsTexts(j),'String','');
                else
                    set(self.GainTexts(j),'String',sprintf('%0.1f ',gainOrResistanceThis));
                    gainOrResistanceUnitsThis = gainOrResistanceUnits{j} ;
                    set(self.GainUnitsTexts(j),'String',gainOrResistanceUnitsThis);
                end
            end
            %fprintf('here 3\n');
            % draw the trace line
            %ephys = testPulser.Parent ;
            monitor = wsModel.getTestPulseMonitorTrace() ;
            %t=testPulser.Time;  % s            
            if ~isempty(monitor) ,
                set(self.TraceLine, 'YData', monitor) ;
            end
            drawnow('nocallbacks') ;
        end  % method
        
%         function updateIsReady(self,varargin)            
%             if isempty(testPulser) || testPulser.IsReady ,
%                 set(self.FigureGH_,'pointer','arrow');
%             else
%                 % Change cursor to hourglass
%                 set(self.FigureGH_,'pointer','watch');
%             end
%             drawnow('update');
%         end        
    end  % methods
    
    methods (Access=protected)
        function updateImplementation_(self,varargin)
            % Syncs self with model, making no prior assumptions about what
            % might have changed or not changed in the model.
            %fprintf('update!\n');
            self.updateControlsInExistance_();
            self.updateControlPropertiesImplementation_();
            self.layout_();
            self.updateVisibility() ;
            % update readiness, without the drawnow()
            wsModel = self.Model_ ;
            if isempty(wsModel) ,
                set(self.FigureGH_,'pointer','arrow');
            else                
                %ephys = wsModel.Ephys ;
                if wsModel.IsReady ,
                    set(self.FigureGH_,'pointer','arrow');
                else
                    % Change cursor to hourglass
                    set(self.FigureGH_,'pointer','watch');
                end
            end            
        end
        
        function updateControlPropertiesImplementation_(self,varargin)
            %fprintf('\n\nTestPulserFigure.updateControlPropertiesImplementation:\n');
            %dbstack
            % If there are issues with the model, just return
            if isempty(self.Model_) || ~isvalid(self.Model_) ,
                return
            end
                        
%             fprintf('TestPulserFigure.updateControlPropertiesImplementation_:\n');
%             dbstack
%             fprintf('\n');            
            
            % Get some handles we'll need
            wsModel = self.Model_ ;
            %ephys = wsModel.Ephys ;
            %testPulser = ephys.TestPulser ;
            %electrodeManager=ephys.ElectrodeManager;
            %electrode = ephys.TestPulseElectrode ;
            tpElectrodeIndex = wsModel.TestPulseElectrodeIndex ;
            
            % Define some useful booleans
            isElectrodeManual = isempty(tpElectrodeIndex) || isequal(wsModel.getTestPulseElectrodeProperty('Type'), 'Manual') ; 
            isElectrodeManagerInControlOfSoftpanelModeAndGains=wsModel.IsInControlOfSoftpanelModeAndGains;
            isWavesurferIdle=isequal(wsModel.State,'idle');
            %isWavesurferTestPulsing=(wavesurferModel.State==ws.ApplicationState.TestPulsing);
            isWavesurferTestPulsing = wsModel.isTestPulsing() ;
            isWavesurferIdleOrTestPulsing = isWavesurferIdle||isWavesurferTestPulsing ;
            isAutoY = wsModel.IsAutoYInTestPulseView ;
            isAutoYRepeating = wsModel.IsAutoYRepeatingInTestPulseView ;
            
            % Update the graphics objects to match the model and/or host
            isStartStopButtonEnabled = wsModel.isTestPulsingEnabled() ;
%                 isWavesurferIdleOrTestPulsing && ...
%                 ~isempty(tpElectrodeIndex) && ...
%                 wsModel.areTestPulseElectrodeChannelsValid() && ...
%                 wsModel.areAllMonitorAndCommandChannelNamesDistinct() && ...
%                 ~wsModel.areTestPulseElectrodeMonitorAndCommandChannelsOnDiffrentDevices() ; 
            set(self.StartStopButton, ...
                'String',ws.fif(isWavesurferTestPulsing,'Stop','Start'), ...
                'Enable',ws.onIff(isStartStopButtonEnabled));
            
            electrodeNames = wsModel.getAllElectrodeNames ;
            electrodeName = wsModel.getTestPulseElectrodeProperty('Name') ;
            ws.setPopupMenuItemsAndSelectionBang(self.ElectrodePopupMenu, ...
                                                 electrodeNames, ...
                                                 electrodeName);
            set(self.ElectrodePopupMenu, ...
                'Enable',ws.onIff(isWavesurferIdleOrTestPulsing));
                                         
            set(self.SubtractBaselineCheckbox,'Value',wsModel.DoSubtractBaselineInTestPulseView, ...
                                              'Enable',ws.onIff(isWavesurferIdleOrTestPulsing));
            set(self.AutoYCheckbox,'Value',isAutoY, ...
                                   'Enable',ws.onIff(isWavesurferIdleOrTestPulsing));
            set(self.AutoYRepeatingCheckbox,'Value',isAutoYRepeating, ...
                                            'Enable',ws.onIff(isWavesurferIdleOrTestPulsing&&isAutoY));
                   
            % Have to disable these togglebuttons during test pulsing,
            % because switching an electrode's mode during test pulsing can
            % fail: in the target mode, the electrode may not be
            % test-pulsable (e.g. the monitor and command channels haven't
            % been set for the target mode), or the monitor and command
            % channels for the set of active electrode may not be mutually
            % exclusive.  That makes computing whether the target mode is
            % valid complicated.  We punt by just disabling the
            % mode-switching toggle buttons during test pulsing.  The user
            % can always stop test pulsing, switch the mode, then start
            % again (if that's a valid action in the target mode).
            % Hopefully this limitation is not too annoying for users.
            mode = wsModel.getTestPulseElectrodeProperty('Mode') ;
            set(self.VCToggle, 'Enable', ws.onIff(isWavesurferIdle && ...
                                                  ~isempty(tpElectrodeIndex) && ...
                                                  (isElectrodeManual||isElectrodeManagerInControlOfSoftpanelModeAndGains)), ...
                               'Value', ~isempty(tpElectrodeIndex)&&isequal(mode,'vc'));
            set(self.CCToggle, 'Enable', ws.onIff(isWavesurferIdle && ...
                                                  ~isempty(tpElectrodeIndex)&& ...
                                                  (isElectrodeManual||isElectrodeManagerInControlOfSoftpanelModeAndGains)), ...
                               'Value', ~isempty(tpElectrodeIndex) && ...
                                        (isequal(mode,'cc')||isequal(mode,'i_equals_zero')));
                        
            amplitude = wsModel.getTestPulseElectrodeProperty('TestPulseAmplitude') ;                      
            set(self.AmplitudeEdit,'String',sprintf('%g',amplitude), ...
                                   'Enable',ws.onIff(isWavesurferIdleOrTestPulsing&&~isempty(tpElectrodeIndex)));
            set(self.AmplitudeEditUnitsText,'String',wsModel.getTestPulseElectrodeCommandUnits, ...
                                            'Enable',ws.onIff(isWavesurferIdleOrTestPulsing&&~isempty(tpElectrodeIndex)));
            set(self.DurationEdit, 'String', sprintf('%g', 1e3*wsModel.TestPulseDuration), ...
                                   'Enable', ws.onIff(isWavesurferIdleOrTestPulsing)) ;
            set(self.DurationEditUnitsText,'Enable',ws.onIff(isWavesurferIdleOrTestPulsing));
            nElectrodes=length(self.GainLabelTexts);
            isVCPerTestPulseElectrode = wsModel.getIsVCPerTestPulseElectrode() ;
            isCCPerTestPulseElectrode = wsModel.getIsCCPerTestPulseElectrode() ;
            tpElectrodeNames = wsModel.getTestPulseElectrodeNames() ;
            for i=1:nElectrodes ,
                if isCCPerTestPulseElectrode(i) || isVCPerTestPulseElectrode(i) ,
                    set(self.GainLabelTexts(i), 'String', sprintf('%s Resistance: ', tpElectrodeNames{i})) ;
                else
                    set(self.GainLabelTexts(i), 'String', sprintf('%s Gain: ', tpElectrodeNames{i})) ;
                end
                %set(self.GainUnitsTexts(i),'String',string(testPulser.GainOrResistanceUnitsPerElectrode(i)));
                set(self.GainUnitsTexts(i),'String','');
            end
            sweepDuration = 2*wsModel.TestPulseDuration ;
            set(self.TraceAxes,'XLim',1000*[0 sweepDuration]);
            self.YLimits_ = wsModel.TestPulseYLimits ;
            set(self.TraceAxes,'YLim',self.YLimits_);
            set(self.YAxisLabel,'String',sprintf('Monitor (%s)',wsModel.getTestPulseElectrodeMonitorUnits()));
            t = wsModel.getTestPulseMonitorTraceTimeline() ;
            %t=testPulser.Time;
            set(self.TraceLine,'XData',1000*t,'YData',nan(size(t)));  % convert s to ms
            set(self.ZoomInButton,'Enable',ws.onIff(~isAutoY));
            set(self.ZoomOutButton,'Enable',ws.onIff(~isAutoY));
            set(self.ScrollUpButton,'Enable',ws.onIff(~isAutoY));
            set(self.ScrollDownButton,'Enable',ws.onIff(~isAutoY));
            set(self.YLimitsButton,'Enable',ws.onIff(~isAutoY));
            self.updateTrace();
        end  % method        
                
    end  % protected methods block
    
    methods (Access=protected)
        function createFixedControls_(self)
            
            % Start/stop button
            self.StartStopButton= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','pushbutton', ...
                          'String','Start', ...
                          'Callback',@(src,evt)(self.controlActuated('StartStopButton',src,evt)));
                          
            % Electrode popup menu
            self.ElectrodePopupMenuLabelText= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Electrode: ');
            self.ElectrodePopupMenu= ...
                ws.uipopupmenu('Parent',self.FigureGH_, ...
                          'String',{'Electrode 1' 'Electrode 2'}, ...
                          'Value',1, ...
                          'Callback',@(src,evt)(self.controlActuated('ElectrodePopupMenu',src,evt)));
                      
            % Baseline subtraction checkbox
            self.SubtractBaselineCheckbox= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                        'Style','checkbox', ...
                        'String','Sub Base', ...
                        'Callback',@(src,evt)(self.controlActuated('SubtractBaselineCheckbox',src,evt)));

            % Auto Y checkbox
            self.AutoYCheckbox= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                        'Style','checkbox', ...
                        'String','Auto Y', ...
                        'Callback',@(src,evt)(self.controlActuated('AutoYCheckbox',src,evt)));

            % Auto Y repeat checkbox
            self.AutoYRepeatingCheckbox= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                        'Style','checkbox', ...
                        'String','Repeating', ...
                        'Callback',@(src,evt)(self.controlActuated('AutoYRepeatingCheckbox',src,evt)));
                    
            % VC/CC toggle buttons
            self.VCToggle= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','radiobutton', ...
                          'String','VC', ...
                          'Callback',@(src,evt)(self.controlActuated('VCToggle',src,evt)));
            self.CCToggle= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','radiobutton', ...
                          'String','CC', ...
                          'Callback',@(src,evt)(self.controlActuated('CCToggle',src,evt)));
                      
            % Amplitude edit
            self.AmplitudeEditLabelText= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Amplitude: ');
            self.AmplitudeEdit= ...
                ws.uiedit('Parent',self.FigureGH_, ...
                          'HorizontalAlignment','right', ...
                          'Callback',@(src,evt)(self.controlActuated('AmplitudeEdit',src,evt)));
            self.AmplitudeEditUnitsText= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                        'Style','text', ...
                        'HorizontalAlignment','left', ...
                        'String','mV');

            % Duration edit
            self.DurationEditLabelText= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...
                        'String','Duration: ');
            self.DurationEdit= ...
                ws.uiedit('Parent',self.FigureGH_, ...
                          'HorizontalAlignment','right', ...
                          'Callback',@(src,evt)(self.controlActuated('DurationEdit',src,evt)));
            self.DurationEditUnitsText= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                        'Style','text', ...
                        'HorizontalAlignment','left', ...
                        'String','ms');

            % Trace axes        
            self.TraceAxes= ...
                axes('Parent',self.FigureGH_, ...
                     'Units','pixels', ...
                     'box','on', ...
                     'XLim',[0 20], ...
                     'YLim',self.YLimits_, ...
                     'FontSize', 9, ...
                     'Visible','on');
            
            % Axis labels
            self.XAxisLabel= ...
                xlabel(self.TraceAxes,'Time (ms)','FontSize',9,'Interpreter','none');
            self.YAxisLabel= ...
                ylabel(self.TraceAxes,'Monitor (pA)','FontSize',9,'Interpreter','none');
            
            % Trace line
            self.TraceLine= ...
                line('Parent',self.TraceAxes, ...
                     'XData',[], ...
                     'YData',[]);
            
            % Update rate text
            self.UpdateRateTextLabelText= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                        'Style','text', ...
                        'HorizontalAlignment','right', ...                        
                        'String','Update Rate: ');
            self.UpdateRateText= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','text', ...
                          'HorizontalAlignment','right', ...
                          'String','50');
            self.UpdateRateTextUnitsText= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                        'Style','text', ...
                        'String','Hz');
                    
            % Y axis control buttons
            self.ZoomInButton= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','pushbutton', ...
                          'String','+', ...
                          'Callback',@(src,evt)(self.controlActuated('ZoomInButton',src,evt)));
            self.ZoomOutButton= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','pushbutton', ...
                          'String','-', ...
                          'Callback',@(src,evt)(self.controlActuated('ZoomOutButton',src,evt)));

            wavesurferDirName=fileparts(which('wavesurfer'));
            iconFileName = fullfile(wavesurferDirName, '+ws', 'icons', 'up_arrow.png');
            cdata = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            self.ScrollUpButton= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','pushbutton', ...
                          'CData',cdata, ...
                          'Callback',@(src,evt)(self.controlActuated('ScrollUpButton',src,evt)));
%                           'String','^', ...

            iconFileName = fullfile(wavesurferDirName, '+ws', 'icons', 'down_arrow.png');
            cdata = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            self.ScrollDownButton= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','pushbutton', ...
                          'CData',cdata, ...
                          'Callback',@(src,evt)(self.controlActuated('ScrollDownButton',src,evt)));
            
            iconFileName = fullfile(wavesurferDirName, '+ws', 'icons', 'y_manual_set.png');
            cdata = ws.readPNGWithTransparencyForUIControlImage(iconFileName) ;
            self.YLimitsButton= ...
                ws.uicontrol('Parent',self.FigureGH_, ...
                          'Style','pushbutton', ...
                          'CData',cdata, ...
                          'Callback',@(src,evt)(self.controlActuated('YLimitsButton',src,evt)));
        end  % function
        
        function setInitialFigurePosition_(self)
            % set the initial figure size and position, then layout the
            % figure like normal

            % Get the screen size
            originalScreenUnits=get(0,'Units');
            set(0,'Units','pixels');
            screenPosition=get(0,'ScreenSize');
            set(0,'Units',originalScreenUnits);            
            screenSize=screenPosition(3:4);
            
            % Position the figure in the middle of the screen
            initialSize=[570 500];
            figureOffset=(screenSize-initialSize)/2;
            figurePosition=[figureOffset initialSize];
            set(self.FigureGH_,'Position',figurePosition);
            
            % do the widget layout within the figure
            %self.layout();
        end  % function
        
        function layout_(self)
            % lays out the figure widgets, given the current figure size
            %fprintf('Inside layout()...\n');

            % The "layout" is basically the figure rectangle, but
            % taking into account the fact that the figure can be hmade
            % arbitrarily small, but the layout has a miniumum width and
            % height.  Further, the layout rectangle *top* left corner is
            % the same point as the figure top left corner.
            
            % The layout contains the following things, in order from top
            % to bottom: 
            %
            %     top space
            %     top stuff (the widgets at the top of the figure)
            %     top-stuff-traces-plot-interspace
            %     the traces plot
            %     bottom-stuff-traces-plot-interspace
            %     bottom stuff (the update rate and gain widgets)
            %     bottom space.  
            %
            % Each is a rectangle, and they are laid out edge-to-edge
            % vertically.  All but the traces plot have a fixed height, and
            % the traces plot fills the leftover height in the layout.  The
            % top edge of the top space is fixed to the top edge of the
            % layout, and the bottom of the bottom space is fixed to the
            % bottom edge of the layout.

            % minimum layout dimensions
            minimumLayoutWidth=570;  % If the figure gets small, we lay it out as if it was bigger
            minimumLayoutHeight=500;  
            
            % Heights of the stacked rectangles that comprise the layout
            topSpaceHeight = 0 ;
            % we don't know the height of the top stuff yet, but it does
            % not depend on the figure/layout size
            topStuffToTracesPlotInterspaceHeight = 2 ;
            % traces plot height is set to fill leftover space in the
            % layout
            tracesPlotToBottomStuffInterspaceHeight=10;
            % we don't know the height of the bottom stuff yet, but it does
            % not depend on the figure/layout size            
            bottomSpaceHeight = 2 ;
            
            % General widget sizes
            editWidth=40;
            editHeight=20;
            textHeight=18;  % for 8 pt font
            
            % Top stuff layout parameters
            widthFromTopStuffLeftToStartStopButton=22;
            heightFromTopStuffTopToStartStopButton=20;
            startStopButtonWidth=96;
            startStopButtonHeight=28;
            checkboxBankXOffset = 145 ;
            checkboxBankWidth = 80 ;
            widthFromCheckboxBankToElectrodeBank = 16 ;
            heightFromFigureTopToSubBaseCheckbox = 6 ; 
            heightBetweenCheckboxes = -1 ;
            widthOfAutoYRepeatingIndent = 14 ;
            electrodePopupMenuLabelTextX=checkboxBankXOffset + checkboxBankWidth + widthFromCheckboxBankToElectrodeBank ;
            heightFromTopStuffStopToPopup=10;
            heightBetweenAmplitudeAndDuration=26;
            electrodePopupWidth=100;
            widthFromPopupsRightToAmplitudeLeft=20;
            clampToggleWidth = 40 ;
            clampToggleHeight = 18 ;
            electrodePopupToClampToggleAreaHeight=8;
            interClampToggleWidth = 2 ;
            
            % Traces plot layout parameters                      
            widthFromLayoutLeftToPlot=0;
            widthFromLayoutRightToPlot=0;            
            traceAxesLeftPad=5;
            traceAxesRightPad=5;
            tickLength=5;  % in pixels
            fromAxesToYRangeButtonsWidth=6;
            yRangeButtonSize=20;  % those buttons are square
            spaceBetweenScrollButtons=5;
            spaceBetweenZoomButtons=5;
            
            % Bottom stuff layout parameters
            widthFromLayoutLeftToUpdateRateLeft=20;  
            widthFromLayoutRightToGainRight=20;
            updateRateTextWidth=36;  % wide enough to accomodate '100.0'
            gainTextWidth=60;
            interGainSpaceHeight=0;
            gainUnitsTextWidth=40;  % approximately right for 'GOhm' in 9 pt text.  Don't want layout to change even if units change
            %gainLabelTextWidth=200;  % Approximate width if the string is 'Electrode 1 Resistance: ' [sic]
            gainLabelTextWidth=160;  % Approximate width if the string is 'Electrode 1 Resistance: ' [sic]
            %fromSubBaseToAutoYSpaceWidth=16;
            
            % Get the dimensions of the figure, determine the size and
            % position of the layout rectangle
            figurePosition=get(self.FigureGH_,'Position');
            figureWidth = figurePosition(3) ;
            figureHeight = figurePosition(4) ;
            % When the figure gets small, we layout the widgets as if it were
            % bigger.  The size we're "pretending" the figure is we call the
            % "layout" size
            layoutWidth=max(figureWidth,minimumLayoutWidth) ;  
            layoutHeight=max(figureHeight,minimumLayoutHeight) ;
            layoutYOffset = figureHeight - layoutHeight ;
              % All widget coords have to ultimately be given in the figure
              % coordinate system.  This is the y position of the layout
              % lower left corner, in the figure coordinate system.
            layoutTopYOffset = layoutYOffset + layoutHeight ;  
              
            % Can compute the height of the bottom stuff pretty easily, so
            % do that now
            nElectrodes=length(self.GainTexts);
            nBottomRows=max(nElectrodes,1);  % Even when no electrodes, there's still the update rate text
            bottomStuffHeight = nBottomRows*textHeight + (nBottomRows-1)*interGainSpaceHeight ;

            
              
            %
            %
            % Position thangs
            %
            %
            
            %
            % The start/stop button "bank"
            %
            
            % The start/stop button
            topStuffTopYOffset = layoutTopYOffset - topSpaceHeight ;
            startStopButtonX=widthFromTopStuffLeftToStartStopButton;
            startStopButtonY=topStuffTopYOffset-heightFromTopStuffTopToStartStopButton-startStopButtonHeight;
            set(self.StartStopButton, ...
                'Position',[startStopButtonX startStopButtonY ...
                            startStopButtonWidth startStopButtonHeight]);
                  
            %
            % The checkbox "bank"
            %
                        
            % Baseline subtraction checkbox
            [subtractBaselineCheckboxTextWidth,subtractBaselineCheckboxTextHeight]=ws.getExtent(self.SubtractBaselineCheckbox);
            subtractBaselineCheckboxWidth=subtractBaselineCheckboxTextWidth+16;  % Add some width to accomodate the checkbox itself
            subtractBaselineCheckboxHeight=subtractBaselineCheckboxTextHeight;
            subtractBaselineCheckboxY = topStuffTopYOffset - heightFromFigureTopToSubBaseCheckbox - subtractBaselineCheckboxHeight ;
            subtractBaselineCheckboxX = checkboxBankXOffset ;
            set(self.SubtractBaselineCheckbox, ...
                'Position',[subtractBaselineCheckboxX subtractBaselineCheckboxY ...
                            subtractBaselineCheckboxWidth subtractBaselineCheckboxHeight]);
            
            % Auto Y checkbox
            [autoYCheckboxTextWidth,autoYCheckboxTextHeight]=ws.getExtent(self.AutoYCheckbox);
            autoYCheckboxWidth=autoYCheckboxTextWidth+16;  % Add some width to accomodate the checkbox itself
            autoYCheckboxHeight=autoYCheckboxTextHeight;
            autoYCheckboxY = subtractBaselineCheckboxY - heightBetweenCheckboxes - autoYCheckboxHeight ;
            autoYCheckboxX = checkboxBankXOffset ;
            set(self.AutoYCheckbox, ...
                'Position',[autoYCheckboxX autoYCheckboxY ...
                            autoYCheckboxWidth autoYCheckboxHeight]);
                        
            % Auto Y Locked checkbox
            [autoYRepeatingCheckboxTextWidth,autoYRepeatingCheckboxTextHeight] = ws.getExtent(self.AutoYRepeatingCheckbox) ;
            autoYRepeatingCheckboxWidth = autoYRepeatingCheckboxTextWidth + 16 ;  % Add some width to accomodate the checkbox itself
            autoYRepeatingCheckboxHeight = autoYRepeatingCheckboxTextHeight ;
            autoYRepeatingCheckboxY = autoYCheckboxY - heightBetweenCheckboxes - autoYRepeatingCheckboxHeight ;
            autoYRepeatingCheckboxX = checkboxBankXOffset + widthOfAutoYRepeatingIndent ;
            set(self.AutoYRepeatingCheckbox, ...
                'Position',[autoYRepeatingCheckboxX autoYRepeatingCheckboxY ...
                            autoYRepeatingCheckboxWidth autoYRepeatingCheckboxHeight]);

            % 
            %  The electrode bank
            %
            
            % The command channel popupmenu and its label                                           
            electrodePopupMenuLabelExtent=get(self.ElectrodePopupMenuLabelText,'Extent');
            electrodePopupMenuLabelWidth=electrodePopupMenuLabelExtent(3);
            electrodePopupMenuLabelHeight=electrodePopupMenuLabelExtent(4);
            electrodePopupMenuPosition=get(self.ElectrodePopupMenu,'Position');
            electrodePopupMenuHeight=electrodePopupMenuPosition(4);
            electrodePopupMenuY= ...
                topStuffTopYOffset-heightFromTopStuffStopToPopup-electrodePopupMenuHeight;
            electrodePopupMenuLabelTextY=...
                electrodePopupMenuY+electrodePopupMenuHeight/2-electrodePopupMenuLabelHeight/2-4;  % shim
            electrodePopupMenuX=electrodePopupMenuLabelTextX+electrodePopupMenuLabelWidth+1;
            set(self.ElectrodePopupMenuLabelText, ...
                'Position',[electrodePopupMenuLabelTextX electrodePopupMenuLabelTextY ...
                            electrodePopupMenuLabelWidth electrodePopupMenuLabelHeight]);
            set(self.ElectrodePopupMenu, ...
                'Position',[electrodePopupMenuX electrodePopupMenuY ...
                            electrodePopupWidth electrodePopupMenuHeight]);
                        
            % VC, CC toggle buttons
            clampToggleAreaHeight=clampToggleHeight;
            clampToggleAreaWidth=clampToggleWidth+interClampToggleWidth+clampToggleWidth;

            clampToggleAreaCenterX=electrodePopupMenuX+electrodePopupWidth/2;
            %clampToggleAreaRightX=electrodePopupMenuX+electrodePopupWidth;
            %clampToggleAreaCenterX=clampToggleAreaRightX-clampToggleAreaWidth/2;
            
            clampToggleAreaTopY=electrodePopupMenuY-electrodePopupToClampToggleAreaHeight;
            clampToggleAreaX=clampToggleAreaCenterX-clampToggleAreaWidth/2;
            %clampToggleAreaX = electrodePopupMenuX ;             
            clampToggleAreaY=clampToggleAreaTopY-clampToggleAreaHeight;
            
            % VC toggle button
            vcToggleX=clampToggleAreaX;
            vcToggleY=clampToggleAreaY;
            set(self.VCToggle, ...
                'Position',[vcToggleX vcToggleY ...
                            clampToggleWidth clampToggleHeight]);
                        
            % CC toggle button
            ccToggleX=vcToggleX+interClampToggleWidth+clampToggleWidth;
            ccToggleY=clampToggleAreaY;
            set(self.CCToggle, ...
                'Position',[ccToggleX ccToggleY ...
                            clampToggleWidth clampToggleHeight]);

                        
            % 
            %  The amplitude and duration bank
            %            
                        
            % The amplitude edit and its label
            [amplitudeEditLabelTextWidth,amplitudeEditLabelTextHeight]=ws.getExtent(self.AmplitudeEditLabelText);
            amplitudeEditLabelTextX=electrodePopupMenuX+electrodePopupWidth+widthFromPopupsRightToAmplitudeLeft;
            amplitudeEditLabelTextY=electrodePopupMenuLabelTextY;
            set(self.AmplitudeEditLabelText, ...
                'Position',[amplitudeEditLabelTextX amplitudeEditLabelTextY ...
                            amplitudeEditLabelTextWidth amplitudeEditLabelTextHeight]);
            amplitudeStuffMiddleY=electrodePopupMenuLabelTextY+amplitudeEditLabelTextHeight/2;
            amplitudeEditX=amplitudeEditLabelTextX+amplitudeEditLabelTextWidth+1;  % shim
            amplitudeEditY=amplitudeStuffMiddleY-editHeight/2+2;
            set(self.AmplitudeEdit, ...
                'Position',[amplitudeEditX amplitudeEditY ...
                            editWidth editHeight]);
            %[~,amplitudeEditUnitsTextHeight]=ws.getExtent(self.AmplitudeEditUnitsText);
            amplitudeEditUnitsTextFauxWidth=30;
            amplitudeEditUnitsTextX=amplitudeEditX+editWidth+1;  % shim
            amplitudeEditUnitsTextY=amplitudeEditLabelTextY-1;
            set(self.AmplitudeEditUnitsText, ...
                'Position',[amplitudeEditUnitsTextX amplitudeEditUnitsTextY ...
                            amplitudeEditUnitsTextFauxWidth textHeight]);
            
            % The duration edit and its label
            [~,durationEditLabelTextHeight]=ws.getExtent(self.DurationEditLabelText);
            durationEditLabelTextX=amplitudeEditLabelTextX;
            durationEditLabelTextY=electrodePopupMenuLabelTextY-heightBetweenAmplitudeAndDuration;
            set(self.DurationEditLabelText, ...
                'Position',[durationEditLabelTextX durationEditLabelTextY ...
                            amplitudeEditLabelTextWidth amplitudeEditLabelTextHeight]);
            durationStuffMiddleY=durationEditLabelTextY+durationEditLabelTextHeight/2;
            durationEditX=amplitudeEditX;  % shim
            durationEditY=durationStuffMiddleY-editHeight/2+2;
            set(self.DurationEdit, ...
                'Position',[durationEditX durationEditY ...
                            editWidth editHeight]);
            [durationEditUnitsTextWidth,durationEditUnitsTextHeight]=ws.getExtent(self.DurationEditUnitsText);
            durationEditUnitsTextX=amplitudeEditUnitsTextX;
            durationEditUnitsTextY=durationEditLabelTextY-1;
            set(self.DurationEditUnitsText, ...
                'Position',[durationEditUnitsTextX durationEditUnitsTextY ...
                            durationEditUnitsTextWidth durationEditUnitsTextHeight]);
            
            % All the stuff above is at a fixed y offset from the top of
            % the layout.  So now we can compute the height of the top
            % stuff rectangle.
            topStuffYOffset = min([autoYRepeatingCheckboxY vcToggleY durationEditY]) ;
            topStuffHeight = topStuffTopYOffset - topStuffYOffset ;
                        
                        
            %
            % The trace plot
            %
            traceAxesAreaX=widthFromLayoutLeftToPlot;
            traceAxesAreaWidth= ...
                layoutWidth-widthFromLayoutLeftToPlot-widthFromLayoutRightToPlot-yRangeButtonSize-fromAxesToYRangeButtonsWidth;
            traceAxesAreaHeight = layoutHeight-topSpaceHeight-topStuffToTracesPlotInterspaceHeight-topStuffHeight-tracesPlotToBottomStuffInterspaceHeight-bottomStuffHeight ;
            traceAxesAreaTopY = layoutTopYOffset - topSpaceHeight - topStuffHeight - topStuffToTracesPlotInterspaceHeight ;
            traceAxesAreaY = traceAxesAreaTopY - traceAxesAreaHeight ;
            set(self.TraceAxes,'OuterPosition',[traceAxesAreaX traceAxesAreaY traceAxesAreaWidth traceAxesAreaHeight]);
            tightInset=get(self.TraceAxes,'TightInset');
            traceAxesX=traceAxesAreaX+tightInset(1)+traceAxesLeftPad;
            traceAxesY=traceAxesAreaY+tightInset(2);
            traceAxesWidth=traceAxesAreaWidth-tightInset(1)-tightInset(3)-traceAxesLeftPad-traceAxesRightPad;
            traceAxesHeight=traceAxesAreaHeight-tightInset(2)-tightInset(4);
            set(self.TraceAxes,'Position',[traceAxesX traceAxesY traceAxesWidth traceAxesHeight]);
            
            % set the axes tick length to keep a constant number of pels
            traceAxesSize=max([traceAxesWidth traceAxesHeight]);
            tickLengthRelative=tickLength/traceAxesSize;
            set(self.TraceAxes,'TickLength',tickLengthRelative*[1 1]);
            
            % the zoom buttons
            yRangeButtonsX=traceAxesX+traceAxesWidth+fromAxesToYRangeButtonsWidth;
            zoomOutButtonX=yRangeButtonsX;
            zoomOutButtonY=traceAxesY;  % want bottom-aligned with axes
            set(self.ZoomOutButton, ...
                'Position',[zoomOutButtonX zoomOutButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            zoomInButtonX=yRangeButtonsX;
            zoomInButtonY=zoomOutButtonY+yRangeButtonSize+spaceBetweenZoomButtons;  % want just above other zoom button
            set(self.ZoomInButton, ...
                'Position',[zoomInButtonX zoomInButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            
            % the y limits button
            yLimitsButtonX=yRangeButtonsX;
            yLimitsButtonY=zoomInButtonY+yRangeButtonSize+spaceBetweenZoomButtons;  % want above other zoom buttons
            set(self.YLimitsButton, ...
                'Position',[yLimitsButtonX yLimitsButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            
            % the scroll buttons
            scrollUpButtonX=yRangeButtonsX;
            scrollUpButtonY=traceAxesY+traceAxesHeight-yRangeButtonSize;  % want top-aligned with axes
            set(self.ScrollUpButton, ...
                'Position',[scrollUpButtonX scrollUpButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
            scrollDownButtonX=yRangeButtonsX;
            scrollDownButtonY=scrollUpButtonY-yRangeButtonSize-spaceBetweenScrollButtons;  % want under scroll up button
            set(self.ScrollDownButton, ...
                'Position',[scrollDownButtonX scrollDownButtonY ...
                            yRangeButtonSize yRangeButtonSize]);
                        
            %
            % The stuff at the bottom of the figure
            %
                         
            bottomStuffYOffset = layoutYOffset + bottomSpaceHeight ;
            % The update rate and its label
            [updateRateTextLabelTextWidth,updateRateTextLabelTextHeight]=ws.getExtent(self.UpdateRateTextLabelText);
            updateRateTextLabelTextX=widthFromLayoutLeftToUpdateRateLeft;
            updateRateTextLabelTextY=bottomStuffYOffset;
            set(self.UpdateRateTextLabelText, ...
                'Position',[updateRateTextLabelTextX updateRateTextLabelTextY ...
                            updateRateTextLabelTextWidth updateRateTextLabelTextHeight]);
            updateRateTextX=updateRateTextLabelTextX+updateRateTextLabelTextWidth+1;  % shim
            updateRateTextY=bottomStuffYOffset;
            set(self.UpdateRateText, ...
                'Position',[updateRateTextX updateRateTextY ...
                            updateRateTextWidth updateRateTextLabelTextHeight]);
            [updateRateUnitsTextWidth,updateRateUnitsTextHeight]=ws.getExtent(self.UpdateRateTextUnitsText);
            updateRateUnitsTextX=updateRateTextX+updateRateTextWidth+1;  % shim
            updateRateUnitsTextY=bottomStuffYOffset;
            set(self.UpdateRateTextUnitsText, ...
                'Position',[updateRateUnitsTextX updateRateUnitsTextY ...
                            updateRateUnitsTextWidth updateRateUnitsTextHeight]);
            
            % The gains and associated labels
            for j=1:nElectrodes ,
                nRowsBelow=nElectrodes-j;
                thisRowY = bottomStuffYOffset + nRowsBelow*(textHeight+interGainSpaceHeight) ;
                
                gainUnitsTextX=layoutWidth-widthFromLayoutRightToGainRight-gainUnitsTextWidth;
                gainUnitsTextY=thisRowY;
                set(self.GainUnitsTexts(j), ...
                    'Position',[gainUnitsTextX gainUnitsTextY ...
                                gainUnitsTextWidth textHeight]);
                gainTextX=gainUnitsTextX-gainTextWidth-1;  % shim
                gainTextY=thisRowY;
                set(self.GainTexts(j), ...
                    'Position',[gainTextX gainTextY ...
                                gainTextWidth textHeight]);
                GainLabelTextX=gainTextX-gainLabelTextWidth-1;  % shim
                GainLabelTextY=thisRowY;
                set(self.GainLabelTexts(j), ...
                    'Position',[GainLabelTextX GainLabelTextY ...
                                gainLabelTextWidth textHeight]);
            end
            
                        
                        
            % Do some hacking to set the minimum figure size
            % Is seems to work OK to only set this after the figure is made
            % visible...
%             if ~self.IsMinimumSizeSet_ && isequal(get(self.FigureGH_,'Visible'),'on') ,
%                 %fprintf('Setting the minimum size...\n');
%                 originalWarningState=ws.warningState('MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
%                 warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
%                 fpj=get(handle(self.FigureGH_),'JavaFrame');
%                 warning(originalWarningState,'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');                
%                 if verLessThan('matlab', '8.4') ,
%                     jw=fpj.fHG1Client.getWindow();
%                 else
%                     jw=fpj.fHG2Client.getWindow();
%                 end
%                 if ~isempty(jw)
%                     jw.setMinimumSize(java.awt.Dimension(minimumFigureWidth, ...
%                                                          minimumFigureHeight));  % Note that this setting does not stick if you set Visible to 'off'
%                                                                                  % and then on again.  Which kinda sucks...
%                     self.IsMinimumSizeSet_=true;                                 
%                 end
%             end
        end

        function updateControlsInExistance_(self)
            %fprintf('updateControlsInExistance_!\n');
            % Makes sure the controls that exist match what controls _should_
            % exist, given the current model state.

            % Determine the number of electrodes right now
            wsModel = self.Model_ ;
            if isempty(wsModel) || ~isvalid(wsModel) ,
                nElectrodes=0;
            else
                %testPulser = self.Model_.Ephys.TestPulser ;
                %nElectrodes=testPulser.NElectrodes;
                nElectrodes = wsModel.TestPulseElectrodesCount ;
            end
            %nElectrodes=4  % FOR DEBUGGING ONLY
            
            % Determine how many electrodes there were the last time the
            % controls in existance was updated
            nElectrodesPreviously=length(self.GainTexts);
            
            nNewElectrodes=nElectrodes-nElectrodesPreviously;
            if nNewElectrodes>0 ,
                for i=1:nNewElectrodes ,
                    j=nElectrodesPreviously+i;  % index of new row in "table"
                    % Gain text
                    self.GainLabelTexts(j)= ...
                        ws.uicontrol('Parent',self.FigureGH_, ...
                                  'Style','text', ...
                                  'HorizontalAlignment','right', ...
                                  'String','Gain: ');
                    self.GainTexts(j)= ...
                        ws.uicontrol('Parent',self.FigureGH_, ...
                                  'Style','text', ...
                                  'HorizontalAlignment','right', ...
                                  'String','100');
                    self.GainUnitsTexts(j)= ...
                        ws.uicontrol('Parent',self.FigureGH_, ...
                                  'Style','text', ...
                                  'HorizontalAlignment','left', ...
                                  'String','MOhm');
                end
            elseif nNewElectrodes<0 ,
                % Delete the excess HG objects
                ws.deleteIfValidHGHandle(self.GainLabelTexts(nElectrodes+1:end));
                ws.deleteIfValidHGHandle(self.GainTexts(nElectrodes+1:end));
                ws.deleteIfValidHGHandle(self.GainUnitsTexts(nElectrodes+1:end));

                % Delete the excess HG handles
                self.GainLabelTexts(nElectrodes+1:end)=[];
                self.GainTexts(nElectrodes+1:end)=[];
                self.GainUnitsTexts(nElectrodes+1:end)=[];
            end            
        end
        
%         function controlActuated(self,src,evt) %#ok<INUSD>
%             % This makes it so that we don't have all these implicit
%             % references to the controller in the closures attached to HG
%             % object callbacks.  It also means we can just do nothing if
%             % the Controller is invalid, instead of erroring.
%             %fprintf('view.controlActuated!\n');
%             if isempty(self.Controller) || ~isvalid(self.Controller) ,
%                 return
%             end
%             self.Controller.controlActuated(src);
%         end  % function
    end  % protected methods
        
%     methods
%         function closeRequested(self,source,event)
%             % This makes it so that we don't have all these implicit
%             % references to the controller in the closures attached to HG
%             % object callbacks.  It also means we can just do nothing if
%             % the Controller is invalid, instead of erroring.
%             if isempty(self.Controller) || ~isvalid(self.Controller) ,
%                 delete(self);
%             else
%                 self.Controller.windowCloseRequested(source,event);
%             end
%         end  % function        
%     end  % methods

%     methods (Access = protected)
%         % Have to subclass this b/c there are SetAccess=protected properties.
%         % (Would be nice to have a less-hacky solution for this...)
%         function setHGTagsToPropertyNames_(self)
%             % For each object property, if it's an HG object, set the tag
%             % based on the property name, and set other HG object properties that can be
%             % set systematically.
%             mc=metaclass(self);
%             propertyNames={mc.PropertyList.Name};
%             for i=1:length(propertyNames) ,
%                 propertyName=propertyNames{i};
%                 propertyThing=self.(propertyName);
%                 if ~isempty(propertyThing) && all(ishghandle(propertyThing)) && ~(isscalar(propertyThing) && isequal(get(propertyThing,'Type'),'figure')) ,
%                     % Set Tag
%                     set(propertyThing,'Tag',propertyName);                    
%                 end
%             end
%         end  % function        
%     end  % protected methods block
    
    methods            
%         function self=TestPulserController(wavesurferController,wavesurferModel)
%             % Call the superclass constructor
%             %testPulser=wavesurferModel.Ephys.TestPulser;
%             self = self@ws.Controller(wavesurferController,wavesurferModel);  
% 
%             % Create the figure, store a pointer to it
%             fig = ws.TestPulserFigure(wavesurferModel,self) ;
%             self.Figure_ = fig ;            
%         end
        
        function exceptionMaybe = controlActuated(self, controlName, source, event, varargin)
            try
                wsModel = self.Model_ ;
                %testPulser = wsModel.Ephys.TestPulser;
                if strcmp(controlName, 'StartStopButton') ,
                    self.StartStopButtonActuated() ;
                    exceptionMaybe = {} ;
                else
                    % If the model is running, stop it (have to disable broadcast so we don't lose the new setting)
                    wasRunningOnEntry = wsModel.isTestPulsing() ;
                    if wasRunningOnEntry ,
                        self.AreUpdatesEnabled = false ;
                        wsModel.stopTestPulsing() ;
                    end
                    
                    % Act on the control
                    exceptionMaybe = controlActuated@ws.Controller(self, controlName, source, event, varargin{:}) ;
                    % if exceptionMaybe is nonempty, a dialog has already
                    % been shown to the user.

                    % Start running again, if needed, and if there was no
                    % exception.
                    if wasRunningOnEntry ,
                        self.AreUpdatesEnabled = true ;
                        self.updateControlProperties() ;
                        if isempty(exceptionMaybe) ,
                            wsModel.startTestPulsing() ;
                        end
                    end
                end
            catch exception
                ws.raiseDialogOnException(exception) ;
                exceptionMaybe = { exception } ;
            end
        end  % function
        
        function StartStopButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model_.do('toggleIsTestPulsing');
        end
        
        function ElectrodePopupMenuActuated(self, source, event, varargin)  %#ok<INUSD>
            wsModel = self.Model_ ;
            electrodeNames = wsModel.getAllElectrodeNames() ;
            menuItem = ws.getPopupMenuSelection(self.ElectrodePopupMenu, ...
                                                electrodeNames);
            if isempty(menuItem) ,  % indicates invalid selection
                self.update();                
            else
                electrodeName=menuItem;
                wsModel.do('setTestPulseElectrodeByName', electrodeName) ;
            end
        end
        
        function SubtractBaselineCheckboxActuated(self, source, event, varargin)  %#ok<INUSD>
            newValue = logical(get(self.SubtractBaselineCheckbox,'Value')) ;
            self.Model_.do('set', 'DoSubtractBaselineInTestPulseView', newValue) ;
        end
        
        function AutoYCheckboxActuated(self, source, event, varargin)  %#ok<INUSD>
            newValue = logical(get(self.AutoYCheckbox,'Value')) ;
            self.Model_.do('set', 'IsAutoYInTestPulseView', newValue) ;
        end
        
        function AutoYRepeatingCheckboxActuated(self, source, event, varargin)  %#ok<INUSD>
            newValue = logical(get(self.AutoYRepeatingCheckbox,'Value')) ;
            self.Model_.do('set', 'IsAutoYRepeatingInTestPulseView', newValue) ;
        end
        
        function AmplitudeEditActuated(self, source, event, varargin)  %#ok<INUSD>
            value = get(self.AmplitudeEdit,'String') ;
            %ephys = self.Model_.Ephys ;
            self.Model_.do('setTestPulseElectrodeProperty', 'TestPulseAmplitude', value) ;
        end
        
        function DurationEditActuated(self, source, event, varargin)  %#ok<INUSD>
            newValueInMsAsString = get(self.DurationEdit,'String') ;
            newValue = 1e-3 * str2double(newValueInMsAsString) ;
            self.Model_.do('set', 'TestPulseDuration', newValue) ;
        end
        
        function ZoomInButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model_.do('zoomInTestPulseView') ;
        end
        
        function ZoomOutButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model_.do('zoomOutTestPulseView') ;
        end
        
        function YLimitsButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.MyYLimDialogController = [] ;  % if not first call, this should cause the old controller to be garbage collectable
            
            wsModel = self.Model_ ;
            
            setModelYLimitsCallback = @(newYLimits)(wsModel.do('set', 'TestPulseYLimits', newYLimits)) ;
%             function setModelYLimits(newYLimits)
%                 wsModel.do('set', 'TestPulseYLimits', newYLimits) ;
%             end
            
            self.MyYLimDialogController = ...
                ws.YLimDialogController([], ...
                                    get(self.FigureGH_,'Position'), ...
                                    wsModel.TestPulseYLimits, ...
                                    wsModel.getTestPulseElectrodeMonitorUnits(), ...
                                    setModelYLimitsCallback) ;
        end
        
        function ScrollUpButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model_.do('scrollUpTestPulseView') ;
        end
        
        function ScrollDownButtonActuated(self, source, event, varargin)  %#ok<INUSD>
            self.Model_.do('scrollDownTestPulseView') ;
        end
        
        function VCToggleActuated(self, source, event, varargin)  %#ok<INUSD>
            % update the other toggle
            set(self.CCToggle, 'Value', 0) ;  % Want this to be fast
            drawnow('update');

            % Change the setting
            %ephys = self.Model_.Ephys ;
            self.Model_.do('setTestPulseElectrodeProperty', 'Mode', 'vc') ;
        end  % function
        
        function CCToggleActuated(self, source, event, varargin)  %#ok<INUSD>
            % update the other toggle
            set(self.VCToggle, 'Value', 0) ;  % Want this to be fast
            drawnow('update');
            
            % Change the setting    
            %ephys = self.Model_.Ephys ;
            self.Model_.do('setTestPulseElectrodeProperty', 'Mode', 'cc') ;
        end  % function
    end  % methods    

    methods (Access=protected)
        function closeRequested_(self, source, event)  %#ok<INUSD>
            wsModel = self.Model_ ;
            
            if isempty(wsModel) || ~isvalid(wsModel) ,
                shouldStayPut = false ;
            else
                shouldStayPut = ~wsModel.isIdleSensuLato() ;
            end
           
            if shouldStayPut ,
                % Do nothing
            else
                %self.hide() ;
                wsModel.IsTestPulserFigureVisible = false ;
            end
        end        
    end  % protected methods block    
    
%     methods (Access=protected)
%         function updateVisibility_(self, ~, ~, ~, ~, event)
%             figureName = event.Args{1} ;
%             oldValue = event.Args{2} ;            
%             if isequal(figureName, 'TestPulser') ,
%                 newValue = self.Model_.IsTestPulserFigureVisible ;
%                 if oldValue && newValue , 
%                     % Do this to raise the figure
%                     set(self.FigureGH_, 'Visible', 'off') ;
%                     set(self.FigureGH_, 'Visible', 'on') ;
%                 else
%                     set(self.FigureGH_, 'Visible', ws.onIff(newValue)) ;
%                 end                    
%             end
%         end                
%     end
    
end  % classdef
