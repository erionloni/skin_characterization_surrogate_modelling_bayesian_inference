function [candidates, materials, full] = screening_design(cfg)
%SCREENING_DESIGN The protocols and material points a screening call uses.
%   [CANDIDATES, MATERIALS, FULL] = study.screening_design(CFG) returns the
%   candidate registry (screening.build_candidate_registry) and the seeded
%   material Latin hypercube (screening.build_material_lhs) of the thesis
%   screen, restricted to the rows CFG.native.screeningCandidates and
%   CFG.native.screeningMaterials when these are not empty (tests only).
%   FULL is true when both are complete. The rows keep the values of the
%   generators, so a subset equals the same rows of the full screen.
%   Side effects: none.
    [candidates, ~] = screening.build_candidate_registry(cfg);
    [materials, ~] = screening.build_material_lhs(cfg);
    rowsC = cfg.native.screeningCandidates;
    rowsM = cfg.native.screeningMaterials;
    assert(all(rowsC <= height(candidates)) && all(rowsM <= height(materials)), ...
        'study:screening:Subset', ['Screening subsets are row indices of the %d ' ...
        'candidate protocols and the %d material points.'], height(candidates), height(materials));
    if ~isempty(rowsC), candidates = candidates(rowsC, :); end
    if ~isempty(rowsM), materials = materials(rowsM, :); end
    full = isempty(rowsC) && isempty(rowsM);
end
