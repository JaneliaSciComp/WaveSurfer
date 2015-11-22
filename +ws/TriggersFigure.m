classdef TriggersFigure < ws.MCOSFigure
    properties
        AcquisitionPanel
        AcquisitionSchemeText
        AcquisitionSchemePopupmenu
        
        StimulationPanel
        UseAcquisitionTriggerCheckbox
        StimulationSchemeText
        StimulationSchemePopupmenu
        
        CounterTriggersPanel
        CounterTriggersTable
        
        ExternalTriggersPanel
        ExternalTriggersTable
    end  % properties
    
    methods
        function self=TriggersFigure(model,controller)
            self = self@ws.MCOSFigure(model,controller);            
            set(self.FigureGH, ...
                'Tag','triggersFigureWrapper', ...
                'Units','Pixels', ...
                'Color',get(0,'defaultUIControlBackgroundColor'), ...
                'Resize','off', ...
                'Name','Triggers', ...
                'MenuBar','none', ...
                'DockControls','off', ...
                'NumberTitle','off', ...
                'Visible','off', ...
                'CloseRequestFcn',@(source,event)(self.closeRequested(source,event)));
               % CloseRequestFcn will get overwritten by the ws.most.Controller constructor, but
               % we re-set it in the ws.TriggersController
               % constructor.
           
           % Create the fixed controls (which for this figure is all of them)
           self.createFixedControls_();          

           % Set up the tags of the HG objects to match the property names
           self.setNonidiomaticProperties_();
           
           % Layout the figure and set the position
           self.layout_();
           ws.utility.positionFigureOnRootRelativeToUpperLeftBang(self.FigureGH,[30 30+40]);
           
           % Initialize the guidata
           self.updateGuidata_();
           
           % Sync to the model
           self.update();
           
%            % Make the figure visible
%            set(self.FigureGH,'Visible','on');
        end  % constructor
    end
    
    methods (Access=protected)
        function didSetModel_(self)
            self.updateSubscriptionsToModelEvents_();
            didSetModel_@ws.MCOSFigure(self);
        end
    end
    
    methods (Access = protected)
        function createFixedControls_(self)
            % Creates the controls that are guaranteed to persist
            % throughout the life of the window.
            
            % Acquisition Panel
            self.AcquisitionPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels', ...
                        'BorderType','none', ...
                        'FontWeight','bold', ...
                        'Title','Acquisition');
%             self.UseASAPTriggeringCheckbox = ...
%                 uicontrol('Parent',self.AcquisitionPanel, ...
%                           'Style','checkbox', ...
%                           'String','Use ASAP triggering');
            self.AcquisitionSchemeText = ...
                uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','text', ...
                          'String','Scheme:');
            self.AcquisitionSchemePopupmenu = ...
                uicontrol('Parent',self.AcquisitionPanel, ...
                          'Style','popupmenu', ...
                          'String',{'Thing 1';'Thing 2'});
                          
            % Stimulation Panel
            self.StimulationPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels', ...
                        'BorderType','none', ...
                        'FontWeight','bold', ...
                        'Title','Stimulation');
            self.UseAcquisitionTriggerCheckbox = ...
                uicontrol('Parent',self.StimulationPanel, ...
                          'Style','checkbox', ...
                          'String','Use acquisition scheme');
            self.StimulationSchemeText = ...
                uicontrol('Parent',self.StimulationPanel, ...
                          'Style','text', ...
                          'String','Scheme:');
            self.StimulationSchemePopupmenu = ...
                uicontrol('Parent',self.StimulationPanel, ...
                          'Style','popupmenu', ...
                          'String',{'Thing 1';'Thing 2'});

            % Trigger Sources Panel
            self.CounterTriggersPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels', ...
                        'BorderType','none', ...
                        'FontWeight','bold', ...
                        'Title','Counter Triggers');
            self.CounterTriggersTable = ...
                uitable('Parent',self.CounterTriggersPanel, ...
                        'ColumnName',{'Name' 'Device' 'CTR' 'Repeats' 'Interval (s)' 'PFI' 'Edge'}, ...
                        'ColumnFormat',{'char' 'char' 'numeric' 'numeric' 'numeric' 'numeric' {'Rising' 'Falling'}}, ...
                        'ColumnEditable',[false false false true true false false]);
            
            % Trigger Destinations Panel
            self.ExternalTriggersPanel = ...
                uipanel('Parent',self.FigureGH, ...
                        'Units','pixels', ...
                        'BorderType','none', ...
                        'FontWeight','bold', ...
                        'Title','External Triggers');
            self.ExternalTriggersTable = ...
                uitable('Parent',self.ExternalTriggersPanel, ...
                        'ColumnName',{'Name' 'Device' 'PFI' 'Edge'}, ...
                        'ColumnFormat',{'char' 'char' 'numeric' {'Rising' 'Falling'}}, ...
                        'ColumnEditable',[false false false false]);
        end  % function
    end  % singleton methods block
    
    methods (Access = protected)
        function setNonidiomaticProperties_(self)
            % For each object property, if it's an HG object, set the tag
            % based on the property name, and set other HG object properties that can be
            % set systematically.
            mc=metaclass(self);
            propertyNames={mc.PropertyList.Name};
            for i=1:length(propertyNames) ,
                propertyName=propertyNames{i};
                propertyThing=self.(propertyName);
                if ~isempty(propertyThing) && all(ishghandle(propertyThing)) && ~(isscalar(propertyThing) && isequal(get(propertyThing,'Type'),'figure')) ,
                    % Set Tag
                    set(propertyThing,'Tag',propertyName);
                    
                    % Set Callback
                    if isequal(get(propertyThing,'Type'),'uimenu') ,
                        if get(propertyThing,'Parent')==self.FigureGH ,
                            % do nothing for top-level menus
                        else
                            set(propertyThing,'Callback',@(source,event)(self.controlActuated(propertyName,source,event)));
                        end
                    elseif ( isequal(get(propertyThing,'Type'),'uicontrol') && ~isequal(get(propertyThing,'Style'),'text') ) ,
                        set(propertyThing,'Callback',@(source,event)(self.controlActuated(propertyName,source,event)));
                    elseif isequal(get(propertyThing,'Type'),'uitable') 
                        set(propertyThing,'CellEditCallback',@(source,event)(self.controlActuated(propertyName,source,event)));                        
                    end
                    
                    % Set Font
                    if isequal(get(propertyThing,'Type'),'uicontrol') || isequal(get(propertyThing,'Type'),'uipanel') ,
                        set(propertyThing,'FontName','Tahoma');
                        set(propertyThing,'FontSize',8);
                    end
                    
                    % Set Units
                    if isequal(get(propertyThing,'Type'),'uicontrol') || isequal(get(propertyThing,'Type'),'uipanel') ,
                        set(propertyThing,'Units','pixels');
                    end
                    
%                     % Set border type
%                     if isequal(get(propertyThing,'Type'),'uipanel') ,
%                         set(propertyThing,'BorderType','none', ...
%                                           'FontWeight','bold');
%                     end
                end
            end
        end  % function        
    end  % protected methods block

    methods (Access = protected)
        function figureSize=layoutFixedControls_(self)
            % We return the figure size so that the figure can be properly
            % resized after the initial layout, and we can keep all the
            % layout info in one place.
            
            import ws.utility.positionEditLabelAndUnitsBang
            
            topPadHeight=10;
            schemesAreaWidth=280;
            tablePanelsAreaWidth=500;
            tablePanelAreaHeight=210;
            heightBetweenTableAreas=6;

            figureWidth=schemesAreaWidth+tablePanelsAreaWidth;
            figureHeight=tablePanelAreaHeight+heightBetweenTableAreas+tablePanelAreaHeight+topPadHeight;

            sweepBasedAcquisitionPanelAreaHeight=78;
            sweepBasedStimulationPanelAreaHeight=78;
            %continuousPanelAreaHeight=56;
            spaceBetweenPanelsHeight=30;
            
            
            %
            % The schemes area containing the sweep-based acq, sweep-based
            % stim, and continuous panels, arranged in a column
            %
            panelInset=3;  % panel dimensions are defined by the panel area, then inset by this amount on all sides
            
            % The Acquisition panel
            sweepBasedAcquisitionPanelXOffset=panelInset;
            sweepBasedAcquisitionPanelWidth=schemesAreaWidth-panelInset-panelInset;
            sweepBasedAcquisitionPanelAreaYOffset=figureHeight-topPadHeight-sweepBasedAcquisitionPanelAreaHeight;
            sweepBasedAcquisitionPanelYOffset=sweepBasedAcquisitionPanelAreaYOffset+panelInset;            
            sweepBasedAcquisitionPanelHeight=sweepBasedAcquisitionPanelAreaHeight-panelInset-panelInset;
            set(self.AcquisitionPanel, ...
                'Position',[sweepBasedAcquisitionPanelXOffset sweepBasedAcquisitionPanelYOffset ...
                            sweepBasedAcquisitionPanelWidth sweepBasedAcquisitionPanelHeight]);

            % The Stimulation panel
            sweepBasedStimulationPanelXOffset=panelInset;
            sweepBasedStimulationPanelWidth=schemesAreaWidth-panelInset-panelInset;
            sweepBasedStimulationPanelAreaYOffset=sweepBasedAcquisitionPanelAreaYOffset-sweepBasedStimulationPanelAreaHeight-spaceBetweenPanelsHeight;
            sweepBasedStimulationPanelYOffset=sweepBasedStimulationPanelAreaYOffset+panelInset;            
            sweepBasedStimulationPanelHeight=sweepBasedStimulationPanelAreaHeight-panelInset-panelInset;
            set(self.StimulationPanel, ...
                'Position',[sweepBasedStimulationPanelXOffset sweepBasedStimulationPanelYOffset ...
                            sweepBasedStimulationPanelWidth sweepBasedStimulationPanelHeight]);

            % The Trigger Sources panel
            tablesAreaXOffset=schemesAreaWidth;
            counterTriggersPanelXOffset=tablesAreaXOffset+panelInset;
            counterTriggersPanelWidth=tablePanelsAreaWidth-panelInset-panelInset;
            counterTriggersPanelAreaYOffset=tablePanelAreaHeight+heightBetweenTableAreas;
            counterTriggersPanelYOffset=counterTriggersPanelAreaYOffset+panelInset;            
            counterTriggersPanelHeight=tablePanelAreaHeight-panelInset-panelInset;
            set(self.CounterTriggersPanel, ...
                'Position',[counterTriggersPanelXOffset counterTriggersPanelYOffset ...
                            counterTriggersPanelWidth counterTriggersPanelHeight]);
            
            % The Trigger Destinations panel
            externalTriggersPanelXOffset=tablesAreaXOffset+panelInset;
            externalTriggersPanelWidth=tablePanelsAreaWidth-panelInset-panelInset;
            externalTriggersPanelAreaYOffset=0;
            externalTriggersPanelYOffset=externalTriggersPanelAreaYOffset+panelInset;            
            externalTriggersPanelHeight=tablePanelAreaHeight-panelInset-panelInset;
            set(self.ExternalTriggersPanel, ...
                'Position',[externalTriggersPanelXOffset externalTriggersPanelYOffset ...
                            externalTriggersPanelWidth externalTriggersPanelHeight]);

            % Contents of panels
            self.layoutSweepBasedAcquisitionPanel_(sweepBasedAcquisitionPanelWidth,sweepBasedAcquisitionPanelHeight);
            self.layoutSweepBasedStimulationPanel_(sweepBasedStimulationPanelWidth,sweepBasedStimulationPanelHeight);
            %self.layoutContinuousPanel_(continuousPanelWidth,continuousPanelHeight);
            self.layoutCounterTriggersPanel_(counterTriggersPanelWidth,counterTriggersPanelHeight);
            self.layoutExternalTriggersPanel_(externalTriggersPanelWidth,externalTriggersPanelHeight);
                        
            % We return the figure size
            figureSize=[figureWidth figureHeight];
        end  % function
    end
    
    methods (Access = protected)
        function layoutSweepBasedAcquisitionPanel_(self,panelWidth,panelHeight)  %#ok<INUSL>
            import ws.utility.positionEditLabelAndUnitsBang
            import ws.utility.positionPopupmenuAndLabelBang

            % Dimensions
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
            heightFromTopToPopupmenu=6;
            %heightFromPopupmenuToRest=4;
            rulerXOffset=60;
            popupmenuWidth=200;
            
            % Source popupmenu
            position=get(self.AcquisitionSchemePopupmenu,'Position');
            height=position(4);
            popupmenuYOffset=panelHeight-heightOfPanelTitle-heightFromTopToPopupmenu-height;  %checkboxYOffset-heightFromPopupmenuToRest-height;
            positionPopupmenuAndLabelBang(self.AcquisitionSchemeText,self.AcquisitionSchemePopupmenu, ...
                                          rulerXOffset,popupmenuYOffset,popupmenuWidth)            

%             % Checkbox
%             checkboxFullExtent=get(self.UseASAPTriggeringCheckbox,'Extent');
%             checkboxExtent=checkboxFullExtent(3:4);
%             checkboxPosition=get(self.UseASAPTriggeringCheckbox,'Position');
%             checkboxXOffset=rulerXOffset;
%             checkboxWidth=checkboxExtent(1)+16;  % size of the checkbox itself
%             checkboxHeight=checkboxPosition(4);
%             checkboxYOffset=popupmenuYOffset-heightFromPopupmenuToRest-checkboxHeight;  % panelHeight-heightOfPanelTitle-heightFromTopToPopupmenu-checkboxHeight;            
%             set(self.UseASAPTriggeringCheckbox, ...
%                 'Position',[checkboxXOffset checkboxYOffset ...
%                             checkboxWidth checkboxHeight]);            
        end  % function
    end

    methods (Access = protected)
        function layoutSweepBasedStimulationPanel_(self,panelWidth,panelHeight)  %#ok<INUSL>
            import ws.utility.positionEditLabelAndUnitsBang
            import ws.utility.positionPopupmenuAndLabelBang

            % Dimensions
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
            heightFromTopToCheckbox=2;
            heightFromCheckboxToRest=4;
            rulerXOffset=60;
            popupmenuWidth=200;
            
            % Checkbox
            checkboxFullExtent=get(self.UseAcquisitionTriggerCheckbox,'Extent');
            checkboxExtent=checkboxFullExtent(3:4);
            checkboxPosition=get(self.UseAcquisitionTriggerCheckbox,'Position');
            checkboxXOffset=rulerXOffset;
            checkboxWidth=checkboxExtent(1)+16;  % size of the checkbox itself
            checkboxHeight=checkboxPosition(4);
            checkboxYOffset=panelHeight-heightOfPanelTitle-heightFromTopToCheckbox-checkboxHeight;            
            set(self.UseAcquisitionTriggerCheckbox, ...
                'Position',[checkboxXOffset checkboxYOffset ...
                            checkboxWidth checkboxHeight]);
            
            % Source popupmenu
            position=get(self.StimulationSchemePopupmenu,'Position');
            height=position(4);
            popupmenuYOffset=checkboxYOffset-heightFromCheckboxToRest-height;
            positionPopupmenuAndLabelBang(self.StimulationSchemeText,self.StimulationSchemePopupmenu, ...
                                          rulerXOffset,popupmenuYOffset,popupmenuWidth)            
        end  % function
    end

    methods (Access = protected)
%         function layoutContinuousPanel_(self,panelWidth,panelHeight) %#ok<INUSL>
%             import ws.utility.positionEditLabelAndUnitsBang
%             import ws.utility.positionPopupmenuAndLabelBang
% 
%             % Dimensions
%             heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title
%             heightFromTopToRest=6;
%             rulerXOffset=60;
%             popupmenuWidth=200;
%             
%             % Source popupmenu
%             position=get(self.ContinuousSchemePopupmenu,'Position');
%             height=position(4);
%             popupmenuYOffset=panelHeight-heightOfPanelTitle-heightFromTopToRest-height;
%             positionPopupmenuAndLabelBang(self.ContinuousSchemeText,self.ContinuousSchemePopupmenu, ...
%                                           rulerXOffset,popupmenuYOffset,popupmenuWidth)            
%         end
    end
    
    methods (Access = protected)
        function layoutCounterTriggersPanel_(self,panelWidth,panelHeight)
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title

            leftPad=10;
            rightPad=10;
            bottomPad=10;
            topPad=2;
            
            tableWidth=panelWidth-leftPad-rightPad;
            tableHeight=panelHeight-heightOfPanelTitle-bottomPad-topPad;
            
            % The table cols have fixed width except Name, which takes up
            % the slack.
            deviceWidth=50;
            ctrWidth=40;            
            repeatsWidth=60;
            intervalWidth=66;
            pfiWidth=40;
            edgeWidth=50;
            nameWidth=tableWidth-(deviceWidth+ctrWidth+repeatsWidth+intervalWidth+pfiWidth+edgeWidth+34);  % 30 for the row titles col
            
            % 'Name' 'CTR' 'Repeats' 'Interval (s)' 'PFI' 'Edge'
            set(self.CounterTriggersTable, ...
                'Position', [leftPad bottomPad tableWidth tableHeight], ...
                'ColumnWidth', {nameWidth deviceWidth ctrWidth repeatsWidth intervalWidth pfiWidth edgeWidth});
        end
    end
    
    methods (Access = protected)
        function layoutExternalTriggersPanel_(self,panelWidth,panelHeight)
            heightOfPanelTitle=14;  % Need to account for this to not overlap with panel title

            leftPad=10;
            rightPad=10;
            bottomPad=10;
            topPad=2;
            
            tableWidth=panelWidth-leftPad-rightPad;
            tableHeight=panelHeight-heightOfPanelTitle-bottomPad-topPad;
            
            % The table cols have fixed width except Name, which takes up
            % the slack.
            deviceWidth=50;
            pfiWidth=40;
            edgeWidth=50;
            nameWidth=tableWidth-(deviceWidth+pfiWidth+edgeWidth+34);  % 34 for the row titles col
                        
            % 'Name' 'PFI' 'Edge'
            set(self.ExternalTriggersTable, ...
                'Position', [leftPad bottomPad tableWidth tableHeight], ...
                'ColumnWidth', {nameWidth deviceWidth pfiWidth edgeWidth});
        end
    end
    
    methods
        function delete(self) %#ok<INUSD>
%             if ishghandle(self.FigureGH) ,
%                 delete(self.FigureGH);
%             end
        end  % function       
    end  % methods    

%     methods
%         function controlActuated(self,controlName,source,event)
%             if isempty(self.Controller) ,
%                 % do nothing
%             else
%                 self.Controller.controlActuated(controlName,source,event);
%                 %self.Controller.updateModel(source,event,guidata(self.FigureGH));
%             end
%         end  % function       
%     end  % methods

    methods (Access=protected)
        function updateControlPropertiesImplementation_(self,varargin)
            if isempty(self.Model) ,
                return
            end            
            self.updateSweepBasedAcquisitionControls();
            self.updateSweepBasedStimulationControls();
            %self.updateContinuousModeControls();
            self.updateCounterTriggersTable();
            self.updateExternalTriggersTable();                   
        end  % function
    end  % methods
    
    methods (Access=protected)
        function updateControlEnablementImplementation_(self)
            triggeringModel=self.Model;
            if isempty(triggeringModel) || ~isvalid(triggeringModel) ,
                return
            end            
            wsModel=triggeringModel.Parent;  % this is the WavesurferModel
            isIdle=isequal(wsModel.State,'idle');
            isSweepBased = wsModel.AreSweepsFiniteDuration;
            
            import ws.utility.onIff
            
            set(self.AcquisitionSchemePopupmenu,'Enable',onIff(isIdle));
            
            %acquisitionUsesASAPTriggering=triggeringModel.AcquisitionUsesASAPTriggering;
            isStimulusUsingAcquisitionTriggerScheme=triggeringModel.StimulationUsesAcquisitionTriggerScheme;
            %isAcquisitionSchemeInternal=triggeringModel.AcquisitionTriggerScheme.IsInternal;
            %set(self.UseASAPTriggeringCheckbox,'Enable',onIff(isIdle&&isSweepBased&&isAcquisitionSchemeInternal));
            set(self.UseAcquisitionTriggerCheckbox,'Enable',onIff(isIdle&&~isSweepBased));
            set(self.StimulationSchemePopupmenu,'Enable',onIff(isIdle&&~isStimulusUsingAcquisitionTriggerScheme));
            
            %set(self.ContinuousSchemePopupmenu,'Enable',onIff(isIdle));
            
            set(self.CounterTriggersTable,'Enable',onIff(isIdle));
            set(self.ExternalTriggersTable,'Enable',onIff(isIdle));
        end  % function
    end
    
    methods
        function updateSweepBasedAcquisitionControls(self,varargin)
            model=self.Model;
            if isempty(model) ,
                return
            end
            %import ws.utility.setPopupMenuItemsAndSelectionBang
            %import ws.utility.onIff
            schemes = model.AcquisitionSchemes ;
            rawMenuItems = cellfun(@(scheme)(scheme.Name),schemes,'UniformOutput',false) ;
            rawCurrentItem=model.AcquisitionTriggerScheme.Name;
            ws.utility.setPopupMenuItemsAndSelectionBang(self.AcquisitionSchemePopupmenu, ...
                                                         rawMenuItems, ...
                                                         rawCurrentItem);
        end  % function       
    end  % methods
    
    methods
        function updateSweepBasedStimulationControls(self,varargin)
            model=self.Model;
            if isempty(model) ,
                return
            end
            %import ws.utility.setPopupMenuItemsAndSelectionBang
            %import ws.utility.onIff
            set(self.UseAcquisitionTriggerCheckbox,'Value',model.StimulationUsesAcquisitionTriggerScheme);
            schemes = model.Schemes ;
            rawMenuItems = cellfun(@(scheme)(scheme.Name),schemes,'UniformOutput',false) ;
            rawCurrentItem=model.StimulationTriggerScheme.Name;
            ws.utility.setPopupMenuItemsAndSelectionBang(self.StimulationSchemePopupmenu, ...
                                                         rawMenuItems, ...
                                                         rawCurrentItem);
        end  % function       
    end  % methods
    
    methods
%         function updateContinuousModeControls(self,varargin)
%             model=self.Model;
%             if isempty(model) ,
%                 return
%             end
%             import ws.utility.setPopupMenuItemsAndSelectionBang
%             import ws.utility.onIff
%             rawMenuItems={model.CounterTriggers.Name};
%             rawCurrentItem=model.ContinuousModeTriggerScheme.Target.Name;
%             setPopupMenuItemsAndSelectionBang(self.ContinuousSchemePopupmenu, ...
%                                               rawMenuItems, ...
%                                               rawCurrentItem);
%         end  % function       
    end  % methods

    methods
        function updateCounterTriggersTable(self,varargin)
            model=self.Model;
            if isempty(model) ,
                return
            end
            nRows=length(model.CounterTriggers);
            nColumns=7;
            data=cell(nRows,nColumns);
            for i=1:nRows ,
                source=model.CounterTriggers{i};
                data{i,1}=source.Name;
                data{i,2}=source.DeviceName;
                data{i,3}=source.CounterID;
                data{i,4}=source.RepeatCount;
                data{i,5}=source.Interval;
                data{i,6}=source.PFIID;
                data{i,7}=char(source.Edge);
            end
            set(self.CounterTriggersTable,'Data',data);
        end  % function
    end  % methods
    
    methods
        function updateExternalTriggersTable(self,varargin)
            model=self.Model;
            if isempty(model) ,
                return
            end
            nRows=length(model.ExternalTriggers);
            nColumns=4;
            data=cell(nRows,nColumns);
            for i=1:nRows ,
                destination=model.ExternalTriggers{i};
                data{i,1}=destination.Name;
                data{i,2}=destination.DeviceName;
                data{i,3}=destination.PFIID;
                data{i,4}=char(destination.Edge);
            end
            set(self.ExternalTriggersTable,'Data',data);
        end  % function
    end  % methods
    
    methods (Access=protected)
        function updateSubscriptionsToModelEvents_(self)
            % Unsubscribe from all events, then subsribe to all the
            % approprate events of model.  model should be a Triggering subsystem
            %self.unsubscribeFromAll();
            model=self.Model;
            if ~isempty(model) && isvalid(model) ,
                %model.AcquisitionTriggerScheme.subscribeMe(self,'DidSetTarget','','updateSweepBasedAcquisitionControls');
                %model.StimulationTriggerScheme.subscribeMe(self,'DidSetTarget','','updateSweepBasedStimulationControls');  

                % Add subscriptions for updating control enablement
                model.Parent.subscribeMe(self,'DidSetState','','updateControlEnablement');
                %model.Parent.subscribeMe(self,'DidSetAreSweepsFiniteDurationOrContinuous','','update');
                model.subscribeMe(self,'Update','','update');
                %model.AcquisitionTriggerScheme.subscribeMe(self,'DidSetIsInternal','','updateControlEnablement');  
                %model.StimulationTriggerScheme.subscribeMe(self,'DidSetIsInternal','','updateControlEnablement');  

                % Add subscriptions for the changeable fields of each element
                % of model.CounterTriggers
                self.updateSubscriptionsToSourceProperties_();
            end
        end
        
        function updateSubscriptionsToSourceProperties_(self,varargin)
            % Add subscriptions for the changeable fields of each source
            model=self.Model;
            sources = model.CounterTriggers;            
            for i = 1:length(sources) ,
                source=sources{i};
                source.unsubscribeMeFromAll(self);
                %source.subscribeMe(self, 'PostSet', 'Interval', 'updateCounterTriggersTable');
                %source.subscribeMe(self, 'PostSet', 'RepeatCount', 'updateCounterTriggersTable');
                source.subscribeMe(self, 'Update', '', 'updateCounterTriggersTable');
            end
        end
    end
    
end  % classdef
