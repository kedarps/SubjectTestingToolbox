function x = hciUtilSpeechShapedNoise(fs,n)

if isscalar(n) % Assume you want a vector of length n.
    n = cat(2,n,1);
end

[b, a] = hciUtilSpeechShapedNoiseFilterCoefficients(fs);

x = filter(b,a,randn(n));