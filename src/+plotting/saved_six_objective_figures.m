function manifest = saved_six_objective_figures(cfg, options)
%SAVED_SIX_OBJECTIVE_FIGURES Figures of the six-objective protocol-screening supplement.
%   MANIFEST = plotting.saved_six_objective_figures(CFG, OPTIONS) reads the
%   saved six-objective rankings of the 730 candidate protocols (operational
%   covariance: measurement plus emulator uncertainty), the objective
%   registry and the three objective-focused protocols selected for the
%   confirmation, and draws:
%     six_objective_operational_rankings
%         mean covariance-proxy score against rank for each objective, with
%         the default protocol marked
%     proposed_protocol_cross_objective_changes
%         reduction of every objective's mean score relative to the default
%         protocol, for the three selected protocols [%]
%   Only saved rankings are read; no Fisher information is recomputed.
%   Ported from the private review script (render_multiobjective_review.m).
%   OPTIONS is unused.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    folder = study.source_folder(cfg, 'six_objective');
    rankingsPath = fullfile(folder, 'six_objective_rankings.csv');
    selectionPath = fullfile(folder, 'proposed_objective_selections.csv');
    registryPath = fullfile(folder, 'objective_registry.csv');
    empty = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', ...
        'SourceArtifacts'});
    if ~(isfile(rankingsPath) && isfile(selectionPath) && isfile(registryPath))
        manifest = empty;
        return;
    end
    R = readtable(rankingsPath, 'Delimiter', ',', 'TextType', 'string');
    W = readtable(selectionPath, 'Delimiter', ',', 'TextType', 'string');
    registry = readtable(registryPath, 'Delimiter', ',', 'TextType', 'string');
    objectives = registry.ObjectiveID;
    O = R(R.CovarianceCase == "operational_measurement_plus_emulator", :);
    parts = {};

    fig = figure('Position', [60 60 1300 740]);
    layout = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    for o = 1:numel(objectives)
        nexttile(layout); hold on;
        T = sortrows(O(O.ObjectiveID == objectives(o), :), 'Rank');
        plot(T.Rank, T.MeanScore, 'LineWidth', 1.4, 'DisplayName', 'candidate protocols');
        d = T(T.IsDefault == 1, :);
        scatter(d.Rank, d.MeanScore, 45, 'filled', 'DisplayName', 'default protocol');
        xlabel('protocol rank');
        ylabel('mean prior-SD covariance proxy');
        title(strrep(char(objectives(o)), '_', ' '));
        if o == 1, legend('Location', 'best'); end
    end
    title(layout, 'Six design objectives: operational covariance ranking of the 730 protocols');
    parts{end+1} = plotting.export_saved_figure(fig, cfg, 'screening', ...
        'six_objective_operational_rankings', {rankingsPath, registryPath}, 'publication',[]);

    selected = W(W.CovarianceCase == "operational_measurement_plus_emulator", :);
    labels = {'joint weak-pair selector', 'permeability selector', 'dissipation selector'};
    values = nan(height(selected), numel(objectives));
    for a = 1:height(selected)
        for o = 1:numel(objectives)
            r = O(O.CandidateID == selected.CandidateID(a) & O.ObjectiveID == objectives(o), :);
            assert(height(r) == 1, 'plotting:saved_six_objective_figures:Candidate', ...
                ['The saved six-objective table has %d rows for candidate %s and objective ' ...
                 '%s, not one.'],height(r),string(selected.CandidateID(a)),string(objectives(o)));
            values(a, o) = 100 * r.RelativeImprovement;
        end
    end
    fig = figure('Position', [80 80 1150 560]);
    imagesc(values);
    colormap(fig, parula); cb = colorbar; cb.Label.String = 'reduction relative to the default [%]';
    xticks(1:numel(objectives)); xticklabels(strrep(objectives, '_', ' ')); xtickangle(25);
    yticks(1:height(selected)); yticklabels(labels(1:height(selected)));
    for a = 1:height(selected)
        for o = 1:numel(objectives)
            text(o, a, sprintf('%.2f', values(a, o)), 'HorizontalAlignment', 'center');
        end
    end
    grid off;
    title('Selected protocols: default-relative reduction of each objective''s mean score [%]');
    parts{end+1} = plotting.export_saved_figure(fig, cfg, 'screening', ...
        'proposed_protocol_cross_objective_changes', {selectionPath, rankingsPath, registryPath}, ...
        'publication',[]);
    manifest = vertcat(parts{:});
end
