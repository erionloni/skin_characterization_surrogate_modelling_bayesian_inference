function manifest = saved_combination_figures(cfg, ~)
%SAVED_COMBINATION_FIGURES The parameter combinations the posteriors determine, and the compensation behind them.
%   MANIFEST = plotting.saved_combination_figures(CFG, OPTIONS) draws, from
%   the saved results of recovery.parameter_combinations
%   (study.source_folder 'combinations'), into the recovery analysis (file
%   names starting with combinations_):
%     tables   _cells (per cell and replicate: the best-determined
%              combinations with their SD ratios, the label, the log form,
%              the compensation and the angles), _marginals (per cell,
%              replicate and best combination: its marginal against its
%              prior, and the truth), _summary (per scenario, replicate and
%              best combination: the consensus, the spread of the
%              directions, medians and counts; the certified cells alone in
%              the columns ending in _certified_only)
%     figures  _weak_pair_sd_ratios: per case and scenario the SD ratio of
%              the best combination of the weak pair next to the SD ratios
%              of its two parameters (both replicates; the log form where it
%              applies; half the smaller SD ratio, below which a combination
%              is labelled identified); _weak_pair_directions: the direction
%              of the best weak-pair combination per case, as its angle in
%              the plane of the pair, with the consensus; _compensation: per
%              case the least-informative direction of the pair that the GP
%              predicts at the truth against the worst-determined posterior
%              direction, the angle between them, and the angle between the
%              sensitivity vectors of the pair
%   and per cell, in its case folder (cases/case_<id>/combinations/figures/):
%     <scenario>_<design>_combination_marginals  the marginals of the best
%              four-parameter combination, of the best weak-pair combination
%              and of its log form, replicate 1 with its mean, median, mode
%              and central intervals as in the inversion's marginals,
%              replicate 2 dashed, each with its prior and the truth
%     <scenario>_<design>_weak_pair_scatter      every draw of the weak
%              pair, per replicate, with the best (solid) and the worst
%              (dashed) direction through the mean over +/- 2 SD, and the truth
%   OPTIONS is unused.
%   Side effects: writes the tables and figures and closes the figures.
%   Computation: seconds per cell (the scatter reads the cell's draws).

    manifest = empty_manifest();
    if ~study.is_publication(cfg), return; end
    folder = study.source_folder(cfg, 'combinations');
    paths = struct('cohort', fullfile(folder, 'cohort.csv'), 'cells', fullfile(folder, 'cells.csv'), ...
        'marginals', fullfile(folder, 'marginals.csv'), 'densities', fullfile(folder, 'densities.csv'), ...
        'consensus', fullfile(folder, 'consensus.csv'));
    if ~isfile(paths.cells), return; end
    cohort = utils.read_csv_table(paths.cohort, {'Scenario', 'Design', 'Status', 'ProviderSampler', 'Note'});
    cells = utils.read_csv_table(paths.cells, {'Scenario', 'Design', 'Status', 'LogFormReason'});
    marginals = utils.read_csv_table(paths.marginals, {'Scenario', 'Design', 'Status', 'Combination', 'Formula'});
    densities = utils.read_csv_table(paths.densities, {'Scenario', 'Design', 'Status', 'Combination', 'Curve'});
    consensus = utils.read_csv_table(paths.consensus, {'Scenario', 'Combination'});
    names = cellstr(string(cfg.paramNames));
    pair = names(cfg.analysis.weakPairIndices);
    order = case_order(cfg, cells);
    scenarios = reshape(unique(cells.Scenario, 'stable'), 1, []);
    scope = struct('CaseID', order, 'Scenario', {cellstr(scenarios)}, 'Design', {cellstr(unique(cells.Design))});
    study.export_table(cfg, 'combinations', 'cells', cells, {paths.cells, paths.cohort}, ...
        ['Per cell and replicate: the best-determined combinations with their SD ratios, the label, ' ...
         'the log form, the compensation and the angles'], scope);
    study.export_table(cfg, 'combinations', 'marginals', marginals, {paths.marginals}, ...
        'Per cell, replicate and best combination: its marginal against its prior, and the truth', scope);
    study.export_table(cfg, 'combinations', 'summary', consensus, {paths.consensus}, ...
        ['Per scenario, replicate and best combination: the consensus, the spread of the directions, ' ...
         'medians and counts (the certified cells alone in the columns ending in _certified_only)'], scope);
    factor = cfg.analysis.combinations.labelFactor;
    parts = {sd_ratio_figure(cfg, cells, pair, order, scenarios, factor, {paths.cells}, scope), ...
        direction_figure(cfg, cells, consensus, pair, order, scenarios, {paths.cells, paths.consensus}, scope), ...
        compensation_figure(cfg, cells, pair, order, scenarios, {paths.cells}, scope)};
    for k = 1:height(cohort)
        if cohort.Replicates(k) == 0, continue; end
        record = struct('caseID', cohort.CaseID(k), 'scenario', char(cohort.Scenario(k)), ...
            'design', char(cohort.Design(k)));
        [A, status] = recovery.load_posterior_provider(cfg, record);
        if ~status.loaded, continue; end
        mine = @(T) T(T.CaseID == record.caseID & T.Scenario == record.scenario & T.Design == record.design, :);
        C = mine(cells);
        if isempty(C), continue; end
        sources = {paths.cells, paths.marginals, paths.densities, A.paths.posteriorPath};
        cellScope = struct('CaseID', record.caseID, 'Scenario', record.scenario, 'Design', record.design);
        stem = sprintf('%s_%s', record.scenario, record.design);
        label = cell_label(cfg, record);
        parts{end+1} = marginal_figure(cfg, C, mine(marginals), mine(densities), names, pair, label, ...
            [stem '_combination_marginals'], sources, cellScope); %#ok<AGROW>
        replicates = cell(1, 2);
        for r = reshape(C.Replicate, 1, [])
            [R, s] = recovery.load_posterior_provider(cfg, record, char(cohort.ProviderSampler(k)), r, ...
                cohort.ProviderSteps(k));
            if s.loaded, replicates{r} = double(R.drawsPhysical); end
        end
        parts{end+1} = scatter_figure(cfg, C, replicates, double(A.truth(:)).', pair, label, ...
            [stem '_weak_pair_scatter'], sources, cellScope); %#ok<AGROW>
    end
    manifest = vertcat(parts{:});
end

function ids = case_order(cfg, cells)
%CASE_ORDER The cases in the order of the inversion's cases (A.6), then any others ascending.
    present = unique(double(cells.CaseID));
    ids = reshape(double(cfg.inversion.caseIDs), [], 1);
    ids = [ids(ismember(ids, present)); setdiff(present, ids)];
end

function label = cell_label(cfg, record)
    label = sprintf('Case %d, %s, %s', record.caseID, plotting.display_name('scenario', record.scenario), ...
        plotting.display_name('design', record.design));
    status = plotting.cell_status_label(cfg, record.caseID, record.scenario, record.design);
    if ~isempty(status), label = sprintf('%s (%s)', label, status); end
end

function text = tex_name(name, logged)
%TEX_NAME The parameter in a formula: a short symbol (ln ... when the log form took its natural log).
    switch name
        case 'm3_f_RD', text = 'm_{3f}';
        case 'm3_e_RD', text = 'm_{3e}';
        case 'log10_k0_RD', text = 'log_{10}k_0';
        case 'Thickness_RD', text = 't';
        otherwise, text = plotting.display_name('parameter', name);
    end
    if logged, text = ['ln ' text]; end
end

function lines = wrapped(text, width)
%WRAPPED TEXT in lines of at most about WIDTH characters, broken between words.
    words = strsplit(strtrim(char(text)), ' ');
    lines = {}; current = '';
    for k = 1:numel(words)
        if ~isempty(current) && numel(current) + 1 + numel(words{k}) > width
            lines{end+1} = current; %#ok<AGROW>
            current = words{k};
        else
            current = strtrim([current ' ' words{k}]);
        end
    end
    lines{end+1} = current;
end

function text = tex_formula(w, labels)
%TEX_FORMULA A combination as text: its weights on z(<parameter>).
    parts = strings(1, numel(w));
    for j = 1:numel(w)
        parts(j) = sprintf('%+.2f z(%s)', w(j), labels{j});
    end
    text = char(strjoin(parts, ' '));
end

function row = sd_ratio_figure(cfg, cells, pair, order, scenarios, factor, sources, scope)
%SD_RATIO_FIGURE Per case: the SD ratio of the best weak-pair combination next to each parameter's.
    fig = figure('Position', [40 40 1250 760]);
    layout = tiledlayout(fig, numel(scenarios), 1, 'Padding', 'compact', 'TileSpacing', 'compact');
    band = legend_band(fig, layout);
    colours = struct('first', [0.00 0.45 0.70], 'second', [0.85 0.37 0.01], 'best', [0 0 0], ...
        'log', [0.00 0.60 0.50], 'limit', [0.55 0.55 0.55]);
    shown = gobjects(1, 0);
    for s = 1:numel(scenarios)
        ax = nexttile(layout); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
        for r = 1:2
            T = cells(cells.Scenario == scenarios(s) & cells.Replicate == r, :);
            if isempty(T), continue; end
            [~, at] = ismember(double(T.CaseID), order);
            x = at + 0.3 * (r - 1.5);
            limit = factor * min(T.(['SDRatio_' pair{1}]), T.(['SDRatio_' pair{2}]));
            h = [plot(ax, x, limit, '_', 'Color', colours.limit, 'MarkerSize', 12, 'LineWidth', 1.5), ...
                plot(ax, x, T.(['SDRatio_' pair{1}]), 's', 'Color', colours.first, 'MarkerSize', 6, ...
                    'MarkerFaceColor', face(colours.first, r)), ...
                plot(ax, x, T.(['SDRatio_' pair{2}]), '^', 'Color', colours.second, 'MarkerSize', 6, ...
                    'MarkerFaceColor', face(colours.second, r)), ...
                plot(ax, x, T.Best_SDRatio, 'o', 'Color', colours.best, 'MarkerSize', 7, ...
                    'MarkerFaceColor', face(colours.best, r)), ...
                plot(ax, x, T.LogBest_SDRatio, 'd', 'Color', colours.log, 'MarkerSize', 6, ...
                    'MarkerFaceColor', face(colours.log, r))];
            if isempty(shown) && r == 1, shown = h; end
        end
        first = cells(cells.Scenario == scenarios(s) & cells.Replicate == 1, :);
        xlim(ax, [0.4 numel(order) + 0.6]); ylim(ax, [0 max(1.15, 1.05 * max(first.(['SDRatio_' pair{2}])))]);
        xticks(ax, 1:numel(order)); xticklabels(ax, string(order));
        ylabel(ax, 'SD ratio');
        title(ax, sprintf(['%s: the best combination is labelled identified in %d of %d cells, its log ' ...
            'form in %d (replicate 1)'], plotting.display_name('scenario', char(scenarios(s))), ...
            nnz(logical(first.Identified)), height(first), nnz(logical(first.LogIdentified))), ...
            'Interpreter', 'none');
    end
    xlabel(ax, 'case');
    legend_row(band, legend_proxies(band, shown), {sprintf('%g x the smaller SD ratio of the pair', factor), ...
        ['SD ratio of ' plotting.display_name('parameter', pair{1})], ...
        ['SD ratio of ' plotting.display_name('parameter', pair{2})], 'best combination of the pair', ...
        'best combination in log form (log coordinates)'});
    title(layout, {'The best-determined combination of the weak pair against each of its parameters alone', ...
        ['SD ratio: posterior SD over prior SD (1: the prior width); open: replicate 2; below the grey ' ...
         'mark: "identified combination", a description, not a test']});
    row = plotting.export_saved_figure(fig, cfg, 'combinations', 'weak_pair_sd_ratios', sources, ...
        'publication', scope);
end

function c = face(colour, replicate)
    c = colour;
    if replicate == 2, c = 'none'; end
end

function a = direction_angle(T, prefix, pair)
%DIRECTION_ANGLE The angle of a weak-pair direction in the plane of the pair (degrees; first weight >= 0).
    a = atan2d(T.([prefix pair{2}]), T.([prefix pair{1}]));
end

function row = direction_figure(cfg, cells, consensus, pair, order, scenarios, sources, scope)
%DIRECTION_FIGURE The direction of the best weak-pair combination per case, with the consensus.
    fig = figure('Position', [40 40 1250 760]);
    layout = tiledlayout(fig, numel(scenarios), 1, 'Padding', 'compact', 'TileSpacing', 'compact');
    band = legend_band(fig, layout);
    labels = cellfun(@(p) plotting.display_name('parameter', p), pair, 'UniformOutput', false);
    shown = gobjects(1, 0);
    for s = 1:numel(scenarios)
        ax = nexttile(layout); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
        Q = consensus(consensus.Scenario == scenarios(s) & consensus.Replicate == 1 & ...
            consensus.Combination == "weak_pair_best", :);
        angleAll = atan2d(Q.(['ConsensusWeight_' pair{2}]), Q.(['ConsensusWeight_' pair{1}]));
        angleCertified = atan2d(Q.(['ConsensusWeight_' pair{2} '_certified_only']), ...
            Q.(['ConsensusWeight_' pair{1} '_certified_only']));
        yline(ax, angleAll, 'k-', 'LineWidth', 1.4);
        yline(ax, angleCertified, 'k:', 'LineWidth', 1.4);
        consensusLines = [plot(ax, NaN, NaN, 'k-', 'LineWidth', 1.4), plot(ax, NaN, NaN, 'k:', 'LineWidth', 1.4)];
        for r = 1:2
            T = cells(cells.Scenario == scenarios(s) & cells.Replicate == r, :);
            if isempty(T), continue; end
            [~, at] = ismember(double(T.CaseID), order);
            h = plot(ax, at + 0.3 * (r - 1.5), direction_angle(T, 'Best_w_', pair), 'o', ...
                'Color', [0 0.45 0.70], 'MarkerSize', 7, 'MarkerFaceColor', face([0 0.45 0.70], r));
            if isempty(shown) && r == 1, shown = [h consensusLines]; end
        end
        xlim(ax, [0.4 numel(order) + 0.6]); ylim(ax, [-90 90]);
        xticks(ax, 1:numel(order)); xticklabels(ax, string(order));
        yticks(ax, -90:45:90);
        yticklabels(ax, {['-90: ' labels{2} ' alone'], ['-45: z(' labels{1} ') - z(' labels{2} ')'], ...
            ['0: ' labels{1} ' alone'], ['45: z(' labels{1} ') + z(' labels{2} ')'], ['90: ' labels{2} ' alone']});
        set(ax, 'TickLabelInterpreter', 'tex');
        ylabel(ax, 'direction [degrees]');
        title(ax, sprintf(['%s: consensus %s; angle of the cells to it: median %.0f, largest %.0f degrees ' ...
            '(replicate 1, %d cells)'], plotting.display_name('scenario', char(scenarios(s))), ...
            tex_formula([Q.(['ConsensusWeight_' pair{1}]) Q.(['ConsensusWeight_' pair{2}])], labels), ...
            Q.MedianAngleToConsensus, Q.MaxAngleToConsensus, Q.Cells), 'Interpreter', 'tex');
    end
    xlabel(ax, 'case');
    legend_row(band, legend_proxies(band, shown), {'best combination of the pair (open: replicate 2)', ...
        'consensus of the cells', 'consensus of the certified cells'});
    title(layout, {'The direction of the best-determined combination of the weak pair, per case', ...
        ['the angle of its weights in the plane of the two prior-standardized parameters; consensus: the ' ...
         'leading eigenvector of the cells'' mean projector']});
    row = plotting.export_saved_figure(fig, cfg, 'combinations', 'weak_pair_directions', sources, ...
        'publication', scope);
end

function a = shifted(a)
%SHIFTED Axis angles in (-45, 135] degrees: the worst-determined directions lie near 90, away from the wrap.
    a(a <= -45) = a(a <= -45) + 180;
end

function row = compensation_figure(cfg, cells, pair, order, scenarios, sources, scope)
%COMPENSATION_FIGURE Predicted least-informative against observed worst-determined direction, per case.
    fig = figure('Position', [40 40 1250 800]);
    layout = tiledlayout(fig, 3, numel(scenarios), 'Padding', 'compact', 'TileSpacing', 'compact');
    band = legend_band(fig, layout);
    blue = [0 0.45 0.70]; shown = gobjects(1, 0);
    for s = 1:numel(scenarios)
        top = nexttile(layout, s); hold(top, 'on'); box(top, 'on'); grid(top, 'on');
        middle = nexttile(layout, numel(scenarios) + s); hold(middle, 'on'); box(middle, 'on'); grid(middle, 'on');
        bottom = nexttile(layout, 2 * numel(scenarios) + s); hold(bottom, 'on'); box(bottom, 'on');
        grid(bottom, 'on');
        for r = 1:2
            T = cells(cells.Scenario == scenarios(s) & cells.Replicate == r, :);
            if isempty(T), continue; end
            [~, at] = ismember(double(T.CaseID), order);
            x = at + 0.3 * (r - 1.5);
            observed = plot(top, x, shifted(direction_angle(T, 'Worst_w_', pair)), 'o', 'Color', blue, ...
                'MarkerSize', 6, 'MarkerFaceColor', face(blue, r));
            plot(middle, x, T.AnglePredictedToObservedWorst, 'o', 'Color', blue, 'MarkerSize', 6, ...
                'MarkerFaceColor', face(blue, r));
            if r == 1
                predicted = plot(top, at, shifted(direction_angle(T, 'Predicted_w_', pair)), 'kd', ...
                    'MarkerSize', 7, 'MarkerFaceColor', [0.85 0.85 0.85]);
                plot(bottom, at, T.CompensationAngle, 'ks', 'MarkerSize', 6, 'MarkerFaceColor', [0.4 0.4 0.4]);
                if isempty(shown), shown = [predicted observed]; end
            end
        end
        for ax = [top middle bottom]
            xlim(ax, [0.4 numel(order) + 0.6]); xticks(ax, 1:numel(order)); xticklabels(ax, string(order));
        end
        ylim(top, [-45 135]); yticks(top, -45:45:135); ylim(middle, [0 90]); ylim(bottom, [0 180]);
        yticks(bottom, 0:45:180);
        title(top, sprintf('%s: direction in the plane of the pair', ...
            plotting.display_name('scenario', char(scenarios(s)))), 'Interpreter', 'none');
        title(middle, 'angle between the predicted and the observed direction', 'Interpreter', 'none');
        title(bottom, 'angle between the sensitivity vectors (180: full compensation)', 'Interpreter', 'none');
        if s == 1
            ylabel(top, 'direction [degrees]'); ylabel(middle, 'angle [degrees]');
            ylabel(bottom, 'angle [degrees]');
        end
        xlabel(bottom, 'case');
    end
    legend_row(band, legend_proxies(band, shown), {['least-informative direction predicted by the GP ' ...
        '(whitened Jacobian at the truth)'], 'worst-determined posterior direction (open: replicate 2)'});
    title(layout, {'The compensation of the weak pair: predicted at the truth and observed in the posteriors', ...
        ['directions as angles of their weights in the plane of the two prior-standardized parameters ' ...
         '(0: the first alone, 90: the second alone, 135: their difference)']});
    row = plotting.export_saved_figure(fig, cfg, 'combinations', 'compensation', sources, 'aggregate', scope);
end

function row = marginal_figure(cfg, C, M, D, names, pair, label, name, sources, cells)
%MARGINAL_FIGURE The marginals of the cell's best combinations against their priors, both replicates.
    fig = figure('Position', [40 40 1250 470]);
    layout = tiledlayout(fig, 1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    band = legend_band(fig, layout);
    kinds = ["four_d_tightest", "weak_pair_best", "weak_pair_best_log"];
    headings = {'four parameters', 'weak pair', 'weak pair, log form'};
    first = C(C.Replicate == 1, :);
    if isempty(first), first = C(1, :); end
    logged = ismember(pair, cfg.analysis.combinations.logForm.parameters);
    weights = {first{1, strcat('FourD_w_', names)}, first{1, strcat('Best_w_', pair)}, ...
        first{1, strcat('LogBest_w_', pair)}};
    labels = {cellfun(@(p) tex_name(p, false), names, 'UniformOutput', false), ...
        cellfun(@(p) tex_name(p, false), pair, 'UniformOutput', false), ...
        arrayfun(@(j) tex_name(pair{j}, logged(j)), 1:2, 'UniformOutput', false)};
    blue = [0.00 0.45 0.70]; shown = gobjects(1, 0);
    for k = 1:numel(kinds)
        ax = nexttile(layout); hold(ax, 'on'); box(ax, 'on');
        one = M(M.Combination == kinds(k), :);
        if isempty(one(one.Replicate == 1, :))
            text(ax, 0.5, 0.5, [{'not applicable:'}, wrapped(first.LogFormReason(1), 40)], ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', 'Interpreter', 'none', 'FontSize', 9);
            axis(ax, 'off');
            title(ax, headings{k}, 'Interpreter', 'none', 'FontWeight', 'normal', 'FontSize', 9);
            continue;
        end
        m1 = one(one.Replicate == 1, :);
        curve = @(r, kind) D(D.Combination == kinds(k) & D.Replicate == r & D.Curve == kind, :);
        p1 = curve(1, "prior");
        area(ax, p1.X, p1.Density, 'FaceColor', [0.88 0.88 0.88], 'EdgeColor', [0.6 0.6 0.6]);
        prior = plot(ax, NaN, NaN, 's', 'MarkerSize', 10, 'MarkerFaceColor', [0.88 0.88 0.88], ...
            'MarkerEdgeColor', [0.6 0.6 0.6]);
        handles = draw_marginal(ax, curve(1, "posterior"), m1, blue, '-', true);
        m2 = one(one.Replicate == 2, :);
        second = gobjects(1, 0);
        if ~isempty(m2)
            second = draw_marginal(ax, curve(2, "posterior"), m2, [0.30 0.30 0.30], '--', false);
            second = second.density;
        end
        xline(ax, m1.Truth, 'Color', [1 0 0], 'LineStyle', '-', 'LineWidth', 1.8);
        truth = plot(ax, NaN, NaN, 'Color', [1 0 0], 'LineStyle', '-', 'LineWidth', 1.8);
        limits = [m1.Lower m1.Upper];
        if kinds(k) == "weak_pair_best_log"
            % The log of a parameter whose prior reaches zero has a long left
            % tail: the axis starts at the prior's 2.5 % quantile.
            left = min([m1.PriorQ025, m1.Q025, m1.Truth]);
            limits = [left - 0.03 * (limits(2) - left), limits(2)];
        end
        xlim(ax, limits);
        xlabel(ax, 'combination u = w^T z', 'Interpreter', 'tex');
        if k == 1, ylabel(ax, 'density'); end
        ratio2 = '';
        if ~isempty(m2), ratio2 = sprintf(' (replicate 2: %.2f)', m2.SDRatio); end
        title(ax, {headings{k}, tex_formula(weights{k}, labels{k}), sprintf('SD ratio %.2f%s; 95%% width %.2f', ...
            m1.SDRatio, ratio2, m1.WidthRatio95)}, 'Interpreter', 'tex', 'FontWeight', 'normal', 'FontSize', 9);
        if isempty(shown)
            shown = [prior handles.density handles.interval95 handles.interval50 handles.mean handles.median ...
                handles.mode second truth];
        end
    end
    entries = {'prior', 'posterior, replicate 1', '95% interval', '50% interval', 'mean', 'median', 'mode'};
    if numel(shown) == 9, entries{end+1} = 'posterior, replicate 2'; end
    entries{end+1} = 'truth';
    legend_row(band, legend_proxies(band, shown), entries);
    title(layout, {sprintf('%s: the best-determined combinations', label), ...
        ['prior-standardized coordinates z (prior SD 1); SD ratio and 95% width: the draws against the ' ...
         'prior sample; the log form from its prior''s 2.5% quantile']});
    row = plotting.export_saved_figure(fig, cfg, 'case/combinations', name, sources, 'publication', cells);
end

function handles = draw_marginal(ax, D, M, colour, style, intervals)
%DRAW_MARGINAL A saved marginal as the inversion's marginals draw it: density, mean, median, mode, intervals.
    handles.density = plot(ax, D.X, D.Density, 'Color', colour, 'LineStyle', style, 'LineWidth', 1.7);
    values = [M.Mean M.Median M.Mode];
    markers = {'o', 's', '^'}; fields = {'mean', 'median', 'mode'};
    for i = 1:3
        y = interp1(D.X, D.Density, values(i), 'linear', 'extrap');
        handles.(fields{i}) = plot(ax, values(i), max(y, 0), markers{i}, 'Color', colour, ...
            'MarkerFaceColor', 'white', 'MarkerSize', 6, 'LineWidth', 1.2);
    end
    handles.interval95 = gobjects(0); handles.interval50 = gobjects(0);
    if intervals
        baseline = -0.035 * max(D.Density);
        handles.interval95 = plot(ax, [M.Q025 M.Q975], [baseline baseline], '-', ...
            'Color', 0.70 + 0.30 * colour, 'LineWidth', 2);
        handles.interval50 = plot(ax, [M.Q25 M.Q75], [baseline baseline], '-', 'Color', colour, 'LineWidth', 5);
    end
end

function row = scatter_figure(cfg, C, replicates, truth, pair, label, name, sources, cells)
%SCATTER_FIGURE Every draw of the weak pair per replicate, with the best and worst directions through the mean.
    names = cellstr(string(cfg.paramNames));
    weak = cfg.analysis.weakPairIndices;
    bounds = double(cfg.paramBounds(weak, :));
    priorSD = (bounds(:, 2) - bounds(:, 1)).' / sqrt(12);
    fig = figure('Position', [40 40 1150 560]);
    layout = tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    band = legend_band(fig, layout);
    shown = gobjects(1, 0);
    for r = 1:2
        ax = nexttile(layout); hold(ax, 'on'); box(ax, 'on');
        T = C(C.Replicate == r, :);
        if isempty(replicates{r}) || isempty(T)
            text(ax, 0.5, 0.5, sprintf('replicate %d not available', r), 'Units', 'normalized', ...
                'HorizontalAlignment', 'center');
            axis(ax, 'off');
            continue;
        end
        X = replicates{r}(:, weak);
        alpha = min(0.15, max(0.02, 0.15 * sqrt(2500 / size(X, 1))));
        draws = scatter(ax, X(:, 1), X(:, 2), 5, 'filled', 'MarkerFaceAlpha', alpha);
        centre = mean(X, 1);
        best = segment(ax, centre, [T.(['Best_w_' pair{1}]) T.(['Best_w_' pair{2}])], T.Best_SDRatio, ...
            priorSD, '-');
        worst = segment(ax, centre, [T.(['Worst_w_' pair{1}]) T.(['Worst_w_' pair{2}])], T.Worst_SDRatio, ...
            priorSD, '--');
        mark = plot(ax, truth(weak(1)), truth(weak(2)), 'rx', 'LineWidth', 1.4, 'MarkerSize', 9);
        xlim(ax, bounds(1, :)); ylim(ax, bounds(2, :));
        xlabel(ax, plotting.display_name('parameter', names{weak(1)}, true), 'Interpreter', 'tex');
        ylabel(ax, plotting.display_name('parameter', names{weak(2)}, true), 'Interpreter', 'tex');
        title(ax, sprintf('replicate %d: best SD ratio %.2f, worst %.2f', r, T.Best_SDRatio, T.Worst_SDRatio), ...
            'Interpreter', 'none', 'FontWeight', 'normal');
        if isempty(shown), shown = [draws best worst mark]; end
    end
    legend_row(band, legend_proxies(band, shown), {'posterior draw', ...
        'best-determined direction (+/- 2 SD)', 'worst-determined direction (+/- 2 SD)', 'truth'});
    title(layout, {sprintf('%s: the weak pair', label), ['every retained draw; the directions run through ' ...
        'the posterior mean over +/- 2 posterior SD along each']});
    row = plotting.export_saved_figure(fig, cfg, 'case/combinations', name, sources, 'diagnostic', cells);
end

function h = segment(ax, centre, w, sdRatio, priorSD, style)
%SEGMENT A direction w of the prior-standardized pair through CENTRE over +/- 2 SD, in model coordinates.
    step = 2 * sdRatio * (w .* priorSD);
    h = plot(ax, centre(1) + [-1 1] * step(1), centre(2) + [-1 1] * step(2), style, 'Color', [0 0 0], ...
        'LineWidth', 2);
end

function band = legend_band(fig, layout)
%LEGEND_BAND A hidden axes across the bottom of the figure for the legend; the layout lies above it.
    share = 0.07;
    layout.OuterPosition = [0 share 1 1 - share];
    band = axes(fig, 'Units', 'normalized', 'Position', [0 0 1 share]);
    hold(band, 'on');
end

function proxies = legend_proxies(ax, handles)
%LEGEND_PROXIES Copies of drawn objects without data in AX, so that its legend shows them as drawn.
    proxies = reshape(copyobj(handles, ax), 1, []);
    for k = 1:numel(proxies)
        set(proxies(k), 'XData', NaN, 'YData', NaN, 'HandleVisibility', 'on');
        if isprop(proxies(k), 'MarkerFaceAlpha')
            % The faint draws of a scatter, shown opaque in the legend.
            set(proxies(k), 'MarkerFaceAlpha', 0.6);
        end
    end
end

function legend_row(ax, handles, labels)
%LEGEND_ROW A one-row legend in the hidden axes of the legend band.
    legend(ax, handles, labels, 'Orientation', 'horizontal', 'NumColumns', numel(handles), ...
        'Location', 'north', 'Interpreter', 'tex');
    axis(ax, 'off');
end

function M = empty_manifest()
    M = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', 'SourceArtifacts'});
end
