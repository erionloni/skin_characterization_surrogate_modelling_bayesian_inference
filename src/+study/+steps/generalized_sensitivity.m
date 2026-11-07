function generalized_sensitivity(cfg, ~)
%GENERALIZED_SENSITIVITY Step 'sensitivity' of the generalized route.
%   study.steps.generalized_sensitivity(CFG, STEPSINCALL) computes, from the
%   approved generalized GP and PCE (the approved package of the shipped
%   results, CFG.realExtended.packageBound), the Sobol indices of the six
%   closing pressures with respect to the four material and three protocol
%   inputs, the derived cycle-drop and ratio indices, ARD importance and the
%   support audit, and writes <run>/generalized/03_sensitivity/data:
%   sensitivity.mat, primary/, supporting/, sensitivity/ and
%   metadata/. The master seed is set as the pre-publication stage set it.
%   CFG comes from study.native_config.
%   Computation: tens of minutes (UQLab predictions of the approved GP).
%   Runs sensitivity.run_generalized.
%   Side effects: writes the outputs above below the run folder.
    state = rng;
    restore = onCleanup(@() rng(state));
    rng(cfg.seed, 'twister');
    sensitivity.run_generalized(cfg);
end
