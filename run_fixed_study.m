function report = run_fixed_study(varargin)
%RUN_FIXED_STUDY Fixed-protocol study: 4 material parameters -> 6 pressures.
%   run_fixed_study() renders the fixed-route figures and tables from the
%   shipped results (Mode 'reproduce', the default).
%   run_fixed_study('Mode','rerun') recomputes the steps whose run switch is
%   true (study_settings.m, section 0.2: one switch per step and per analysis
%   inside a step; thesis: all, which is expensive); 'Steps',{...} names the
%   steps of one call instead.
%   run_fixed_study(...,'Plan',true) only prints what would run and its cost.
%
%   Steps, in dependency order (switches s.run.fixed.<step>):
%     dataset               452 cases -> 391 development / 61 external
%     surrogates            six Matern-3/2 GP and PCE surrogates
%     surrogate_assessment  predictions of the 61 held-out cases
%     surrogate_audit       (hours) kernel/seed/CV audit
%     sensitivity           Sobol and ARD sensitivity
%     inversion             (expensive, cluster) 360 AIES inversion cells
%     conditional_inversion (expensive, cluster) parameters fixed at the truth (A.9)
%     gp_mean_inversion     (expensive, cluster) the GP mean on the COMSOL data, 20 cells (A.13)
%     recovery              coverage_recovery, eigen_analysis, feature_reconstruction,
%                           error_budget (each with its own switch)
%     design_study          Fisher-information comparison of the six observation designs
%     figures               all fixed-route figures and tables
%
%   Other options: see study_settings.m and study.resolve_settings.
%   Output: <output folder>/<run name>/, with run_record.json (the calls,
%   settings and completed steps).
%
%   Examples:
%     run_fixed_study('Mode','rerun','Steps',{'dataset','surrogates'},'Plan',true)
%     run_fixed_study('Mode','rerun','Steps',{'sensitivity'},'RunName','my_run')
%
%   Side effects: changes the MATLAB path (src/; config/ and UQLab as the
%   steps need them); writes the run folder; rerun mode starts UQLab.
%   Computation: reproduce mode about 30 minutes; rerun costs per step
%   ('Plan',true).

    addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));
    report = study.run('fixed', varargin{:});
end
