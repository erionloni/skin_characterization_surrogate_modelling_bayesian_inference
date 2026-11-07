function io = step_io(entry, stepName)
%STEP_IO Artifacts a native step reads, and the files it writes.
%   IO = study.step_io(ENTRY, STEP) returns a struct with
%     inputs   artifact keys (study.artifacts) the step reads
%     outputs  what it writes, below the run folder ('/' separated): a
%              folder ending in '/' stands for every file below it
%   for a step of the registry (study.steps). The outputs are what the run
%   record lists for the step (study.run_record).
%   Side effects: none.

    key = [char(string(entry)) '/' char(string(stepName))];
    switch key
        case 'fixed/dataset'
            io = struct('inputs', {{}}, 'outputs', {{'fixed/01_dataset/data/'}});
        case 'fixed/surrogates'
            io = struct('inputs', {{'dataset'}}, 'outputs', {{ ...
                'fixed/02_surrogates/data/models/', ...
                'fixed/02_surrogates/data/output_training_contract.mat', ...
                'fixed/02_surrogates/data/output_training_cohorts.csv', ...
                'fixed/02_surrogates/data/assessment/external_holdout_evaluation_status.json'}});
        case 'fixed/surrogate_assessment'
            io = struct('inputs', {{'dataset', 'gp', 'pce'}}, ...
                'outputs', {{'fixed/02_surrogates/data/assessment/'}});
        case 'fixed/surrogate_audit'
            % Also the role manifest next to the dataset (study.native_config).
            io = struct('inputs', {{'dataset'}}, ...
                'outputs', {{'fixed/02_surrogates/data/audit/'}});
        case 'generalized/dataset'
            % Input: the dataset table (setting generalized.dataset.file,
            % recorded in the run record).
            io = struct('inputs', {{}}, 'outputs', {{'generalized/01_dataset/data/'}});
        case 'generalized/surrogates'
            % Per-output checkpoints, candidate fits, progress, logs and the
            % stage report stay in <run>/_run/surrogates and are not listed.
            io = struct('inputs', {{'dataset'}}, 'outputs', {{ ...
                'generalized/02_surrogates/data/surrogates/', ...
                'generalized/02_surrogates/data/models/'}});
        case 'generalized/surrogate_assessment'
            % Inputs of the generalized steps: the approved package (the
            % shipped dataset, GP and PCE and the calibration of the
            % settings, listed in the run record by study.run_native).
            io = struct('inputs', {{}}, 'outputs', {{'generalized/02_surrogates/data/assessment/'}});
        case 'generalized/default_protocol_comparison'
            io = struct('inputs', {{}}, 'outputs', {{'generalized/04_default_protocol_comparison/data/'}});
        case 'generalized/sensitivity'
            io = struct('inputs', {{}}, 'outputs', {{'generalized/03_sensitivity/data/'}});
        case 'fixed/sensitivity'
            io = struct('inputs', {{'dataset', 'gp', 'pce'}}, ...
                'outputs', {{'fixed/03_sensitivity/data/'}});
        case 'fixed/feature_accuracy'
            io = struct('inputs', {{'dataset', 'validation'}}, ...
                'outputs', {{'fixed/02_surrogates/data/feature_accuracy/'}});
        case 'generalized/feature_accuracy'
            io = struct('inputs', {{'validation_predictions'}}, ...
                'outputs', {{'generalized/02_surrogates/data/feature_accuracy/'}});
        case 'fixed/feature_sensitivity'
            io = struct('inputs', {{'gp'}}, 'outputs', {{'fixed/03_sensitivity/data/features/'}});
        case 'generalized/feature_sensitivity'
            % Input: the approved package's GP (study.run_native lists it).
            io = struct('inputs', {{}}, 'outputs', {{'generalized/03_sensitivity/data/features/'}});
        case 'fixed/inversion'
            % The sampler bookkeeping (request trees, receipts, checkpoints)
            % stays in <run>/_run/inversion and is not listed.
            io = struct('inputs', {{'dataset', 'gp'}}, ...
                'outputs', {{'fixed/04_inversion/data/'}});
        case 'fixed/conditional_inversion'
            % Bookkeeping in <run>/_run/inversion/conditional_inversion.
            io = struct('inputs', {{'dataset', 'gp'}}, ...
                'outputs', {{'fixed/07_conditional_inversion/data/'}});
        case 'fixed/gp_mean_inversion'
            % Bookkeeping in <run>/_run/inversion/gp_mean_inversion; the
            % canonical cells it is compared with come from thesis_results/.
            io = struct('inputs', {{'dataset', 'gp'}}, ...
                'outputs', {{'fixed/09_gp_mean_inversion/data/'}});
        case 'generalized/screen'
            % Inputs: the approved generalized package and the provider's
            % recorded sources (listed by study.run_native).
            io = struct('inputs', {{}}, ...
                'outputs', {{'generalized/05_protocol_screening/data/screen/'}});
        case 'generalized/objective_supplement'
            io = struct('inputs', {{'local_information'}}, ...
                'outputs', {{'generalized/05_protocol_screening/data/six_objective/'}});
        case 'generalized/rankings'
            io = struct('inputs', {{'full_covariance'}}, 'outputs', {{ ...
                'generalized/05_protocol_screening/data/six_objective/six_objective_rankings.csv', ...
                'generalized/05_protocol_screening/data/six_objective/objective_registry.csv'}});
        case 'fixed/recovery'
            % Posteriors: this run's inversion campaign (<run>/_run/inversion)
            % or, without one, the full draws shipped in thesis_results/
            % (study.run_has_inversion, study.native_config). Each cell's
            % outputs record the file its draws came from.
            io = struct('inputs', {{'dataset', 'gp', 'validation'}}, ...
                'outputs', {{'fixed/05_recovery/data/'}});
        case 'fixed/design_study'
            io = struct('inputs', {{'dataset', 'gp'}}, ...
                'outputs', {{'fixed/06_design_study/data/'}});
        case 'fixed/ratio_error_curves'
            % Posteriors as for the recovery: this run's campaign or the
            % shipped full draws (each draw file holds its observation).
            io = struct('inputs', {{'dataset', 'gp'}}, ...
                'outputs', {{'fixed/08_ratio_error_curves/data/'}});
        case 'fixed/combinations'
            % Posteriors as for the recovery: this run's campaign or the
            % shipped full draws; the GP at the truths.
            io = struct('inputs', {{'dataset', 'gp'}}, ...
                'outputs', {{'fixed/05_recovery/data/combinations/'}});
        case 'generalized/export_design'
            % Inputs: the design of the settings (B.7) with the fixed
            % dataset and, for the protocols 'from_screening', the
            % screening rankings (listed by study.run_native).
            io = struct('inputs', {{}}, 'outputs', {{'generalized/06_confirmation/data/design/'}});
        case 'generalized/import_observations'
            % Inputs: the design of the settings and the observation files
            % ('ConfirmationObservationFiles', listed by study.run_native).
            io = struct('inputs', {{}}, ...
                'outputs', {{'generalized/06_confirmation/data/observations/'}});
        case 'generalized/prepare'
            % The campaign's preparation, task table and seed schedule. The
            % observations: this run's import or the table of the setting
            % generalized.confirmation.observations.
            io = struct('inputs', {{'observations'}}, 'outputs', {{ ...
                '_run/confirmation/configuration/', '_run/confirmation/inputs/', ...
                '_run/confirmation/pairing/', '_run/confirmation/cell_grid/'}});
        case 'generalized/run_cells'
            % The request trees and cell outcome records stay in
            % <run>/_run/confirmation and are not listed.
            io = struct('inputs', {{}}, 'outputs', {{}});
        case 'generalized/combinations'
            % The confirmation's status table and draws: this run's step
            % compare or the shipped results (study.native_config).
            io = struct('inputs', {{}}, 'outputs', {{'generalized/06_confirmation/data/combinations/'}});
        case 'generalized/compare'
            io = struct('inputs', {{}}, 'outputs', {{'generalized/06_confirmation/data/campaign/', ...
                'generalized/06_confirmation/data/draws/', ...
                'generalized/06_confirmation/data/cell_status.csv'}});
        otherwise
            error('study:step_io:NotNative', ...
                'Step %s of %s does not run natively yet.', stepName, entry);
    end
end
