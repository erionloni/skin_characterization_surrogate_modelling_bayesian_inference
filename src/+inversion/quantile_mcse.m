function Q = quantile_mcse(runs, probabilities, functionals)
%QUANTILE_MCSE Density-based quantile MCSE using ensemble occupancy traces.
%   At each iteration, the empirical CDF is the fraction of interacting
%   walkers below the pooled quantile.  Its time-series ESS is calculated
%   across genuinely independent complete ensembles.  MCSE(q_p) is then
%   approximated by MCSE(F(q_p))/f(q_p).  Degenerate or poorly resolved
%   densities are marked infeasible rather than reported as zero uncertainty.
%   Q = inversion.quantile_mcse(RUNS, PROBABILITIES, FUNCTIONALS) returns,
%   per probability and parameter, the pooled quantile, its MCSE, the
%   estimated density and whether the approximation is feasible.
%   Side effects: none.

    if nargin < 2 || isempty(probabilities), probabilities = [0.025 0.5 0.975]; end
    if nargin < 3 || isempty(functionals)
        functionals = inversion.ensemble_functionals(runs);
    end
    probabilities = probabilities(:);
    pooled = functionals.pooled;
    nParam = size(pooled, 2);
    nProb = numel(probabilities);
    Q.probabilities = probabilities;
    Q.quantiles = quantile(pooled, probabilities, 1);
    Q.ess = zeros(nProb, nParam);
    Q.density = zeros(nProb, nParam);
    Q.mcse = inf(nProb, nParam);
    Q.feasible = false(nProb, nParam);
    if functionals.nIndependentReplicates < 2
        Q.method = 'density_delta_method_on_whole_ensemble_CDF_trace_v1';
        return;
    end

    nIteration = functionals.nIterations;
    nRep = functionals.nIndependentReplicates;
    for j = 1:nParam
        x = pooled(:, j);
        bandwidth = robust_bandwidth(x);
        for pIndex = 1:nProb
            q = Q.quantiles(pIndex, j);
            occupancy = nan(nIteration, 1, nRep);
            for r = 1:nRep
                run = functionals.alignedRuns{r};
                occupancy(:, 1, r) = mean(run(:, j, :) <= q, 3);
            end
            Q.ess(pIndex, j) = inversion.ess_geyer(occupancy);
            if isfinite(bandwidth) && bandwidth > 0
                standardized = (q - x) / bandwidth;
                Q.density(pIndex, j) = mean(exp(-0.5 * standardized.^2)) / ...
                    (sqrt(2*pi) * bandwidth);
            end
            cdfTraceSD = std(occupancy(:), 0);
            feasible = Q.ess(pIndex, j) >= 20 && ...
                isfinite(Q.density(pIndex, j)) && Q.density(pIndex, j) > 0 && ...
                cdfTraceSD > 0;
            Q.feasible(pIndex, j) = feasible;
            if feasible
                Q.mcse(pIndex, j) = cdfTraceSD / ...
                    sqrt(Q.ess(pIndex, j)) / Q.density(pIndex, j);
            end
        end
    end
    Q.method = 'density_delta_method_on_whole_ensemble_CDF_trace_v1';
end

function h = robust_bandwidth(x)
    n = numel(x);
    s = std(x, 0);
    robustScale = iqr(x) / 1.349;
    scale = min(s, robustScale);
    if ~(isfinite(scale) && scale > 0)
        scale = s;
    end
    if ~(isfinite(scale) && scale > 0)
        h = NaN;
    else
        h = 0.9 * scale * n^(-1/5);
    end
end
