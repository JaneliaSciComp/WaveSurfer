classdef PezUserClass < ws.UserClass
    properties (Constant, Transient)  % Transient so doesn't get written to data files
        TrialSequenceModeOptions = {'all-1' 'all-2' 'alternating' 'random'} ;
    end

    properties (Constant)
        ComPortName = 'COM3' ;
    end
    
    properties (Dependent)
        TrialSequenceMode
        RandomTrialSequenceMaximumRunLength
        
        ToneFrequency1
        ToneDelay1
        ToneDuration1
        DispenseDelay1
        DeliverPosition1X
        DeliverPosition1Y
        DeliverPosition1Z
        DispensePosition1X
        DispensePosition1Y
        DispensePosition1Z

        ToneFrequency2
        ToneDelay2
        ToneDuration2
        DispenseDelay2
        DeliverPosition2X
        DeliverPosition2Y
        DeliverPosition2Z
        DispensePosition2X
        DispensePosition2Y
        DispensePosition2Z
        
        ReturnDelay

        TapCount
        DispenseSpeedX
        DispenseSpeedY
        DispenseSpeedZ
        RandomTrialSequenceLaserTrialSpacing  % only matters for random trials
        
        TrialSequence  % 1 x sweepCount, each element 1 or 2        
        IsRunning
        IsResetEnabled
        IsTrialSequenceDeterministic
        
        IsFigurePositionSaved
        SavedFigurePosition
    end  % properties
    
    properties (Access=protected)
        TrialSequenceMode_ = 'alternating'  % can be 'all-1', 'all-2', 'alternating', or 'random'
        RandomTrialSequenceMaximumRunLength_ = 3
        
        ToneFrequency1_ = 3000  % Hz
        ToneDelay1_ = 1  % s
        ToneDuration1_ = 1  % s
        DispenseDelay1_ = 1  % s
        DeliverPosition1X_ =  60  % mm?
        DeliverPosition1Y_ =  60  % mm?
        DeliverPosition1Z_ =  10  % mm?
        DispensePosition1X_ =  60  % mm?
        DispensePosition1Y_ =  60  % mm?
        DispensePosition1Z_ = 12  % scalar, mm?, the vertical delta from the deliver position to the dispense position

        ToneFrequency2_ = 10000  % Hz
        ToneDelay2_ = 1  % s
        ToneDuration2_ = 1  % s
        DispenseDelay2_ = 1  % s
        DeliverPosition2X_ =  60  % mm?
        DeliverPosition2Y_ =  60  % mm?
        DeliverPosition2Z_ = 10  % mm?
        DispensePosition2X_ =  60  % mm?
        DispensePosition2Y_ =  60  % mm?
        DispensePosition2Z_ = 12  % scalar, mm?
        
        ReturnDelay_ = 1  % s, the duration the piston holds at the dispense position
        
        TapCount_ = 3
        DispenseSpeedX_ = 250
        DispenseSpeedY_ = 250
        DispenseSpeedZ_ = 250                
        RandomTrialSequenceLaserTrialSpacing_ = +inf
        
        IsFigurePositionSaved_ = false
        SavedFigurePosition_ = []
    end  % properties

    properties (Access=protected, Transient=true)
        PezDispenser_
        TrialSequence_
        Controller_
        IsRunning_ = false
        IsResetInATimeout_ = false
        ResetTimeoutTimer_
    end
    
    methods
        function self = PezUserClass()
            % Creates the "user object"
            fprintf('Instantiating an instance of PezUserClass.\n');
        end
        
        function wake(self, rootModel)
            fprintf('Waking an instance of PezUserClass.\n');
            if isa(rootModel, 'ws.WavesurferModel') && rootModel.IsITheOneTrueWavesurferModel ,
                ws.examples.pez.PezController(self) ;  % this will register the controller with self
                self.Controller_.syncFigurePosition() ;
            end
        end
        
        function delete(self)
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
            fprintf('An instance of PezUserClass is being deleted.\n');
            if ~isempty(self.ResetTimeoutTimer_) && isvalid(self.ResetTimeoutTimer_) ,
                stop(self.ResetTimeoutTimer_) ;
                delete(self.ResetTimeoutTimer_) ;
            end
            if ~isempty(self.Controller_) && isvalid(self.Controller_) ,
                delete(self.Controller_) ;
            end
        end
        
        function willSaveToProtocolFile(self, wsModel)  %#ok<INUSD>
            controller = self.Controller_ ;
            if ~isempty(controller) ,
                position = controller.FigurePosition ;
                self.SavedFigurePosition_ = position ;
                self.IsFigurePositionSaved_ = true ;
            end
        end
        
        function startingRun(self, wsModel)
            % Called just before each set of sweeps (a.k.a. each
            % "run")
            fprintf('About to start a run in PezUserClass.\n');
            sweepCount = wsModel.NSweepsPerRun ;
            if isequal(self.TrialSequenceMode, 'all-1') 
                self.TrialSequence_ = repmat(1, [1 sweepCount]) ;  %#ok<REPMAT>
            elseif isequal(self.TrialSequenceMode, 'all-2') 
                self.TrialSequence_ = repmat(2, [1 sweepCount]) ;
            elseif isequal(self.TrialSequenceMode, 'alternating')
                self.TrialSequence_ = repmat([1 2], [1 ceil(sweepCount/2)]) ;
            elseif isequal(self.TrialSequenceMode, 'random') 
                maximumRunLength = self.RandomTrialSequenceMaximumRunLength ;
                laserTrialSpacing = self.RandomTrialSequenceLaserTrialSpacing ;
                trialSequence = ws.examples.pez.randomTrialSequence(sweepCount, maximumRunLength, laserTrialSpacing) ;
                self.TrialSequence_ = trialSequence ;
            else
                error('Unrecognized TrialSequenceMode: %s', self.TrialSequenceMode) ;
            end
            self.IsRunning_ = true ;
            self.PezDispenser_ = ws.examples.pez.ModularClient(self.ComPortName) ;
            self.PezDispenser_.open() ;
            % Need to set the nextDeliverPosition to the position for the first trail,
            % then give the .startAssay() command to get the Arduino to position the stage
            % appropriately.
            if sweepCount > 0 ,
                firstTrialType = self.TrialSequence_(1) ;
                if firstTrialType == 1 ,
                    self.PezDispenser_.nextDeliverPosition(...
                        'setValue', [self.DeliverPosition1Z self.DeliverPosition1X self.DeliverPosition1Y]) ;
                    %self.PezDispenser_.nextDispensePosition(...
                    %    'setValue', [self.DispensePosition1Z self.DispensePosition1X self.DispensePosition1Y]) ;
                else
                    self.PezDispenser_.nextDeliverPosition(...
                        'setValue', [self.DeliverPosition2Z self.DeliverPosition2X self.DeliverPosition2Y]) ;
                    %self.PezDispenser_.nextDispensePosition(...
                    %    'setValue', [self.DispensePosition2Z self.DispensePosition2X self.DispensePosition2Y]) ;
                end
                self.PezDispenser_.startAssay() ;
                % Wait for Arduino to be ready
                ticId = tic() ;
                while toc(ticId) < 30 ,
                    stateStruct = self.PezDispenser_.getAssayStatus() ;
                    status = stateStruct.state ;
                    isReadyToDispense = isequal(status, 'READY_TO_DISPENSE') ;
                    if isReadyToDispense ,
                        break
                    end
                    pause(1) ;
                end
                if ~isReadyToDispense ,
                    self.tellControllerToUpdateIfPresent_() ;
                    error('Pez dispenser failed to get ready in the alloted time') ;
                end
            end
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function completingRun(self,wsModel)  %#ok<INUSD>
            % Called just after each set of sweeps (a.k.a. each
            % "run")
            fprintf('Completed a run in PezUserClass.\n');
            self.PezDispenser_.close() ;
            delete(self.PezDispenser_) ;
            self.PezDispenser_ = [] ;
            self.IsRunning_ = false ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function stoppingRun(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('User stopped a run in PezUserClass.\n');
            self.PezDispenser_.abort() ;
            self.PezDispenser_.close() ;
            delete(self.PezDispenser_) ;
            self.PezDispenser_ = [] ;
            self.IsRunning_ = false ;
            self.tellControllerToUpdateIfPresent_() ;
        end        
        
        function abortingRun(self,wsModel)  %#ok<INUSD>
            % Called if a run goes wrong, after the call to
            % abortingSweep()
            fprintf('Oh noes!  A run aborted in PezUserClass.\n');
            self.PezDispenser_.abort() ;
            self.PezDispenser_.close() ;
            delete(self.PezDispenser_) ;
            self.PezDispenser_ = [] ;
            self.IsRunning_ = false ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function startingSweep(self,wsModel)
            % Called just before each sweep
            fprintf('About to start a sweep in PezUserClass.\n');
            sweepIndex = wsModel.NSweepsCompletedInThisRun + 1 ;
            trialType = self.TrialSequence_(sweepIndex) ;
                        
            if trialType == 1 ,
                self.PezDispenser_.positionToneFrequency('setValue', self.ToneFrequency1) ;
                self.PezDispenser_.positionToneDelay('setValue', self.ToneDelay1) ;
                self.PezDispenser_.positionToneDuration('setValue', self.ToneDuration1) ;
                self.PezDispenser_.dispenseDelay('setValue', self.DispenseDelay1) ;
                %self.PezDispenser_.dispenseChannelPosition('setValue', self.DispensePosition1Z) ;
                self.PezDispenser_.nextDispensePosition('setValue', [self.DispensePosition1Z self.DispensePosition1X self.DispensePosition1Y]) ;
                self.PezDispenser_.position('setValue', 'LEFT') ;
            else
                self.PezDispenser_.positionToneFrequency('setValue', self.ToneFrequency2) ;
                self.PezDispenser_.positionToneDelay('setValue', self.ToneDelay2) ;
                self.PezDispenser_.positionToneDuration('setValue', self.ToneDuration2) ;
                self.PezDispenser_.dispenseDelay('setValue', self.DispenseDelay2) ;
                %self.PezDispenser_.dispenseChannelPosition('setValue', self.DispensePosition2Z) ;
                self.PezDispenser_.nextDispensePosition('setValue', [self.DispensePosition2Z self.DispensePosition2X self.DispensePosition2Y]) ;
                self.PezDispenser_.position('setValue', 'RIGHT') ;
            end

            % We need to tell the Arduino the delivery position for the *next* sweep, so
            % that it goes to the right spot at the end.
            nextSweepIndex = sweepIndex + 1 ;
            if nextSweepIndex > length(self.TrialSequence_) ,
                nextSweepIndex = sweepIndex ;
            end
            nextTrialType = self.TrialSequence_(nextSweepIndex) ;
            
            % Note well: We have to permute the permission coordinates so that they match
            % user expectations, given the orientation of the stage.  To the Arduino,
            % increasing x means "piston more extended".  If we used Ardunio-native coords, 
            %
            %   increasing x == upward
            %   increasing y == rightward
            %   increasing z == away
            %
            % (All of these are from the POV of the experimenter, sitting in front of the
            % rig.)
            %
            % We want increasing z to be upwards, and to keep the coordinate system
            % right-handed.  So we'll have a "user" coord system s.t.:
            %
            %   increasing x == rightward
            %   increasing y == away
            %   increasing z == upward
            %
            % Thus:
            %
            %   user x == arduino y
            %   user y == arduino z
            %   uzer z == arduino x
            %
            % I.e.
            %   arduino x == user z
            %   arduino y == user x
            %   arduino z == user y
            %
            % So, long story short, we permute the user coords to get arduino coords            
            if nextTrialType == 1 ,
                self.PezDispenser_.nextDeliverPosition('setValue', [self.DeliverPosition1Z self.DeliverPosition1X self.DeliverPosition1Y]) ;
                %self.PezDispenser_.nextDispensePosition('setValue', [self.DispensePosition1Z self.DispensePosition1X self.DispensePosition1Y]) ;
            else
                self.PezDispenser_.nextDeliverPosition('setValue', [self.DeliverPosition2Z self.DeliverPosition2X self.DeliverPosition2Y]) ;
                %self.PezDispenser_.nextDispensePosition('setValue', [self.DispensePosition2Z self.DispensePosition2X self.DispensePosition2Y]) ;
            end                
            self.PezDispenser_.returnDelayMin('setValue', self.ReturnDelay) ;
            self.PezDispenser_.returnDelayMax('setValue', self.ReturnDelay) ;
            self.PezDispenser_.tapCount('setValue', self.TapCount) ;
            
            %self.PezDispenser_.toneDelayMin('setValue', 0) ;  % Just to make sure, since we're not using toneDelay any more
            %self.PezDispenser_.toneDelayMax('setValue', 0) ;            
            %dispenseToneVolume = ws.fif(self.DoPlayDispenseTone, self.DispenseToneVolumeWhenPlayed_, 0) ;
            %self.PezDispenser_.dispenseToneVolume('setValue', dispenseToneVolume) ;
            %self.PezDispenser_.dispenseToneFrequency('setValue', self.DispenseToneFrequency) ;
        end
        
        function completingSweep(self,wsModel)  %#ok<INUSD>
            % Called after each sweep completes
            fprintf('Completed a sweep in PezUserClass.\n');
        end
        
        function stoppingSweep(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('User stopped a sweep in PezUserClass.\n');
        end        
        
        function abortingSweep(self,wsModel)  %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('Oh noes!  A sweep aborted in PezUserClass.\n');
        end        
        
        function dataAvailable(self, wsModel)  %#ok<INUSD>
            % Called each time a "chunk" of data (typically 100 ms worth) 
            % has been accumulated from the looper.
            %analogData = wsModel.getLatestAIData();
            %digitalData = wsModel.getLatestDIData();  %#ok<NASGU>
            %nScans = size(analogData,1);
            %fprintf('Just read %d scans of data in PezUserClass.\n', nScans);                                    
        end
        
        function samplesAcquired(self, looper, analogData, digitalData)  %#ok<INUSD>
            % Called each time a "chunk" of data (typically a few ms worth) 
            % is read from the DAQ board.
            %nScans = size(analogData,1);
            %fprintf('Just acquired %d scans of data in PezUserClass.\n', nScans);                                    
        end
        
        function startingEpisode(self,refiller)  %#ok<INUSD>
            % Called just before each episode
            fprintf('About to start an episode in PezUserClass.\n');
        end
        
        function completingEpisode(self,refiller)  %#ok<INUSD>
            % Called after each episode completes
            fprintf('Completed an episode in PezUserClass.\n');
        end
        
        function stoppingEpisode(self,refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
            fprintf('User stopped an episode in PezUserClass.\n');
        end        
        
        function abortingEpisode(self,refiller)  %#ok<INUSD>
            % Called if a episode goes wrong
            fprintf('Oh noes!  An episode aborted in PezUserClass.\n');
        end
    end  % public methods
        
    methods
        function result = get.TrialSequence(self)
            result = self.TrialSequence_ ;        
        end
        
        function result = get.RandomTrialSequenceMaximumRunLength(self)
            result = self.RandomTrialSequenceMaximumRunLength_ ;
        end
        
        function result = get.TrialSequenceMode(self)
            result = self.TrialSequenceMode_ ;
        end
        
        function result = get.ToneFrequency1(self)
            result = self.ToneFrequency1_ ;
        end
        
        function result = get.DeliverPosition1X(self)
            result = self.DeliverPosition1X_ ;
        end
        
        function result = get.DeliverPosition1Y(self)
            result = self.DeliverPosition1Y_ ;
        end
        
        function result = get.DeliverPosition1Z(self)
            result = self.DeliverPosition1Z_ ;
        end
        
        function result = get.DispensePosition1X(self)
            result = self.DispensePosition1X_ ;
        end
        
        function result = get.DispensePosition1Y(self)
            result = self.DispensePosition1Y_ ;
        end
        
        function result = get.DispensePosition1Z(self)
            result = self.DispensePosition1Z_ ;
        end
        
        function result = get.ToneFrequency2(self)
            result = self.ToneFrequency2_ ;
        end
        
        function result = get.DeliverPosition2X(self)
            result = self.DeliverPosition2X_ ;
        end
        
        function result = get.DeliverPosition2Y(self)
            result = self.DeliverPosition2Y_ ;
        end
        
        function result = get.DeliverPosition2Z(self)
            result = self.DeliverPosition2Z_ ;
        end
        
        function result = get.DispensePosition2X(self)
            result = self.DispensePosition2X_ ;
        end
        
        function result = get.DispensePosition2Y(self)
            result = self.DispensePosition2Y_ ;
        end
        
        function result = get.DispensePosition2Z(self)
            result = self.DispensePosition2Z_ ;
        end
        
        function result = get.ToneDelay1(self)
            result = self.ToneDelay1_ ;
        end
        
        function result = get.ToneDuration1(self)
            result = self.ToneDuration1_ ;
        end
        
        function result = get.DispenseDelay1(self)
            result = self.DispenseDelay1_ ;
        end
        
        function result = get.ToneDelay2(self)
            result = self.ToneDelay2_ ;
        end
        
        function result = get.ToneDuration2(self)
            result = self.ToneDuration2_ ;
        end
        
        function result = get.DispenseDelay2(self)
            result = self.DispenseDelay2_ ;
        end
        
        function result = get.ReturnDelay(self)
            result = self.ReturnDelay_ ;
        end
        
        function result = get.TapCount(self)
            result = self.TapCount_ ;
        end

        function result = get.DispenseSpeedX(self)
            result = self.DispenseSpeedX_ ;
        end

        function result = get.DispenseSpeedY(self)
            result = self.DispenseSpeedY_ ;
        end

        function result = get.DispenseSpeedZ(self)
            result = self.DispenseSpeedZ_ ;
        end
        
        function result = get.RandomTrialSequenceLaserTrialSpacing(self)
            result = self.RandomTrialSequenceLaserTrialSpacing_ ;
        end
        
        function result = get.IsTrialSequenceDeterministic(self)
            result = ~isequal(self.TrialSequenceMode, 'random') ;
        end
        
%         function result = get.DispenseToneFrequency(self)
%             result = self.DispenseToneFrequency_ ;
%         end        
%         
%         function result = get.DoPlayDispenseTone(self)
%             result = self.DoPlayDispenseTone_ ;
%         end        
        
        function set.TrialSequenceMode(self, newValue) 
            if ~any(strcmp(newValue, self.TrialSequenceModeOptions))
                error('ws:invalidPropertyValue', ...
                      'TrialSequenceMode must be one of ''all-1'', ''all-2'', ''alternating'', ''random'', or ''random-laser''') ;
            end
            self.TrialSequenceMode_ = newValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end        
                
        function set.ToneFrequency1(self, newValue)
            screenedValue = self.screenValue_('ToneFrequency1', newValue) ;
            self.ToneFrequency1_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition1X(self, newValue)
            screenedValue = self.screenValue_('DeliverPosition1X', newValue) ;
            self.DeliverPosition1X_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition1Y(self, newValue)
            screenedValue = self.screenValue_('DeliverPosition1Y', newValue) ;
            self.DeliverPosition1Y_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition1Z(self, newValue)
            screenedValue = self.screenValue_('DeliverPosition1Z', newValue) ;
            self.DeliverPosition1Z_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispensePosition1X(self, newValue)
            screenedValue = self.screenValue_('DispensePosition1X', newValue) ;
            self.DispensePosition1X_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispensePosition1Y(self, newValue)
            screenedValue = self.screenValue_('DispensePosition1Y', newValue) ;
            self.DispensePosition1Y_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispensePosition1Z(self, newValue)
            screenedValue = self.screenValue_('DispensePosition1Z', newValue) ;
            self.DispensePosition1Z_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ToneFrequency2(self, newValue)
            screenedValue = self.screenValue_('ToneFrequency2', newValue) ;
            self.ToneFrequency2_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition2X(self, newValue)
            screenedValue = self.screenValue_('DeliverPosition2X', newValue) ;
            self.DeliverPosition2X_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition2Y(self, newValue)
            screenedValue = self.screenValue_('DeliverPosition2Y', newValue) ;
            self.DeliverPosition2Y_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DeliverPosition2Z(self, newValue)
            screenedValue = self.screenValue_('DeliverPosition2Z', newValue) ;
            self.DeliverPosition2Z_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispensePosition2X(self, newValue)
            screenedValue = self.screenValue_('DispensePosition2X', newValue) ;
            self.DispensePosition2X_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispensePosition2Y(self, newValue)
            screenedValue = self.screenValue_('DispensePosition2Y', newValue) ;
            self.DispensePosition2Y_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispensePosition2Z(self, newValue)
            screenedValue = self.screenValue_('DispensePosition2Z', newValue) ;
            self.DispensePosition2Z_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ToneDelay1(self, newValue)
            screenedValue = self.screenValue_('ToneDelay1', newValue) ;
            self.ToneDelay1_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ToneDuration1(self, newValue)
            screenedValue = self.screenValue_('ToneDuration1', newValue) ;
            self.ToneDuration1_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispenseDelay1(self, newValue)
            screenedValue = self.screenValue_('DispenseDelay1', newValue) ;
            self.DispenseDelay1_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ToneDelay2(self, newValue)
            screenedValue = self.screenValue_('ToneDelay2', newValue) ;
            self.ToneDelay2_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ToneDuration2(self, newValue)
            screenedValue = self.screenValue_('ToneDuration2', newValue) ;
            self.ToneDuration2_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispenseDelay2(self, newValue)
            screenedValue = self.screenValue_('DispenseDelay2', newValue) ;
            self.DispenseDelay2_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.ReturnDelay(self, newValue)
            screenedValue = self.screenValue_('ReturnDelay', newValue) ;
            self.ReturnDelay_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end

        function set.TapCount(self, newValue)
            screenedValue = self.screenValue_('TapCount', newValue) ;
            self.TapCount_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispenseSpeedX(self, newValue)
            screenedValue = self.screenValue_('DispenseSpeedX', newValue) ;
            self.DispenseSpeedX_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispenseSpeedY(self, newValue)
            screenedValue = self.screenValue_('DispenseSpeedY', newValue) ;
            self.DispenseSpeedY_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function set.DispenseSpeedZ(self, newValue)
            screenedValue = self.screenValue_('DispenseSpeedZ', newValue) ;
            self.DispenseSpeedZ_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end

        function set.RandomTrialSequenceLaserTrialSpacing(self, newValue)
            screenedValue = self.screenValue_('RandomTrialSequenceLaserTrialSpacing', newValue) ;
            self.RandomTrialSequenceLaserTrialSpacing_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end

        function set.RandomTrialSequenceMaximumRunLength(self, newValue)
            screenedValue = self.screenValue_('RandomTrialSequenceMaximumRunLength', newValue) ;
            self.RandomTrialSequenceMaximumRunLength_ = screenedValue ;
            self.tellControllerToUpdateIfPresent_() ;
        end

        function result = get.IsRunning(self)
            result = self.IsRunning_ ;            
        end
        
        function result = get.IsResetEnabled(self)
            result = ~self.IsRunning_ && ~self.IsResetInATimeout_ ;            
        end

        function clearIsRunning_(self)
            self.IsRunning_ = false ;
            self.tellControllerToUpdateIfPresent_() ;
        end
        
        function clearIsResetInATimeout_(self)
            if ~isempty(self.ResetTimeoutTimer_) ,
                stop(self.ResetTimeoutTimer_) ;
                delete(self.ResetTimeoutTimer_) ;
                self.ResetTimeoutTimer_ = [] ;
                self.IsResetInATimeout_ = false ;
                self.tellControllerToUpdateIfPresent_() ;
            end
        end
        
        function reset(self)
            if self.IsResetEnabled ,
                self.IsResetInATimeout_ = true ;
                self.tellControllerToUpdateIfPresent_() ;
                self.PezDispenser_ = ws.examples.pez.ModularClient(self.ComPortName) ;
                self.PezDispenser_.open() ;
                self.PezDispenser_.reset() ;
                %self.PezDispenser_.close() ;
                delete(self.PezDispenser_) ;
                self.PezDispenser_ = [] ;
                self.ResetTimeoutTimer_ = ...
                    timer('ExecutionMode', 'singleShot', ...
                          'StartDelay', 30, ...
                          'TimerFcn', @(~,~)(self.clearIsResetInATimeout_()), ...
                          'ErrorFcn', @(~,~)(fprintf('WTF?!\n'))) ;                          
                start(self.ResetTimeoutTimer_) ;      
            else
                error('Reset is not currently enabled.') ;
            end
        end
        
        function registerController(self, controller)
            self.Controller_ = controller ;
        end
        
        function clearController(self)
            self.Controller_ = [] ;
        end
        
        function result = get.IsFigurePositionSaved(self)
            result = self.IsFigurePositionSaved_ ;
        end
        
        function result = get.SavedFigurePosition(self)
            if self.IsFigurePositionSaved_ ,                
                result = self.SavedFigurePosition_ ;
            else
                result = [] ;
            end
        end
        
    end  % public methods
    
    methods (Access=protected)
        function tellControllerToUpdateIfPresent_(self)
            if ~isempty(self.Controller_) ,
                self.Controller_.update() ;
            end
        end
        
        function screenedValue = screenValue_(self, propertyName, newValue)  %#ok<INUSL>
            if isequal(propertyName, 'ReturnDelay') ,
                if ~( isscalar(newValue) && isreal(newValue) && isfinite(newValue) && 1<=newValue && newValue<=3600) ,
                    error('ws:invalidPropertyValue', 'ReturnDelay property value is invalid') ;
                end
                screenedValue = newValue ;
            elseif isequal(propertyName, 'TapCount') ,
                screenedValue = round(real(newValue)) ;
                if ~( isscalar(screenedValue) && isfinite(screenedValue) && 1<=screenedValue && screenedValue<=5) ,
                    error('ws:invalidPropertyValue', 'TapCount property value is invalid') ;
                end                                    
            elseif isequal(propertyName, 'RandomTrialSequenceMaximumRunLength') ,
                screenedValue = round(real(newValue)) ;
                if ~( isscalar(screenedValue) && ~isnan(screenedValue) && 2<=screenedValue ) ,
                    error('ws:invalidPropertyValue', 'RandomTrialSequenceMaximumRunLength property value is invalid') ;
                end                                    
            elseif isequal(propertyName, 'RandomTrialSequenceLaserTrialSpacing') ,
                screenedValue = round(real(newValue)) ;
                if ~( isscalar(screenedValue) && ~isnan(screenedValue) && 1<=screenedValue ) ,
                    error('ws:invalidPropertyValue', 'RandomTrialSequenceLaserTrialSpacing property value is invalid') ;
                end                                    
            elseif isequal(propertyName, 'DispensePosition1Z') || ...
                   isequal(propertyName, 'DispensePosition2Z') || ...
                   isequal(propertyName, 'DeliverPosition1Z') || ...
                   isequal(propertyName, 'DeliverPosition2Z'),
                screenedValue = round(newValue) ;
                if ~( isscalar(screenedValue ) && isreal(screenedValue ) && isfinite(screenedValue ) && (0<=screenedValue ) && (screenedValue <=20) ) ,
                    error('ws:invalidPropertyValue', 'Z Position property value is invalid') ;
                end
            elseif ~isempty(strfind(propertyName, 'Position')) ,  %#ok<STREMP>
                screenedValue = round(newValue) ;
                if ~( isscalar(screenedValue ) && isreal(screenedValue ) && isfinite(screenedValue ) && (0<=screenedValue ) && (screenedValue <=+100) ) ,
                    error('ws:invalidPropertyValue', 'Position property value is invalid') ;
                end
            elseif ~isempty(strfind(propertyName, 'Speed')) ,  %#ok<STREMP>
                screenedValue = round(newValue) ;
                if ~( isscalar(screenedValue ) && isreal(screenedValue ) && isfinite(screenedValue ) && (1<=screenedValue ) && (screenedValue <=500) ) ,
                    error('ws:invalidPropertyValue', 'Speed property value is invalid') ;
                end
            elseif ~isempty(strfind(propertyName, 'Duration')) ,  %#ok<STREMP>
                if ~( isscalar(newValue) && isreal(newValue) && isfinite(newValue) && 0<=newValue ) ,
                    error('ws:invalidPropertyValue', 'Duration property value is invalid') ;
                end                    
                screenedValue = newValue ;
            elseif ~isempty(strfind(propertyName, 'Delay')) ,  %#ok<STREMP>
                if ~( isscalar(newValue) && isreal(newValue) && isfinite(newValue) && 0<=newValue ) ,
                    error('ws:invalidPropertyValue', 'Delay property value is invalid') ;
                end                    
                screenedValue = newValue ;
            elseif ~isempty(strfind(propertyName, 'Frequency')) ,  %#ok<STREMP>
                screenedValue = round(newValue) ;
                if ~( isscalar(screenedValue ) && isreal(screenedValue ) && isfinite(screenedValue ) && 0<screenedValue  ) ,
                    error('ws:invalidPropertyValue', 'Frequency property value is invalid') ;
                end                    
            else
                error('Unrecognized property name') ;
            end
        end
    end  % protected methods block
    
    methods
        function out = getPropertyValue_(self, name)
            % This allows public access to private properties in certain limited
            % circumstances, like persisting.
            out = self.(name);
        end
        
        function setPropertyValue_(self, name, value)
            % This allows public access to private properties in certain limited
            % circumstances, like persisting.
            self.(name) = value;
        end
    end  % protected
    
    methods
        function mimic(self, other)
            ws.mimicBang(self, other) ;
        end
    end    
    
    methods
        % These are intended for getting/setting *public* properties.
        % I.e. they are for general use, not restricted to special cases like
        % encoding or ugly hacks.
        function result = get(self, propertyName) 
            result = self.(propertyName) ;
        end
        
        function set(self, propertyName, newValue)
            self.(propertyName) = newValue ;
        end           
    end  % public methods block            
        
end  % classdef

