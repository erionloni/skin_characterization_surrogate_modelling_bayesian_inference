function generalized_feature_accuracy(cfg, ~)
%GENERALIZED_FEATURE_ACCURACY Step 'feature_accuracy' of the generalized route: the surrogates' accuracy in feature space.
%   study.steps.generalized_feature_accuracy(CFG, STEPSINCALL) compares, for
%   the 82 external cases, every feature of the feature catalog (settings
%   0.7) computed from the GP and PCE means with the same feature computed
%   from the COMSOL pressures, from the predictions that the step
%   surrogate_assessment saved (CFG.files.validationPredictions;
%   features.feature_accuracy), and writes
%   <run>/generalized/02_surrogates/data/feature_accuracy. CFG comes from
%   study.native_config.
%   Computation: seconds.
%   Side effects: writes the outputs above below the run folder.
    features.feature_accuracy(cfg);
end
