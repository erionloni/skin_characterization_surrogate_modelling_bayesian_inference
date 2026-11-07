function T = case_outputs(cfg, output)
%CASE_OUTPUTS The cells or cases of one kind of per-case output (settings A.10).
%   T = study.case_outputs(CFG, OUTPUT) expands the selection of the setting
%   s.fixed.caseOutputs.<OUTPUT> (CFG.fig.caseOutputs) into a table with the
%   columns CaseID, Scenario and Design, one row per selected cell, in the
%   order of the selection (a cell selected twice is listed once). A
%   selection is a list of cases, or rows {cases, scenarios} or {cases,
%   scenarios, designs}: cases a list of CaseIDs or 'all', scenarios and
%   designs a list of names or 'all'; {} or [] selects nothing. 'all' is
%   every case of the inversion (CFG.inversion.caseIDs), every scenario of
%   the inversion or every design. Scenario and Design are "" where the
%   selection has no such part. A case, scenario or design that is not one
%   of the inversion is left out: a run of other cases has none of its
%   cells.
%   Side effects: none.

    selection = cfg.fig.caseOutputs.(output);
    if ~iscell(selection)
        selection = {selection};
        if isempty(selection{1}), selection = {}; end
    end
    cohort = reshape(double(cfg.inversion.caseIDs), 1, []);
    caseColumn = zeros(0, 1);
    scenarioColumn = strings(0, 1);
    designColumn = strings(0, 1);
    for r = 1:size(selection, 1)
        cases = members(selection{r, 1}, cohort);
        scenarios = "";
        if size(selection, 2) >= 2
            scenarios = members(selection{r, 2}, string(cfg.inversion.activeScenarioTags));
        end
        designs = "";
        if size(selection, 2) >= 3
            designs = members(selection{r, 3}, string(cfg.inversion.designNames));
        end
        for c = cases
            for s = scenarios
                for d = designs
                    caseColumn(end + 1, 1) = c; %#ok<AGROW>
                    scenarioColumn(end + 1, 1) = s; %#ok<AGROW>
                    designColumn(end + 1, 1) = d; %#ok<AGROW>
                end
            end
        end
    end
    T = table(caseColumn, scenarioColumn, designColumn, ...
        'VariableNames', {'CaseID', 'Scenario', 'Design'});
    T = unique(T, 'stable');
end

function list = members(value, all)
%MEMBERS The values of a selection that belong to ALL, in the selection's order ('all': ALL).
    if (ischar(value) || isstring(value)) && isscalar(string(value)) && string(value) == "all"
        list = reshape(all, 1, []);
        return;
    end
    if isnumeric(all)
        list = reshape(double(value), 1, []);
    else
        list = reshape(string(value), 1, []);
    end
    list = list(ismember(list, all));
end
