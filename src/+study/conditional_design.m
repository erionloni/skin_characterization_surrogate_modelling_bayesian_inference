function design = conditional_design(C, parameterNames, scenarios)
%CONDITIONAL_DESIGN The conditions and the campaign of the conditional inversion, from the settings (A.9).
%   DESIGN = study.conditional_design(C, PARAMETERNAMES, SCENARIOS) reads the
%   settings C (s.fixed.conditionalInversion) with the material parameters
%   PARAMETERNAMES (A.1, in their canonical order) and the scenarios
%   SCENARIOS of the inversion (A.6), and returns
%     conditions  one per row of the condition table, in its order: code (the
%                 label), label and description (its description), the fixed
%                 and free parameter indices and names, mask (1 = free, in
%                 the canonical order), id and tag (<names>_fixed from the
%                 fixed set, e.g. m3f_and_thickness_fixed; baseline for the
%                 row that fixes nothing), role, canonicalReference,
%                 scheduledScenarios (where the campaign runs it, for the
%                 reference every scenario of the campaign, in the order in
%                 which the campaign rows first name them)
%     reference   the code of the row that fixes nothing (the canonical
%                 all_six cell, never run by the conditional inversion)
%     schedule    the cells of one case: a struct array of (scenario, code),
%                 every condition of a campaign row in every scenario of the
%                 row, rows and scenarios and conditions in their order
%   A condition is defined by its fixed parameters: renaming its label
%   changes neither its id nor its cells or seeds. The checks of the
%   settings schema have run (study.validate_settings); here the names are
%   checked against A.1 and the campaign against the table, before any
%   computation: a fixed parameter that is no parameter of A.1 (with the
%   closest valid name), a campaign label that is not in the table or is the
%   reference, and a cell (scenario and condition) twice.
%   Side effects: none.

    parameterNames = reshape(cellstr(parameterNames), 1, []);
    scenarios = reshape(cellstr(scenarios), 1, []);
    table = C.conditions;
    n = size(table, 1);
    template = struct('code', '', 'id', '', 'tag', '', 'label', '', 'description', '', ...
        'fixedParameterNames', {{}}, 'freeParameterNames', {{}}, ...
        'fixedParameterIndices', [], 'freeParameterIndices', [], 'mask', [], ...
        'fixedValueSource', 'case_truth', 'role', '', 'scheduledScenarios', {{}}, ...
        'canonicalReference', false, 'supplementaryExecution', false);
    conditions = repmat(template, 1, n);
    for i = 1:n
        code = char(table{i, 1});
        names = reshape(cellstr(table{i, 3}), 1, []);
        fixed = zeros(1, numel(names));
        for k = 1:numel(names)
            hit = find(strcmp(parameterNames, names{k}));
            if isempty(hit)
                error('study:settings:ConditionalParameter', ...
                    ['setting fixed.conditionalInversion.conditions (section A.9 of the settings file): ' ...
                     'condition ''%s'' fixes ''%s'', which is no material parameter of A.1 (%s); did you ' ...
                     'mean ''%s''?'], code, names{k}, strjoin(parameterNames, ', '), ...
                    closest(names{k}, parameterNames));
            end
            fixed(k) = hit;
        end
        fixed = sort(fixed);
        free = setdiff(1:numel(parameterNames), fixed);
        mask = ones(1, numel(parameterNames));
        mask(fixed) = 0;
        reference = isempty(fixed);
        conditions(i) = struct('code', code, 'id', condition_id(parameterNames(fixed)), ...
            'tag', condition_id(parameterNames(fixed)), 'label', char(table{i, 2}), ...
            'description', char(table{i, 2}), 'fixedParameterNames', {parameterNames(fixed)}, ...
            'freeParameterNames', {parameterNames(free)}, 'fixedParameterIndices', fixed, ...
            'freeParameterIndices', free, 'mask', mask, 'fixedValueSource', 'case_truth', ...
            'role', role(reference), 'scheduledScenarios', {{}}, 'canonicalReference', reference, ...
            'supplementaryExecution', ~reference);
    end
    codes = {conditions.code};
    referenceCode = conditions([conditions.canonicalReference]).code;
    runnable = codes(~[conditions.canonicalReference]);

    schedule = struct('scenario', {}, 'code', {});
    rows = C.cells;
    for r = 1:size(rows, 1)
        labels = rows{r, 1};
        if (ischar(labels) || isstring(labels)) && strcmp(char(labels), 'all')
            labels = runnable;
        end
        labels = reshape(cellstr(labels), 1, []);
        for k = 1:numel(labels)
            if strcmp(labels{k}, referenceCode)
                error('study:settings:ConditionalReference', ...
                    ['setting fixed.conditionalInversion.cells (section A.9 of the settings file): ' ...
                     'condition ''%s'' fixes nothing; it is the canonical all_six cell of the inversion ' ...
                     '(step inversion) and is not run by the conditional inversion. Remove it from the ' ...
                     'campaign rows.'], labels{k});
            end
            if ~ismember(labels{k}, codes)
                error('study:settings:ConditionalLabel', ...
                    ['setting fixed.conditionalInversion.cells (section A.9 of the settings file): ' ...
                     'condition ''%s'' is not a label of the condition table (%s); did you mean ''%s''?'], ...
                    labels{k}, strjoin(codes, ', '), closest(labels{k}, runnable));
            end
        end
        rowScenarios = rows{r, 2};
        if (ischar(rowScenarios) || isstring(rowScenarios)) && strcmp(char(rowScenarios), 'all')
            rowScenarios = scenarios;
        end
        rowScenarios = reshape(cellstr(rowScenarios), 1, []);
        for s = 1:numel(rowScenarios)
            for k = 1:numel(labels)
                twice = strcmp({schedule.scenario}, rowScenarios{s}) & strcmp({schedule.code}, labels{k});
                if any(twice)
                    error('study:settings:ConditionalCellTwice', ...
                        ['setting fixed.conditionalInversion.cells (section A.9 of the settings file): ' ...
                         'condition ''%s'' in scenario %s is in more than one row; list each cell once.'], ...
                        labels{k}, rowScenarios{s});
                end
                schedule(end + 1) = struct('scenario', rowScenarios{s}, 'code', labels{k}); %#ok<AGROW>
            end
        end
    end
    % Scenarios in the order in which the campaign rows first name them (the
    % order of the summaries and the status table).
    for i = 1:n
        if conditions(i).canonicalReference
            conditions(i).scheduledScenarios = unique({schedule.scenario}, 'stable');
        else
            conditions(i).scheduledScenarios = unique( ...
                {schedule(strcmp({schedule.code}, conditions(i).code)).scenario}, 'stable');
        end
    end
    design = struct('conditions', conditions, 'reference', referenceCode, 'schedule', schedule);
end

function id = condition_id(names)
%CONDITION_ID The id of a condition from its fixed parameters: <names>_fixed, or baseline when it fixes nothing.
%   A name is the parameter's name without the suffix _RD and without '_',
%   in lower case (m3_f_RD -> m3f, log10_k0_RD -> log10k0, Thickness_RD ->
%   thickness); the names are joined by _and_ in the canonical order.
    if isempty(names)
        id = 'baseline';
        return;
    end
    short = cellfun(@(x) lower(strrep(regexprep(x, '_RD$', ''), '_', '')), names, 'UniformOutput', false);
    id = [strjoin(short, '_and_') '_fixed'];
end

function text = role(reference)
    if reference
        text = 'canonical_all_free_reference';
    else
        text = 'supplementary_truth_conditioned_identifiability';
    end
end

function best = closest(name, names)
%CLOSEST The name of NAMES nearest to NAME (fewest single-character edits).
    best = '';
    if isempty(names), return; end
    distances = cellfun(@(n) edit_distance(lower(name), lower(n)), names);
    [~, k] = min(distances);
    best = names{k};
end

function d = edit_distance(a, b)
%EDIT_DISTANCE Levenshtein distance of two texts.
    m = numel(a); n = numel(b);
    previous = 0:n;
    for i = 1:m
        current = [i, zeros(1, n)];
        for j = 1:n
            current(j + 1) = min([previous(j + 1) + 1, current(j) + 1, previous(j) + (a(i) ~= b(j))]);
        end
        previous = current;
    end
    d = previous(end);
end
