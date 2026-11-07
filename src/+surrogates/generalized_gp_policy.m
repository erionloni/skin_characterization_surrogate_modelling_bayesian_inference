function policy = generalized_gp_policy(cfg,outputIndex)
%GENERALIZED_GP_POLICY Frozen baseline policy for the seven-input GP family.
%   POLICY = surrogates.generalized_gp_policy(CFG, J) adds what applies to output J:
%   the declared multi-start selection of the fit policy (outputs 1 and 3),
%   or else the recorded thesis seed of the full fit (fullFitSeed, from
%   config/seeds/surrogate_fit_seeds.csv), when one is recorded. A
%   demonstration budget (cfg.gp.demonstrationIterations) limits every HGA
%   optimization to that many iterations and keeps the first two declared
%   starts; it is recorded as demonstrationIterations.
%   Side effects: none.
    policy=struct('schemaVersion','real_extended_gp_policy_v1', ...
        'kernel',cfg.gp.kernel,'trend',cfg.gp.trend, ...
        'correlationType',cfg.gp.correlation,'optimizer',cfg.gp.optim_method, ...
        'optimizerControl',[ ...
            'UQLab HGA defaults; cfg.gp.optim_starts is not passed by ' ...
            'surrogates.train_gp'], ...
        'retryAttempt',surrogates.generalized_retry_attempt(cfg), ...
        'retryPolicy',[ ...
            'terminal failures are immutable; retry only with a larger ' ...
            'GeneralizedRetryAttempt option'], ...
        'nugget',cfg.gp.nugget, ...
        'cvFolds',cfg.gp.cvFolds,'cvMetric','NRMSE_training_range', ...
        'heldoutUsedForSelection',false);
    if nargin>1&&~isempty(cfg.gp.fixedTheta)
        % refit_manual with fixed length scales (settings B.3).
        policy.fixedTheta=cfg.gp.fixedTheta(outputIndex,:);
    end
    if isfield(cfg.gp,'demonstrationIterations')&&~isempty(cfg.gp.demonstrationIterations)
        policy.demonstrationIterations=double(cfg.gp.demonstrationIterations);
    end
    if nargin>1&&isfield(cfg.gp,'generalizedFitPolicy')
        records=cfg.gp.generalizedFitPolicy.outputPolicies;
        selected=find([records.outputIndex]==outputIndex);
        if ~isempty(selected)
            assert(isscalar(selected),'surrogates:generalized_gp_policy:Output', ...
                'The GP fit policy lists output %d more than once.',outputIndex);
            policy.numericalSelection=records(selected);
            policy.numericalSelection.kernel=cfg.gp.kernel;
            if isfield(policy,'demonstrationIterations')
                policy.numericalSelection.maxIter=policy.demonstrationIterations;
                policy.numericalSelection.seeds=policy.numericalSelection.seeds(1:min(2,end));
            end
        end
    end
    if nargin>1&&~isfield(policy,'numericalSelection')
        seed=seeds.recorded(cfg,'surrogateFits',struct('Route','generalized', ...
            'Model','gp','Output',outputIndex,'Degree',[],'Fold',0));
        if ~isnan(seed),policy.fullFitSeed=seed;end
    end
end
