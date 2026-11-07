function screening_screen(cfg, ~)
%SCREENING_SCREEN Step 'screen' of the protocol screening.
%   study.steps.screening_screen(CFG, STEPSINCALL) evaluates, with the
%   approved generalized GP, the local Fisher information of every candidate
%   protocol (730) at every material point of the seeded Latin hypercube
%   (1000; seed CFG.stage9bScreening.materialLHSSeed), under both covariance
%   views, and ranks the protocols. It writes the screen, as in thesis_results/, to
%   <run>/generalized/05_protocol_screening/data/screen, including the full
%   local-information array (local_information/local_information.mat,
%   about 113 MB; thesis_results/ does not ship it).
%   The settings 'ScreeningCandidates' and 'ScreeningMaterials' (row indices
%   of the candidate registry and of the material design) restrict the
%   screen to a subset for tests; the run then records an incomplete design.
%   Runs screening.run_screening with the
%   provider of study.screening_provider. CFG comes from study.native_config.
%   Computation: about 1 h for the full design (55 min recorded).
%   Side effects: writes the outputs above below the run folder.
    [candidates, materials, full] = study.screening_design(cfg);
    if full
        % The full design is built by the screen itself, as in the thesis run.
        candidates = table();
        materials = table();
    end
    screening.run_screening('Configuration', cfg, 'Provider', study.screening_provider(cfg), ...
        'OutputRoot', cfg.native.screenRoot, ...
        'CandidateRegistry', candidates, 'MaterialDesign', materials, ...
        'RequireFullDesign', full, 'RenderFigures', false);
end
