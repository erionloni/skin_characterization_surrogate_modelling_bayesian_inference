function manifest = saved_bound_sensitivity_table(cfg, ~)
%SAVED_BOUND_SENSITIVITY_TABLE The aggregates of one scenario without the fallback cells whose walkers sit at a bound.
%   MANIFEST = plotting.saved_bound_sensitivity_table(CFG) writes the table
%   <scenario>_sensitivity_without_bound_cells into the recovery analysis
%   (settings A.7, CFG.analysis.boundSensitivity; thesis: gp_only and the
%   healthy fallbacks of cases 172, 220, 48, 166 and 246 in
%   physics_guided_full_rank_six, whose healthy replicate has walkers at the
%   lower thickness bound). For every published aggregate of the scenario
%   that contains one of those cells it gives the value with them (the
%   published value) and the value on the cohort without the cases, removed
%   from every design that is compared, each with its N. The values are
%   computed from the saved per-case results with the definitions of the
%   published tables:
%     <scenario>_matched_designs_posterior_width_ratio and
%     <scenario>_matched_designs_recovery_error (recovery): per design and
%       parameter, the mean posterior SD ratio and the mean normalized
%       absolute recovery error over the cases with a posterior in every
%       design (N: cases);
%     recovery_by_scenario_and_design (recovery): per design, the means over
%       the case and parameter rows with a posterior of the SD ratio, the
%       contraction and the truth inclusion in the central 50 % and 95 %
%       intervals (N: rows), and the mean over the cases of each case's mean
%       absolute recovery error (N: cases);
%     <scenario>_design_ranking (design study): per design, over the cases
%       with a posterior in every design, the mean information on the weak
%       pair and on all four parameters, 0.5 (log det C0 - log det Cpost)
%       with the posterior covariance in the unit box and C0 = I/12, the mean
%       D-utility, posterior SD ratio, contraction and 95 % inclusion, and the
%       rank of the designs by the weak-pair information (N: cases).
%   The certified-only values do not change (the cells are healthy
%   fallbacks) and are not repeated. Nothing is written outside the
%   publication layout or when the saved recovery results are absent; the
%   design-ranking rows need the saved design study.
%   Side effects: writes the table.

    manifest = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', 'SourceArtifacts'});
    if ~study.is_publication(cfg), return; end
    S = cfg.analysis.boundSensitivity;
    cellsPath = fullfile(study.source_folder(cfg, 'coverage'), 'posterior_parameter_cells.csv');
    if ~isfile(cellsPath), return; end
    designs = cellstr(cfg.inversion.designNames);
    C = utils.read_csv_table(cellsPath, {'Scenario', 'Design', 'Parameter', 'CellID'});
    C = C(C.Scenario == string(S.scenario), :);
    params = reshape(cellstr(cfg.paramNames), 1, []);
    sources = {cellsPath};
    T = table();
    for excluded = {[], S.cases}
        V = recovery_values(C, designs, params, excluded{1});
        T = merge(T, V, isempty(excluded{1}));
    end
    tables = fullfile(study.source_folder(cfg, 'design_study'), 'scenarios', S.scenario, 'tables');
    covariancePath = fullfile(tables, 'posterior_covariance_reference.csv');
    parameterPath = fullfile(tables, 'posterior_parameter_reference.csv');
    fimPath = fullfile(tables, 'fim_metrics.csv');
    if isfile(covariancePath) && isfile(parameterPath) && isfile(fimPath)
        K = utils.read_csv_table(covariancePath, {'Design', 'RowParameter', 'ColumnParameter'});
        Q = utils.read_csv_table(parameterPath, {'Design', 'Parameter'});
        F = utils.read_csv_table(fimPath, {'Design'});
        weak = params(cfg.analysis.weakPairIndices);
        R = table();
        for excluded = {[], S.cases}
            V = ranking_values(K, Q, F, S.scenario, designs, params, weak, excluded{1});
            R = merge(R, V, isempty(excluded{1}));
        end
        T = [T; R];
        sources = [sources, {covariancePath, parameterPath, fimPath}];
    end
    label = sprintf('%s %s', strrep(plotting.display_name('scenario', S.scenario), ' ', '-'), ...
        strrep(plotting.display_name('design', S.design), ' ', '-'));
    study.export_table(cfg, 'robustness', sprintf('%s_sensitivity_without_bound_cells', S.scenario), T, sources, ...
        sprintf(['Sensitivity: without the %s %s fallback cells with walkers at the thickness bound ' ...
        '(cases %s)'], number_word(numel(S.cases)), label, strjoin(string(S.cases), ', ')), []);
end

function V = recovery_values(C, designs, params, excluded)
%RECOVERY_VALUES The recovery aggregates of the scenario's rows C without the cases EXCLUDED.
    keep = C(~ismember(C.CaseID, excluded) & double(C.ArtifactLoaded) == 1, :);
    matched = [];
    for d = 1:numel(designs)
        here = unique(keep.CaseID(keep.Design == string(designs{d})));
        if d == 1, matched = here; else, matched = intersect(matched, here); end
    end
    V = table();
    for d = 1:numel(designs)
        rows = keep(keep.Design == string(designs{d}), :);
        for p = 1:numel(params)
            m = rows(rows.Parameter == string(params{p}) & ismember(rows.CaseID, matched), :);
            V = add(V, sprintf('%s_matched_designs_posterior_width_ratio', C.Scenario(1)), designs{d}, ...
                sprintf('mean posterior SD ratio, %s', params{p}), mean(m.NormalizedPosteriorSD), numel(matched));
            V = add(V, sprintf('%s_matched_designs_recovery_error', C.Scenario(1)), designs{d}, ...
                sprintf('mean normalized absolute recovery error, %s', params{p}), ...
                mean(m.NormalizedAbsoluteErrorFromPosteriorMedian), numel(matched));
        end
        name = 'recovery_by_scenario_and_design';
        V = add(V, name, designs{d}, 'mean posterior SD ratio (rows)', mean(rows.NormalizedPosteriorSD), height(rows));
        V = add(V, name, designs{d}, 'mean contraction (rows)', mean(rows.ContractionAmount), height(rows));
        V = add(V, name, designs{d}, 'truth inclusion, central 50 % (rows)', mean(rows.TruthCovered50), height(rows));
        V = add(V, name, designs{d}, 'truth inclusion, central 95 % (rows)', mean(rows.TruthCovered95), height(rows));
        [cases, ~, at] = unique(rows.CaseID);
        perCase = accumarray(at, rows.NormalizedAbsoluteErrorFromPosteriorMedian, [], @mean);
        V = add(V, name, designs{d}, 'mean over cases of the mean absolute recovery error', mean(perCase), ...
            numel(cases));
    end
end

function V = ranking_values(K, Q, F, scenario, designs, params, weak, excluded)
%RANKING_VALUES The design ranking's aggregates over the cases with a posterior in every design, without EXCLUDED.
    matched = [];
    for d = 1:numel(designs)
        here = unique(K.CaseID(K.Design == string(designs{d}) & ~ismember(K.CaseID, excluded)));
        if d == 1, matched = here; else, matched = intersect(matched, here); end
    end
    n = numel(matched);
    info = zeros(numel(designs), 1);
    V = table();
    name = sprintf('%s_design_ranking', scenario);
    for d = 1:numel(designs)
        q = zeros(n, 1); full = zeros(n, 1);
        for c = 1:n
            rows = K(K.Design == string(designs{d}) & K.CaseID == matched(c), :);
            q(c) = information(rows, weak);
            full(c) = information(rows, params);
        end
        info(d) = mean(q);
        f = F(F.Design == string(designs{d}) & ismember(F.CaseID, matched), :);
        p = Q(Q.Design == string(designs{d}) & ismember(Q.CaseID, matched), :);
        V = add(V, name, designs{d}, 'mean information on the weak pair [nats]', info(d), n);
        V = add(V, name, designs{d}, 'mean information on all four parameters [nats]', mean(full), n);
        V = add(V, name, designs{d}, 'mean D-utility', mean(f.DOptimalUtility), n);
        V = add(V, name, designs{d}, 'mean posterior SD ratio', mean(p.NormalizedPosteriorSD), n);
        V = add(V, name, designs{d}, 'mean contraction', mean(p.ContractionAmount), n);
        V = add(V, name, designs{d}, 'truth inclusion, central 95 %', mean(p.TruthCovered95), n);
    end
    [~, order] = sort(info, 'descend');
    rank = zeros(numel(designs), 1); rank(order) = 1:numel(designs);
    for d = 1:numel(designs)
        V = add(V, name, designs{d}, 'rank by the information on the weak pair', rank(d), n);
    end
end

function value = information(rows, names)
%INFORMATION 0.5 (log det C0 - log det Cpost) of the parameters NAMES, in the unit box (C0 = I/12).
    k = numel(names);
    C = zeros(k);
    for i = 1:k
        for j = 1:k
            C(i, j) = rows.CovarianceU(rows.RowParameter == string(names{i}) & ...
                rows.ColumnParameter == string(names{j}));
        end
    end
    value = 0.5 * (k * log(1 / 12) - log(det(C)));
end

function T = merge(T, V, first)
%MERGE The values with every case (FIRST: the published values) or without the excluded ones, side by side.
    if first
        T = renamevars(V, 'Value', 'Published');
    else
        T.WithoutTheCells = V.Value;
        T.NWithout = V.N;
    end
end

function V = add(V, aggregate, design, quantity, value, n)
    V = [V; table(string(aggregate), string(design), string(quantity), value, n, 'VariableNames', ...
        {'Aggregate', 'Design', 'Quantity', 'Value', 'N'})];
end

function w = number_word(n)
    words = {'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'};
    w = sprintf('%d', n);
    if n >= 1 && n <= numel(words), w = words{n}; end
end
