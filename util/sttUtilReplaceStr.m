function new_str = sttUtilReplaceStr(name,new_char,match_char,find_ext)
%
% function new_str = sttUtilReplaceStr(name,new_char,match_char,find_ext)
%
% This function uses sttUtilParseStr to break down a string at the match_char
%   locations (the match_char is removed).  Then each of the pieces is
%   reformed, separated by new_char.  Note:  If find_ext is 1, then the
%   entire extension will be replaced.
%
% EXAMPLE:  str = 'file_placed_at_here.mat'
%           new_str = sttUtilReplaceStr(str,'0','_',1)
%           new_str = 'file0placed0at0here0'
%
% VARIABLES:
%   name        -   1 x M string array presumably containing a string like
%                   that in match_char
%   new_char    -   1 x K string array used to replace match_char
%   match_char  -   (optional) 1 x C string array where C < M.  The default
%                   is '_'.  If match_char is white space, it is forced to
%                   be of length 1 (i.e. match_char cannot be 5 spaces).
%   find_ext    -   (optional) 1 indicates looking for an extension
%                   (assumes one '.' within name - if more, takes the
%                   last); the default is 0.  Note:  the entire extension
%                   will be replaced with MATCH_CHAR.
%   
% OUTPUT
%   new_str   -     1 x L string
%                   If no search for extension:
%                   L = M - (num(match_char)*length(match_char)) +
%                       (num(match_char)*length(new_char))
%                   Else:
%                   L = M - (num(match_char)*length(match_char) + 1) +
%                       ((num(match_char)+1)*length(new_char))
%

%------------------------------------------------------------
% Set up options.
if (nargin < 3)
    match_char = '_';
    find_ext = 0;
elseif (nargin < 4)
    find_ext = 0;
end
if (isempty(match_char))
    match_char = '_';
end
if (isempty(new_char))
    new_char = '';
end

%-------------------------------------------------------------
% Parse string by match_char.
parse_old = sttUtilParseStr(name,match_char,find_ext);

%-------------------------------------------------------------
% Reform string.
if (min(strfind(name,match_char)) == 1)
    new_str = [new_char parse_old{1}];
else
    new_str = parse_old{1};
end

if (find_ext)
    end_addition = length(parse_old) - 1;
else
    end_addition = length(parse_old);
end
for p = 2:end_addition
    new_str = [new_str new_char parse_old{p}];
end

if (max(strfind(name,match_char)) == (length(name)-length(match_char)+1))
    new_str = [new_str new_char];
elseif (find_ext)
    new_str = [new_str new_char];
end


