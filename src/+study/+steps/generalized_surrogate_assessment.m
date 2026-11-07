function generalized_surrogate_assessment(cfg, ~)
%GENERALIZED_SURROGATE_ASSESSMENT Step 'surrogate_assessment' of the generalized route.
%   study.steps.generalized_surrogate_assessment(CFG, STEPSINCALL) predicts
%   the 82 held-out external cases with the approved generalized GP
%   (calibrated emulator variance, gamma 0.48225) and PCE, and writes the
%   metrics, residuals, predictions, coverage and the validation record into
%   <run>/generalized/02_surrogates/data/assessment. It fits nothing: the
%   cross-validation predictions are the ones saved with the models. It
%   reads held-out outcomes, so it runs only when the call selects it (its
%   run switch, settings 0.2, or 'Steps'; CFG.stage2.evaluateExternalHoldout).
%   CFG comes from study.native_config.
%   Computation: minutes (UQLab predictions).
%   Runs the generalized assessment (surrogates.evaluate_generalized_holdout).
%   Side effects: writes the outputs above below the run folder.
    assert(logical(cfg.stage2.evaluateExternalHoldout), ...
        'study:steps:ExternalEvaluationDisabled', ...
        'The external assessment reads held-out outcomes and must be requested explicitly.');
    surrogates.evaluate_generalized_holdout(cfg);
end
