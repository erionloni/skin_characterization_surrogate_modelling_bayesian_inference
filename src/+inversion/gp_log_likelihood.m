function [logL, D] = gp_log_likelihood(params, data, model, cfg, opts)
%GP_LOG_LIKELIHOOD Gaussian likelihood with the propagated GP and measurement uncertainty.
%   LOGL = inversion.gp_log_likelihood(PARAMS, DATA, MODEL, CFG, OPTS) is the
%   custom likelihood used by inversion.bayes_invert. Raw UQLab variance is
%   retained for provenance; production uncertainty uses the frozen
%   development-only tempered-local diagonal emulator variance.
%
%   [LOGL, D] also returns the evaluated means and covariance components for
%   deterministic audit tests. Supported observation transforms are raw
%   subsets ('none'), the four correlated cycle ratios ('ratios'), and the
%   invertible six-coordinate physics-guided representation. Nonlinear
%   transforms retain their complete delta-method covariance. Supplementary
%   conditional requests may supply a reduced sampler state through
%   opts.parameterAdapter; it is expanded to the canonical four GP inputs
%   before this established likelihood is evaluated.
%   Side effects: none.
%   Computation: one GP evaluation (mean and variance) per call.

    [canonicalParams,parameterRecord]= ...
        inversion.canonical_likelihood_parameters(params,opts);
    prediction=evaluate_prediction(model,canonicalParams,cfg,opts);
    muAll=prediction.GPMean;
    emulatorVarianceAll=prediction.CalibratedEmulatorVariance;
    floor2 = cfg.likelihood.minSigma^2;

    D = struct('observationTransform', opts.observationTransform, ...
        'gpPredictiveOutput','raw_and_calibrated_variance', ...
        'rawMean',[],'rawUQLabVariance',prediction.RawUQLabVariance, ...
        'processVariance',prediction.ProcessVariance, ...
        'localVarianceShapeH',prediction.LocalVarianceShapeH, ...
        'calibratedEmulatorVariance', ...
            prediction.CalibratedEmulatorVariance, ...
        'rawVariance', [], ...
        'rawCovariance', [], ...
        'observationMean', [], 'observationCovariance', [], ...
        'uncertaintyMode', inversion.uncertainty_mode(opts), ...
        'measurementCV', inversion.option_value(opts, 'measurementCV', cfg.meas_cv), ...
        'numericalFloorVariance', floor2, ...
        'parameterAdapter',parameterRecord);

    switch opts.observationTransform
        case 'ratios'
            rawMu = muAll(:, 1:6);
            rawS2 = inversion.raw_observation_variance( ...
                rawMu,emulatorVarianceAll(:,1:6),cfg,opts,1:6);
            ratioMu = ratio_transform(rawMu, cfg);
            logL = transformed_ratio_loglik(ratioMu, data, rawMu, rawS2, cfg);

            D.rawMean = rawMu;
            D.rawVariance = rawS2;
            D.observationMean = ratioMu;
            if size(params, 1) == 1
                D.rawCovariance=diag(rawS2);
                J = ratio_jacobian(rawMu, cfg);
                D.observationCovariance = J*D.rawCovariance*J.';
            end
            return;

        case 'physics_guided_full_rank_six'
            rawMu=muAll(:,1:6);
            rawS2=inversion.raw_observation_variance( ...
                rawMu,emulatorVarianceAll(:,1:6),cfg,opts,1:6);
            transformedMu=inversion.physics_guided_full_rank_values( ...
                rawMu,inversion.physics_floor(cfg));
            logL=transformed_physics_guided_loglik( ...
                transformedMu,data,rawMu,rawS2,cfg);

            D.rawMean=rawMu;
            D.rawVariance=rawS2;
            D.observationMean=transformedMu;
            if size(params,1)==1
                D.rawCovariance=diag(rawS2);
                [~,~,D.observationCovariance]= ...
                    inversion.physics_guided_full_rank_transform( ...
                    rawMu,D.rawCovariance,inversion.physics_floor(cfg));
            end
            return;

        case 'none'
            mu = muAll(:, opts.outputs);
            s2 = inversion.raw_observation_variance( ...
                mu,emulatorVarianceAll(:,opts.outputs),cfg,opts,opts.outputs);
            D.rawMean = mu;
            D.rawVariance = s2;
            D.observationMean = mu;
            if size(params, 1) == 1
                D.rawCovariance=diag(s2);
                D.observationCovariance = D.rawCovariance;
            end
        otherwise
            error('inversion:gp_log_likelihood:ObservationTransform', ...
                'Unsupported observation transform "%s".', ...
                opts.observationTransform);
    end

    logL = raw_gaussian_loglik(mu,data,s2);
end

function prediction=evaluate_prediction(model,params,cfg,opts)
% Keep the fixed-route evaluator as the unchanged default. Consume-only
% protocol actions may inject a verified evaluator without forking the
% normalized Gaussian likelihood or any covariance mathematics.
    if isfield(opts,'predictionEvaluator')&& ...
            ~isempty(opts.predictionEvaluator)
        assert(isa(opts.predictionEvaluator,'function_handle'), ...
            'inversion:gp_log_likelihood:PredictionEvaluator', ...
            'opts.predictionEvaluator must be a function handle.');
        prediction=opts.predictionEvaluator(model,params,cfg);
    else
        prediction=surrogates.evaluate_canonical_gp(model,params,cfg);
    end
    required={'GPMean','RawUQLabVariance','ProcessVariance', ...
        'LocalVarianceShapeH','CalibratedEmulatorVariance'};
    assert(isstruct(prediction)&&isscalar(prediction)&& ...
        all(isfield(prediction,required))&& ...
        isequal(size(prediction.GPMean),[size(params,1) 6])&& ...
        isequal(size(prediction.CalibratedEmulatorVariance), ...
            size(prediction.GPMean)), ...
        'inversion:gp_log_likelihood:PredictionContract', ...
        'The prediction evaluator returned an incompatible GP contract.');
end

% -------------------------------------------------------------------------
function logL=raw_gaussian_loglik(mu,data,s2)
%RAW_GAUSSIAN_LOGLIK Use the common Cholesky path for diagonal raw designs.
    n=size(mu,1);dimension=size(mu,2);target=reshape(double(data),[],1);
    assert(numel(target)==dimension, ...
        'inversion:gp_log_likelihood:RawObservationDimension');
    logL=nan(n,1);
    for row=1:n
        residual=mu(row,:).'-target;
        logL(row)=gaussian_full(residual,diag(s2(row,:)),dimension);
    end
end

% -------------------------------------------------------------------------
function logL = transformed_ratio_loglik(ratioMu, data, rawMu, rawS2, cfg)
%TRANSFORMED_RATIO_LOGLIK Full delta-method covariance for the four ratios.
%   Ratios sharing a denominator are correlated; retaining only their diagonal
%   variances would overstate their independence.
    n = size(rawMu, 1);
    k = size(ratioMu, 2);
    logL = nan(n, 1);
    y = data(:);
    for r = 1:n
        J = ratio_jacobian(rawMu(r, :), cfg);
        S = J * diag(rawS2(r, :)) * J.';
        e = ratioMu(r, :).' - y;
        logL(r) = gaussian_full(e, S, k);
    end
end

% -------------------------------------------------------------------------
function logL = transformed_physics_guided_loglik( ...
        transformedMu,data,rawMu,rawS2,cfg)
%TRANSFORMED_PHYSICS_GUIDED_LOGLIK Full 6-by-6 delta-method likelihood.
%   The established raw-pressure uncertainty contract supplies a complete
%   diagonal SIGMA_P for the independent pressure-level error model. The
%   shared nonlinear coordinates induce off-diagonal covariance, retained as
%   SIGMA_F = J_F*SIGMA_P*J_F'. No transformed coordinate is treated as
%   independent.
    n=size(rawMu,1);
    k=6;
    logL=nan(n,1);
    target=data(:);
    for r=1:n
        rawCovariance=diag(rawS2(r,:));
        [~,~,transformedCovariance]= ...
            inversion.physics_guided_full_rank_transform( ...
            rawMu(r,:),rawCovariance,inversion.physics_floor(cfg));
        residual=transformedMu(r,:).'-target;
        logL(r)=gaussian_full(residual,transformedCovariance,k);
    end
end

% -------------------------------------------------------------------------
function value = gaussian_full(residual, covariance, dimension)
%GAUSSIAN_FULL Fully normalised Gaussian log-density with adaptive roundoff jitter.
    S = (covariance + covariance.') / 2;
    scale = max(1, max(abs(diag(S))));
    jitter = eps(scale);
    [L, p] = chol(S, 'lower');
    nGrow = 0;
    while p > 0 && nGrow < 8
        S = S + jitter * eye(dimension);
        jitter = 10 * jitter;
        [L, p] = chol(S, 'lower');
        nGrow = nGrow + 1;
    end
    if p > 0
        error('inversion:gp_log_likelihood:NonPositiveCovariance', ...
            ['The complete delta-method transformed covariance is not ' ...
             'numerically positive definite after adaptive stabilization.']);
    end
    q = L \ residual;
    value = -0.5 * (q.' * q + 2*sum(log(diag(L))) + dimension*log(2*pi));
end

% -------------------------------------------------------------------------
function ratios = ratio_transform(Y, cfg)
%RATIO_TRANSFORM Map raw closing pressures to configured cycle ratios.
    assert(isequal(cfg.ratios.num,[2 3 5 6]) && ...
        isequal(cfg.ratios.den,[1 1 4 4]), ...
        'inversion:gp_log_likelihood:RatioDefinition', ...
        'Configured ratios differ from the central design-study operator.');
    ratios = design_study.ratio_values(Y,cfg.ratios.denFloor);
end

% -------------------------------------------------------------------------
function J = ratio_jacobian(Y, cfg)
%RATIO_JACOBIAN Jacobian of the ratio vector with respect to six raw outputs.
    assert(isequal(cfg.ratios.num,[2 3 5 6]) && ...
        isequal(cfg.ratios.den,[1 1 4 4]), ...
        'inversion:gp_log_likelihood:RatioDefinition', ...
        'Configured ratios differ from the central design-study operator.');
    [~,J] = design_study.ratio_transform(Y,[],cfg.ratios.denFloor);
end
