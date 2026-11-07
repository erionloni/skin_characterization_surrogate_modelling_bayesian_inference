function result = feature_accuracy(cfg)
%FEATURE_ACCURACY How well the GP (and the PCE) reproduce every catalog feature on the external cases.
%   RESULT = features.feature_accuracy(CFG) compares, for the complete
%   external cases of the route (features.external_predictions: what the
%   surrogate assessment saved), each feature computed from the surrogate
%   means with the same feature computed from the COMSOL pressures: the six
%   pressures (F0) and every feature of the catalog (settings 0.7). Point
%   predictions only; nothing is tuned on the result.
%     error e    log-linear features (log f = w * log p, the pressures with a
%                unit w): e = w * delta, delta = log(mu) - log(y), about the
%                relative error of f; raw features: e = f(mu) - f(y) (mbar
%                for a difference)
%   Per feature and surrogate (GP, PCE): n, bias with mean +/- 1.96 SD/sqrt(n),
%   RMSE and R^2 with case-bootstrap intervals (the settings' resamples and
%   seed, 0.7 accuracy; 2.5 % and 97.5 %), MAE, median and maximum |e| (its
%   case), SD(e), the spread (SD over the cases of the COMSOL feature: log f
%   for a log-linear feature), NRMSE = RMSE / spread, R^2 = 1 - sum(e^2) /
%   sum((f - mean f)^2) (in log for log-linear features), the noise scale
%   (the SD of the feature under independent errors of the reference CV c on
%   the six pressures: c * sqrt(sum w^2) for log-linear features; the delta
%   method on the COMSOL pressures for raw ones, median over the cases),
%   RMSE / noise scale, the rounding scale (the SD that the 1 s output grid
%   of the gridded outputs alone gives: steps of |rate| x the time step,
%   uniform rounding, propagated as the noise scale; median over the cases)
%   and, for the GP and log-linear features, the emulator check
%   z = e / s, s = sqrt(sum w^2 v / mu^2) under the likelihood's independent
%   calibrated emulator variances v: SD(z) and the count of |z| < 1.96.
%   A raw quotient whose COMSOL or GP denominator changes sign over the cases,
%   or whose most extreme case carries more than the settings' share of the
%   variance (the rule of the feature sensitivity, 0.7), is UNSTABLE:
%   reported, left out of the summaries of the rankings.
%   The generalized route adds the subsets: suction rate faster or not
%   than the default protocol's (B.1); inside or outside the assessment's
%   training support of pcl3_D6_mbar.
%   Writes below CFG.paths.featureAccuracy:
%     feature_metrics.csv     per surrogate, subset and feature
%     feature_errors.csv      per case, feature and surrogate: the features and e (z for the GP)
%     relative_errors.csv     per case and output: delta of the GP and the PCE, the relative emulator SD
%     error_correlation.csv   the correlation of delta between the outputs (GP)
%     error_decomposition.csv per log-linear feature: Var(e) = sum w_k^2 Var(delta_k) + covariance terms (GP)
%     top_errors.csv          per feature the five cases with the largest |e| (GP), with their inputs
%   Side effects: writes the files above.
%   Computation: seconds.

    route = 'fixed';
    if strcmp(cfg.dataMode, 'real_extended'), route = 'generalized'; end
    A = cfg.features.accuracy;
    D = features.definitions(cfg);
    E = features.external_predictions(cfg);
    F = all_features(features.catalog(cfg), D.outputs);
    n = numel(E.caseIDs);
    steps = 10 * E.rate * A.outputTimeStep;  % mbar per output time step (1 kPa = 10 mbar)
    gridded = ismember(D.outputs, cellstr(string(A.griddedOutputs)));
    subsets = struct('name', "all", 'members', true(n, 1));
    if strcmp(route, 'generalized')
        subsets(end+1) = struct('name', "rate_faster_than_default", 'members', E.rate > A.defaultRate);
        subsets(end+1) = struct('name', "rate_not_faster_than_default", 'members', E.rate <= A.defaultRate);
        inside = E.support(:, strcmp(D.outputs, 'pcl3_D6_mbar')) == "well_supported";
        subsets(end+1) = struct('name', "pcl3_D6_inside_training_support", 'members', inside);
        subsets(end+1) = struct('name', "pcl3_D6_outside_training_support", 'members', ~inside);
    end
    metricParts = {}; errorParts = {};
    for s = ["GP", "PCE"]
        mu = E.gp; if s == "PCE", mu = E.pce; end
        for f = 1:numel(F)
            [fy, fmu, e] = feature_errors(F(f), E.comsol, mu);
            z = nan(n, 1);
            if s == "GP" && F(f).type == "loglinear"
                z = e ./ sqrt(((E.variance ./ E.gp.^2) * (F(f).w.^2).'));
            end
            [unstable, reason] = stability(F(f), E.comsol, mu, fy, cfg.features.unstableTailShare);
            errorParts{end+1, 1} = table(E.caseIDs, repmat(F(f).name, n, 1), repmat(F(f).family, n, 1), ...
                repmat(s, n, 1), fy, fmu, e, z, 'VariableNames', {'CaseID', 'Feature', 'Family', ...
                'Surrogate', 'FeatureCOMSOL', 'FeatureSurrogate', 'Error', 'Z'}); %#ok<AGROW>
            noise = noise_scale(F(f), E.comsol, D.c);
            rounding = rounding_scale(F(f), E.comsol, gridded .* steps / sqrt(12));
            for subset = subsets
                k = subset.members;
                if nnz(k) < 3, continue; end
                M = metrics(e(k), fy(k), z(k), E.caseIDs(k), A.bootstrapSeed, A.bootstrapResamples);
                M.Surrogate = s; M.Subset = subset.name; M.Feature = F(f).name; M.Family = F(f).family;
                M.Type = F(f).type; M.NoiseScale = median(noise(k)); M.RMSEOverNoise = M.RMSE / M.NoiseScale;
                M.RoundingSD = median(rounding(k)); M.Unstable = unstable; M.Reason = reason;
                metricParts{end+1, 1} = struct2table(M); %#ok<AGROW>
            end
        end
    end
    order = {'Surrogate', 'Subset', 'Feature', 'Family', 'Type', 'N', 'Bias', 'BiasLow', 'BiasHigh', ...
        'RMSE', 'RMSELow', 'RMSEHigh', 'MAE', 'MedianAbsError', 'MaxAbsError', 'MaxCaseID', 'SDError', ...
        'Spread', 'NRMSE', 'R2', 'R2Low', 'R2High', 'NoiseScale', 'RMSEOverNoise', 'RoundingSD', 'SDZ', ...
        'ZWithin196', 'Unstable', 'Reason'};
    metricsTable = vertcat(metricParts{:}); metricsTable = metricsTable(:, order);
    root = cfg.paths.featureAccuracy;
    if ~isfolder(root), mkdir(root); end
    utils.atomic_write_table(fullfile(root, 'feature_metrics.csv'), metricsTable);
    utils.atomic_write_table(fullfile(root, 'feature_errors.csv'), vertcat(errorParts{:}));
    utils.atomic_write_table(fullfile(root, 'relative_errors.csv'), relative_errors(E));
    utils.atomic_write_table(fullfile(root, 'error_correlation.csv'), correlation(E));
    utils.atomic_write_table(fullfile(root, 'error_decomposition.csv'), decomposition(F, E));
    utils.atomic_write_table(fullfile(root, 'top_errors.csv'), top_errors(F, E));
    result = struct('route', route, 'cases', n, 'features', numel(F), 'root', root);
end

function F = all_features(C, outputs)
%ALL_FEATURES The six pressures (log-linear, unit weights) followed by the catalog.
    F = struct('name', {}, 'family', {}, 'type', {}, 'w', {}, 'b', {});
    for k = 1:6
        w = zeros(1, 6); w(k) = 1;
        F(end+1) = struct('name', string(outputs{k}), 'family', "F0_raw_pressures", ...
            'type', "loglinear", 'w', w, 'b', zeros(1, 6)); %#ok<AGROW>
    end
    for k = 1:height(C)
        F(end+1) = struct('name', C.Name(k), 'family', C.Family(k), 'type', C.Type(k), ...
            'w', C.Weights(k, :), 'b', C.Denominator(k, :)); %#ok<AGROW>
    end
end

function [fy, fmu, e] = feature_errors(f, y, mu)
%FEATURE_ERRORS The feature from COMSOL and from the surrogate, and the error (log-linear: in log).
    if f.type == "loglinear"
        fy = log(y) * f.w.'; fmu = log(mu) * f.w.';
    elseif any(f.b)
        fy = (y * f.w.') ./ (y * f.b.'); fmu = (mu * f.w.') ./ (mu * f.b.');
    else
        fy = y * f.w.'; fmu = mu * f.w.';
    end
    e = fmu - fy;
end

function s = noise_scale(f, y, c)
%NOISE_SCALE Per case the SD of the feature under independent relative errors c of the six pressures.
    n = size(y, 1);
    if f.type == "loglinear"
        s = repmat(c * sqrt(sum(f.w.^2)), n, 1);
    else
        s = c * sqrt(sum((raw_gradient(f, y) .* y).^2, 2));
    end
end

function s = rounding_scale(f, y, sd)
%ROUNDING_SCALE Per case the SD of the feature from the rounding of the gridded outputs alone (SD in mbar, n x 6).
    if f.type == "loglinear"
        s = sqrt(((sd ./ y).^2) * (f.w.^2).');
    else
        s = sqrt(sum((raw_gradient(f, y) .* sd).^2, 2));
    end
end

function g = raw_gradient(f, y)
%RAW_GRADIENT Per case the derivative of a raw feature with respect to the six pressures.
    if any(f.b)
        num = y * f.w.'; den = y * f.b.';
        g = (f.w .* den - f.b .* num) ./ den.^2;
    else
        g = repmat(f.w, size(y, 1), 1);
    end
end

function [unstable, reason] = stability(f, y, mu, fy, limit)
%STABILITY The rule of the feature sensitivity for a raw quotient, on the external cases.
    unstable = false; reason = "";
    if f.type == "loglinear" || ~any(f.b), return; end
    den = [y * f.b.', mu * f.b.'];
    reasons = strings(1, 0);
    if any(den(:) > 0) && any(den(:) < 0)
        reasons(end+1) = "the denominator changes sign over the cases";
    end
    deviations = sort((fy - mean(fy)).^2, 'descend');
    share = sum(deviations(1:ceil(0.001 * numel(fy)))) / sum(deviations);
    if share > limit
        reasons(end+1) = sprintf('the most extreme case carries %.3g of the variance', share);
    end
    unstable = ~isempty(reasons);
    reason = strjoin(reasons, '; ');
end

function M = metrics(e, fy, z, caseIDs, seed, resamples)
%METRICS The error summaries of one feature on the cases of one subset, with case-bootstrap intervals.
%   The resamples come from a random stream of their own with the seed of
%   the settings: every feature of a subset is resampled with the same cases.
    n = numel(e);
    M.N = n;
    M.Bias = mean(e);
    half = 1.96 * std(e) / sqrt(n);
    M.BiasLow = M.Bias - half; M.BiasHigh = M.Bias + half;
    M.RMSE = sqrt(mean(e.^2));
    M.MAE = mean(abs(e)); M.MedianAbsError = median(abs(e));
    [M.MaxAbsError, worst] = max(abs(e)); M.MaxCaseID = caseIDs(worst);
    M.SDError = std(e);
    M.Spread = std(fy);
    M.NRMSE = M.RMSE / M.Spread;
    M.R2 = 1 - sum(e.^2) / sum((fy - mean(fy)).^2);
    pick = randi(RandStream('twister', 'Seed', seed), n, n, resamples);
    eb = e(pick); fb = fy(pick);
    rmse = sqrt(mean(eb.^2, 1));
    r2 = 1 - sum(eb.^2, 1) ./ sum((fb - mean(fb, 1)).^2, 1);
    bounds = quantile(rmse, [0.025 0.975]); M.RMSELow = bounds(1); M.RMSEHigh = bounds(2);
    bounds = quantile(r2, [0.025 0.975]); M.R2Low = bounds(1); M.R2High = bounds(2);
    M.SDZ = std(z); M.ZWithin196 = nnz(abs(z) < 1.96);
    if all(isnan(z)), M.SDZ = NaN; M.ZWithin196 = NaN; end
end

function T = relative_errors(E)
%RELATIVE_ERRORS Per case and output: delta = log(mu / y) of the GP and the PCE, the relative emulator SD.
    n = numel(E.caseIDs);
    caseID = repmat(E.caseIDs, 1, 6).'; output = repmat(string(E.outputs), n, 1).';
    delta = (log(E.gp) - log(E.comsol)).'; deltaPCE = (log(E.pce) - log(E.comsol)).';
    sd = (sqrt(E.variance) ./ E.gp).';
    T = table(caseID(:), output(:), delta(:), deltaPCE(:), sd(:), 'VariableNames', {'CaseID', 'Output', ...
        'DeltaGP', 'DeltaPCE', 'RelativeEmulatorSD'});
end

function T = correlation(E)
%CORRELATION The correlation of the GP's relative errors between the six outputs.
    R = corrcoef(log(E.gp) - log(E.comsol));
    T = array2table(R, 'VariableNames', E.outputs);
    T = [table(string(E.outputs(:)), 'VariableNames', {'Output'}), T];
end

function T = decomposition(F, E)
%DECOMPOSITION Var(e) of each log-linear feature: the variance terms and the covariance terms of delta (GP).
    delta = log(E.gp) - log(E.comsol);
    S = cov(delta);
    rows = {};
    for f = F
        if f.type ~= "loglinear", continue; end
        w = f.w;
        varianceTerms = sum(w.^2 .* diag(S).');
        total = w * S * w.';
        e = delta * w.';
        rows{end+1, 1} = table(f.name, f.family, varianceTerms, total - varianceTerms, total, var(e), ...
            'VariableNames', {'Feature', 'Family', 'VarianceTerms', 'CovarianceTerms', 'Sum', ...
            'ObservedVariance'}); %#ok<AGROW>
    end
    T = vertcat(rows{:});
end

function T = top_errors(F, E)
%TOP_ERRORS Per feature the five cases with the largest |e| of the GP, with their inputs.
    rows = {};
    for f = F
        [~, ~, e] = feature_errors(f, E.comsol, E.gp);
        [~, order] = sort(abs(e), 'descend');
        for r = 1:min(5, numel(e))
            i = order(r);
            row = table(f.name, f.family, r, E.caseIDs(i), e(i), 'VariableNames', {'Feature', 'Family', ...
                'Rank', 'CaseID', 'Error'});
            for m = 1:numel(E.inputNames), row.(E.inputNames{m}) = E.inputs(i, m); end
            rows{end+1, 1} = row; %#ok<AGROW>
        end
    end
    T = vertcat(rows{:});
end
