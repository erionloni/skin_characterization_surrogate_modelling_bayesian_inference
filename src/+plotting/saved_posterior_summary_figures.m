function manifest = saved_posterior_summary_figures(cfg, ~)
%SAVED_POSTERIOR_SUMMARY_FIGURES Posterior intervals, truth inclusion and matched comparisons.
%   MANIFEST = plotting.saved_posterior_summary_figures(CFG, OPTIONS) reads the
%   saved posterior summaries of every inversion cell
%   (coverage/posterior_parameter_cells.csv) and draws,
%   for the all_six design:
%     <scenario>_coverage_forest               per case: median, 50% and 95%
%                                              equal-tailed intervals and truth
%     <scenario>_coverage_error_vs_contraction absolute median error / prior
%                                              range against posterior SD /
%                                              uniform-prior SD
%     <scenario>_coverage_parameter            fraction of case truths inside
%                                              the 50% and 95% intervals
%     posterior_intervals                      one case, the three scenarios
%                                              (cases/case_<id>/recovery/; the
%                                              cases of the settings, A.10
%                                              'posteriorIntervals')
%     width_ratio_noise_vs_no_noise,           measurement_plus_gp against
%     recovery_error_noise_vs_no_noise         gp_only on their common cases
%   and, per scenario, over the cases available for all six designs:
%     <scenario>_matched_designs_posterior_width_ratio
%     <scenario>_matched_designs_recovery_error
%   "Coverage" is the fraction of case truths inside the saved intervals, not
%   a repeated-noise calibration. Every cell with a posterior counts,
%   certified or a healthy fallback; the tables give next to each value its
%   value over the certified cells alone (<column>_certified_only), and a
%   case's figure names its fallbacks and unavailable scenarios. Missing
%   cells stay blank, never zero. Every number is a saved summary or a mean
%   over an explicit case set.
%   Parameters are in model coordinates (log10 of the permeability).
%   Ported from the meeting-additions adapter (generate_meeting.py, coverage()).
%   OPTIONS is unused.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    source = fullfile(study.source_folder(cfg, 'coverage'), 'posterior_parameter_cells.csv');
    if ~isfile(source)
        manifest = empty_manifest();
        return;
    end
    T = readtable(source, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    T = T(logical(T.ArtifactLoaded), :);
    certified = T.CertificationMechanism == "CERTIFIED_AIES_REPLICATE_AGREEMENT";
    assert(height(unique(T(:, {'CellID', 'Parameter'}))) == height(T), ...
        'plotting:saved_posterior_summary_figures:Duplicate', ...
        'The saved posterior summary %s repeats cell and parameter rows; rerun the step ''recovery''.',source);
    scenarios = string(cfg.inversion.activeScenarioTags);
    designs = string(cfg.inversion.designNames);
    parameters = string(cfg.paramNames);
    cases = reshape(double(cfg.inversion.caseIDs), [], 1);
    colors = [0.14 0.48 0.63; 0.85 0.51 0.16; 0.40 0.56 0.30; 0.57 0.40 0.68];
    parts = {};

    for s = scenarios(:).'
        z = T(T.Scenario == s & T.Design == "all_six", :);
        if isempty(z), continue; end
        parts{end+1} = forest(cfg, z, s, parameters, cases, source); %#ok<AGROW>
        parts{end+1} = error_vs_width(cfg, z, s, parameters, colors, source); %#ok<AGROW>
        parts{end+1} = truth_inclusion(cfg, z, certified(T.Scenario == s & T.Design == "all_six"), ...
            s, parameters, source); %#ok<AGROW>
    end
    selection = study.case_outputs(cfg, 'posteriorIntervals');
    for c = reshape(selection.CaseID, 1, [])
        z = T(T.CaseID == c & T.Design == "all_six", :);
        if isempty(z), continue; end
        parts{end+1} = case_intervals(cfg, z, c, scenarios, parameters, source); %#ok<AGROW>
    end
    parts = [parts, matched_scenarios(cfg, T, certified, scenarios(1:2), parameters, source)];
    for s = scenarios(:).'
        q = T(T.Scenario == s, :);
        qc = T(T.Scenario == s & certified, :);
        metrics = {'NormalizedPosteriorSD', 'posterior_width_ratio', 'posterior SD / prior SD'; ...
            'NormalizedAbsoluteErrorFromPosteriorMedian', 'recovery_error', ...
            'absolute median error / prior range'};
        for m = 1:size(metrics, 1)
            [values, n] = matched_design_means(q, designs, parameters, metrics{m, 1});
            if n == 0, break; end   % no case has a posterior for all six designs
            [valuesC, nC] = matched_design_means(qc, designs, parameters, metrics{m, 1});
            name = sprintf('%s_matched_designs_%s', s, metrics{m, 2});
            fig = heatmap_figure(values, plotting.display_name('design', designs), ...
                plotting.display_name('parameter', parameters), metrics{m, 3}, ...
                sprintf('%s: all six designs on the same %d cases', ...
                plotting.display_name('scenario', s), n));
            summary = utils.add_certified_only(design_table(values, n, designs, parameters), ...
                design_table(valuesC, nC, designs, parameters), {'Design'});
            parts{end+1} = export(fig, cfg, name, source, summary, ...
                sprintf(['Mean %s per design and parameter over the %d matched cases with a ' ...
                'posterior (certified and healthy fallback), each followed by its value over ' ...
                'the %d matched certified cases'], metrics{m, 3}, n, nC), ...
                struct('Scenario', s)); %#ok<AGROW>
        end
    end
    manifest = vertcat(parts{:});
end

function row = forest(cfg, z, scenario, parameters, cases, source)
    fig = figure('Position', [40 40 1500 820]);
    layout = tiledlayout(fig, 1, numel(parameters), 'Padding', 'compact', 'TileSpacing', 'compact');
    y = (1:numel(cases)).';
    for p = 1:numel(parameters)
        ax = nexttile(layout); hold on;
        q = align_cases(z(z.Parameter == parameters(p), :), cases);
        for i = 1:numel(cases)
            plot([q.CI025Physical(i) q.CI975Physical(i)], [y(i) y(i)], '-', 'Color', [0.65 0.79 0.87], 'LineWidth', 1.5);
            plot([q.CI25Physical(i) q.CI75Physical(i)], [y(i) y(i)], '-', 'Color', [0.14 0.48 0.63], 'LineWidth', 4);
        end
        plot(q.PosteriorMedianPhysical, y, 'o', 'MarkerSize', 5, 'MarkerFaceColor', [0.14 0.48 0.63], 'MarkerEdgeColor', 'w');
        plot(q.TruthPhysical, y, 'x', 'Color', [0.74 0.26 0.18], 'MarkerSize', 7, 'LineWidth', 1.5);
        set(ax, 'YDir', 'reverse', 'YTick', y, 'YTickLabel', string(cases));
        ylim([0.5 numel(cases) + 0.5]);
        xlabel(plotting.display_name('parameter', parameters(p), true), 'Interpreter', 'tex');
        title(plotting.display_name('parameter', parameters(p)), 'Interpreter', 'tex');
        if p == 1, ylabel('CaseID'); end
    end
    lg = legend(ax, [plot(nan, nan, '-', 'Color', [0.65 0.79 0.87], 'LineWidth', 1.5), ...
        plot(nan, nan, '-', 'Color', [0.14 0.48 0.63], 'LineWidth', 4), ...
        plot(nan, nan, 'o', 'MarkerFaceColor', [0.14 0.48 0.63], 'MarkerEdgeColor', 'none'), ...
        plot(nan, nan, 'x', 'Color', [0.74 0.26 0.18], 'LineWidth', 1.5)], ...
        {'95% interval', '50% interval', 'posterior median', 'truth'}, 'Orientation', 'horizontal');
    lg.Layout.Tile = 'south';
    title(layout, sprintf('%s, all six outputs: posterior median, 50%% / 95%% intervals and truth', ...
        plotting.display_name('scenario', scenario)));
    row = export(fig, cfg, sprintf('%s_coverage_forest', scenario), source, [], '', ...
        struct('Scenario', scenario, 'Design', 'all_six'));
end

function row = error_vs_width(cfg, z, scenario, parameters, colors, source)
    fig = figure('Position', [80 80 820 560]); hold on;
    for p = 1:numel(parameters)
        q = z(z.Parameter == parameters(p), :);
        scatter(q.NormalizedPosteriorSD, q.NormalizedAbsoluteErrorFromPosteriorMedian, 36, ...
            colors(p, :), 'filled', 'MarkerFaceAlpha', 0.8, 'DisplayName', ...
            plotting.display_name('parameter', parameters(p)));
    end
    xline(1, 'k--', 'HandleVisibility', 'off');
    xlabel('posterior SD / uniform-prior SD');
    ylabel('absolute median error / prior range');
    legend('Location', 'best', 'Interpreter', 'tex');
    title(sprintf('%s, all six outputs: recovery error against posterior width', ...
        plotting.display_name('scenario', scenario)));
    row = export(fig, cfg, sprintf('%s_coverage_error_vs_contraction', scenario), source, [], '', ...
        struct('Scenario', scenario, 'Design', 'all_six'));
end

function row = truth_inclusion(cfg, z, certified, scenario, parameters, source)
    S = inclusion_table(z, parameters);
    n = S.N; c50 = S.Coverage50; c95 = S.Coverage95;
    S = utils.add_certified_only(S, inclusion_table(z(certified, :), parameters), {'Parameter'});
    fig = figure('Position', [80 80 860 460]);
    b = bar([c50 c95], 0.8);
    b(1).DisplayName = '50% interval'; b(2).DisplayName = '95% interval';
    yline(0.5, ':', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
    yline(0.95, ':', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
    ax = gca; ax.TickLabelInterpreter = 'tex';
    xticks(1:numel(parameters));
    xticklabels(compose('%s (N = %d)', string(plotting.display_name('parameter', parameters)).', n));
    ylim([0 1.05]);
    ylabel('fraction of case truths inside the interval');
    legend('Location', 'southoutside', 'Orientation', 'horizontal');
    title(sprintf('%s, all six outputs: truth inclusion across cases', ...
        plotting.display_name('scenario', scenario)));
    row = export(fig, cfg, sprintf('%s_coverage_parameter', scenario), source, S, ...
        ['Fraction of case truths inside the 50% and 95% intervals, per parameter, over the ' ...
         'cases with a posterior (certified and healthy fallback), each followed by its value ' ...
         'over the certified cases'], struct('Scenario', scenario, 'Design', 'all_six'));
end

function S = inclusion_table(z, parameters)
%INCLUSION_TABLE Cases, truth inclusion (50%, 95%) and mean SD ratio per parameter.
    n = zeros(numel(parameters), 1); c50 = nan(numel(parameters), 1); c95 = c50; width = c50;
    for p = 1:numel(parameters)
        q = z(z.Parameter == parameters(p), :);
        n(p) = numel(unique(q.CaseID));
        c50(p) = mean(double(q.TruthCovered50));
        c95(p) = mean(double(q.TruthCovered95));
        width(p) = mean(q.NormalizedPosteriorSD);
    end
    S = table(parameters(:), n, c50, c95, width, 'VariableNames', ...
        {'Parameter', 'N', 'Coverage50', 'Coverage95', 'MeanSDRatio'});
end

function [values, n] = matched_design_means(q, designs, parameters, metric)
%MATCHED_DESIGN_MEANS Mean METRIC per design and parameter over the cases present in every design.
%   N is the number of those cases (0: VALUES is NaN).
    values = nan(numel(designs), numel(parameters));
    n = 0;
    if isempty(q), return; end
    counts = groupcounts(q, 'CaseID');
    full = counts.CaseID(counts.GroupCount == numel(designs) * numel(parameters));
    q = q(ismember(q.CaseID, full), :);
    n = numel(full);
    if n == 0, return; end
    for d = 1:numel(designs)
        for p = 1:numel(parameters)
            one = q(q.Design == designs(d) & q.Parameter == parameters(p), :);
            values(d, p) = mean(one.(metric));
        end
    end
end

function S = design_table(values, n, designs, parameters)
%DESIGN_TABLE Design, matched case count and one column per parameter.
    S = [table(designs(:), repmat(n, numel(designs), 1), ...
        'VariableNames', {'Design', 'MatchedCaseCount'}), ...
        array2table(values, 'VariableNames', cellstr(parameters))];
end

function row = case_intervals(cfg, z, caseID, scenarios, parameters, source)
    present = ismember(scenarios, z.Scenario);
    fallback = ismember(scenarios, z.Scenario(z.CertificationMechanism ~= ...
        "CERTIFIED_AIES_REPLICATE_AGREEMENT"));
    fig = figure('Position', [60 60 1150 760]);
    layout = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    y = (1:numel(scenarios)).';
    for p = 1:numel(parameters)
        ax = nexttile(layout); hold on;
        q = z(z.Parameter == parameters(p), :);
        truth = NaN;
        for s = 1:numel(scenarios)
            one = q(q.Scenario == scenarios(s), :);
            if isempty(one), continue; end
            plot([one.CI025Physical one.CI975Physical], [s s], '-', 'Color', [0.65 0.79 0.87], 'LineWidth', 2);
            plot([one.CI25Physical one.CI75Physical], [s s], '-', 'Color', [0.14 0.48 0.63], 'LineWidth', 5);
            plot(one.PosteriorMedianPhysical, s, 'o', 'MarkerFaceColor', [0.14 0.48 0.63], 'MarkerEdgeColor', 'none');
            truth = one.TruthPhysical;
        end
        if isfinite(truth), xline(truth, '--', 'Color', [0.74 0.26 0.18], 'LineWidth', 1.2); end
        set(ax, 'YTick', y, 'YTickLabel', plotting.display_name('scenario', scenarios), 'YDir', 'reverse');
        ylim([0.5 numel(scenarios) + 0.5]);
        xlabel(plotting.display_name('parameter', parameters(p), true), 'Interpreter', 'tex');
    end
    title(layout, sprintf(['Case %d, all six outputs: posterior median, 50%% / 95%% ' ...
        'intervals and truth (dashed) per scenario; healthy fallback: %s; unavailable: %s'], ...
        caseID, listed(scenarios(fallback)), listed(scenarios(~present))));
    % A per-case output: cases/case_<id>/recovery/posterior_intervals.
    row = plotting.export_saved_figure(fig, cfg, 'case/recovery', 'posterior_intervals', ...
        {source}, 'publication', struct('CaseID', caseID, 'Design', 'all_six'));
end

function parts = matched_scenarios(cfg, T, certified, pair, parameters, source)
%MATCHED_SCENARIOS measurement_plus_gp against gp_only on their common cases.
%   The figure shows the cells with a posterior (certified and healthy
%   fallback); the table adds the same means over the certified cells alone.
    rows = T.Design == "all_six" & ismember(T.Scenario, pair);
    [q, common] = common_cases(T(rows, :), pair);
    [qc, commonC] = common_cases(T(rows & certified, :), pair);
    metrics = {'NormalizedPosteriorSD', 'width_ratio_noise_vs_no_noise', 'mean posterior SD / prior SD'; ...
        'NormalizedAbsoluteErrorFromPosteriorMedian', 'recovery_error_noise_vs_no_noise', ...
        'mean absolute median error / prior range'};
    parts = cell(1, size(metrics, 1));
    for m = 1:size(metrics, 1)
        values = scenario_means(q, pair, parameters, metrics{m, 1});
        fig = figure('Position', [80 80 860 460]);
        b = bar(values, 0.8);
        for s = 1:numel(pair), b(s).DisplayName = plotting.display_name('scenario', pair(s)); end
        ax = gca; ax.TickLabelInterpreter = 'tex';
        xticks(1:numel(parameters)); xticklabels(plotting.display_name('parameter', parameters));
        ylabel(metrics{m, 3});
        legend('Location', 'best');
        title(sprintf('All six outputs, matched cases (N = %d): with and without measurement noise', ...
            numel(unique(common))));
        S = utils.add_certified_only( ...
            scenario_table(values, numel(unique(common)), pair, parameters), ...
            scenario_table(scenario_means(qc, pair, parameters, metrics{m, 1}), ...
            numel(unique(commonC)), pair, parameters), {'Parameter'});
        parts{m} = export(fig, cfg, metrics{m, 2}, source, S, ...
            sprintf(['%s per parameter for both scenarios on their common cases with a ' ...
            'posterior (certified and healthy fallback), each followed by its value on their ' ...
            'common certified cases'], metrics{m, 3}), struct('Scenario', pair, 'Design', 'all_six'));
    end
end

function [q, common] = common_cases(q, pair)
%COMMON_CASES The rows of the cases present in both scenarios of PAIR.
    common = intersect(q.CaseID(q.Scenario == pair(1)), q.CaseID(q.Scenario == pair(2)));
    q = q(ismember(q.CaseID, common), :);
end

function values = scenario_means(q, pair, parameters, metric)
%SCENARIO_MEANS Mean METRIC per parameter (rows) and scenario (columns).
    values = nan(numel(parameters), numel(pair));
    for s = 1:numel(pair)
        for p = 1:numel(parameters)
            values(p, s) = mean(q.(metric)(q.Scenario == pair(s) & q.Parameter == parameters(p)));
        end
    end
end

function S = scenario_table(values, n, pair, parameters)
%SCENARIO_TABLE Parameter, one column per scenario, and the matched case count.
    S = [table(parameters(:), 'VariableNames', {'Parameter'}), ...
        array2table(values, 'VariableNames', cellstr(pair))];
    S.MatchedCaseCount = repmat(n, height(S), 1);
end

function text = listed(scenarios)
%LISTED Scenario names for a title: 'none', or the names, comma separated.
    text = 'none';
    if ~isempty(scenarios)
        text = char(strjoin(strrep(scenarios, '_', ' '), ', '));
    end
end

function q = align_cases(q, cases)
%ALIGN_CASES One row per case in the given order; absent cases are NaN rows.
    [present, where] = ismember(cases, q.CaseID);
    names = {'CI025Physical', 'CI975Physical', 'CI25Physical', 'CI75Physical', ...
        'PosteriorMedianPhysical', 'TruthPhysical'};
    out = array2table(nan(numel(cases), numel(names)), 'VariableNames', names);
    for k = 1:numel(names)
        out.(names{k})(present) = q.(names{k})(where(present));
    end
    q = out;
end

function fig = heatmap_figure(values, rowLabels, columnLabels, colorLabel, titleText)
    fig = figure('Position', [80 80 900 520]);
    plotting.blank_missing(imagesc(values));
    colormap(fig, parula);
    cb = colorbar; cb.Label.String = colorLabel;
    ax = gca; ax.TickLabelInterpreter = 'tex';
    xticks(1:numel(columnLabels)); xticklabels(columnLabels);
    yticks(1:numel(rowLabels)); yticklabels(rowLabels);
    for r = 1:size(values, 1)
        for c = 1:size(values, 2)
            if isfinite(values(r, c))
                text(c, r, sprintf('%.2g', values(r, c)), 'HorizontalAlignment', 'center');
            else
                text(c, r, 'n/a', 'HorizontalAlignment', 'center');
            end
        end
    end
    grid off;
    title(titleText);
end

function row = export(fig, cfg, name, source, T, tableTitle, cells)
%EXPORT The figure, and its table when it aggregates the saved summaries
%   (figures that plot saved rows directly get no separate table); CELLS
%   are the inversion cells both show (study.index_entry).
    if study.is_publication(cfg) && ~isempty(T)
        study.export_table(cfg, 'robustness', name, T, {source}, tableTitle, cells);
    end
    row = plotting.export_saved_figure(fig, cfg, 'robustness', name, {source}, 'publication', ...
        cells);
end

function T = empty_manifest()
    T = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', ...
        'SourceArtifacts'});
end
