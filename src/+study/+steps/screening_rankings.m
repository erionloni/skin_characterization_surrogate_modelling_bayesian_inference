function screening_rankings(cfg, ~)
%SCREENING_RANKINGS Step 'rankings': the six-objective rankings from the saved covariances.
%   study.steps.screening_rankings(CFG, STEPSINCALL) ranks the protocols of
%   this run's screen under the six design objectives (primary: the mean
%   largest eigenvalue of the weak-pair covariance), from the full
%   covariances that the step objective_supplement saved in
%   <run>/generalized/05_protocol_screening/data/six_objective, and writes
%   six_objective_rankings.csv and objective_registry.csv there. It computes
%   nothing but the aggregation (screening.aggregate_objectives), so a ranking
%   can be redone without recomputing the covariances. CFG comes from
%   study.native_config.
%   Computation: seconds.
%   Side effects: writes the outputs above below the run folder.
    root = cfg.native.supplementRoot;
    saved = load(fullfile(root, 'full_covariance_supplement.mat'), 'localInformation');
    local = saved.localInformation;
    native = cfg.native;
    native.screeningCandidates = [];
    native.screeningMaterials = [];
    full = cfg;
    full.native = native;
    allCandidates = study.screening_design(full);
    [found, rows] = ismember(string(local.CandidateIDs(:)), string(allCandidates.CandidateID));
    assert(all(found), 'study:screening:ScreenRows', ...
        'The supplement of this run holds protocols of another design.');
    rankings = screening.aggregate_objectives(allCandidates(rows, :), local, cfg.stage9bScreening);
    utils.atomic_write_table(fullfile(root, 'six_objective_rankings.csv'), rankings);
    utils.atomic_write_table(fullfile(root, 'objective_registry.csv'), screening.objective_registry());
end
