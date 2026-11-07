function R = ensemble_rhat(F)
%ENSEMBLE_RHAT Rank-split R-hat for several whole-ensemble functionals.
%   This does not call interacting AIES walkers independent chains.  A
%   genuinely independent complete ensemble is the replicate dimension.
%   R = inversion.ensemble_rhat(F) returns the rank-normalized, folded,
%   split R-hat (inversion.rhat_rank_split) of each ensemble functional F
%   (inversion.ensemble_functionals) per parameter, and its maximum over
%   the functionals.
%   Side effects: none.

    traces = {F.stateMean, F.stateMedian, F.stateSecondMoment, ...
        F.lowerTailOccupancy, F.upperTailOccupancy};
    names = {'mean', 'median', 'secondMoment', 'lowerTailOccupancy', ...
        'upperTailOccupancy'};
    values = nan(numel(traces), size(F.stateMean, 2));
    for k = 1:numel(traces)
        values(k, :) = inversion.rhat_rank_split(traces{k});
    end
    R.names = names;
    R.values = values;
    R.maximum = max(values, [], 1);
    R.definition = 'maximum_rank_normalized_folded_split_Rhat_over_ensemble_functionals_v1';
end
