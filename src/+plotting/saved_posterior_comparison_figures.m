function manifest = saved_posterior_comparison_figures(cfg, ~)
%SAVED_POSTERIOR_COMPARISON_FIGURES All-six posterior marginals of one case across scenarios.
%   MANIFEST = plotting.saved_posterior_comparison_figures(CFG, OPTIONS) draws,
%   for every case of the settings (A.10 'scenarioMarginals'), one figure
%   with four panels (one per parameter,
%   model coordinates): the histogram density of the retained draws of the
%   selected all_six provider in each scenario (measurement_plus_gp, gp_only,
%   gp_self_det), in 50 fixed bins spanning the prior domain, and the truth.
%     all_six_scenario_marginals    (cases/case_<id>/inversion/)
%   The provider of each cell is the selected one, certified or a healthy
%   fallback (recovery.load_posterior_provider); the title names the
%   fallbacks and the scenarios without a provider, which are left out.
%   Replicates are never pooled.
%   Ported from the meeting-additions adapter (generate_meeting.py,
%   posterior(), "case_<id>_posterior_modes").
%   OPTIONS is unused.
%   Side effects: writes the figures and marginal-statistics tables and
%   closes the figures.
%   Computation: seconds to a minute.

    scenarios = string(cfg.inversion.activeScenarioTags);
    parameters = string(cfg.paramNames);
    selection = study.case_outputs(cfg, 'scenarioMarginals');
    cases = reshape(selection.CaseID, 1, []);
    colors = [0.14 0.48 0.63; 0.85 0.51 0.16; 0.40 0.56 0.30];
    parts = {};
    for c = cases
        providers = cell(1, numel(scenarios));
        fallback = false(1, numel(scenarios));
        sources = {};
        for s = 1:numel(scenarios)
            record = struct('caseID', c, 'scenario', char(scenarios(s)), 'design', 'all_six');
            [A, status] = recovery.load_posterior_provider(cfg, record);
            if status.loaded
                providers{s} = A;
                fallback(s) = ~logical(status.certified);
                sources{end+1} = A.paths.posteriorPath; %#ok<AGROW>
            end
        end
        if all(cellfun(@isempty, providers)), continue; end
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
        title(layout, sprintf(['Case %d, all six outputs: posterior marginals per scenario ' ...
            '(histograms of all retained draws of the selected provider); healthy fallback: ' ...
            '%s; unavailable: %s'], c, listed(scenarios(fallback)), ...
            listed(scenarios(cellfun(@isempty, providers)))));
        % A per-case output: cases/case_<id>/inversion/all_six_scenario_marginals.
        parts{end+1} = plotting.export_saved_figure(fig, cfg, 'case/inversion', ...
            'all_six_scenario_marginals', sources, 'publication', ...
            struct('CaseID', c, 'Design', 'all_six')); %#ok<AGROW>
    end
    if isempty(parts)
        manifest = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
            'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', ...
            'SourceArtifacts'});
    else
        manifest = vertcat(parts{:});
    end
end

function text = listed(scenarios)
%LISTED Scenario names for a title: 'none', or the names, comma separated.
    text = 'none';
    if ~isempty(scenarios)
        text = char(strjoin(strrep(scenarios, '_', ' '), ', '));
    end
end
