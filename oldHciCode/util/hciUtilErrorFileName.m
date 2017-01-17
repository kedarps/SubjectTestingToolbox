function s = hciUtilResultsFileName(s)

if nargin < 1
    s = cat(2,datestr(now,'yyyymmddHHMMSS'),'_errorLog.mat');
else
    s = cat(2,datestr(now,'yyyymmddHHMMSS'),'_errorLog_',s,'.mat');
end