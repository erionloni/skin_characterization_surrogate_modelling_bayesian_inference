function E = ensemble_ess(F)
%ENSEMBLE_ESS Conservative bulk/tail ESS from whole-ensemble functionals.
%   Bulk ESS uses rank-normalized ensemble mean and median traces.  Tail ESS
%   uses the fraction of interacting walkers in the pooled 5% tails at each
%   ensemble iteration.  The maximum ESS is iterations times independent
%   ensembles, not iterations times walkers.
%
%   Ranks are taken separately for each parameter, as in ess_bulk_tail.
%   Definition v1 ranked the traces of all parameters in one pool, which
%   compresses each parameter's normal scores into part of the normal scale
%   (a defect of the thesis code, corrected here). The ESS is a warning diagnostic
%   for AIES pairs; it never changes a certification decision.
%
%   E = inversion.ensemble_ess(F) takes the ensemble functionals F
%   (inversion.ensemble_functionals) and returns, per parameter, the bulk
%   ESS (the smaller of the mean and median traces' ESS), the lower and
%   upper tail ESS and the tail ESS (the smaller), and the maximum
%   (iterations times independent replicates).
%   Side effects: none.

    meanESS = inversion.ess_geyer(rank_normalize_each(F.stateMean));
    medianESS = inversion.ess_geyer(rank_normalize_each(F.stateMedian));
    lowerTailESS = inversion.ess_geyer(F.lowerTailOccupancy);
    upperTailESS = inversion.ess_geyer(F.upperTailOccupancy);
    E.meanESS = meanESS;
    E.medianESS = medianESS;
    E.bulkESS = min(meanESS, medianESS);
    E.lowerTailESS = lowerTailESS;
    E.upperTailESS = upperTailESS;
    E.tailESS = min(lowerTailESS, upperTailESS);
    E.maximumIndependentTimeStates = F.nIterations * F.nIndependentReplicates;
    E.definition = 'whole_ensemble_functional_ESS_v2_per_parameter_ranks';
end

function z = rank_normalize_each(x)
%RANK_NORMALIZE_EACH Normal scores per parameter of [iteration x parameter x ensemble].
    z = nan(size(x));
    for j = 1:size(x, 2)
        z(:, j, :) = inversion.rank_normalize(x(:, j, :));
    end
end
