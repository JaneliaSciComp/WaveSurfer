classdef (Abstract) Controller < ws.EventSubscriber
    % This is a base class that wraps a handle graphics figure in a proper
    % MCOS object, but does not have a separate controller.  All methods
    % fired by UI actions are methods of the Controller
    % subclass.
    
    properties (Access=protected, Transient=true)
        DegreeOfEnablement_ = 1
            % We want to be able to disable updates, and do it in such a way
            % that it can be called in nested loops, functions, etc and
            % behave in a reasonable way.  So this this an integer that can
            % take on negative values when it has been disabled multiple
            % times without being enabled.  But it is always <= 1.
        NCallsToUpdateWhileDisabled_ = []    
        NCallsToUpdateControlPropertiesWhileDisabled_ = []    
        NCallsToUpdateControlEnablementWhileDisabled_ = []    
        %DegreeOfReadiness_ = 1
    end
    
    properties (Dependent=true, Transient=true)
        AreUpdatesEnabled   % logical scalar; if false, changes in the model should not be reflected in the UI
    end
    
    properties (Access=protected)
        FigureGH_  % the figure graphics handle
        Model_  % the model        
    end  % properties    
    
    methods
        function self = Controller(model)
            backgroundColor = ws.getDefaultUIControlBackgroundColor() ;
            self.FigureGH_=figure('Units','Pixels', ...
                                  'Color',backgroundColor, ...
                                  'Visible','off', ...
                                  'HandleVisibility','off', ...
                                  'DockControls','off', ...
                                  'NumberTitle','off', ...
                                  'CloseRequestFcn',@(source,event)(self.closeRequested_(source,event)), ...
                                  'ResizeFcn', @(source,event)(self.resize_()) ) ;
            if exist('model','var') ,
                self.Model_ = model ;
                if ~isempty(model) && isvalid(model) ,
                    %fprintf('About to subscribe a figure-with-self-control of class %s to a model of class %s\n', class(self), class(model)) ;
                    model.subscribeMe(self,'UpdateReadiness','','updateReadiness');
                end
            else
                self.Model_ = [] ;  % need this to can create an empty array of MCOSFigures
            end
        end
        
        function delete(self)
            self.deleteFigureGH_();
            self.Model_ = [] ;
        end
        
        function set.AreUpdatesEnabled(self, newValue)
            % The AreUpdatesEnabled property looks from the outside like a simple boolean,
            % but it actually accumulates the number of times it's been set true vs set
            % false, and the getter only returns true if that difference is greater than
            % zero.  Also, the accumulator value (self.DegreeOfEnablement_) never goes above
            % one.
            if ~( islogical(newValue) && isscalar(newValue) ) ,
                return
            end
            netValueBefore = (self.DegreeOfEnablement_ > 0) ;
            newValueAsSign = 2 * double(newValue) - 1 ;  % [0,1] -> [-1,+1]
            newDegreeOfEnablementRaw = self.DegreeOfEnablement_ + newValueAsSign ;
            self.DegreeOfEnablement_ = ...
                    ws.fif(newDegreeOfEnablementRaw <= 1, ...
                           newDegreeOfEnablementRaw, ...
                           1);
            netValueAfter = (self.DegreeOfEnablement_ > 0) ;
            if netValueAfter && ~netValueBefore ,
                % Updates have just been enabled
                if self.NCallsToUpdateWhileDisabled_ > 0 ,
                    self.updateImplementation_() ;
                elseif self.NCallsToUpdateControlPropertiesWhileDisabled_ > 0 ,
                    self.updateControlPropertiesImplementation_() ;
                elseif self.NCallsToUpdateControlEnablementWhileDisabled_ > 0 ,
                    self.updateControlEnablementImplementation_() ;
                end
                self.NCallsToUpdateWhileDisabled_ = [] ;
                self.NCallsToUpdateControlPropertiesWhileDisabled_ = [] ;
                self.NCallsToUpdateControlEnablementWhileDisabled_ = [] ;
            elseif ~netValueAfter && netValueBefore ,
                % Updates have just been disabled
                self.NCallsToUpdateWhileDisabled_ = 0 ;
                self.NCallsToUpdateControlPropertiesWhileDisabled_ = 0 ;
                self.NCallsToUpdateControlEnablementWhileDisabled_ = 0 ;
            end            
        end  % function

        function value = get.AreUpdatesEnabled(self)
            value = (self.DegreeOfEnablement_ > 0) ;
        end
        
        function update(self, varargin)
            % Sometimes outsiders need to prompt an update.  Methods of the 
            % Controller should generally call update_() directly.
            self.update_(varargin{:}) ;
        end
        
        function updateControlProperties(self, varargin)
            % Sometimes outsiders need to prompt an update.  Methods of the 
            % Controller should generally call update_() directly.
            self.updateControlProperties_(varargin{:}) ;
        end

        function updateControlEnablement(self, varargin)
            % Sometimes outsiders need to prompt an update.  Methods of the 
            % Controller should generally call update_() directly.
            self.updateControlEnablement_(varargin{:}) ;
        end
        
        function updateReadiness(self, varargin)
            % Sometimes outsiders need to prompt an update.  Methods of the 
            % Controller should generally call update_() directly.
            self.updateReadiness_(varargin{:}) ;
        end

        function updateVisibility(self, varargin)
            if length(varargin)>=5 ,
                event = varargin{5} ;                
                figureName = event.Args{1} ;
                %oldValue = event.Args{2} ;
                myFigureName = ws.figureNameFromControllerClassName(class(self)) ;
                isMatch = isequal(figureName, myFigureName) ;
            else
                isMatch = true ;
            end
            if isMatch ,
                isVisiblePropertyName = ws.isFigureVisibleVariableNameFromControllerClassName(class(self)) ;
                newValue = self.Model_.(isVisiblePropertyName) ;
                set(self.FigureGH_, 'Visible', ws.onIff(newValue)) ;
            end
        end                

        function syncFigurePositionFromModel(self, monitorPositions)
            modelPropertyName = ws.positionVariableNameFromControllerClassName(class(self));
            rawPosition = self.Model_.(modelPropertyName) ;  % Can be empty if opening an older protocol file
            if ~isempty(rawPosition) ,
                set(self.FigureGH_, 'Position', rawPosition);
            end
            self.constrainPositionToMonitors(monitorPositions) ;
        end
    end  % public methods block
    
    methods (Access=protected)
%         function set(self, propName, value)
%             if strcmpi(propName,'Visible') && islogical(value) && isscalar(value) ,
%                 % special case to deal with Visible, which seems to
%                 % sometimes be a boolean
%                 if value,
%                     set(self.FigureGH_,'Visible','on');
%                 else
%                     set(self.FigureGH_,'Visible','off');
%                 end
%             else
%                 set(self.FigureGH_,propName,value);
%             end
%         end
%         
%         function value=get(self,propName)
%             value=get(self.FigureGH_,propName);
%         end
        
        function update_(self,varargin)
            % Called when the caller wants the figure to fully re-sync with the
            % model, from scratch.  This may cause the figure to be
            % resized, but this is always done in such a way that the
            % upper-righthand corner stays in the same place.
            if self.AreUpdatesEnabled ,
                if isempty(self.Model_) ,
                    self.updateImplementation_();
                else                    
                    isVisiblePropertyName = ws.isFigureVisibleVariableNameFromControllerClassName(class(self)) ;
                    isVisible = self.Model_.(isVisiblePropertyName) ;
                    if isVisible ,
                        self.updateImplementation_();
                    end
                end
            else
                self.NCallsToUpdateWhileDisabled_ = self.NCallsToUpdateWhileDisabled_ + 1 ;
            end
        end
        
        function updateControlProperties_(self,varargin)
            % Called when caller wants the control properties (Properties besides enablement, that is.) to re-sync
            % with the model, but doesn't need to update the controls that are in existance, or change the positions of the controls.
            if self.AreUpdatesEnabled ,
                if isempty(self.Model_) ,
                    self.updateImplementation_();
                else                    
                    isVisiblePropertyName = ws.isFigureVisibleVariableNameFromControllerClassName(class(self)) ;
                    isVisible = self.Model_.(isVisiblePropertyName) ;
                    if isVisible ,
                        self.updateControlPropertiesImplementation_();
                    end
                end
            else
                self.NCallsToUpdateControlPropertiesWhileDisabled_ = self.NCallsToUpdateControlPropertiesWhileDisabled_ + 1 ;
            end
        end
        
        function updateControlEnablement_(self,varargin)
            % Called when caller only needs to update the
            % enablement/disablment of the controls, given the model state.
            if self.AreUpdatesEnabled ,
                if isempty(self.Model_) ,
                    self.updateImplementation_();
                else                    
                    isVisiblePropertyName = ws.isFigureVisibleVariableNameFromControllerClassName(class(self)) ;
                    isVisible = self.Model_.(isVisiblePropertyName) ;
                    if isVisible ,
                        self.updateControlEnablementImplementation_() ;
                    end
                end
            else
                self.NCallsToUpdateControlEnablementWhileDisabled_ = self.NCallsToUpdateControlEnablementWhileDisabled_ + 1 ;
            end            
        end
        
        function updateReadiness_(self,varargin)
            self.updateReadinessImplementation_();
        end

        function doWithModel_(self, varargin)
            if ~isempty(self.Model_) ,
                self.Model_.do(varargin{:}) ;
            end
        end
        
        function newPosition = positionUpperLeftRelativeToOtherUpperRight_(self, referenceFigurePosition, offset)
            % Positions the upper left corner of the figure relative to the upper
            % *right* corner of the other figure.  offset is 2x1, with the 1st
            % element the number of pixels from the right side of the other figure,
            % the 2nd the number of pixels from the top of the other figure.

            %ws.positionFigureUpperLeftRelativeToFigureUpperRightBang(self.FigureGH_, other.FigureGH_, offset) ;
            
            % Get our position
            figureGH = self.FigureGH_ ;
            originalUnits=get(figureGH,'units');
            set(figureGH,'units','pixels');
            position=get(figureGH,'position');
            set(figureGH,'units',originalUnits);
            figureSize=position(3:4);

            % Get the reference figure position
            %originalUnits=get(referenceFigureGH,'units');
            %set(referenceFigureGH,'units','pixels');
            %referenceFigurePosition=get(referenceFigureGH,'position');
            %set(referenceFigureGH,'units',originalUnits);
            referenceFigureOffset=referenceFigurePosition(1:2);
            referenceFigureSize=referenceFigurePosition(3:4);

            % Calculate a new offset that will position us as wanted
            origin = referenceFigureOffset + referenceFigureSize ;
            figureHeight=figureSize(2);
            newOffset = [ origin(1) + offset(1) ...
                          origin(2) + offset(2) - figureHeight ] ;
            
            % Get the new position
            newPosition = [newOffset figureSize] ;

            % Set figure position, using the new offset but the same size as before
            originalUnits=get(figureGH,'units');
            set(figureGH,'units','pixels');
            set(figureGH,'position',newPosition);
            set(figureGH,'units',originalUnits);            
        end
        
        createFixedControls_(self)
            % In subclass, this should create all the controls that persist
            % throughout the lifetime of the figure.
        
        function updateControlsInExistance_(self)  %#ok<MANU>
            % In subclass, this should make sure the non-fixed controls in
            % existance are synced with the model state, deleting
            % inappropriate ones and creating appropriate ones as needed.
            
            % This default implementation does nothing, and is appropriate
            % only if all the controls are fixed.
        end
        
        updateControlPropertiesImplementation_(self) 
            % In subclass, this should make sure the properties of the
            % controls (besides Position and Enable) are in-sync with the
            % model.  It can assume that all the controls that should
            % exist, do exist.
        
        updateControlEnablementImplementation_(self) 
            % In subclass, this should make sure the Enable property of
            % each control is in-sync with the model.  It can assume that
            % all the controls that should exist, do exist.
        
        figureSize = layoutFixedControls_(self) 
            % In subclass, this should make sure all the positions of the
            % fixed controls are appropriate given the current model state.
        
        function figureSizeModified = layoutNonfixedControls_(self, figureSize)  %#ok<INUSL>
            % In subclass, this should make sure all the positions of the
            % non-fixed controls are appropriate given the current model state.
            % It can safely assume that all the non-fixed controls already
            % exist
            figureSizeModified = figureSize ;  % this is appropriate if there are no nonfixed controls
        end

        function resize_(self)
            % This method should make sure all the controls are sized and placed
            % appropraitely when the figure is resized.
            
            % This implementation should work in most cases, but can be overridden by
            % subclasses if needed.
            self.layout_() ;
        end
        
        function layout_(self)
            % This method should make sure all the controls are sized and placed
            % appropraitely given the current model state.
            
            % This implementation should work in most cases, but can be overridden by
            % subclasses if needed.
            figureSize = self.layoutFixedControls_() ;
            figureSizeModified = self.layoutNonfixedControls_(figureSize) ;
            ws.resizeLeavingUpperLeftFixedBang(self.FigureGH_, figureSizeModified) ;
        end
        
        function updateImplementation_(self)
            % This method should make sure the figure is fully synched with the
            % model state after it is called.  This includes existance,
            % placement, sizing, enablement, and properties of each control, and
            % of the figure itself.

            % This implementation should work in most cases, but can be overridden by
            % subclasses if needed.
            self.updateControlsInExistance_() ;
            self.updateControlPropertiesImplementation_() ;
            self.updateControlEnablementImplementation_() ;
            self.layout_() ;
            self.updateVisibility() ;
        end
        
        function updateReadinessImplementation_(self)
            if isempty(self.Model_) 
                pointerValue = 'arrow';
            else
                if isvalid(self.Model_) ,
                    if self.Model_.IsReady ,
                        pointerValue = 'arrow';
                    else
                        pointerValue = 'watch';
                    end
                else
                    pointerValue = 'arrow';
                end
            end
            set(self.FigureGH_,'pointer',pointerValue);
            %fprintf('drawnow(''update'')\n');
            drawnow('update');
        end
    end
    
    methods (Access=protected)
        function setIsVisible_(self, newValue)
            if ~isempty(self.FigureGH_) && ishghandle(self.FigureGH_) ,
                set(self.FigureGH_, 'Visible', ws.onIff(newValue));
            end
        end  % function
    end  % methods
    
    methods
        function show(self)
            self.setIsVisible_(true);
        end  % function       
    end  % methods    

    methods
        function hide(self)
            self.setIsVisible_(false);
        end  % function       
    end  % methods    
    
    methods
        function raise(self)
            self.hide() ;
            self.show() ;  
        end  % function       
    end  % public methods block
    
    methods (Access=protected)
        function closeRequested_(self, source, event)  %#ok<INUSD>
            % Subclasses can override this if it's not to their liking
            self.deleteFigureGH_();
        end  % function       
    end  % methods    
            
    methods (Access=protected)
        function deleteFigureGH_(self)   
            % This causes the figure HG object to be deleted, with no ifs
            % ands or buts
            if ~isempty(self.FigureGH_) && ishghandle(self.FigureGH_) ,
                delete(self.FigureGH_);
            end
            self.FigureGH_ = [] ;
        end  % function       
    end  % methods    
        
    methods
        function exceptionMaybe = controlActuated(self, methodNameStem, source, event, varargin)  % public so that control actuation can be easily faked          
            % E.g. self.CancelButton_ would typically have the method name stem 'cancelButton'.
            % The advantage of passing in the methodNameStem, rather than,
            % say always storing it in the tag of the graphics object, and
            % then reading it out of the source arg, is that doing it this
            % way makes it easier to fake control actuations by calling
            % this function with the desired methodNameStem and an empty
            % source and event.
            try
                if isempty(source) ,
                    % this means the control actuated was a 'faux' control
                    methodName=[methodNameStem 'Actuated'] ;
                    if ismethod(self,methodName) ,
                        self.(methodName)(source, event, varargin{:});
                    end
                else
                    type=get(source,'Type');
                    if isequal(type,'uitable') ,
                        if isfield(event,'EditData') || isprop(event,'EditData') ,  % in older Matlabs, event is a struct, in later, an object
                            methodName=[methodNameStem 'CellEdited'];
                        else
                            methodName=[methodNameStem 'CellSelected'];
                        end
                        if ismethod(self,methodName) ,
                            self.(methodName)(source, event, varargin{:});
                        end
                    elseif isequal(type,'uicontrol') || isequal(type,'uimenu') ,
                        methodName=[methodNameStem 'Actuated'] ;
                        if ismethod(self,methodName) ,
                            self.(methodName)(source, event, varargin{:});
                        end
                    else
                        % odd --- just ignore
                    end
                end
                exceptionMaybe = {} ;
            catch exception
                if isequal(exception.identifier,'ws:invalidPropertyValue') ,
                    % ignore completely, don't even pass on to output
                    exceptionMaybe = {} ;
                else
                    ws.raiseDialogOnException(exception) ;
                    exceptionMaybe = { exception } ;
                end
            end
        end  % function       
    end  % public methods block
    
    methods
        function constrainPositionToMonitors(self, monitorPositions)
            % For each monitor, calculate the translation needed to get the
            % figure onto it.

            % get the figure's OuterPosition
            %dbstack
            figureOuterPosition = get(self.FigureGH_, 'OuterPosition') ;
            figurePosition = get(self.FigureGH_, 'Position') ;
            %monitorPositions
            
            % define some local functions we'll need
            function translation = translationToFit2D(offset, sz, screenOffset, screenSize)
                xTranslation = translationToFit1D(offset(1), sz(1), screenOffset(1), screenSize(1)) ;
                yTranslation = translationToFit1D(offset(2), sz(2), screenOffset(2), screenSize(2)) ;
                translation = [xTranslation yTranslation] ;
            end

            function translation = translationToFit1D(offset, sz, screenOffset, screenSize)
                % Calculate a translation that will get a thing of size size at offset
                % offset onto a screen at offset screenOffset, of size screenSize.  All
                % args are *scalars*, as is the returned value
                topOffset = offset + sz ;  % or right offset, really
                screenTop = screenOffset+screenSize ;
                if offset < screenOffset ,
                    newOffset = screenOffset ;
                    translation =  newOffset - offset ;
                elseif topOffset > screenTop ,
                    newOffset = screenTop - sz ;
                    translation =  newOffset - offset ;
                else
                    translation = 0 ;
                end
            end
            
            % Get the offset, size of the figure
            figureOuterOffset = figureOuterPosition(1:2) ;
            figureOuterSize = figureOuterPosition(3:4) ;
            figureOffset = figurePosition(1:2) ;
            figureSize = figurePosition(3:4) ;
            
            % Compute the translation needed to get the figure onto each of
            % the monitors
            nMonitors = size(monitorPositions, 1) ;
            figureTranslationForEachMonitor = zeros(nMonitors,2) ;
            for i = 1:nMonitors ,
                monitorPosition = monitorPositions(i,:) ;
                monitorOffset = monitorPosition(1:2) ;
                monitorSize = monitorPosition(3:4) ;
                figureTranslationForThisMonitor = translationToFit2D(figureOuterOffset, figureOuterSize, monitorOffset, monitorSize) ;
                figureTranslationForEachMonitor(i,:) = figureTranslationForThisMonitor ;
            end

            % Calculate the magnitude of the translation for each monitor
            sizeOfFigureTranslationForEachMonitor = hypot(figureTranslationForEachMonitor(:,1), figureTranslationForEachMonitor(:,2)) ;
            
            % Pick the smallest translation that gets the figure onto
            % *some* monitor
            [~,indexOfSmallestFigureTranslation] = min(sizeOfFigureTranslationForEachMonitor) ;
            if isempty(indexOfSmallestFigureTranslation) ,
                figureTranslation = [0 0] ;
            else
                figureTranslation = figureTranslationForEachMonitor(indexOfSmallestFigureTranslation,:) ;
            end        

            % Compute the new position
            newFigurePosition = [figureOffset+figureTranslation figureSize] ;  
              % Apply the translation to the Position, not the
              % OuterPosition, as this seems to be more reliable.  Setting
              % the OuterPosition causes the layouts to get messed up
              % sometimes.  (Maybe setting the 'OuterSize' is the problem?)
            
            % Set it
            set(self.FigureGH_, 'Position', newFigurePosition) ;
        end  % function               
        
    end  % public methods block
    
    methods (Sealed = true)
        function setFigurePositionInModel(self)
            % Add layout info for this window (just this one window) to
            % a struct representing the layout of all windows in the app
            % session.
           
            % Framework specific transformation.
            fig = self.FigureGH_ ;
            position = get(fig, 'Position') ;
            modelPropertyName = ws.positionVariableNameFromControllerClassName(class(self));
            self.Model_.(modelPropertyName) = position ;
        end
    end
            
    methods
        function setAreUpdatesEnabledForFigure(self, newValue)
            self.AreUpdatesEnabled = newValue ;
        end        
    end

end  % classdef
