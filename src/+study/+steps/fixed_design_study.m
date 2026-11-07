function fixed_design_study(cfg, ~)
%FIXED_DESIGN_STUDY Step 'design_study' of the fixed route: Fisher-information comparison of the six observation designs.
%   study.steps.fixed_design_study(CFG, STEPSINCALL) compares the six
%   observation designs on the posteriors of this run's inversion campaign
%   (CFG.paths.stage04, that is <run>/_run/inversion) or, in a run without
%   an inversion of its own, on the full draws shipped in thesis_results/
%   (study.native_config): posterior information
%   (Gaussian-moment covariance log-volume reduction), local Fisher
%   information at the truths, and rankings with bootstrap intervals, per
%   scenario on the cases available for every design compared (missing
%   cells are explicit, never imputed). Every cell with a selected provider
%   counts, certified or a healthy fallback. It writes
%   <run>/fixed/06_design_study/data as in thesis_results/.
%   The design summary of each scenario also gets the same summary over the
%   certified cells alone, as columns with the suffix _certified_only
%   (design_study.add_certified_only_summary): the shipped draws hold healthy
%   fallbacks, so the study runs a second time on their certified providers
%   (in <run>/_run/design_study_certified_only); a run's own campaign selects
%   certified providers only, so there both summaries are the same.
%   No sampler runs. CFG comes from study.native_config.
%   Computation: about 20 min for the thesis grid (22 min recorded), twice
%   that on the shipped draws. The analysis is design_study.run_design_study.
%   Side effects: writes the outputs above below the run folder.
    design_study.run_design_study(cfg);
    certified = cfg.paths.stage06;
    if study.reads_shipped_draws(cfg)
        certified = fullfile(cfg.paths.runRoot, '_run', 'design_study_certified_only');
        alone = study.reroot(cfg, cfg.paths.stage06, certified);
        alone.native.shippedDraws.certifiedOnly = true;
        design_study.run_design_study(alone);
    end
    scenarios = inversion.scenario_registry();
    for scenario = reshape({scenarios.tag}, 1, [])
        tables = fullfile('scenarios', scenario{1}, 'tables', 'design_summary.csv');
        design_study.add_certified_only_summary(fullfile(cfg.paths.stage06, tables), ...
            fullfile(certified, tables));
    end
end
