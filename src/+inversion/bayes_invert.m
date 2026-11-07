function R = bayes_invert(model, yObs, P, cfg, opts)
%BAYES_INVERT Bayesian inversion of one observation via UQLab MCMC.
%   R = BAYES_INVERT(model, yObs, P, cfg) recovers the posterior over the free
%   material parameters from a 1x6 observation using the trained GP surrogate
%   as the forward model and UQLab's Inversion module. The configured sampler
%   is either AIES or Adaptive Metropolis (AM). Sampler-aware R-hat and
%   effective sample size are reported; interacting AIES walkers are never
%   relabelled as chains.
%
%   R = BAYES_INVERT(..., opts) selects one of the three canonical uncertainty
%   modes through opts.uncertaintyMode: measurement_plus_gp, gp_only, or
%   numerical_floor_only.
%       opts.outputs  indices of the 6 outputs to condition on (default 1:6)
%       opts.observationTransform  'none' (default), 'ratios' (condition on
%                     the 4 cycle ratios), or
%                     'physics_guided_full_rank_six' (condition on the
%                     invertible 6-feature representation). Both nonlinear
%                     paths use full delta-method covariance and override
%                     opts.outputs.
%       opts.thetaTrue  1x4 truth, enables coverage diagnostics (default [])
%       opts.keepAnalysis  store the UQLab object in R.analysis (default false)
%       opts.parameterAdapter optional conditional-parameter adapter. The
%                     sampler and prior use only its free coordinates; every
%                     likelihood/predictive GP evaluation receives the
%                     reconstructed canonical four-vector.
%
%   The likelihood is always the explicit, normalized Gaussian implementation
%   in inversion.gp_log_likelihood, one uncertainty contract for every
%   scenario and design.
%
%   Key fields of R: postSample and sampleArray retain the actual sampler
%   dimension (four ordinarily; two or three for conditional requests).
%   canonicalPostSample always contains reconstructed canonical coordinates;
%   sampler-specific health is intentionally computed only in free dimensions.
%   Cell-level R-hat/ESS/MCSE and certification are computed only by the
%   cross-analysis reliability layer.
%   Side effects: creates the UQLab inversion analysis of the request in
%   the UQLab session; the caller seeds the random number generator.
%   Computation: minutes to an hour (one MCMC request; GP evaluations).

    if nargin < 5, opts = struct(); end
    opts = set_defaults(opts);

    validate_options(opts);
    validate_parameter_contract(P,opts);
    switch opts.observationTransform
        case 'ratios'
            % Condition on four ratios with full, heteroscedastic delta
            % covariance.
            opts.outputs=sort(unique([cfg.ratios.num,cfg.ratios.den]));
            yObsSub=ratio_transform(yObs,cfg);
        case 'physics_guided_full_rank_six'
            % This is an invertible re-expression of all six pressures, not
            % additional measurement information.
            opts.outputs=1:6;
            yObsSub=inversion.physics_guided_full_rank_values(yObs, ...
                inversion.physics_floor(cfg));
        otherwise
            yObsSub=yObs(opts.outputs);
    end

    Solver.Type        = 'MCMC';
    Solver.MCMC.Sampler = cfg.mcmc.sampler;
    Solver.MCMC.Steps   = cfg.mcmc.n_steps;
    Solver.MCMC.NChains = cfg.mcmc.n_chains;
    samplerSettings = utils.effective_sampler_settings(cfg.mcmc);
    switch upper(char(string(cfg.mcmc.sampler)))
        case 'AIES'
            Solver.MCMC.a = samplerSettings.a;
        case 'AM'
            Solver.MCMC.Proposal = samplerSettings.Proposal;
            Solver.MCMC.T0 = samplerSettings.T0;
            Solver.MCMC.Epsilon = samplerSettings.Epsilon;
        otherwise
            error('inversion:bayes_invert:UnsupportedSampler', ...
                'Only AIES and Adaptive Metropolis (AM) are supported; got "%s".', ...
                cfg.mcmc.sampler);
    end
    initialEnsemble = utils.dispersed_initial_ensemble(P.bounds, ...
        cfg.mcmc.n_chains, opts.initialization, opts.initializationParameters);
    % UQLab calls this coordinate array "Seed"; it is not the MATLAB RNG seed.
    Solver.MCMC.Seed = reshape(initialEnsemble.', 1, P.M, cfg.mcmc.n_chains);

    BayesOpts.Type   = 'Inversion';
    BayesOpts.Prior  = P.Input;
    BayesOpts.Data.y = yObsSub;
    BayesOpts.Solver = Solver;

    BayesOpts.LogLikelihood = @(params, data) ...
        inversion.gp_log_likelihood(params, data, model, cfg, opts);

    % A full grid creates at least two analyses per cell. Private analyses
    % prevent UQLab's session registry from retaining every completed object.
    analysis = uq_createAnalysis(BayesOpts,'-private');
    uq_postProcessInversion(analysis, 'burnIn', cfg.mcmc.burn_in, ...
        'gelmanRubin', false, 'pointEstimate', 'mean');

    R = summarise(analysis, P, cfg, opts);
    if opts.keepAnalysis
        R.analysis = analysis;
    end
end

% -------------------------------------------------------------------------
function opts = set_defaults(opts)
    d = struct('outputs', 1:6, ...
               'observationTransform', 'none', 'thetaTrue', [], 'keepAnalysis', false, ...
               'scenarioTag', '', 'observationSource', '', ...
               'uncertaintyMode', '', 'measurementCV', [], ...
               'emulatorErrorCalibrationVersion','', 'replicateID', 1, ...
               'continuationStage', 'pilot', 'initialization', 'latin_hypercube', ...
               'initializationParameters', struct(), ...
               'caseID', 'unspecified', 'seed', NaN, ...
               'parameterAdapter', struct([]));
    f = fieldnames(d);
    for k = 1:numel(f)
        if ~isfield(opts, f{k}) || isempty(opts.(f{k}))
            if ~strcmp(f{k}, 'thetaTrue'), opts.(f{k}) = d.(f{k}); end
        end
    end
    if ~isfield(opts, 'thetaTrue'), opts.thetaTrue = []; end
end

function validate_parameter_contract(P,opts)
    assert(isstruct(P)&&isscalar(P)&&all(isfield(P, ...
        {'names','bounds','M','Input','outputNames'}))&& ...
        isequal(size(P.bounds),[double(P.M) 2]), ...
        'inversion:bayes_invert:ParameterSpace', ...
        'P must be a complete sampler parameter-space record.');
    adapter=opts.parameterAdapter;
    if isempty(adapter)
        return;
    end
    required={'schemaVersion','samplerDimension', ...
        'canonicalDimension','freeParameterIndices','fixedParameterIndices', ...
        'freeBounds','canonicalTruth'};
    assert(isstruct(adapter)&&isscalar(adapter)&&all(isfield(adapter,required))&& ...
        strcmp(adapter.schemaVersion,'conditional_parameter_adapter_v1')&& ...
        double(adapter.samplerDimension)==double(P.M)&& ...
        double(adapter.canonicalDimension)==4&& ...
        isequal(double(adapter.freeBounds),double(P.bounds))&& ...
        isfield(P,'adapter')&&isequaln(P.adapter,adapter), ...
        'inversion:bayes_invert:ConditionalParameterSpace', ...
        'The reduced UQLab parameter space and conditional adapter disagree.');
    if ~isempty(opts.thetaTrue)
        truth=reshape(double(opts.thetaTrue),1,[]);
        assert(isequal(truth,reshape(double(adapter.canonicalTruth),1,[])), ...
            'inversion:bayes_invert:ConditionalTruth', ...
            'Conditional thetaTrue must be the adapter-bound canonical truth.');
    end
end

% -------------------------------------------------------------------------
function validate_options(opts)
%VALIDATE_OPTIONS Reject compatibility modes outside the publication contract.
    assert(ismember(opts.observationTransform, ...
        {'none','ratios','physics_guided_full_rank_six'}), ...
        'inversion:bayes_invert:ObservationTransform', ...
        ['Only raw subsets, the canonical ratio transform, and the ' ...
         'physics-guided full-rank six transform are supported.']);
    assert(ismember(opts.uncertaintyMode, ...
        {'measurement_plus_gp','gp_only','numerical_floor_only'}), ...
        'inversion:bayes_invert:UncertaintyMode', ...
        'A canonical direct-MCMC uncertainty mode is required.');
    scenario=inversion.scenario_registry(opts.scenarioTag);
    assert(strcmp(opts.uncertaintyMode,scenario.uncertaintyMode)&& ...
        strcmp(opts.observationSource,scenario.observationSource), ...
        'inversion:bayes_invert:ScenarioContract', ...
        'Scenario tag, observation source, and uncertainty mode disagree.');
end

% -------------------------------------------------------------------------
function r = ratio_transform(Y, cfg)
%RATIO_TRANSFORM Map raw closing pressures to the cfg.ratios cycle ratios.
    assert(isequal(cfg.ratios.num,[2 3 5 6]) && ...
        isequal(cfg.ratios.den,[1 1 4 4]), ...
        'inversion:bayes_invert:RatioDefinition', ...
        'Configured ratios differ from the central design-study operator.');
    r = design_study.ratio_values(Y,cfg.ratios.denFloor);
end

% -------------------------------------------------------------------------
function R = summarise(analysis, P, cfg, opts)
%SUMMARISE Collapse sampler states into posterior summaries.
    PP = analysis.Results.PostProc;
    S  = PP.PostSample;                       % [nIter x M x nChains]
    M  = size(S, 2);
    flat = reshape(permute(S, [1 3 2]), [], M);
    [canonicalFlat,parameterRecord]= ...
        inversion.canonical_likelihood_parameters(flat,opts);
    isConditional=logical(parameterRecord.conditional);

    R.postSample   = flat;
    R.freePostSample=flat;
    R.canonicalPostSample=canonicalFlat;
    R.sampleArray = S;
    R.rawSample = analysis.Results.Sample;
    R.logLikelihoodTrace = analysis.Results.LogLikeliEval;
    assert(isnumeric(R.logLikelihoodTrace)&&~isempty(R.logLikelihoodTrace)&& ...
        all(isfinite(R.logLikelihoodTrace),'all'), ...
        'inversion:bayes_invert:NonFiniteLikelihood', ...
        ['The completed sampler request contains a nonfinite required ' ...
         'log-likelihood value.']);
    R.initialSamplerStates = squeeze(R.rawSample(1,:,:)).';
    R.terminalSamplerStates = squeeze(R.rawSample(end,:,:)).';
    if isConditional
        R.canonicalInitialSamplerStates= ...
            inversion.expand_conditional_parameters( ...
            R.initialSamplerStates,opts.parameterAdapter);
        R.canonicalTerminalSamplerStates= ...
            inversion.expand_conditional_parameters( ...
            R.terminalSamplerStates,opts.parameterAdapter);
    else
        R.canonicalInitialSamplerStates=R.initialSamplerStates;
        R.canonicalTerminalSamplerStates=R.terminalSamplerStates;
    end
    samplerSemantics = utils.sampler_semantics(cfg.mcmc.sampler);
    if samplerSemantics.withinAnalysisIndependent
        diagnosticIndependentUnit = 'independent_MCMC_chain';
    else
        diagnosticIndependentUnit = samplerSemantics.independentReplicateUnit;
    end
    R.sampleSemantics = struct('layout', 'iteration_parameter_sampler_state', ...
        'sampler', samplerSemantics.sampler, ...
        'stateSemantics', samplerSemantics.stateSemantics, ...
        'thirdDimension', samplerSemantics.thirdDimension, ...
        'withinAnalysisIndependent', samplerSemantics.withinAnalysisIndependent, ...
        'independentUnit', diagnosticIndependentUnit, ...
        'independentAnalysisUnit', samplerSemantics.independentReplicateUnit, ...
        'burnInAppliedBy', 'uq_postProcessInversion', ...
        'thinning', 1, ...
        'samplerParameterCount',M, ...
        'canonicalParameterCount',size(canonicalFlat,2), ...
        'conditionalParameterAdapter',isConditional);
    R.acceptancePerSamplerState = analysis.Results.Acceptance;
    if samplerSemantics.withinAnalysisIndependent
        R.acceptancePerChain = R.acceptancePerSamplerState;
    else
        R.acceptancePerWalker = R.acceptancePerSamplerState;
    end
    R.acceptance   = mean(R.acceptancePerSamplerState);
    R.pointEstimate = reshape(double(PP.PointEstimate.X{1}),1,[]);
    if isConditional
        R.canonicalPointEstimate=inversion.expand_conditional_parameters( ...
            R.pointEstimate,opts.parameterAdapter);
    else
        R.canonicalPointEstimate=R.pointEstimate;
    end
    R.opts         = opts;
    R.outputs      = opts.outputs;
    R.observationTransform = opts.observationTransform;
    R.parameterAdapter=opts.parameterAdapter;

    % A single direct analysis is assessed without a pre-MCMC gate. AIES
    % walkers remain interacting states and are never used as independent
    % chains; cell certification is decided separately from AIES/AM evidence.
    R.singleAnalysisHealth = inversion.single_analysis_health( ...
        S, P.bounds, cfg, samplerSemantics.sampler);

    probs = [0.025 0.5 0.975];
    [R.paramQ025, R.paramMedian, R.paramQ975, R.paramMean] = deal(zeros(1, M));
    for i = 1:M
        q = utils.weighted_quantile(flat(:, i), probs);
        R.paramQ025(i) = q(1); R.paramMedian(i) = q(2); R.paramQ975(i) = q(3);
        R.paramMean(i) = mean(flat(:, i));
    end
    canonicalM=size(canonicalFlat,2);
    [R.canonicalParamQ025,R.canonicalParamMedian,R.canonicalParamQ975, ...
        R.canonicalParamMean]=deal(nan(1,canonicalM));
    canonicalSummaryIndices=1:canonicalM;
    if isConditional
        canonicalSummaryIndices=opts.parameterAdapter.freeParameterIndices;
    end
    for i=canonicalSummaryIndices
        q=utils.weighted_quantile(canonicalFlat(:,i),probs);
        R.canonicalParamQ025(i)=q(1);
        R.canonicalParamMedian(i)=q(2);
        R.canonicalParamQ975(i)=q(3);
        R.canonicalParamMean(i)=mean(canonicalFlat(:,i));
    end
    if ~isempty(opts.thetaTrue)
        if isConditional
            canonicalTruth=reshape(double(opts.thetaTrue),1,[]);
            freeTruth=canonicalTruth(opts.parameterAdapter.freeParameterIndices);
            R.thetaTrue=freeTruth;
            R.canonicalThetaTrue=canonicalTruth;
        else
            R.thetaTrue=reshape(double(opts.thetaTrue),1,[]);
            R.canonicalThetaTrue=R.thetaTrue;
        end
        R.paramInside95=R.thetaTrue>=R.paramQ025& ...
            R.thetaTrue<=R.paramQ975;
        R.paramNormError=(R.paramMedian-R.thetaTrue)./ ...
            (P.bounds(:,2).'-P.bounds(:,1).');
        canonicalBounds=double(cfg.paramBounds);
        R.canonicalParamInside95=nan(1,canonicalM);
        R.canonicalParamNormError=nan(1,canonicalM);
        canonicalFree=canonicalSummaryIndices;
        R.canonicalParamInside95(canonicalFree)= ...
            R.canonicalThetaTrue(canonicalFree)>= ...
            R.canonicalParamQ025(canonicalFree)& ...
            R.canonicalThetaTrue(canonicalFree)<= ...
            R.canonicalParamQ975(canonicalFree);
        R.canonicalParamNormError(canonicalFree)= ...
            (R.canonicalParamMedian(canonicalFree)- ...
            R.canonicalThetaTrue(canonicalFree))./ ...
            (canonicalBounds(canonicalFree,2).'- ...
            canonicalBounds(canonicalFree,1).');
    end
end
