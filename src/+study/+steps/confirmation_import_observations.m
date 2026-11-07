function outcome = confirmation_import_observations(cfg, ~)
%CONFIRMATION_IMPORT_OBSERVATIONS Step 'import_observations': accept the reviewed COMSOL observations.
%   OUTCOME = study.steps.confirmation_import_observations(CFG, STEPSINCALL)
%   checks the reviewed COMSOL observations of the design of the settings
%   (B.7, confirmation.confirmation_design) in the folder
%   CFG.native.observationFiles ('ConfirmationObservationFiles'):
%     reviewed_export.csv          one row per COMSOL solve: its inputs, the
%                    probe, the three closing pressures and their QC, the
%                    solve's status
%     source_provenance.json       the COMSOL model, geometry, swelling,
%                    protocol definition and pressure extraction
%     direct_data_acceptance.json  the reviewer's acceptance
%   joins every solve to the design by its exact inputs and probe, and
%   writes to <run>/generalized/06_confirmation/data/observations
%   (CFG.native.observationsRoot) the QC of every design row
%   (observation_qc.csv), the COMSOL outcome of the solves per protocol and
%   probe (comsol_outcomes.csv), copies of the three inputs and, when every
%   design row has the QC-valid pressures of the confirmation's observation
%   design (B.7 design) or is excluded by the reviewer, the accepted
%   observations (confirmation_observations.csv, one row per design row; the
%   thesis table is data/confirmation/confirmation_observations.csv).
%   Otherwise it stops and lists the design rows that lack pressures
%   (confirmation.import_confirmation_observations). No extraction,
%   interpolation, simulation or sampling. CFG comes from
%   study.native_config.
%   OUTCOME.details records the planned and the accepted design rows.
%   Computation: seconds.
%   Side effects: writes the outputs above below the run folder.

    folder = cfg.native.observationFiles;
    result = confirmation.import_confirmation_observations(cfg, confirmation.confirmation_design(cfg), ...
        fullfile(folder, 'reviewed_export.csv'), fullfile(folder, 'source_provenance.json'), ...
        fullfile(folder, 'direct_data_acceptance.json'), cfg.native.observationsRoot);
    outcome = struct('published', true, 'details', struct('planned_rows', result.planned, ...
        'accepted_rows', result.accepted));
end
