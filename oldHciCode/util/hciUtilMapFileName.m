function s = hciUtilMapFileName(s)

s = cat(2,datestr(now,'yyyymmddHHMMSS'),'_',s,'.mat');