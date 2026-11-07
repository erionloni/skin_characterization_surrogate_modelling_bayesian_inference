function tf = placed_intermediate(runFolder, pathValue)
%PLACED_INTERMEDIATE True when a run folder holds an intermediate placed there from a recorded source.
%   TF = study.placed_intermediate(RUNFOLDER, PATH) is true when
%   RUNFOLDER/_run/placed_intermediates.csv lists PATH (below the run folder,
%   with '/') and the file exists. Full-size intermediates that thesis_results/
%   does not ship can be placed at the paths where a run writes them
%   (study.omitted_intermediates), each with its source
%   in that record; later steps then read them like outputs of the run
%   (study.plan, study.resolve_input).
%   Side effects: none.
    tf = false;
    record = fullfile(runFolder, '_run', 'placed_intermediates.csv');
    if ~isfile(record), return; end
    T = utils.read_csv_table(record, {'path', 'source'});
    tf = any(T.path == string(pathValue)) && isfile(fullfile(runFolder, strrep(pathValue, '/', filesep)));
end
