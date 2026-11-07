function folder = source_folder(cfg, key)
%SOURCE_FOLDER Folder of saved results that a renderer reads.
%   FOLDER = study.source_folder(CFG, KEY) returns the folder holding the
%   saved results named KEY (see study.layout, e.g. 'coverage' or
%   'surrogate_audit').
%   - Publication layout (CFG.layout set by reproduce mode): the folder inside
%     the shipped results, thesis_results/<route>/<NN_analysis>/data/....
%   - Numbered-stage run (no CFG.layout): the stage folder of the run, as the
%     pre-publication code wrote it.
%   Side effects: none. The folder is not checked for existence, except when
%   a rerun's own results are rendered (CFG.layout.strictSources, set by
%   study.render_run): then a missing folder is an error
%   (study:source_folder:NotInRun) naming the results the run lacks, so that
%   no renderer silently draws a partial set.

    L = study.layout();
    if is_publication(cfg)
        route = cfg.layout.route;
    elseif strcmp(cfg.dataMode, 'real')
        route = 'fixed';
    else
        route = 'generalized';
    end
    match = L.sources(strcmp({L.sources.route}, route) & strcmp({L.sources.key}, key));
    assert(isscalar(match), 'study:source_folder:UnknownKey', ...
        'No saved-result folder named "%s" is defined for the %s route (study.layout).', ...
        key, route);
    if is_publication(cfg)
        relative = match.folder;
        folder = fullfile(cfg.layout.results, strrep(relative, '/', filesep));
        if isfield(cfg.layout, 'strictSources') && cfg.layout.strictSources && ~isfolder(folder)
            error('study:source_folder:NotInRun', ...
                'This run holds no "%s" results (%s); the step that writes them was not run.', ...
                key, relative);
        end
    else
        folder = fullfile(cfg.paths.(match.legacy{1}), strrep(match.legacy{2}, '/', filesep));
    end
end

function tf = is_publication(cfg)
    tf = isfield(cfg, 'layout') && isstruct(cfg.layout) && ~isempty(cfg.layout);
end
