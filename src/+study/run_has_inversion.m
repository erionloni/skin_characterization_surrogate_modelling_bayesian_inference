function tf = run_has_inversion(s)
%RUN_HAS_INVERSION True when a run folder holds an inversion campaign of its own.
%   TF = study.run_has_inversion(S) is true when the step 'inversion'
%   completed in the run folder S.paths.run (the run record lists it) or the
%   run holds an inversion campaign (<run>/_run/inversion: for example cells
%   run in separate processes, or copied back from a cluster, before the
%   step's last call). Recovery, the design study and the ratio-error
%   curves then read that campaign; otherwise the full draws shipped in thesis_results/
%   (study.native_config). The campaigns of the conditional and the GP-mean
%   inversion (<run>/_run/inversion/conditional_inversion and
%   gp_mean_inversion) are not an inversion campaign of the run: a folder
%   that holds only these does not count.
%   Side effects: none.
    tf = ~isempty(study.run_record('step', s.paths.run, 'fixed', 'inversion'));
    if tf, return; end
    folder = fullfile(s.paths.run, '_run', 'inversion');
    if ~isfolder(folder), return; end
    entries = dir(folder);
    names = setdiff({entries.name}, {'.', '..', 'conditional_inversion', 'gp_mean_inversion'});
    tf = ~isempty(names);
end
