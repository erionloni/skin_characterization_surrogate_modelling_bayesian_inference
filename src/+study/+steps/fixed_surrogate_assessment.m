function fixed_surrogate_assessment(cfg, ~)
%FIXED_SURROGATE_ASSESSMENT Step 'surrogate_assessment' of the fixed route.
%   study.steps.fixed_surrogate_assessment(CFG, STEPSINCALL) predicts the 61
%   held-out external cases with the fitted GP (calibrated emulator variance)
%   and PCE, and writes the metrics, predictions and calibration record into
%   <run>/fixed/02_surrogates/data/assessment. It reads held-out outcomes, so
%   it runs only when the call selects it (its run switch, settings 0.2, or
%   'Steps'; CFG.stage2.evaluateExternalHoldout).
%   Computation: seconds (UQLab predictions). CFG comes from
%   study.native_config.
%   Side effects: writes the outputs above below the run folder.
    assert(logical(cfg.stage2.evaluateExternalHoldout), ...
        'study:steps:ExternalEvaluationDisabled', ...
        'The external assessment reads held-out outcomes and must be requested explicitly.');
    surrogates.evaluate_external_holdout(cfg);
end
