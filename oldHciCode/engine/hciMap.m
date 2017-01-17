classdef hciMap < hgsetget
    properties
        nucleusMapStructure
        
        % This is a structure used by the Nucleus Matlab Toolbox to talk to
        % the device.  It should be set every time a new map is loaded (and
        % the previous version should be shut down).
        NMTclient
        
        % According to the NucleusMatlabToolbox.ppt documentation (July
        % 31st, 2002), slide 19, there is no way to tell when streaming has
        % concluded and streaming has a 350 ms latency.
        % CST 2/6/13 - 350 ms does not appear to be enough
        streamLatency = 0.7;
        
        % If an error occurs and a stimulus was not sent, this structure
        % contains information about why
        stimulusErrorStructure
        
        % To handle loudness issues with changing pulse rate, changes in
        % T's and C's must be estimated for the range of pulse rates.
        pulseRateRange = [200 1600];
        rateSteps = 100;
        
        maxCLevel = 255;
        
        verboseText = false;
        
        upSend;
        
        downSend;
        
        deviceStimulationFailureCallback = [];
        catestrophicFailure = false;
    end
    methods
        % Initialize map
        function self = hciMap(initMap)
            if isstruct(initMap)
                self.nucleusMapStructure = initMap;
            elseif ischar(initMap)
                readMap(self,initMap)
            end
        end
        
        function startProcessor(self)
            if (hciUtilHaveNmtButNoHardwareDebugMode || hciUtilNoHardwareDebugMode)
                % Debugging
                disp('Starting processor...')
                self.NMTclient = 'on';
            else
                try 
                    client = NICStreamClient;
                    client = initialiseClient(client, ['L34-' self.nucleusMapStructure.implant.IC '-1']);
                    self.NMTclient = client;
                catch clientError
                    self.stimulusErrorStructure.map = self.nucleusMapStructure;
                    self.stimulusErrorStructure.errorMsg = clientError.message;
                    deviceStimulationFailure(self);
                end
            end
        end
        
        function stopProcessor(self)
            if (hciUtilHaveNmtButNoHardwareDebugMode || hciUtilNoHardwareDebugMode)
                % Debugging
                disp('Stopping processor...')
                self.NMTclient = [];
            else            
                try
                    shutdownClient(self.NMTclient);
                    self.NMTclient = [];
                catch clientError
                    self.stimulusErrorStructure.map = self.nucleusMapStructure;
                    self.stimulusErrorStructure.errorMsg = clientError.message;
                    deviceStimulationFailure(self);
                end
            end
        end
        
        function streamSequence(self,client,sequenceStruct,sequenceDuration)
            if (hciUtilHaveNmtButNoHardwareDebugMode || hciUtilNoHardwareDebugMode)
                disp('Sending stimulus...')
            else
                try
                    self.NMTclient = NIC_stream_sequence(client,sequenceStruct);
                catch streamError
                    self.stimulusErrorStructure.map = self.nucleusMapStructure;
                    self.stimulusErrorStructure.client = client;
                    self.stimulusErrorStructure.seq = sequenceStruct;
                    self.stimulusErrorStructure.seqDur = sequenceDuration;
                    self.stimulusErrorStructure.errorMsg = streamError.message;
                    deviceStimulationFailure(self);
                end
            end
            seqDependentPause = (0.0395*sequenceDuration^2) + (0.0218*sequenceDuration) + 0.6386;
            disp(['Sequence duration: ' num2str(sequenceDuration)])
            disp(['Sequence pause: ' num2str(seqDependentPause)])
            pause(sequenceDuration + seqDependentPause)
        end
        
        function saveMap(self,fileName)
            map = self.nucleusMapStructure; %#ok<NASGU>
            save(fileName,'map');
        end
        
        function saveError(self,fileName)
            errorStruct = self.stimulusErrorStructure;
            save(fileName,'errorStruct')
            
            % Reset error structure
            self.stimulusErrorStructure = [];
        end
        
        function readMap(self,fileName)
            assert(exist(fileName,'file')==2,'specified Nucleus map mat file does not appear to exist.');
            
            matFileContents = load(fileName);
            fnames = fieldnames(matFileContents);
            assert(length(fnames)==1,'The specified map mat file does not appear to be a valid map mat file.');
            map = matFileContents.(fnames{1});
            
            % TODO: Probably want to do more error checks here.
            % Like make sure that map has the correct fields
            
            self.nucleusMapStructure = map;
        end
        function setQ(self, Q)
            % Generate temporary map with Q
            [tempMap, mapCreatedFlag] = hciUtilCreateTemporaryMapForStimulation(...
                self.nucleusMapStructure,...
                'Q',Q);
            
            if mapCreatedFlag
                self.nucleusMapStructure = tempMap;
            else
                self.setMapErrorStructure.task = 'Set Q.';
                self.setMapErrorStructure.newQ = Q;
                self.setMapErrorStructure.origMap = self.nucleusMapStructure;
                self.setMapErrorStructure.newMap = tempMap;
                deviceStimulationFailure(self);
            end
        end
        function setT(self, electrode, newLevel)
            % Change thresholds
            currentTs = self.nucleusMapStructure.threshold_levels;
            electrodeMatch = find(self.nucleusMapStructure.electrodes == electrode);
            if (length(electrodeMatch) ~= 1)
                error('Invalid electrode specified.');
            end
            currentTs(electrodeMatch) = round(newLevel);
            
            % Generate temporary map with new thresholds
            [tempMap, mapCreatedFlag] = hciUtilCreateTemporaryMapForStimulation(...
                self.nucleusMapStructure,...
                'threshold_levels',currentTs);

            if mapCreatedFlag
                self.nucleusMapStructure = tempMap;
            else
                self.setMapErrorStructure.task = 'Set threshold.';
                self.setMapErrorStructure.changeElectrode = electrode;
                self.setMapErrorStrucutre.newThreshold = newLevel;
                self.setMapErrorStructure.currentTs = currentTs;
                self.setMapErrorStructure.origMap = self.nucleusMapStructure;
                self.setMapErrorStructure.newMap = tempMap;
                deviceStimulationFailure(self);
            end
           
            if self.verboseText
                disp('Ts and Cs have been altered!')
                disp([self.nucleusMapStructure.electrodes self.nucleusMapStructure.threshold_levels self.nucleusMapStructure.comfort_levels])
            end
        end
        function setC(self, electrode, newLevel)
            % Change comfortLevels
            currentCs = self.nucleusMapStructure.comfort_levels;
            electrodeMatch = find(self.nucleusMapStructure.electrodes == electrode);
            if (length(electrodeMatch) ~= 1)
                error('Invalid electrode specified.');
            end
            currentCs(electrodeMatch) = round(newLevel);
            if (self.nucleusMapStructure.threshold_levels(electrodeMatch) >= newLevel)
                warning('Specified comfort level is less than or equal to the current threshold.')
                mapCreatedFlag = false;
            else
                % Generate temporary map with new comfort levels
                [tempMap, mapCreatedFlag] = hciUtilCreateTemporaryMapForStimulation(...
                    self.nucleusMapStructure,...
                    'comfort_levels',currentCs);
            end
            
            if mapCreatedFlag
                self.nucleusMapStructure = tempMap;
            else
                self.setMapErrorStructure.task = 'Set comfort level.';
                self.setMapErrorStructure.changeElectrode = electrode;
                self.setMapErrorStrucutre.newThreshold = newLevel;
                self.setMapErrorStructure.currentCs = currentCs;
                self.setMapErrorStructure.origMap = self.nucleusMapStructure;
                self.setMapErrorStructure.newMap = tempMap;
                deviceStimulationFailure(self);
            end
            
            if self.verboseText
                disp('Ts and Cs have been altered!')
                disp(self.getTsAndCs());
            end
        end
        function setTsAndCsJointly(self,electrode,tVal,cVal)
            currentTs = self.nucleusMapStructure.threshold_levels;
            currentCs = self.nucleusMapStructure.comfort_levels;
            electrodeMatch = find(self.nucleusMapStructure.electrodes == electrode);
            if (length(electrodeMatch) ~= 1)
                warning('Invalid electrode specified.');
                mapCreatedFlag = false;
            else
                currentTs(electrodeMatch) = round(tVal);
                currentCs(electrodeMatch) = round(cVal);
                if (tVal >= cVal)
                    warning('Specified comfort level is less than or equal to the current threshold.')
                    mapCreatedFlag = false;
                else
                    % Generate temporary map with new comfort levels
                    [tempMap, mapCreatedFlag] = hciUtilCreateTemporaryMapForStimulation(...
                        self.nucleusMapStructure,...
                        'threshold_levels',currentTs,...
                        'comfort_levels',currentCs);
                end
            end
            
            if mapCreatedFlag
                self.nucleusMapStructure = tempMap;
            else
                self.setMapErrorStructure.task = 'Set comfort level.';
                self.setMapErrorStructure.changeElectrode = electrode;
                self.setMapErrorStrucutre.newThreshold = newLevel;
                self.setMapErrorStructure.currentCs = currentCs;
                self.setMapErrorStructure.origMap = self.nucleusMapStructure;
                self.setMapErrorStructure.newMap = tempMap;
                deviceStimulationFailure(self);
            end
            
            if self.verboseText
                disp('Ts and Cs have been altered!')
                disp(self.getTsAndCs());
            end
        end
            
        
        function tsAndCs = getTsAndCs(self)
            tsAndCs = cat(2,self.nucleusMapStructure.electrodes(:), self.nucleusMapStructure.threshold_levels(:),self.nucleusMapStructure.comfort_levels(:));
        end
        
        function nE = getNumElectrodes(self)
            nE = self.nucleusMapStructure.num_bands; 
        end
        
        function nE = getElectrodes(self)
            nE = self.nucleusMapStructure.electrodes(:); 
        end

        
        % Set pulse rate
        function val = getRate(self)
           val = self.nucleusMapStructure.channel_stim_rate;
        end
        
        function val = getNormalizedT(self, electrode)
            tsAndCs = self.getTsAndCs;
            val = tsAndCs(:,2)./255;
            
            if nargin > 1
                ind = find(tsAndCs(:,1)==electrode,1,'first');
                if isempty(ind)
                    error('Invalid electrode specified');
                end
                val = val(ind);
            end
        end
        
        function val = getNormalizedC(self, electrode)
            tsAndCs = self.getTsAndCs;
            val = tsAndCs(:,3)./255;
            
            if nargin > 1
                ind = find(tsAndCs(:,1)==electrode,1,'first');
                if isempty(ind)
                    error('Invalid electrode specified');
                end
                val = val(ind);
            end
        end
        
        
        % Display map
        function displayMap(self)
            disp('Current Map: ')
            self.nucleusMapStructure
        end
        
        % Display selected fields of map
        function displayMapField(self,mapFieldName)
            for m = 1:length(mapFieldName)
                disp([mapFieldName{m} ' is currently set to: '])
                disp(self.nucleusMapStructure.(mapFieldName{m}))
            end
        end
        
        function stimulateThreshold(self, magnitudeT, electrode, pulseRate, duration) %#ok<MANU,INUSL>
             
             % Debug
             disp(['Stimulating electrode ' num2str(electrode) ' at ' ...
                 num2str(magnitudeT) ' current levels.'])
             
             % Construct NMT sequence
             [seq, testResults, pulseSentFlag] = hciUtilSendPulseTrain(...
                 self.nucleusMapStructure,...
                 electrode,...
                 magnitudeT,...
                 pulseRate,...
                 duration);
             
            % If sequence is safe to send, send it - otherwise end task and
            %   save error log
             if pulseSentFlag
                 currentMap = self.nucleusMapStructure;
                 save(fullfile(hciRoot, 'debuggingMatFiles','ThresholdStimInformation'),...
                     'seq',...
                     'currentMap',...
                     'electrode',...
                     'magnitudeT',...
                     'pulseRate',...
                     'duration',...
                     'testResults');
                 self.streamSequence(self.NMTclient, seq, duration);
             else
                 self.stimulusErrorStructure.task = 'Stimulate threshold pulse train.';
                 self.stimulusErrorStructure.magnitudeT = magnitudeT;
                 self.stimulusErrorStructure.electrode = electrode;
                 self.stimulusErrorStructure.pulseRate = pulseRate;
                 self.stimulusErrorStructure.durationInSec = duration;
                 self.stimulusErrorStructure.seq = seq;
                 self.stimulusErrorStructure.testResults = testResults;
                 self.stimulusErrorStructure.client = self.NMTclient;
                 self.stimulusErrorStructure.map = self.nucleusMapStructure;
                 deviceStimulationFailure(self);
             end
        end
        function stimulateThresholdWithSweep(self, currentTs, currentCs, ...
                electrodes, pulseRate, duration) %#ok<MANU,INUSL>
             
             % Debug
             disp('Sweeping electrodes.')
             
             % Construct NMT sequence
             [seq, testResults, pulseSentFlag] = hciUtilSendSweepPulseTrain(...
                 self.nucleusMapStructure,...
                 round(currentTs),...
                 electrodes,...
                 pulseRate,...
                 duration);
             
            % If sequence is safe to send, send it - otherwise end task and
            %   save error log
             if pulseSentFlag
                 currentMap = self.nucleusMapStructure;
                 save(fullfile(hciRoot,'debuggingMatFiles','ThresholdStimInformation'),...
                     'seq',...
                     'currentMap',...
                     'currentTs',...
                     'currentCs',...
                     'pulseRate',...
                     'duration',...
                     'testResults');
                 self.streamSequence(self.NMTclient, seq, duration);
             else
                 self.stimulusErrorStructure.task = 'Stimulate with a sweep pulse train.';
                 self.stimulusErrorStructure.currentTs = currentTs;
                 self.stimulusErrorStructure.currentCs = currentCs;
                 self.stimulusErrorStructure.pulseRate = pulseRate;
                 self.stimulusErrorStructure.durationInSec = duration;
                 self.stimulusErrorStructure.seq = seq;
                 self.stimulusErrorStructure.testResults = testResults;
                 self.stimulusErrorStructure.client = self.NMTclient;
                 self.stimulusErrorStructure.map = self.nucleusMapStructure;
                 deviceStimulationFailure(self);
             end
        end 
        function stimulateComfortableLoudnessWithSpeech(self, currentTs, currentCs, ...
                token,cStepSize,cRecentChange) %#ok<MANU,INUSL>
            
            % Debugging
            disp('Stimulating new C-levels: ')
            
            %.............................................................
            % Presentation of sequence
            
            % First time through, determine sequence at current amplitude
            %   and present
            if (isempty(self.upSend) == 1)
                tempMap = hciUtilCreateTemporaryMapForStimulation(...
                    self.nucleusMapStructure,...
                    'threshold_levels',round(currentTs),...
                    'comfort_levels',round(currentCs));
                
                % First time through need a current token and a "next"
                %  token - set first token to a constant selection
                [audio,Fs] = wavread(fullfile(hciDirsDataSentences,'Qualitative','ABoyFellFromTheWindow.wav'));

                [seq,speechSampleSentFlag] = hciUtilSendSpeech(...
                    tempMap, ...
                    audio, ...
                    Fs);

                if speechSampleSentFlag
                    disp('Stimulating token: A Boy Fell From The Window.')
                    
                    origMap = self.nucleusMapStructure; %#ok<NASGU>
                    stimMap = tempMap; %#ok<NASGU>
                    save(fullfile(hciRoot,'debuggingMatFiles','FirstComfortStimInformation'),...
                        'seq',...
                        'origMap',...
                        'stimMap',...
                        'audio',...
                        'Fs');
                    
                    timeToSend = length(audio)/Fs;
                    self.streamSequence(self.NMTclient,seq.output_stimuli,timeToSend);
                else
                    self.stimulusErrorStructure.task = 'Stimulate comfort level speech.';
                    self.stimulusErrorStructure.currentTs = currentTs;
                    self.stimulusErrorStructure.currentCs = currentCs;
                    self.stimulusErrorStructure.tokenFile = token;
                    self.stimulusErrorStructure.seq = seq;
                    self.stimulusErrorStructure.client = self.NMTclient;
                    self.stimulusErrorStructure.map = self.nucleusMapStructure;
                    self.stimulusErrorStructure.stimulationMap = tempMap;
                    deviceStimulationFailure(self);
                end
            
            % If not first time, present previously determined sequence
            else                    
                if (cRecentChange > 0)  % increase amplitude
                    load(fullfile(hciRoot,'debuggingMatFiles','IncreaseComfortStimInformation'))
                    disp(['Stimulating token: ' tokenName]) %#ok<NODEF>
                    
                    timeToSend = length(audio)/Fs;
                    self.streamSequence(self.NMTclient,self.upSend.output_stimuli,timeToSend);
                else                    % decrease amplitude
                    load(fullfile(hciRoot,'debuggingMatFiles','DecreaseComfortStimInformation'))
                    disp(['Stimulating token: ' tokenName]) %#ok<NODEF>

                    timeToSend = length(audio)/Fs;
                    self.streamSequence(self.NMTclient,self.downSend.output_stimuli,timeToSend);
                end
            end
            
            
            %.............................................................
            % Determine sequence for next stimulus (increase and decrease
            %   in amplitude)
            [audio,Fs] = wavread(token);
            
            % Increasing amplitude
            increasedCs = round(currentCs)+cStepSize;
            increasedCs(increasedCs > self.maxCLevel) = self.maxCLevel;
            tempMapIncrease = hciUtilCreateTemporaryMapForStimulation(...
                self.nucleusMapStructure,...
                'threshold_levels',round(currentTs),...
                'comfort_levels',increasedCs);

            [self.upSend,speechSampleSentFlag] = hciUtilSendSpeech(...
                tempMapIncrease, ...
                audio, ...
                Fs);

            if speechSampleSentFlag
                origMap = self.nucleusMapStructure;
                stimMap = tempMapIncrease;
                [tokenPath, tokenName] = fileparts(token);
                seq = self.upSend;
                save(fullfile(hciRoot,'debuggingMatFiles','IncreaseComfortStimInformation'),...
                    'seq',...
                    'tokenPath',...
                    'tokenName',...
                    'origMap',...
                    'stimMap',...
                    'audio',...
                    'Fs');
            else
                self.stimulusErrorStructure.task = 'Stimulate comfort level speech.';
                self.stimulusErrorStructure.currentTs = currentTs;
                self.stimulusErrorStructure.currentCs = currentCs;
                self.stimulusErrorStructure.tokenFile = token;
                self.stimulusErrorStructure.seq = seq;
                self.stimulusErrorStructure.client = self.NMTclient;
                self.stimulusErrorStructure.map = self.nucleusMapStructure;
                self.stimulusErrorStructure.stimulationMap = tempMapIncrease;
                deviceStimulationFailure(self);
            end
            
            % Decreasing amplitude
            decreasedCs = round(currentCs)-cStepSize;
            tooLowI = decreasedCs < round(currentTs);
            decreasedCs(tooLowI) = round(currentTs(tooLowI)) + 1;
            tempMapDecrease = hciUtilCreateTemporaryMapForStimulation(...
                self.nucleusMapStructure,...
                'threshold_levels',round(currentTs),...
                'comfort_levels',decreasedCs);
            
            [self.downSend,speechSampleSentFlag] = hciUtilSendSpeech(...
                tempMapDecrease, ...
                audio, ...
                Fs);
            
            if speechSampleSentFlag
                origMap = self.nucleusMapStructure;
                stimMap = tempMapDecrease;
                [tokenPath, tokenName] = fileparts(token);
                seq = self.downSend;
                save(fullfile(hciRoot,'debuggingMatFiles','DecreaseComfortStimInformation'),...
                    'seq',...
                    'tokenPath',...
                    'tokenName',...
                    'origMap',...
                    'stimMap',...
                    'audio',...
                    'Fs');
             else
                 self.stimulusErrorStructure.task = 'Stimulate comfort level speech.';
                 self.stimulusErrorStructure.currentTs = currentTs;
                 self.stimulusErrorStructure.currentCs = currentCs;
                 self.stimulusErrorStructure.tokenFile = token;
                 self.stimulusErrorStructure.seq = seq;
                 self.stimulusErrorStructure.client = self.NMTclient;
                 self.stimulusErrorStructure.map = self.nucleusMapStructure;
                 self.stimulusErrorStructure.stimulationMap = tempMapDecrease;
                 deviceStimulationFailure(self);
            end
        end 
        function stimulateComfortableLoudnessWithSweep(self, currentTs, currentCs, ...
                electrodes, pulseRate, duration) %#ok<MANU,INUSL>
             
             % Debug
             disp(['Sweeping electrodes at t + ' ...
                 num2str(mean(round(currentCs(~isnan(currentCs)))-round(currentTs(~isnan(currentTs)))))])
             
             % Construct NMT sequence
             [seq, testResults, pulseSentFlag] = hciUtilSendSweepPulseTrain(...
                 self.nucleusMapStructure,...
                 round(currentCs),...
                 electrodes, ...
                 pulseRate,...
                 duration);
             
            % If sequence is safe to send, send it - otherwise end task and
            %   save error log
             if pulseSentFlag
                 currentMap = self.nucleusMapStructure;
                 save(fullfile(hciRoot,'debuggingMatFiles','ComfortStimInformation'),...
                     'seq',...
                     'currentMap',...
                     'currentTs',...
                     'currentCs',...
                     'pulseRate',...
                     'duration',...
                     'testResults');
                 self.streamSequence(self.NMTclient, seq, duration);
             else
                 self.stimulusErrorStructure.task = 'Stimulate with a sweep pulse train.';
                 self.stimulusErrorStructure.currentTs = currentTs;
                 self.stimulusErrorStructure.currentCs = currentCs;
                 self.stimulusErrorStructure.pulseRate = pulseRate;
                 self.stimulusErrorStructure.durationInSec = duration;
                 self.stimulusErrorStructure.seq = seq;
                 self.stimulusErrorStructure.testResults = testResults;
                 self.stimulusErrorStructure.client = self.NMTclient;
                 self.stimulusErrorStructure.map = self.nucleusMapStructure;
                 deviceStimulationFailure(self);
             end
        end 
        function stimulateComfortableLoudnessWithPulseTrain(self, magnitudeC, ...
                electrode, pulseRate, duration) %#ok<MANU,INUSL>
             
             % Debug
             disp(['Stimulating electrode ' num2str(electrode) ' at ' ...
                 num2str(magnitudeC) ' current levels.'])
             
             % Construct NMT sequence
             [seq, testResults, pulseSentFlag] = hciUtilSendPulseTrain(...
                 self.nucleusMapStructure,...
                 electrode,...
                 magnitudeC,...
                 pulseRate,...
                 duration);
             
            % If sequence is safe to send, send it - otherwise end task and
            %   save error log
             if pulseSentFlag
                 currentMap = self.nucleusMapStructure;
                 save(fullfile(hciRoot,'debuggingMatFiles','ComfortStimInformation'),...
                     'seq',...
                     'currentMap',...
                     'electrode',...
                     'magnitudeC',...
                     'pulseRate',...
                     'duration',...
                     'testResults');
                 self.streamSequence(self.NMTclient, seq, duration);
             else
                 self.stimulusErrorStructure.task = 'Stimulate comfort level with pulse train.';
                 self.stimulusErrorStructure.magnitudeC = magnitudeC;
                 self.stimulusErrorStructure.electrode = electrode;
                 self.stimulusErrorStructure.pulseRate = pulseRate;
                 self.stimulusErrorStructure.durationInSec = duration;
                 self.stimulusErrorStructure.seq = seq;
                 self.stimulusErrorStructure.testResults = testResults;
                 self.stimulusErrorStructure.client = self.NMTclient;
                 self.stimulusErrorStructure.map = self.nucleusMapStructure;
                 deviceStimulationFailure(self);
             end
        end
        
        function stimulateSpeechToken(self,presentationToken,noiseLevel,addReverb) %#ok<MANU>
            % Read in token
            [audio,Fs] = wavread(presentationToken);
            
            % Add noise
            if noiseLevel > 0
                noisyAudio = audio + noiseLevel*hciUtilSpeechShapedNoise(Fs, size(audio));
            else
                noisyAudio = audio;
            end
            
            % Add reverb
            if addReverb
                reverbAudio = ISM_AudioData('ISM_RIRs.mat',noisyAudio);
            else
                reverbAudio = noisyAudio;
            end
            reverbAudio = reverbAudio/max(abs(reverbAudio(:)));

            if (hciUtilHaveNmtButNoHardwareDebugMode || hciUtilNoHardwareDebugMode)
                soundsc(reverbAudio,Fs)
            end
            
            [seq,speechSampleSentFlag] = hciUtilSendSpeech(...
                self.nucleusMapStructure, ...
                reverbAudio, ...
                Fs);
            
            if speechSampleSentFlag
                [tokenPath, tokenName] = fileparts(presentationToken);
                disp(['Stimulating token: ' tokenName])
                
                origMap = self.nucleusMapStructure; %#ok<NASGU>
                save(fullfile(hciRoot,'debuggingMatFiles','StimulateSpeechToken'),...
                    'seq',...
                    'origMap',...
                    'audio',...
                    'Fs');
                
                timeToSend = length(reverbAudio)/Fs;
                self.streamSequence(self.NMTclient,seq.output_stimuli,timeToSend);
            else
                self.stimulusErrorStructure.task = 'Stimulate speech token.';
                self.stimulusErrorStructure.tokenFile = presentationToken;
                self.stimulusErrorStructure.noiseLevel = noiseLevel;
                self.stimulusErrorStructure.addReverb = addReverb;
                self.stimulusErrorStructure.seq = seq;
                self.stimulusErrorStructure.client = self.NMTclient;
                self.stimulusErrorStructure.map = self.nucleusMapStructure;
                deviceStimulationFailure(self);
            end
        end
        function stimulateSpeechTokenWithChangedDynamicRange(self,...
                presentationToken,noiseLevel,addReverb,currentTs, currentCs) %#ok<MANU>

            % Read in token
            [audio,Fs] = wavread(presentationToken);
            
            % Add noise
            if noiseLevel > 0
                noisyAudio = audio + noiseLevel*hciUtilSpeechShapedNoise(Fs, size(audio));
            else
                noisyAudio = audio;
            end
            
            % Add reverb
            if addReverb
                reverbAudio = ISM_AudioData('ISM_RIRs.mat',noisyAudio);
            else
                reverbAudio = noisyAudio;
            end
            reverbAudio = reverbAudio/max(abs(reverbAudio(:)));

            if (hciUtilHaveNmtButNoHardwareDebugMode || hciUtilNoHardwareDebugMode)
                soundsc(reverbAudio,Fs)
            end
            
            % Create new temporary map for stimulation
            tempMap = hciUtilCreateTemporaryMapForStimulation(...
                    self.nucleusMapStructure,...
                    'threshold_levels',round(currentTs),...
                    'comfort_levels',round(currentCs));
            [seq,speechSampleSentFlag] = hciUtilSendSpeech(...
                tempMap, ...
                reverbAudio, ...
                Fs);
            
            if speechSampleSentFlag
                [tokenPath, tokenName] = fileparts(presentationToken);
                disp(['Stimulating token: ' tokenName])
                
                origMap = self.nucleusMapStructure; %#ok<NASGU>
                newMap = tempMap;
                save(fullfile(hciRoot,'debuggingMatFiles','StimulateSpeechToken'),...
                    'seq',...
                    'origMap',...
                    'newMap',...
                    'audio',...
                    'Fs');
                
                timeToSend = length(reverbAudio)/Fs;
                self.streamSequence(self.NMTclient,seq.output_stimuli,timeToSend);
            else
                self.stimulusErrorStructure.task = 'Stimulate speech token.';
                self.stimulusErrorStructure.tokenFile = presentationToken;
                self.stimulusErrorStructure.noiseLevel = noiseLevel;
                self.stimulusErrorStructure.addReverb = addReverb;
                self.stimulusErrorStructure.seq = seq;
                self.stimulusErrorStructure.client = self.NMTclient;
                self.stimulusErrorStructure.origMap = self.nucleusMapStructure;
                self.stimulusErrorStructure.map = tempMap;
                deviceStimulationFailure(self);
            end
        end        
        function stimulateLoudnessGrowth(self, Q, Qsequence) 
            % Debugging
            fprintf('Playing Speech with loudness growth Q=%d\n', Q);
            if ~hciUtilNoHardwareDebugMode
                timeToSend = length(Qsequence.stimuli)/Qsequence.audio_sample_rate;
                self.streamSequence(self.NMTclient,Qsequence.output_stimuli,timeToSend);
            end
        end
        function alpha = getLoudnessGrowthAlpha(self, Q)
            % Use NMT software:
            if nargin > 1
                p = struct('base_level',self.nucleusMapStructure.base_level,...
                    'sat_level',self.nucleusMapStructure.sat_level,...
                    'Q',Q);
            else
                % Use map-defined parameters
                p = struct('base_level',self.nucleusMapStructure.base_level,...
                    'sat_level',self.nucleusMapStructure.sat_level,...
                    'Q',self.nucleusMapStructure.Q);
            end
            
             alpha = LGF_alpha(p.Q, p.base_level, p.sat_level);
        end
        function [x, y, alpha] = getLoudnessGrowthCurve(self, Q)
            % This is code from Josh that was ripped from the NMT
            % Thanks Josh!
            % Loudness growth function has nothing to do with dynamic
            % range, but rather is a set of proportions of dynamic range
            % that can be applied to all electrodes.  Changed code to
            % reflect this.
            
            alpha = getLoudnessGrowthAlpha(self, Q);
            
            if nargin > 1
                p = struct('baseLevel',self.nucleusMapStructure.base_level,...
                    'satLevel',self.nucleusMapStructure.sat_level,...      
                    'Q',Q);
            else
                p = struct('baseLevel',self.nucleusMapStructure.base_level,...
                    'satLevel',self.nucleusMapStructure.sat_level,...      
                    'Q',self.nucleusMapStructure.Q);
            end
            
            % FTM input
            x = linspace(0,p.satLevel,1024*2);
            
            xNorm = @(x)(x-p.baseLevel)/(p.satLevel - p.baseLevel);
            lgf = @(x,alpha)log(1+xNorm(x)*alpha)/log(1+alpha);
            
            %Calculate compression function including saturation
            y = min(lgf(x,alpha),lgf(p.satLevel,alpha));
            
            %Due to log function/imaginary results, can't just take
            %y = min(lgf(x,alpha),lgf(p.baseLevel,alpha));
            %Instead find inputs below base level and set output to 0 (i.e., threshold)
            y(x<p.baseLevel) = 0;
            
            % Normalize FTM input
            x = xNorm(x);
            x(x<0) = 0;
            
        end
        function [seqsForQs, noisySeqForQs, veryNoisySeqForQs] = ...
                generateLoudnessGrowthStimuli(self,possibleQs,token)
            [audio, fs] = wavread(token);
            for iQ = 1:length(possibleQs)
                % Change Q
                [tempMapQ, tempMapQFlag] = hciUtilCreateTemporaryMapForStimulation(...
                    self.nucleusMapStructure,...
                    'Q',possibleQs(iQ));
                
                if tempMapQFlag
                    % Process token in quiet
                    [seq,speechSampleSentFlag] = hciUtilSendSpeech(tempMapQ, audio, fs);
                    if speechSampleSentFlag
                        seqsForQs(iQ) = seq;
                    else
                        self.stimulusErrorStructure.task = 'Stimulate loudness growth speech.';
                        self.stimulusErrorStructure.map = self.nucleusMapStructure;
                        self.stimulusErrorStructure.newQ = possibleQs(iQ);
                        self.stimulusErrorStructure.tokenFile = token;
                        self.stimulusErrorStructure.client = self.NMTclient;
                        self.stimulusErrorStructure.stimulationMap = tempMapQ;
                        deviceStimulationFailure(self);
                    end
                    clear seq speechSampleSentFlag
                    
                    % Process token in approx. 20 dB noise
                    noisyAudio = audio + 0.05*hciUtilSpeechShapedNoise(fs, size(audio));
                    
                    [seq,speechSampleSentFlag] = hciUtilSendSpeech(tempMapQ, noisyAudio, fs);
                    if speechSampleSentFlag
                        noisySeqForQs(iQ) = seq;
                    else
                        self.stimulusErrorStructure.task = 'Stimulate loudness growth speech (little noise).';
                        self.stimulusErrorStructure.map = self.nucleusMapStructure;
                        self.stimulusErrorStructure.newQ = possibleQs(iQ);
                        self.stimulusErrorStructure.tokenFile = token;
                        self.stimulusErrorStructure.client = self.NMTclient;
                        self.stimulusErrorStructure.stimulationMap = tempMapQ;
                        deviceStimulationFailure(self);
                    end
                    clear noisyAudio seq speechSampleSentFlag
                    
                    % Process token in approx. 10 dB noise
                    veryNoisyAudio = audio + 0.15*hciUtilSpeechShapedNoise(fs, size(audio));
                    
                    [seq,speechSampleSentFlag] = hciUtilSendSpeech(tempMapQ, veryNoisyAudio, fs);
                    if speechSampleSentFlag
                        veryNoisySeqForQs(iQ) = seq;
                    else
                        self.stimulusErrorStructure.task = 'Stimulate loudness growth speech  (lots of noise).';
                        self.stimulusErrorStructure.map = self.nucleusMapStructure;
                        self.stimulusErrorStructure.newQ = possibleQs(iQ);
                        self.stimulusErrorStructure.tokenFile = token;
                        self.stimulusErrorStructure.client = self.NMTclient;
                        self.stimulusErrorStructure.stimulationMap = tempMapQ;
                        deviceStimulationFailure(self);
                    end
                    clear veryNoisyAudio seq speechSampleSentFlag
                    clear tempMapQ
                else
                    self.stimulusErrorStructure.task = 'Stimulate loudness growth speech.';
                    self.stimulusErrorStructure.map = self.nucleusMapStructure;
                    self.stimulusErrorStructure.newQ = possibleQs(iQ);
                    self.stimulusErrorStructure.tokenFile = token;
                    self.stimulusErrorStructure.client = self.NMTclient;
                    self.stimulusErrorStructure.stimulationMap = tempMapQ;
                    deviceStimulationFailure(self);
                end
            end
        end
        
        function range = getPulseRateRange(self)
            if ~isempty(self.pulseRateRange)
                % Find acceptable range of pulse rates given other
                % parameters:  physically possible
                pulseDuration = (2*self.nucleusMapStructure.phase_width) + ...
                    self.nucleusMapStructure.phase_gap;
                maximaDuration = (pulseDuration*...
                    self.nucleusMapStructure.num_selected)/10^6;
                maxRate = floor(1/(self.rateSteps*maximaDuration))*self.rateSteps;
                
                % Find acceptable range of pulse rates given other
                % parameters:  possible given the RF frequency
                rfMaxRate = 1e6/(self.nucleusMapStructure.num_selected * ...
                    self.nucleusMapStructure.implant.MIN_PERIOD_us);

                if (min(self.pulseRateRange) > maxRate) || ...
                        (min(self.pulseRateRange) > rfMaxRate)
                    error('Pulse rate range is completely outside feasible range.')
                end
                if (max(self.pulseRateRange) > maxRate) || ...
                        (max(self.pulseRateRange) > rfMaxRate)
                    if (max(self.pulseRateRange) > rfMaxRate)
                        self.pulseRateRange(2) = floor(rfMaxRate/self.rateSteps)*self.rateSteps;
                    else
                        self.pulseRateRange(2) = maxRate;
                    end
                end
                
                % Have to figure out why max rate can still cause errors
                % For now, just leave off max of max rate
                self.pulseRateRange(2) = self.pulseRateRange(2) - 100;
                self.pulseRateRange(2) = max(self.pulseRateRange(2),...
                    self.nucleusMapStructure.channel_stim_rate);
                

                range = self.pulseRateRange;
            else
                self.stimulusErrorStructure.errorMsg = 'Pulse rate range missing.';
                self.stimulusErrorStructure.task = 'Set pulse rates.';
                self.stimulusErrorStructure.map = self.nucleusMapStructure;
                deviceStimulationFailure(self);
            end
        end
        function setPulseRateTsAndCs(self)
            self.pulseRateRangeTsAndCs = [100 150; 150 220];
        end
            
        function val = getPulseRate(self)
            val = self.nucleusMapStructure.channel_stim_rate; %#FIXME!
        end
        function setPulseRate(self, pr, lgfT, lgfC)
            % Determine new T's and C's for new pulse rate
            currentTs = round(self.nucleusMapStructure.threshold_levels + polyval(lgfT,pr));
            currentTs(currentTs < 1) = 1;
            currentCs = self.nucleusMapStructure.comfort_levels + polyval(lgfC,pr);
            currentCs(currentCs > self.maxCLevel) = self.maxCLevel;
            currentCs = round(max([currentCs(:) currentTs(:)+1], [], 2));
            
            % Generate temporary map with new pulse rate
            [tempMap, mapCreatedFlag] = hciUtilCreateTemporaryMapForStimulation(...
                self.nucleusMapStructure,...
                'channel_stim_rate',pr,...
                'threshold_levels',currentTs,...
                'comfort_levels',currentCs);

            if mapCreatedFlag
                self.nucleusMapStructure = tempMap;
            else
                self.setMapErrorStructure.task = 'Set pulse rate.';
                self.setMapErrorStructure.currentPR = pr;
                self.setMapErrorStructure.currentTs = currentTs;
                self.setMapErrorStructure.currentCs = currentCs;
                self.setMapErrorStructure.lgfT = lgfT;
                self.setMapErrorStructure.lgfC = lgfC;
                self.setMapErrorStructure.origMap = self.nucleusMapStructure;
                self.setMapErrorStructure.newMap = tempMap;
                deviceStimulationFailure(self);
            end
        end
        function stimulatePulseRate(self, pr, lgfT, lgfC, token) %#ok<MANU>
            %#FIXME!
            fprintf('Playing Speech with pulse rate = %f\n', pr);
            
            % Determine new T's and C's for new pulse rate
            currentTs = round(self.nucleusMapStructure.threshold_levels + polyval(lgfT,pr));
            currentTs(currentTs < 1) = 1;
            currentCs = self.nucleusMapStructure.comfort_levels + polyval(lgfC,pr);
            currentCs(currentCs > self.maxCLevel) = self.maxCLevel;
            currentCs = round(max([currentCs(:) currentTs(:)+1], [], 2));
            
            % Generate temporary map with new pulse rate
            [tempMap, mapCreatedFlag] = hciUtilCreateTemporaryMapForStimulation(...
                self.nucleusMapStructure,...
                'channel_stim_rate',pr,...
                'threshold_levels',currentTs,...
                'comfort_levels',currentCs);
                
            % Convert audio to stream sequence
            [audio,Fs] = wavread(token);
            if mapCreatedFlag
                [seq,speechSampleSentFlag] = hciUtilSendSpeech(...
                    tempMap, ...
                    audio, ...
                    Fs);
            
                % If valid sequence, send speech
                if speechSampleSentFlag
                    [tokenPath, tokenName] = fileparts(token);
                    disp(['Stimulating token: ' tokenName])
                    origMap = self.nucleusMapStructure;
                    stimMap = tempMap;
                    save(fullfile(hciRoot,'debuggingMatFiles','PulseRateStimulation'),...
                        'seq',...
                        'origMap',...
                        'stimMap',...
                        'audio',...
                        'Fs',...
                        'token');
                    
                    timeToSend = length(audio)/Fs;
                    self.streamSequence(self.NMTclient,seq.output_stimuli,timeToSend);
                else
                    self.stimulusErrorStructure.task = 'Stimulate pulse rate speech.';
                    self.stimulusErrorStructure.currentPR = pr;
                    self.stimulusErrorStructure.currentTs = currentTs;
                    self.stimulusErrorStructure.currentCs = currentCs;
                    self.stimulusErrorStructure.lgfT = lgfT;
                    self.stimulusErrorStructure.lgfC = lgfC;
                    self.stimulusErrorStructure.tokenFile = token;
                    self.stimulusErrorStructure.seq = seq;
                    self.stimulusErrorStructure.client = self.NMTclient;
                    self.stimulusErrorStructure.map = self.nucleusMapStructure;
                    self.stimulusErrorStructure.stimulationMap = tempMap;
                    deviceStimulationFailure(self);
                end
            else
                self.stimulusErrorStructure.task = 'Stimulate pulse rate speech.';
                self.stimulusErrorStructure.currentPR = pr;
                self.stimulusErrorStructure.currentTs = currentTs;
                self.stimulusErrorStructure.currentCs = currentCs;
                self.stimulusErrorStructure.lgfT = lgfT;
                self.stimulusErrorStructure.lgfC = lgfC;
                self.stimulusErrorStructure.tokenFile = token;
                self.stimulusErrorStructure.client = self.NMTclient;
                self.stimulusErrorStructure.map = self.nucleusMapStructure;
                deviceStimulationFailure(self);
            end
        end
        
        function deviceStimulationFailure(self)
            errorStruct = self.stimulusErrorStructure;
            errorStruct.lastError = lasterror; %#ok<LERR>
            save(fullfile(hciRoot,'debuggingMatFiles','TaskFailure'),'errorStruct');
            if isfield(self.stimulusErrorStructure,'errorMsg')
                disp(self.stimulusErrorStructure.errorMsg)
            end
            if ~isempty(self.deviceStimulationFailureCallback)
                feval(self.deviceStimulationFailureCallback);
                msgbox('Please notify the test administrator of this error.','Task failed.','error');
            end
            self.catestrophicFailure = true;
        end
    end
end