function add_certified_only_summary(target, certified)
%ADD_CERTIFIED_ONLY_SUMMARY Add the certified cells' design summary to a scenario's design summary.
%   design_study.add_certified_only_summary(TARGET, CERTIFIED) reads the
%   design summary TARGET (design_summary.csv of a scenario, over the
%   cells with a selected provider: certified or healthy fallback) and the
%   design summary CERTIFIED of the same scenario over the certified cells
%   alone, and writes TARGET again with, right after each aggregate and
%   cohort column of design_study.certified_only_columns, the same column of
%   CERTIFIED under the name <column>_certified_only (the
%   certified-only value next to every aggregate). The rows are joined by
%   Design; every value is copied as text.
%   Side effects: writes TARGET.

    T = read_text(target);
    C = read_text(certified);
    assert(isequal(sort(T.Design), sort(C.Design)) && numel(unique(T.Design)) == height(T), ...
        'design_study:add_certified_only_summary:Designs', ...
        'The design summaries %s and %s do not list the same designs once each.', target, certified);
    [~, order] = ismember(T.Design, C.Design);
    C = C(order, :);
    for name = design_study.certified_only_columns()
        column = name{1};
        assert(ismember(column, T.Properties.VariableNames) && ...
            ismember(column, C.Properties.VariableNames), ...
            'design_study:add_certified_only_summary:Column', ...
            'The design summaries lack the column %s.', column);
        added = [column '_certified_only'];
        T.(added) = C.(column);
        T = movevars(T, added, 'After', column);
    end
    utils.atomic_write_table(target, T);
end

function T = read_text(file)
%READ_TEXT A CSV table with every column as text, so that values are copied unchanged.
    options = detectImportOptions(file, 'Delimiter', ',', 'TextType', 'string', ...
        'VariableNamingRule', 'preserve');
    options = setvartype(options, 'string');
    T = readtable(file, options);
    for name = T.Properties.VariableNames
        values = T.(name{1});
        values(ismissing(values)) = "";
        T.(name{1}) = values;
    end
end
