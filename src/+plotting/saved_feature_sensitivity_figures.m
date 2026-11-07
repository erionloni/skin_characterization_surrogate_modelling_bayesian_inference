function manifest = saved_feature_sensitivity_figures(cfg, ~)
%SAVED_FEATURE_SENSITIVITY_FIGURES The Sobol indices of the derived features: families, rankings, overview, registry.
%   MANIFEST = plotting.saved_feature_sensitivity_figures(CFG, OPTIONS) draws,
%   from the saved results of features.feature_sensitivity
%   (study.source_folder 'feature_sensitivity') and the primary indices of
%   the six pressures (data/primary), into the sensitivity analysis of the
%   route (file names starting with features_):
%     tables/features_<family>.csv      per family (F0_raw_pressures ...
%                                       F4_decline_shape): feature, status,
%                                       convention, unit, input, S1, ST, the gap
%                                       ST - S1 and the effect size
%     figures/features_<family>.png     per derived family: ST per feature and
%                                       input, S1 written in each cell
%     tables/features_ranking_<input>.csv  per input: every feature ranked by
%                                       ST (with the GP's accuracy on the
%                                       external cases when the step
%                                       feature_accuracy saved it: R^2, NRMSE),
%                                       the top 10 flagged, the features of
%                                       the observation design
%                                       physics_guided_full_rank_six marked,
%                                       exploratory ones flagged, UNSTABLE ones
%                                       left out of the ranks with the reason
%     figures/features_rankings.png     per input the top 10 by ST (bars), S1
%                                       (markers), coloured by family
%     tables/features_dominant_parameter.csv  per feature the input with the
%                                       largest ST, its ST and the second input
%     figures/features_overview.png     every feature, grouped by family: ST
%                                       per input, S1 written in each cell
%     tables/features_registry.csv      the catalog with each feature's
%                                       definition, type, convention, unit,
%                                       status on this route, existing name,
%                                       physics-guided mark and hypothesis
%   The six pressures (F0) carry the primary indices; their effect sizes use
%   the variance of the feature sample. Without primary indices (a run that
%   did not compute the step sensitivity) the six pressures are left out.
%   OPTIONS is unused.
%   Side effects: writes the tables and figures and closes the figures.
%   Computation: seconds.

    manifest = empty_manifest();
    if ~study.is_publication(cfg), return; end
    folder = study.source_folder(cfg, 'feature_sensitivity');
    indicesPath = fullfile(folder, 'feature_indices.csv');
    stabilityPath = fullfile(folder, 'feature_stability.csv');
    if ~isfile(indicesPath), return; end
    primary = fullfile(study.source_folder(cfg, 'sensitivity'), 'primary');
    firstPath = fullfile(primary, 'sobol_gp_first.csv'); totalPath = fullfile(primary, 'sobol_gp_total.csv');
    T = utils.read_csv_table(indicesPath, {'Feature', 'Family', 'Status', 'Convention', 'Unit', 'ExistingAs', ...
        'Parameter'});
    S = utils.read_csv_table(stabilityPath, {'Feature', 'Reason'});
    sources = {indicesPath, stabilityPath};
    if isfile(firstPath) && isfile(totalPath)
        T = with_primary(T, firstPath, totalPath);
        sources = [sources, {firstPath, totalPath}];
    else
        % A run that computed the derived features without the step
        % sensitivity has no primary indices of the six pressures.
        T = T(T.Family ~= "F0_raw_pressures", :);
    end
    C = features.catalog(cfg);
    G = features.physics_guided(cfg, C);
    T = in_catalog_order(T, C, cellstr(string(cfg.outputNames)));
    parameters = unique(T.Parameter, 'stable');
    ranked = T(~startsWith(T.Status, "duplicate"), :);
    unstable = S.Feature(logical(S.Unstable));
    physics = G.Feature(G.Feature ~= "");
    [accuracy, accuracyPath] = feature_accuracy(cfg);
    if ~isempty(accuracyPath), sources{end+1} = accuracyPath; end
    parts = {};
    families = ["F0_raw_pressures", "F1_ratios", "F2_differences", "F3_levels", "F4_decline_shape"];
    for f = families
        rows = T(T.Family == f, :);
        if isempty(rows), continue; end
        study.export_table(cfg, 'sensitivity', "features_" + f, tidy(rows), sources, ...
            sprintf('Sobol indices of the features of family %s (GP mean; S1, ST, ST - S1, effect size)', f), []);
        if f ~= "F0_raw_pressures"
            shown = rows(~startsWith(rows.Status, "duplicate"), :);
            parts{end+1} = heatmap(cfg, shown, parameters, unstable, "Family " + strrep(f, "_", " ") + ...
                ": total-order Sobol indices (S1 in brackets)", "features_" + f, sources); %#ok<AGROW>
        end
    end
    for m = 1:numel(parameters)
        R = with_accuracy(ranking(ranked, parameters(m), unstable, S, physics), accuracy);
        study.export_table(cfg, 'sensitivity', "features_ranking_" + parameters(m), R, sources, ...
            sprintf(['Every feature ranked by its total-order Sobol index for %s (top 10 flagged; ' ...
            'physics-guided design features marked; UNSTABLE ones not ranked)'], parameters(m)), []);
    end
    parts{end+1} = rankings_figure(cfg, ranked, parameters, unstable, physics, sources);
    study.export_table(cfg, 'sensitivity', 'features_dominant_parameter', with_accuracy(dominant(ranked, S), accuracy), ...
        sources, 'Per feature the input with the largest total-order Sobol index, and the second', []);
    parts{end+1} = heatmap(cfg, ranked, parameters, unstable, ...
        "All features by family: total-order Sobol indices (S1 in brackets)", "features_overview", sources);
    study.export_table(cfg, 'sensitivity', 'features_registry', registry(T, C, G, S), sources, ...
        'The feature catalog: definition, convention, status on this route, hypothesis', []);
    manifest = vertcat(parts{:});
end

function [A, pathValue] = feature_accuracy(cfg)
%FEATURE_ACCURACY The GP's accuracy of each feature on the external cases (the step feature_accuracy), when saved.
    A = table('Size', [0 4], 'VariableTypes', {'string', 'double', 'double', 'string'}, ...
        'VariableNames', {'Feature', 'AccuracyR2', 'AccuracyNRMSE', 'AccuracyNote'});
    pathValue = '';
    try
        candidate = fullfile(study.source_folder(cfg, 'feature_accuracy'), 'feature_metrics.csv');
    catch
        return;   % a run without the step feature_accuracy
    end
    if ~isfile(candidate), return; end
    pathValue = candidate;
    M = utils.read_csv_table(candidate, {'Surrogate', 'Subset', 'Feature', 'Family', 'Type', 'Reason'});
    M = M(M.Surrogate == "GP" & M.Subset == "all", :);
    note = strings(height(M), 1);
    note(logical(M.Unstable)) = "UNSTABLE on the external cases: " + M.Reason(logical(M.Unstable));
    A = table(M.Feature, M.R2, M.NRMSE, note, 'VariableNames', A.Properties.VariableNames);
end

function R = with_accuracy(R, A)
%WITH_ACCURACY The columns of the GP's accuracy on the external cases (R^2, NRMSE; NaN without them).
    [hit, at] = ismember(R.Feature, A.Feature);
    R.AccuracyR2 = nan(height(R), 1); R.AccuracyNRMSE = nan(height(R), 1); R.AccuracyNote = strings(height(R), 1);
    R.AccuracyR2(hit) = A.AccuracyR2(at(hit)); R.AccuracyNRMSE(hit) = A.AccuracyNRMSE(at(hit));
    R.AccuracyNote(hit) = A.AccuracyNote(at(hit));
end

function T = with_primary(T, firstPath, totalPath)
%WITH_PRIMARY The six pressures' primary indices (data/primary), their gaps and effect sizes.
    first = readtable(firstPath, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    total = readtable(totalPath, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    names = string(first{:, 1});
    assert(isequal(names, string(total{:, 1})), 'plotting:saved_feature_sensitivity_figures:Primary', ...
        'The primary first- and total-order tables list different outputs.');
    for i = find(T.Family == "F0_raw_pressures").'
        row = names == T.Feature(i);
        T.S1(i) = first.(char(T.Parameter(i)))(row);
        T.ST(i) = total.(char(T.Parameter(i)))(row);
        T.Gap(i) = max(T.ST(i) - T.S1(i), 0);
        T.EffectSize(i) = sqrt(T.ST(i) * T.Variance(i));
    end
end

function T = in_catalog_order(T, C, outputs)
%IN_CATALOG_ORDER The rows by family (F0 to F4), then the pressures in output order and the features in catalog order.
    families = ["F0_raw_pressures", "F1_ratios", "F2_differences", "F3_levels", "F4_decline_shape"];
    [~, family] = ismember(T.Family, families);
    family(family == 0) = numel(families) + 1;
    [inOutputs, a] = ismember(T.Feature, string(outputs));
    [inCatalog, b] = ismember(T.Feature, C.Name);
    position = height(C) + 1 + zeros(height(T), 1);   % duplicates of existing features last in their family
    position(inOutputs) = a(inOutputs);
    position(inCatalog) = b(inCatalog);
    [~, order] = sortrows([family, position, (1:height(T)).']);
    T = T(order, :);
end

function R = tidy(rows)
%TIDY The published columns of a family table.
    R = rows(:, {'Feature', 'Family', 'Status', 'Convention', 'Unit', 'Parameter', 'S1', 'ST', 'Gap', ...
        'EffectSize'});
end

function R = ranking(T, parameter, unstable, S, physics)
%RANKING Every feature ranked by its ST for one input; UNSTABLE ones after the ranked ones, without a rank.
    R = T(T.Parameter == parameter, {'Feature', 'Family', 'Status', 'Convention', 'Unit', 'S1', 'ST', ...
        'Gap', 'EffectSize'});
    excluded = ismember(R.Feature, unstable);
    [~, order] = sort(R.ST(~excluded), 'descend');
    kept = R(~excluded, :); kept = kept(order, :);
    kept.Rank = (1:height(kept)).';
    out = R(excluded, :); out.Rank = nan(height(out), 1);
    R = [kept; out];
    R.Top10 = R.Rank <= 10;
    R.PhysicsGuided = ismember(R.Feature, physics);
    R.Note = strings(height(R), 1);
    for i = 1:height(R)
        R.Note(i) = quotient_note(S, R.Feature(i));
    end
    R = R(:, {'Rank', 'Feature', 'Family', 'Status', 'Convention', 'Unit', 'S1', 'ST', 'Gap', ...
        'EffectSize', 'Top10', 'PhysicsGuided', 'Note'});
end

function D = dominant(T, S)
%DOMINANT Per feature the input with the largest ST and the second; an UNSTABLE feature with its reason.
    names = unique(T.Feature, 'stable');
    n = numel(names);
    D = table(names, strings(n, 1), strings(n, 1), zeros(n, 1), strings(n, 1), zeros(n, 1), strings(n, 1), ...
        'VariableNames', {'Feature', 'Family', 'DominantParameter', 'DominantST', 'SecondParameter', ...
        'SecondST', 'Note'});
    for i = 1:n
        rows = T(T.Feature == names(i), :);
        [values, order] = sort(rows.ST, 'descend');
        D.Family(i) = rows.Family(1);
        D.DominantParameter(i) = rows.Parameter(order(1)); D.DominantST(i) = values(1);
        D.SecondParameter(i) = rows.Parameter(order(2)); D.SecondST(i) = values(2);
        D.Note(i) = quotient_note(S, names(i));
    end
end

function note = quotient_note(S, name)
%QUOTIENT_NOTE The stability of a raw quotient (UNSTABLE with the reason), "" for any other feature.
    note = "";
    hit = S.Feature == name;
    if ~any(hit), return; end
    note = sprintf(['smallest |denominator| %.3g; the 0.1 %% of values farthest from the mean carry %.3g ' ...
        'of the variance'], S.MinAbsDenominator(hit), S.TailShare(hit));
    if logical(S.Unstable(hit)), note = "UNSTABLE, not ranked: " + S.Reason(hit); end
end

function M = empty_manifest()
    M = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', 'SourceArtifacts'});
end

function row = heatmap(cfg, rows, parameters, unstable, titleText, name, sources)
%HEATMAP ST per feature and input, S1 in brackets, in the style of the sensitivity heatmaps.
%   An UNSTABLE feature's cells are grey and carry no number (its indices
%   are in the tables, with the reason).
    names = unique(rows.Feature, 'stable');
    nf = numel(names); np = numel(parameters);
    ST = nan(nf, np); S1 = nan(nf, np); labels = strings(nf, 1);
    for i = 1:nf
        for m = 1:np
            hit = rows.Feature == names(i) & rows.Parameter == parameters(m);
            ST(i, m) = rows.ST(hit); S1(i, m) = rows.S1(hit);
        end
        first = find(rows.Feature == names(i), 1);
        labels(i) = extractBefore(rows.Family(first), 3) + "  " + names(i);
        if rows.Status(first) == "exploratory", labels(i) = labels(i) + " (exploratory)"; end
        if ismember(names(i), unstable)
            labels(i) = labels(i) + " (UNSTABLE)";
            ST(i, :) = NaN; S1(i, :) = NaN;
        end
    end
    fig = figure('Position', [80 40 960 min(820, 170 + 24 * nf)]);
    image = imagesc(ST); set(image, 'AlphaData', ~isnan(ST)); set(gca, 'Color', [0.85 0.85 0.85]);
    colorbar; clim([0 max([ST(:); eps], [], 'omitnan')]);
    xticks(1:np); xticklabels(cellfun(@(n) plotting.display_name('parameter', n), cellstr(parameters), ...
        'UniformOutput', false)); xtickangle(24); set(gca, 'TickLabelInterpreter', 'tex');
    yticks(1:nf); yticklabels(cellstr(strrep(labels, "_", "\_")));
    for i = 1:nf
        for m = 1:np
            if isnan(ST(i, m)), continue; end
            text(m, i, sprintf('%.2f (%.2f)', rounded(ST(i, m)), rounded(S1(i, m))), ...
                'HorizontalAlignment', 'center', 'FontSize', 7);
        end
    end
    xlabel('input'); ylabel('feature'); title(titleText, 'Interpreter', 'none');
    row = plotting.export_saved_figure(fig, cfg, 'sensitivity', char(name), sources, 'aggregate', []);
end

function v = rounded(v)
%ROUNDED A value rounded to two decimals as written in a cell, without a negative zero.
    v = round(v * 100) / 100;
    if v == 0, v = 0; end
end

function row = rankings_figure(cfg, T, parameters, unstable, physics, sources)
%RANKINGS_FIGURE Per input the ten features with the largest ST (bars, coloured by family) and their S1.
    families = ["F0_raw_pressures", "F1_ratios", "F2_differences", "F3_levels", "F4_decline_shape"];
    colors = [0.45 0.45 0.45; 0.00 0.45 0.70; 0.84 0.37 0.00; 0.00 0.62 0.45; 0.80 0.47 0.65];
    np = numel(parameters);
    columns = ceil(np / 2);
    fig = figure('Position', [40 40 min(1300, 330 * columns + 250) 820]);
    layout = tiledlayout(fig, 2, columns, 'Padding', 'compact', 'TileSpacing', 'compact');
    for m = 1:np
        ax = nexttile(layout);
        R = T(T.Parameter == parameters(m) & ~ismember(T.Feature, unstable), :);
        [~, order] = sort(R.ST, 'descend');
        R = R(order(1:min(10, height(R))), :);
        R = flipud(R);
        hold(ax, 'on');
        for i = 1:height(R)
            barh(ax, i, R.ST(i), 0.7, 'FaceColor', colors(families == R.Family(i), :), 'EdgeColor', 'none');
        end
        plot(ax, R.S1, 1:height(R), 'k.', 'MarkerSize', 14);
        labels = R.Feature;
        labels(ismember(R.Feature, physics)) = labels(ismember(R.Feature, physics)) + " *";
        labels(R.Status == "exploratory") = labels(R.Status == "exploratory") + " (expl.)";
        yticks(ax, 1:height(R)); yticklabels(ax, cellstr(labels)); ylim(ax, [0.4 height(R) + 0.6]);
        set(ax, 'TickLabelInterpreter', 'none');
        xlim(ax, [0 1]); grid(ax, 'on'); box(ax, 'on');
        xlabel(ax, 'total-order index S_T');
        title(ax, plotting.display_name('parameter', parameters(m)), 'Interpreter', 'tex');
    end
    % The legend: the families (patches) and the first-order marker.
    ax = nexttile(layout, 1);
    handles = gobjects(1, numel(families) + 1);
    for f = 1:numel(families)
        handles(f) = patch(ax, NaN, NaN, colors(f, :), 'EdgeColor', 'none', ...
            'DisplayName', strrep(families(f), "_", " "));
    end
    handles(end) = plot(ax, NaN, NaN, 'k.', 'MarkerSize', 14, 'DisplayName', 'first-order index S_1');
    shown = legend(ax, handles, 'Orientation', 'horizontal', 'NumColumns', numel(handles), 'Interpreter', 'tex');
    shown.Layout.Tile = 'south';
    title(layout, {'Features ranked by their total-order Sobol index, per input (the ten largest)', ...
        '*: a feature of the observation design physics\_guided\_full\_rank\_six; UNSTABLE features not ranked'});
    row = plotting.export_saved_figure(fig, cfg, 'sensitivity', 'features_rankings', sources, 'aggregate', []);
end

function R = registry(T, C, G, S)
%REGISTRY One row per feature of this route: definition, convention, status, existing name, hypothesis.
    names = unique(T.Feature, 'stable');
    n = numel(names);
    R = table(names, strings(n, 1), strings(n, 1), strings(n, 1), strings(n, 1), strings(n, 1), ...
        strings(n, 1), strings(n, 1), false(n, 1), strings(n, 1), strings(n, 1), 'VariableNames', ...
        {'Feature', 'Family', 'Type', 'Definition', 'Convention', 'Unit', 'Status', 'ExistingAs', ...
        'PhysicsGuided', 'Hypothesis', 'Note'});
    for i = 1:n
        row = T(find(T.Feature == names(i), 1), :);
        R.Family(i) = row.Family; R.Convention(i) = row.Convention; R.Unit(i) = row.Unit;
        R.Status(i) = row.Status; R.ExistingAs(i) = row.ExistingAs;
        R.PhysicsGuided(i) = ismember(names(i), G.Feature);
        k = find(C.Name == names(i), 1);
        if ~isempty(k)
            R.Type(i) = C.Type(k); R.Definition(i) = C.Formula(k); R.Hypothesis(i) = C.Hypothesis(k);
        elseif row.Family == "F0_raw_pressures"
            R.Type(i) = "raw"; R.Definition(i) = "f = " + names(i);
            R.Hypothesis(i) = "the closing pressure itself: level (and implicitly the decline)";
        else
            R.Type(i) = "raw"; R.Definition(i) = row.ExistingAs;
        end
        R.Note(i) = quotient_note(S, names(i));
    end
end
