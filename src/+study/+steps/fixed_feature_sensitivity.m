function fixed_feature_sensitivity(cfg, ~)
%FIXED_FEATURE_SENSITIVITY Step 'feature_sensitivity' of the fixed route: Sobol indices of the derived features.
%   study.steps.fixed_feature_sensitivity(CFG, STEPSINCALL) computes, from
%   the GP of CFG.files.gp, the first- and total-order Sobol indices of the
%   derived features of the feature catalog (settings 0.7) with respect to
%   the four material parameters, on the sample of the step sensitivity's
%   ratio indices (features.feature_sensitivity), and writes
%   <run>/fixed/03_sensitivity/data/features. CFG comes from
%   study.native_config.
%   Computation: about a minute (UQLab predictions).
%   Side effects: writes the outputs above below the run folder.
    features.feature_sensitivity(cfg);
end
