function variance = raw_observation_variance( ...
        meanPrediction, calibratedEmulatorVariance, cfg, opts, outputIndices)
%RAW_OBSERVATION_VARIANCE The observation variance of the six closing pressures in each scenario.
%   VARIANCE = inversion.raw_observation_variance(MEANPREDICTION,
%   CALIBRATEDEMULATORVARIANCE, CFG, OPTS, OUTPUTINDICES) returns, per row
%   and output (N-by-K, mbar^2), the variance of the likelihood's
%   observation error in the uncertainty mode of OPTS
%   (inversion.uncertainty_mode):
%     measurement_plus_gp   (CV * |mean|)^2 + calibrated emulator variance
%                           + numerical floor;
%     gp_only               calibrated emulator variance + numerical floor;
%     numerical_floor_only  numerical floor only,
%   with the measurement CV OPTS.measurementCV (default CFG.meas_cv) and the
%   floor CFG.likelihood.minSigma^2. MEANPREDICTION and
%   CALIBRATEDEMULATORVARIANCE (N-by-K) come from the GP evaluator
%   (surrogates.evaluate_canonical_gp or surrogates.evaluate_generalized_gp);
%   OUTPUTINDICES names their outputs among the six (default 1:K).
%   Side effects: none.

    if nargin < 4 || isempty(opts), opts = struct(); end
    if nargin < 5 || isempty(outputIndices)
        outputIndices = 1:size(meanPrediction,2);
    end
    validateattributes(meanPrediction,{'numeric'}, ...
        {'2d','real','finite','nonempty'});
    validateattributes(calibratedEmulatorVariance,{'numeric'}, ...
        {'2d','real','finite','size',size(meanPrediction)});
    outputIndices = outputIndices(:).';
    assert(numel(outputIndices)==size(meanPrediction,2) && ...
        all(outputIndices==round(outputIndices)) && ...
        all(outputIndices>=1 & outputIndices<=6) && ...
        numel(unique(outputIndices))==numel(outputIndices), ...
        'inversion:raw_observation_variance:OutputIndices', ...
        'outputIndices must identify each supplied output exactly once.');
    assert(isstruct(cfg) && isfield(cfg,'meas_cv') && ...
        isfield(cfg,'likelihood') && isfield(cfg.likelihood,'minSigma'), ...
        'inversion:raw_observation_variance:Configuration', ...
        'cfg must provide meas_cv and likelihood.minSigma.');
    assert(all(calibratedEmulatorVariance>=0,'all'), ...
        'inversion:raw_observation_variance:NegativeEmulatorVariance', ...
        'Calibrated emulator variance must be nonnegative.');

    mode = inversion.uncertainty_mode(opts);
    measurementCV = inversion.option_value(opts,'measurementCV',cfg.meas_cv);
    validateattributes(measurementCV,{'numeric'}, ...
        {'scalar','real','finite','nonnegative'});
    numericalFloorVariance = cfg.likelihood.minSigma^2;

    switch mode
        case 'measurement_plus_gp'
            variance = (measurementCV*max(abs(meanPrediction),1e-8)).^2 + ...
                calibratedEmulatorVariance + numericalFloorVariance;
        case 'gp_only'
            variance = calibratedEmulatorVariance + numericalFloorVariance;
        case 'numerical_floor_only'
            variance = numericalFloorVariance*ones(size(meanPrediction));
        otherwise
            error('inversion:raw_observation_variance:BadMode', ...
                'Unknown uncertainty mode "%s".',mode);
    end
    assert(all(isfinite(variance),'all') && all(variance>0,'all'), ...
        'inversion:raw_observation_variance:NonPositiveResult', ...
        'The canonical observation variance must be finite and positive.');
end
