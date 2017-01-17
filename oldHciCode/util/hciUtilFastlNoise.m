function x = hciUtilFastlNoise(fs, n)

warning('not done yet');

x = hciUtilSpeechShapedNoise(fs, n);

t = (0:(max(n)-1))'/fs;

frequencySignal = 4+0.1.*hciUtilSpeechShapedNoise(fs,n); % Not right!

modulationSignal = sin(2*pi*frequencySignal.*t);

x = bsxfun(@times,x,modulationSignal);
