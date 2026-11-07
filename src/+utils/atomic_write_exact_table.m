function atomic_write_exact_table(pathValue,T)
%ATOMIC_WRITE_EXACT_TABLE Write a table as CSV with every double written exactly.
%   utils.atomic_write_exact_table(PATH, T) writes T atomically
%   (utils.atomic_write_table), each double column with 17 significant
%   digits ('%.17g'), which MATLAB reads back to the same IEEE value, and
%   logical columns as 0/1. Use it for scientific inputs that other steps
%   read (the confirmation design and observations), not for display
%   tables. Every variable must be one column of double, logical, string or
%   cellstr values.
%   Side effects: writes PATH.
    assert(istable(T),'utils:atomic_write_exact_table:Table','A table is required.');
    serial=T;
    for name=string(T.Properties.VariableNames)
        v=T.(name);
        assert(ismatrix(v)&&size(v,2)==1, ...
            'utils:atomic_write_exact_table:Shape','Each variable must be one column: %s.',name);
        if isa(v,'double')
            assert(isreal(v),'utils:atomic_write_exact_table:Complex','Real columns required.');
            serial.(name)=compose('%.17g',v);
        elseif islogical(v)
            serial.(name)=string(double(v));
        else
            assert(isstring(v)||iscellstr(v), ...
                'utils:atomic_write_exact_table:Type','Unsupported column type: %s.',name);
        end
    end
    utils.atomic_write_table(pathValue,serial,'QuoteStrings',true);
end
