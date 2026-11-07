function manifest = saved_predictive_check_figures(cfg, ~)
%SAVED_PREDICTIVE_CHECK_FIGURES The posterior predictive check of single cells, from the recovery's reconstruction.
%   MANIFEST = plotting.saved_predictive_check_figures(CFG, OPTIONS) draws,
%   for every cell of the settings (A.10 'predictiveChecks') that the
%   recovery reconstructed, the six closing pressures of the case (the
%   held-out COMSOL pressures) against the posterior median and central
%   95 % interval of the GP mean at the cell's posterior draws, as the
%   recovery saved them (feature_reconstruction/reconstruction_long_form.csv,
%   evaluation space all_six; the reconstruction covers measurement_plus_gp
%   and gp_only), and returns the manifest. A per-case output:
%   cases/case_<CaseID>/recovery/<scenario>_<design>_predictive. The title
%   states the cell's status. Nothing is evaluated: the medians and
%   intervals are the saved ones. A cell without valid reconstruction rows
%   is not drawn.
%   OPTIONS is unused.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    manifest = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', ...
        'SourceArtifacts'});
    source = fullfile(study.source_folder(cfg, 'feature_reconstruction'), ...
        'reconstruction_long_form.csv');
    if ~isfile(source), return; end
    T = utils.read_csv_table(source, {'Scenario', 'FittingDesign', 'EvaluationSpace', ...
        'ScalarFeature', 'Units'});
    required = {'Scenario', 'CaseID', 'FittingDesign', 'EvaluationSpace', 'ScalarFeature', ...
        'Units', 'Truth', 'PosteriorMedian', 'Q025', 'Q975', 'ReconstructionValid'};
    assert(all(ismember(required, T.Properties.VariableNames)), ...
        'plotting:saved_predictive_check_figures:Schema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''recovery''.', source, ...
        strjoin(setdiff(required, T.Properties.VariableNames), ', '));
    S = study.case_outputs(cfg, 'predictiveChecks');
    parts = {};
    for k = 1:height(S)
        rows = double(T.CaseID) == S.CaseID(k) & T.Scenario == S.Scenario(k) & ...
            T.FittingDesign == S.Design(k) & T.EvaluationSpace == "all_six";
        if ~any(rows) || ~all(logical(double(T.ReconstructionValid(rows)))), continue; end
        parts{end+1} = predictive_figure(cfg, T(rows, :), S(k, :), source); %#ok<AGROW>
    end
    if ~isempty(parts), manifest = vertcat(parts{:}); end
end

function row = predictive_figure(cfg, R, selected, source)
%PREDICTIVE_FIGURE The six closing pressures of one cell: observation, posterior median and 95 % interval.
    order = ["p1_D2" "p2_D2" "p3_D2" "p1_D6" "p2_D6" "p3_D6"];
    [present, at] = ismember(order, R.ScalarFeature);
    R = R(at(present), :);
    labels = plotting.display_name('output', regexprep(cellstr(order(present)), ...
        '^p(\d)_(D\d)$', 'pcl$1_$2'));
    x = 1:height(R);
    fig = figure('Position', [100 100 860 480]);
    hold on;
    interval = plot([x; x], [R.Q025.'; R.Q975.'], '-', 'Color', [0.65 0.79 0.87], 'LineWidth', 6);
    center = plot(x, R.PosteriorMedian, 'o', 'MarkerFaceColor', [0.14 0.48 0.63], ...
        'MarkerEdgeColor', 'none', 'MarkerSize', 7);
    observed = plot(x, R.Truth, 'x', 'Color', [0.74 0.26 0.18], 'LineWidth', 2, 'MarkerSize', 11);
    xticks(x);
    xticklabels(labels);
    ax = gca; ax.TickLabelInterpreter = 'tex';
    xlim([0.5 numel(x) + 0.5]);
    ylabel('closing pressure [mbar]');
    grid on;
    legend([interval(1) center observed], {'central 95% interval of the GP mean at the posterior draws', ...
        'posterior median of the GP mean', 'observation (held-out COMSOL pressure)'}, ...
        'Location', 'best');
    scenario = char(selected.Scenario);
    design = char(selected.Design);
    status = plotting.cell_status_label(cfg, selected.CaseID, scenario, design);
    if ~isempty(status), status = [' (' status ')']; end
    title({sprintf('case %d %s %s%s:', selected.CaseID, strrep(scenario, '_', ' '), ...
        strrep(design, '_', ' '), status), ...
        'the six closing pressures against the GP mean at the posterior draws'});
    row = plotting.export_saved_figure(fig, cfg, 'case/recovery', ...
        sprintf('%s_%s_predictive', scenario, design), {source}, 'publication', ...
        struct('CaseID', selected.CaseID, 'Scenario', scenario, 'Design', design));
end
