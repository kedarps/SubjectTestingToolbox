function parse_set = sttUtilParseStr(name,match_char,find_ext)
%
% function parse_set = sttUtilParseStr(name,match_char,find_ext)
%
% This function breaks down a string based on the string in match_char
%   (typically a single character), similar to how FILEPARTS parses a 
%   string based on '\' and '.'.  The output is a cell array of the 
%   substrings.  If specified, the function also looks for an extention, 
%   which will be the final element in the cell array.
%
% VARIABLES:
%   name        -   1 x M string array presumably containing a string like
%                   that in match_char
%   match_char  -   (optional) 1 x C string array where C < M.  The default
%                   is '_'.  If match_char is white space, it is forced to
%                   be of length 1 (i.e. match_char cannot be 5 spaces).
%   find_ext    -   (optional) 1 indicates looking for an extension
%                   (assumes one '.' within name - if more, takes the
%                   last); 0 does not look for an extension.  If
%                   match_char = '_', then the default is 1; otherwise, the
%                   default is 0.
%   
% OUTPUT
%   parse_set   -   1 x N matrix of string arrays.
%                   N = num(match_char) + 1 + 1 (if looked for and found an
%                   extension)
%

%------------------------------------------------------------
% Set up options.
if (nargin < 2)
    match_char = '_';
    find_ext = 1;
elseif (nargin < 3)
    if (strcmp(match_char,'_'))
        find_ext = 1;
    else
        find_ext = 0;
    end
end
if (isempty(match_char))
    match_char = '_';
end

%-------------------------------------------------------------
% Look for extension.
if (find_ext)
    ext_ind = strfind(name, '.');
    if (~isempty(ext_ind))
        ext_ind(1:end-1) = [];
        new_name = name(1:(ext_ind - 1));
        ext_str = name((ext_ind + 1):end);
    else
        new_name = name;
        ext_str = [];
    end
else
    new_name = name;
    ext_str = [];
end


%-------------------------------------------------------------
% Parse string.
if (isstrprop(match_char,'wspace'))
    uind = strfind(new_name, match_char(1));
    mc_length = 1;
else
    uind = strfind(new_name, match_char);
    mc_length = length(match_char);
end
if (isempty(uind))
    parse_set = {new_name, ext_str};
else
    parse_set = [];
    for u = 1:(length(uind)+1)
        if (u == 1)
            parse_set = [parse_set {new_name(1:(uind(u)-1))}];
        elseif (u > length(uind))
            parse_set = [parse_set, ...
                {new_name((uind(u-1)+mc_length):end)}];
        else
            parse_set = [parse_set, ...
                {new_name((uind(u-1)+mc_length):(uind(u)-1))}];
        end
    end
    if ~isempty(ext_str)
        parse_set = [parse_set {ext_str}];
    end
end
