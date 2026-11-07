function fixed_combinations(cfg, ~)
%FIXED_COMBINATIONS Step 'combinations' of the fixed route: the parameter combinations the posteriors determine.
%   study.steps.fixed_combinations(CFG, STEPSINCALL) analyses, per cell of
%   the settings (A.12) and per replicate, the combinations of the four
%   parameters that the posterior determines and the compensation that the
%   GP predicts at the truth (recovery.parameter_combinations), on this
%   run's inversion campaign or on the shipped full draws, and writes
%   <run>/fixed/05_recovery/data/combinations. CFG comes from
%   study.native_config.
%   Computation: about a minute.
%   Side effects: writes the outputs above below the run folder.
    recovery.parameter_combinations(cfg);
end
