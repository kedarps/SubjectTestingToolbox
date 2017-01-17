function sttPath

d = dir(sttRoot);
d = d(3:end);
d = d(cat(1,d.isdir));

foldersNotToAdd = {...
    'oldHciCode', ...
    };

P = '';
for iD = 1:length(d)
    % Ignore specified folders
    if ~any(ismember(foldersNotToAdd, d(iD).name))
        P = cat(2,P,genpath(fullfile(sttRoot,d(iD).name)));
    end
end
addpath(P);

%Remove some paths we don't need (we remove all directories that start with
% a . or a ]

removePath = [];
[string,remString] = strtok(P,pathsep);
while ~isempty(string)
    if ~isempty(strfind(string,[filesep '.'])) || ~isempty(strfind(string,[filesep ']']))
        removePath = cat(2,removePath,pathsep,string);
    end
    [string,remString] = strtok(remString,pathsep); %#ok
end
if ~isempty(removePath)
    rmpath(removePath);
end