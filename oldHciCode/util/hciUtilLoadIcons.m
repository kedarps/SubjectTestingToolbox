function IconData = hciUtilLoadIcons

iconDir = hciUtilIconDir;
fileNames = getfileNames;
sizeStrs = {'size64','size16'};


problemStr  = '';
alphaThresh = 100;
problemEncountered = false;
for iIcon = 1:length(fileNames)
    cName = genvarname(strrep(fileNames{iIcon},'-','_'));
    
    for iSize = 1:length(sizeStrs)
        cSizeStr = sizeStrs{iSize};
    
        try
            %[A, map, alpha] = imread(fullfile(iconDir,cFiles(iFile).name),'BackgroundColor',[0.941176 0.941176 0.941176]);
            %[A, map, alpha] = imread(fullfile(iconDir,cFiles(iFile).name),'BackgroundColor',[nan nan nan]);
            [A, map, alpha] = imread(fullfile(iconDir,cSizeStr,cat(2,fileNames{iIcon},'.png')));
            A = double(A);
        
            % [nan 1 1] is somehow transparent in matlab uicontrols
            % (Thanks for the documentation Mathworks!)
            cInds = cat(3,alpha<alphaThresh,false(size(A,1),size(A,2)),false(size(A,1),size(A,2)));
            A(cInds(:)) = nan;
            cInds = cat(3,false(size(A,1),size(A,2)),alpha<alphaThresh,false(size(A,1),size(A,2)));
            A(cInds(:)) = 256;
            cInds = cat(3,false(size(A,1),size(A,2)),false(size(A,1),size(A,2)),alpha<alphaThresh);
            A(cInds(:)) = 256;
        
            IconData.(cSizeStr).(cName) = A/256;
        catch %#ok<CTCH>
            IconData.(cSizeStr).(cName) = repmat(rand(16),[1 1 3]); % Default size is 16x16
            problemEncountered = true;
            if isempty(problemStr)
                problemStr = cat(2,'\t',cSizeStr, ' ', cName, ' is missing.');
            else
                problemStr = cat(2,problemStr,'\n\t',cSizeStr, ' ', cName, ' is missing.');
            end
        end
    end
end

if problemEncountered
    warning('hci:hciUtilLoadIcons:missingFiles',cat(2,'A problem was encountered with the icons.\n', problemStr));
end

end

function strs = getfileNames

strs = {'mail-mark-task';
        'office-chart-area-stacked';
        'user-new-3';
        'user-properties';
        'view-sort-descending';
        'tools-check-spelling-5';
        'tools-check-spelling';
        'people-xbill';
        'office-chart-line-stacked';
        'office-chart-bar';
        'circle_green';
        'circle_red';
        'circle_yellow';
        'user-delete-2';
        'edit-delete-3';
        'archive-insert-2';...
        'preferences-desktop-font-6'};
end