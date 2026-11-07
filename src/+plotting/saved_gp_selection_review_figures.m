function manifest = saved_gp_selection_review_figures(cfg, options)
%SAVED_GP_SELECTION_REVIEW_FIGURES Figures of the bounded GP selection review (generalized route).
%   MANIFEST = plotting.saved_gp_selection_review_figures(CFG, OPTIONS) reads
%   the saved tables of the review that selected the approved generalized
%   GP for outputs 1 and 3 (surrogate_selection_review) and draws:
%     selection_review_optimizer_objectives
%         training analytic leave-one-out MSE of the five declared starts,
%         optimizer budget of 20 (original) against 100 iterations (approved)
%     selection_review_matched_oof_rmse
%         outer-fold RMSE of the original against the revised fits on the
%         same 5 x 5 cross-validation folds
%     selection_review_calibration_original_vs_successor
%         cross-fitted NLPD and CRPS of the emulator-variance calibration
%         (tempered local shape, all folds pooled) before and after
%   Only saved review tables are read; nothing is refitted.
%   Ported from the private review scripts (diagnose_bounded_candidates.m,
%   summarize_full_surfaces.m, compare_successor_calibration.py).
%   OPTIONS is unused.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    folder = study.source_folder(cfg, 'surrogate_selection_review');
    objectivesPath = fullfile(folder, 'full_candidate_objectives.csv');
    matchedPath = fullfile(folder, 'matched_affected_output_oof.csv');
    crossfitPath = fullfile(folder, 'original_vs_successor_crossfit_metrics.csv');
    parts = {};
    outputs = cellstr(string(cfg.outputNames(:))).';
    if isfile(objectivesPath)
        T = readtable(objectivesPath, 'Delimiter', ',');
        fig = figure('Position', [80 80 1150 480]);
        layout = tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
        for j = [1 3]
            nexttile(layout); hold on;
            t = sortrows(T(T.OutputIndex == j, :), 'SeedOrder');
            plot(t.SeedOrder, t.OriginalLOOMSE, 'o-', 'LineWidth', 1.4, 'DisplayName', 'MaxIter 20 (original)');
            plot(t.SeedOrder, t.NewLOOMSE, 's-', 'LineWidth', 1.4, 'DisplayName', 'MaxIter 100 (approved)');
            selected = t(logical(t.Selected), :);
            plot(selected.SeedOrder, selected.NewLOOMSE, 'kp', 'MarkerSize', 12, ...
                'MarkerFaceColor', 'y', 'DisplayName', 'selected start');
            xlabel('declared start (seed order)');
            ylabel('training analytic LOO MSE [mbar^2]', 'Interpreter', 'tex');
            title(plotting.display_name('output', outputs{j}, true), 'Interpreter', 'tex');
            legend('Location', 'best');
            xticks(t.SeedOrder);
        end
        title(layout, 'Bounded GP selection: optimizer objective of the five declared starts');
        parts{end+1} = plotting.export_saved_figure(fig, cfg, 'surrogate', ...
            'selection_review_optimizer_objectives', {objectivesPath}, 'publication',[]);
    end
    if isfile(matchedPath)
        T = readtable(matchedPath, 'Delimiter', ',');
        fig = figure('Position', [80 80 1150 520]);
        layout = tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
        for j = [1 3]
            nexttile(layout); hold on;
            t = T(T.OutputIndex == j, :);
            scatter(t.OldRMSE, t.NewRMSE, 30, 'filled');
            limits = [min([t.OldRMSE; t.NewRMSE]) max([t.OldRMSE; t.NewRMSE])];
            plot(limits, limits, 'k--');
            axis square;
            xlabel('original outer-fold RMSE [mbar]');
            ylabel('revised outer-fold RMSE [mbar]');
            title(plotting.display_name('output', outputs{j}, true), 'Interpreter', 'tex');
        end
        title(layout, 'Bounded GP selection: matched out-of-fold RMSE (5 repeats x 5 folds)');
        parts{end+1} = plotting.export_saved_figure(fig, cfg, 'surrogate', ...
            'selection_review_matched_oof_rmse', {matchedPath}, 'publication',[]);
    end
    if isfile(crossfitPath)
        T = readtable(crossfitPath, 'Delimiter', ',', 'TextType', 'string');
        pooled = sortrows(T(T.CalibrationFold == 0 & T.Candidate == "tempered_local_shape" & ...
            T.OutputIndex > 0, :), 'OutputIndex');
        fig = figure('Position', [80 80 1100 460]);
        layout = tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
        metrics = {'GaussianNLPD', 'cross-fitted NLPD'; 'GaussianCRPS', 'cross-fitted CRPS [mbar]'};
        for m = 1:size(metrics, 1)
            nexttile(layout); hold on;
            plot(pooled.OutputIndex, pooled.([metrics{m, 1} '_original']), 'o-', 'LineWidth', 1.4, ...
                'DisplayName', 'original audit calibration');
            plot(pooled.OutputIndex, pooled.([metrics{m, 1} '_successor']), 's-', 'LineWidth', 1.4, ...
                'DisplayName', 'approved (successor) calibration');
            ax = gca; ax.TickLabelInterpreter = 'tex';
            xticks(pooled.OutputIndex);
            xticklabels(plotting.display_name('output', outputs(pooled.OutputIndex)));
            ylabel(metrics{m, 2});
            legend('Location', 'best');
        end
        title(layout, ['Emulator-variance calibration (tempered local shape, folds pooled): ' ...
            'original audit against approved successor']);
        parts{end+1} = plotting.export_saved_figure(fig, cfg, 'surrogate', ...
            'selection_review_calibration_original_vs_successor', {crossfitPath}, 'publication',[]);
    end
    if isempty(parts)
        manifest = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
            'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', ...
            'SourceArtifacts'});
    else
        manifest = vertcat(parts{:});
    end
end
