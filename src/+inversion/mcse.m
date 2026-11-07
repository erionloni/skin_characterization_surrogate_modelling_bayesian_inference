function M = mcse(runs, meanESS, functionals)
%MCSE Whole-ensemble Monte Carlo SEs for posterior mean, median, and SD.
%   Mean and variance are written as expectations of whole-ensemble time
%   functionals.  This preserves AIES walker dependence.  Median and tail
%   quantile MCSEs use an explicitly labelled density-based approximation and
%   report whether that approximation is numerically feasible.
%   M = inversion.mcse(RUNS, MEANESS, FUNCTIONALS) returns, per parameter,
%   the MCSE of the posterior mean (from MEANESS), of the standard
%   deviation (delta method on the second-moment functional) and of the
%   2.5%, 50% and 97.5% quantiles (inversion.quantile_mcse), with the
%   feasibility of the quantile approximation.
%   Side effects: none.

    if nargin < 3 || isempty(functionals)
        functionals = inversion.ensemble_functionals(runs);
    end
    m = size(functionals.pooled, 2);
    if functionals.nIndependentReplicates < 2
        M.mean = inf(1, m);
        M.sd = inf(1, m);
        M.relativeSD = inf(1, m);
        M.varianceESS = zeros(1, m);
    else
        meanTraceSD = squeeze_std(functionals.stateMean);
        M.mean = meanTraceSD ./ sqrt(max(meanESS, 1));

        varianceESS = inversion.ess_geyer(functionals.stateSecondMoment);
        posteriorSD = std(functionals.pooled, 0, 1);
        varianceTraceSD = squeeze_std(functionals.stateSecondMoment);
        varianceMCSE = varianceTraceSD ./ sqrt(max(varianceESS, 1));
        M.sd = varianceMCSE ./ max(2 * posteriorSD, realmin);
        M.relativeSD = M.sd ./ max(posteriorSD, realmin);
        M.varianceESS = varianceESS;
    end
    M.quantile = inversion.quantile_mcse(runs, [0.025 0.50 0.975], functionals);
    M.median = M.quantile.mcse(2, :);
    M.medianFeasible = M.quantile.feasible(2, :);
    M.definition = 'whole_ensemble_functional_MCSE_v1';
    M.sdMethod = 'delta_method_from_global_second_moment_time_functional';
end

function values = squeeze_std(trace)
    flat = reshape(permute(trace, [1 3 2]), [], size(trace, 2));
    values = reshape(std(flat, 0, 1), 1, []);
end
