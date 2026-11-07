function [result, inputs, outputs] = render_run(s)
%RENDER_RUN Step 'figures' of a native rerun: render the results this run holds.
%   [RESULT, INPUTS, OUTPUTS] = study.render_run(S) renders, with the
%   renderers of reproduce mode (study.reproduce), the figures and tables of
%   every analysis of the route S.run.entry that a step of this run folder
%   produced (a step the run record lists as completed, study.run_record),
%   reading the saved results from the run
%   folder itself, never from the shipped results. A renderer that needs
%   results the run does not hold (for example the development audit when
%   'surrogate_audit' was not run) is not rendered; it is listed in
%   RESULT.skipped with the results it lacks. Any other renderer failure is
%   an error.
%   INPUTS are the outputs of the steps whose results were rendered (key:
%   the step); OUTPUTS the figures/, tables/ and README.md of every
%   rendered analysis (the run record lists both).
%   Errors before rendering when the run holds no results of the entry point.
%   Side effects: writes figures, tables and READMEs into the run folder.

    registry = study.steps(s.run.entry);
    present = {};
    inputs = struct('key', {}, 'path', {}, 'origin', {});
    for r = registry
        if strcmp(r.name, 'figures'), continue; end
        E = study.run_record('step', s.paths.run, s.run.entry, r.name);
        if isempty(E), continue; end
        present{end+1} = r.name; %#ok<AGROW>
        for output = reshape(cellstr(E.outputs), 1, [])
            inputs(end+1) = struct('key', r.name, 'path', ...
                fullfile(s.paths.run, strrep(output{1}, '/', filesep)), 'origin', 'run'); %#ok<AGROW>
        end
    end
    assert(~isempty(present), 'study:figures:NothingToRender', ...
        ['This run folder holds no results of %s to render: run the steps first, or ' ...
         'use Mode ''reproduce'' to render the shipped results.'], ...
        study.entry_function(s.run.entry));
    local = s;
    local.paths.results = s.paths.run;
    % The shipped results, for the canonical cells that a conditional campaign
    % of this run took from them (study.reproduce).
    local.run.shippedResults = s.paths.results;
    local.run.steps = present;
    local.run.inPlace = false;
    local.run.renderFromRun = true;
    result = study.reproduce(local);
    notInRun = strcmp({result.failures.identifier}, 'study:source_folder:NotInRun');
    result.skipped = result.failures(notInRun);
    failed = result.failures(~notInRun);
    if ~isempty(failed)
        error('study:figures:RendererFailed', ...
            '%d renderer call(s) failed on the results of this run. First (%s, in %s): %s', ...
            numel(failed), failed(1).renderer, failed(1).where, failed(1).message);
    end
    outputs = {};
    for i = 1:numel(result.analyses)
        outputs = [outputs, strcat(result.analyses{i}, {'/figures/', '/tables/', '/README.md'})]; %#ok<AGROW>
    end
end
