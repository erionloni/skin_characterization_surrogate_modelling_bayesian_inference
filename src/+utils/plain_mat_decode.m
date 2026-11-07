function S=plain_mat_decode(S)
%PLAIN_MAT_DECODE The variables of a plain MAT file in their original MATLAB types.
%   S = utils.plain_mat_decode(S) takes the variables S loaded from a file
%   that utils.plain_mat_encode wrote and, for each conversion its
%   plainMatEncoding lists whose variable S holds (a partial load holds only
%   some), restores the table (with its string columns) or the string array;
%   plainMatEncoding is removed. Variables without a recorded conversion,
%   and files without plainMatEncoding, are returned as loaded.
%   Side effects: none.

    if ~isfield(S,'plainMatEncoding'),return;end
    encoding=S.plainMatEncoding;
    S=rmfield(S,'plainMatEncoding');
    for i=1:numel(encoding)
        parts=strsplit(encoding(i).path,'.');
        if ~isfield(S,parts{1}),continue;end
        switch encoding(i).type
            case 'table'
                value=struct2table(S.(parts{1}));
                for c=1:numel(encoding(i).stringColumns)
                    name=encoding(i).stringColumns{c};
                    value.(name)=string(value.(name));
                end
                S.(parts{1})=value;
            case 'string'
                if isscalar(parts)
                    S.(parts{1})=string(S.(parts{1}));
                else
                    value=S.(parts{1});
                    for e=1:numel(value)
                        value(e).(parts{2})=string(value(e).(parts{2}));
                    end
                    S.(parts{1})=value;
                end
            otherwise
                error('utils:plain_mat_decode:Type','Unknown conversion %s of %s.', ...
                    encoding(i).type,encoding(i).path);
        end
    end
end
