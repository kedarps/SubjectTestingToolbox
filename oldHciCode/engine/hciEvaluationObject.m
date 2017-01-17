classdef hciEvaluationObject < hgsetget
    properties
        subjMap
        
        StimType
        DurationInSec
        Electrode
        AmplitudeInCurrentSteps
        WavFile
        
        stimulus
        Fs
    end
    
    methods
        function self = hciEvaluationObject(varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
        end
        
        function generateStimulus(self,varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
            ptAmp = self.AmplitudeInCurrentSteps/255;
            switch lower(self.StimType)
                case 'pulse train - electrode'
                    self.Fs = 16000;
                    channelFreq = logspace(log10(250),log10(6000),...
                        size(self.subjMap.NMTmap.threshold_levels,1));
                    n = 0:(self.DurationInSec*self.Fs);
                    self.stimulus = ...
                        ptAmp*sin(2*pi*channelFreq(self.Electrode)*n/self.Fs);
                    self.stimulus = self.stimulus(:).*hamming(length(self.stimulus(:)));
                case 'pulse train - center freq'
                    self.Fs = 16000;
                    n = 0:(self.DurationInSec*self.Fs);
                    self.stimulus = ...
                        ptAmp*sin(2*pi*self.subjMap.NMTmap.channel_stim_rate*n/self.Fs);
                    self.stimulus = self.stimulus(:).*hamming(length(self.stimulus(:)));
                case 'wav'
                    [s,self.Fs] = wavread(self.WavFile);
                    s = s/(max(abs(s(:))));
                    self.stimulus = ptAmp*s;
                otherwise
                    error('No such stimulus type exists.')
            end
        end
        
        function soundStimulus(self)
            sound(self.stimulus, self.Fs)
        end
        
        function plotStimulus(self)
            figHandle = figure;
            t = 0:(1/self.Fs):((length(self.stimulus)-1)/self.Fs);
            plot(t,self.stimulus)
            xlabel('Time (sec)')
            ylabel('Normalized Amplitude')
            title('Current Stimulus')
            uicontrol('Style','pushbutton',...
                'String','Done',...
                'Units','normalized','Position',[0.9 0 0.1 0.1],...
                'Callback',{@closeFigure figHandle});
            
            function closeFigure(source,event,figHandle)
                close(figHandle)
            end
        end
    end
end
