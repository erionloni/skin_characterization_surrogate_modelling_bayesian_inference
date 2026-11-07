function result = run_recovery(cfg)
%RUN_RECOVERY Coverage, recovery and posterior geometry of the fixed inversion grid.
%   RESULT = recovery.run_recovery(CFG) summarizes the posteriors of the
%   selected providers of the inversion grid (recovery.load_posterior_provider:
%   a run's own certified posteriors below CFG.paths.stage04, or the shipped
%   draws, certified or healthy fallback); no sampler runs. CFG.analysis
%   selects its analyses (the run switches of the settings, 0.2):
%     runCoverageRecovery   per cell and parameter: posterior width,
%                           contraction, truth inclusion and recovery error,
%                           and their summaries by scenario and design (tables
%                           below CFG.paths.stage05; the six-design comparison
%                           summarizes the same grid across cases and
%                           scenarios)
%     runPosteriorCovarianceEigendecomposition  the posterior covariance
%                           eigendecomposition
%     runFeatureReconstructionAnalysis  the feature reconstruction, with its
%                           downstream error budget (runDownstreamErrorBudget)
%     runSecondModeCheck    the second walker group of one cell
%                           (recovery.second_mode_check)
%   Each analysis reads the posteriors itself; switching one off leaves the
%   others' results unchanged. RESULT counts the planned, certified and
%   unresolved cells (NaN for the latter two when the coverage summaries are
%   not computed).
%   The body of the pre-publication script
%   (s05_run_coverage_recovery), moved unchanged. Its resume mode for
%   the supplementary analyses alone, which only the pre-publication launcher
%   set, is gone.
%   Computation: minutes to about 1 h (GP evaluations at posterior draws).
%   Side effects: writes the tables and records below CFG.paths.stage05.
    assert(strcmp(cfg.dataMode,'real'),'recovery:run_recovery:Route', ...
        'The recovery analysis belongs to the fixed route.');
    tableRoot=fullfile(cfg.paths.stage05,'tables');
    ensure_dirs({tableRoot});
    P=parameters.parameter_space(cfg);
    cases=data.inversion_cases(cfg,P);
    grid=inversion.build_inversion_grid(cfg,cases);
    assert(grid.caseCount==numel(cases)&&grid.scenarioCount==3&& ...
        grid.designCount==6&&grid.cellCount==double( ...
        cfg.inversion.expectedCellCount), ...
        'recovery:run_recovery:ActiveGridShape', ...
        ['The recovery needs the complete configured inversion grid ' ...
         '(N cases x 3 scenarios x 6 designs).']);
    summary=struct('plannedCellCount',grid.cellCount,'certifiedCellCount',NaN, ...
        'unresolvedCellCount',NaN,'complete',false);
    if logical(cfg.analysis.runCoverageRecovery)
        summary=coverage_recovery(cfg,grid,tableRoot);
    end
    eigendecompositionResult=struct([]);
    runEigen=logical(cfg.analysis.runPosteriorCovarianceEigendecomposition);
    runFeature=logical(cfg.analysis.runFeatureReconstructionAnalysis);
    if runEigen
        eigendecompositionResult= ...
            recovery.run_posterior_eigendecomposition(cfg,grid);
    end
    featureReconstructionResult=struct([]);
    if runFeature
        featureReconstructionResult= ...
            recovery.run_feature_reconstruction(cfg,grid);
    end
    result=struct('planned_cells',summary.plannedCellCount, ...
        'certified_cells',summary.certifiedCellCount, ...
        'unresolved_cells',summary.unresolvedCellCount, ...
        'mcmc_run_count',0,'complete',logical(summary.complete));
    if ~isempty(eigendecompositionResult)
        result.posterior_covariance_eigendecomposition= ...
            eigendecompositionResult.status;
    end
    if ~isempty(featureReconstructionResult)
        result.feature_reconstruction=featureReconstructionResult.status;
    end
    if logical(cfg.analysis.runSecondModeCheck)
        result.second_mode_check=recovery.second_mode_check(cfg);
    end
    if logical(cfg.analysis.runCoverageRecovery)
        fprintf('[recovery] read the posteriors of %d/%d certified cells; no MCMC run.\n', ...
            summary.certifiedCellCount,summary.plannedCellCount);
    end
end

function summary=coverage_recovery(cfg,grid,tableRoot)
%COVERAGE_RECOVERY Truth inclusion, posterior width and recovery error per cell, and their summaries.
    summary=recovery.summarize_posterior_grid(cfg,grid);

    write(summary.parameterCells,'posterior_parameter_cells.csv');
    write(summary.cellStatus,'posterior_cell_status.csv');
    write(summary.correlations,'posterior_correlations.csv');
    write(summary.byParameter,'summary_by_parameter.csv');
    write(summary.byScenarioParameter,'summary_by_scenario_parameter.csv');
    write(summary.byScenarioDesignParameter, ...
        'summary_by_scenario_design_parameter.csv');
    write(summary.byScenario,'summary_by_scenario.csv');
    write(summary.byScenarioDesign,'summary_by_scenario_design.csv');
    utils.atomic_save_struct(fullfile(cfg.paths.stage05, ...
        'coverage_recovery_summary.mat'),struct('summary',summary),'-v7.3');
    scope=struct('schema_version','coverage_recovery_scope_v1', ...
        'interpretation',['Deterministic held-out COMSOL truth inclusion ' ...
        'and simulation-to-simulation recovery; not repeated-noise ' ...
        'frequentist posterior calibration.'], ...
        'measurement_plus_gp_role','primary_realistic', ...
        'gp_only_role','structural_no_measurement_noise_diagnostic', ...
        'gp_self_det_role','numerical_self_consistency_diagnostic', ...
        'design_count',6, ...
        'physics_guided_full_rank_six_role', ...
            'representation_parity_with_all_six_not_new_information', ...
        'mcmc_runs_performed',0, ...
        'missing_cells_retained_explicitly',true);
    utils.atomic_write_json(fullfile(cfg.paths.stage05, ...
        'analysis_scope.json'),scope,'AllowReplace',true);

    function write(T,name)
        utils.atomic_write_table(fullfile(tableRoot,name),T);
    end
end

function ensure_dirs(paths)
    for i=1:numel(paths),if ~isfolder(paths{i}),mkdir(paths{i});end,end
end
