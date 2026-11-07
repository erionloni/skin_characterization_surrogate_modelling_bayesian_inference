function generalized_feature_sensitivity(cfg, ~)
%GENERALIZED_FEATURE_SENSITIVITY Step 'feature_sensitivity' of the generalized route.
%   study.steps.generalized_feature_sensitivity(CFG, STEPSINCALL) computes,
%   from the approved generalized GP (the approved package of the shipped
%   results), the first- and total-order Sobol indices of the derived
%   features of the feature catalog (settings 0.7) with respect to the four
%   material and three protocol inputs, on the sample of the step
%   sensitivity's derived-feature indices (features.feature_sensitivity),
%   and writes <run>/generalized/03_sensitivity/data/features. CFG comes
%   from study.native_config.
%   Computation: about 4 minutes (UQLab predictions of the approved GP).
%   Side effects: writes the outputs above below the run folder.
    features.feature_sensitivity(cfg);
end
