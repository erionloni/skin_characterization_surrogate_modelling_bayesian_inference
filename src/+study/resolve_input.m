function input = resolve_input(s, key)
%RESOLVE_INPUT Where a step reads one artifact: this run or the shipped results.
%   INPUT = study.resolve_input(S, KEY) returns a struct with key, path and
%   origin for artifact KEY (study.artifacts) of the call with resolved
%   settings S:
%     origin 'run'      the step that writes it completed in this run folder
%                       (the run record lists it, study.run_record); not for
%                       the models of the step 'surrogates' when the setting
%                       modelSource is 'use_shipped'
%     origin 'placed'   the run folder holds it as an intermediate placed
%                       there from a recorded source (study.placed_intermediate,
%                       e.g. the thesis intermediates that thesis_results/ does not
%                       ship)
%     origin 'shipped'  otherwise, the file at its fixed location in the
%                       shipped results (S.paths.results); not for the
%                       fixed route's models when modelSource is a refit
%                       (they must come from this run: an error)
%     origin 'data'     for an artifact that a setting names
%                       (study.artifacts: the accepted confirmation
%                       observations), the setting's file
%                       (study.artifact_source)
%   Files are read from their fixed locations.
%   Errors (study:InputMissing) name the step that produces the artifact.
%   Side effects: none.

    A = study.artifacts(s.run.entry);
    a = A(strcmp({A.key}, key));
    assert(isscalar(a), 'study:resolve_input:UnknownArtifact', 'Unknown artifact "%s".', key);
    relative = strrep(a.path, '/', filesep);

    shippedModels = strcmp(a.step, 'surrogates') && ...
        strcmp(s.(s.run.entry).surrogates.modelSource, 'use_shipped');
    if ~shippedModels && ~isempty(study.run_record('step', s.paths.run, s.run.entry, a.step))
        pathValue = fullfile(s.paths.run, relative);
        assert(isfile(pathValue), 'study:InputMissing', ...
            ['%s was written by step "%s" of this run but is missing since (%s). ' ...
             'Rerun that step.'], a.key, a.step, pathValue);
        input = struct('key', key, 'path', pathValue, 'origin', 'run');
        return;
    end
    if study.placed_intermediate(s.paths.run, a.path)
        input = struct('key', key, 'path', fullfile(s.paths.run, relative), 'origin', 'placed');
        return;
    end

    registry = study.steps(s.run.entry);
    producer = registry(strcmp({registry.name}, a.step));
    if strcmp(s.run.entry, 'fixed') && strcmp(a.step, 'surrogates') && ~shippedModels
        % With a refit (A.3), the later steps read this run's models, never the
        % shipped ones (study.plan refuses such a call before any computation).
        error('study:InputMissing', ...
            ['%s: setting fixed.surrogates.modelSource is ''%s'', so the later steps read the ' ...
             'models this run fits, and run "%s" has none. Switch the surrogates on (s.run.fixed.' ...
             'surrogates, settings 0.2) or add ''surrogates'' to ''Steps'' (%s).'], a.path, ...
            s.fixed.surrogates.modelSource, s.run.name, producer.cost);
    end
    pathValue = study.artifact_source(s, a);
    where = 'in the shipped results';
    origin = 'shipped';
    if ~isempty(a.setting)
        where = sprintf('at %s (setting %s)', pathValue, a.setting);
        origin = 'data';
    end
    assert(isfile(pathValue), 'study:InputMissing', ...
        ['%s (written by the step "%s") is neither in this run nor %s.\nProduce it with ' ...
         '%s(''Mode'',''rerun'',''Steps'',{''%s''}) (%s).'], a.path, a.step, where, ...
        study.entry_function(s.run.entry), a.step, producer.cost);
    input = struct('key', key, 'path', pathValue, 'origin', origin);
end
