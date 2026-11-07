function R = renderers(route, folder)
%RENDERERS The renderers that draw the figures of one analysis folder.
%   R = study.renderers(ROUTE, FOLDER) returns a struct array with fields
%     fn          handle @(cfg,options) returning a figure manifest table
%     name        function name, named in the progress messages and failures
%     options     figure-selection options that differ from the defaults of
%                 study.reproduce for this renderer
%   for the analysis ROUTE/FOLDER (see study.analyses). Renderers read only
%   saved results; none fits a model, samples or evaluates a likelihood.
%   Side effects: none.

    switch [char(route) '/' char(folder)]
        case 'fixed/01_dataset'
            R = [r(@plotting.saved_fixed_dataset_figures), ...
                 r(@plotting.saved_thesis_tables)];
        case 'fixed/02_surrogates'
            % The GP training-versus-external figure and table read the
            % calibrated training-cohort metrics that the recovery analysis
            % saved.
            R = [r(@plotting.saved_surrogate_figures), ...
                 r(@plotting.saved_surrogate_quality_audit_figures), ...
                 r(@plotting.saved_training_convergence_figures), ...
                 r(@plotting.saved_feature_accuracy_figures), ...
                 r(@plotting.saved_thesis_tables), ...
                 r(@plotting.saved_hyperparameter_tables)];
        case 'fixed/03_sensitivity'
            R = [r(@plotting.saved_sensitivity_figures), ...
                 r(@plotting.saved_feature_sensitivity_figures), ...
                 r(@plotting.saved_thesis_tables)];
        case 'fixed/04_inversion'
            R = [r(@plotting.saved_inversion_figures), ...
                 r(@plotting.saved_certification_summaries), ...
                 r(@plotting.saved_cross_design_figures), ...
                 r(@plotting.saved_posterior_comparison_figures), ...
                 r(@plotting.saved_pair_diagnostic_figures), ...
                 r(@plotting.saved_thesis_tables)];
        case 'fixed/05_recovery'
            R = [r(@plotting.saved_coverage_figures), ...
                 r(@plotting.saved_posterior_summary_figures), ...
                 r(@plotting.saved_predictive_check_figures), ...
                 r(@plotting.saved_feature_reconstruction_figures), ...
                 r(@plotting.saved_downstream_error_budget_figures), ...
                 r(@plotting.saved_posterior_eigendecomposition_figures), ...
                 r(@plotting.saved_second_mode_figures), ...
                 r(@plotting.saved_combination_figures), ...
                 r(@plotting.saved_bound_sensitivity_table), ...
                 r(@plotting.saved_thesis_tables)];
        case 'fixed/06_design_study'
            R = [r(@plotting.saved_design_study_figures), ...
                 r(@plotting.saved_thesis_tables)];
        case 'fixed/07_conditional_inversion'
            R = [r(@plotting.saved_conditional_inversion_figures), ...
                 r(@plotting.saved_thesis_tables)];
        case 'fixed/08_ratio_error_curves'
            R = r(@plotting.saved_ratio_error_curve_figures);
        case 'fixed/09_gp_mean_inversion'
            R = r(@plotting.saved_gp_mean_inversion_figures);
        case 'generalized/01_dataset'
            R = [r(@generalized_dataset), ...
                 r(@plotting.saved_thesis_tables)];
        case 'generalized/02_surrogates'
            R = [r(@generalized_surrogates), ...
                 r(@plotting.saved_surrogate_quality_audit_figures), ...
                 r(@plotting.saved_gp_selection_review_figures), ...
                 r(@plotting.saved_feature_accuracy_figures), ...
                 r(@plotting.saved_thesis_tables), ...
                 r(@plotting.saved_hyperparameter_tables)];
        case 'generalized/03_sensitivity'
            R = [r(@generalized_sensitivity), ...
                 r(@plotting.saved_feature_sensitivity_figures), ...
                 r(@plotting.saved_thesis_tables)];
        case 'generalized/04_default_protocol_comparison'
            R = [r(@generalized_default_protocol), ...
                 r(@plotting.saved_thesis_tables)];
        case 'generalized/05_protocol_screening'
            R = [r(@protocol_screening), ...
                 r(@plotting.saved_six_objective_figures), ...
                 r(@plotting.saved_thesis_tables)];
        case 'generalized/06_confirmation'
            R = [r(@plotting.saved_thesis_tables), ...
                 r(@confirmation_results), ...
                 r(@plotting.saved_confirmation_showcase_figures), ...
                 r(@plotting.saved_confirmation_pair_figures), ...
                 r(@plotting.saved_confirmation_combination_figures)];
        otherwise
            R = r([]);
            R = R([]);
    end
end

function s = r(fn, options)
    if nargin < 2, options = struct(); end
    name = '';
    if ~isempty(fn), name = func2str(fn); end
    s = struct('fn', {fn}, 'name', name, 'options', options);
end

% Adapters: the generalized renderers take their saved inputs as arguments.

function manifest = generalized_dataset(cfg, ~)
    folder = study.source_folder(cfg, 'dataset');
    selected = fullfile(folder, 'processed', 'selected_cases.csv');
    assert(isfile(selected), 'study:renderers:GeneralizedDataset', ...
        'Expected the selected generalized cases in %s.', selected);
    manifest = plotting.saved_generalized_dataset_figures(cfg, selected, ...
        fullfile(folder, 'registries', 'case_registry.csv'));
end

function manifest = generalized_surrogates(cfg, ~)
    manifest = plotting.saved_generalized_surrogate_figures(cfg);
end

function manifest = generalized_sensitivity(cfg, ~)
    % The tables of the sensitivity run, in data/sensitivity. A run that
    % computed only the derived features (data/features) has none: nothing to
    % draw here (study.render_run lists the renderer as skipped).
    folder = fullfile(study.source_folder(cfg, 'sensitivity'), 'sensitivity');
    if ~isfolder(folder)
        error('study:source_folder:NotInRun', ...
            'This run holds no results of the step sensitivity (%s).', folder);
    end
    manifest = plotting.saved_generalized_sensitivity_figures(cfg, folder);
end

function manifest = generalized_default_protocol(cfg, ~)
    manifest = plotting.saved_default_protocol_cross_route_figures(cfg);
end

function manifest = confirmation_results(cfg, ~)
    % The compact tier of a finished campaign, copied by the step compare.
    folder = study.source_folder(cfg, 'confirmation');
    manifest = [];
    statusPath = fullfile(folder, 'campaign', 'status', 'confirmation_status.json');
    if ~isfile(statusPath)
        % No compared campaign (observations alone are not rendered).
        return;
    end
    % The analysis's command is that of its first step (the design); its
    % results come from the step compare.
    cfg.layout.command = strrep(cfg.layout.command, '{''export_design''}', '{''compare''}');
    manifest = plotting.saved_confirmation_figures(fullfile(folder, 'campaign'), cfg, ...
        'BookkeepingRoot', cfg.paths.stage07);
end

function manifest = protocol_screening(cfg, ~)
    folder = study.source_folder(cfg, 'screening');
    manifest = plotting.saved_screening_figures(folder, cfg, cfg.paths.stage07);
end
