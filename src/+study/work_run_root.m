function p = work_run_root(s)
%WORK_RUN_ROOT The run root of the configuration: a folder inside the run's bookkeeping.
%   P = study.work_run_root(S) is <run>/_run/work/<real|real_extended>/runs/<run name>.
%   The configuration of a step (study.native_config) names it as
%   CFG.paths.runRoot, from which the analysis code derives the paths it
%   records; the published results of the step are written to the
%   publication layout of the run.
%   Side effects: none.
    if strcmp(s.run.entry, 'fixed')
        route = 'real';
    else
        route = 'real_extended';
    end
    p = fullfile(s.paths.run, '_run', 'work', route, 'runs', s.run.name);
end
