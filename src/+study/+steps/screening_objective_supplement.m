function screening_objective_supplement(cfg, ~)
%SCREENING_OBJECTIVE_SUPPLEMENT Step 'objective_supplement': full covariances for the six objectives.
%   study.steps.screening_objective_supplement(CFG, STEPSINCALL)
%   re-evaluates the local information of this run's screen, with the full
%   four-parameter covariance retained, for the same protocols and material
%   points. It starts from the run's own screen: thesis_results/ does not ship the
%   screen's arrays. It checks that the screen's
%   weak-pair metrics are reproduced (to 1e-10), ranks the protocols under
%   the six objectives and writes, as in thesis_results/,
%   <run>/generalized/05_protocol_screening/data/six_objective:
%   full_covariance_supplement.mat, six_objective_rankings.csv,
%   objective_registry.csv, inputs.mat and receipt.json.
%   Runs screening.run_objective_supplement unchanged. The protocols and
%   material points are the screen's rows, taken by their IDs from the
%   seeded generators (study.screening_design). CFG comes from
%   study.native_config.
%   Computation: about 30 min for the full design (32 min recorded).
%   Side effects: writes the outputs above below the run folder.
    parent = cfg.native.screenRoot;
    saved = load(fullfile(parent, 'local_information', 'local_information.mat'), 'localInformation');
    [candidates, materials] = rows_of_screen(cfg, saved.localInformation);
    screening.run_objective_supplement(study.screening_provider(cfg), candidates, materials, ...
        parent, cfg.native.supplementRoot);
end

function [candidates, materials] = rows_of_screen(cfg, local)
%ROWS_OF_SCREEN The screen's protocols and material points, in the screen's order.
    native = cfg.native;
    native.screeningCandidates = [];
    native.screeningMaterials = [];
    full = cfg;
    full.native = native;
    [allCandidates, allMaterials] = study.screening_design(full);
    [foundC, rowsC] = ismember(string(local.CandidateIDs(:)), string(allCandidates.CandidateID));
    [foundM, rowsM] = ismember(string(local.MaterialPointIDs(:)), string(allMaterials.MaterialPointID));
    assert(all(foundC) && all(foundM), 'study:screening:ScreenRows', ...
        'The screen of this run holds protocols or material points of another design.');
    candidates = allCandidates(rowsC, :);
    materials = allMaterials(rowsM, :);
end
