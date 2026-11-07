function F = ensemble_functionals(runs)
%ENSEMBLE_FUNCTIONALS Time traces whose independent unit is a full ensemble.
%   Each RUNS cell is [iteration x parameter x interacting walker].  Walkers
%   are summarized within an iteration; they are never re-labelled as
%   independent chains.  Runs are aligned on their most recent common length.
%   F = inversion.ensemble_functionals(RUNS) returns, per iteration,
%   parameter and replicate, the ensemble mean, median and second moment
%   and the fractions of walkers in the lower and upper 5% tails, with the
%   iteration and replicate counts.
%   Side effects: none.

    assert(iscell(runs) && ~isempty(runs), ...
        'inversion:ensemble_functionals:Empty', 'At least one run is required.');
    nRep = numel(runs);
    nParam = size(runs{1}, 2);
    nIteration = min(cellfun(@(x) size(x, 1), runs));
    assert(nIteration >= 4, 'inversion:ensemble_functionals:TooShort', ...
        'At least four retained iterations are required.');

    aligned = cell(nRep, 1);
    pooled = zeros(0, nParam);
    for r = 1:nRep
        run = runs{r};
        assert(isnumeric(run) && size(run, 2) == nParam && size(run, 3) >= 1, ...
            'inversion:ensemble_functionals:Shape', ...
            'Each run must be iteration x parameter x walker.');
        assert(all(isfinite(run(:))), 'inversion:ensemble_functionals:NonFinite', ...
            'Run samples must be finite.');
        aligned{r} = run(end-nIteration+1:end, :, :);
        pooled = [pooled; flatten(aligned{r})]; %#ok<AGROW>
    end

    pooledMean = mean(pooled, 1);
    pooledQuantiles = quantile(pooled, [0.025 0.05 0.50 0.95 0.975], 1);
    stateMean = nan(nIteration, nParam, nRep);
    stateMedian = stateMean;
    stateSecondMoment = stateMean;
    lowerTailOccupancy = stateMean;
    upperTailOccupancy = stateMean;
    for r = 1:nRep
        run = aligned{r};
        stateMean(:, :, r) = mean(run, 3);
        stateMedian(:, :, r) = median(run, 3);
        centered = run - reshape(pooledMean, 1, nParam, 1);
        stateSecondMoment(:, :, r) = mean(centered.^2, 3);
        lowerTailOccupancy(:, :, r) = mean(run <= reshape(pooledQuantiles(2, :), 1, nParam, 1), 3);
        upperTailOccupancy(:, :, r) = mean(run >= reshape(pooledQuantiles(4, :), 1, nParam, 1), 3);
    end

    F.alignedRuns = aligned;
    F.pooled = pooled;
    F.pooledMean = pooledMean;
    F.pooledQuantiles = pooledQuantiles;
    F.stateMean = stateMean;
    F.stateMedian = stateMedian;
    F.stateSecondMoment = stateSecondMoment;
    F.lowerTailOccupancy = lowerTailOccupancy;
    F.upperTailOccupancy = upperTailOccupancy;
    F.nIterations = nIteration;
    F.nIndependentReplicates = nRep;
    F.definition = 'whole_ensemble_time_functionals_v1';
end

function flat = flatten(run)
    flat = reshape(permute(run, [1 3 2]), [], size(run, 2));
end
