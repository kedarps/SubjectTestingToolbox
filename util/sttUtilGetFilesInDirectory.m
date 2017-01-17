
%
% files = sttUtilGetFilesInDirectory(directory, namePattern)
%
% Get a list of the files in a directory.
%
% VARIABLES:
% directory     -   string containing directory location of files
% namePattern   -   (optional) a string that the file name must contain in
%                   order to be returned, e.g. '.mat' would return only mat
%                   files
%
% OUTPUT:
% files         -   cell list of names of files contained in the directory
%

function files = sttUtilGetFilesInDirectory(directory, namePattern)

if nargin < 2
    namePattern = [];
end

% Get list of files and directories
filesAndDirs = dir(directory);

% Eliminate directories
filesAndDirs([filesAndDirs.isdir] == 1) = [];

% Get list of file names
files = {filesAndDirs.name};

% If a pattern was specified, elminate files without that pattern
if ~isempty(namePattern)
    rmFileI = [];
    for f = 1:length(files)
        if isempty(strfind(files{f}, namePattern))
            rmFileI = [rmFileI f];
        end
    end
    files(rmFileI) = [];
end


