function pathValue = absolute_path(pathValue)
%ABSOLUTE_PATH Resolve a path against MATLAB's current working directory.
%   Java's user.dir can lag behind MATLAB CD, so relative paths are joined
%   to PWD before Java canonicalization.
%   PATHVALUE = utils.absolute_path(PATHVALUE) returns the canonical absolute
%   path (character vector) of a file or folder, which need not exist.
%   Side effects: none.

    pathValue=char(string(pathValue));
    assert(~isempty(pathValue)&&~contains(pathValue,char(0)), ...
        'utils:absolute_path:InvalidPath', ...
        'Path must be a nonempty string without NUL bytes.');
    file=javaObject('java.io.File',pathValue);
    if ~file.isAbsolute()
        file=javaObject('java.io.File',fullfile(pwd,pathValue));
    end
    pathValue=char(file.getCanonicalPath());
end
