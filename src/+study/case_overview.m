function L = case_overview(s, root)
%CASE_OVERVIEW The canonical truths of the shipped results, the status of their cells and their folders.
%   L = study.case_overview(S, ROOT) returns the lines (Markdown) of the
%   case overview of the results README ROOT/README.md
%   (study.write_results_readme): one row per canonical truth of the
%   fixed-route inversion, in its canonical order, with its values from the
%   fixed dataset (settings A.1), the links to its case folders in ROOT (the
%   step folders of both routes that exist) and the status of its cells in
%   the shipped results S.paths.results:
%     - the 18 canonical cells (3 scenarios x 6 designs), per scenario: the
%       number of certified cells and the designs of the healthy fallbacks
%       (a provider that is not certified) and of the unavailable cells
%       (fixed/04_inversion/data/cell_status.csv, the campaign's status
%       table);
%     - the scheduled conditional cells (the status table
%       fixed/07_conditional_inversion/data/cell_status.csv without the
%       canonical references), named by scenario and condition.
%   L is empty when the shipped results hold no canonical status table.
%   Side effects: none.

    L = {};
    fixed = fullfile(s.paths.results, 'fixed');
    canonicalFile = fullfile(fixed, '04_inversion', 'data', 'cell_status.csv');
    if ~isfile(canonicalFile), return; end
    C = utils.read_csv_table(canonicalFile, {'Scenario', 'Design', 'Status'});
    cases = unique(double(C.CaseID), 'stable');
    scenarios = unique(cellstr(C.Scenario), 'stable');
    status = short_status(C.Status);

    conditionalFile = fullfile(fixed, '07_conditional_inversion', 'data', 'cell_status.csv');
    K = table();
    if isfile(conditionalFile)
        K = utils.read_csv_table(conditionalFile, {'Scenario', 'Design', 'Condition', 'Status'});
        K = K(K.Condition ~= "baseline", :);
    end

    D = utils.read_csv_table(study.fixed_dataset_file(s), {});
    values = {'m3_f_RD', 'm3_e_RD', 'k0_RD', 'Thickness_RD'};
    header = ['| Case | Canonical | ' strjoin(strcat('`', values, '`'), ' | ') ' | Case folders | ' ...
        strjoin(scenarios, ' | ')];
    rule = ['|---|---|' repmat('---|', 1, numel(values) + 1 + numel(scenarios))];
    if ~isempty(K)
        header = [header ' | conditional'];
        rule = [rule '---|'];
    end
    counts = [sum(status == "certified"), sum(status == "fallback"), sum(status == "unavailable")];
    L = {'## Cases', '', ...
        sprintf(['The %d canonical truths of the fixed-route inversion in their canonical order ' ...
         '(settings A.6), their values in `data/fixed/fixed_dataset.csv` (four significant ' ...
         'digits here), their case folders and the status of their cells: per likelihood ' ...
         'scenario, the number of ' ...
         'certified cells of the %d observation designs and the designs whose cell is a healthy ' ...
         'fallback (a provider that is not certified) or unavailable (no posterior).'], ...
         numel(cases), numel(unique(cellstr(C.Design)))), '', ...
        [header ' |'], rule};
    for i = 1:numel(cases)
        id = cases(i);
        row = D(double(D.CaseID) == id, :);
        assert(height(row) == 1, 'study:case_overview:Case', ...
            'Case %d of the inversion is not a case of the fixed dataset.', id);
        cells = {sprintf('%d', id), sprintf('#%d', i)};
        for v = values
            cells{end+1} = sprintf('%.4g', row.(v{1})); %#ok<AGROW>
        end
        cells{end+1} = folder_links(root, id); %#ok<AGROW>
        for k = 1:numel(scenarios)
            mine = double(C.CaseID) == id & strcmp(cellstr(C.Scenario), scenarios{k});
            cells{end+1} = status_text(status(mine), cellstr(C.Design(mine))); %#ok<AGROW>
        end
        if ~isempty(K)
            mine = double(K.CaseID) == id;
            names = strcat(cellstr(K.Scenario(mine)), '/', cellstr(K.Condition(mine)));
            cells{end+1} = status_text(short_status(K.Status(mine)), names); %#ok<AGROW>
        end
        L{end+1} = ['| ' strjoin(cells, ' | ') ' |']; %#ok<AGROW>
    end
    L = [L, {'', sprintf(['Canonical cells: %d certified, %d healthy fallbacks, %d unavailable ' ...
        '(of %d).'], counts, height(C))}];
    if ~isempty(K)
        given = short_status(K.Status);
        L{end} = sprintf(['%s Conditional cells (parameters fixed at the truth): %d certified, ' ...
            '%d healthy fallbacks, %d unavailable (of %d).'], L{end}, sum(given == "certified"), ...
            sum(given == "fallback"), sum(given == "unavailable"), height(K));
    end
    L{end+1} = '';
end

function t = folder_links(root, id)
%FOLDER_LINKS Links to the step folders of case ID in ROOT, in the order of study.layout ('' without any).
    C = study.layout().categories;
    C = C(startsWith({C.category}, 'case/'));
    links = {};
    for route = {'fixed', 'generalized'}
        mine = {};
        for c = C(strcmp({C.route}, route{1}))
            step = extractAfter(c.category, 'case/');
            relative = sprintf('%s/cases/case_%d/%s', route{1}, id, step);
            if isfolder(fullfile(root, relative))
                mine{end+1} = sprintf('[%s](%s)', step, relative); %#ok<AGROW>
            end
        end
        if isempty(mine), continue; end
        if strcmp(route{1}, 'generalized')
            mine{1} = ['generalized: ' mine{1}];
        end
        links{end+1} = strjoin(mine, ', '); %#ok<AGROW>
    end
    t = strjoin(links, '; ');
end

function status = short_status(recorded)
%SHORT_STATUS certified, fallback (a healthy fallback) or unavailable (every other status).
    recorded = string(recorded);
    status = repmat("unavailable", numel(recorded), 1);
    status(recorded == "healthy fallback") = "fallback";
    status(recorded == "certified") = "certified";
end

function t = status_text(status, names)
%STATUS_TEXT 'n certified', then the named healthy fallbacks and unavailable cells.
    t = sprintf('%d certified', sum(status == "certified"));
    fallback = names(status == "fallback");
    unavailable = names(status == "unavailable");
    if ~isempty(fallback)
        t = sprintf('%s; fallback: %s', t, strjoin(fallback, ', '));
    end
    if ~isempty(unavailable)
        t = sprintf('%s; unavailable: %s', t, strjoin(unavailable, ', '));
    end
end
