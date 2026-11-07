function S=load_plain_mat(pathValue,varargin)
%LOAD_PLAIN_MAT Load variables of a MAT file and restore the types utils.plain_mat_encode converted.
%   S = utils.load_plain_mat(PATH) loads every variable of PATH;
%   S = utils.load_plain_mat(PATH, NAME1, NAME2, ...) loads the named ones,
%   like load. The tables and string arrays that the file stores as plain
%   values (its variable plainMatEncoding) are restored
%   (utils.plain_mat_decode). A file written before the conversion, without
%   plainMatEncoding, is returned as loaded.
%   Side effects: none.

    S=load(pathValue,varargin{:});
    if ~isempty(varargin)&&~isempty(whos('-file',pathValue,'plainMatEncoding'))
        record=load(pathValue,'plainMatEncoding');
        S.plainMatEncoding=record.plainMatEncoding;
    end
    S=utils.plain_mat_decode(S);
end
