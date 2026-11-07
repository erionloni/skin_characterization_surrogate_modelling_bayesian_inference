function T = add_certified_only(T, C, shared)
%ADD_CERTIFIED_ONLY Put after each aggregate column its value over the certified cells alone.
%   T = utils.add_certified_only(T, C, SHARED) takes a summary T over the
%   cells with a posterior (certified and healthy fallback) and the same
%   summary C over the certified cells alone, with the same rows in the same
%   order: the columns SHARED (the keys, and counts that do not depend on the
%   cells) are equal in both. Every other column X of T gets C.X right after
%   it, as X_certified_only (next to each aggregate its certified-only
%   value).
%   Side effects: none.
    shared = cellstr(string(shared));
    assert(height(T) == height(C) && isequaln(T(:, shared), C(:, shared)), ...
        'utils:add_certified_only:Rows', ...
        'The certified-only summary has other rows than the summary (columns %s).', ...
        strjoin(shared, ', '));
    for name = setdiff(T.Properties.VariableNames, shared, 'stable')
        added = [name{1} '_certified_only'];
        T.(added) = C.(name{1});
        T = movevars(T, added, 'After', name{1});
    end
end
