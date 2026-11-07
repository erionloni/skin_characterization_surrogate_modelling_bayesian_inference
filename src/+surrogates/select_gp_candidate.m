function index=select_gp_candidate(objectives,eligible)
%SELECT_GP_CANDIDATE The GP candidate with the smallest re-evaluated leave-one-out error.
%   INDEX = surrogates.select_gp_candidate(OBJECTIVES, ELIGIBLE) returns the
%   index of the eligible candidate (ELIGIBLE: logical, one per candidate)
%   with the smallest re-evaluated leave-one-out mean squared error
%   (OBJECTIVES); exact ties go to the earlier candidate (seed order).
%   Side effects: none.
    assert(isnumeric(objectives)&&isreal(objectives)&&isvector(objectives)&& ...
        islogical(eligible)&&isvector(eligible)&& ...
        numel(objectives)==numel(eligible), ...
        'surrogates:select_gp_candidate:Shape','Check failed: surrogates:select_gp_candidate:Shape.');
    objectives=objectives(:);eligible=eligible(:);
    assert(all(isfinite(objectives(eligible)))&&all(objectives(eligible)>=0), ...
        'surrogates:select_gp_candidate:EligibleObjective','Check failed: surrogates:select_gp_candidate:EligibleObjective.');
    candidates=find(eligible);
    assert(~isempty(candidates),'surrogates:select_gp_candidate:NoEligibleCandidate','Check failed: surrogates:select_gp_candidate:NoEligibleCandidate.');
    [~,local]=min(objectives(candidates));index=candidates(local);
end
