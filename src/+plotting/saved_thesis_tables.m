function manifest = saved_thesis_tables(cfg, ~)
%SAVED_THESIS_TABLES Thesis-facing summary tables of one analysis folder.
%   MANIFEST = plotting.saved_thesis_tables(CFG, OPTIONS) writes, in reproduce
%   mode, the summary tables of the analysis CFG.layout.route /
%   CFG.layout.analysis into its tables/ folder, as CSV with full
%   precision. Every number is copied or counted from saved results (data/,
%   config/); nothing is recomputed. The tables of the posterior-based
%   analyses cover the cells with a posterior, certified and healthy
%   fallback, and give next to each aggregate its value over the certified
%   cells alone (<column>_certified_only); the inversion and the
%   conditional inversion also get cell_status.csv, the status of every
%   cell. MANIFEST is an empty figure manifest (tables
%   only).
%   Outside reproduce mode it does nothing.
%   OPTIONS is unused.
%   Side effects: writes the tables (CSV) and enters them in the index of the analysis.
%   Computation: seconds.

    manifest = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', ...
        'SourceArtifacts'});
    if ~study.is_publication(cfg), return; end
    switch [cfg.layout.route '/' cfg.layout.analysis]
        case 'fixed/01_dataset', fixed_dataset(cfg);
        case 'fixed/02_surrogates', surrogate_assessment(cfg, 'fixed');
        case 'fixed/03_sensitivity', sobol_table(cfg);
        case 'fixed/04_inversion', certification(cfg);
        case 'fixed/05_recovery', recovery(cfg);
        case 'fixed/06_design_study', design_ranking(cfg);
        case 'fixed/07_conditional_inversion', conditional(cfg);
        case 'generalized/01_dataset', generalized_dataset(cfg);
        case 'generalized/02_surrogates', surrogate_assessment(cfg, 'generalized');
        case 'generalized/03_sensitivity', sobol_table(cfg);
        case 'generalized/04_default_protocol_comparison', default_protocol(cfg);
        case 'generalized/05_protocol_screening', screening(cfg);
        case 'generalized/06_confirmation'
            confirmation_design(cfg); confirmation_outcomes(cfg); confirmation_results(cfg);
    end
end

function fixed_dataset(cfg)
    folder = study.source_folder(cfg, 'dataset');
    splitPath = fullfile(folder, 'split_manifest.csv');
    supportPath = fullfile(folder, 'per_output_development_support.csv');
    S = readtable(splitPath, 'Delimiter', ',', 'TextType', 'string');
    % The split records the roles 'development' and 'external_test'.
    development = nnz(S.MethodologicalRole == "development");
    external = nnz(S.MethodologicalRole == "external_test");
    assert(development + external == height(S), 'plotting:saved_thesis_tables:SplitRoles', ...
        ['The split %s has %d cases, but %d development and %d external_test roles; ' ...
         'rerun the step ''dataset''.'], splitPath, height(S), development, external);
    counts = table(["usable cases"; "complete (all six pressures)"; "partial"; ...
        "development"; "external (held out)"], ...
        [height(S); nnz(S.Classification == "complete"); nnz(S.Classification == "partial"); ...
        development; external], ...
        'VariableNames', {'Quantity', 'Cases'});
    study.export_table(cfg, 'dataset', 'dataset_counts', counts, {splitPath}, ...
        'Fixed route: usable cases, completeness and development/external split',[]);
    P = readtable(supportPath, 'Delimiter', ',', 'TextType', 'string');
    support = P(:, {'Output', 'ValidDevelopmentCount', 'CompleteContributorCount', ...
        'PartialContributorCount', 'MissingDevelopmentCount'});
    study.export_table(cfg, 'dataset', 'development_cases_per_output', support, {supportPath}, ...
        'Fixed route: development cases available for training each output',[]);
end

function generalized_dataset(cfg)
    folder = study.source_folder(cfg, 'dataset');
    registryPath = fullfile(folder, 'registries', 'case_registry.csv');
    splitPath = fullfile(folder, 'splits', 'split_registry.csv');
    evidencePath = fullfile(folder, 'output_training_evidence.csv');
    rows = {};
    sources = {};
    if isfile(splitPath)
        S = readtable(splitPath, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
        sources{end+1} = splitPath;
        names = S.Properties.VariableNames;
        roleColumn = names{find(ismember(lower(names), {'split_role', 'role', 'methodologicalrole'}), 1)};
        roles = string(S.(roleColumn));
        rows{end+1} = table("cases in the split registry", height(S), 'VariableNames', {'Quantity', 'Cases'});
        for r = unique(roles).'
            rows{end+1} = table("split role: " + r, nnz(roles == r), ...
                'VariableNames', {'Quantity', 'Cases'}); %#ok<AGROW>
        end
    end
    if isfile(registryPath)
        C = readtable(registryPath, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
        sources{end+1} = registryPath;
        status = string(C.pair_status);
        for r = unique(status).'
            rows{end+1} = table("pair status: " + r, nnz(status == r), ...
                'VariableNames', {'Quantity', 'Cases'}); %#ok<AGROW>
        end
    end
    if ~isempty(rows)
        study.export_table(cfg, 'dataset', 'dataset_counts', vertcat(rows{:}), sources, ...
            'Generalized route: cases by split role and by campaign pair status',[]);
    end
    if isfile(evidencePath)
        E = readtable(evidencePath, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
        study.export_table(cfg, 'dataset', 'development_cases_per_output', E, {evidencePath}, ...
            'Generalized route: training evidence per output',[]);
    end
end

function surrogate_assessment(cfg, route)
    folder = study.source_folder(cfg, 'surrogate_assessment');
    gpPath = fullfile(folder, 'gp_validation_metrics.csv');
    pcePath = fullfile(folder, 'pce_validation_metrics.csv');
    predictionPath = fullfile(folder, 'validation_predictions.csv');
    G = readtable(gpPath, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    columns = {'Output', 'ObservationCount', 'R2', 'RMSE', 'NRMSE_range', 'MAE', ...
        'Coverage50_percent', 'Coverage95_percent', 'GaussianNLPD'};
    T = G(:, columns);
    T.Properties.VariableNames = {'Output', 'ExternalCases', 'GP_R2', 'GP_RMSE_mbar', ...
        'GP_NRMSE_range', 'GP_MAE_mbar', 'GP_Coverage50_percent', 'GP_Coverage95_percent', 'GP_NLPD'};
    sources = {gpPath, predictionPath};
    % NRMSE_range divides by the range of the external truths; the range is
    % recorded next to it (CLN-028) and checked to be the denominator used.
    V = readtable(predictionPath, 'Delimiter', ',', 'TextType', 'string');
    range = zeros(height(T), 1);
    for i = 1:height(T)
        truth = cohort_truths(V, T.Output(i));
        assert(numel(truth) == T.ExternalCases(i), 'plotting:saved_thesis_tables:CohortSize', ...
            '%s: %d external predictions for %d cases.', T.Output(i), numel(truth), ...
            T.ExternalCases(i));
        range(i) = max(truth) - min(truth);
        assert(abs(T.GP_NRMSE_range(i) * range(i) - T.GP_RMSE_mbar(i)) <= ...
            1e-9 * T.GP_RMSE_mbar(i), 'plotting:saved_thesis_tables:NRMSEDenominator', ...
            '%s: the saved NRMSE is not RMSE / range of the external truths.', T.Output(i));
    end
    T = addvars(T, range, 'After', 'ExternalCases', 'NewVariableNames', 'TruthRange_mbar');
    if isfile(pcePath)
        P = readtable(pcePath, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
        if ismember('Family', P.Properties.VariableNames), P = P(P.Family == "pce", :); end
        [~, where] = ismember(T.Output, P.Output);
        T.PCE_R2 = P.R2(where);
        T.PCE_RMSE_mbar = P.RMSE(where);
        T.PCE_NRMSE_range = P.NRMSE_range(where);
        sources{end+1} = pcePath;
    end
    study.export_table(cfg, 'surrogate', 'external_assessment_metrics', T, sources, ...
        sprintf(['%s route: accuracy on the external cases (GP with calibrated emulator ' ...
        'variance, PCE mean only); NRMSE_range = RMSE / TruthRange_mbar, the range of ' ...
        'the external truths'], route),[]);
    if strcmp(route, 'fixed'), training_versus_external(cfg); end
    % Emulator-variance calibration: v_emu = tau^2 * h^gamma (the record of
    % the settings, A.3 and B.3).
    calibrationPath = cfg.paths.emulatorErrorCalibration;
    C = jsondecode(fileread(calibrationPath));
    outputs = string(cfg.outputNames(:));
    b = C.bootstrap_provenance;
    K = table(outputs, repmat(C.shared_gamma, numel(outputs), 1), ...
        repmat(b.gamma_q025, numel(outputs), 1), repmat(b.gamma_q975, numel(outputs), 1), ...
        C.tau_squared_mbar2(:), b.tau_squared_q025_mbar2(:), b.tau_squared_q975_mbar2(:), ...
        'VariableNames', {'Output', 'Gamma', 'GammaBootstrapQ025', 'GammaBootstrapQ975', ...
        'Tau2_mbar2', 'Tau2BootstrapQ025_mbar2', 'Tau2BootstrapQ975_mbar2'});
    study.export_table(cfg, 'surrogate', 'emulator_variance_calibration', K, {calibrationPath}, ...
        sprintf(['%s route: frozen emulator-variance calibration, v_emu = tau^2 * h^gamma with ' ...
        'h = GP variance / process variance (bootstrap 95%% intervals)'], route),[]);
end

function training_versus_external(cfg)
%TRAINING_VERSUS_EXTERNAL GP metrics on the training cases and the external cases, with denominators.
%   NRMSE_range divides the RMSE by the truth range of the cohort it is
%   computed on, so the training and external values have different
%   denominators (CLN-028): N and that range stand next to every NRMSE, and
%   RMSE is the like-for-like comparison. No difference of NRMSE values is
%   formed.
    metricPath = fullfile(study.source_folder(cfg, 'downstream_error_budget'), ...
        'gp_train_validation_metrics.csv');
    trainingPath = fullfile(study.source_folder(cfg, 'surrogate_training_predictions'), ...
        'gp_training_predictions.csv');
    externalPath = fullfile(study.source_folder(cfg, 'surrogate_assessment'), ...
        'validation_predictions.csv');
    if ~(isfile(metricPath) && isfile(trainingPath) && isfile(externalPath)), return; end
    M = readtable(metricPath, 'Delimiter', ',', 'TextType', 'string');
    M = M(ismember(M.Cohort, ["training" "held_out_validation"]), :);
    predictions = struct('training', readtable(trainingPath, 'Delimiter', ',', 'TextType', 'string'), ...
        'held_out_validation', readtable(externalPath, 'Delimiter', ',', 'TextType', 'string'));
    range = zeros(height(M), 1);
    for i = 1:height(M)
        truth = cohort_truths(predictions.(char(M.Cohort(i))), M.Output(i));
        assert(numel(truth) == M.CaseCount(i), 'plotting:saved_thesis_tables:CohortSize', ...
            'Cohort %s, %s: %d predictions for %d cases.', M.Cohort(i), M.Output(i), ...
            numel(truth), M.CaseCount(i));
        range(i) = max(truth) - min(truth);
        assert(abs(M.NRMSE_range(i) * range(i) - M.RMSE(i)) <= 1e-9 * max(M.RMSE(i), eps), ...
            'plotting:saved_thesis_tables:NRMSEDenominator', ...
            'Cohort %s, %s: the saved NRMSE is not RMSE / truth range of the cohort.', ...
            M.Cohort(i), M.Output(i));
    end
    cohort = replace(M.Cohort, "held_out_validation", "external");
    T = table(M.Output, cohort, M.CaseCount, range, M.R2, M.RMSE, M.NRMSE_range, M.MAE, ...
        M.Coverage95Percent, 'VariableNames', {'Output', 'Cohort', 'Cases', ...
        'TruthRange_mbar', 'R2', 'RMSE_mbar', 'NRMSE_range', 'MAE_mbar', 'Coverage95_percent'});
    [~, order] = sortrows([double(M.OutputIndex), double(cohort == "external")]);
    T = T(order, :);
    study.export_table(cfg, 'surrogate', 'gp_training_vs_external_metrics', T, ...
        {metricPath, trainingPath, externalPath}, ...
        ['fixed route: GP on its training cases and on the 61 external cases; NRMSE_range = ' ...
         'RMSE / TruthRange_mbar of the same cohort, so the NRMSE values of the two cohorts ' ...
         'have different denominators (compare RMSE)'],[]);
end

function truth = cohort_truths(P, output)
%COHORT_TRUTHS COMSOL values of one output over the cases where it was observed.
    if ismember('ObservationAvailable', P.Properties.VariableNames)
        P = P(P.ObservationAvailable == 1, :);
    end
    truth = double(P.COMSOL(P.Output == output));
end

function sobol_table(cfg)
    folder = study.source_folder(cfg, 'sensitivity');
    firstPath = fullfile(folder, 'primary', 'sobol_gp_first.csv');
    totalPath = fullfile(folder, 'primary', 'sobol_gp_total.csv');
    if ~(isfile(firstPath) && isfile(totalPath)), return; end
    F = readtable(firstPath, 'Delimiter', ',', 'VariableNamingRule', 'preserve', 'TextType', 'string');
    Tt = readtable(totalPath, 'Delimiter', ',', 'VariableNamingRule', 'preserve', 'TextType', 'string');
    inputs = F.Properties.VariableNames(2:end);
    rows = {};
    for r = 1:height(F)
        for k = 1:numel(inputs)
            rows{end+1} = table(string(F{r, 1}), string(inputs{k}), F{r, k + 1}, Tt{r, k + 1}, ...
                'VariableNames', {'Output', 'Input', 'FirstOrder', 'TotalOrder'}); %#ok<AGROW>
        end
    end
    study.export_table(cfg, 'sensitivity', 'sobol_indices_gp', vertcat(rows{:}), ...
        {firstPath, totalPath}, 'First- and total-order Sobol indices from the GP surrogate',[]);
end

function certification(cfg)
    % The campaign's status table (study.cell_status_columns).
    indexPath = fullfile(study.source_folder(cfg, 'inversion'), 'cell_status.csv');
    T = utils.read_csv_table(indexPath, {'Scenario', 'Design', 'Status', 'ProviderSampler', ...
        'Reason', 'HealthNote'});
    scenarios = string(cfg.inversion.activeScenarioTags);
    designs = string(cfg.inversion.designNames);
    rows = {};
    for s = scenarios(:).'
        for d = designs(:).'
            one = T(T.Scenario == s & T.Design == d, :);
            rows{end+1} = table(s, d, height(one), nnz(one.Status == "certified"), ...
                nnz(one.Status == "healthy fallback"), nnz(one.Status == "unavailable"), ...
                'VariableNames', {'Scenario', 'Design', 'Planned', 'Certified', ...
                'HealthyFallback', 'Unavailable'}); %#ok<AGROW>
        end
    end
    C = vertcat(rows{:});
    C = [C; table("all", "all", sum(C.Planned), sum(C.Certified), sum(C.HealthyFallback), ...
        sum(C.Unavailable), 'VariableNames', C.Properties.VariableNames)];
    study.export_table(cfg, 'inversion', 'certification_counts', C, {indexPath}, ...
        'Canonical inversion cells by scenario and design: certified, healthy fallback, unavailable', ...
        'all');
    study.export_table(cfg, 'inversion', 'cell_status', T, {indexPath}, ...
        ['Status of every canonical inversion cell: certified, healthy fallback (a selected ' ...
         'provider that is not certified) or unavailable (no posterior), with the provider, ' ...
         'whether it counts in the certified-only values, why it is not certified and the health ' ...
         'note of its undefined or degenerate warning diagnostics'], 'all');
    essPath = fullfile(study.source_folder(cfg, 'inversion_diagnostics'), ...
        'ensemble_ess_per_parameter_ranks.csv');
    if isfile(essPath)
        E = utils.read_csv_table(essPath, {'Scenario', 'Design', 'Condition'});
        groups = unique(E(:, {'Scenario', 'Design'}), 'rows');
        rows = {};
        for g = 1:height(groups)
            one = E(E.Scenario == groups.Scenario(g) & E.Design == groups.Design(g) & ...
                E.Condition == "", :);
            if isempty(one), continue; end
            rows{end+1} = table(groups.Scenario(g), groups.Design(g), height(one), ...
                median(one.RecordedBulkESS), median(one.CorrectedBulkESS), ...
                max(one.RecordedBulkESS), max(one.CorrectedBulkESS), ...
                nnz(one.CorrectedBulkESSAboveThreshold), 'VariableNames', {'Scenario', 'Design', ...
                'ParameterRecords', 'MedianRecordedBulkESS', 'MedianCorrectedBulkESS', ...
                'MaxRecordedBulkESS', 'MaxCorrectedBulkESS', 'CorrectedAbove400'}); %#ok<AGROW>
        end
        study.export_table(cfg, 'inversion', 'ensemble_bulk_ess_correction', vertcat(rows{:}), ...
            {essPath}, ['Ensemble bulk ESS of the replicate pairs, as recorded (ranks pooled over ' ...
            'parameters) and corrected (ranks per parameter); warning diagnostic only'], ...
            'all');
    end
end

function recovery(cfg)
%RECOVERY Posterior width, contraction, truth inclusion and recovery error per scenario and design.
%   Over the case x parameter records with a posterior (IncludedRows:
%   certified and healthy fallback), each value followed by its value over
%   the certified records alone (CertifiedRows).
    path = fullfile(study.source_folder(cfg, 'coverage'), 'summary_by_scenario_design.csv');
    T = readtable(path, 'Delimiter', ',', 'TextType', 'string');
    R = T(:, {'Scenario', 'Design', 'PlannedRows'});
    R.IncludedRows = T.IncludedRows;
    R.CertifiedRows = T.CertifiedRows;
    for metric = {'MeanNormalizedPosteriorSD', 'MeanContractionAmount', 'MeanTruthCovered50', ...
            'MeanTruthCovered95', 'AcrossCaseMeanNormAbsErrorFromPosteriorMedian'}
        R.(metric{1}) = T.(metric{1});
        R.([metric{1} '_certified_only']) = T.([metric{1} '_certified_only']);
    end
    study.export_table(cfg, 'robustness', 'recovery_by_scenario_and_design', R, {path}, ...
        ['Posterior width, contraction, truth inclusion and recovery error per scenario and design, ' ...
        'over the records with a posterior (certified and healthy fallback; rows = case x parameter ' ...
        'records), each value followed by its value over the certified records alone'], 'all');
end

function design_ranking(cfg)
    scenarios = string(cfg.inversion.activeScenarioTags);
    for s = scenarios(:).'
        path = fullfile(fullfile(study.source_folder(cfg, 'design_study'), 'scenarios', ...
            char(s), 'tables'), 'design_summary.csv');
        if ~isfile(path), continue; end
        T = readtable(path, 'Delimiter', ',', 'TextType', 'string');
        R = T(:, {'Design'});
        for column = {'MeanQInformation', 'MeanFullInformation', 'MeanDUtility', ...
                'MeanNormalizedPosteriorSD', 'MeanContractionAmount', 'MeanCoverage95', ...
                'MatchedCaseCount', 'AnalysisStatus'}
            R.(column{1}) = T.(column{1});
            R.([column{1} '_certified_only']) = T.([column{1} '_certified_only']);
        end
        R.RankByQInformation = rank_of(T.MeanQInformation);
        R.RankByQInformation_certified_only = rank_of(T.MeanQInformation_certified_only);
        % The numerical rank of the local Fisher information (4: full rank);
        % the spectra and condition-number figures leave out the zeros and the
        % infinite values of designs without full rank.
        R.MeanNumericalRank = T.MeanNumericalRank;
        R.MeanNumericalRank_certified_only = T.MeanNumericalRank_certified_only;
        study.export_table(cfg, 'stage9', sprintf('%s_design_ranking', s), R, {path}, ...
            sprintf(['Design comparison, %s: posterior target-q information and related metrics ' ...
            'over the matched cases with a posterior (certified and healthy fallback), each followed ' ...
            'by its value over the matched certified cases, and the numerical rank of the local ' ...
            'Fisher information'], s), struct('Scenario', s));
    end
end

function conditional(cfg)
%CONDITIONAL The matched case cohorts of the condition comparisons, and the status of every cell.
    reports = fullfile(study.source_folder(cfg, 'conditional_inversion'), 'reports');
    path = fullfile(reports, 'conditional_inversion_matched_summary.csv');
    if ~isfile(path), return; end
    T = readtable(path, 'Delimiter', ',', 'TextType', 'string');
    R = T(:, {'AnalysisID', 'Scenario', 'RequiredConditions', 'ExpectedCaseCount'});
    for column = {'MatchedCaseCount', 'IncludedCaseIDs', 'ExcludedCaseIDs'}
        R.(column{1}) = T.(column{1});
        R.([column{1} '_certified_only']) = T.([column{1} '_certified_only']);
    end
    study.export_table(cfg, 'inversion/conditional', 'conditional_matched_cohorts', R, {path}, ...
        ['Conditional inversion: matched case cohorts of the condition comparisons, cases with a ' ...
         'posterior (certified or healthy fallback) for every condition, and the same over the ' ...
         'certified cells alone'], 'all');
    % The conditional campaign's status table (study.cell_status_columns).
    statusPath = fullfile(study.source_folder(cfg, 'conditional_inversion'), 'cell_status.csv');
    S = utils.read_csv_table(statusPath, {'Scenario', 'Design', 'Condition', 'Status', ...
        'ProviderSampler', 'Reason'});
    study.export_table(cfg, 'inversion/conditional', 'cell_status', S, {statusPath}, ...
        ['Status of every scheduled conditional cell and of its canonical reference (condition ' ...
         'baseline): certified, healthy fallback or unavailable, with the provider, whether ' ...
         'it counts in the certified-only values and why it is not certified'], 'all');
    % The posterior SD of each condition against the reference.
    [cases, summary, sources] = plotting.conditional_sd_ratio_tables(cfg);
    study.export_table(cfg, 'inversion/conditional', 'conditional_sd_ratios', cases, sources, ...
        ['Conditional inversion: per matched case, condition and free parameter, the posterior SD ' ...
         'over the prior SD of the condition''s cell and of the reference (all parameters free), ' ...
         'their ratio, the replicate discrepancy of both cells (normalized Wasserstein distance ' ...
         'and relative SD difference of the two replicates) and their recovery errors'], 'all');
    study.export_table(cfg, 'inversion/conditional', 'conditional_sd_ratio_summary', summary, ...
        sources, ['Conditional inversion: per scenario, condition and free parameter, the median ' ...
         'and quartiles over the matched cases of the SD ratio to the reference and of the ' ...
         'recovery errors, and the median replicate SD difference, each followed by its value ' ...
         'over the certified cells alone'], 'all');
end

function r = rank_of(q)
%RANK_OF Rank 1 for the largest value; NaN when a design has no value (no partial ranking).
    r = nan(numel(q), 1);
    if all(isfinite(q))
        [~, order] = sort(q, 'descend');
        r(order) = 1:numel(q);
    end
end

function default_protocol(cfg)
    folder = study.source_folder(cfg, 'default_protocol_comparison');
    gpPath = fullfile(folder, 'default_protocol_gp_metrics.csv');
    if ~isfile(gpPath), return; end
    G = readtable(gpPath, 'Delimiter', ',', 'TextType', 'string');
    columns = {'Output', 'Cohort', 'CompatibilityStatus', 'ObservationCount', 'R2', 'RMSE', ...
        'NRMSE_range', 'MAE', 'Coverage95_percent'};
    recorded = "not recorded";
    if ismember('CompatibilityStatus', G.Properties.VariableNames) && height(G) > 0
        recorded = lower(strrep(G.CompatibilityStatus(1), '_', ' '));
    end
    study.export_table(cfg, 'default_protocol_cross_route', 'default_protocol_gp_metrics', ...
        G(:, columns(ismember(columns, G.Properties.VariableNames))), {gpPath}, ...
        sprintf(['Generalized GP at the default protocol against the fixed-route COMSOL values ' ...
        '(recorded compatibility status: %s)'], recorded),[]);
end

function screening(cfg)
    top = fullfile(study.source_folder(cfg, 'screening'), 'rankings', 'top10_protocols.csv');
    if isfile(top)
        T = readtable(top, 'Delimiter', ',', 'TextType', 'string');
        columns = {'CovarianceCase', 'Rank', 'CandidateIndex', 'RateMagnitude_kPa_s', 'Hold_s', ...
            'Pause_s', 'IsDefault', 'MeanTargetProxyLambdaMax', 'RelativePrimaryImprovement'};
        study.export_table(cfg, 'screening', 'top10_protocols', ...
            T(:, columns(ismember(columns, T.Properties.VariableNames))), {top}, ...
            'Ten best protocols by the primary objective, per covariance view',[]);
    end
    leaders = fullfile(study.source_folder(cfg, 'six_objective'), 'six_objective_leaders.csv');
    if isfile(leaders)
        L = readtable(leaders, 'Delimiter', ',', 'TextType', 'string');
        L = L(:, ~ismember(L.Properties.VariableNames, {'CandidateID'}));
        study.export_table(cfg, 'screening', 'six_objective_leaders', L, {leaders}, ...
            'Best protocol for each of the six objectives and covariance views',[]);
    end
end

function confirmation_results(cfg)
%CONFIRMATION_RESULTS The status and comparison tables of a compared confirmation campaign.
%   Nothing before the step compare has run (no placeholder rows).
    folder = study.source_folder(cfg, 'confirmation');
    statusPath = fullfile(folder, 'cell_status.csv');
    if ~isfile(fullfile(folder, 'campaign', 'status', 'confirmation_status.json')) || ...
            ~isfile(statusPath)
        return;
    end
    % The analysis's command is that of its first step (the design); these
    % tables come from the step compare (as the figures, study.renderers).
    cfg.layout.command = strrep(cfg.layout.command, '{''export_design''}', '{''compare''}');
    S = utils.read_csv_table(statusPath, {'Protocol', 'ProtocolRole', 'Design', 'Status', ...
        'ProviderSampler', 'Reason'});
    study.export_table(cfg, 'confirmation', 'cell_status', S, {statusPath}, ...
        ['Status of every confirmation cell (material x protocol in the confirmation''s ' ...
         'observation design; then the cells of the complete pairs in the descriptive design): ' ...
         'certified, healthy fallback (a healthy provider that was not certified) or unavailable ' ...
         '(no posterior), with the provider, whether it counts in the certified-only values and ' ...
         'why it is not certified'], 'all');
    [T, sources] = plotting.confirmation_result_tables(cfg);
    study.export_table(cfg, 'confirmation', 'confirmation_sd_ratios', T.sdRatios, sources, ...
        ['Per matched material, focused protocol and parameter: the posterior SD over the prior ' ...
         'SD under the protocol and under the default, their ratio, whether the parameter is a ' ...
         'target of the protocol''s objective, the replicate discrepancy of both cells ' ...
         '(normalized Wasserstein distance and relative SD difference of the two replicates) ' ...
         'and their recovery errors'], 'all');
    study.export_table(cfg, 'confirmation', 'confirmation_sd_ratio_summary', T.sdRatioSummary, ...
        sources, ['Per focused protocol and target parameter, over the matched materials: the ' ...
         'fraction with a smaller SD than under the default, the median and quartiles of the SD ' ...
         'ratio and the median replicate SD difference, each with its certified-only value'], 'all');
    study.export_table(cfg, 'confirmation', 'confirmation_objective_summary', ...
        T.objectiveSummary, sources, ['Per focused protocol and objective of the screen: the ' ...
         'matched materials, the fraction improved and the median and quartiles of the ratio of ' ...
         'the posterior objective to the default''s, each with its certified-only value'], 'all');
    study.export_table(cfg, 'confirmation', 'confirmation_fim_agreement', T.fimAgreement, ...
        sources, ['FIM-predicted against posterior change per focused protocol and objective: ' ...
         'the fraction with the same direction and the Spearman rank correlation over the matched ' ...
         'materials, each with its certified-only value'], 'all');
    study.export_table(cfg, 'confirmation', 'confirmation_recovery_error', T.recoveryError, ...
        sources, ['Recovery error of the posterior median (over the prior width) per protocol and ' ...
         'parameter, over the materials whose four cells have a posterior (certified-only: four ' ...
         'certified cells)'], 'all');
    % The descriptive design of the complete pairs (settings B.7 completePairsDesign).
    [C, sources] = plotting.confirmation_result_tables(cfg, 'complete_pairs');
    if isempty(C), return; end
    cells = struct('Design', string(C.design));
    study.export_table(cfg, 'confirmation', 'confirmation_complete_pairs_sd_ratios', C.sdRatios, ...
        sources, sprintf(['%s (design %s): per pair and parameter, the posterior SD over the prior ' ...
         'SD under the focused protocol and the default, their ratio and the replicate ' ...
         'discrepancy of both cells'], C.note, C.design), cells);
    study.export_table(cfg, 'confirmation', 'confirmation_complete_pairs_sd_ratio_summary', ...
        C.sdRatioSummary, sources, sprintf(['%s (design %s): per focused protocol and target ' ...
         'parameter, the columns of confirmation_sd_ratio_summary'], C.note, C.design), cells);
    study.export_table(cfg, 'confirmation', 'confirmation_complete_pairs_objective_summary', ...
        C.objectiveSummary, sources, sprintf(['%s (design %s): per focused protocol and objective, ' ...
         'the columns of confirmation_objective_summary'], C.note, C.design), cells);
end

function confirmation_outcomes(cfg)
%CONFIRMATION_OUTCOMES How the confirmation's COMSOL solves ended, per protocol and probe (once imported).
%   The step import_observations writes it (confirmation.import_confirmation_observations).
    file = fullfile(study.source_folder(cfg, 'confirmation'), 'observations', 'comsol_outcomes.csv');
    if ~isfile(file), return; end
    T = utils.read_csv_table(file, {'Protocol', 'Probe', 'EarlyStopPhase', 'OtherStatus'});
    cfg.layout.command = strrep(cfg.layout.command, '{''export_design''}', '{''import_observations''}');
    study.export_table(cfg, 'confirmation', 'confirmation_comsol_outcomes', T, {file}, ...
        ['How the COMSOL solves of the confirmation ended, per protocol and probe: completed (the ' ...
         'three cycles), early stop (with the phase it stopped in; phase 5 is the hold of cycle 2), ' ...
         'nonlinear failure, not run'], []);
end

function confirmation_design(cfg)
    % The design of the settings (B.7, confirmation.confirmation_design: the
    % truths from the fixed dataset); a rerun renders the design its step
    % export_design wrote into the run folder.
    columns = {'DesignIndex', 'MaterialCaseID', 'Protocol', 'ProtocolRole', 'ObjectiveID', ...
        'm3_f_RD', 'm3_e_RD', 'log10_k0_RD', 'Thickness_RD', 'SignedRate_kPa_s', 'Hold_s', 'Pause_s'};
    if isfield(cfg, 'layout') && isfield(cfg.layout, 'strictSources') && cfg.layout.strictSources
        rowsPath = fullfile(cfg.layout.results, 'generalized', '06_confirmation', 'data', 'design', ...
            'design_rows.csv');
        if ~isfile(rowsPath), return; end
        D = confirmation.read_exact_table(rowsPath, columns([1 2 6:end]));
        sources = {rowsPath};
    else
        design = confirmation.confirmation_design(cfg);
        D = design.rows;
        sources = {cfg.realData.csv};
    end
    study.export_table(cfg, 'confirmation', 'confirmation_design', D(:, columns), sources, ...
        sprintf('Confirmation design of the settings: %d materials x %d protocols', ...
        numel(unique(D.MaterialCaseID)), numel(unique(D.Protocol))),[]);
    % The screen's proxy of the design's protocols, as the step export_design
    % wrote it (confirmation.design_predictions).
    file = fullfile(study.source_folder(cfg, 'confirmation'), 'design', 'design_predictions.csv');
    if ~isfile(file), return; end
    P = utils.read_csv_table(file, {'Design', 'Protocol', 'ProtocolRole', 'CovarianceCase', 'ObjectiveID'});
    study.export_table(cfg, 'confirmation', 'confirmation_design_predictions', P, {file}, ...
        ['The protocol screen''s proxy of the design''s protocols (its six objectives, both ' ...
         'covariance views) at the screen''s 1,000 material points, with all six pressures (the ' ...
         'screen''s values) and in the confirmation''s observation designs: mean, median and 90 % ' ...
         'quantile of the score, the default''s mean, the relative improvement and the fractions ' ...
         'of materials improved, near-equal and worse'], []);
end
