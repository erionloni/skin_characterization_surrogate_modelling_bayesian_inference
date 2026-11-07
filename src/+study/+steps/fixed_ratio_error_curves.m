function fixed_ratio_error_curves(cfg, ~)
%FIXED_RATIO_ERROR_CURVES Step 'ratio_error_curves' of the fixed route: how well the posterior draws reproduce the ratios.
%   study.steps.fixed_ratio_error_curves(CFG, STEPSINCALL) maps, on the
%   posteriors of this run's inversion campaign or, in a run without one, on
%   the full draws shipped in thesis_results/ (study.native_config), how
%   well the parameter values inside each posterior reproduce the four
%   cycle-to-cycle pressure ratios of its observation (settings A.11;
%   features.ratio_error_curves). It writes
%   <run>/fixed/08_ratio_error_curves/data as in thesis_results/. No sampler
%   runs. CFG comes from study.native_config.
%   Computation: about 2 min for the thesis cells (the GP at every draw).
%   Side effects: writes the outputs above below the run folder.
    features.ratio_error_curves(cfg);
end
