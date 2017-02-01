lastwarn('')
close all
% clear classes
% clear all
clear
clear global

if ~isempty(lastwarn)
    exit
end

% check for timer objects and delete them
t = timerfindall;
for i = 1:length(t)
    delete(t(i));
end