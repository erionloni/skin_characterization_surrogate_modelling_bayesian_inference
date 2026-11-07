function manifest = saved_feature_accuracy_figures(cfg, ~)
%SAVED_FEATURE_ACCURACY_FIGURES The surrogates' accuracy in feature space on the external cases.
%   MANIFEST = plotting.saved_feature_accuracy_figures(CFG, OPTIONS) draws,
%   from the saved results of features.feature_accuracy
%   (study.source_folder 'feature_accuracy'), into the surrogate analysis of
%   the route (file names starting with feature_accuracy_):
%     tables   _gp, _pce (per feature: bias with its interval, RMSE and R^2
%              with case-bootstrap intervals, MAE, median and maximum |e|,
%              SD(e), spread, NRMSE, noise scale, RMSE / noise, rounding
%              scale, the emulator check, UNSTABLE), _subsets (generalized:
%              the rate and support subsets), _case_errors, _relative_errors,
%              _error_correlation, _error_decomposition, _top_errors
%     figures  _main: the four within-probe ratios and the double ratio R21
%              from the GP mean against COMSOL (identity line; RMSE, bias,
%              max |e| and R^2 written in), and their errors per case with the
%              spread of the feature over the cases (signal scale) and the
%              noise scale (independent errors of the reference CV;
%              descriptive) as bands; _main_pce the same for the PCE;
%              _parity_<family> the other features; _strip every feature's
%              errors over its spread; _error_correlation the correlation of
%              the relative errors of the six outputs and the decomposition
%              of the main features' error variance; _z the emulator check;
%              _subsets (generalized) RMSE per feature in the subsets
%   External cases only, surrogate means. OPTIONS is unused.
%   Side effects: writes the tables and figures and closes the figures.
%   Computation: seconds.

    manifest = empty_manifest();
    if ~study.is_publication(cfg), return; end
    folder = study.source_folder(cfg, 'feature_accuracy');
    names = {'feature_metrics', 'feature_errors', 'relative_errors', 'error_correlation', ...
        'error_decomposition', 'top_errors'};
    paths = cellfun(@(n) fullfile(folder, [n '.csv']), names, 'UniformOutput', false);
    if ~isfile(paths{1}), return; end
    M = utils.read_csv_table(paths{1}, {'Surrogate', 'Subset', 'Feature', 'Family', 'Type', 'Reason'});
    E = utils.read_csv_table(paths{2}, {'Feature', 'Family', 'Surrogate'});
    sources = paths;
    main = ["r21_D2", "r31_D2", "r21_D6", "r31_D6", "R21"];
    overall = M(M.Subset == "all", :);
    gp = overall(overall.Surrogate == "GP", :); pce = overall(overall.Surrogate == "PCE", :);
    route = cfg.layout.route;
    n = gp.N(1);
    study.export_table(cfg, 'surrogate', 'feature_accuracy_gp', drop(gp, {'Surrogate', 'Subset'}), sources, ...
        sprintf(['GP accuracy of every feature on the %d external cases: errors of the feature from the GP ' ...
        'mean against COMSOL (log-linear features in log, about relative; differences in mbar)'], n), []);
    study.export_table(cfg, 'surrogate', 'feature_accuracy_pce', ...
        drop(pce, {'Surrogate', 'Subset', 'SDZ', 'ZWithin196'}), sources, ...
        sprintf('PCE accuracy of every feature on the %d external cases', n), []);
    subsets = M(M.Subset ~= "all" & M.Surrogate == "GP", :);
    if ~isempty(subsets)
        study.export_table(cfg, 'surrogate', 'feature_accuracy_subsets', drop(subsets, {'Surrogate'}), sources, ...
            'GP accuracy of every feature in the protocol subsets of the external cases', []);
    end
    study.export_table(cfg, 'surrogate', 'feature_accuracy_case_errors', ...
        drop(E(E.Surrogate == "GP", :), {'Surrogate'}), sources, ...
        'Per external case and feature: the feature from COMSOL and from the GP mean, the error e and z', []);
    for k = 3:6
        T = readtable(paths{k}, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
        study.export_table(cfg, 'surrogate', ['feature_accuracy_' names{k}], T, sources(k), ...
            table_title(names{k}), []);
    end
    parts = {main_figure(cfg, E, gp, main, "GP", 'feature_accuracy_main', sources), ...
        main_figure(cfg, E, pce, main, "PCE", 'feature_accuracy_main_pce', sources)};
    families = unique(gp.Family, 'stable');
    for f = reshape(families, 1, [])
        members = gp.Feature(gp.Family == f & ~ismember(gp.Feature, main));
        if isempty(members), continue; end
        parts{end+1} = parity_figure(cfg, E, gp, members, "GP", "feature_accuracy_parity_" + f, ...
            sprintf('Family %s from the GP mean against COMSOL, %d external cases', strrep(f, '_', ' '), n), ...
            sources); %#ok<AGROW>
    end
    parts{end+1} = strip_figure(cfg, E, gp, sources);
    D = readtable(paths{5}, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    R = readtable(paths{4}, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    parts{end+1} = correlation_figure(cfg, R, D, main, sources);
    parts{end+1} = z_figure(cfg, E, gp, main, sources);
    if ~isempty(subsets) && strcmp(route, 'generalized')
        parts{end+1} = subsets_figure(cfg, M, sources);
    end
    manifest = vertcat(parts{:});
end

function T = drop(T, columns)
    T(:, intersect(T.Properties.VariableNames, columns, 'stable')) = [];
end

function text = table_title(name)
    switch name
        case 'relative_errors'
            text = 'Per external case and output: the relative errors delta = log(mu / y) of the GP and the PCE, the relative emulator SD';
        case 'error_correlation'
            text = 'The correlation of the GP''s relative errors delta between the six outputs (external cases)';
        case 'error_decomposition'
            text = 'Var(e) of every log-linear feature: the variance terms and the covariance terms of delta (GP)';
        otherwise
            text = 'Per feature the five external cases with the largest |e| of the GP, with their inputs';
    end
end

function [x, y] = shown_values(E, feature, surrogate)
%SHOWN_VALUES The feature from COMSOL and from the surrogate (a log-linear feature as log f).
    rows = E(E.Feature == feature & E.Surrogate == surrogate, :);
    x = rows.FeatureCOMSOL; y = rows.FeatureSurrogate;
end

function row = main_figure(cfg, E, M, main, surrogate, name, sources)
%MAIN_FIGURE The four within-probe ratios and R21: parity panels and the error strip with the two scales.
    fig = figure('Position', [40 40 1250 780]);
    layout = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    for k = 1:numel(main)
        nexttile(layout);
        parity_panel(E, M, main(k), surrogate);
    end
    ax = nexttile(layout); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    for k = 1:numel(main)
        row = M(M.Feature == main(k), :);
        rows = E(E.Feature == main(k) & E.Surrogate == surrogate, :);
        patch(ax, k + [-0.35 0.35 0.35 -0.35], 100 * row.NoiseScale * [-1 -1 1 1], [0.85 0.85 0.85], ...
            'EdgeColor', 'none', 'FaceAlpha', 0.6);
        patch(ax, k + [-0.25 0.25 0.25 -0.25], 100 * row.Spread * [-1 -1 1 1], [0.98 0.75 0.45], ...
            'EdgeColor', 'none', 'FaceAlpha', 0.6);
        offsets = ((1:height(rows)).' - 0.5) / height(rows) - 0.5;
        plot(ax, k + 0.3 * offsets, 100 * rows.Error, '.', 'Color', [0 0.45 0.7], 'MarkerSize', 8);
    end
    yline(ax, 0, 'k-');
    xticks(ax, 1:numel(main)); xticklabels(ax, cellstr(main)); set(ax, 'TickLabelInterpreter', 'none');
    xlim(ax, [0.4 numel(main) + 0.6]);
    ylabel(ax, 'error of log f [%]');
    title(ax, {'errors per case; orange: \pm spread;', ...
        sprintf('grey: \\pm noise scale (CV %.3g %%)', 100 * double(cfg.features.referenceCV))});
    title(layout, {sprintf(['Features from the %s mean against COMSOL, %d external cases (never used for ' ...
        'training, selection or calibration)'], surrogate, M.N(1)), ...
        ['log-ratio errors e = log f(mean) - log f(COMSOL), about relative; R^2 in log; spread: the SD of ' ...
        'the feature over the cases; noise scale: descriptive']});
    row = plotting.export_saved_figure(fig, cfg, 'surrogate', name, sources, 'publication', []);
end

function parity_panel(E, M, feature, surrogate)
%PARITY_PANEL One feature from the surrogate mean against COMSOL, its metrics written in.
    row = M(M.Feature == feature, :);
    [x, y] = shown_values(E, feature, surrogate);
    loglinear = row.Type == "loglinear";
    if loglinear, x = exp(x); y = exp(y); end
    plot(x, y, 'o', 'Color', [0 0.45 0.7], 'MarkerSize', 4, 'MarkerFaceColor', [0.6 0.78 0.9]);
    hold on; grid on; box on;
    limits = [min([x; y]), max([x; y])]; pad = 0.05 * max(diff(limits), eps);
    limits = limits + [-pad pad];
    plot(limits, limits, 'k-'); xlim(limits); ylim(limits);
    scale = 1; unit = '';
    if loglinear, scale = 100; unit = ' %'; end
    text(0.04, 0.96, {sprintf('RMSE %.3g%s, bias %+.2g%s', scale * row.RMSE, unit, scale * row.Bias, unit), ...
        sprintf('max |e| %.3g%s (case %d)', scale * row.MaxAbsError, unit, row.MaxCaseID), ...
        sprintf('R^2 %.3f, spread %.3g%s', row.R2, scale * row.Spread, unit)}, 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'FontSize', 8, 'Interpreter', 'tex');
    note = '';
    if logical(row.Unstable), note = ' (UNSTABLE)'; end
    title([char(feature) note], 'Interpreter', 'none');
    xlabel('from COMSOL'); ylabel(['from the ' char(surrogate) ' mean']);
end

function row = parity_figure(cfg, E, M, members, surrogate, name, heading, sources)
%PARITY_FIGURE Parity panels of several features.
    k = numel(members); columns = min(4, k); rows = ceil(k / columns);
    fig = figure('Position', [40 40 min(1250, 310 * columns + 60) min(800, 270 * rows + 90)]);
    layout = tiledlayout(fig, rows, columns, 'Padding', 'compact', 'TileSpacing', 'compact');
    for i = 1:k
        nexttile(layout);
        parity_panel(E, M, members(i), surrogate);
    end
    title(layout, {heading, ['identity line: the feature reproduced exactly; log-linear features as f, their ' ...
        'errors in log']}, 'Interpreter', 'none');
    row = plotting.export_saved_figure(fig, cfg, 'surrogate', char(name), sources, 'aggregate', []);
end

function row = strip_figure(cfg, E, M, sources)
%STRIP_FIGURE Every feature's errors over its spread, with the noise scale over the spread.
    features = M.Feature;
    fig = figure('Position', [40 40 1250 560]); hold on; box on; grid on;
    for k = 1:numel(features)
        row = M(M.Feature == features(k), :);
        if logical(row.Unstable), continue; end
        rows = E(E.Feature == features(k) & E.Surrogate == "GP", :);
        noise = row.NoiseScale / row.Spread;
        patch(k + [-0.35 0.35 0.35 -0.35], noise * [-1 -1 1 1], [0.85 0.85 0.85], 'EdgeColor', 'none', ...
            'FaceAlpha', 0.6);
        patch(k + [-0.25 0.25 0.25 -0.25], [-1 -1 1 1], [0.98 0.75 0.45], 'EdgeColor', 'none', 'FaceAlpha', 0.6);
        offsets = ((1:height(rows)).' - 0.5) / height(rows) - 0.5;
        plot(k + 0.3 * offsets, rows.Error / row.Spread, '.', 'Color', [0 0.45 0.7], 'MarkerSize', 6);
    end
    yline(0, 'k-');
    xticks(1:numel(features)); xticklabels(cellstr(features)); xtickangle(60);
    set(gca, 'TickLabelInterpreter', 'none'); xlim([0.4 numel(features) + 0.6]); ylim([-4 4]);
    ylabel('error / spread over the cases');
    unstable = features(logical(M.Unstable));
    note = '';
    if ~isempty(unstable)
        note = sprintf('; UNSTABLE, not drawn: %s', strjoin(strrep(unstable, '_', '\_'), ', '));
    end
    title({sprintf('Every feature: GP errors on the %d external cases in units of the feature''s spread', M.N(1)), ...
        ['orange: \pm the spread (signal scale); grey: \pm the noise scale (descriptive), clipped at \pm4' note]});
    row = plotting.export_saved_figure(fig, cfg, 'surrogate', 'feature_accuracy_strip', sources, 'aggregate', []);
end

function row = correlation_figure(cfg, R, D, main, sources)
%CORRELATION_FIGURE The correlation of the relative errors and the decomposition of the main features' Var(e).
    fig = figure('Position', [60 60 1200 520]);
    layout = tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    ax = nexttile(layout);
    values = R{:, 2:end};
    imagesc(ax, values); colorbar(ax); clim(ax, [-1 1]); colormap(ax, plotting_colormap());
    labels = cellfun(@(n) plotting.display_name('output', n), cellstr(R.Output), 'UniformOutput', false);
    xticks(ax, 1:6); yticks(ax, 1:6); xticklabels(ax, labels); yticklabels(ax, labels);
    set(ax, 'TickLabelInterpreter', 'tex'); xtickangle(ax, 30);
    for i = 1:6
        for j = 1:6
            colour = [0 0 0];
            if abs(values(i, j)) > 0.6, colour = [1 1 1]; end
            text(ax, j, i, sprintf('%.2f', values(i, j)), 'HorizontalAlignment', 'center', 'FontSize', 8, ...
                'Color', colour);
        end
    end
    title(ax, 'correlation of the relative GP errors \delta');
    ax = nexttile(layout); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    rows = D(ismember(D.Feature, main), :);
    bars = bar(ax, 1e4 * [rows.VarianceTerms, rows.CovarianceTerms], 'grouped');
    plot(ax, (1:height(rows)) + 0.25, 1e4 * rows.ObservedVariance, 'kd', 'MarkerFaceColor', 'k');
    xticks(ax, 1:height(rows)); xticklabels(ax, cellstr(rows.Feature)); set(ax, 'TickLabelInterpreter', 'none');
    ylabel(ax, 'variance of the error [10^{-4}]');
    legend(ax, [bars(1), bars(2)], {'variance terms \Sigma_k w_k^2 Var(\delta_k)', ...
        'covariance terms 2 \Sigma_{j<k} w_j w_k Cov(\delta_j, \delta_k)'}, 'Location', 'northwest', ...
        'Interpreter', 'tex');
    title(ax, {'Var(e) = variance terms + covariance terms (diamonds: observed)', ...
        'negative covariance terms: the errors cancel in the ratio'});
    title(layout, 'The GP''s relative errors on the external cases: correlation and decomposition');
    row = plotting.export_saved_figure(fig, cfg, 'surrogate', 'feature_accuracy_error_correlation', sources, ...
        'aggregate', []);
end

function map = plotting_colormap()
%PLOTTING_COLORMAP A blue-white-red map for correlations.
    t = linspace(0, 1, 128).';
    map = [[t; ones(128, 1)], [t; flipud(t)], [ones(128, 1); flipud(t)]];
end

function row = z_figure(cfg, E, M, main, sources)
%Z_FIGURE The emulator check: z = e / s per case, against the standard normal.
    fig = figure('Position', [60 60 1200 620]);
    layout = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    grid1 = linspace(-4, 4, 200);
    for k = 1:numel(main)
        ax = nexttile(layout); hold(ax, 'on'); box(ax, 'on');
        rows = E(E.Feature == main(k) & E.Surrogate == "GP", :);
        histogram(ax, rows.Z, -4:0.5:4, 'Normalization', 'pdf', 'FaceColor', [0.6 0.78 0.9]);
        plot(ax, grid1, exp(-grid1.^2 / 2) / sqrt(2 * pi), 'k-', 'LineWidth', 1.2);
        row = M(M.Feature == main(k), :);
        title(ax, sprintf('%s: SD(z) %.2f; |z| < 1.96 in %d of %d', main(k), row.SDZ, row.ZWithin196, row.N), ...
            'Interpreter', 'none');
        xlabel(ax, 'z = e / s'); ylabel(ax, 'density');
    end
    title(layout, {'Emulator check in feature space: the GP error over its SD under independent calibrated emulator variances', ...
        'curve: the standard normal; SD(z) < 1: s overstates the errors (conservative); SD(z) > 1: s understates them'});
    row = plotting.export_saved_figure(fig, cfg, 'surrogate', 'feature_accuracy_z', sources, 'aggregate', []);
end

function row = subsets_figure(cfg, M, sources)
%SUBSETS_FIGURE The GP's RMSE per log-linear feature in the protocol subsets of the external cases.
    G = M(M.Surrogate == "GP" & M.Type == "loglinear", :);
    features = unique(G.Feature, 'stable');
    subsets = unique(G.Subset, 'stable');
    markers = {'o', '^', 'v', 's', 'd'};
    colours = [0 0 0; 0 0 1; 0 0 1; 1 0 0; 1 0 0];
    fig = figure('Position', [40 40 1250 520]); hold on; box on; grid on;
    handles = gobjects(1, numel(subsets)); labels = strings(1, numel(subsets));
    for s = 1:numel(subsets)
        rows = G(G.Subset == subsets(s), :);
        [~, position] = ismember(rows.Feature, features);
        x = position + 0.08 * (s - 3);
        colour = colours(min(s, size(colours, 1)), :);
        plot([x x].', 100 * [rows.RMSELow rows.RMSEHigh].', '-', 'Color', colour, 'LineWidth', 0.5);
        handles(s) = plot(x, 100 * rows.RMSE, markers{min(s, numel(markers))}, 'Color', colour, ...
            'MarkerSize', 5);
        labels(s) = sprintf('%s (n = %d)', strrep(subsets(s), '_', ' '), rows.N(1));
    end
    xticks(1:numel(features)); xticklabels(cellstr(features)); xtickangle(60);
    set(gca, 'TickLabelInterpreter', 'none'); xlim([0.4 numel(features) + 0.6]);
    ylabel('RMSE of log f [%]');
    legend(handles, cellstr(labels), 'Location', 'northwest', 'Interpreter', 'none');
    title({'GP accuracy of the log-linear features in the protocol subsets of the external cases', ...
        ['rate faster or not than the default protocol''s; inside or outside the training support of ' ...
        'pcl3\_D6\_mbar; lines: 95 % case-bootstrap intervals']});
    row = plotting.export_saved_figure(fig, cfg, 'surrogate', 'feature_accuracy_subsets', sources, 'aggregate', []);
end

function M = empty_manifest()
    M = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', 'SourceArtifacts'});
end
