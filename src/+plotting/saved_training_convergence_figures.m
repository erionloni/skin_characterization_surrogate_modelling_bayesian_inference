function manifest = saved_training_convergence_figures(cfg, options)
%SAVED_TRAINING_CONVERGENCE_FIGURES Per-output accuracy against training-set size.
%   MANIFEST = plotting.saved_training_convergence_figures(CFG, OPTIONS)
%   reads the development audit's training-size study
%   (surrogate_audit/training_convergence/training_convergence_per_output_metrics.csv:
%   three models x six outputs x six nominal sizes x five repetitions) and
%   draws one six-panel figure per metric (R2, RMSE, NRMSE_range, MAE):
%     x = mean actual training count of the output over the five repetitions
%         at one nominal global size,
%     y = mean of the saved metric over the same five repetitions,
%   one line per model (GP Matern-3/2, GP Matern-5/2, PCE). NRMSE_range is
%   RMSE divided by the range of the assessment truths of that output.
%   Only saved audit metrics are averaged; nothing is refitted or predicted.
%   Ported from the meeting-additions adapter (add_training_nrmse.py).
%   OPTIONS is unused.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    source = fullfile(study.source_folder(cfg, 'surrogate_audit'), ...
        'training_convergence', 'training_convergence_per_output_metrics.csv');
    if ~isfile(source)
        manifest = empty_manifest();
        return;
    end
    T = readtable(source, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    assert(all(T.FitStatus == "completed") && ...
        all(T.Cohort == "temporary_development_validation") && height(T) == 540, ...
        'plotting:saved_training_convergence_figures:Study', ...
        'Expected the complete 540-row development training-size study.');
    outputs = cellstr(string(cfg.outputNames(:))).';
    models = {"GP", "Matern-3_2", 'GP Matern-3/2', [0.00 0.45 0.74], 'o'; ...
              "GP", "Matern-5_2", 'GP Matern-5/2', [0.85 0.33 0.10], 'd'; ...
              "PCE", "degree_adaptive_BCS_PCE", 'PCE', [0.49 0.18 0.56], 's'};
    metrics = {'R2', 'R^2', 'r2'; 'RMSE', 'RMSE [mbar]', 'rmse'; ...
               'NRMSE_range', 'NRMSE (RMSE / truth range)', 'nrmse'; ...
               'MAE', 'MAE [mbar]', 'mae'};
    summary = summarize(T, outputs, models, metrics);
    if study.is_publication(cfg)
        study.export_table(cfg, 'surrogate/quality_audit', 'training_convergence_per_output', ...
            summary, {source}, ['Mean training-set size and mean saved accuracy metrics ' ...
            'per output, model and nominal size (five repetitions each)'],[]);
    end
    parts = cell(size(metrics, 1), 1);
    for m = 1:size(metrics, 1)
        fig = figure('Position', [40 40 1500 880]);
        layout = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
        for j = 1:numel(outputs)
            nexttile(layout); hold on;
            for k = 1:size(models, 1)
                rows = summary.Output == outputs{j} & summary.Model == models{k, 3};
                points = sortrows(summary(rows, :), 'NominalGlobalDevelopmentCaseCount');
                plot(points.MeanTrainingSetSize, points.(['Mean' metrics{m, 1}]), ...
                    ['-' models{k, 5}], 'Color', models{k, 4}, 'LineWidth', 1.6, ...
                    'MarkerSize', 6, 'DisplayName', models{k, 3});
            end
            title(plotting.display_name('output', outputs{j}, true), 'Interpreter', 'tex');
            xlabel('mean training set size (cases with this output)');
            ylabel(metrics{m, 2}, 'Interpreter', 'tex');
            if j == 1, legend('Location', 'best'); end
        end
        title(layout, sprintf(['Development audit: %s against training-set size ' ...
            '(mean of five repetitions per size)'], metrics{m, 2}), 'Interpreter', 'tex');
        name = ['training_convergence_per_output_' metrics{m, 3}];
        parts{m} = plotting.export_saved_figure(fig, cfg, 'surrogate/quality_audit', name, ...
            {source}, 'publication',[]);
    end
    manifest = vertcat(parts{:});
end

function S = summarize(T, outputs, models, metrics)
%SUMMARIZE Mean training size and mean metrics over the five repetitions.
    rows = {};
    for j = 1:numel(outputs)
        for k = 1:size(models, 1)
            one = T(T.Output == outputs{j} & T.ModelFamily == models{k, 1} & ...
                T.Candidate == models{k, 2}, :);
            sizes = unique(one.NominalGlobalDevelopmentCaseCount);
            for n = reshape(sizes, 1, [])
                g = one(one.NominalGlobalDevelopmentCaseCount == n, :);
                assert(isequal(sort(g.Repeat).', 1:5), ...
                    'plotting:saved_training_convergence_figures:Repetitions', ...
                    ['The saved training-convergence table must have repeats 1 to 5 for each ' ...
                     'development-set size; rerun the step ''surrogate_audit''.']);
                values = cellfun(@(name) mean(g.(name)), metrics(:, 1)).';
                rows{end+1} = [table(string(outputs{j}), string(models{k, 3}), ...
                    string(models{k, 1}), string(models{k, 2}), n, height(g), ...
                    mean(g.ActualTrainingCaseCount), min(g.ActualTrainingCaseCount), ...
                    max(g.ActualTrainingCaseCount), mean(g.ActualAssessmentCaseCount), ...
                    'VariableNames', {'Output', 'Model', 'ModelFamily', 'Candidate', ...
                    'NominalGlobalDevelopmentCaseCount', 'Repetitions', 'MeanTrainingSetSize', ...
                    'MinimumTrainingSetSize', 'MaximumTrainingSetSize', ...
                    'MeanAssessmentSetSize'}), array2table(values, 'VariableNames', ...
                    strcat('Mean', metrics(:, 1)).')]; %#ok<AGROW>
            end
        end
    end
    S = vertcat(rows{:});
end

function T = empty_manifest()
    T = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', ...
        'SourceArtifacts'});
end
