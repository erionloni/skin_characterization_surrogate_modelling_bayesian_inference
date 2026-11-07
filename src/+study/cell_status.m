function T = cell_status(cfg)
%CELL_STATUS The inversion cells of an analysis and the status of each.
%   T = study.cell_status(CFG) returns, for the analysis CFG.layout.route /
%   CFG.layout.analysis, one row per inversion cell its figures and tables
%   draw on: CaseID, Scenario, Design, Condition ("" for a canonical cell;
%   for a conditional cell its condition, "baseline" for the canonical
%   all-free reference), Status: "certified", "healthy fallback" (a
%   selected provider that is not certified) or "unavailable" (no
%   posterior), and InCertifiedOnlyValues: whether the cell counts in the
%   certified-only values of the summary tables (the columns ending in
%   _certified_only). The status is read from the analysis's own saved
%   results:
%     fixed 04_inversion              data/cell_status.csv (the campaign's
%                                     status table)
%     fixed 05_recovery               data/tables/posterior_cell_status.csv
%                                     (a run without the recovery: the
%                                     cells of data/combinations/cohort.csv)
%     fixed 06_design_study           data/tables/certification_coverage.csv
%     fixed 07_conditional_inversion  data/cell_status.csv (the conditional
%                                     campaign's status table)
%     fixed 08_ratio_error_curves     data/cohort.csv (its cells)
%     fixed 09_gp_mean_inversion      data/cell_status.csv (its cells) and
%                                     data/comparison.csv (the canonical
%                                     all_six cells it is compared with,
%                                     their shipped status)
%     generalized 06_confirmation     data/cell_status.csv (the
%                                     confirmation's status table: CaseID
%                                     the material, Condition the protocol)
%   and T is empty for every other analysis and when the file is absent.
%   Every certified cell counts in the certified-only values
%   (InCertifiedOnlyValues, as the status tables record it).
%   study.index_entry states the status of the cells of each figure and
%   table from it.
%   Side effects: none.

    T = table('Size', [0 6], ...
        'VariableTypes', {'double', 'string', 'string', 'string', 'string', 'logical'}, ...
        'VariableNames', {'CaseID', 'Scenario', 'Design', 'Condition', 'Status', ...
        'InCertifiedOnlyValues'});
    if strcmp(cfg.layout.route, 'generalized') && strcmp(cfg.layout.analysis, '06_confirmation')
        % The confirmation: one cell per material, protocol (in Condition) and
        % observation design, measurement_plus_gp.
        file = fullfile(study.source_folder(cfg, 'confirmation'), 'cell_status.csv');
        if ~isfile(file), return; end
        P = utils.read_csv_table(file, {'Protocol', 'ProtocolRole', 'Design', 'Status', ...
            'ProviderSampler', 'Reason'});
        T = table(double(P.MaterialCaseID), repmat("measurement_plus_gp", height(P), 1), ...
            P.Design, P.Protocol, P.Status, ...
            logical(P.InCertifiedOnlyValues), 'VariableNames', T.Properties.VariableNames);
        return;
    end
    if ~strcmp(cfg.layout.route, 'fixed'), return; end
    switch cfg.layout.analysis
        case '04_inversion'
            file = fullfile(study.source_folder(cfg, 'inversion'), 'cell_status.csv');
            if ~isfile(file), return; end
            P = utils.read_csv_table(file, {'Scenario', 'Design', 'Status'});
            T = rows(P, repmat("", height(P), 1), P.Status);
            T.InCertifiedOnlyValues = logical(P.InCertifiedOnlyValues);
        case '05_recovery'
            % The recovery's status table; in a run with the parameter
            % combinations alone, their cells.
            file = optional_file(cfg, 'coverage', 'posterior_cell_status.csv');
            if isfile(file)
                P = utils.read_csv_table(file, {'Scenario', 'Design', 'ExecutionStatus'});
                T = rows(P, repmat("", height(P), 1), named(P.ExecutionStatus));
                return;
            end
            file = optional_file(cfg, 'combinations', 'cohort.csv');
            if ~isfile(file), return; end
            P = utils.read_csv_table(file, {'Scenario', 'Design', 'Status', 'ProviderSampler', 'Note'});
            T = rows(P, repmat("", height(P), 1), P.Status);
        case '06_design_study'
            file = fullfile(study.source_folder(cfg, 'design_study'), 'tables', ...
                'certification_coverage.csv');
            if ~isfile(file), return; end
            P = utils.read_csv_table(file, {'Scenario', 'Design', 'CellStatus'});
            T = rows(P, repmat("", height(P), 1), named(P.CellStatus));
        case '07_conditional_inversion'
            file = fullfile(study.source_folder(cfg, 'conditional_inversion'), 'cell_status.csv');
            if ~isfile(file), return; end
            P = utils.read_csv_table(file, {'Scenario', 'Design', 'Condition', 'Status'});
            T = rows(P, P.Condition, P.Status);
            T.InCertifiedOnlyValues = logical(P.InCertifiedOnlyValues);
        case '08_ratio_error_curves'
            file = fullfile(study.source_folder(cfg, 'ratio_error_curves'), 'cohort.csv');
            if ~isfile(file), return; end
            P = utils.read_csv_table(file, {'Scenario', 'Design', 'Role', 'Status', 'ProviderSampler', 'Note'});
            T = rows(P, repmat("", height(P), 1), P.Status);
        case '09_gp_mean_inversion'
            % Its own cells, then the canonical all_six cells it is compared
            % with, with their shipped status (data/comparison.csv).
            folder = optional_file(cfg, 'gp_mean_inversion', '');
            file = fullfile(folder, 'cell_status.csv');
            if isempty(folder) || ~isfile(file), return; end
            P = utils.read_csv_table(file, {'Scenario', 'Design', 'Status', 'ProviderSampler', 'Reason', ...
                'HealthNote', 'LevelsRun'});
            T = rows(P, repmat("", height(P), 1), P.Status);
            T.InCertifiedOnlyValues = logical(P.InCertifiedOnlyValues);
            C = utils.read_csv_table(fullfile(folder, 'comparison.csv'), {'Parameter', 'Scenario', ...
                'Status', 'Source'});
            C = C(C.Scenario ~= "gp_mean_det", :);
            [~, first] = unique(compose("%d|%s", double(C.CaseID), C.Scenario), 'stable');
            C = C(first, :);
            C.Design = repmat("all_six", height(C), 1);
            canonical = rows(C, repmat("", height(C), 1), C.Status);
            canonical.InCertifiedOnlyValues = logical(C.InCertifiedOnlyValues);
            T = [T; canonical];
    end
end

function file = optional_file(cfg, key, name)
%OPTIONAL_FILE A file of a saved-result folder, or '' when a rerun does not hold the folder.
    try
        file = fullfile(study.source_folder(cfg, key), name);
    catch err
        if ~strcmp(err.identifier, 'study:source_folder:NotInRun'), rethrow(err); end
        file = '';
    end
end

function T = rows(P, condition, status)
    T = table(double(P.CaseID), string(P.Scenario), string(P.Design), string(condition), status, ...
        status == "certified", 'VariableNames', {'CaseID', 'Scenario', 'Design', 'Condition', ...
        'Status', 'InCertifiedOnlyValues'});
end

function status = named(recorded)
%NAMED The status names of the recorded states (certified, exploratory_noncertified, other).
    recorded = string(recorded);
    status = repmat("unavailable", numel(recorded), 1);
    status(recorded == "exploratory_noncertified") = "healthy fallback";
    status(recorded == "certified") = "certified";
end
