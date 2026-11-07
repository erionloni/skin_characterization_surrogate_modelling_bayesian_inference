function fixed_surrogate_audit(cfg, ~)
%FIXED_SURROGATE_AUDIT Step 'surrogate_audit' of the fixed route: the development audit of the surrogates.
%   study.steps.fixed_surrogate_audit(CFG, STEPSINCALL) repeats the audit of
%   the thesis on the 391 development cases of the dataset of this run's
%   step 'dataset' (or the shipped dataset): kernel cross-validation (3
%   kernels, 5 x 5 folds), same-data seed stability, training convergence,
%   residual distributions and correlations, variance-model comparison,
%   variance semantics and the grouped cross-fit of the emulator-variance
%   calibration. It fits its own disposable models, never loads the
%   outcomes of the 61 external cases and never replaces a canonical model.
%   It writes <run>/fixed/02_surrogates/data/audit, the layout of thesis_results/
%   (which ships the audit records that its figures and tables read). The
%   review that chose the seed of the output-6 GP was separate from the
%   audit; its seed is recorded in config/seeds/surrogate_fit_seeds.csv.
%   The audit is surrogates.run_surrogate_quality_audit. CFG comes from
%   study.native_config.
%   Computation: several hours (1050 GP and PCE fits). The thesis audit is
%   shipped as evidence and was not rerun for the publication.
%   Side effects: writes the outputs above below the run folder.
    assert(logical(cfg.stage2.runSurrogateQualityAudit) && ...
        ~logical(cfg.stage2.evaluateExternalHoldout), 'study:steps:AuditScope', ...
        ['The audit uses development cases only: it runs without a step that reads ' ...
         'held-out outcomes.']);
    surrogates.run_surrogate_quality_audit(cfg);
end
