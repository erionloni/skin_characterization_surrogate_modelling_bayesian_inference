function varargout = combination_support(action, varargin)
%COMBINATION_SUPPORT The parts of the parameter-combination analysis that the canonical and the confirmation posteriors share.
%   Used by recovery.parameter_combinations (the fixed route's cells, A.12)
%   and confirmation.parameter_combinations (the confirmation's cells, B.8):
%   the prior sample, the log-form check, the analysis of one replicate's
%   draws, its row of cells.csv and the consensus of a group of cells. All
%   in the prior-standardized coordinates of the recovery's eigen-analysis,
%   z = (theta - prior mean) / prior SD: a unit-length combination w'z has
%   prior variance 1, and its SD ratio (posterior SD over prior SD) is
%   sqrt(w' C_z w).
%
%   Actions (recovery.combination_support(ACTION, ...)):
%     'prior_sample'        C, BOUNDS, WEAK, LOGGED -> the prior sample of the
%                           settings C (size, seed): its standardized
%                           coordinates and the prior mean and SD of the log
%                           coordinates of the weak pair
%     'log_form_check'      REPLICATES, WEAK, LOGGED, NAMES, BOUNDS, L ->
%                           [VALID, REASON]: whether the draws of both
%                           replicates allow the log form (every draw of a
%                           logged parameter positive, each replicate's
%                           quantile L.quantile at least L.rangeShare of the
%                           prior range above the lower bound), and why not
%     'replicate_analysis'  DRAWS, TRUTH, BOUNDS, NAMES, WEAK, PRIOR, FORMS,
%                           LOGVALID, C, EIGENOPTIONS -> the combinations of
%                           one replicate: the four-dimensional
%                           eigen-directions (recovery.
%                           posterior_covariance_eigensystem), the weak pair's
%                           best and worst combinations (first weight
%                           non-negative) with the individual SD ratios and
%                           the label, the log form and its power law, and the
%                           marginals of the best combinations with their
%                           densities
%     'cell_columns'        A, K, NAMES, WEAK, FORMS, PRIOR, LOGREASON -> the
%                           replicate's row of cells.csv after its key; K, the
%                           compensation predicted at the truth
%                           (recovery.parameter_combinations), adds its
%                           columns; [] leaves them out
%     'consensus_rows'      CELLS, NAMES, WEAK, PRIOR, FORMS, GROUPS ->
%                           [T, CELLS]: per group (the values of the columns
%                           GROUPS), replicate and best combination the
%                           consensus (recovery.consensus_projector, rank 1),
%                           the angles of the cells to it, medians and counts,
%                           for all cells and for the certified ones alone
%                           (columns ending in _certified_only); CELLS gains
%                           each cell's angle to its consensus
%     'pair_sign'           W -> W with its first nonzero weight positive
%     'power_law'           W, LOGSD, FORMS -> the exponents of a log-form
%                           combination on the natural logs of the physical
%                           parameters (NaN without a power law)
%   FORMS describes the weak pair's log form: logged (the natural log of the
%   parameter), log10 (its model coordinate is a log10), physicalNames,
%   powerLaw (every coordinate a logarithm), labels and logLabels.
%   Side effects: none.

    switch char(string(action))
        case 'prior_sample'
            varargout{1} = prior_sample(varargin{:});
        case 'log_form_check'
            [varargout{1:2}] = log_form_check(varargin{:});
        case 'replicate_analysis'
            varargout{1} = replicate_analysis(varargin{:});
        case 'cell_columns'
            varargout{1} = cell_columns(varargin{:});
        case 'consensus_rows'
            [varargout{1:2}] = consensus_rows(varargin{:});
        case 'pair_sign'
            varargout{1} = pair_sign(varargin{1});
        case 'power_law'
            varargout{1} = power_law(varargin{:});
        otherwise
            error('recovery:combination_support:Action', 'Unsupported combination action "%s".', ...
                char(string(action)));
    end
end

function prior = prior_sample(C, bounds, weak, logged)
%PRIOR_SAMPLE The prior sample of the settings: its standardized coordinates and those of the log form.
    stream = RandStream('twister', 'Seed', C.priorSampleSeed);
    lower = bounds(:, 1).'; width = (bounds(:, 2) - bounds(:, 1)).';
    theta = lower + rand(stream, C.priorSampleSize, numel(lower)) .* width;
    prior.mean = lower + width / 2;
    prior.sd = width / sqrt(12);
    prior.Z = (theta - prior.mean) ./ prior.sd;
    Y = theta(:, weak);
    Y(:, logged) = log(Y(:, logged));
    prior.logMean = mean(Y, 1);
    prior.logSD = std(Y, 0, 1);
    prior.Zlog = (Y - prior.logMean) ./ prior.logSD;
end

function [valid, reason] = log_form_check(replicates, weak, logged, names, bounds, L)
%LOG_FORM_CHECK Whether a cell's draws allow the log form, and why not.
    valid = true; reason = "";
    for r = find(~cellfun(@isempty, replicates))
        for j = find(logged)
            x = replicates{r}(:, weak(j));
            floorValue = bounds(weak(j), 1) + L.rangeShare * diff(bounds(weak(j), :));
            q = quantile(x, L.quantile);
            if any(x <= 0)
                valid = false;
                reason = sprintf('replicate %d: %d draws of %s not positive', r, nnz(x <= 0), names{weak(j)});
                return;
            elseif q < floorValue
                valid = false;
                reason = sprintf(['replicate %d: the %g %% quantile of %s, %.4g, lies below %.4g (%g %% of ' ...
                    'the prior range above the lower bound)'], r, 100 * L.quantile, names{weak(j)}, q, ...
                    floorValue, 100 * L.rangeShare);
                return;
            end
        end
    end
end

function A = replicate_analysis(draws, truth, bounds, names, weak, prior, forms, logValid, C, eigenOptions)
%REPLICATE_ANALYSIS The combinations of one replicate's draws.
    A = struct('valid', false, 'reason', '');
    G = recovery.posterior_covariance_eigensystem(draws, bounds, 'ParameterNames', names, eigenOptions{:});
    if ~G.eigensystem.valid
        A.reason = char(string(G.eigensystem.invalidReason));
        return;
    end
    A.valid = true;
    S = G.eigensystem;
    Z = G.standardizedDraws;
    zTruth = (truth - G.priorMean) ./ G.priorSD;
    A.draws = size(draws, 1);
    A.directions = table((1:4).', string(S.directionLabels), S.correctedEigenvalues, ...
        S.directionalPosteriorSDRatio, 'VariableNames', {'DirectionRank', 'DirectionLabel', 'Eigenvalue', ...
        'SDRatio'});
    for p = 1:numel(names)
        A.directions.(['Loading_' names{p}]) = S.eigenvectorsSignAligned(p, :).';
    end
    A.fourD = S.eigenvectorsSignAligned(:, 1);
    A.fourDSDRatio = S.directionalPosteriorSDRatio(1);
    B = S.covarianceSymmetrized(weak, weak);
    A.individual = sqrt(diag(B)).';
    [A.best, A.worst, A.lambda] = pair_directions(B);
    A.identified = sqrt(A.lambda(1)) <= C.labelFactor * min(A.individual);
    A.logValid = logValid;
    marginals = {}; densities = {};
    [marginals{end+1}, densities{end+1}] = marginal("four_d_tightest", formula(A.fourD, strcat('z(', names, ')')), ...
        Z * A.fourD, prior.Z * A.fourD, zTruth * A.fourD, sqrt(3) * sum(abs(A.fourD)) * [-1 1]);
    w = zeros(numel(names), 1); w(weak) = A.best;
    [marginals{end+1}, densities{end+1}] = marginal("weak_pair_best", formula(A.best, forms.labels), ...
        Z * w, prior.Z * w, zTruth * w, sqrt(3) * sum(abs(A.best)) * [-1 1]);
    if logValid
        Y = draws(:, weak); Y(:, forms.logged) = log(Y(:, forms.logged));
        yTruth = truth(weak); yTruth(forms.logged) = log(yTruth(forms.logged));
        Zlog = (Y - prior.logMean) ./ prior.logSD;
        zLogTruth = (yTruth - prior.logMean) ./ prior.logSD;
        L = cov(Zlog, 0);
        A.logIndividual = sqrt(diag((L + L.') / 2)).';
        [A.logBest, A.logWorst, A.logLambda] = pair_directions(L);
        A.logIdentified = sqrt(A.logLambda(1)) <= C.labelFactor * min(A.logIndividual);
        A.exponents = power_law(A.logBest, prior.logSD, forms);
        u = Zlog * A.logBest; up = prior.Zlog * A.logBest; ut = zLogTruth * A.logBest;
        [marginals{end+1}, densities{end+1}] = marginal("weak_pair_best_log", formula(A.logBest, forms.logLabels), ...
            u, up, ut, [min([u; up; ut]) max([u; up; ut])]);
    end
    A.marginals = vertcat(marginals{:});
    A.densities = vertcat(densities{:});
end

function [best, worst, lambda] = pair_directions(B)
%PAIR_DIRECTIONS The eigen-directions of a 2 x 2 covariance block, ascending, with the weak pair's sign.
%   A principal block of a valid covariance (recovery.covariance_eigensystem)
%   has no materially negative eigenvalue; rounding below zero is set to 0.
    [V, D] = eig((B + B.') / 2);
    [lambda, order] = sort(real(diag(D)), 'ascend');
    V = real(V(:, order));
    lambda = max(lambda, 0);
    best = pair_sign(V(:, 1));
    worst = pair_sign(V(:, 2));
end

function w = pair_sign(w)
%PAIR_SIGN The sign of a weak-pair direction: its first nonzero weight positive.
    w = w(:);
    pivot = find(w ~= 0, 1);
    if ~isempty(pivot) && w(pivot) < 0, w = -w; end
end

function e = power_law(w, logSD, forms)
%POWER_LAW The exponents of a log-form combination on the natural logs of the physical parameters.
%   A coordinate that is a natural log: weight / prior SD; a log10 model
%   coordinate: weight / (prior SD x ln 10). NaN without a power law.
    e = nan(1, 2);
    if ~forms.powerLaw, return; end
    e = reshape(w, 1, []) ./ logSD;
    e(forms.log10) = e(forms.log10) / log(10);
end

function text = formula(w, labels)
    parts = strings(1, numel(w));
    for j = 1:numel(w)
        parts(j) = sprintf('%+.3f %s', w(j), labels{j});
    end
    text = strjoin(parts, ' ');
end

function [row, density] = marginal(name, label, u, up, ut, span)
%MARGINAL The marginal of one combination: its summaries against the prior, and both densities.
%   The posterior's density on the range of its draws (a narrow posterior
%   keeps its shape), the prior's on the combination's prior support SPAN.
    estimate = plotting.posterior_marginal_density(u);
    priorEstimate = plotting.posterior_marginal_density(up, 'Bounds', span);
    qp = quantile(up, [0.025 0.975]);
    row = table(string(name), string(label), span(1), span(2), ut, estimate.posteriorMean, ...
        estimate.posteriorMedian, estimate.marginalMode, estimate.q025, estimate.q25, estimate.q75, ...
        estimate.q975, std(u), std(up), qp(1), qp(2), std(u) / std(up), ...
        (estimate.q975 - estimate.q025) / (qp(2) - qp(1)), ut >= estimate.q25 && ut <= estimate.q75, ...
        ut >= estimate.q025 && ut <= estimate.q975, numel(u), 'VariableNames', {'Combination', 'Formula', ...
        'Lower', 'Upper', 'Truth', 'Mean', 'Median', 'Mode', 'Q025', 'Q25', 'Q75', 'Q975', 'PosteriorSD', ...
        'PriorSD', 'PriorQ025', 'PriorQ975', 'SDRatio', 'WidthRatio95', 'TruthIn50', 'TruthIn95', 'Draws'});
    n = numel(estimate.grid); m = numel(priorEstimate.grid);
    density = table(repmat(string(name), n + m, 1), [repmat("posterior", n, 1); repmat("prior", m, 1)], ...
        [estimate.grid; priorEstimate.grid], [estimate.density; priorEstimate.density], ...
        'VariableNames', {'Combination', 'Curve', 'X', 'Density'});
end

function T = cell_columns(A, K, names, weak, forms, prior, logReason)
%CELL_COLUMNS One replicate's row of cells.csv (after its key); K [] leaves out the compensation.
    pair = names(weak);
    T = table(A.draws, 'VariableNames', {'Draws'});
    for p = 1:numel(names), T.(['FourD_w_' names{p}]) = A.fourD(p); end
    T.FourD_SDRatio = A.fourDSDRatio;
    for j = 1:2, T.(['SDRatio_' pair{j}]) = A.individual(j); end
    for j = 1:2, T.(['Best_w_' pair{j}]) = A.best(j); end
    T.Best_SDRatio = sqrt(A.lambda(1));
    for j = 1:2, T.(['Worst_w_' pair{j}]) = A.worst(j); end
    T.Worst_SDRatio = sqrt(A.lambda(2));
    for j = 1:2, T.(['BestPerUnit_' pair{j}]) = A.best(j) / prior.sd(weak(j)); end
    T.Identified = A.identified;
    T.LogFormApplicable = A.logValid;
    T.LogFormReason = string(logReason);
    values = nan(1, 10);
    if A.logValid
        values = [A.logIndividual, A.logBest.', sqrt(A.logLambda(1)), A.logWorst.', sqrt(A.logLambda(2)), ...
            A.exponents];
    end
    for j = 1:2, T.(['LogSDRatio_' pair{j}]) = values(j); end
    for j = 1:2, T.(['LogBest_w_' pair{j}]) = values(2 + j); end
    T.LogBest_SDRatio = values(5);
    for j = 1:2, T.(['LogWorst_w_' pair{j}]) = values(5 + j); end
    T.LogWorst_SDRatio = values(8);
    for j = 1:2, T.(['LogExponent_' forms.physicalNames{j}]) = values(8 + j); end
    T.LogExponentRatio = values(10) / values(9);
    T.LogIdentified = A.logValid && A.logIdentified;
    if isempty(K), return; end
    T.CompensationAngle = K.angle;
    T.CollinearityPair = K.collinearityPair;
    T.CollinearityAll = K.collinearityAll;
    for j = 1:2, T.(['Predicted_w_' pair{j}]) = K.leastInformative(j); end
    T.AnglePredictedToObservedWorst = acosd(recovery.axis_similarity(K.leastInformative, A.worst));
    T.JacobianStepDifference = K.stepDifference;
end

function [T, cells] = consensus_rows(cells, names, weak, prior, forms, groups)
%CONSENSUS_ROWS Per group, replicate and best combination: the consensus, the angles to it and the spread.
    pair = names(weak);
    kinds = struct('name', {"weak_pair_best", "weak_pair_best_log", "four_d_tightest"}, ...
        'prefix', {'Best_w_', 'LogBest_w_', 'FourD_w_'}, 'params', {pair, pair, names}, ...
        'angle', {'AngleToConsensus', 'LogAngleToConsensus', 'FourDAngleToConsensus'}, ...
        'sd', {'Best_SDRatio', 'LogBest_SDRatio', 'FourD_SDRatio'}, ...
        'individual', {'SDRatio_', 'LogSDRatio_', ''}, 'identified', {'Identified', 'LogIdentified', ''});
    for k = 1:numel(kinds), cells.(kinds(k).angle) = nan(height(cells), 1); end
    rows = {};
    keys = unique(cells(:, groups), 'stable');
    for g = 1:height(keys)
        inGroup = true(height(cells), 1);
        for c = 1:numel(groups)
            inGroup = inGroup & cells.(groups{c}) == keys.(groups{c})(g);
        end
        for r = reshape(unique(cells.Replicate).', 1, [])
            for k = 1:numel(kinds)
                kind = kinds(k);
                W = cells{:, strcat(kind.prefix, kind.params)};
                member = inGroup & cells.Replicate == r & all(isfinite(W), 2);
                row = [keys(g, :), table(r, kind.name, 'VariableNames', {'Replicate', 'Combination'})];
                [part, angles] = consensus_part(cells(member, :), W(member, :), kind, names, pair, prior, forms);
                cells.(kind.angle)(member) = angles;
                certified = member & cells.Status == "certified";
                partCertified = consensus_part(cells(certified, :), W(certified, :), kind, names, pair, prior, ...
                    forms);
                partCertified.Properties.VariableNames = strcat(partCertified.Properties.VariableNames, ...
                    '_certified_only');
                rows{end+1, 1} = [row, part, partCertified]; %#ok<AGROW>
            end
        end
    end
    T = vertcat(rows{:});
end

function [T, angles] = consensus_part(cells, W, kind, names, pair, prior, forms)
%CONSENSUS_PART The consensus of the rows of W (one combination per row) and its summaries.
%   The individual SD ratios are those of the weak pair PAIR in the
%   combination's coordinates (NaN for the four-dimensional combination).
    n = size(W, 1);
    weights = nan(1, numel(names));
    eigenvalue = NaN; angles = nan(n, 1); exponentRatio = NaN;
    if n > 0
        projectors = zeros(size(W, 2), size(W, 2), n);
        for i = 1:n, projectors(:, :, i) = W(i, :).' * W(i, :); end
        R = recovery.consensus_projector(projectors, 'TargetRank', 1);
        axis = R.dominantAxis;
        if ~strcmp(kind.prefix, 'FourD_w_'), axis = pair_sign(axis); end
        eigenvalue = R.dominantProjectorEigenvalue;
        for i = 1:n, angles(i) = acosd(recovery.axis_similarity(W(i, :), axis)); end
        [~, position] = ismember(kind.params, names);
        weights(position) = axis;
        if strcmp(kind.prefix, 'LogBest_w_')
            e = power_law(axis, prior.logSD, forms);
            exponentRatio = e(2) / e(1);
        end
    end
    T = table(n, 'VariableNames', {'Cells'});
    for p = 1:numel(names), T.(['ConsensusWeight_' names{p}]) = weights(p); end
    T.DominantProjectorEigenvalue = eigenvalue;
    T.MedianAngleToConsensus = median(angles);
    T.MaxAngleToConsensus = max([angles; NaN], [], 'omitnan');
    T.MedianSDRatio = median(cells.(kind.sd));
    individual = nan(1, 2);
    identified = NaN;
    if ~isempty(kind.individual)
        individual = [median(cells.([kind.individual kind.params{1}])), ...
            median(cells.([kind.individual kind.params{2}]))];
        identified = nnz(cells.(kind.identified));
    end
    for j = 1:2, T.(['MedianIndividualSDRatio_' pair{j}]) = individual(j); end
    T.IdentifiedCount = identified;
    T.ConsensusExponentRatio = exponentRatio;
end
