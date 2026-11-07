function p = portable_path(source, layout)
%PORTABLE_PATH Path of a figure or table source without the folders of this computer.
%   P = study.portable_path(SOURCE, LAYOUT) returns
%     thesis_results/<path>   for a file of the shipped results (LAYOUT.results),
%     <path>           relative to the run folder (LAYOUT.run) for the
%                      intermediate tables a renderer computed in this run,
%     <path>           relative to the repository for data/ and config/ files.
%   Any other location is refused: reproduce mode reads nothing else. The
%   renderers' manifest rows and the README of an analysis name their
%   sources this way.
%   Side effects: none.

    source = utils.absolute_path(source);
    results = [utils.absolute_path(layout.results) filesep];
    repository = [utils.absolute_path(study.root()) filesep];
    run = [utils.absolute_path(layout.run) filesep];
    if strncmpi(source, results, numel(results))
        p = ['thesis_results/' strrep(source(numel(results)+1:end), '\', '/')];
    elseif strncmpi(source, run, numel(run))
        p = strrep(source(numel(run)+1:end), '\', '/');
    elseif strncmpi(source, repository, numel(repository))
        p = strrep(source(numel(repository)+1:end), '\', '/');
    else
        error('study:portable_path:SourceOutside', ...
            ['A figure or table source lies outside the shipped results, the ' ...
             'repository and the run folder: %s'], source);
    end
end
