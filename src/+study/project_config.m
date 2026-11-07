function cfg = project_config(s, varargin)
%PROJECT_CONFIG The configuration that the analysis code reads, derived from the settings.
%   CFG = study.project_config(S, NAME, VALUE, ...) derives, from the
%   validated settings S (study_settings.m, study.resolve_settings), the
%   configuration of one step: every scientific value comes from S; this
%   function adds only what follows from them (paths below the run, the
%   expanded structures the analysis code reads, the frozen records the
%   settings select, loaded and checked) and the labels that describe the
%   implementation (schema, algorithm and semantics versions).
%
%   The name-value arguments describe the step's run, not a choice
%   (study.config_arguments builds them from the call):
%     Route            'real' (the fixed route) or 'real_extended' (the
%                      generalized route)
%     RunRoot          the run root of the configuration (study.work_run_root)
%     Stage            the configuration section of the step (0-7)
%     Resume           reuse the finished parts of the run (false)
%     DatasetFile      the dataset MAT the step reads (this run's or the shipped one)
%     BindGeneralizedPackage   true: the step uses the approved generalized
%                      package (the dataset, GP and PCE of the shipped
%                      results; the steps after the dataset and the refit)
%     GeneralizedRetryAttempt   retry attempt of a failed generalized fit (0)
%     InversionCaseIDs the run's explicit inversion cases ('Cases'; empty:
%                      the settings' cases)
%     RunSurrogateQualityAudit, EvaluateExternalHoldout,
%     RunConditionalInversion, RunStage9BScreening,
%     RunStage9BAIESConfirmation
%                      the steps of the call (study.native_config)
%   Side effects: none (reads the records the settings select).

    root = study.root();
    parser = inputParser;
    parser.FunctionName = 'study.project_config';
    addParameter(parser, 'Route', 'real', @text_scalar);
    addParameter(parser, 'RunRoot', '', @text_scalar);
    addParameter(parser, 'DatasetFile', '', @text_scalar);
    addParameter(parser, 'BindGeneralizedPackage', false, @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'GeneralizedRetryAttempt', 0, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x == fix(x) && x >= 0);
    addParameter(parser, 'Stage', 0, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x == fix(x) && x >= 0 && x <= 7);
    addParameter(parser, 'Resume', false, @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'RunSurrogateQualityAudit', false, @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'RunStage9BScreening', false, @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'RunStage9BAIESConfirmation', false, @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'EvaluateExternalHoldout', true, @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'InversionCaseIDs', [], @case_id_vector);
    addParameter(parser, 'RunConditionalInversion', false, @(x) islogical(x) && isscalar(x));
    parse(parser, varargin{:});
    o = parser.Results;
    F = s.fixed;
    G = s.generalized;

    %% Seeds (settings 0.6)
    cfg.seed = double(s.seeds.master);
    cfg.seeds.folder = repository_path(root, s.seeds.folder);
    cfg.seeds.tables = s.seeds.tables;
    cfg.seeds.rules = s.seeds.rules;
    % Labels of the implementation (they describe the code, not a choice).
    cfg.scientificVersion = 'direct_mcmc_publication_v5_partial_output_dynamic_cohorts';
    cfg.diagnosticVersion = 'aies_replicate_distribution_reproducibility_v2';
    cfg.ratioTransformVersion = 'ratio_full_delta_cov_v2';
    cfg.physicsGuidedFullRankSix.transformVersion = ...
        'physics_guided_full_rank_six_full_delta_cov_v1';

    cfg.dataMode = lower(strtrim(char(string(o.Route))));
    cfg.validDataModes = {'real', 'real_extended'};
    assert(ismember(cfg.dataMode, cfg.validDataModes), 'project_config:UnknownRoute', ...
        'Route must be real or real_extended, not "%s".', cfg.dataMode);
    fixedRoute = strcmp(cfg.dataMode, 'real');
    cfg.resume = o.Resume;
    cfg.currentStage = double(o.Stage);
    cfg.parallelWorkers = double(s.compute.parallelWorkers);

    %% Data, parameters and measurement (settings A.1, A.2, B.1, B.2)
    cfg.outputNames = reshape(cellstr(F.dataset.outputColumns), 1, []);
    cfg.realData.inputCols = reshape(cellstr(F.dataset.inputColumns), 1, []);
    cfg.realData.outputCols = cfg.outputNames;
    cfg.realData.groupCol = char(F.dataset.groupColumn);
    cfg.realData.k0Col = 0;
    if ~isempty(F.dataset.logColumn)
        cfg.realData.k0Col = find(strcmp(cfg.realData.inputCols, F.dataset.logColumn));
        assert(isscalar(cfg.realData.k0Col), 'project_config:LogColumn', ...
            'setting fixed.dataset.logColumn (%s) is not one of fixed.dataset.inputColumns.', ...
            F.dataset.logColumn);
    end
    cfg.realData.trainFraction = double(F.dataset.developmentFraction);
    cfg.realData.validationFraction = double(F.dataset.externalFraction);
    assert(abs(cfg.realData.trainFraction + cfg.realData.validationFraction - 1) < 1e-12, ...
        'project_config:SplitFractions', ['settings fixed.dataset.developmentFraction and ' ...
        'fixed.dataset.externalFraction must sum to 1.']);
    cfg.realData.splitSeed = cfg.seed;
    cfg.realData.preferredExternalCaseIDs = reshape(double(F.dataset.preferredExternalCases), 1, []);
    cfg.realData.dataContractVersion = 'complete_partial_six_output_v1';
    cfg.realData.splitAlgorithmVersion = 'complete_case_constrained_mt19937_v2';
    if fixedRoute
        cfg.paramNames = reshape(cellstr(F.parameters.names), 1, []);
        cfg.paramUnits = reshape(cellstr(F.parameters.units), 1, []);
        cfg.paramBounds = double(F.parameters.bounds);
        cfg.meas_cv = double(F.measurement.cv);
        cfg.likelihood.minSigma = double(F.measurement.minimumSigma);
    else
        cfg.paramNames = reshape(cellstr(G.parameters.names), 1, []);
        cfg.paramUnits = reshape(cellstr(G.parameters.units), 1, []);
        cfg.paramBounds = double(G.parameters.bounds);
        cfg.meas_cv = double(G.measurement.cv);
        cfg.likelihood.minSigma = double(G.measurement.minimumSigma);
    end
    cfg.likelihood.implementationVersion = ...
        'routeR_gaussian_likelihood_v5_tempered_diagonal_full_rank_transform';

    %% The inversion (settings A.6)
    cfg.ratios.num = reshape(double(F.inversion.ratioNumerators), 1, []);
    cfg.ratios.den = reshape(double(F.inversion.ratioDenominators), 1, []);
    cfg.ratios.denFloor = double(F.inversion.ratioDenominatorFloor);
    cfg.physicsGuidedFullRankSix.denominatorFloor = cfg.ratios.denFloor;
    cfg.physicsGuidedFullRankSix.featureNames = { ...
        'p3_D2', 'p3_D2_over_p1_D2', 'p1_D2_minus_p2_D2', ...
        'p1_D2_over_p3_D6', 'p3_D6_over_p1_D6', 'p2_D6_over_p1_D6'};
    cfg.physicsGuidedFullRankSix.scientificRole = ...
        'full_rank_representation_check_not_new_measurement_information';
    cfg.inversion.activeScenarioTags = expand(F.inversion.scenarios, ...
        {'measurement_plus_gp', 'gp_only', 'gp_self_det'});
    cfg.inversion.designNames = expand(F.inversion.designs, {'all_six', 'd2_only', 'd6_only', ...
        'cycle_1_only', 'ratios_only', 'physics_guided_full_rank_six'});
    % The warning diagnostics' degenerate R-hat (a health note, left out of the figures).
    cfg.inversion.degenerateRhat = double(F.inversion.diagnostics.degenerateRhat);
    % The canonical cases of the settings; a call's explicit 'Cases' replace
    % them (data.resolve_inversion_cohort).
    cases = F.inversion.cases;
    if ischar(cases) || isstring(cases)
        cfg.inversion.defaultAnchorCaseIDs = zeros(1, 0);
        cfg.inversion.allExternalCases = true;
    else
        cfg.inversion.defaultAnchorCaseIDs = reshape(double(cases), 1, []);
        cfg.inversion.allExternalCases = false;
    end
    cfg.inversion.defaultCaseCount = numel(cfg.inversion.defaultAnchorCaseIDs);
    explicit = reshape(double(o.InversionCaseIDs), 1, []);
    cfg.inversion.requestedCaseCount = cfg.inversion.defaultCaseCount;
    if ~isempty(explicit), cfg.inversion.requestedCaseCount = numel(explicit); end
    cfg.inversion.explicitCaseIDs = explicit;
    if ~isempty(explicit)
        assert(numel(unique(explicit)) == numel(explicit), 'project_config:InversionCaseIDs', ...
            'InversionCaseIDs must be unique.');
        cfg.inversion.caseIDs = explicit;
    else
        cfg.inversion.caseIDs = cfg.inversion.defaultAnchorCaseIDs;
    end
    cfg.inversion.cohortResolved = false;
    cfg.inversion.cohortSelectionMode = 'unresolved_until_stage01_dataset';
    cfg.inversion.expectedCellCount = numel(cfg.inversion.caseIDs) * ...
        numel(cfg.inversion.activeScenarioTags) * numel(cfg.inversion.designNames);

    %% The conditional inversion (settings A.9)
    % The conditions with their masks and the campaign's (scenario,
    % condition) pairs, checked against A.1 and A.6 (study.conditional_design).
    C = F.conditionalInversion;
    design = study.conditional_design(C, cfg.paramNames, intersect(cfg.inversion.activeScenarioTags, ...
        {'measurement_plus_gp', 'gp_only'}, 'stable'));
    cfg.conditionalInversion.enabled = logical(o.RunConditionalInversion);
    cfg.conditionalInversion.studyVersion = 'oracle_truth_conditioning_all_six_v1';
    cfg.conditionalInversion.design = char(C.design);
    cfg.conditionalInversion.conditions = design.conditions;
    cfg.conditionalInversion.referenceCode = design.reference;
    cfg.conditionalInversion.schedule = design.schedule;
    cfg.conditionalInversion.caseSelection = C.cases;
    cfg.conditionalInversion.caseIDs = conditional_cases(C.cases, cfg.inversion.caseIDs);
    cfg.conditionalInversion.baselineStatuses = reshape(cellstr(C.baselineStatuses), 1, []);
    cfg.conditionalInversion.reuseShippedCells = logical(C.reuseShippedCells);
    cfg.conditionalInversion.expectedNewCellCount = numel(design.schedule) * ...
        numel(cfg.conditionalInversion.caseIDs);

    %% The GP-mean inversion (settings A.13)
    % The scenario gp_mean_det (inversion.scenario_registry) on the cases
    % selected among those of the inversion, design all_six.
    GM = F.gpMeanInversion;
    cfg.gpMeanInversion.scenario = 'gp_mean_det';
    cfg.gpMeanInversion.design = char(GM.design);
    cfg.gpMeanInversion.caseSelection = GM.cases;
    cfg.gpMeanInversion.caseIDs = gp_mean_cases(GM.cases, cfg.inversion.caseIDs);
    cfg.gpMeanInversion.showcaseCase = double(GM.showcaseCase);
    cfg.gpMeanInversion.comparisonScenarios = {'measurement_plus_gp', 'gp_only', 'gp_self_det'};
    % The best fit's search (inversion.gp_mean_best_fit), as the settings give it.
    cfg.gpMeanInversion.bestFit = GM.bestFit;
    cfg.gpMeanInversion.bestFit.starts = reshape(double(GM.bestFit.starts), 1, []);

    %% Recovery (settings A.7)
    E = F.recovery.eigendecomposition;
    % The analyses of the step recovery, as the run switches select them (0.2).
    cfg.analysis.runCoverageRecovery = logical(s.run.fixed.coverage_recovery);
    cfg.analysis.runPosteriorCovarianceEigendecomposition = logical(s.run.fixed.eigen_analysis);
    eigenScenarios = expand(E.scenarios, cfg.inversion.activeScenarioTags);
    cfg.analysis.posteriorEigendecomposition = struct( ...
        'schemaVersion', 'posterior_covariance_eigendecomposition_policy_v1', ...
        'caseIDs', cfg.inversion.caseIDs, ...
        'design', char(E.design), ...
        'scenarios', {eigenScenarios}, ...
        'excludedScenarios', {setdiff(cfg.inversion.activeScenarioTags, eigenScenarios, 'stable')}, ...
        'parameterNames', {reshape(cellstr(F.parameters.names), 1, [])}, ...
        'expectedCellCount', numel(eigenScenarios) * numel(cfg.inversion.caseIDs), ...
        'nearDegenerateGapThreshold', double(E.nearDegenerateGapThreshold), ...
        'negativeEigenvalueTolerance', double(E.negativeEigenvalueTolerance), ...
        'symmetryTolerance', double(E.symmetryTolerance), ...
        'divisionFloor', double(E.divisionFloor), ...
        'primaryPosteriorSemantics', 'certified_AIES_replicate_1_shortest_accepted_level', ...
        'replicate2Semantics', 'same_accepted_level_warning_only_never_recertify', ...
        'poolingPermitted', false, ...
        'automaticPosteriorGenerationPermitted', false);
    [found, weakPair] = ismember(E.weakPair, F.parameters.names);
    assert(all(found), 'project_config:WeakPair', ...
        'setting fixed.recovery.eigendecomposition.weakPair names parameters outside fixed.parameters.names.');
    cfg.analysis.weakPairIndices = reshape(weakPair, 1, []);
    R = F.recovery.featureReconstruction;
    cfg.analysis.runFeatureReconstructionAnalysis = logical(s.run.fixed.feature_reconstruction) && fixedRoute;
    cfg.analysis.runDownstreamErrorBudget = logical(s.run.fixed.error_budget) && fixedRoute;
    cfg.analysis.runSecondModeCheck = logical(s.run.fixed.second_mode_check) && fixedRoute;
    M = F.recovery.secondModeCheck;
    cfg.analysis.secondModeCheck = struct('caseID', double(M.caseID), 'scenario', char(M.scenario), ...
        'design', char(M.design), 'groupDistance', double(M.groupDistance), ...
        'pathPoints', double(M.pathPoints), 'neighbourhood', double(M.neighbourhood), ...
        'shareScenarios', {reshape(cellstr(M.shareScenarios), 1, [])}, ...
        'directionScenario', char(M.directionScenario), 'comsolNeighbours', double(M.comsolNeighbours), ...
        'gpEvaluationBatchSize', double(s.compute.posteriorBatchSize), ...
        'optimizer', struct('algorithm', char(M.optimizer.algorithm), ...
            'optimalityTolerance', double(M.optimizer.optimalityTolerance), ...
            'stepTolerance', double(M.optimizer.stepTolerance), ...
            'maxIterations', double(M.optimizer.maxIterations), ...
            'maxFunctionEvaluations', double(M.optimizer.maxFunctionEvaluations)), ...
        'classification', struct('exactDistance', double(M.classification.exactDistance), ...
            'exactLogLikelihood', double(M.classification.exactLogLikelihood), ...
            'nearDelta', double(M.classification.nearDelta)));
    B = F.recovery.boundSensitivity;
    cfg.analysis.boundSensitivity = struct('cases', reshape(double(B.cases), 1, []), ...
        'scenario', char(B.scenario), 'design', char(B.design));
    % The shared definitions of the derived features (settings 0.7,
    % features.definitions) and the ratio-error curves (A.11).
    cfg.features = struct('referenceCV', double(s.features.referenceCV), ...
        'catalog', {s.features.catalog}, 'unstableTailShare', double(s.features.unstableTailShare));
    % The feature accuracy: its bootstrap, the gridded outputs and the output
    % time step (0.7); the default protocol's rate (B.1): the rate of the
    % fixed route and the boundary of the generalized route's rate subsets.
    FA = s.features.accuracy;
    cfg.features.accuracy = struct('bootstrapResamples', double(FA.bootstrapResamples), ...
        'bootstrapSeed', double(FA.bootstrapSeed), 'griddedOutputs', {cellstr(string(FA.griddedOutputs))}, ...
        'outputTimeStep', double(FA.outputTimeStep), ...
        'defaultRate', abs(double(s.generalized.defaultProtocol.suctionRate)));
    C = F.ratioErrorCurves;
    cfg.analysis.runRatioErrorCurves = logical(s.run.fixed.ratio_error_curves) && fixedRoute;
    cfg.analysis.ratioErrorCurves = struct('scenario', char(C.scenario), 'design', char(C.design), ...
        'cases', {C.cases}, 'supplementCases', {C.supplementCases}, ...
        'supplementScenario', char(C.supplementScenario), 'bins', double(C.bins), ...
        'quantiles', reshape(double(C.quantiles), 1, []), ...
        'gpEvaluationBatchSize', double(s.compute.posteriorBatchSize));
    % The parameter combinations (A.12).
    M6 = F.combinations;
    cfg.analysis.combinations = struct('cases', {M6.cases}, ...
        'scenarios', {reshape(cellstr(string(M6.scenarios)), 1, [])}, 'design', char(M6.design), ...
        'priorSampleSize', double(M6.priorSampleSize), 'priorSampleSeed', double(M6.priorSampleSeed), ...
        'logForm', struct('parameters', {reshape(cellstr(string(M6.logForm.parameters)), 1, [])}, ...
            'quantile', double(M6.logForm.quantile), 'rangeShare', double(M6.logForm.rangeShare)), ...
        'labelFactor', double(M6.labelFactor));
    % The parameter combinations of the confirmation (B.8).
    M8 = s.generalized.combinations;
    cfg.analysis.confirmationCombinations = struct('designs', {M8.designs}, ...
        'priorSampleSize', double(M8.priorSampleSize), 'priorSampleSeed', double(M8.priorSampleSeed), ...
        'logForm', struct('parameters', {reshape(cellstr(string(M8.logForm.parameters)), 1, [])}, ...
            'quantile', double(M8.logForm.quantile), 'rangeShare', double(M8.logForm.rangeShare)), ...
        'labelFactor', double(M8.labelFactor));
    reconstructionScenarios = expand(R.scenarios, cfg.inversion.activeScenarioTags);
    cfg.analysis.featureReconstruction = struct( ...
        'schemaVersion', 'feature_reconstruction_policy_v1', ...
        'caseIDs', cfg.inversion.caseIDs, ...
        'fittingDesigns', {cfg.inversion.designNames}, ...
        'scenarios', {reconstructionScenarios}, ...
        'excludedScenarios', {setdiff(cfg.inversion.activeScenarioTags, ...
            reconstructionScenarios, 'stable')}, ...
        'activeEvaluationSpaces', {cfg.inversion.designNames}, ...
        'diagnosticEvaluationSpaces', {reshape(cellstr(R.diagnosticSpaces), 1, [])}, ...
        'expectedPosteriorCellCount', numel(reconstructionScenarios) * ...
            numel(cfg.inversion.designNames) * numel(cfg.inversion.caseIDs), ...
        'validationCohortSize', NaN, ...
        'expectedCoreMatrixSize', [6 6], ...
        'expectedExpandedMatrixSize', [6 9], ...
        'normalizationDefinition', 'fixed_truth_range_over_complete_external_test_cohort', ...
        'nearZeroRangeTolerance', double(R.nearZeroRangeTolerance), ...
        'denominatorFloor', cfg.ratios.denFloor, ...
        'gpEvaluationBatchSize', double(s.compute.posteriorBatchSize), ...
        'latentResponseSemantics', 'deterministic_GP_mean_at_each_retained_posterior_draw', ...
        'measurementNoiseDrawsAdded', false, ...
        'posteriorPoolingPermitted', false, ...
        'automaticPosteriorGenerationPermitted', false, ...
        'surrogateOnlyReferenceIsInversionRow', false);

    %% Surrogates and sensitivity (settings A.3-A.5, B.3)
    if fixedRoute
        cfg.gp = gp_settings(root, F.surrogates, 'fixed');
    else
        cfg.gp = gp_settings(root, G.surrogates, 'generalized');
    end
    if fixedRoute
        calibrationFile = repository_path(root, F.surrogates.emulatorCalibration);
    else
        calibrationFile = repository_path(root, G.surrogates.emulatorCalibration);
    end
    cfg.paths.emulatorErrorCalibration = calibrationFile;
    if fixedRoute
        cfg.emulatorErrorCalibration = surrogates.load_emulator_error_calibration( ...
            cfg.paths.emulatorErrorCalibration, 'ExpectedOutputOrder', cfg.outputNames);
        check_calibration_gp(cfg.emulatorErrorCalibration, cfg.gp, ...
            'project_config:EmulatorCalibrationGPContract', 'A.3', ...
            'fixed.surrogates.emulatorCalibration');
        cfg.inversion.emulatorErrorCalibrationVersion = ...
            cfg.emulatorErrorCalibration.variance_formula_version;
    else
        cfg.emulatorErrorCalibration = struct();
        cfg.inversion.emulatorErrorCalibrationVersion = 'not_applicable';
    end
    cfg.pce.method = char(F.surrogates.pce.method);
    cfg.pce.degrees = reshape(double(F.surrogates.pce.degrees), 1, []);
    cfg.pce.q_norm = double(F.surrogates.pce.qNorm);
    if ~fixedRoute
        cfg.pce.method = char(G.surrogates.pce.method);
        cfg.pce.degrees = [reshape(double(G.surrogates.pce.initialDegrees), 1, []), ...
            reshape(double(G.surrogates.pce.escalationDegrees), 1, [])];
        cfg.pce.q_norm = double(G.surrogates.pce.qNorm);
        % The staged degree search of a generalized PCE refit
        % (surrogates.generalized_pce_policy) and the GP folds.
        cfg.pce.initialDegrees = reshape(double(G.surrogates.pce.initialDegrees), 1, []);
        cfg.pce.escalationDegrees = reshape(double(G.surrogates.pce.escalationDegrees), 1, []);
        cfg.pce.cvFolds = double(G.surrogates.pce.folds);
        cfg.pce.adequateMeanCVNRMSE = double(G.surrogates.pce.adequateMeanNRMSE);
        cfg.pce.adequateMaxFoldNRMSE = double(G.surrogates.pce.adequateMaxFoldNRMSE);
        cfg.gp.cvFolds = double(G.surrogates.gpFolds);
    end
    cfg.N_sobol = double(F.sensitivity.sobolSamples);
    cfg.sobol.order = double(F.sensitivity.sobolOrder);
    if ~fixedRoute
        % The generalized route's own order (B.4); its sample size is the
        % stage-3 policy's (realExtended.stage3.sobolSampleSize).
        cfg.sobol.order = double(G.sensitivity.sobolOrder);
    end
    cfg.sobol.consistencyTol = double(F.sensitivity.consistencyTolerance);
    cfg.stage9.bootstrapReplicates = double(F.designStudy.bootstrapReplicates);
    cfg.stage9.ratioValidationDraws = double(F.designStudy.ratioValidationDraws);
    cfg.stage9.ratioValidationTolerance = double(F.designStudy.ratioValidationTolerance);
    cfg.stage9.finiteDifferenceStep = double(F.designStudy.finiteDifferenceStep);
    cfg.stage9.finiteDifferenceCheckSteps = reshape(double(F.designStudy.finiteDifferenceCheckSteps), 1, []);
    cfg.stage2.runSurrogateQualityAudit = logical(o.RunSurrogateQualityAudit);
    cfg.stage9bScreening = struct('enabled', logical(o.RunStage9BScreening));
    cfg.stage9bConfirmation = struct('enabled', logical(o.RunStage9BAIESConfirmation));
    cfg.stage2.evaluateExternalHoldout = logical(o.EvaluateExternalHoldout);
    A = F.surrogateAudit;
    cfg.surrogateQualityAudit = struct( ...
        'schemaVersion', 'surrogate_development_quality_audit_policy_v2', ...
        'kernels', {reshape(cellstr(A.kernels), 1, [])}, ...
        'sameDataKernels', {reshape(cellstr(A.sameDataKernels), 1, [])}, ...
        'optimizer', cfg.gp.optim_method, ...
        'nugget', cfg.gp.nugget, ...
        'trend', char(A.trend), ...
        'correlation', char(A.correlation), ...
        'inputScaling', 'UQLab_internal_normalized_input_coordinates', ...
        'sameDataReplicates', double(A.sameDataReplicates), ...
        'crossValidationRepeats', double(A.crossValidationRepeats), ...
        'crossValidationFolds', double(A.crossValidationFolds), ...
        'seedScheduleVersion', 'paired_gp_development_audit_schedule_v2', ...
        'foldAssignmentVersion', 'caseid_unit_random_permutation_cyclic_assignment_v1', ...
        'metricVersion', 'surrogate_quality_metrics_v2_sd_standardized', ...
        'probeDesignVersion', 'centered_latin_hypercube_bounds_v1', ...
        'probePointCount', double(A.probePointCount), ...
        'trainingConvergenceRepeats', double(A.trainingConvergenceRepeats), ...
        'trainingConvergenceValidationCount', double(A.trainingConvergenceValidationCount), ...
        'trainingConvergencePoolCount', double(A.trainingConvergencePoolCount), ...
        'trainingConvergenceSizes', reshape(double(A.trainingConvergenceSizes), 1, []), ...
        'calibrationFolds', double(A.calibrationFolds), ...
        'calibrationFoldVersion', 'caseid_grouped_five_fold_v1', ...
        'varianceCandidates', {{'raw_uqlab', 'constant_oof', 'full_local_shape', ...
            'tempered_local_shape'}}, ...
        'gammaGrid', reshape(double(A.gammaGrid), 1, []), ...
        'gammaObjectiveVersion', 'caseid_balanced_equal_output_gaussian_working_objective_v1', ...
        'localShapeBinCount', double(A.localShapeBinCount), ...
        'clusterBootstrapReplicates', double(A.clusterBootstrapReplicates), ...
        'clusterBootstrapVersion', 'caseid_cluster_bootstrap_v1', ...
        'residualCorrelationBootstrapReplicates', double(A.residualCorrelationBootstrapReplicates), ...
        'residualTailCount', double(A.residualTailCount), ...
        'varianceFactorizationTolerance', double(A.varianceFactorizationTolerance), ...
        'residualCorrelationEstimator', 'caseid_aggregated_analytic_shrinkage_to_identity_v1', ...
        'predictiveVarianceSafeguard', 'sigma_raw=sqrt(max(variance,0)); sigma_safe=max(sigma_raw,eps)', ...
        'comparisonTolerance', double(A.comparisonTolerance), ...
        'relativeDenominatorTolerance', double(A.relativeDenominatorTolerance), ...
        'rangeTolerance', double(A.rangeTolerance), ...
        'intervalLevels', reshape(double(A.intervalLevels), 1, []), ...
        'pairDifferenceOrientation', 'Matern-3_2_minus_Matern-5_2', ...
        'tiePolicy', 'abs(diff)<=comparisonTolerance*max(1,abs(left),abs(right))');

    %% MCMC and certification (settings A.6; B.7 for the confirmation)
    if fixedRoute
        M = F.inversion.mcmc;
        T = F.inversion.certification;
    else
        M = G.confirmation.mcmc;
        T = G.confirmation.certification;
    end
    cfg.mcmc.levels = reshape(double(M.levels), 1, []);
    cfg.mcmc.burn_in = double(M.burnIn);
    cfg.mcmc.thinning = double(M.thinning);
    cfg.mcmc.initialization = char(M.initialization);
    cfg.mcmc.productionSampler = 'AIES';
    cfg.mcmc.productionReplicateIDs = reshape(double(M.replicates), 1, []);
    % The Adaptive Metropolis cross-check is not available in this version.
    cfg.mcmc.enableAdaptiveMetropolisValidation = false;
    cfg.mcmc.amValidationCaseIDs = zeros(1, 0);
    cfg.mcmc.amValidationStepCount = cfg.mcmc.levels(1);
    cfg.mcmc.amValidationReplicateID = 1;
    cfg.mcmc.continuationSemantics = 'fresh_total_length_rerun_new_seed_no_sample_pooling';
    cfg.mcmc.aies = struct('sampler', 'AIES', 'n_chains', double(M.walkers), ...
        'samplerOptions', struct('a', double(M.stretchScale)), ...
        'initialization', char(M.initialization));
    cfg.mcmc.adaptiveMetropolis = struct('sampler', 'AM', 'n_chains', 10, ...
        'samplerOptions', struct('Proposal', struct('PriorScale', 0.1), 'T0', 300, ...
        'Epsilon', 1e-6), 'initialization', 'latin_hypercube');
    % Aliases read by inversion.bayes_invert; each request replaces them with
    % its own sampler settings.
    cfg.mcmc.sampler = cfg.mcmc.aies.sampler;
    cfg.mcmc.samplerOptions = cfg.mcmc.aies.samplerOptions;
    cfg.mcmc.n_chains = cfg.mcmc.aies.n_chains;
    cfg.mcmc.n_steps = cfg.mcmc.levels(1);
    t = struct();
    for name = {'maxRankSplitRhat', 'minBulkESS', 'minTailESS', 'maxRelativeSdMCSE', ...
            'maxMedianRangeDifference', 'maxQuantileRangeDifference', ...
            'maxNormalizedWasserstein', 'correlationDifferenceWarning', ...
            'minIndependentReplicates', 'frozenMovementFraction', 'minimumUniqueStates', ...
            'duplicateSampleTolerance', 'maxDuplicateFraction'}
        t.(name{1}) = double(T.(name{1}));
    end
    cfg.mcmcDiagnostics.v2 = t;

    %% Figures (settings 0.4, A.10)
    cfg.fig.resolution = double(s.figures.resolution);
    cfg.fig.mode = char(s.figures.mode);
    % The per-case outputs: selections of cases, scenarios and designs; 'all'
    % stands for those of the inversion when they are drawn (study.case_outputs).
    cfg.fig.caseOutputs = F.caseOutputs;
    cfg.fig.generateCrossDesignComparisons = logical(s.figures.crossDesignComparisons);
    cfg.fig.generateAllPosteriorCornerPlots = strcmp(s.figures.cornerGallery, 'all');
    cfg.fig.thetaAtUpperBound = double(s.figures.thetaAtUpperBound);

    %% Paths below the run root
    cfg.paths.root = root;
    runRoot = strtrim(char(string(o.RunRoot)));
    assert(~isempty(runRoot), 'project_config:RunRoot', ...
        'The run root of the configuration is missing (study.work_run_root).');
    cfg.paths.runRoot = canonical_or_absolute(runRoot);
    cfg.paths.outputRoot = output_root_from_run(cfg.paths.runRoot, cfg.dataMode);
    [~, cfg.runID] = fileparts(cfg.paths.runRoot);
    cfg = stage_paths(cfg);

    cfg.realData.csv = repository_path(root, F.dataset.file);
    cfg.files.dataset = fullfile(cfg.paths.stage01, 'data', dataset_file_name(cfg.dataMode));
    datasetFile = strtrim(char(string(o.DatasetFile)));
    if ~isempty(datasetFile)
        cfg.files.dataset = canonical_or_absolute(datasetFile);
    end
    % The dataset, surrogate and sensitivity steps never read external
    % outcomes; the inversion cohort is resolved from the dataset for the
    % inversion and the steps after it.
    if fixedRoute && cfg.currentStage >= 4 && isfile(cfg.files.dataset)
        cfg = resolved_cohort(cfg);
    end
    cfg = file_names(cfg);
    if ~fixedRoute
        cfg = generalized_configuration(cfg, root, s);
        cfg.realExtended.stage2RetryAttempt = double(o.GeneralizedRetryAttempt);
        if o.BindGeneralizedPackage, cfg = bind_generalized_package(cfg, s, root); end
    end
end

function cfg = bind_generalized_package(cfg, s, root)
%BIND_GENERALIZED_PACKAGE The approved generalized package of the shipped results (settings B.3).
%   The generalized steps after the dataset and the refit use the approved
%   dataset, GP and PCE of thesis_results/generalized (their locations:
%   study.artifacts) with the calibration of the settings: CFG.files points
%   at them, the configuration's dataset folder is the shipped one, and
%   CFG.realExtended.packageBound says so. A surrogate audit cannot run on
%   the package, and the dataset step and the refit never bind it.
    assert(~cfg.stage2.runSurrogateQualityAudit, 'project_config:PackageAudit', ...
        'The approved package is used as it is; a surrogate audit cannot run with it.');
    results = repository_path(root, s.paths.results);
    A = study.artifacts('generalized');
    files = struct();
    for key = {'dataset', 'gp', 'pce'}
        a = A(strcmp({A.key}, key{1}));
        files.(key{1}) = fullfile(results, strrep(a.path, '/', filesep));
        assert(isfile(files.(key{1})), 'project_config:PackageMissing', ...
            ['The approved generalized %s is missing: %s. Restore thesis_results/ from the ' ...
             'repository (setting paths.results).'], key{1}, files.(key{1}));
    end
    cfg.files.dataset = files.dataset;
    cfg.files.gp = files.gp;
    cfg.files.pce = files.pce;
    % The configuration's dataset folder is the shipped one, where the
    % dataset step's data/ level is lifted (data/X is stored as X).
    stage1Root = fileparts(files.dataset);
    fields = fieldnames(cfg.realExtended.paths);
    for i = 1:numel(fields)
        value = cfg.realExtended.paths.(fields{i});
        if ischar(value) && startsWith(value, cfg.paths.stage01)
            suffix = regexprep(value(numel(cfg.paths.stage01) + 1:end), '^[\\/]data(?=[\\/]|$)', '');
            cfg.realExtended.paths.(fields{i}) = [stage1Root suffix];
        end
    end
    cfg.realExtended.packageBound = true;
end

function gp = gp_settings(root, S, route)
%GP_SETTINGS The GP of the route (settings A.3, B.3).
%   'use_shipped' and 'refit_audit_selected': the configuration the audit
%   selected, from its records: the fixed route's decision record; the
%   generalized fit policy (kernel, multi-start rule of outputs 1 and 3) and
%   the approved calibration (trend, correlation, optimizer and nugget of the
%   approved GP). 'refit_manual': the manual settings, optionally with fixed
%   length scales (fixedTheta; a GP without a nugget only).
    gp = struct();
    switch S.modelSource
        case {'use_shipped', 'refit_audit_selected'}
            if strcmp(route, 'fixed')
                record = jsondecode(fileread(repository_path(root, S.auditSelection)));
                gp.kernel = char(record.decision.gp_kernel);
                gp.trend = char(record.decision.gp_trend);
                gp.correlation = char(record.decision.gp_correlation_type);
                gp.optim_method = char(record.decision.gp_optimizer);
                gp.nugget = double(record.decision.gp_nugget);
            else
                gp.generalizedFitPolicy = surrogates.load_gp_fit_policy( ...
                    repository_path(root, S.fitPolicy));
                approved = jsondecode(fileread(repository_path(root, S.emulatorCalibration)));
                gp.kernel = gp.generalizedFitPolicy.kernel;
                gp.trend = char(approved.trend);
                gp.correlation = char(approved.correlation_type);
                gp.optim_method = char(approved.optimizer);
                gp.nugget = double(approved.nugget);
            end
            gp.fixedTheta = [];
        otherwise
            gp.kernel = char(S.manual.kernel);
            gp.trend = char(S.manual.trend);
            gp.correlation = char(S.manual.correlation);
            gp.optim_method = char(S.manual.optimizer);
            gp.nugget = double(S.manual.nugget);
            gp.fixedTheta = double(S.manual.fixedTheta);
            % UQLab 2.3 fits a GP with a nugget of at least eps as a GP
            % regression and always optimizes its hyperparameters (the
            % length scales and the GP variance).
            section = 'A.3';
            if strcmp(route, 'generalized'), section = 'B.3'; end
            assert(isempty(gp.fixedTheta) || gp.nugget < eps, 'project_config:FixedTheta', ...
                ['setting %s.surrogates.manual.fixedTheta (section %s) needs a GP without a ' ...
                 'nugget (manual.nugget 0): UQLab fits a GP with a nugget as a GP regression, ' ...
                 'whose hyperparameters it always optimizes.'], route, section);
    end
    gp.modelSource = char(S.modelSource);
end

function check_calibration_gp(calibration, gp, id, section, setting)
%CHECK_CALIBRATION_GP The emulator calibration was fitted for the configured GP.
%   A calibration holds for the GP it was fitted for: its kernel, trend,
%   correlation, optimizer and nugget are those of the settings (the thesis
%   GP, or a manual one with its own calibration).
    fitted = {char(calibration.kernel), char(calibration.trend), ...
        char(calibration.correlation_type), char(calibration.optimizer)};
    configured = {gp.kernel, gp.trend, gp.correlation, gp.optim_method};
    assert(isequal(fitted, configured) && double(calibration.nugget) == gp.nugget, id, ...
        ['The emulator-error calibration %s was fitted for the GP with kernel %s, trend %s, ' ...
         'correlation %s, optimizer %s and nugget %g; the settings configure kernel %s, ' ...
         'trend %s, correlation %s, optimizer %s and nugget %g (%s). A GP with other ' ...
         'values needs a calibration fitted for it (setting %s).'], calibration.artifact_path, ...
        fitted{:}, double(calibration.nugget), configured{:}, gp.nugget, section, setting);
end

function names = expand(selection, all)
%EXPAND A selection of the settings: a list (in the order of ALL) or 'all'.
    if ischar(selection) || isstring(selection)
        names = reshape(cellstr(all), 1, []);
    else
        names = reshape(cellstr(selection), 1, []);
    end
end

function p = repository_path(root, p)
%REPOSITORY_PATH A path of the settings: absolute as given, otherwise below the repository.
    p = char(string(p));
    if ~(startsWith(p, filesep) || ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\'))
        p = fullfile(root, strrep(p, '/', filesep));
    end
    p = canonical_or_absolute(p);
end

function tf = text_scalar(value)
    tf = ischar(value) || (isstring(value) && isscalar(value));
end

function tf = case_id_vector(value)
    tf = isnumeric(value) && (isempty(value) || isvector(value)) && ...
        all(isfinite(value)) && all(value == fix(value));
end

function value = canonical_or_absolute(value)
    value = char(string(value));
    file = javaObject('java.io.File', value);
    if ~file.isAbsolute(), file = javaObject('java.io.File', pwd, value); end
    value = char(file.getCanonicalPath());
end

function cfg = stage_paths(cfg)
%STAGE_PATHS The folders below the run root that the analysis code writes and reads.
%   A step of the publication layout points the ones it writes at
%   <run>/<route>/<NN_analysis>/data (study.native_config).
    p = cfg.paths;
    p.stage01 = fullfile(p.runRoot, 'stage01_dataset');
    p.stage02 = fullfile(p.runRoot, 'stage02_surrogates');
    p.stage03 = fullfile(p.runRoot, 'stage03_sensitivity');
    p.stage04 = fullfile(p.runRoot, 'stage04_inversion');
    p.stage05 = fullfile(p.runRoot, 'stage05_coverage_recovery');
    p.stage06 = fullfile(p.runRoot, 'stage06_stage9a_oed');
    p.stage07 = fullfile(p.runRoot, 'stage07_figures');
    p.datasetMetadata = fullfile(p.stage01, 'metadata');
    p.surrogateAssessment = fullfile(p.stage02, 'validation');
    p.sensitivityTables = fullfile(p.stage03, 'tables');
    % Figures the generalized dataset and sensitivity draw while they compute.
    p.datasetFigures = fullfile(p.stage01, 'figures');
    p.sensitivityFigures = fullfile(p.stage03, 'figures');
    % Per-output checkpoints, candidate fits, progress and logs of the
    % generalized surrogate fits (empty = inside the stage's results folder).
    p.surrogateWork = '';
    p.stage04Base = p.stage04;
    p.stage05Base = p.stage05;
    p.stage06Base = p.stage06;
    p.stage07Base = p.stage07;
    p.stage09bProtocolOED = fullfile(p.runRoot, 'stage09b_protocol_oed');
    p.stage09bProtocolConfirmation = fullfile(p.runRoot, 'stage09b_protocol_confirmation');
    p.conditionalInversion = fullfile(p.stage04, 'conditional_inversion');
    p.gpMeanInversion = fullfile(p.stage04, 'gp_mean_inversion');
    p.posteriorEigendecomposition = fullfile(p.stage05, 'eigen_analysis');
    p.featureReconstruction = fullfile(p.stage05, 'feature_reconstruction');
    p.secondModeCheck = fullfile(p.stage05, 'second_mode_check');
    p.ratioErrorCurves = fullfile(p.runRoot, 'ratio_error_curves');
    p.featureSensitivity = fullfile(p.runRoot, 'feature_sensitivity');
    p.featureAccuracy = fullfile(p.runRoot, 'feature_accuracy');
    p.combinations = fullfile(p.runRoot, 'combinations');
    p.surrogateQualityAudit = fullfile(p.stage02, 'surrogate_quality_audit');
    p.defaultProtocolCrossRoute = fullfile(p.stage02, 'default_protocol_cross_route');
    p.downstreamErrorBudget = fullfile(p.featureReconstruction, 'error_budget');
    p.logs = fullfile(p.runRoot, 'logs');
    p.data = fullfile(p.stage01, 'data');
    p.currentStage = stage_root(p, cfg.currentStage);
    p.results = stage_results_root(p, cfg.currentStage);
    p.figures = fullfile(p.currentStage, 'figures');
    p.reports = fullfile(p.currentStage, 'metadata');
    cfg.paths = p;
end

function cfg = resolved_cohort(cfg)
%RESOLVED_COHORT The inversion cohort resolved from the dataset, and what follows from it.
    cohort = data.resolve_inversion_cohort(cfg);
    cfg.inversion.caseIDs = cohort.caseIDs;
    cfg.inversion.cohortResolved = true;
    cfg.inversion.cohortSelectionMode = cohort.selectionMode;
    cfg.inversion.expectedCellCount = numel(cohort.caseIDs) * ...
        numel(cfg.inversion.activeScenarioTags) * numel(cfg.inversion.designNames);
    cfg.conditionalInversion.caseIDs = conditional_cases(cfg.conditionalInversion.caseSelection, ...
        cohort.caseIDs);
    cfg.conditionalInversion.expectedNewCellCount = numel(cfg.conditionalInversion.schedule) * ...
        numel(cfg.conditionalInversion.caseIDs);
    cfg.gpMeanInversion.caseIDs = gp_mean_cases(cfg.gpMeanInversion.caseSelection, cohort.caseIDs);
    E = cfg.analysis.posteriorEigendecomposition;
    E.caseIDs = cohort.caseIDs;
    E.expectedCellCount = numel(E.scenarios) * numel(cohort.caseIDs);
    cfg.analysis.posteriorEigendecomposition = E;
    R = cfg.analysis.featureReconstruction;
    R.caseIDs = cohort.caseIDs;
    R.expectedPosteriorCellCount = numel(R.scenarios) * numel(R.fittingDesigns) * numel(cohort.caseIDs);
    loadedCounts = utils.load_plain_mat(cfg.files.dataset, 'counts');
    if isfield(loadedCounts, 'counts') && isfield(loadedCounts.counts, 'externalTestCases')
        R.validationCohortSize = double(loadedCounts.counts.externalTestCases);
    end
    cfg.analysis.featureReconstruction = R;
    cohortFolder = sprintf('cohort_%d_cases', numel(cohort.caseIDs));
    p = cfg.paths;
    p.stage04 = fullfile(p.stage04Base, 'cohorts', cohortFolder);
    p.stage05 = fullfile(p.stage05Base, 'cohorts', cohortFolder);
    p.stage06 = fullfile(p.stage06Base, 'cohorts', cohortFolder);
    p.stage07 = fullfile(p.stage07Base, 'cohorts', cohortFolder);
    p.conditionalInversion = fullfile(p.stage04, 'conditional_inversion');
    p.gpMeanInversion = fullfile(p.stage04, 'gp_mean_inversion');
    p.posteriorEigendecomposition = fullfile(p.stage05, 'eigen_analysis');
    p.featureReconstruction = fullfile(p.stage05, 'feature_reconstruction');
    p.secondModeCheck = fullfile(p.stage05, 'second_mode_check');
    p.downstreamErrorBudget = fullfile(p.featureReconstruction, 'error_budget');
    p.currentStage = stage_root(p, cfg.currentStage);
    p.results = stage_results_root(p, cfg.currentStage);
    p.figures = fullfile(p.currentStage, 'figures');
    p.reports = fullfile(p.currentStage, 'metadata');
    cfg.paths = p;
end

function ids = conditional_cases(selection, cohort)
%CONDITIONAL_CASES The cases of the conditional inversion: the inversion's cases, or the selected ones among them.
%   SELECTION is 'all' or CaseIDs (A.9); COHORT the CaseIDs of the
%   inversion. A selected case that is not a case of the inversion is
%   refused (a condition fixes parameters at the case's synthetic truth);
%   the order is the inversion's. An unresolved cohort (empty) is checked
%   once it is resolved.
    cohort = reshape(double(cohort), 1, []);
    if ischar(selection) || isstring(selection)
        ids = cohort;
        return;
    end
    selection = reshape(double(selection), 1, []);
    outside = setdiff(selection, cohort, 'stable');
    if ~isempty(cohort) && ~isempty(outside)
        error('study:settings:ConditionalCases', ...
            ['setting fixed.conditionalInversion.cases (section A.9 of the settings file): case %d is ' ...
             'not a case of the inversion (%s); a condition fixes parameters at the synthetic truth of ' ...
             'a case of the inversion. Select cases of the inversion, or ''all''.'], outside(1), ...
            mat2str(cohort));
    end
    ids = cohort(ismember(cohort, selection));
end

function ids = gp_mean_cases(selection, cohort)
%GP_MEAN_CASES The cases of the GP-mean inversion: the inversion's cases, or the selected ones among them.
%   SELECTION is 'all' or CaseIDs (A.13); COHORT the CaseIDs of the
%   inversion. A selected case that is not a case of the inversion is
%   refused (its observation and truth are those of the inversion's
%   cases); the order is the inversion's. An unresolved cohort (empty) is
%   checked once it is resolved.
    cohort = reshape(double(cohort), 1, []);
    if ischar(selection) || isstring(selection)
        ids = cohort;
        return;
    end
    selection = reshape(double(selection), 1, []);
    outside = setdiff(selection, cohort, 'stable');
    if ~isempty(cohort) && ~isempty(outside)
        error('study:settings:GPMeanCases', ...
            ['setting fixed.gpMeanInversion.cases (section A.13 of the settings file): case %d is ' ...
             'not a case of the inversion (%s). Select cases of the inversion, or ''all''.'], ...
            outside(1), mat2str(cohort));
    end
    ids = cohort(ismember(cohort, selection));
end

function cfg = file_names(cfg)
%FILE_NAMES The files that the analysis code writes and reads, below the stage folders.
    p = cfg.paths;
    f = cfg.files;
    f.gp = fullfile(p.stage02, 'models', 'gp_surrogate.mat');
    f.pce = fullfile(p.stage02, 'models', 'pce_surrogate.mat');
    f.validation = fullfile(p.surrogateAssessment, 'surrogate_validation.mat');
    f.outputTrainingContract = fullfile(p.stage02, 'metadata', 'output_training_contract.mat');
    f.outputTrainingCohorts = fullfile(p.stage02, 'metadata', 'output_training_cohorts.csv');
    f.externalHoldoutStatus = fullfile(p.surrogateAssessment, 'external_holdout_evaluation_status.json');
    f.internalHeldoutEvaluationStatus = fullfile(p.surrogateAssessment, ...
        'internal_heldout_evaluation_status.json');
    f.methodologicalRoleManifest = fullfile(p.datasetMetadata, 'development_external_role_manifest.csv');
    f.surrogateQualityAuditStatus = fullfile(p.surrogateQualityAudit, 'status', ...
        'surrogate_quality_audit_status.json');
    f.defaultProtocolCrossRouteStatus = fullfile(p.defaultProtocolCrossRoute, ...
        'default_protocol_comparison_status.json');
    f.sensitivity = fullfile(p.sensitivityTables, 'sensitivity.mat');
    f.inversionGrid = fullfile(p.stage04, 'grid.csv');
    f.certificationIndex = fullfile(p.stage04, 'certification', 'certification_index.csv');
    f.conditionalInversionGrid = fullfile(p.conditionalInversion, 'conditional_grid.csv');
    f.conditionalCertificationIndex = fullfile(p.conditionalInversion, 'certification', ...
        'conditional_certification_index.csv');
    f.conditionalComparison = fullfile(p.conditionalInversion, 'reports', ...
        'conditional_inversion_comparison.csv');
    f.conditionalAvailability = fullfile(p.conditionalInversion, 'reports', ...
        'conditional_inversion_availability.csv');
    f.conditionalMatchedCohorts = fullfile(p.conditionalInversion, 'reports', ...
        'conditional_inversion_matched_cohorts.csv');
    f.conditionalMatchedSummary = fullfile(p.conditionalInversion, 'reports', ...
        'conditional_inversion_matched_summary.csv');
    f.conditionalCampaign = fullfile(p.conditionalInversion, 'conditional_inversion_campaign.mat');
    f.conditionalStatus = fullfile(p.conditionalInversion, 'conditional_inversion_status.json');
    f.coverage = fullfile(p.stage05, 'tables', 'posterior_parameter_cells.csv');
    f.posteriorEigendirections = fullfile(p.posteriorEigendecomposition, 'posterior_eigendirections.csv');
    f.posteriorEigendecompositionAvailability = fullfile(p.posteriorEigendecomposition, 'availability.csv');
    f.posteriorEigendecompositionStatus = fullfile(p.posteriorEigendecomposition, ...
        'posterior_eigendecomposition_status.json');
    f.featureReconstructionLongForm = fullfile(p.featureReconstruction, 'reconstruction_long_form.csv');
    f.featureReconstructionRegistry = fullfile(p.featureReconstruction, 'feature_registry.csv');
    f.featureReconstructionPerFeatureSummary = fullfile(p.featureReconstruction, ...
        'reconstruction_per_feature_summary.csv');
    f.featureReconstructionMatrixSummary = fullfile(p.featureReconstruction, ...
        'reconstruction_matrix_summary.csv');
    f.featureReconstructionMaximumDeviation = fullfile(p.featureReconstruction, ...
        'maximum_deviation_summary.csv');
    f.featureReconstructionWorstFeaturePerCase = fullfile(p.featureReconstruction, ...
        'worst_feature_per_case.csv');
    f.featureReconstructionWorstFeatureFrequency = fullfile(p.featureReconstruction, ...
        'worst_feature_frequency.csv');
    f.featureReconstructionSurrogateOnlyReference = fullfile(p.featureReconstruction, ...
        'surrogate_only_reference.csv');
    f.featureReconstructionAvailability = fullfile(p.featureReconstruction, 'availability.csv');
    f.featureReconstructionMatchedCohorts = fullfile(p.featureReconstruction, 'matched_cohorts.csv');
    f.featureReconstructionStatus = fullfile(p.featureReconstruction, ...
        'feature_reconstruction_status.json');
    f.downstreamErrorBudgetStatus = fullfile(p.downstreamErrorBudget, 'downstream_error_budget_status.json');
    f.stage9 = fullfile(p.stage06, 'design_study.mat');
    f.stage9bScreeningStatus = fullfile(p.stage09bProtocolOED, 'status', 'screening_status.json');
    cfg.files = f;
end

function cfg = generalized_configuration(cfg, root, s)
%GENERALIZED_CONFIGURATION The generalized route: dataset, surrogates, sensitivity, screening, confirmation (settings B).
%   The dataset table and its snapshot come from the settings (B.1); no
%   property of the dataset is compiled into the code.
    G = s.generalized;
    cfg.realExtended.scientificVersion = 'real_extended_stage123_v2';
    % True once the approved package is bound (bind_generalized_package).
    cfg.realExtended.packageBound = false;
    cfg.realExtended.csv = repository_path(root, G.dataset.file);
    cfg.realExtended.snapshotID = char(string(G.dataset.snapshot));
    cfg.realExtended.stage4PlusEnabled = false;
    cfg.realExtended.learningInputNames = reshape(cellstr(G.parameters.names), 1, []);
    cfg.realExtended.outputNames = reshape(cellstr(G.dataset.outputColumns), 1, []);
    rate = double(G.defaultProtocol.suctionRate);
    cfg.realExtended.defaultProtocol = struct('suction_rate_kPa_s', rate, ...
        'log10_abs_suction_rate', log10(abs(rate)), 'hold_dur_s', double(G.defaultProtocol.holdSeconds), ...
        'pause_dur_s', double(G.defaultProtocol.pauseSeconds));
    cfg.realExtended.learningBounds = double(G.parameters.bounds);
    cfg.realExtended.authoritativePhysicalBounds = double(G.parameters.physicalBounds);
    cfg.realExtended.transformTolerance = double(G.dataset.transformTolerance);
    cfg.realExtended.monotonicToleranceMbar = double(G.dataset.monotonicToleranceMbar);
    cfg.realExtended.monotonicRuleVersion = 'strict_adjacent_cycle_drop_gt_zero_v1';
    cfg.realExtended.roundingScaleMbar = double(G.dataset.roundingScaleMbar);
    cfg.realExtended.monotonicReviewFraction = double(G.dataset.monotonicReviewFraction);
    cfg.realExtended.protocolAssociationSMD = double(G.dataset.protocolAssociationSMD);
    cfg.realExtended.testFraction = double(G.dataset.externalFraction);
    cfg.realExtended.splitSeed = cfg.seed;
    % The calibration of the approved GP (settings B.3); every step that
    % evaluates the GP's uncertainty reads it. Its contract (inputs, outputs,
    % snapshot, split seed) is checked when it is loaded, the GP it was
    % fitted for here.
    cfg.emulatorErrorCalibration = surrogates.load_generalized_emulator_calibration( ...
        cfg.paths.emulatorErrorCalibration, ...
        'ExpectedInputOrder', cfg.realExtended.learningInputNames, ...
        'ExpectedOutputOrder', cfg.realExtended.outputNames, ...
        'ExpectedSnapshot', cfg.realExtended.snapshotID, ...
        'ExpectedSplitSeed', cfg.realExtended.splitSeed);
    check_calibration_gp(cfg.emulatorErrorCalibration, cfg.gp, ...
        'project_config:ExtendedEmulatorCalibrationGPContract', 'B.3', ...
        'generalized.surrogates.emulatorCalibration');
    % The data pairing is checked where the calibration is applied
    % (surrogates.validate_generalized_calibration_data_contract).
    cfg.realExtended.emulatorErrorCalibrationVersion = ...
        cfg.emulatorErrorCalibration.variance_formula_version;
    cfg.inversion.emulatorErrorCalibrationVersion = cfg.realExtended.emulatorErrorCalibrationVersion;
    cfg.realExtended.defaultProtocolComparison = struct( ...
        'schemaVersion', 'real_extended_default_protocol_cross_route_policy_v2', ...
        'referenceRole', 'fixed_protocol_COMSOL_truth_consume_only', ...
        'referenceDatasetPath', cfg.realData.csv, ...
        'defaultProtocol', cfg.realExtended.defaultProtocol, ...
        'coordinateEqualityTolerance', cfg.realExtended.transformTolerance, ...
        'primaryCohort', 'fixed_reference_rows_without_exact_extended_training_overlap', ...
        'generalizedTrainingUnaffected', true, ...
        'generalizedCalibrationUnaffected', true, ...
        'automaticScientificInterpretation', false, ...
        'provenanceSource', char(G.defaultProtocolComparison.provenanceSource));
    cfg.realExtended.predictionBatchSize = double(s.compute.gpPredictionBatchSize);
    S3 = G.sensitivity;
    cfg.realExtended.stage3 = struct('schemaVersion', 'real_extended_stage3_policy_v2', ...
        'predictionBatchSize', cfg.realExtended.predictionBatchSize, ...
        'sobolSampleSize', double(S3.sobolSamples), ...
        'uqlabGreaterOrderBatchGuardVersion', 'uqlab23_unsafe_one_to_two_million_rows_guard_v1', ...
        'campaignBoundsAbsoluteTolerance', double(S3.campaignBoundsTolerance), ...
        'supportAuditSampleSize', double(S3.supportAuditSamples), ...
        'fixedSurrogateBootstrapEnabled', logical(S3.bootstrap.enabled), ...
        'fixedSurrogateBootstrapBaseSize', double(S3.bootstrap.baseSize), ...
        'fixedSurrogateBootstrapReplicates', double(S3.bootstrap.replicates), ...
        'fixedSurrogateBootstrapSeed', double(S3.bootstrap.seed), ...
        'supportAuditSeed', double(S3.supportAuditSeed), ...
        'refitReplicates', 0, ...
        'posteriorEnabled', false);
    names = cfg.realExtended.learningInputNames;
    SC = G.screening;
    cfg.stage9bScreening = struct( ...
        'schemaVersion', 'real_extended_stage9b_screening_policy_v1', ...
        'enabled', logical(cfg.stage9bScreening.enabled), ...
        'observationDesign', 'all_six', ...
        'materialParameterNames', {names(1:4)}, ...
        'protocolParameterNames', {names(5:7)}, ...
        'targetParameterNames', {reshape(cellstr(SC.targetParameters), 1, [])}, ...
        'targetParameterOrder', {reshape(cellstr(SC.targetParameters), 1, [])}, ...
        'protocolLevelCount', double(SC.protocolLevels), ...
        'protocolBounds', double(cfg.realExtended.learningBounds(5:7, :)), ...
        'defaultProtocol', cfg.realExtended.defaultProtocol, ...
        'candidateDuplicateTolerance', double(SC.candidateDuplicateTolerance), ...
        'materialPointCount', double(SC.materialPoints), ...
        'materialLHSSeed', double(SC.materialSeed), ...
        'materialLHSImplementation', 'utils.dispersed_initial_ensemble_latin_hypercube', ...
        'materialCoordinateSystem', 'independent_uniform_prior_sd', ...
        'finiteDifferenceStepUnitBox', double(SC.finiteDifferenceStep), ...
        'finiteDifferenceCoordinateSystem', 'normalized_unit_box', ...
        'finiteDifferenceMode', 'primary_step_only_batched_boundary_safe', ...
        'jacobianCoordinateSystem', 'independent_uniform_prior_sd', ...
        'covarianceCases', {reshape(cellstr(SC.covarianceCases), 1, [])}, ...
        'localInformationDefinition', 'local_mean_sensitivity_FIM_approximation', ...
        'covarianceProxyDefinition', 'inv(I4_plus_F)_via_cholesky_solves', ...
        'primaryMetric', 'MeanTargetProxyLambdaMax', ...
        'comparisonTolerance', double(SC.comparisonTolerance), ...
        'symmetryTolerance', double(SC.symmetryTolerance), ...
        'psdTolerance', double(SC.psdTolerance), ...
        'candidateBatchSize', double(s.compute.screeningBlockSize), ...
        'automaticScientificSelection', false, ...
        'confirmationActionImplemented', true);
    CF = G.confirmation;
    % The design (materials x protocols, confirmation.confirmation_design);
    % 'from_screening' reads the six-objective rankings of the shipped
    % screen (a run that ranks its own screen reads those,
    % study.native_config). The accepted observations are the setting's
    % table unless the run imports its own. The descriptive design of the
    % complete pairs is a second design, not the first one again.
    assert(isempty(CF.completePairsDesign) || ~strcmp(char(CF.completePairsDesign), char(CF.design)), ...
        'project_config:ConfirmationDesigns', ...
        ['generalized.confirmation.completePairsDesign (B.7) must differ from ' ...
         'generalized.confirmation.design (%s), or be '''' for none.'], char(CF.design));
    cfg.stage9bConfirmation = struct( ...
        'schemaVersion', 'real_extended_confirmation_policy_v3', ...
        'enabled', logical(cfg.stage9bConfirmation.enabled), ...
        'materials', CF.materials, ...
        'protocols', {CF.protocols}, ...
        'objectives', {reshape(cellstr(CF.objectives), 1, [])}, ...
        'observationsFile', repository_path(root, CF.observations), ...
        'rankingsFile', fullfile(repository_path(root, s.paths.results), 'generalized', ...
            '05_protocol_screening', 'data', 'six_objective', 'six_objective_rankings.csv'), ...
        'scenario', char(CF.scenario), ...
        'design', char(CF.design), ...
        'completePairsDesign', char(CF.completePairsDesign), ...
        'protocolRoles', {{'default', 'selected'}}, ...
        'targetParameterNames', {reshape(cellstr(CF.targetParameters), 1, [])}, ...
        'coordinateEqualityTolerance', double(CF.coordinateTolerance), ...
        'posteriorReconstructionBatchSize', double(s.compute.posteriorBatchSize), ...
        'maximumRepresentativeOverlayPairs', double(CF.overlayPairs), ...
        'showcase', CF.showcase);
    p = cfg.paths.stage01;
    cfg.realExtended.paths = struct( ...
        'data', fullfile(p, 'data'), ...
        'registries', fullfile(p, 'data', 'registries'), ...
        'processed', fullfile(p, 'data', 'processed'), ...
        'splits', fullfile(p, 'data', 'splits'), ...
        'exclusions', fullfile(p, 'data', 'exclusions'), ...
        'results', p, 'reports', fullfile(p, 'metadata'));
end

function value = stage_root(paths, stage)
    if stage >= 1 && stage <= 7
        value = paths.(sprintf('stage%02d', stage));
    else
        value = paths.runRoot;
    end
end

function value = stage_results_root(paths, stage)
    value = stage_root(paths, stage);
    if stage == 3, value = fullfile(value, 'tables'); end
end

function name = dataset_file_name(~)
    % Both routes name their dataset dataset.mat (the route folder tells them apart).
    name = 'dataset.mat';
end

function outputRoot = output_root_from_run(runRoot, route)
    [runsRoot, runID] = fileparts(runRoot);
    [routeRoot, runsName] = fileparts(runsRoot);
    [outputRoot, routeName] = fileparts(routeRoot);
    assert(~isempty(runID) && strcmp(runsName, 'runs') && strcmp(routeName, route), ...
        'project_config:RunRootLayout', 'RunRoot must have the form <OutputRoot>/%s/runs/<RunID>.', route);
    outputRoot = canonical_or_absolute(outputRoot);
end
