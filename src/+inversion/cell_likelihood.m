function L = cell_likelihood(cfg, gp, cellRecord)
%CELL_LIKELIHOOD The likelihood of one canonical inversion cell, as its requests evaluated it.
%   L = inversion.cell_likelihood(CFG, GP, CELLRECORD) returns the
%   likelihood of the cell CELLRECORD (caseID, scenario, design, stepCount,
%   truth, and observation: the six pressures its requests conditioned on,
%   the held-out COMSOL pressures or, in gp_self_det, the GP mean at the
%   truth; a draw file's or posterior record's observation) with the
%   approved GP GP. Its options are those inversion.run_cell gives the
%   request and inversion.bayes_invert completes (its defaults and the
%   observation transform of the design), so that inversion.gp_log_likelihood
%   evaluates what the sampler evaluated: replayed in the sampler's order,
%   the values equal the sampler's bit for bit. No
%   sampler runs. Fields of L:
%     logLikelihood(X)        the log-likelihood at each row of X (model
%                             coordinates), one row per evaluation, as the
%                             sampler evaluates a candidate
%     logLikelihoodBatch(X,N) the same for many rows, N rows per evaluation
%                             (the unique rows; differs from one row at a
%                             time only by the GP's rounding)
%     prediction(X)           the GP at the rows of X as the likelihood uses
%                             it (surrogates.evaluate_canonical_gp: GPMean,
%                             CalibratedEmulatorVariance, ...)
%     observation, data, opts, requestCfg  what the likelihood conditions on
%   Canonical cells and those of the GP-mean inversion (gp_mean_det, the
%   held-out COMSOL pressures; settings A.13) only (no condition).
%   Side effects: none.
%   Computation: one GP evaluation per call.

    assert(~isfield(cellRecord, 'conditionCode') || isempty(cellRecord.conditionCode), ...
        'inversion:cell_likelihood:Conditional', ...
        'inversion.cell_likelihood builds the likelihood of canonical cells only.');
    requestCfg = inversion.sampler_request_config(cfg, 'AIES', double(cellRecord.stepCount));
    design = inversion.design_registry(char(string(cellRecord.design)));
    scenarioEntry = inversion.scenario_registry(char(string(cellRecord.scenario)));
    truth = reshape(double(cellRecord.truth), 1, []);
    % The options of inversion.run_cell; the seed, replicate and stage do not enter the likelihood.
    opts = struct('outputs', design.sourceOutputIndices, ...
        'observationTransform', design.observationTransform, ...
        'thetaTrue', truth, 'keepAnalysis', false, ...
        'scenarioTag', scenarioEntry.tag, ...
        'observationSource', scenarioEntry.observationSource, ...
        'uncertaintyMode', scenarioEntry.uncertaintyMode, ...
        'measurementCV', cfg.meas_cv, ...
        'emulatorErrorCalibrationVersion', cfg.inversion.emulatorErrorCalibrationVersion, ...
        'replicateID', 1, ...
        'continuationStage', sprintf('fresh_total_%d', double(cellRecord.stepCount)), ...
        'initialization', requestCfg.mcmc.initialization, ...
        'initializationParameters', struct(), ...
        'caseID', double(cellRecord.caseID), 'seed', NaN, ...
        'parameterAdapter', struct([]));
    switch scenarioEntry.tag
        case 'measurement_plus_gp'
            opts.uncertaintyMode = 'measurement_plus_gp';
        case 'gp_only'
            opts.uncertaintyMode = 'gp_only';
            opts.measurementCV = 0;
        case {'gp_self_det', 'gp_mean_det'}
            opts.uncertaintyMode = 'numerical_floor_only';
            opts.measurementCV = 0;
        otherwise
            error('inversion:cell_likelihood:Scenario', 'Unsupported scenario "%s".', scenarioEntry.tag);
    end
    observation = reshape(double(cellRecord.observation), 1, []);
    assert(numel(observation) == 6 && all(isfinite(observation)), ...
        'inversion:cell_likelihood:Observation', 'The cell''s observation must be six finite pressures.');
    % inversion.bayes_invert: the outputs and the observation of the design's transform.
    switch opts.observationTransform
        case 'ratios'
            opts.outputs = sort(unique([requestCfg.ratios.num, requestCfg.ratios.den]));
            data = design_study.ratio_values(observation, requestCfg.ratios.denFloor);
        case 'physics_guided_full_rank_six'
            opts.outputs = 1:6;
            data = inversion.physics_guided_full_rank_values(observation, inversion.physics_floor(requestCfg));
        otherwise
            data = observation(opts.outputs);
    end
    L = struct('observation', observation, 'data', data, 'opts', opts, 'requestCfg', requestCfg);
    L.logLikelihood = @(X) rows(X);
    L.logLikelihoodBatch = @(X, n) unique_rows(X, n);
    L.prediction = @(X) surrogates.evaluate_canonical_gp(gp, double(X), requestCfg);

    function value = rows(X)
        X = double(X);
        value = zeros(size(X, 1), 1);
        for k = 1:size(X, 1)
            value(k) = inversion.gp_log_likelihood(X(k, :), data, gp, requestCfg, opts);
        end
    end

    function value = unique_rows(X, n)
        [U, ~, ic] = unique(double(X), 'rows');
        values = zeros(size(U, 1), 1);
        for first = 1:n:size(U, 1)
            last = min(first + n - 1, size(U, 1));
            values(first:last) = inversion.gp_log_likelihood(U(first:last, :), data, gp, requestCfg, opts);
        end
        value = values(ic);
    end
end
