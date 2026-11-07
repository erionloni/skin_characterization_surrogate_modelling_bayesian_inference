function fixed_recovery(cfg, ~)
%FIXED_RECOVERY Step 'recovery' of the fixed route: what the posteriors of this run recover.
%   study.steps.fixed_recovery(CFG, STEPSINCALL) summarizes the posteriors
%   of this run's inversion campaign (CFG.paths.stage04, that is
%   <run>/_run/inversion) or, in a run without an inversion of its own, the
%   full draws of both replicates shipped in thesis_results/
%   (study.native_config): per cell and parameter the posterior width,
%   contraction, truth inclusion (50% and 95%) and recovery error, their
%   summaries by scenario and design, the posterior covariance
%   eigendecomposition, the feature reconstruction and the downstream error
%   budget. Every cell with a selected provider counts, certified or a
%   healthy fallback of the shipped draws (a run's own campaign selects
%   certified providers only); the status of every cell is in
%   tables/posterior_cell_status.csv. It writes <run>/fixed/05_recovery/data:
%   tables/, eigen_analysis/, feature_reconstruction/ and
%   analysis_scope.json, as in thesis_results/. Cells without a provider
%   (unresolved, or not run in a partial campaign) stay explicit rows with
%   NaN metrics. No sampler runs.
%   CFG comes from study.native_config.
%   Computation: minutes to about 1 h for the thesis grid (GP evaluations
%   at posterior draws). The analysis is recovery.run_recovery.
%   Side effects: writes the outputs above below the run folder.
    recovery.run_recovery(cfg);
end
