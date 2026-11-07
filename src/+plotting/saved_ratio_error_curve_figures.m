function manifest = saved_ratio_error_curve_figures(cfg, ~)
%SAVED_RATIO_ERROR_CURVE_FIGURES The ratio-error curves beside the posterior marginals, and the cohort's eta2.
%   MANIFEST = plotting.saved_ratio_error_curve_figures(CFG, OPTIONS) draws,
%   from the saved results of features.ratio_error_curves
%   (study.source_folder 'ratio_error_curves') and the draws of each cell,
%   per cell with a posterior, in its case folder
%   (cases/case_<id>/ratio_error_curves/figures/):
%     <scenario>_<design>_ratio_discrepancy   figure A: per parameter the
%                       posterior marginal of the provider (as in the
%                       inversion's marginals figure, with the truth line)
%                       above the bin medians of the ratio discrepancy d
%                       (markers and lines; the band between the lower and
%                       upper quantiles of the settings, replicate 1;
%                       replicate 2's medians dashed; d at the truth on the
%                       truth line); one y-range for the four lower panels,
%                       no horizontal reference lines
%     <scenario>_<design>_ratio_errors        figure B: the four signed
%                       ratio errors in percent (medians of replicate 1 with
%                       light bands, the zero line: the ratio reproduced
%                       exactly; the values at the truth)
%     <scenario>_<design>_level_discrepancy   as A for the level discrepancy
%     <scenario>_<design>_double_ratio_error  as B for the error of the
%                       double ratio
%   and, in the analysis folder, the table eta2 (one row per cell, one
%   column per parameter; replicate 1) and the figure eta2 (the cohort
%   cells' eta2 per parameter). The curves run between the outermost bin
%   medians (no extrapolation). OPTIONS is unused.
%   Side effects: writes the figures and tables and closes the figures.
%   Computation: seconds per cell (the marginals from the draws).

    manifest = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', 'SourceArtifacts'});
    if ~study.is_publication(cfg), return; end
    folder = study.source_folder(cfg, 'ratio_error_curves');
    paths = struct('cohort', fullfile(folder, 'cohort.csv'), 'bins', fullfile(folder, 'bin_summaries.csv'), ...
        'truth', fullfile(folder, 'truth_markers.csv'), 'eta', fullfile(folder, 'eta2.csv'));
    if ~isfile(paths.cohort), return; end
    cohort = utils.read_csv_table(paths.cohort, {'Scenario', 'Design', 'Role', 'Status', 'ProviderSampler', 'Note'});
    bins = utils.read_csv_table(paths.bins, {'Scenario', 'Design', 'Parameter'});
    truths = utils.read_csv_table(paths.truth, {'Scenario', 'Design'});
    names = cellstr(string(cfg.paramNames));
    c = double(cfg.features.referenceCV);
    parts = {};
    for k = 1:height(cohort)
        if cohort.Replicates(k) == 0, continue; end
        record = struct('caseID', cohort.CaseID(k), 'scenario', char(cohort.Scenario(k)), ...
            'design', char(cohort.Design(k)));
        [A, status] = recovery.load_posterior_provider(cfg, record);
        if ~status.loaded, continue; end
        B = bins(bins.CaseID == record.caseID & bins.Scenario == record.scenario & ...
            bins.Design == record.design, :);
        T = truths(truths.CaseID == record.caseID & truths.Scenario == record.scenario & ...
            truths.Design == record.design, :);
        sources = {paths.bins, paths.truth, A.paths.posteriorPath};
        cells = struct('CaseID', record.caseID, 'Scenario', record.scenario, 'Design', record.design);
        stem = sprintf('%s_%s', record.scenario, record.design);
        label = cell_label(cfg, record);
        parts{end+1} = curve_figure(cfg, A, B, T, names, 'd', ...
            {'ratio discrepancy d', sprintf('[%g %% reference units]', 100 * c)}, ...
            sprintf('%s: ratio discrepancy d along each parameter', label), ...
            [stem '_ratio_discrepancy'], sources, cells); %#ok<AGROW>
        parts{end+1} = signed_figure(cfg, A, B, T, names, ratio_quantities(), ratio_legends(), ...
            'ratio error [%]', sprintf('%s: the four ratio errors along each parameter', label), ...
            [stem '_ratio_errors'], sources, cells); %#ok<AGROW>
        parts{end+1} = curve_figure(cfg, A, B, T, names, 'dLevel', ...
            {'level discrepancy d_{level}', sprintf('[%g %% reference units]', 100 * c)}, ...
            sprintf('%s: level discrepancy along each parameter', label), ...
            [stem '_level_discrepancy'], sources, cells); %#ok<AGROW>
        parts{end+1} = signed_figure(cfg, A, B, T, names, {'DoubleRatioErrorPercent'}, ...
            {'(p^{D2}_{cl,2}/p^{D2}_{cl,1}) / (p^{D6}_{cl,2}/p^{D6}_{cl,1})'}, ...
            'double-ratio error [%]', sprintf('%s: double-ratio error along each parameter', label), ...
            [stem '_double_ratio_error'], sources, cells); %#ok<AGROW>
    end
    if isfile(paths.eta)
        eta = utils.read_csv_table(paths.eta, {'Scenario', 'Design', 'Parameter'});
        if ~isempty(eta)
            parts{end+1} = eta_outputs(cfg, eta, cohort, names, {paths.eta, paths.cohort});
        end
    end
    if ~isempty(parts), manifest = vertcat(parts{:}); end
end

function label = cell_label(cfg, record)
    label = sprintf('Case %d, %s, %s', record.caseID, ...
        plotting.display_name('scenario', record.scenario), plotting.display_name('design', record.design));
    status = plotting.cell_status_label(cfg, record.caseID, record.scenario, record.design);
    if ~isempty(status), label = sprintf('%s (%s)', label, status); end
end

function names = ratio_quantities()
    names = {'RatioErrorPercent_D2_c2c1', 'RatioErrorPercent_D2_c3c1', ...
        'RatioErrorPercent_D6_c2c1', 'RatioErrorPercent_D6_c3c1'};
end

function labels = ratio_legends()
    labels = {'p^{D2}_{cl,2}/p^{D2}_{cl,1}', 'p^{D2}_{cl,3}/p^{D2}_{cl,1}', ...
        'p^{D6}_{cl,2}/p^{D6}_{cl,1}', 'p^{D6}_{cl,3}/p^{D6}_{cl,1}'};
end

function columns = quantile_columns(cfg, quantity)
%QUANTILE_COLUMNS The saved columns of the lower quantile, the centre and the upper quantile of a quantity.
    quantiles = cfg.analysis.ratioErrorCurves.quantiles;
    columns = arrayfun(@(q) sprintf('%s_Q%02d', quantity, round(100 * q)), quantiles, 'UniformOutput', false);
end

function [layout, lower, below] = marginal_layout(fig, cfg, A, names)
%MARGINAL_LAYOUT Per parameter the provider's marginal (upper axes) on an empty lower axes with the same x-axis.
%   The four pairs stand in a 2 x 2 grid, each pair in a layout of its own
%   so that its two axes touch; the x-axis spans the prior range. The
%   marginals are drawn as in the inversion's marginals figure. Below the
%   grid lie two legend rows (legend_band): the marginals' legend, and
%   BELOW, the hidden axes for the legend of the lower panels (legend_row).
    layout = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    [marginals, below] = legend_band(fig, layout);
    draws = double(A.drawsPhysical); truth = double(A.truth(:));
    truthLine = truth_style();
    lower = gobjects(1, numel(names));
    for p = 1:numel(names)
        pair = tiledlayout(layout, 2, 1, 'Padding', 'none', 'TileSpacing', 'tight');
        pair.Layout.Tile = p;
        upper = nexttile(pair);
        [~, handles] = plotting.render_posterior_marginal(draws(:, p), cfg.paramBounds(p, :), ...
            'DisplayName', 'posterior', 'ShowCentralIntervals', true);
        xline(upper, truth(p), truthLine{:});
        ylabel(upper, 'posterior density');
        title(upper, plotting.display_name('parameter', names{p}), 'Interpreter', 'tex');
        if p == 1
            legend_row(marginals, [legend_proxies(marginals, [handles.density handles.interval95 ...
                handles.interval50 handles.mean handles.median handles.mode]), ...
                plot(marginals, NaN, NaN, truthLine{:})], {'posterior density', '95% equal-tailed interval', ...
                '50% equal-tailed interval', 'posterior mean', 'posterior median', 'marginal mode', ...
                'synthetic truth'});
        end
        lower(p) = nexttile(pair);
        hold(lower(p), 'on'); box(lower(p), 'on');
        xline(lower(p), truth(p), truthLine{:});
        linkaxes([upper lower(p)], 'x');
        xlim(upper, cfg.paramBounds(p, :));
        xticklabels(upper, {});
        xlabel(lower(p), plotting.display_name('parameter', names{p}, true), 'Interpreter', 'tex');
    end
end

function [first, second] = legend_band(fig, layout)
%LEGEND_BAND Two hidden axes across the bottom of the figure, one legend row each; the layout lies above them.
%   A legend stays in the layout of its axes, and the pairs are layouts of
%   their own: so the legends of the figure stand outside the layout.
    band = 0.08;  % the share of the figure height below the layout
    layout.OuterPosition = [0 band 1 1 - band];
    first = axes(fig, 'Units', 'normalized', 'Position', [0 band / 2 1 band / 2]);
    second = axes(fig, 'Units', 'normalized', 'Position', [0 0 1 band / 2]);
    hold(first, 'on'); hold(second, 'on');
end

function style = truth_style()
%TRUTH_STYLE The truth line of the marginals (as in the inversion's marginals figure).
    style = {'Color', [1 0 0], 'LineStyle', '-', 'LineWidth', 1.8};
end

function proxies = legend_proxies(ax, handles)
%LEGEND_PROXIES Copies of drawn lines and patches without data in AX, so that its legend shows them as drawn.
    proxies = reshape(copyobj(handles, ax), 1, []);
    set(proxies, 'XData', NaN, 'YData', NaN, 'HandleVisibility', 'on');
end

function legend_row(ax, handles, labels)
%LEGEND_ROW A one-row legend of HANDLES in the hidden axes AX of the legend band (legend_band).
    legend(ax, handles, labels, 'Orientation', 'horizontal', 'NumColumns', numel(handles), ...
        'Location', 'north', 'Interpreter', 'tex');
    axis(ax, 'off');
end

function row = curve_figure(cfg, A, B, T, names, quantity, yLabel, heading, name, sources, cells)
%CURVE_FIGURE The marginals above the bin medians of a nonnegative discrepancy, with the band and replicate 2.
    quantiles = cfg.analysis.ratioErrorCurves.quantiles;
    columns = quantile_columns(cfg, quantity);
    fig = figure('Position', [50 40 1150 800]);
    [layout, lower, below] = marginal_layout(fig, cfg, A, names);
    color = [0.00 0.45 0.70]; top = 0; shown = gobjects(1, 0); labels = {};
    for p = 1:numel(names)
        ax = lower(p);
        one = B(B.Parameter == names{p} & B.Replicate == 1 & B.N > 0, :);
        x = double(one.MedianParameter);
        band = fill(ax, [x; flipud(x)], [one.(columns{1}); flipud(one.(columns{3}))], color, ...
            'FaceAlpha', 0.18, 'EdgeColor', 'none');
        median1 = plot(ax, x, one.(columns{2}), '-o', 'Color', color, 'MarkerSize', 4, ...
            'MarkerFaceColor', color, 'LineWidth', 1.2);
        two = B(B.Parameter == names{p} & B.Replicate == 2 & B.N > 0, :);
        median2 = gobjects(1, 0);
        if ~isempty(two)
            median2 = plot(ax, double(two.MedianParameter), two.(columns{2}), '--', 'Color', [0.30 0.30 0.30], ...
                'LineWidth', 1.2);
            top = max([top; two.(columns{2})]);
        end
        atTruth = plot(ax, double(T.(['Truth_' names{p}])), T.(quantity), 'rd', 'MarkerFaceColor', 'r', ...
            'MarkerSize', 6);
        ylabel(ax, yLabel, 'Interpreter', 'tex');
        top = max([top; one.(columns{3}); T.(quantity)]);
        if p == 1
            shown = [band median1 median2 atTruth];
            labels = [{sprintf('%g-%g %% band (replicate 1)', 100 * quantiles(1), 100 * quantiles(3)), ...
                'bin median (replicate 1)'}, repmat({'bin median (replicate 2)'}, 1, numel(median2)), ...
                {'at the truth'}];
        end
    end
    for p = 1:numel(names), ylim(lower(p), [0 1.05 * top]); end
    legend_row(below, legend_proxies(below, shown), labels);
    title(layout, {heading, sprintf(['per parameter: the posterior marginal (top) and the medians of ' ...
        'the %d equal-count bins of replicate 1 (bottom)'], cfg.analysis.ratioErrorCurves.bins)});
    row = plotting.export_saved_figure(fig, cfg, 'case/ratio_error_curves', name, sources, 'publication', cells);
end

function row = signed_figure(cfg, A, B, T, names, quantities, legends, yLabel, heading, name, sources, cells)
%SIGNED_FIGURE The marginals above the bin medians of signed errors with their bands, the zero line and the truth.
    quantiles = cfg.analysis.ratioErrorCurves.quantiles;
    colors = [0.00 0.45 0.70; 0.84 0.37 0.00; 0.00 0.62 0.45; 0.80 0.47 0.65];
    fig = figure('Position', [50 40 1150 800]);
    [layout, lower, below] = marginal_layout(fig, cfg, A, names);
    limits = [0 0]; shown = gobjects(1, numel(quantities));
    for p = 1:numel(names)
        ax = lower(p);
        one = B(B.Parameter == names{p} & B.Replicate == 1 & B.N > 0, :);
        x = double(one.MedianParameter);
        yline(ax, 0, 'k-');
        for q = 1:numel(quantities)
            columns = quantile_columns(cfg, quantities{q});
            fill(ax, [x; flipud(x)], [one.(columns{1}); flipud(one.(columns{3}))], colors(q, :), ...
                'FaceAlpha', 0.10, 'EdgeColor', 'none');
            curve = plot(ax, x, one.(columns{2}), '-', 'Color', colors(q, :), 'LineWidth', 1.4);
            plot(ax, double(T.(['Truth_' names{p}])), T.(quantities{q}), 'd', 'Color', colors(q, :), ...
                'MarkerFaceColor', colors(q, :), 'MarkerSize', 6);
            if p == 1, shown(q) = curve; end
            limits = [min([limits(1); one.(columns{1}); T.(quantities{q})]), ...
                max([limits(2); one.(columns{3}); T.(quantities{q})])];
        end
        ylabel(ax, yLabel);
    end
    pad = 0.05 * max(diff(limits), eps);
    for p = 1:numel(names), ylim(lower(p), limits + [-pad pad]); end
    legend_row(below, legend_proxies(below, shown), legends);
    title(layout, {heading, sprintf(['bottom: medians of replicate 1 in the %d equal-count bins with their ' ...
        '%g-%g %% bands; diamonds: at the truth; 0: the ratio reproduced exactly'], ...
        cfg.analysis.ratioErrorCurves.bins, 100 * quantiles(1), 100 * quantiles(3))});
    row = plotting.export_saved_figure(fig, cfg, 'case/ratio_error_curves', name, sources, 'publication', cells);
end

function row = eta_outputs(cfg, eta, cohort, names, sources)
%ETA_OUTPUTS The table eta2 (one row per cell, one column per parameter) and the figure of the cohort cells.
    W = unique(eta(:, {'CaseID', 'Scenario', 'Design'}), 'stable');
    W.Role = strings(height(W), 1); W.Status = strings(height(W), 1);
    for i = 1:height(W)
        hit = cohort.CaseID == W.CaseID(i) & cohort.Scenario == W.Scenario(i) & cohort.Design == W.Design(i);
        W.Role(i) = cohort.Role(hit); W.Status(i) = cohort.Status(hit);
    end
    for p = 1:numel(names)
        values = nan(height(W), 1);
        for i = 1:height(W)
            hit = eta.CaseID == W.CaseID(i) & eta.Scenario == W.Scenario(i) & eta.Design == W.Design(i) & ...
                eta.Parameter == names{p};
            values(i) = eta.Eta2(hit);
        end
        W.(['Eta2_' names{p}]) = values;
    end
    study.export_table(cfg, 'ratio_error_curves', 'eta2', W, sources, ...
        ['eta2 of the ratio discrepancy d per cell and parameter (replicate 1): the share of the ' ...
         'variance of d between the equal-count bins of the parameter (descriptive)'], 'all');
    members = W(W.Role == "cohort", :);
    fig = figure('Position', [80 80 900 520]); hold on;
    spread = 0.30 * (((1:height(members)).' - 0.5) / max(height(members), 1) - 0.5);
    for p = 1:numel(names)
        values = members.(['Eta2_' names{p}]);
        plot(p + spread, values, 'o', 'Color', [0.00 0.45 0.70], 'MarkerFaceColor', [0.55 0.75 0.88], ...
            'MarkerSize', 6);
        plot(p + [-0.22 0.22], median(values) * [1 1], 'k-', 'LineWidth', 2);
    end
    xticks(1:numel(names)); xlim([0.5 numel(names) + 0.5]); ylim([0 1]); grid on; box on;
    xticklabels(cellfun(@(n) plotting.display_name('parameter', n), names, 'UniformOutput', false));
    set(gca, 'TickLabelInterpreter', 'tex');
    ylabel('\eta^2 of d (replicate 1)');
    C = cfg.analysis.ratioErrorCurves;
    title({'Ratio discrepancy d: share of its variance between the bins of each parameter', ...
        sprintf('%d cells (%s, %s; %d equal-count bins); black bars: medians', height(members), ...
        plotting.display_name('scenario', C.scenario), plotting.display_name('design', C.design), C.bins)});
    row = plotting.export_saved_figure(fig, cfg, 'ratio_error_curves', 'eta2', sources, 'aggregate', 'all');
end
