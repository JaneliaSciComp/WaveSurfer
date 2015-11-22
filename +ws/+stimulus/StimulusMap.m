classdef StimulusMap < ws.Model & ws.mixin.ValueComparable
    
    properties (Dependent=true)
        Name
        Duration  % s
        ChannelNames  % a cell array of strings
        IndexOfEachStimulusInLibrary
        Stimuli  % a cell array, with [] for missing stimuli
        Multipliers  % a double array
    end
    
    properties (Dependent = true, Transient=true)
        IsMarkedForDeletion  % a logical array
    end

    properties (Dependent = true, SetAccess=immutable, Transient=true)
        IsDurationFree
        %IsLive
        NBindings
    end
    
    properties (Access = protected)
        Name_ = ''
        ChannelNames_ = {}
        IndexOfEachStimulusInLibrary_ = {}  % for each binding, the index of the stimulus (in the library) for that binding, or empty if unspecified
        Multipliers_ = []
        Duration_ = 1  % s, internal duration, can be overridden in some circumstances
        IsMarkedForDeletion_ = logical([])
    end
    
    methods
        function self = StimulusMap(parent,varargin)
            self@ws.Model(parent);
            pvArgs = ws.utility.filterPVArgs(varargin, {'Name', 'Duration'}, {});
            
            prop = pvArgs(1:2:end);
            vals = pvArgs(2:2:end);
            
            for idx = 1:length(prop)
                self.(prop{idx}) = vals{idx};
            end
            
            %if isempty(self.Parent) ,
            %    error('wavesurfer:stimulusMapMustHaveParent','A stimulus map has to have a parent StimulusLibrary');
            %end
            
            %self.UUID = rand();
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end
        
%         function set.Parent(self, newParent)
%             if isa(newParent,'nan'), return, end            
%             %self.validatePropArg('Parent', newParent);
%             if (isa(newParent,'double') && isempty(newParent)) || (isa(newParent,'ws.stimulus.StimulusLibrary') && isscalar(newParent)) ,
%                 if isempty(newParent) ,
%                     self.Parent=[];
%                 else
%                     self.Parent=newParent;
%                 end
%             end            
%         end  % function
        
        function set.Name(self,newValue)
            if ischar(newValue) && isrow(newValue) && ~isempty(newValue) ,
                allItems=self.Parent.Maps;
                isNotMe=cellfun(@(item)(item~=self),allItems);
                allItemsButMe=allItems(isNotMe);
                allOtherItemNames=cellfun(@(item)(item.Name),allItemsButMe,'UniformOutput',false);
                if ismember(newValue,allOtherItemNames) ,
                    % do nothing
                else
                    self.Name_=newValue;
                end
            end
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end

        function out = get.NBindings(self) 
            out = length(self.ChannelNames);
        end
        
        function out = get.Name(self)
            out = self.Name_;
        end   % function

        function out = get.IndexOfEachStimulusInLibrary(self)
            out = self.IndexOfEachStimulusInLibrary_ ;
        end   % function

%         function durationPrecursorMayHaveChanged(self,varargin)
%             self.Duration=nan.The;  % a code to do no setting, but cause the post-set event to fire
%             self.IsDurationFree=nan.The;  % cause the post-set event to fire
%         end
        
        function set.ChannelNames(self,newValue)
            % newValue must be a row cell array, with each element a string
            % and each string either empty or a valid output channel name
            stimulation=ws.utility.getSubproperty(self,'Parent','Parent');
            if isempty(stimulation) ,
                doCheckChannelNames=false;
            else
                doCheckChannelNames=true;
                allChannelNames=stimulation.ChannelNames;
            end
            
            if iscell(newValue) && all(size(newValue)==size(self.ChannelNames_)) ,  % can't change number of bindings
                nElements=length(newValue);
                isGoodSoFar=true;
                for i=1:nElements ,
                    putativeChannelName=newValue{i};
                    if ischar(putativeChannelName) && (isrow(putativeChannelName) || isempty(putativeChannelName)) ,
                        if isempty(putativeChannelName) ,
                            % this is ok
                        else
                            if doCheckChannelNames ,
                                if ismember(putativeChannelName,allChannelNames) ,
                                    % this is ok
                                else
                                    isGoodSoFar=false;
                                    break
                                end
                            else
                                % this is ok
                            end                            
                        end
                    else
                        isGoodSoFar=false;
                        break
                    end
                end
                % if isGoodSoFar==true here, is good
                if isGoodSoFar ,
                    self.ChannelNames_=newValue;
                end   
            end            
            % notify the stim library so that views can be updated    
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end                        
        end  % function

        function val = get.ChannelNames(self)
            val = self.ChannelNames_ ;
        end

        function set.Stimuli(self,newValue)
            % newValue a cell array of length equal to the number of
            % bindings.  Each element either [], or a stimulus
            % in the library
            
            if iscell(newValue) && all(size(newValue)==size(self.ChannelNames_)) ,  % can't change number of bindings
                areAllElementsOfNewValueOK = true ;
                indexOfEachStimulusInLibrary = cell(size(self.ChannelNames_)) ;
                for i=1:numel(newValue) ,
                    stimulus = newValue{i} ;
                    if (isempty(stimulus) && isa(stimulus,'double')) ,
                        indexOfEachStimulusInLibrary{i} = [] ;
                    elseif isa(stimulus,'ws.stimulus.Stimulus') && isscalar(stimulus) ,
                        indexOfThisStimulusInLibrary = self.Parent.getStimulusIndex(stimulus) ;
                        if isempty(indexOfThisStimulusInLibrary)
                            % This stim is not in library
                            areAllElementsOfNewValueOK = false ;
                            break
                        else
                            indexOfEachStimulusInLibrary{i} = indexOfThisStimulusInLibrary ;
                        end
                    else
                        areAllElementsOfNewValueOK = false ;
                        break
                    end                        
                end  % for
                
                if areAllElementsOfNewValueOK ,                    
                    self.IndexOfEachStimulusInLibrary_ = indexOfEachStimulusInLibrary ;
                end
            end
            
            % notify the powers that be
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end
        
        function output = get.Stimuli(self)
            nBindings = numel(self.IndexOfEachStimulusInLibrary_) ;            
            output = cell(size(self.IndexOfEachStimulusInLibrary_)) ;
            for i = 1:nBindings ,
                indexOfThisStimulusInLibrary = self.IndexOfEachStimulusInLibrary_{i} ;
                if isempty(indexOfThisStimulusInLibrary) ,
                    output{i} = [] ;
                else                    
                    output{i} = self.Parent.Stimuli{indexOfThisStimulusInLibrary} ;
                end
            end
        end
        
        function set.Multipliers(self,newValue)
            if isnumeric(newValue) && all(size(newValue)==size(self.ChannelNames_)) ,  % can't change number of bindings                
                self.Multipliers_ = double(newValue);
            end
            % notify the powers that be
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end
        
        function output = get.Multipliers(self)
            output = self.Multipliers_ ;
        end
                
        function set.IsMarkedForDeletion(self,newValue)
            if islogical(newValue) && isequal(size(newValue),size(self.ChannelNames_)) ,  % can't change number of bindings                
                self.IsMarkedForDeletion_ = newValue;
            end
            % notify the powers that be
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end
        end
        
        function output = get.IsMarkedForDeletion(self)
            output = self.IsMarkedForDeletion_ ;
        end
                
        function value = get.Duration(self)  % always returns a double
            try
                % See if we can collect all the information we need to make
                % an informed decision about whether to use the acquisition
                % duration or our own internal duration
                [isSweepBased,doesStimulusUseAcquisitionTriggerScheme,acquisitionDuration]=self.collectExternalInformationAboutDuration();
            catch 
                % If we can't collect enough information to make an
                % informed decision, just fall back to the internal
                % duration.
                value=self.Duration_;
                return
            end
            
            % Return the acquisiton duration or the internal duration,
            % depending
            if isSweepBased && doesStimulusUseAcquisitionTriggerScheme ,
                value=acquisitionDuration;
            else
                value=self.Duration_;
            end
        end   % function
        
        function set.Duration(self, newValue)
            if ws.utility.isASettableValue(newValue) ,                
                if isnumeric(newValue) && isreal(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>=0 ,            
                    newValue = double(newValue) ;
                    didThrow=false ;
                    try
                        % See if we can collect all the information we need to make
                        % an informed decision about whether to use the acquisition
                        % duration or our own internal duration
                        % (This is essentially a way to test whether the
                        % parent-child relationships that enable us to determine
                        % the duration from external object are set up.  If this
                        % throws, we know that they're _not_ set up, and so we are
                        % free to set the internal duration to the given value.)
                        [isSweepBased,doesStimulusUseAcquisitionTriggerScheme]=self.collectExternalInformationAboutDuration();
                    catch 
                        didThrow=true ;
                    end
                    if didThrow ,
                        self.Duration_ = newValue;
                    else
                        % If get here, we were able to collect the
                        % external information we wanted.
                        
                        % Return the acquisition duration or the internal duration,
                        % depending
                        if isSweepBased && doesStimulusUseAcquisitionTriggerScheme ,
                           % Internal duration is overridden, so don't set it.
                        else
                            self.Duration_ = newValue;
                        end
                    end
                else
                    if ~isempty(self.Parent) ,
                        self.Parent.childMayHaveChanged(self);
                    end
                    error('most:Model:invalidPropVal', ...
                          'Duration must be numeric, real, scalar, nonnegative, and finite.');                
                end
            end
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged(self);
            end            
        end   % function
        
        function value = get.IsDurationFree(self)
            try
                % See if we can collect all the information we need to make
                % an informed decision about whether to use the acquisition
                % duration or our own internal duration
                [isSweepBased,doesStimulusUseAcquisitionTriggerScheme]=self.collectExternalInformationAboutDuration();
            catch me %#ok<NASGU>
                % If we can't collect enough information to make an
                % informed decision, then we are free!  Ignorance is
                % freedom!
                value=true;
                return
            end
            
            % Return the acquisiton duration or the internal duration,
            % depending
            value=~(isSweepBased && doesStimulusUseAcquisitionTriggerScheme);
        end   % function
        
%         function set.IsDurationFree(self, newValue) %#ok<INUSD>
%             % This does nothing, and is only present so we can cause the
%             % PostSet event on the property to fire when the precursors
%             % change.
%         end   % function

        function [isSweepBased,doesStimulusUseAcquisitionTriggerScheme,acquisitionDuration]=collectExternalInformationAboutDuration(self)
            % Collect information that determines whether we use the
            % internal duration or the acquisition duration.  This will
            % throw if the parent/child relationships are not set up.
            
            % See if we can collect all the information we need to make
            % an informed decision about whether to use the acquisition
            % duration or our own internal duration
            stimulusLibrary=self.Parent;
            stimulationSubsystem=stimulusLibrary.Parent;
            rootModel=stimulationSubsystem.Parent;
            triggeringSubsystem=rootModel.Triggering;
            %acquisitionSubsystem=rootModel.Acquisition;  % problematic: refiller doesn't have this subsystem      
            isSweepBased=rootModel.AreSweepsFiniteDuration;
            doesStimulusUseAcquisitionTriggerScheme=triggeringSubsystem.StimulationUsesAcquisitionTriggerScheme;
            %acquisitionDuration=acquisitionSubsystem.Duration;
            acquisitionDuration=rootModel.SweepDuration;
        end   % function
        
        function out = containsStimulus(self, stimuliOrStimulus)
            stimuli=ws.utility.cellifyIfNeeded(stimuliOrStimulus);
            out = false(size(stimuli));
            
            for index = 1:numel(stimuli)
                validateattributes(stimuli{index}, {'ws.stimulus.Stimulus'}, {'vector'});
            end
            
            if isempty(stimuli)
                return
            end
                        
            %currentStimuli = [self.Bindings_.Stimulus];
            %boundStimuli = cellfun(@(binding)(binding.Stimulus),self.Bindings_,'UniformOutput',false);
            boundStimuli = self.Stimuli;
            
            for index = 1:numel(stimuli) ,
                thisStimulus=stimuli{index};
                isMatch=cellfun(@(boundStimulus)(boundStimulus==thisStimulus),boundStimuli);
                if any(isMatch) ,
                    out(index) = true;
                end
            end
        end   % function

        function addBinding(self, channelName, stimulus, multiplier)
            % Deal with missing args
            if ~exist('channelName','var') || isempty(channelName) ,
                channelName = '';
            end
            if ~exist('stimulus','var') || isempty(stimulus) ,
                stimulus=[];
            end
            if ~exist('multiplier','var') || isempty(multiplier) ,
                multiplier=1;
            end
            
            % Check the args
            if isa(stimulus,'double') && isempty(stimulus) ,
                isStimulusOK = true ;
                indexOfThisStimulusInLibrary = [] ;
            else
                if isa(stimulus,'ws.stimulus.Stimulus') && isscalar(stimulus) ,
                    indexOfThisStimulusInLibrary = self.Parent.getStimulusIndex(stimulus) ;
                    isStimulusOK = ~isempty(indexOfThisStimulusInLibrary) ;
                else
                    isStimulusOK = false ;
                    indexOfThisStimulusInLibrary = [] ;  % could leave un-set, but this *feels* better
                end
            end
            isMultiplierOK = isnumeric(multiplier) && isscalar(multiplier);           
            isChannelNameOK = ischar(channelName) && (isempty(channelName) || isrow(channelName));
            
            % Create the binding
            if isChannelNameOK && isStimulusOK && isMultiplierOK ,
                self.ChannelNames_{end+1}=channelName;
                self.IndexOfEachStimulusInLibrary_{end+1}=indexOfThisStimulusInLibrary;            
                self.Multipliers_(end+1)=multiplier;
                self.IsMarkedForDeletion_(end+1)=false;
            end            
            
            % notify the powers that be
            self.Parent.childMayHaveChanged(self);
        end   % function
        
        function deleteBinding(self, index)
            nBindingsOriginally=length(self.ChannelNames);
            if (1<=index) && (index<=nBindingsOriginally) ,
                self.ChannelNames_(index)=[];
                self.IndexOfEachStimulusInLibrary_(index)=[];
                self.Multipliers_(index)=[];                
                self.IsMarkedForDeletion_(index)=[];                
            end
            self.Parent.childMayHaveChanged(self);            
        end   % function

        function deleteMarkedBindings(self)            
            isMarkedForDeletion = self.IsMarkedForDeletion ;
            self.ChannelNames_(isMarkedForDeletion)=[];
            self.IndexOfEachStimulusInLibrary_(isMarkedForDeletion)=[];
            self.Multipliers_(isMarkedForDeletion)=[];
            self.IsMarkedForDeletion_(isMarkedForDeletion)=[];
            self.Parent.childMayHaveChanged(self);            
        end   % function        
        
%         function replaceStimulus(self, oldStimulus, newStimulus)
%             for idx = 1:numel(self.Bindings) ,
%                 if self.Bindings{idx}.Stimulus == oldStimulus ,
%                     self.Bindings{idx}.Stimulus = newStimulus;
%                 end
%             end
%         end  % function
        
        function nullStimulus(self, stimulus)
            % Set all occurances of stimulus in the self to []
            for i = 1:length(self.Stimuli) ,
                if self.Stimuli{i} == stimulus ,
                    self.Stimuli{i} = [];
                end
            end
        end  % function
        
        function nullStimulusAtBindingIndex(self, bindingIndex)
            % Set all occurances of stimulus in the self to []
            if bindingIndex==round(bindingIndex) && 1<=bindingIndex && bindingIndex<=self.NBindings ,
                self.Stimuli{bindingIndex} = [] ;
            end
        end  % function
        
        function [data, nChannelsWithStimulus] = calculateSignals(self, sampleRate, channelNames, isChannelAnalog, sweepIndexWithinSet)
            % nBoundChannels is the number of channels *in channelNames* for which
            % a non-empty binding was found.
            if ~exist('sweepIndexWithinSet','var') || isempty(sweepIndexWithinSet) ,
                sweepIndexWithinSet=1;
            end
            
            % Create a timeline
            duration = self.Duration ;
            sampleCount = round(duration * sampleRate);
            dt=1/sampleRate;
            t0=0;  % initial sample time
            t=(t0+dt/2)+dt*(0:(sampleCount-1))';            
              % + dt/2 is somewhat controversial, but in the common case
              % that pulse durations are integer multiples of dt, it
              % ensures that each pulse is exactly (pulseDuration/dt)
              % samples long, and avoids other unpleasant pseudorandomness
              % when stimulus discontinuities occur right at sample times
            
            % Create the data array  
            nChannels=length(channelNames);
            data = zeros(sampleCount, nChannels);
            
            % For each named channel, overwrite a col of data
            boundChannelNames=self.ChannelNames;
            nChannelsWithStimulus = 0 ;
            for iChannel = 1:nChannels ,
                thisChannelName=channelNames{iChannel};
                stimIndex = find(strcmp(thisChannelName, boundChannelNames), 1);
                if isempty(stimIndex) ,
                    % do nothing
                else
                    %thisBinding=self.Bindings_{stimIndex};
                    thisStimulus=self.Stimuli{stimIndex}; 
                    if isempty(thisStimulus) ,
                        % do nothing
                    else        
                        % Calc the signal, scale it, overwrite the appropriate col of
                        % data
                        nChannelsWithStimulus = nChannelsWithStimulus + 1 ;
                        rawSignal = thisStimulus.calculateSignal(t, sweepIndexWithinSet);
                        multiplier=self.Multipliers(stimIndex);
                        if isChannelAnalog(iChannel) ,
                            data(:, iChannel) = multiplier*rawSignal ;
                        else
                            data(:, iChannel) = (multiplier*rawSignal>=0.5) ;  % also eliminates nan, sets to false                     
                        end
                    end
                end
            end
        end  % function
        
%         function revive(self,stimuli)
%             for i=1:numel(self) ,
%                 self(i).reviveElement(stimuli);
%             end
%         end  % function

%         function value=get.IsLive(self)   %#ok<MANU>
%             value=true;
% %             nBindings=length(self.ChannelNames);
% %             value=true;
% %             for i=1:nBindings ,
% %                 % A binding is broken when there's a stimulus UUID but no
% %                 % stimulus handle.  It's sound iff it's not broken.
% %                 thisStimulus=self.Stimuli_{i};
% %                 thisStimulusUUID=self.StimulusUUIDs_{i};
% %                 isThisOneLive= ~(isempty(thisStimulus) && ~isempty(thisStimulusUUID)) ;                
% %                 if ~isThisOneLive ,
% %                     value=false;
% %                     break
% %                 end
% %             end
%         end
        
        function setStimulusByName(self, bindingIndex, stimulusName)
            if bindingIndex==round(bindingIndex) && 1<=bindingIndex && bindingIndex<=self.NBindings ,
                library = self.Parent ;
                stimulusIndexInLibrary = library.indexOfStimulusWithName(stimulusName) ;
                if ~isempty(stimulusIndexInLibrary) ,
                    self.IndexOfEachStimulusInLibrary_{bindingIndex} = stimulusIndexInLibrary ;
                end
            end
            self.Parent.childMayHaveChanged(self);
        end
        
        function lines = plot(self, fig, ax, sampleRate)
            if ~exist('ax','var') || isempty(ax)
                ax = axes('Parent',fig);
            end            
            if ~exist('sampleRate','var') || isempty(sampleRate)
                sampleRate = 20000;  % Hz
            end
            
            % Get the channel names
            channelNamesInThisMap=self.ChannelNames;
            
            % Try to determine whether channels are analog or digital.  Fallback to analog, if needed.
            nChannelsInThisMap = length(channelNamesInThisMap) ;
            isChannelAnalog = true(1,nChannelsInThisMap) ;
            stimulusLibrary = self.Parent ;
            if ~isempty(stimulusLibrary) ,
                stimulation = stimulusLibrary.Parent ;
                if ~isempty(stimulation) ,                                    
                    for i = 1:nChannelsInThisMap ,
                        channelName = channelNamesInThisMap{i} ;
                        isChannelAnalog(i) = stimulation.isAnalogChannelName(channelName) ;
                    end
                end
            end
            
            % calculate the signals
            data = self.calculateSignals(sampleRate,channelNamesInThisMap,isChannelAnalog);
            
            %[data, channelNames] = self.calculateSignals(sampleRate, varargin{:});
            n=size(data,1);
            nSignals=size(data,2);
            
            lines = zeros(1, size(data,2));
            
            dt=1/sampleRate;  % s
            time = dt*(0:(n-1))';
            
            %clist = 'bgrycmkbgrycmkbgrycmkbgrycmkbgrycmkbgrycmkbgrycmk';
            clist = ws.utility.make_color_sequence() ;
            
            %set(ax, 'NextPlot', 'Add');

            % Get the list of all the channels in the stimulation subsystem
            stimulation=stimulusLibrary.Parent;
            channelNames=stimulation.ChannelNames;
            
            for idx = 1:nSignals ,
                % Determine the index of the output channel among all the
                % output channels
                thisChannelName = channelNamesInThisMap{idx} ;
                indexOfThisChannelInOverallList = find(strcmp(thisChannelName,channelNames),1) ;                
                lines(idx) = line('Parent',ax, ...
                                  'XData',time, ...
                                  'YData',data(:,idx), ...
                                  'Color',clist(indexOfThisChannelInOverallList,:));
            end
            
            ws.utility.setYAxisLimitsToAccomodateLinesBang(ax,lines);
            legend(ax, channelNamesInThisMap, 'Interpreter', 'None');
            %title(ax,sprintf('Stimulus Map: %s', self.Name));
            xlabel(ax,'Time (s)','FontSize',10);
            ylabel(ax,self.Name,'FontSize',10);
            
            %set(ax, 'NextPlot', 'Replace');
        end        
        
%         function value=isLiveAndSelfConsistent(self)
%             value=false(size(self));
%             for i=1:numel(self) ,
%                 value(i)=self(i).isLiveAndSelfConsistentElement();
%             end
%         end
%         
%         function value=isLiveAndSelfConsistentElement(self) %#ok<MANU>
%             value=true;
% %             nBindings=length(self.ChannelNames);
% %             value=true;
% %             for i=1:nBindings ,
% %                 % A binding is broken when there's a stimulus UUID but no
% %                 % stimulus handle.  It's sound iff it's not broken.
% %                 % It's self-consistent if the locally-stored UUID aggrees
% %                 % with the one in the stimulus object itself.
% %                 thisStimulus=self.Stimuli_{i};
% %                 thisStimulusUUID=self.StimulusUUIDs_{i};
% %                 isThisOneLive= ~(isempty(thisStimulus) && ~isempty(thisStimulusUUID)) ;                
% %                 if isThisOneLive ,
% %                     isThisOneSelfConsistent=(thisStimulus.UUID==thisStimulusUUID);
% %                     if ~isThisOneSelfConsistent ,
% %                         value=false;
% %                         break
% %                     end                    
% %                 else 
% %                     value=false;
% %                     break
% %                 end
% %             end
%         end  % function        

        function result=areAllStimulusIndicesValid(self)
            library = self.Parent ;
            nStimuliInLibrary = length(library.Stimuli) ;
            nStimuli = self.NBindings ;
            for i=1:nStimuli ,
                thisStimulusIndex = self.IndexOfEachStimulusInLibrary_{i} ;
                if isempty(thisStimulusIndex) || ...
                   ( thisStimulusIndex==round(thisStimulusIndex) && 1<=thisStimulusIndex || thisStimulusIndex<=nStimuliInLibrary ) ,
                    % this is all to the good
                else
                    result=false;
                    return
                end
            end
            result=true;
        end
    end  % public methods block
    
    methods (Access = protected)
%         function defineDefaultPropertyTags_(self)
%             % self.setPropertyTags('Name', 'IncludeInFileTypes', {'*'});
%             % self.setPropertyTags('Bindings', 'IncludeInFileTypes', {'*'});
%             self.setPropertyTags('Duration_', 'IncludeInFileTypes', {'*'});            
%         end  % function
        
%         function reviveElement(self,stimuli)
%             nBindings=self.NBindings;
%             for i=1:nBindings ,
%                 self.reviveElementBinding(i,stimuli);
%             end
%         end  % function
        
%         function reviveElementBinding(self,i,stimuli) %#ok<INUSD>
%             % Allows one to re-link a binding to its stimulus, e.g. after
%             % loading from a file.  Tries to find a stimulus in stimuli
%             % with a UUID matching the binding's stored stimulus UUID.            
%             stimulusUUID=self.StimulusUUIDs_{i};
%             uuids=ws.utility.cellArrayPropertyAsArray(stimuli,'UUID');
%             isMatch=(uuids==stimulusUUID);
%             iMatch=find(isMatch,1);
%             if isempty(iMatch) ,
%                 self.Stimuli_{i}=[];  % this will at least make it so Stimuli_ has the right number of elements
%             else                
%                 self.Stimuli_{i}=stimuli{iMatch};
%             end                
%         end  % function
    end
    
    methods
        function value=isequal(self,other)
            value=isequalHelper(self,other,'ws.stimulus.StimulusMap');
        end  % function    
    end  % methods
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            % Test for "value equality" of two scalar StimulusMap's
            propertyNamesToCompare={'Name' 'Duration' 'ChannelNames' 'IndexOfEachStimulusInLibrary' 'Multipliers'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
       end  % function
    end  % methods
    
    methods
        function other=copyGivenParent(self,parent)
            % Makes a "copy" of self, but where other.Stimuli_ point to
            % elements of otherStimulusDictionary.  StimulusMaps are not
            % meant to be free-standing objects, and so are not subclassed
            % from matlab.mixin.Copyable.
            
            % Do the easy part
            other=ws.stimulus.StimulusMap(parent);
            other.Name_ = self.Name_ ;
            other.ChannelNames_ = self.ChannelNames_ ;
            other.IndexOfEachStimulusInLibrary_ = self.IndexOfEachStimulusInLibrary_ ;
            other.Multipliers_ = self.Multipliers_ ;
            other.IsMarkedForDeletion_ = self.IsMarkedForDeletion_ ;
            other.Duration_ = self.Duration_ ;

%             % re-do the bindings so that they point to corresponding
%             % elements of otherStimuli
%             nStimuli=length(self.ChannelNames);
%             other.Stimuli_ = cell(1,nStimuli);
%             %uuids=ws.utility.cellArrayPropertyAsArray(selfStimuli,'UUID');
%             for j=1:nStimuli ,
%                 %uuidOfThisStimulusInSelf=self.StimulusUUIDs_{j};
%                 thisStimulusInSelf=self.Stimuli_{j};
%                 %indexOfThisStimulusInLibrary=find(uuidOfThisStimulusInSelf==uuids);
%                 if isempty(thisStimulusInSelf) ,
%                     isMatch = false(size(selfStimulusDictionary));
%                 else
%                     isMatch = cellfun(@(stimulus)(stimulus==thisStimulusInSelf),selfStimulusDictionary);
%                 end
%                 indexOfThisStimulusInDictionary=find(isMatch,1);
%                 if isempty(indexOfThisStimulusInDictionary) ,
%                     other.Stimuli_{j}=[];
%                 else
%                     other.Stimuli_{j}=otherStimulusDictionary{indexOfThisStimulusInDictionary};
%                 end
%             end
        end  % function
    end  % methods
    
%     methods (Access = protected)
%         function other = copyElement(self)
%             % Perform the standard copy.
%             other = copyElement@matlab.mixin.Copyable(self);
%             
%             % Change the uuid.
%             %other.UUID = rand();
% 
%             other.Parent=[];  % Don't want this to point to self's Parent
%         end
%     end
    
%     methods (Access=protected)
%         function defineDefaultPropertyTags_(self)
%             defineDefaultPropertyTags_@ws.Model(self);
%             %self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
%         end
%     end
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct() ;
%         mdlHeaderExcludeProps = {};
%     end
    
    methods (Access=protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
%     methods (Static)
%         function s = propertyAttributes()
%             s = struct();
%             
%             s.Name = struct('Classes', 'char');
%             s.Duration = struct('Classes', 'numeric', ...
%                                 'Attributes', {{'scalar', 'nonnegative', 'real', 'finite'}});
%             s.ChannelNames = struct('Classes', 'string');
%             s.Multipliers = struct('Classes', 'numeric', 'Attributes', {{'row', 'real', 'finite'}});
%             s.Stimuli = struct('Classes', 'ws.stimulus.StimulusMap');                            
%         end  % function
%         
% %         function self = loadobj(self)
% %             self.IsMarkedForDeletion_ = false(size(self.ChannelNames_));
% %               % Is MarkedForDeletion_ is transient
% %         end
%     end  % class methods block
    
end
