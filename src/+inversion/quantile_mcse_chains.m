function Q = quantile_mcse_chains(chains, probabilities)
%QUANTILE_MCSE_CHAINS Density-based quantile MCSE for independent chains.
%   CHAINS is [iteration x parameter x independent chain]. Indicator-chain
%   ESS is used for each pooled quantile, followed by the usual density
%   delta-method approximation. Numerically unresolved densities fail closed.
%   Q = inversion.quantile_mcse_chains(CHAINS, PROBABILITIES) returns, per
%   probability and parameter, the pooled quantile, its MCSE, the estimated
%   density and whether the approximation is feasible.
%   Side effects: none.

    if nargin < 2 || isempty(probabilities)
        probabilities = [0.025 0.5 0.975];
    end
    probabilities = probabilities(:);
    [~, nParam, nChains] = size(chains);
    assert(nChains >= 2, 'inversion:quantile_mcse_chains:TooFewChains', ...
        'At least two independent chains are required.');
    pooled = reshape(permute(chains, [1 3 2]), [], nParam);
    nProb = numel(probabilities);

    Q.probabilities = probabilities;
    Q.quantiles = quantile(pooled, probabilities, 1);
    Q.ess = zeros(nProb, nParam);
    Q.density = zeros(nProb, nParam);
    Q.mcse = inf(nProb, nParam);
    Q.feasible = false(nProb, nParam);
    for j = 1:nParam
        x = pooled(:, j);
        bandwidth = robust_bandwidth(x);
        for pIndex = 1:nProb
            q = Q.quantiles(pIndex, j);
            occupancy = double(chains(:, j, :) <= q);
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
    Q.method = 'density_delta_method_on_independent_chain_CDF_traces_v1';
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
