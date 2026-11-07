function result = ratio_error_curves(cfg)
%RATIO_ERROR_CURVES How well the draws of each posterior reproduce the observed cycle-to-cycle ratios.
%   RESULT = features.ratio_error_curves(CFG) maps, for the cells of the
%   settings (A.11, CFG.analysis.ratioErrorCurves: the cases of one scenario
%   and design with a posterior, certified or healthy fallback, and the
%   supplement cases), how well the parameter values inside each posterior
%   reproduce the four cycle-to-cycle pressure ratios of the observation the
%   posterior used. For every retained draw of each replicate of the
%   provider's level (never pooled), the GP mean of the production model
%   (CFG.files.gp; mean only, surrogates.evaluate) gives the ratio
%   errors (features.ratio_errors: the discrepancy d in units of the
%   reference CV, the level discrepancy, the four signed ratio errors and
%   the double ratio). Descriptive only: no MCMC, and the ratios are
%   functions of the same six pressures.
%   Writes below CFG.paths.ratioErrorCurves:
%     cohort.csv          one row per cell: role (cohort or supplement),
%                         status, provider, replicates and draw counts
%     draws/<scenario>/case_<id>_replicate_<r>.mat
%                         per draw (row order of the shipped draws:
%                         iteration i of walker w is row i + (w-1) times the
%                         retained iterations): drawIndex, walker,
%                         retainedIteration, step, d, dLevel, e1..e4 (full
%                         precision, plain numbers); the GP means are not
%                         stored (recomputable from the draws and the model)
%     bin_summaries.csv   per cell, replicate, parameter and bin: the bins
%                         are equal-count bins of replicate 1's draws (edges
%                         at its quantiles; the last bin includes its upper
%                         edge; replicate 2 on the same edges, its draws
%                         beyond replicate 1's extremes in the outer bins,
%                         so that no draw is left out): n, edges,
%                         median parameter value, and per quantity (d,
%                         dLevel, the four ratio errors and the double ratio
%                         in percent) the quantiles of the settings and the
%                         mean
%     eta2.csv            per cell and parameter (replicate 1): the share of
%                         the variance of d between the bins, sum_b n_b
%                         (mean_b(d) - mean(d))^2 / sum_s (d_s - mean(d))^2
%     truth_markers.csv   per cell: the truth and its d, dLevel, ratio
%                         errors and double ratio
%   Side effects: writes the files above.
%   Computation: the GP at every retained draw (about 1.7 million points for
%   the thesis cells; about 2 minutes).

    C = cfg.analysis.ratioErrorCurves;
    D = features.definitions(cfg);
    root = cfg.paths.ratioErrorCurves;
    saved = load(cfg.files.gp, 'gp');
    gp = saved.gp;
    records = cell_records(cfg, C);
    names = cellstr(string(cfg.paramNames));
    cohortRows = cell(numel(records), 1);
    binParts = {}; etaParts = {}; truthParts = {};
    for k = 1:numel(records)
        record = records(k);
        [P, status] = recovery.load_posterior_provider(cfg, record);
        if ~status.loaded
            cohortRows{k} = cohort_row(record, status, struct([]), [0 0], 'not loaded: no posterior');
            continue;
        end
        provider = P.certification.provider;
        replicates = cell(1, 2); counts = [0 0]; notes = strings(1, 0);
        for r = 1:2
            [R, s] = recovery.load_posterior_provider(cfg, record, char(string(provider.sampler)), r, ...
                double(provider.stepCount));
            if ~s.loaded
                notes(end+1) = sprintf('replicate %d not available: %s', r, s.reason); %#ok<AGROW>
                continue;
            end
            assert(isequal(double(R.observation(:)), double(P.observation(:))), ...
                'features:ratio_error_curves:Observation', ...
                'The replicates of %s were fitted to different observations.', record.cellID);
            mu = prediction(gp, double(R.drawsPhysical), cfg, C);
            E = features.ratio_errors(mu, double(R.observation), D);
            E.index = draw_index(R, double(provider.stepCount));
            replicates{r} = E;
            counts(r) = size(mu, 1);
            replicates{r}.draws = double(R.drawsPhysical);
            write_draws(root, record, r, E, D);
        end
        cohortRows{k} = cohort_row(record, status, provider, counts, strjoin(notes, '; '));
        if isempty(replicates{1}), continue; end
        truth = double(P.truth(:)).';
        T = features.ratio_errors(prediction(gp, truth, cfg, C), double(P.observation), D);
        truthParts{end+1} = truth_row(record, truth, T, names); %#ok<AGROW>
        [bins, eta] = bin_summaries(record, replicates, names, C);
        binParts{end+1} = bins; %#ok<AGROW>
        etaParts{end+1} = eta; %#ok<AGROW>
    end
    if ~isfolder(root), mkdir(root); end
    cohort = vertcat(cohortRows{:});
    utils.atomic_write_table(fullfile(root, 'cohort.csv'), cohort);
    utils.atomic_write_table(fullfile(root, 'bin_summaries.csv'), vertcat(binParts{:}));
    utils.atomic_write_table(fullfile(root, 'eta2.csv'), vertcat(etaParts{:}));
    utils.atomic_write_table(fullfile(root, 'truth_markers.csv'), vertcat(truthParts{:}));
    result = struct('cells', height(cohort), 'withPosterior', nnz(cohort.Replicates > 0), ...
        'root', root);
end

function records = cell_records(cfg, C)
%CELL_RECORDS The cells: the cases of the settings in the scenario and design, then the supplement.
    cohortCases = selected(C.cases, cfg.inversion.caseIDs);
    supplementCases = selected(C.supplementCases, cfg.inversion.caseIDs);
    records = struct('cellID', {}, 'caseID', {}, 'scenario', {}, 'design', {}, 'role', {});
    for c = cohortCases
        records(end+1) = record_of(c, C.scenario, C.design, 'cohort'); %#ok<AGROW>
    end
    for c = supplementCases
        records(end+1) = record_of(c, C.supplementScenario, C.design, 'supplement'); %#ok<AGROW>
    end
end

function ids = selected(value, cohort)
    if (ischar(value) || isstring(value)) && strcmp(char(value), 'all')
        ids = reshape(double(cohort), 1, []);
    else
        ids = reshape(double(value), 1, []);
    end
end

function r = record_of(caseID, scenario, design, role)
    r = struct('cellID', sprintf('case_%d|%s|%s', caseID, scenario, design), 'caseID', caseID, ...
        'scenario', char(scenario), 'design', char(design), 'role', role);
end

function mu = prediction(gp, X, ~, C)
%PREDICTION The GP mean at the rows of X, mean only, in batches of the settings (0.3).
    mu = double(surrogates.evaluate(gp, X, 'mean', C.gpEvaluationBatchSize));
end

function index = draw_index(R, stepCount)
%DRAW_INDEX Draw, walker, retained iteration and sampler step of every row of the draws.
    [iterations, ~, walkers] = size(R.sampleArray);
    n = size(R.drawsPhysical, 1);
    assert(n == iterations * walkers, 'features:ratio_error_curves:Rows', ...
        'The draws do not hold every retained iteration of every walker.');
    drawIndex = (1:n).';
    index = struct('drawIndex', drawIndex, 'walker', floor((drawIndex - 1) / iterations) + 1, ...
        'retainedIteration', mod(drawIndex - 1, iterations) + 1);
    index.step = stepCount - iterations + index.retainedIteration;
end

function write_draws(root, record, r, E, D)
%WRITE_DRAWS The draw-level values of one replicate as plain numbers (opens without MATLAB).
    folder = fullfile(root, 'draws', record.scenario);
    if ~isfolder(folder), mkdir(folder); end
    S = struct('caseID', record.caseID, 'scenario', record.scenario, 'design', record.design, ...
        'replicateID', r, 'referenceCV', D.c, 'ratios', {{'D2 c2/c1', 'D2 c3/c1', 'D6 c2/c1', 'D6 c3/c1'}}, ...
        'drawIndex', E.index.drawIndex, 'walker', E.index.walker, ...
        'retainedIteration', E.index.retainedIteration, 'step', E.index.step, ...
        'd', E.d, 'dLevel', E.dLevel, 'e1', E.e(:, 1), 'e2', E.e(:, 2), 'e3', E.e(:, 3), 'e4', E.e(:, 4));
    utils.atomic_save_struct(fullfile(folder, sprintf('case_%d_replicate_%d.mat', record.caseID, r)), S, '-v7');
end

function T = cohort_row(record, status, provider, counts, note)
    sampler = ""; level = NaN;
    if ~isempty(provider), sampler = string(provider.sampler); level = double(provider.stepCount); end
    state = "unavailable";
    if status.loaded && status.certified, state = "certified";
    elseif status.loaded, state = "healthy fallback"; end
    T = table(double(record.caseID), string(record.scenario), string(record.design), string(record.role), ...
        state, sampler, level, nnz(counts > 0), counts(1), counts(2), string(note), ...
        'VariableNames', {'CaseID', 'Scenario', 'Design', 'Role', 'Status', 'ProviderSampler', ...
        'ProviderSteps', 'Replicates', 'Replicate1Draws', 'Replicate2Draws', 'Note'});
end

function T = truth_row(record, truth, E, names)
    T = table(double(record.caseID), string(record.scenario), string(record.design), ...
        'VariableNames', {'CaseID', 'Scenario', 'Design'});
    for p = 1:numel(names), T.(['Truth_' names{p}]) = truth(p); end
    T.d = E.d; T.dLevel = E.dLevel;
    labels = ratio_labels();
    for k = 1:4, T.(labels{k}) = E.ratioErrorPercent(k); end
    T.DoubleRatioErrorPercent = E.doubleRatioPercent;
end

function labels = ratio_labels()
    labels = {'RatioErrorPercent_D2_c2c1', 'RatioErrorPercent_D2_c3c1', ...
        'RatioErrorPercent_D6_c2c1', 'RatioErrorPercent_D6_c3c1'};
end

function [B, H] = bin_summaries(record, replicates, names, C)
%BIN_SUMMARIES Per parameter: equal-count bins of replicate 1, both replicates on its edges; eta2 of replicate 1.
    quantities = {'d', 'dLevel', 'RatioErrorPercent_D2_c2c1', 'RatioErrorPercent_D2_c3c1', ...
        'RatioErrorPercent_D6_c2c1', 'RatioErrorPercent_D6_c3c1', 'DoubleRatioErrorPercent'};
    parts = {}; etas = zeros(1, numel(names));
    for p = 1:numel(names)
        edges = quantile(replicates{1}.draws(:, p), (0:C.bins) / C.bins);
        edges(1) = min(replicates{1}.draws(:, p)); edges(end) = max(replicates{1}.draws(:, p));
        assert(all(diff(edges) > 0), 'features:ratio_error_curves:Edges', ...
            'The bin edges of %s, %s are not strictly increasing (many tied draws).', record.cellID, names{p});
        % The outer bins are open, so that every draw of replicate 2 has a bin
        % (replicate 1's draws lie between its extremes, edges(1) and edges(end)).
        assignment = [-Inf, edges(2:end-1), Inf];
        for r = 1:2
            E = replicates{r};
            if isempty(E), continue; end
            values = [E.d, E.dLevel, E.ratioErrorPercent, E.doubleRatioPercent];
            bin = discretize(E.draws(:, p), assignment);
            for b = 1:C.bins
                in = bin == b;
                row = table(double(record.caseID), string(record.scenario), string(record.design), r, ...
                    string(names{p}), b, nnz(in), edges(b), edges(b + 1), median(E.draws(in, p)), ...
                    'VariableNames', {'CaseID', 'Scenario', 'Design', 'Replicate', 'Parameter', 'Bin', ...
                    'N', 'LowerEdge', 'UpperEdge', 'MedianParameter'});
                for q = 1:numel(quantities)
                    x = values(in, q);
                    stats = nan(1, 4);
                    if ~isempty(x), stats = [quantile(x, C.quantiles), mean(x)]; end
                    for k = 1:3
                        row.(sprintf('%s_Q%02d', quantities{q}, round(100 * C.quantiles(k)))) = stats(k);
                    end
                    row.([quantities{q} '_Mean']) = stats(4);
                end
                parts{end+1} = row; %#ok<AGROW>
            end
            if r == 1
                d = E.d; overall = mean(d); between = 0;
                for b = 1:C.bins
                    in = bin == b;
                    if any(in), between = between + nnz(in) * (mean(d(in)) - overall)^2; end
                end
                etas(p) = between / sum((d - overall).^2);
            end
        end
    end
    B = vertcat(parts{:});
    H = table(repmat(double(record.caseID), numel(names), 1), repmat(string(record.scenario), numel(names), 1), ...
        repmat(string(record.design), numel(names), 1), string(names(:)), etas(:), ...
        'VariableNames', {'CaseID', 'Scenario', 'Design', 'Parameter', 'Eta2'});
end
