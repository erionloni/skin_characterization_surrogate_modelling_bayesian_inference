function manifest = saved_gp_mean_inversion_figures(cfg, ~)
%SAVED_GP_MEAN_INVERSION_FIGURES The figures and tables of the GP-mean inversion, from its saved results.
%   MANIFEST = plotting.saved_gp_mean_inversion_figures(CFG, OPTIONS) draws,
%   from the saved results of the step gp_mean_inversion
%   (study.source_folder 'gp_mean_inversion': cell_status.csv,
%   posterior_parameter_cells.csv, comparison.csv, the draws) and the
%   shipped draws of the canonical cells (recovery.load_posterior_provider),
%   in the analysis folder:
%     tables/cell_status            the status of every GP-mean cell
%     tables/posterior_summary      per case and parameter: posterior mean and
%                                   SD, the SD over the prior SD, the 95 %
%                                   interval, the truth, the error of the
%                                   posterior mean (signed, and absolute over
%                                   the prior width), the truth inside
%     tables/comparison             per case and parameter the same SD and
%                                   errors in the four scenarios side by side
%                                   (the canonical cells as shipped)
%     tables/comparison_summary     per scenario and parameter over the cells
%                                   with a posterior: the medians of the
%                                   normalized SD and error and how often the
%                                   95 % interval holds the truth; over the
%                                   certified cells alone in _certified_only
%     figures/cohort_sd_and_error   per parameter the normalized posterior SD
%                                   (top) and the absolute error of the
%                                   posterior mean over the prior width
%                                   (bottom) of every case in the four
%                                   scenarios (log scale; filled certified,
%                                   open healthy fallback; the median)
%   and in the case folder of the showcase case of the settings (A.13),
%   cases/case_<id>/gp_mean_inversion/figures/four_scenario_marginals: the
%   histogram densities of the four scenarios' all_six providers on the
%   prior range, and the truth;
%   and, from the best fit (data/best_fit, study.write_gp_mean_best_fit):
%     tables/best_fit_vs_truth      per case and parameter theta* against the
%                                   truth, its error, whether it lies on a prior
%                                   bound, the objective at theta* and at the
%                                   truth, the minima and starts at the best
%     tables/best_fit_comparison    per case and parameter the error of theta*
%                                   next to those of the posterior means of the
%                                   three canonical scenarios (as shipped)
%     figures/best_fit_error_comparison  per parameter the absolute error over
%                                   the prior width of theta* and of the three
%                                   scenarios' posterior means (log scale)
%     figures/best_fit_against_truth  per parameter theta* against the truth
%     cases/case_<id>/gp_mean_inversion/figures/best_fit_pressures  the
%                                   showcase case: the six COMSOL pressures, the
%                                   GP mean at theta* and at the truth, and the
%                                   residuals
%   and per GP-mean cell with a posterior, in its case folder
%   (cases/case_<id>/gp_mean_inversion/): gp_mean_det_all_six_marginals,
%   the marginals with the mean, median, mode, central intervals and the
%   truth, and their statistics table (as the inversion's per-cell
%   marginals). OPTIONS is unused.
%   Side effects: writes the figures and tables and closes the figures.
%   Computation: seconds.

    manifest = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', 'SourceArtifacts'});
    if ~study.is_publication(cfg), return; end
    folder = study.source_folder(cfg, 'gp_mean_inversion');
    paths = struct('status', fullfile(folder, 'cell_status.csv'), ...
        'cells', fullfile(folder, 'posterior_parameter_cells.csv'), ...
        'comparison', fullfile(folder, 'comparison.csv'));
    if ~isfile(paths.status), return; end
    status = utils.read_csv_table(paths.status, {'Scenario', 'Design', 'Status', 'ProviderSampler', ...
        'Reason', 'HealthNote', 'LevelsRun'});
    cells = utils.read_csv_table(paths.cells, {'Scenario', 'ScenarioLabel', 'Design', 'DesignLabel', ...
        'DesignRole', 'ComparisonClass', 'CellID', 'Parameter', 'CertifiedSampler', ...
        'CertificationMechanism', 'ExecutionStatus', 'FailureReason'});
    comparison = utils.read_csv_table(paths.comparison, {'Parameter', 'Scenario', 'Status', 'Source'});
    scenarios = [string(cfg.gpMeanInversion.comparisonScenarios), "gp_mean_det"];
    parameters = string(cfg.paramNames);
    own = struct('Scenario', 'gp_mean_det', 'Design', 'all_six');

    study.export_table(cfg, 'gp_mean_inversion', 'cell_status', status, {paths.status}, ...
        'Status of the GP-mean cells', own);
    study.export_table(cfg, 'gp_mean_inversion', 'posterior_summary', summary_table(cells, status), ...
        {paths.cells, paths.status}, 'Posterior summary per case and parameter (GP mean, COMSOL data)', own);
    study.export_table(cfg, 'gp_mean_inversion', 'comparison', wide(comparison, scenarios), ...
        {paths.comparison}, 'Posterior SD and error per case and parameter in the four scenarios', 'all');
    study.export_table(cfg, 'gp_mean_inversion', 'comparison_summary', ...
        cohort_summary(comparison, scenarios, parameters), {paths.comparison}, ...
        'Posterior SD, error and truth inclusion per scenario and parameter over the cases', 'all');
    parts = {cohort_figure(cfg, comparison, scenarios, parameters, {paths.comparison})};
    showcase = double(cfg.gpMeanInversion.showcaseCase);
    if ismember(showcase, double(status.CaseID))
        parts{end+1} = four_scenario_figure(cfg, showcase, scenarios, parameters);
    end
    if isfile(fullfile(folder, 'best_fit', 'best_fit.csv'))
        parts = [parts, best_fit_outputs(cfg, folder, comparison, parameters, showcase)];
    end
    for k = 1:height(status)
        if ~ismember(status.Status(k), ["certified", "healthy fallback"]), continue; end
        record = struct('caseID', double(status.CaseID(k)), 'scenario', 'gp_mean_det', ...
            'design', char(status.Design(k)));
        [A, loaded] = recovery.load_posterior_provider(cfg, record);
        if ~loaded.loaded, continue; end
        parts{end+1} = marginal_figure(cfg, A, record, loaded); %#ok<AGROW>
    end
    parts = parts(~cellfun(@isempty, parts));
    if ~isempty(parts), manifest = vertcat(parts{:}); end
end

function T = summary_table(cells, status)
%SUMMARY_TABLE Per case and parameter the posterior summary of the GP-mean cell, with the cell's status.
    [~, where] = ismember(double(cells.CaseID), double(status.CaseID));
    T = table(double(cells.CaseID), cells.Parameter, status.Status(where), ...
        double(cells.TruthPhysical), double(cells.PosteriorMeanPhysical), ...
        double(cells.PosteriorSDPhysical), double(cells.NormalizedPosteriorSD), ...
        double(cells.CI025Physical), double(cells.CI975Physical), double(cells.TruthCovered95), ...
        double(cells.SignedErrorFromPosteriorMeanPhysical), ...
        double(cells.PosteriorMeanNormalizedRecoveryError), ...
        'VariableNames', {'CaseID', 'Parameter', 'Status', 'TruthPhysical', 'PosteriorMeanPhysical', ...
        'PosteriorSDPhysical', 'NormalizedPosteriorSD', 'CI025Physical', 'CI975Physical', ...
        'TruthCovered95', 'ErrorOfPosteriorMeanPhysical', 'NormalizedAbsoluteErrorOfPosteriorMean'});
end

function W = wide(C, scenarios)
%WIDE Per case and parameter, the four scenarios side by side.
    keys = unique(C(:, {'CaseID', 'Parameter'}), 'stable');
    W = keys;
    W.CaseID = double(W.CaseID);
    truth = nan(height(keys), 1);
    columns = {'Status', 'PosteriorSDPhysical', 'NormalizedPosteriorSD', ...
        'SignedErrorFromPosteriorMeanPhysical', 'PosteriorMeanNormalizedRecoveryError', 'TruthCovered95'};
    names = {'Status', 'PosteriorSDPhysical', 'NormalizedPosteriorSD', 'ErrorOfPosteriorMeanPhysical', ...
        'NormalizedAbsoluteErrorOfPosteriorMean', 'TruthCovered95'};
    for s = reshape(scenarios, 1, [])
        for j = 1:numel(columns)
            if strcmp(columns{j}, 'Status')
                value = repmat("", height(keys), 1);
            else
                value = nan(height(keys), 1);
            end
            for i = 1:height(keys)
                row = C(double(C.CaseID) == keys.CaseID(i) & C.Parameter == keys.Parameter(i) & ...
                    C.Scenario == s, :);
                if height(row) ~= 1, continue; end
                value(i) = row.(columns{j});
                if isnan(truth(i)), truth(i) = double(row.TruthPhysical); end
            end
            W.(sprintf('%s_%s', s, names{j})) = value;
        end
    end
    W = addvars(W, truth, 'After', 'Parameter', 'NewVariableNames', 'TruthPhysical');
end

function S = cohort_summary(C, scenarios, parameters)
%COHORT_SUMMARY Per scenario and parameter, over the cells with a posterior; certified cells alone in _certified_only.
    rows = {};
    for s = reshape(scenarios, 1, [])
        for p = reshape(parameters, 1, [])
            R = C(C.Scenario == s & C.Parameter == p, :);
            available = ismember(R.Status, ["certified", "healthy fallback"]) & ...
                isfinite(double(R.NormalizedPosteriorSD));
            certified = available & logical(R.InCertifiedOnlyValues);
            rows{end+1} = [table(s, p, height(R), 'VariableNames', {'Scenario', 'Parameter', ...
                'PlannedCells'}), stats(R(available, :), ''), stats(R(certified, :), '_certified_only')]; %#ok<AGROW>
        end
    end
    S = vertcat(rows{:});
end

function T = stats(R, suffix)
    sd = double(R.NormalizedPosteriorSD);
    err = double(R.PosteriorMeanNormalizedRecoveryError);
    inside = double(R.TruthCovered95);
    n = height(R);
    T = table(n, median_or_nan(sd), median_or_nan(err), sum(inside == 1), share(sum(inside == 1), n), ...
        'VariableNames', strcat({'Cells', 'MedianNormalizedPosteriorSD', ...
        'MedianNormalizedAbsoluteErrorOfPosteriorMean', 'TruthCovered95Count', 'TruthCovered95Share'}, suffix));
end

function v = median_or_nan(x)
    x = x(isfinite(x));
    v = NaN;
    if ~isempty(x), v = median(x); end
end

function v = share(k, n)
    v = NaN;
    if n > 0, v = k / n; end
end

function row = cohort_figure(cfg, C, scenarios, parameters, sources)
%COHORT_FIGURE Per parameter the normalized SD (top) and error (bottom) of every case in the four scenarios.
    colors = scenario_colors();
    fig = figure('Position', [40 40 1500 760]);
    layout = tiledlayout(fig, 2, numel(parameters), 'Padding', 'compact', 'TileSpacing', 'compact');
    quantities = {'NormalizedPosteriorSD', 'posterior SD / prior SD'; ...
        'PosteriorMeanNormalizedRecoveryError', '|posterior mean - truth| / prior width'};
    cases = unique(double(C.CaseID), 'stable');
    offsets = linspace(-0.28, 0.28, numel(cases));
    for q = 1:2
        for p = 1:numel(parameters)
            ax = nexttile(layout); hold(ax, 'on');
            for s = 1:numel(scenarios)
                R = C(C.Scenario == scenarios(s) & C.Parameter == parameters(p), :);
                values = double(R.(quantities{q, 1}));
                [~, at] = ismember(double(R.CaseID), cases);
                x = s + offsets(at(:)).';
                good = isfinite(values) & values > 0;
                certified = good & R.Status == "certified";
                fallback = good & R.Status == "healthy fallback";
                plot(ax, x(certified), values(certified), 'o', 'MarkerSize', 5, ...
                    'MarkerFaceColor', colors(s, :), 'MarkerEdgeColor', colors(s, :));
                plot(ax, x(fallback), values(fallback), 'o', 'MarkerSize', 5, ...
                    'MarkerFaceColor', 'w', 'MarkerEdgeColor', colors(s, :), 'LineWidth', 1);
                if any(good)
                    plot(ax, s + [-0.35 0.35], median(values(good)) * [1 1], 'k-', 'LineWidth', 1.6);
                end
            end
            if q == 1 && p == 1
                % Legend proxies: plain markers and a line without data.
                proxies = [plot(ax, NaN, NaN, 'o', 'MarkerSize', 5, 'MarkerFaceColor', [0.4 0.4 0.4], ...
                    'MarkerEdgeColor', [0.4 0.4 0.4]), plot(ax, NaN, NaN, 'o', 'MarkerSize', 5, ...
                    'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.4 0.4 0.4]), ...
                    plot(ax, NaN, NaN, 'k-', 'LineWidth', 1.6)];
                legend(ax, proxies, {'certified', 'healthy fallback', 'median over the cases'}, ...
                    'Location', 'best');
            end
            set(ax, 'YScale', 'log', 'XLim', [0.4 numel(scenarios) + 0.6], 'XTick', 1:numel(scenarios), ...
                'XTickLabel', arrayfun(@(t) plotting.display_name('scenario', t), scenarios, ...
                'UniformOutput', false), 'XTickLabelRotation', 25);
            grid(ax, 'on');
            if q == 1
                title(ax, plotting.display_name('parameter', parameters(p), true), 'Interpreter', 'tex');
            end
            if p == 1, ylabel(ax, quantities{q, 2}); end
        end
    end
    title(layout, sprintf(['All six outputs, %d cases: normalized posterior SD and error of the ' ...
        'posterior mean in four scenarios'], numel(cases)));
    row = plotting.export_saved_figure(fig, cfg, 'gp_mean_inversion', 'cohort_sd_and_error', sources, ...
        'aggregate', 'all');
end

function row = four_scenario_figure(cfg, caseID, scenarios, parameters)
%FOUR_SCENARIO_FIGURE The all_six marginals of one case in the four scenarios (histograms on the prior range).
    colors = scenario_colors();
    providers = cell(1, numel(scenarios));
    fallback = false(1, numel(scenarios));
    sources = {};
    for s = 1:numel(scenarios)
        record = struct('caseID', caseID, 'scenario', char(scenarios(s)), 'design', 'all_six');
        [A, status] = recovery.load_posterior_provider(cfg, record);
        if status.loaded
            providers{s} = A;
            fallback(s) = ~logical(status.certified);
            sources{end+1} = A.paths.posteriorPath; %#ok<AGROW>
        end
    end
    row = [];
    if all(cellfun(@isempty, providers)), return; end
    fig = figure('Position', [60 60 1150 760]);
    layout = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    for p = 1:numel(parameters)
        nexttile(layout); hold on;
        truth = NaN;
        for s = 1:numel(scenarios)
            A = providers{s};
            if isempty(A), continue; end
            edges = linspace(A.bounds(p, 1), A.bounds(p, 2), 51);
            density = histcounts(A.drawsPhysical(:, p), edges, 'Normalization', 'pdf');
            stairs([edges(1:end-1) edges(end)], [density density(end)], 'Color', colors(s, :), ...
                'LineWidth', 1.5, 'DisplayName', plotting.display_name('scenario', scenarios(s)));
            if ~isfinite(truth), truth = A.truth(p); end
        end
        if isfinite(truth)
            xline(truth, 'k--', 'LineWidth', 1, 'DisplayName', 'truth');
        end
        xlabel(plotting.display_name('parameter', parameters(p), true), 'Interpreter', 'tex');
        ylabel('posterior density');
        if p == 1, legend('Location', 'best'); end
    end
    title(layout, {sprintf('Case %d, all six outputs: posterior marginals in four scenarios', caseID), ...
        sprintf('(histograms of all retained draws of the selected provider); healthy fallback: %s; unavailable: %s', ...
        listed(scenarios(fallback)), listed(scenarios(cellfun(@isempty, providers))))});
    cells = struct('CaseID', caseID, 'Scenario', {cellstr(scenarios)}, 'Design', 'all_six');
    row = plotting.export_saved_figure(fig, cfg, 'case/gp_mean_inversion', 'four_scenario_marginals', ...
        sources, 'publication', cells);
end

function row = marginal_figure(cfg, A, record, status)
%MARGINAL_FIGURE The marginals of one GP-mean cell with their statistics (as the inversion's per-cell marginals).
    draws = double(A.drawsPhysical); truth = double(A.truth(:));
    names = cellstr(string(A.parameterNames));
    label = plotting.provider_status(status);
    cells = struct('CaseID', record.caseID, 'Scenario', record.scenario, 'Design', record.design);
    file = sprintf('%s_%s', record.scenario, record.design);
    sources = {A.paths.posteriorPath};
    fig = figure('Position', [50 50 1120 720]);
    tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    summaries = cell(numel(names), 1);
    for p = 1:numel(names)
        nexttile;
        [estimate, handles] = plotting.render_posterior_marginal(draws(:, p), cfg.paramBounds(p, :), ...
            'DisplayName', 'posterior', 'ShowCentralIntervals', true);
        truthHandle = xline(truth(p), 'r-', 'LineWidth', 1.8, 'DisplayName', 'synthetic truth');
        xlabel(names{p}, 'Interpreter', 'none'); ylabel('posterior density');
        if p == 1
            legend([handles.density handles.interval95 handles.interval50 handles.mean handles.median ...
                handles.mode truthHandle], {'posterior density', '95% equal-tailed interval', ...
                '50% equal-tailed interval', 'posterior mean', 'posterior median', 'marginal mode', ...
                'synthetic truth'}, 'Location', 'best');
        end
        summaries{p} = plotting.posterior_marginal_summary_row(estimate, [label ' posterior'], ...
            names{p}, truth(p));
    end
    sgtitle(sprintf('case %d, GP mean, COMSOL data, all six outputs (%s)', record.caseID, label));
    plotting.write_posterior_marginal_summary(cfg, 'case/gp_mean_inversion', [file '_marginals'], ...
        vertcat(summaries{:}), sources, file, cells);
    row = plotting.export_saved_figure(fig, cfg, 'case/gp_mean_inversion', [file '_marginals'], sources, ...
        'publication', cells);
end

function parts = best_fit_outputs(cfg, folder, comparison, parameters, showcase)
%BEST_FIT_OUTPUTS The tables and figures of the best fit (data/best_fit), with the canonical posterior means.
    files = struct('fit', fullfile(folder, 'best_fit', 'best_fit.csv'), ...
        'residuals', fullfile(folder, 'best_fit', 'residuals.csv'), ...
        'minima', fullfile(folder, 'best_fit', 'local_minima.csv'), ...
        'comparison', fullfile(folder, 'comparison.csv'));
    F = utils.read_csv_table(files.fit, {'Parameter'});
    canonical = string(cfg.gpMeanInversion.comparisonScenarios);
    posteriors = struct('Scenario', {cellstr(canonical)}, 'Design', 'all_six');
    study.export_table(cfg, 'gp_mean_inversion', 'best_fit_vs_truth', truth_table(F), ...
        {files.fit, files.minima}, 'Best fit of the GP mean to the COMSOL pressures against the truth', []);
    study.export_table(cfg, 'gp_mean_inversion', 'best_fit_comparison', ...
        comparison_table(F, comparison, canonical), {files.fit, files.comparison}, ...
        'Error of the best fit and of the posterior means of the three canonical scenarios', posteriors);
    parts = {error_figure(cfg, F, comparison, canonical, parameters, {files.fit, files.comparison}, ...
        posteriors), truth_figure(cfg, F, parameters, {files.fit})};
    R = utils.read_csv_table(files.residuals, {'Output'});
    if ismember(showcase, double(R.CaseID))
        parts{end+1} = pressure_figure(cfg, R(double(R.CaseID) == showcase, :), ...
            F(double(F.CaseID) == showcase, :), showcase, {files.residuals, files.fit});
    end
end

function T = truth_table(F)
%TRUTH_TABLE Per case and parameter theta* against the truth, with the search's record of the case.
    bound = repmat("", height(F), 1);
    bound(logical(F.OnLowerBound)) = "lower";
    bound(logical(F.OnUpperBound)) = "upper";
    T = table(double(F.CaseID), F.Parameter, double(F.TruthPhysical), double(F.BestFitPhysical), ...
        double(F.ErrorPhysical), double(F.NormalizedAbsoluteError), bound, double(F.Objective), ...
        double(F.ObjectiveAtTruth), double(F.LocalMinima), double(F.StartsAtBest), double(F.StartsRun), ...
        'VariableNames', {'CaseID', 'Parameter', 'TruthPhysical', 'BestFitPhysical', 'ErrorPhysical', ...
        'NormalizedAbsoluteError', 'OnPriorBound', 'Objective', 'ObjectiveAtTruth', 'LocalMinima', ...
        'StartsAtBest', 'StartsRun'});
end

function T = comparison_table(F, C, canonical)
%COMPARISON_TABLE Per case and parameter the best fit's error next to the canonical posterior means' errors.
    T = table(double(F.CaseID), F.Parameter, double(F.TruthPhysical), double(F.BestFitPhysical), ...
        double(F.ErrorPhysical), double(F.NormalizedAbsoluteError), 'VariableNames', {'CaseID', ...
        'Parameter', 'TruthPhysical', 'BestFitPhysical', 'BestFitErrorPhysical', ...
        'BestFitNormalizedAbsoluteError'});
    columns = {'Status', 'PosteriorMeanPhysical', 'SignedErrorFromPosteriorMeanPhysical', ...
        'PosteriorMeanNormalizedRecoveryError'};
    names = {'Status', 'PosteriorMeanPhysical', 'ErrorOfPosteriorMeanPhysical', ...
        'NormalizedAbsoluteErrorOfPosteriorMean'};
    for s = reshape(canonical, 1, [])
        for j = 1:numel(columns)
            if j == 1, value = repmat("", height(T), 1); else, value = nan(height(T), 1); end
            for i = 1:height(T)
                row = C(double(C.CaseID) == T.CaseID(i) & C.Parameter == T.Parameter(i) & C.Scenario == s, :);
                if height(row) == 1, value(i) = row.(columns{j}); end
            end
            T.(sprintf('%s_%s', s, names{j})) = value;
        end
    end
end

function row = error_figure(cfg, F, C, canonical, parameters, sources, posteriors)
%ERROR_FIGURE Per parameter the error over the prior width of the best fit and of the canonical posterior means.
    colors = scenario_colors();
    best = colors(4, :);
    fig = figure('Position', [40 40 1500 520]);
    layout = tiledlayout(fig, 1, numel(parameters), 'Padding', 'compact', 'TileSpacing', 'compact');
    cases = unique(double(F.CaseID), 'stable');
    offsets = linspace(-0.28, 0.28, numel(cases));
    labels = [{'Best fit'}, ...
        arrayfun(@(t) plotting.display_name('scenario', t), canonical, 'UniformOutput', false)];
    for p = 1:numel(parameters)
        ax = nexttile(layout); hold(ax, 'on');
        B = F(F.Parameter == parameters(p), :);
        [~, at] = ismember(double(B.CaseID), cases);
        values = double(B.NormalizedAbsoluteError);
        good = isfinite(values) & values > 0;
        x = 1 + offsets(at(:)).';
        plot(ax, x(good), values(good), 'd', 'MarkerSize', 6, 'MarkerFaceColor', best, 'MarkerEdgeColor', best);
        if any(good), plot(ax, [0.65 1.35], median(values(good)) * [1 1], 'k-', 'LineWidth', 1.6); end
        for s = 1:numel(canonical)
            R = C(C.Scenario == canonical(s) & C.Parameter == parameters(p), :);
            values = double(R.PosteriorMeanNormalizedRecoveryError);
            [~, at] = ismember(double(R.CaseID), cases);
            x = s + 1 + offsets(at(:)).';
            good = isfinite(values) & values > 0;
            certified = good & R.Status == "certified";
            fallback = good & R.Status == "healthy fallback";
            plot(ax, x(certified), values(certified), 'o', 'MarkerSize', 5, ...
                'MarkerFaceColor', colors(s, :), 'MarkerEdgeColor', colors(s, :));
            plot(ax, x(fallback), values(fallback), 'o', 'MarkerSize', 5, ...
                'MarkerFaceColor', 'w', 'MarkerEdgeColor', colors(s, :), 'LineWidth', 1);
            if any(good), plot(ax, s + 1 + [-0.35 0.35], median(values(good)) * [1 1], 'k-', 'LineWidth', 1.6); end
        end
        if p == 1
            % Legend proxies: plain markers and a line without data.
            gray = [0.4 0.4 0.4];
            proxies = [plot(ax, NaN, NaN, 'd', 'MarkerSize', 6, 'MarkerFaceColor', best, ...
                'MarkerEdgeColor', best), plot(ax, NaN, NaN, 'o', 'MarkerSize', 5, 'MarkerFaceColor', gray, ...
                'MarkerEdgeColor', gray), plot(ax, NaN, NaN, 'o', 'MarkerSize', 5, 'MarkerFaceColor', 'w', ...
                'MarkerEdgeColor', gray), plot(ax, NaN, NaN, 'k-', 'LineWidth', 1.6)];
            key = legend(ax, proxies, {'best fit of the GP mean to the COMSOL pressures', ...
                'posterior mean, certified', 'posterior mean, healthy fallback', 'median over the cases'}, ...
                'NumColumns', 4);
            key.Layout.Tile = 'south';
            ylabel(ax, '|estimate - truth| / prior width');
        end
        set(ax, 'YScale', 'log', 'XLim', [0.4 numel(canonical) + 1.6], 'XTick', 1:numel(canonical) + 1, ...
            'XTickLabel', labels, 'XTickLabelRotation', 25);
        grid(ax, 'on');
        title(ax, plotting.display_name('parameter', parameters(p), true), 'Interpreter', 'tex');
    end
    title(layout, sprintf(['All six outputs, %d cases: error of the best fit of the GP mean to the COMSOL ' ...
        'pressures and of the posterior means in the three scenarios'], numel(cases)));
    row = plotting.export_saved_figure(fig, cfg, 'gp_mean_inversion', 'best_fit_error_comparison', sources, ...
        'aggregate', posteriors);
end

function row = truth_figure(cfg, F, parameters, sources)
%TRUTH_FIGURE Per parameter theta* against the truth of every case, on the prior range.
    color = scenario_colors();
    color = color(4, :);
    fig = figure('Position', [60 60 1150 760]);
    layout = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    for p = 1:numel(parameters)
        ax = nexttile(layout); hold(ax, 'on');
        B = F(F.Parameter == parameters(p), :);
        range = [double(B.LowerBound(1)) double(B.UpperBound(1))];
        onBound = logical(B.OnLowerBound) | logical(B.OnUpperBound);
        plot(ax, range, range, 'k--', 'LineWidth', 1, 'DisplayName', 'best fit = truth');
        plot(ax, double(B.TruthPhysical(~onBound)), double(B.BestFitPhysical(~onBound)), 'd', ...
            'MarkerSize', 6, 'MarkerFaceColor', color, 'MarkerEdgeColor', color, 'DisplayName', 'best fit');
        plot(ax, double(B.TruthPhysical(onBound)), double(B.BestFitPhysical(onBound)), 's', ...
            'MarkerSize', 7, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', color, 'LineWidth', 1.2, ...
            'DisplayName', 'best fit on a prior bound');
        set(ax, 'XLim', range, 'YLim', range);
        axis(ax, 'square'); grid(ax, 'on');
        name = plotting.display_name('parameter', parameters(p), true);
        xlabel(ax, ['truth ' name], 'Interpreter', 'tex');
        ylabel(ax, ['best fit ' name], 'Interpreter', 'tex');
        if p == 1, legend(ax, 'Location', 'best'); end
    end
    title(layout, sprintf(['All six outputs, %d cases: best fit of the GP mean to the COMSOL pressures ' ...
        'against the truth (axes: the prior range)'], numel(unique(double(F.CaseID)))));
    row = plotting.export_saved_figure(fig, cfg, 'gp_mean_inversion', 'best_fit_against_truth', sources, ...
        'aggregate', []);
end

function row = pressure_figure(cfg, R, F, caseID, sources)
%PRESSURE_FIGURE One case: the six COMSOL pressures, the GP mean at theta* and at the truth, and the residuals.
    color = scenario_colors();
    color = color(4, :);
    gray = [0.45 0.45 0.45];
    n = height(R);
    labels = plotting.display_name('output', R.Output);
    fig = figure('Position', [60 60 1000 700]);
    layout = tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
    ax = nexttile(layout); hold(ax, 'on');
    plot(ax, 1:n, double(R.ObservedPressure), 'kx', 'MarkerSize', 10, 'LineWidth', 1.5, ...
        'DisplayName', 'COMSOL pressure (observation)');
    plot(ax, 1:n, double(R.GPMeanAtBestFit), 'd', 'MarkerSize', 7, 'MarkerFaceColor', color, ...
        'MarkerEdgeColor', color, 'DisplayName', 'GP mean at the best fit');
    plot(ax, 1:n, double(R.GPMeanAtTruth), 'o', 'MarkerSize', 7, 'MarkerEdgeColor', gray, ...
        'LineWidth', 1.2, 'DisplayName', 'GP mean at the truth');
    set(ax, 'XLim', [0.5 n + 0.5], 'XTick', 1:n, 'XTickLabel', labels, 'TickLabelInterpreter', 'tex');
    ylabel(ax, 'pressure [mbar]'); grid(ax, 'on'); legend(ax, 'Location', 'best');
    ax = nexttile(layout); hold(ax, 'on');
    yline(ax, 0, 'k-', 'HandleVisibility', 'off');
    plot(ax, 1:n, double(R.ResidualAtBestFit), 'd', 'MarkerSize', 7, 'MarkerFaceColor', color, ...
        'MarkerEdgeColor', color, 'DisplayName', 'at the best fit');
    plot(ax, 1:n, double(R.ResidualAtTruth), 'o', 'MarkerSize', 7, 'MarkerEdgeColor', gray, ...
        'LineWidth', 1.2, 'DisplayName', 'at the truth');
    set(ax, 'XLim', [0.5 n + 0.5], 'XTick', 1:n, 'XTickLabel', labels, 'TickLabelInterpreter', 'tex');
    ylabel(ax, 'COMSOL pressure - GP mean [mbar]'); grid(ax, 'on'); legend(ax, 'Location', 'best');
    title(layout, {sprintf('Case %d: the six COMSOL pressures and the GP mean at the best fit and at the truth', ...
        caseID), sprintf('(sum of squared residuals: %.3g mbar^2 at the best fit, %.3g mbar^2 at the truth)', ...
        double(F.Objective(1)), double(F.ObjectiveAtTruth(1)))}, 'Interpreter', 'none');
    % An output of one case (its case folder) that is not posterior-based.
    row = plotting.export_saved_figure(fig, cfg, 'case/gp_mean_inversion', 'best_fit_pressures', sources, ...
        'publication', struct('CaseID', caseID, 'PosteriorBased', false));
end

function colors = scenario_colors()
%SCENARIO_COLORS The three canonical scenarios' colors of the inversion's figures, and the GP-mean scenario's.
    colors = [0.14 0.48 0.63; 0.85 0.51 0.16; 0.40 0.56 0.30; 0.55 0.33 0.64];
end

function text = listed(scenarios)
%LISTED Scenario names for a title: 'none', or the names, comma separated.
    text = 'none';
    if ~isempty(scenarios)
        text = char(strjoin(strrep(scenarios, '_', ' '), ', '));
    end
end
