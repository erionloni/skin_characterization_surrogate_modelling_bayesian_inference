function generalized_default_protocol_comparison(cfg, ~)
%GENERALIZED_DEFAULT_PROTOCOL_COMPARISON Step 'default_protocol_comparison' of the generalized route.
%   study.steps.generalized_default_protocol_comparison(CFG, STEPSINCALL)
%   evaluates the approved generalized GP and PCE at the default protocol and
%   compares them with the fixed-route COMSOL results of the 452-case dataset
%   (CFG.realExtended.defaultProtocolComparison.referenceDatasetPath). It
%   writes predictions, metrics, support and overlap tables and the
%   compatibility receipt into
%   <run>/generalized/04_default_protocol_comparison/data. It fits nothing
%   and loads no fixed-route surrogate. It reads held-out outcomes, so it
%   runs only when the call selects it (its run switch, settings 0.2, or
%   'Steps'; CFG.stage2.evaluateExternalHoldout).
%   CFG comes from study.native_config.
%   Computation: minutes (UQLab predictions).
%   Runs surrogates.run_default_protocol_cross_route.
%   Side effects: writes the outputs above below the run folder.
    assert(logical(cfg.stage2.evaluateExternalHoldout), ...
        'study:steps:ExternalEvaluationDisabled', ...
        'The default-protocol comparison reads held-out outcomes and must be requested explicitly.');
    surrogates.run_default_protocol_cross_route(cfg);
end
