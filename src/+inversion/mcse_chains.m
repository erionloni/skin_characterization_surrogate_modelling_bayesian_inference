function M = mcse_chains(chains, bulkESS)
%MCSE_CHAINS Monte Carlo SEs for genuinely independent AM chains.
%   CHAINS is [iteration x parameter x independent chain]. Bulk ESS controls
%   the posterior-mean MCSE. A separate squared-deviation ESS and delta method
%   provide posterior-SD MCSE. Quantile MCSE uses independent indicator chains.
%   M = inversion.mcse_chains(CHAINS, BULKESS) returns, per parameter, the
%   MCSE of the mean, of the standard deviation and of the 2.5%, 50% and
%   97.5% quantiles (inversion.quantile_mcse_chains).
%   Side effects: none.

    [~, nParam, nChains] = size(chains);
    assert(nChains >= 2, 'inversion:mcse_chains:TooFewChains', ...
        'At least two independent chains are required.');
    pooled = reshape(permute(chains, [1 3 2]), [], nParam);
    posteriorMean = mean(pooled, 1);
    posteriorSD = std(pooled, 0, 1);

    M.mean = posteriorSD ./ sqrt(max(bulkESS, 1));
    centeredSquared = (chains - reshape(posteriorMean, 1, nParam, 1)).^2;
    M.varianceESS = inversion.ess_geyer(centeredSquared);
    flatSquared = reshape(permute(centeredSquared, [1 3 2]), [], nParam);
    varianceStateSD = std(flatSquared, 0, 1);
    varianceMCSE = varianceStateSD ./ sqrt(max(M.varianceESS, 1));
    M.sd = varianceMCSE ./ max(2 * posteriorSD, realmin);
    M.relativeSD = M.sd ./ max(posteriorSD, realmin);

    M.quantile = inversion.quantile_mcse_chains( ...
        chains, [0.025 0.50 0.975]);
    M.median = M.quantile.mcse(2, :);
    M.medianFeasible = M.quantile.feasible(2, :);
    M.definition = 'independent_MCMC_chain_MCSE_v1';
    M.sdMethod = 'delta_method_from_independent_chain_squared_deviations';
end
