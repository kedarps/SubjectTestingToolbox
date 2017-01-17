function s = hciUtilResultsFileName(s)

s = cat(2,datestr(now,'yyyymmddHHMMSS'),'_',s,'.yaml');