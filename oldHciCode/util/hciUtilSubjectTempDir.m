function d = hciUtilSubjectTempDir(id)

d = fullfile(hciRoot,'subjects');

if nargin && ~isempty(id)
    d = fullfile(d,id);
end