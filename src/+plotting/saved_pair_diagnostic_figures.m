function manifest = saved_pair_diagnostic_figures(cfg, options)
%SAVED_PAIR_DIAGNOSTIC_FIGURES Saved AIES replicate-pair evidence of the all_six cells.
%   MANIFEST = plotting.saved_pair_diagnostic_figures(CFG, OPTIONS) reads the
%   tabulated pair-reliability records (inversion data:
%   diagnostics/pair_reliability_diagnostics.csv, one row per cell, its
%   replicate pair at the level that decided its status, and sampled
%   parameter, certified or not) and
%   draws, per scenario, one four-panel figure (one panel per parameter, the
%   20 canonical cases on the x axis, one marker per MCMC level) for:
%     <scenario>_pair_normalized_wasserstein      certification criterion
%     <scenario>_pair_normalized_q025_difference  certification criterion
%     <scenario>_pair_normalized_q975_difference  certification criterion
%     <scenario>_pair_ensemble_rhat               supporting warning only
%     <scenario>_pair_ensemble_bulk_ess           supporting warning only
%   with the threshold as a dashed line. The bulk ESS is the corrected value
%   (ranks per parameter); the value recorded at run time used
%   pooled ranks and is in the same table. Interacting walkers are never
%   treated as independent chains; warnings never gate certification.
%   The records include failed and non-certified pairs: the figures show
%   every cell with a pair, certified, healthy fallback or unavailable (a
%   cell whose second replicate ran out of time has none). An undefined
%   R-hat (NaN) or a degenerate one (at least the setting degenerateRhat,
%   A.6) is a health note of the pair diagnostics (study.diagnostic_notes):
%   the R-hat figures leave it out and state the count in their title.
%   Ported from the meeting-additions adapter (generate_meeting.py, diagnostics()).
%   OPTIONS is unused.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    source = fullfile(study.source_folder(cfg, 'inversion_diagnostics'), ...
        'pair_reliability_diagnostics.csv');
    empty = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', ...
        'SourceArtifacts'});
    if ~isfile(source)
        manifest = empty;
        return;
    end
    % Condition is empty for canonical cells, in every row when a campaign has
    % no conditional cells: it is declared text (utils.read_csv_table).
    T = utils.read_csv_table(source, {'Scenario', 'Design', 'Condition', 'Parameter', 'HealthNote'}, ...
        'VariableNamingRule', 'preserve');
    T = T(T.Design == "all_six" & T.Condition == "", :);
    scenarios = string(cfg.inversion.activeScenarioTags);
    parameters = string(cfg.paramNames);
    cases = reshape(double(cfg.inversion.caseIDs), 1, []);
    metrics = {'NormalizedWasserstein', 'WassersteinThreshold', 'normalized_wasserstein', ...
            'normalized Wasserstein distance', 'certification criterion'; ...
        'NormalizedQ025Difference', 'QuantileThreshold', 'normalized_q025_difference', ...
            'normalized 2.5% quantile difference', 'certification criterion'; ...
        'NormalizedQ975Difference', 'QuantileThreshold', 'normalized_q975_difference', ...
            'normalized 97.5% quantile difference', 'certification criterion'; ...
        'EnsembleTimeRhat', 'RhatWarningThreshold', 'ensemble_rhat', ...
            'ensemble-time R-hat', 'warning only'; ...
        'EnsembleTimeBulkESSCorrected', 'BulkESSWarningThreshold', 'ensemble_bulk_ess', ...
            'ensemble-time bulk ESS', 'warning only; ranks per parameter'};
    levels = [2000 5000];
    markers = {'o', 's'};
    colors = [0.14 0.48 0.63; 0.85 0.51 0.16];
    parts = {};
    for s = scenarios(:).'
        z = T(T.Scenario == s, :);
        if isempty(z), continue; end
        for m = 1:size(metrics, 1)
            fig = figure('Position', [40 40 1400 800]);
            layout = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
            leftOut = 0;
            for p = 1:numel(parameters)
                nexttile(layout); hold on;
                q = z(z.Parameter == parameters(p), :);
                if strcmp(metrics{m, 1}, 'EnsembleTimeRhat')
                    % An undefined or degenerate R-hat is a health note (study.diagnostic_notes), not a value.
                    bad = isnan(q.EnsembleTimeRhat) | q.EnsembleTimeRhat >= cfg.inversion.degenerateRhat;
                    leftOut = leftOut + nnz(bad);
                    q = q(~bad, :);
                end
                for k = 1:numel(levels)
                    one = q(q.StepCount == levels(k), :);
                    if isempty(one), continue; end
                    [~, x] = ismember(one.CaseID, cases);
                    scatter(x + (k - 1.5) * 0.25, one.(metrics{m, 1}), 30, colors(k, :), ...
                        markers{k}, 'filled', 'DisplayName', sprintf('%d steps', levels(k)));
                end
                limits = unique(q.(metrics{m, 2}));
                limits = limits(isfinite(limits));
                if isscalar(limits)
                    yline(limits, '--', 'Color', [0.4 0.4 0.4], 'DisplayName', 'threshold');
                end
                xticks(1:numel(cases)); xticklabels(string(cases)); xtickangle(90);
                xlim([0.5 numel(cases) + 0.5]);
                xlabel('CaseID');
                ylabel(metrics{m, 4});
                title(plotting.display_name('parameter', parameters(p)), 'Interpreter', 'tex');
                if p == 1, legend('Location', 'best'); end
            end
            heading = sprintf(['%s, all six outputs: %s of each cell''s replicate pair at ' ...
                'the level that decided its status, certified or not (%s)'], ...
                plotting.display_name('scenario', s), metrics{m, 4}, metrics{m, 5});
            if leftOut > 0
                % The README index joins the two lines with a space.
                title(layout, {[heading ';'], sprintf(['%d undefined or degenerate values left out ' ...
                    '(health notes in the pair diagnostics)'], leftOut)});
            else
                title(layout, heading);
            end
            name = sprintf('%s_pair_%s', s, metrics{m, 3});
            parts{end+1} = plotting.export_saved_figure(fig, cfg, 'inversion', name, ...
                {source}, 'diagnostic', struct('Scenario', s, 'Design', 'all_six')); %#ok<AGROW>
        end
    end
    if isempty(parts)
        manifest = empty;
    else
        manifest = vertcat(parts{:});
    end
end
