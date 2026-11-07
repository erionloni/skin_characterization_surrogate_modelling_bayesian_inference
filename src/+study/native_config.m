function cfg = native_config(s, stepName, inputs, stepsInCall)
%NATIVE_CONFIG Configuration of one step that writes the publication layout.
%   CFG = study.native_config(S, STEP, INPUTS, STEPSINCALL) builds the
%   configuration of STEP from the settings S and the run context of the
%   call (study.project_config, study.config_arguments). Then it points
%     - the step's outputs at the analysis folders of the run folder
%       (<run>/<route>/<NN_analysis>/data, the layout of thesis_results/), and
%     - the step's inputs at INPUTS (struct array from study.resolve_input).
%   STEPSINCALL are the steps this call runs; like the pre-publication stages, a
%   call that runs a step reading held-out outcomes evaluates them. The
%   step's group (study.steps: fixed, generalized, screening, confirmation)
%   selects its folders.
%   Side effects: none.

    registry = study.steps(s.run.entry);
    r = registry(strcmp({registry.name}, stepName));
    involved = registry(ismember({registry.name}, stepsInCall));
    context = run_context(s, any([involved.readsHeldOut]), ...
        ismember('surrogate_audit', stepsInCall));
    posteriorStep = strcmp(s.run.entry, 'fixed') && ...
        ismember(stepName, {'inversion', 'conditional_inversion', 'recovery', 'design_study', ...
        'ratio_error_curves', 'combinations', 'gp_mean_inversion'});
    if strcmp(stepName, 'conditional_inversion')
        context.runConditionalInversion = true;
    end
    campaign = study.inversion_campaign(s.paths.run);
    if posteriorStep && ~strcmp(stepName, 'inversion') && ~isempty(campaign)
        % The steps after the inversion analyse the cases of this run's
        % campaign (study.run refused a 'Cases' list that differs).
        context.inversionCaseIDs = campaign.caseIDs;
    end
    overrides = {};
    if ~strcmp(s.run.entry, 'fixed') && ~ismember(stepName, {'dataset', 'surrogates'})
        % The approved generalized package (settings B.3): the dataset,
        % GP and PCE of the shipped results with the calibration of the
        % settings. The dataset step builds a dataset from the source data
        % instead, and the refit fits its own models
        % (surrogates.fit_generalized refuses to fit on the package).
        overrides = {'BindGeneralizedPackage', true};
    end
    if posteriorStep
        % The inversion cohort is resolved from the dataset the step
        % reads (this run's or the shipped one), as study.project_config resolves
        % it in the pre-publication layout.
        overrides = {'DatasetFile', inputs(strcmp({inputs.key}, 'dataset')).path};
    end
    campaignStep = strcmp(r.group, 'confirmation') && ...
        ismember(stepName, {'prepare', 'run_cells', 'compare'});
    if campaignStep
        % The configuration of the confirmation campaign, with the options
        % the pre-publication stage set. It runs in any MATLAB/UQLab
        % environment.
        overrides = [overrides, {'Resume', true, 'RunSurrogateQualityAudit', false, ...
            'RunStage9BScreening', false, 'RunStage9BAIESConfirmation', true, ...
            'EvaluateExternalHoldout', false}];
    end
    args = study.config_arguments(context, r.stage, overrides{:});
    cfg = study.project_config(s, args{:});
    switch r.group
        case 'fixed'
            cfg = fixed_layout(cfg, s.paths.run);
        case 'generalized'
            cfg = generalized_layout(cfg, s.paths.run, stepName);
        case 'screening'
            cfg = screening_layout(cfg, s);
        case 'confirmation'
            cfg = confirmation_layout(cfg, s, inputs);
            if strcmp(stepName, 'combinations')
                cfg = confirmation_combinations_layout(cfg, s);
            end
    end
    fields = struct('dataset', 'dataset', 'gp', 'gp', 'pce', 'pce', 'validation', 'validation', ...
        'validation_predictions', 'validationPredictions', ...
        'local_information', 'screeningLocalInformation', ...
        'full_covariance', 'screeningFullCovariance', ...
        'rankings', 'screeningRankings', ...
        'observations', 'confirmationObservations');
    for i = 1:numel(inputs)
        cfg.files.(fields.(inputs(i).key)) = inputs(i).path;
    end
    if strcmp(s.run.entry, 'fixed') && strcmp(stepName, 'surrogate_audit')
        % The development/external role manifest lies next to the dataset
        % that the audit reads (this run's or the shipped one).
        cfg.files.methodologicalRoleManifest = fullfile(fileparts(cfg.files.dataset), ...
            'development_external_role_manifest.csv');
    end
    if strcmp(s.run.entry, 'generalized') && strcmp(stepName, 'surrogates')
        % The refit reads the dataset's gate record next to its dataset
        % (metadata/stage1 of this run's or the shipped 01_dataset/data),
        % fits the outputs of this call, and limits its GP optimizations
        % when a demonstration budget is set.
        cfg.paths.stage01 = fileparts(cfg.files.dataset);
        cfg.native = struct('surrogateOutputs', s.advanced.surrogateOutputs);
        if ~isempty(s.advanced.demonstrationGPIterations)
            cfg.gp.demonstrationIterations = s.advanced.demonstrationGPIterations;
        end
    end
    if posteriorStep
        cfg = fixed_posterior_layout(cfg, s, stepName);
    end
end

function cfg = fixed_posterior_layout(cfg, s, stepName)
%FIXED_POSTERIOR_LAYOUT Folders of the inversion and of the steps that read its posteriors.
%   Every such step works on the inversion campaign of this run, in
%   <run>/_run/inversion: the pre-publication names below it, without the
%   cohort folder of that layout (Windows paths are limited to 260
%   characters). The inversion keeps its bookkeeping there and writes its
%   results in the layout of thesis_results/ to <run>/fixed/04_inversion/data
%   (study.write_inversion_results); a second call continues the campaign
%   (cfg.resume). Recovery and design study read the certified posteriors of
%   that campaign when this run has one; otherwise the full draws of both
%   replicates shipped in thesis_results/ (cfg.native.shippedDraws,
%   study.reads_shipped_draws). They write the data
%   folder of their analysis, <run>/fixed/<NN>/data, with every cell that
%   has a selected provider (certified, or a healthy fallback of the shipped
%   draws); the references they record are relative to the run. The
%   conditional inversion compares with the all_six cells of the finalized
%   inversion campaign of this run, or, without one, with the shipped ones
%   (cfg.native.shippedDraws), and runs the cells cfg.native.conditionalCells.
%   The GP-mean inversion keeps its campaign in
%   <run>/_run/inversion/gp_mean_inversion, runs the cells
%   cfg.native.gpMeanCells, writes its results to
%   <run>/fixed/09_gp_mean_inversion/data and compares them with the
%   shipped canonical cells (cfg.native.results, thesis_results/).
    assert(logical(cfg.inversion.cohortResolved), 'study:native_config:InversionCohort', ...
        'The inversion cohort did not resolve from the dataset %s.', cfg.files.dataset);
    cfg = study.reroot(cfg, cfg.paths.stage04, fullfile(s.paths.run, '_run', 'inversion'));
    switch stepName
        case {'inversion', 'conditional_inversion'}
            cfg.resume = true;
            cfg.paths.inversionResults = fullfile(s.paths.run, 'fixed', '04_inversion', 'data');
            cfg.paths.conditionalResults = fullfile(s.paths.run, 'fixed', ...
                '07_conditional_inversion', 'data');
            if ~isempty(s.advanced.demonstrationSteps)
                % Demonstration chain lengths (inversion.sampler_request_config).
                cfg.mcmc.demonstrationSteps = s.advanced.demonstrationSteps;
            end
            cfg.native = struct('run', s.paths.run, 'inversionCells', ...
                s.advanced.inversionCells, 'partialCampaign', s.advanced.partialCampaign, ...
                'conditionalCells', s.advanced.conditionalCells);
            if strcmp(stepName, 'conditional_inversion') && ~isfile(fullfile(s.paths.run, ...
                    '_run', 'inversion', 'inversion_campaign.mat'))
                % No finalized inversion campaign in this run: the canonical
                % all_six cells (the baselines) are the shipped ones.
                cfg.native.shippedDraws = struct('results', s.paths.results, ...
                    'certifiedOnly', false);
            end
        case 'recovery'
            cfg = study.reroot(cfg, cfg.paths.stage05, ...
                fullfile(s.paths.run, 'fixed', '05_recovery', 'data'));
            % The second-mode check compares with the parameter combinations
            % of this run when a call before computed them.
            cfg.paths.combinations = fullfile(s.paths.run, 'fixed', '05_recovery', 'data', 'combinations');
            cfg = posterior_source(cfg, s);
        case 'design_study'
            cfg = study.reroot(cfg, cfg.paths.stage06, ...
                fullfile(s.paths.run, 'fixed', '06_design_study', 'data'));
            cfg = posterior_source(cfg, s);
        case 'ratio_error_curves'
            cfg.paths.ratioErrorCurves = fullfile(s.paths.run, 'fixed', '08_ratio_error_curves', 'data');
            cfg = posterior_source(cfg, s);
        case 'combinations'
            cfg.paths.combinations = fullfile(s.paths.run, 'fixed', '05_recovery', 'data', 'combinations');
            cfg = posterior_source(cfg, s);
        case 'gp_mean_inversion'
            % Its campaign in <run>/_run/inversion/gp_mean_inversion
            % (cfg.paths.gpMeanInversion), its results in the layout of
            % thesis_results/; the shipped results give the seeds used
            % before and the canonical cells it is compared with.
            cfg.resume = true;
            cfg.paths.gpMeanResults = fullfile(s.paths.run, 'fixed', '09_gp_mean_inversion', 'data');
            if ~isempty(s.advanced.demonstrationSteps)
                cfg.mcmc.demonstrationSteps = s.advanced.demonstrationSteps;
            end
            cfg.native = struct('run', s.paths.run, 'gpMeanCells', s.advanced.gpMeanCells, ...
                'partialCampaign', s.advanced.partialCampaign, 'results', s.paths.results);
    end
    if ismember(stepName, {'conditional_inversion', 'recovery', 'design_study', 'ratio_error_curves', ...
            'combinations', 'gp_mean_inversion'})
        cfg.paths.runRoot = s.paths.run;
    end
end

function cfg = posterior_source(cfg, s)
%POSTERIOR_SOURCE The posteriors of recovery, the design study, the ratio-error curves and the parameter combinations.
%   The run's own inversion campaign when the run holds one
%   (study.run_has_inversion; a call that runs the inversion before these
%   steps has created it); otherwise the full draws shipped in
%   thesis_results/: the certified providers and the healthy fallbacks (the
%   design study summarizes the certified ones alone as well,
%   study.steps.fixed_design_study, with certifiedOnly set).
    if ~study.run_has_inversion(s)
        cfg.native.shippedDraws = struct('results', s.paths.results, ...
            'certifiedOnly', false);
    end
end

function cfg = screening_layout(cfg, s)
%SCREENING_LAYOUT Folders and model sources of the protocol screening steps.
%   The screen and the six-objective supplement go to
%   <run>/generalized/05_protocol_screening/data/{screen,six_objective}, as
%   in thesis_results/. The provider (study.screening_provider) reads the recorded
%   sources of the approved package (provider_sources).
    base = fullfile(s.paths.run, 'generalized', '05_protocol_screening', 'data');
    cfg.native = struct('run', s.paths.run, 'screenRoot', fullfile(base, 'screen'), ...
        'supplementRoot', fullfile(base, 'six_objective'), ...
        'screeningCandidates', s.advanced.screeningCandidates, ...
        'screeningMaterials', s.advanced.screeningMaterials, 'providerSources', provider_sources(s));
end

function cfg = confirmation_layout(cfg, s, inputs)
%CONFIRMATION_LAYOUT Folders and inputs of the confirmation steps.
%   The design is that of the settings (B.7, confirmation.confirmation_design);
%   with the protocols 'from_screening' it reads the screening rankings of
%   this run, or those of the shipped results (input 'rankings'). The
%   accepted observations are those this run imported, or the table of the
%   setting generalized.confirmation.observations (input 'observations').
%   The model provider is that of the screening steps
%   (study.screening_provider). The design is written to
%   <run>/generalized/06_confirmation/data/design; the accepted observations
%   to <run>/generalized/06_confirmation/data/observations. The campaign
%   (preparation, task table, request trees, cell outcomes, summaries) is
%   kept in <run>/_run/confirmation; the step compare copies its compact
%   tier to <run>/generalized/06_confirmation/data/campaign.
%   Demonstration chain lengths ('DemonstrationSteps') enter the
%   configuration of the step prepare, which writes them into the campaign's
%   configurations: the cells run with the chains of their campaign.
    campaignRoot = fullfile(s.paths.run, '_run', 'confirmation');
    for key = {'observations', 'rankings'}
        given = inputs(strcmp({inputs.key}, key{1}));
        if isempty(given), continue; end
        cfg.stage9bConfirmation.([key{1} 'File']) = given.path;
    end
    if ~isempty(s.advanced.demonstrationSteps)
        % Demonstration chain lengths (inversion.sampler_request_config).
        cfg.mcmc.demonstrationSteps = s.advanced.demonstrationSteps;
    end
    cfg.paths.stage09bProtocolConfirmation = campaignRoot;
    cfg.native = struct('run', s.paths.run, 'providerSources', provider_sources(s), ...
        'designRoot', fullfile(s.paths.run, 'generalized', '06_confirmation', 'data', 'design'), ...
        'observationFiles', s.advanced.confirmationObservationFiles, ...
        'observationsRoot', fullfile(s.paths.run, 'generalized', '06_confirmation', 'data', ...
            'observations'), ...
        'campaignRoot', campaignRoot, 'confirmationCells', s.advanced.confirmationCells);
end

function cfg = confirmation_combinations_layout(cfg, s)
%CONFIRMATION_COMBINATIONS_LAYOUT The draws that the confirmation's parameter combinations read, and their folder.
%   The confirmation of this run when it has one (its step compare completed,
%   or wrote the draws in this call): <run>/generalized/06_confirmation/data;
%   otherwise the shipped results' (thesis_results/generalized/
%   06_confirmation/data). The combinations go to
%   <run>/generalized/06_confirmation/data/combinations.
    own = fullfile(s.paths.run, 'generalized', '06_confirmation', 'data');
    source = fullfile(s.paths.results, 'generalized', '06_confirmation', 'data');
    if ~isempty(study.run_record('step', s.paths.run, 'generalized', 'compare')) || ...
            isfile(fullfile(own, 'draws', 'index.csv'))
        source = own;
    end
    cfg.native.combinationsSource = source;
    cfg.paths.confirmationCombinations = fullfile(own, 'combinations');
end

function sources = provider_sources(s)
%PROVIDER_SOURCES Recorded records of the approved package read by the model provider.
%   The dataset result and the calibration application record of the
%   approved generalized package, at their fixed locations in the shipped
%   results (screening.generalized_provider, native mode).
    shipped = fullfile(s.paths.results, 'generalized');
    sources = struct( ...
        'stage1Result', fullfile(shipped, '01_dataset', 'data', 'metadata', 'dataset_result.json'), ...
        'application', fullfile(shipped, '02_surrogates', 'data', 'assessment', ...
            'emulator_error_calibration_application.json'));
end

function context = run_context(s, readsHeldOut, runAudit)
%RUN_CONTEXT What the call decides about a step's configuration (study.config_arguments).
%   The route, the run root, whether the run resumes, which steps of the
%   call read held-out outcomes or run the audit, and the call's explicit
%   inversion cases ('Cases'); every scientific value comes from the
%   settings (study.project_config).
    route = 'real';
    if ~strcmp(s.run.entry, 'fixed'), route = 'real_extended'; end
    context = struct( ...
        'route', route, ...
        'runRoot', study.work_run_root(s), ...
        'resume', isfolder(fullfile(s.paths.run, s.run.entry)), ...
        'runSurrogateQualityAudit', runAudit, ...
        'evaluateExternalHoldout', readsHeldOut, ...
        'inversionCaseIDs', zeros(1, 0), ...
        'runConditionalInversion', false);
    if strcmp(route, 'real') && ~isempty(s.advanced.cases)
        context.inversionCaseIDs = reshape(double(s.advanced.cases), 1, []);
    end
end

function cfg = generalized_layout(cfg, run, stepName)
%GENERALIZED_LAYOUT Outputs of a generalized step bound to the approved package.
%   Paths the generalized code records are relative to the run folder, so
%   they name the publication layout; the stage folders below
%   <run>/_run/work keep the step's bookkeeping (computation-time figures,
%   integrity manifests).
    cfg.paths.runRoot = run;
    switch stepName
        case 'dataset'
            % The stage's data/ level is lifted, as in thesis_results/:
            % stage01_dataset/data/X is data/X, stage01_dataset/<folder>/X is
            % data/<folder>/X.
            d1 = fullfile(run, 'generalized', '01_dataset', 'data');
            p = cfg.realExtended.paths;
            p.data = d1;
            p.registries = fullfile(d1, 'registries');
            p.processed = fullfile(d1, 'processed');
            p.splits = fullfile(d1, 'splits');
            p.exclusions = fullfile(d1, 'exclusions');
            p.results = d1;
            p.reports = fullfile(d1, 'metadata');
            cfg.realExtended.paths = p;
            cfg.files.dataset = fullfile(d1, 'dataset.mat');
            cfg.paths.datasetMetadata = fullfile(d1, 'metadata');
            cfg.files.methodologicalRoleManifest = ...
                fullfile(d1, 'metadata', 'development_external_role_manifest.csv');
        case 'surrogates'
            % The refit writes its ensembles, resolvers and tables where
            % thesis_results/ has them; per-output checkpoints, candidate fits,
            % progress, logs and the stage report are bookkeeping, kept in
            % <run>/_run/surrogates (a short path: the candidate fits are
            % nested deeply, and Windows limits paths to 260 characters).
            d2 = fullfile(run, 'generalized', '02_surrogates', 'data');
            cfg.paths.results = d2;
            cfg.paths.surrogateWork = fullfile(run, '_run', 'surrogates');
            cfg.paths.reports = fullfile(cfg.paths.surrogateWork, 'metadata');
            cfg.files.gp = fullfile(d2, 'models', 'gp_surrogate.mat');
            cfg.files.pce = fullfile(d2, 'models', 'pce_surrogate.mat');
            % Written by the step surrogate_assessment; the stage checks that
            % it lies inside the folders the refit may write.
            cfg.files.validation = fullfile(d2, 'assessment', 'surrogate_validation.mat');
        case 'surrogate_assessment'
            assessment = fullfile(run, 'generalized', '02_surrogates', 'data', 'assessment');
            cfg.paths.surrogateAssessment = assessment;
            cfg.files.validation = fullfile(assessment, 'surrogate_validation.mat');
            cfg.files.internalHeldoutEvaluationStatus = ...
                fullfile(assessment, 'internal_heldout_evaluation_status.json');
        case 'default_protocol_comparison'
            d4 = fullfile(run, 'generalized', '04_default_protocol_comparison', 'data');
            cfg.paths.defaultProtocolCrossRoute = d4;
            cfg.files.defaultProtocolCrossRouteStatus = ...
                fullfile(d4, 'default_protocol_comparison_status.json');
        case 'sensitivity'
            d3 = fullfile(run, 'generalized', '03_sensitivity', 'data');
            cfg.paths.results = d3;
            cfg.paths.reports = fullfile(d3, 'metadata');
            cfg.paths.sensitivityTables = d3;
            cfg.files.sensitivity = fullfile(d3, 'sensitivity.mat');
        case 'feature_sensitivity'
            cfg.paths.featureSensitivity = fullfile(run, 'generalized', '03_sensitivity', 'data', 'features');
        case 'feature_accuracy'
            cfg.paths.featureAccuracy = fullfile(run, 'generalized', '02_surrogates', 'data', 'feature_accuracy');
        otherwise
            error('study:native_config:NotNative', ...
                'Generalized step %s does not run natively yet.', stepName);
    end
end

function cfg = fixed_layout(cfg, run)
%FIXED_LAYOUT Outputs of the fixed dataset, surrogate and sensitivity steps.
%   The same files and names as thesis_results/fixed.
    d1 = fullfile(run, 'fixed', '01_dataset', 'data');
    d2 = fullfile(run, 'fixed', '02_surrogates', 'data');
    d3 = fullfile(run, 'fixed', '03_sensitivity', 'data');
    assessment = fullfile(d2, 'assessment');
    cfg.files.dataset = fullfile(d1, 'dataset.mat');
    cfg.paths.datasetMetadata = d1;
    cfg.files.methodologicalRoleManifest = fullfile(d1, 'development_external_role_manifest.csv');
    cfg.files.gp = fullfile(d2, 'models', 'gp_surrogate.mat');
    cfg.files.pce = fullfile(d2, 'models', 'pce_surrogate.mat');
    cfg.files.outputTrainingContract = fullfile(d2, 'output_training_contract.mat');
    cfg.files.outputTrainingCohorts = fullfile(d2, 'output_training_cohorts.csv');
    cfg.paths.surrogateAssessment = assessment;
    cfg.files.validation = fullfile(assessment, 'surrogate_validation.mat');
    cfg.files.externalHoldoutStatus = fullfile(assessment, 'external_holdout_evaluation_status.json');
    cfg.paths.sensitivityTables = d3;
    cfg.files.sensitivity = fullfile(d3, 'sensitivity.mat');
    cfg.paths.featureSensitivity = fullfile(d3, 'features');
    cfg.paths.featureAccuracy = fullfile(d2, 'feature_accuracy');
    % The development audit (step surrogate_audit), as in thesis_results/.
    cfg.paths.surrogateQualityAudit = fullfile(d2, 'audit');
    cfg.files.surrogateQualityAuditStatus = fullfile(d2, 'audit', 'status', ...
        'surrogate_quality_audit_status.json');
end
