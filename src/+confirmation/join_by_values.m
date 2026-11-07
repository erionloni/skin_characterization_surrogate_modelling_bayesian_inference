function at = join_by_values(D, T, names, labels, source)
%JOIN_BY_VALUES The design row each row of a table belongs to, by exactly equal values.
%   AT = confirmation.join_by_values(D, T, NAMES, LABELS, SOURCE) returns,
%   for every row of the table T, the index of the row of the design table D
%   with the same values in the columns NAMES (numbers compared exactly,
%   text as text). Every row of T must have such a row of D, no two rows of
%   T the same one, and every row of D one row of T; otherwise it stops with
%   the rows concerned: rows of T by their line in the file SOURCE, rows of D
%   by LABELS (one text per row of D, e.g. its RunID).
%   Side effects: none.

    names = cellstr(names);
    KD = zeros(height(D), numel(names));
    KT = zeros(height(T), numel(names));
    for k = 1:numel(names)
        d = D.(names{k}); t = T.(names{k});
        if isnumeric(d)
            KD(:, k) = double(d); KT(:, k) = double(t);
        else
            [~, ~, code] = unique([string(d); string(t)]);
            KD(:, k) = code(1:height(D)); KT(:, k) = code(height(D) + 1:end);
        end
    end
    [found, at] = ismember(KT, KD, 'rows');
    lines = find(~found) + 1;
    assert(isempty(lines), 'confirmation:join_by_values:Unknown', ...
        ['%d rows of %s (file lines %s) match no row of the design exactly in %s. The values ' ...
         'must be those of the design''s run list, with 17 significant digits.'], numel(lines), ...
        source, listed(string(lines)), strjoin(names, ', '));
    [counts, rows] = groupcounts(at);
    repeated = rows(counts > 1);
    assert(isempty(repeated), 'confirmation:join_by_values:Repeated', ...
        ['%s gives %s more than once; give each once (do not choose between repeated ' ...
         'simulations here).'], source, listed(string(labels(repeated))));
    missing = setdiff((1:height(D)).', at);
    assert(isempty(missing), 'confirmation:join_by_values:Missing', ...
        '%s lacks %d of the %d rows of the design: %s.', source, numel(missing), height(D), ...
        listed(string(labels(missing))));
end

function text = listed(values)
%LISTED The first ten values, and how many more there are.
    values = reshape(values, 1, []);
    text = strjoin(values(1:min(end, 10)), ', ');
    if numel(values) > 10, text = sprintf('%s and %d more', text, numel(values) - 10); end
end
