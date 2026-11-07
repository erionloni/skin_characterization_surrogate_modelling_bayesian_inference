function outcome = fixed_surrogates(cfg, stepsInCall)
%FIXED_SURROGATES Step 'surrogates' of the fixed route: fit the six GPs and PCEs.
%   OUTCOME = study.steps.fixed_surrogates(CFG, STEPSINCALL) fits, on the
%   development cases of the dataset CFG.files.dataset, one Matern-3/2 GP
%   and one PCE per closing pressure (fixed seeds: derived from the master
%   seed, output 6 with the reviewed seed 221754153) and writes, into
%   <run>/fixed/02_surrogates/data: models/gp_surrogate.mat,
%   models/pce_surrogate.mat, output_training_contract.mat and
%   output_training_cohorts.csv. When this call does not also run
%   'surrogate_assessment', the external cases stay locked:
%   assessment/external_holdout_evaluation_status.json records that they
%   were not evaluated. CFG comes from study.native_config.
%   The later steps of the run use these models:
%   calibration v3 is bound to the training data and the fit specification,
%   not to one fitted model, so it applies to a refit on the same data. The
%   step checks that every output was fitted on the development cases the
%   calibration lists for it (surrogates.validate_calibration_data_contract)
%   and records the check in OUTCOME.details (run record).
%   OUTCOME has fields published (true) and details.
%   Computation: about 1-2 minutes (UQLab). The fit is surrogates.fit_fixed.
%   Side effects: writes the outputs above below the run folder.
    surrogates.fit_fixed(cfg);
    if ~ismember('surrogate_assessment', stepsInCall)
        surrogates.lock_external_holdout(cfg);
    end
    calibration = cfg.emulatorErrorCalibration;
    [~, name, extension] = fileparts(calibration.artifact_path);
    dataSet = utils.load_plain_mat(cfg.files.dataset, 'Y_train', 'trainCaseIDs', 'validationCaseIDs', ...
        'Y_validation');
    surrogates.validate_calibration_data_contract(calibration, dataSet, cfg.outputNames);
    outcome = struct('published', true, 'details', struct( ...
        'later_steps_use', 'the models of this run', ...
        'calibration', [name extension], ...
        'calibration_matches_training_cases', true));
end
