function result = feature_sensitivity(cfg)
%FEATURE_SENSITIVITY Sobol indices of the derived features of the six pressures, on the route's existing sample.
%   RESULT = features.feature_sensitivity(CFG) computes, for the route of
%   CFG (fixed: the four material parameters; generalized: also the three
%   protocol inputs), the first- and total-order Sobol indices of every
%   feature of the catalog (settings 0.7, features.catalog) from the GP mean
%   of the route's production GP, with the estimator, sample design, sample
%   size and seed of the route's existing feature indices:
%     fixed        the sample of the ratio indices of sensitivity.run_fixed:
%                  its seed, then the raw Sobol sample, drawn again so that
%                  the generator stands where it stood, then the sample of
%                  order 1
%     generalized  the sample of the derived-feature indices of
%                  sensitivity.run_generalized: their seed
%                  (sensitivity.generalized_seeds), order, sample size and
%                  prediction batches
%   A feature that the route's step already computes (features.inventory) is
%   evaluated by the existing code, in its raw convention, so that its
%   indices are the existing ones; the others by the catalog
%   (features.feature_values: log-linear features in the log convention, raw
%   ones raw). Per feature and input: S1, ST, the gap max(ST - S1, 0)
%   (as sensitivity.run_fixed), the variance of the feature over the first
%   sample matrix (independent uniform points) and the effect size
%   sqrt(ST * variance), in the feature's own units. For the six pressures
%   their variance only: their indices are the primary ones (data/primary).
%   (UQLab's own total variance pools the outputs; sensitivity.sobol_evaluator.)
%   Per raw quotient of the
%   catalog (a feature with a denominator), its stability over the first
%   sample matrix (independent uniform points): the smallest denominator in
%   magnitude, whether the denominator changes sign, and the share of the
%   sum of squared deviations that the 0.1 % of values farthest from the mean
%   carry; UNSTABLE when the denominator changes sign or that share exceeds
%   the limit of the settings (0.7, features.unstableTailShare).
%   Writes below CFG.paths.featureSensitivity:
%     feature_indices.csv    one row per feature (and existing duplicate) and input
%     feature_stability.csv  one row per raw quotient
%   RESULT: the route, the number of derived features and the folder.
%   Side effects: writes the files above; the random number generator's state
%   is restored afterwards.
%   Computation: minutes (the GP at every point of the sample).

    route = 'fixed';
    if strcmp(cfg.dataMode, 'real_extended'), route = 'generalized'; end
    C = features.catalog(cfg);
    [E, existingValues] = features.inventory(route, C);
    fresh = C(~ismember(C.Name, E.Feature), :);
    state = rng; restore = onCleanup(@() rng(state));
    switch route
        case 'fixed'
            % sensitivity.run_fixed: its seed, the parameter space, the raw
            % Sobol sample, then the ratio sample of order 1.
            rng(cfg.seed, 'twister');
            P = parameters.parameter_space(cfg);
            saved = load(cfg.files.gp, 'gp'); gp = saved.gp;
            sensitivity.sobol(gp, P, cfg);
            local = cfg; local.sobol.order = 1;
            predict = @(X) surrogates.evaluate(gp, X, 'mean');
        case 'generalized'
            P = parameters.parameter_space(cfg);
            gp = surrogates.load_ensemble(cfg.files.gp, 'gp');
            local = cfg; local.N_sobol = cfg.realExtended.stage3.sobolSampleSize;
            batch = cfg.realExtended.predictionBatchSize;
            predict = @(X) surrogates.evaluate(gp, X, 'mean', batch);
            rng(sensitivity.generalized_seeds(cfg).gp_derived, 'twister');
    end
    evaluator = @(X) outputs(predict(X), existingValues, fresh);
    [S1, ST, ~, extra] = sensitivity.sobol_evaluator(evaluator, P, local);
    assert(~isempty(extra.sample1Y), 'features:feature_sensitivity:Sample', ...
        'UQLab kept no evaluations of the Sobol sample; the variances and the stability need them.');
    pressures = cellstr(string(cfg.outputNames));
    columns = [pressures(:); cellstr(E.ExistingName); cellstr(fresh.Name)];
    parts = cell(numel(columns), 1);
    for j = 1:numel(columns)
        d = describe(j, columns{j}, numel(pressures), E, C);
        s1 = S1(j, :).'; st = ST(j, :).';
        if d.family == "F0_raw_pressures", s1(:) = NaN; st(:) = NaN; end
        variance = extra.variance(j);
        gap = st - s1; gap(gap < 0) = 0;  % as sensitivity.run_fixed; NaN stays NaN
        m = P.M;
        parts{j} = table(repmat(d.name, m, 1), repmat(d.family, m, 1), repmat(d.status, m, 1), ...
            repmat(d.convention, m, 1), repmat(d.unit, m, 1), repmat(d.existingAs, m, 1), ...
            string(P.names(:)), s1, st, gap, repmat(variance, m, 1), sqrt(st * variance), ...
            'VariableNames', {'Feature', 'Family', 'Status', 'Convention', 'Unit', 'ExistingAs', ...
            'Parameter', 'S1', 'ST', 'Gap', 'Variance', 'EffectSize'});
    end
    indices = vertcat(parts{:});
    stability = stability_table(extra.sample1Y, columns, fresh, cfg.features.unstableTailShare);
    root = cfg.paths.featureSensitivity;
    if ~isfolder(root), mkdir(root); end
    utils.atomic_write_table(fullfile(root, 'feature_indices.csv'), indices);
    utils.atomic_write_table(fullfile(root, 'feature_stability.csv'), stability);
    result = struct('route', route, 'features', numel(columns) - numel(pressures), 'root', root);
end

function Z = outputs(Y, existingValues, fresh)
%OUTPUTS The six pressures, the route's existing features and the catalog features new on the route.
    Y = double(Y);
    Z = [Y, existingValues(Y), features.feature_values(Y, fresh)];
end

function d = describe(j, column, np, E, C)
%DESCRIBE What column J of the evaluated outputs is: a pressure, an existing feature or a new catalog feature.
    d = struct('name', string(column), 'family', "", 'status', "", 'convention', "raw", 'unit', "", ...
        'existingAs', "");
    if j <= np
        d.family = "F0_raw_pressures"; d.status = "existing"; d.unit = "mbar"; d.existingAs = string(column);
        return;
    end
    if j <= np + height(E)
        e = E(j - np, :);
        d.existingAs = e.ExistingName;
        if e.Feature == ""
            d.family = "other"; d.status = "existing, not in the catalog";
            return;
        end
        k = find(C.Name == e.Feature, 1);
        d.family = C.Family(k); d.unit = C.Unit(k);
        % The catalog feature is the existing feature equal to it, or else the
        % first affine one; other affine ones are duplicates.
        same = find(E.Feature == e.Feature & E.Relation == "same", 1);
        if isempty(same), same = find(E.Feature == e.Feature, 1); end
        if same == j - np
            d.name = e.Feature; d.status = "existing";
            if e.Relation == "affine"
                d.existingAs = sprintf("%s = %s", e.ExistingName, affine_text(e));
            end
        else
            d.name = e.ExistingName;
            d.status = sprintf("duplicate: %s (left out of the rankings)", affine_text(e));
        end
        return;
    end
    k = find(C.Name == string(column), 1);
    d.name = C.Name(k); d.family = C.Family(k); d.status = C.Status(k); d.unit = C.Unit(k);
    if C.Type(k) == "loglinear", d.convention = "log"; end
end

function text = affine_text(e)
%AFFINE_TEXT "1 - r21_D2" for an existing feature that is an affine function of a catalog feature.
    sign = " + "; if e.Scale < 0, sign = " - "; end
    scale = "";
    if abs(abs(e.Scale) - 1) > 1e-12, scale = string(abs(e.Scale)) + " "; end
    text = string(e.Offset) + sign + scale + e.Feature;
end

function T = stability_table(Y1, columns, fresh, limit)
%STABILITY_TABLE The stability of every raw quotient of the catalog over the first sample matrix.
%   Y1: the evaluated outputs at the points of the first sample matrix (its
%   first six columns are the pressures).
    quotients = find(any(fresh.Denominator, 2));
    n = numel(quotients);
    T = table(strings(n, 1), zeros(n, 1), false(n, 1), zeros(n, 1), repmat(limit, n, 1), false(n, 1), ...
        strings(n, 1), 'VariableNames', {'Feature', 'MinAbsDenominator', 'DenominatorChangesSign', ...
        'TailShare', 'TailShareLimit', 'Unstable', 'Reason'});
    for i = 1:n
        k = quotients(i);
        values = Y1(:, strcmp(columns, fresh.Name(k)));
        denominator = Y1(:, 1:6) * fresh.Denominator(k, :).';
        deviations = sort((values - mean(values)).^2, 'descend');
        share = sum(deviations(1:ceil(0.001 * numel(values)))) / sum(deviations);
        changes = any(denominator > 0) && any(denominator < 0);
        reasons = strings(1, 0);
        if changes, reasons(end+1) = "the denominator changes sign over the sample"; end %#ok<AGROW>
        if share > limit
            reasons(end+1) = sprintf(['the 0.1 %% of the values farthest from the mean carry %.3g of ' ...
                'the variance'], share); %#ok<AGROW>
        end
        T.Feature(i) = fresh.Name(k); T.MinAbsDenominator(i) = min(abs(denominator));
        T.DenominatorChangesSign(i) = changes; T.TailShare(i) = share;
        T.Unstable(i) = ~isempty(reasons); T.Reason(i) = strjoin(reasons, '; ');
    end
end
