function P = plan(s)
%PLAN Decide, for every step of one call, whether it runs, is reused or is missing.
%   P = study.plan(S) takes resolved settings (study.resolve_settings) and
%   returns a table with one row per step of the entry point:
%     Step, Action, Cost, Notes
%   Action is 'run' (requested), 'reuse' (needed and already present in this
%   run), 'shipped' (needed and taken from the shipped results), 'missing'
%   (needed but absent), or '' (not involved in this call). In reproduce
%   mode a requested step is 'render': its figures and tables are drawn from
%   the shipped results, and it needs no other step. A step that is not part
%   of the call says why in its Notes: switched off (its run switch, settings
%   0.2) or left out (S.run.selection: e.g. the shipped models).
%   A rerun takes a prerequisite from this run when its step completed here
%   (the run record, study.run_record), otherwise from the shipped results
%   when they hold its artifacts, or from the file a setting names for it
%   (study.artifacts: the accepted confirmation observations). With the setting
%   modelSource 'use_shipped' the models of the step 'surrogates' are always
%   the shipped ones.
%   Nothing is computed and no folder is created.
%   Side effects: none.

    registry = study.steps(s.run.entry);
    names = {registry.name};
    requested = s.run.steps;
    native = strcmp(s.run.mode, 'rerun');
    needed = requested;
    % Close the prerequisite set: every step a requested step depends on.
    % Reproduce mode reads every step's results from the shipped results, so
    % a requested step needs nothing else.
    changed = strcmp(s.run.mode, 'rerun');
    while changed
        changed = false;
        for i = 1:numel(needed)
            if native && strcmp(needed{i}, 'figures')
                % A native 'figures' renders the results this run holds
                % (study.render_run); it takes nothing from the shipped results.
                continue;
            end
            reqs = registry(strcmp(names, needed{i})).requires;
            new = setdiff(reqs, needed);
            if ~isempty(new)
                needed = [needed, new]; %#ok<AGROW>
                changed = true;
            end
        end
    end

    n = numel(registry);
    Action = repmat({''}, n, 1);
    Notes = repmat({''}, n, 1);
    for i = 1:n
        r = registry(i);
        if ismember(r.name, requested) && strcmp(s.run.mode, 'reproduce')
            Action{i} = 'render';
        elseif ismember(r.name, requested)
            Action{i} = 'run';
        elseif ismember(r.name, needed)
            if step_present(s, r, native)
                Action{i} = 'reuse';
            elseif native && step_shipped(s, r)
                Action{i} = 'shipped';
            else
                Action{i} = 'missing';
            end
        end
        notes = {};
        if strcmp(s.run.mode, 'rerun') && strcmp(Action{i}, 'run')
            if r.expensive, notes{end+1} = 'expensive'; end %#ok<AGROW>
            if r.readsHeldOut, notes{end+1} = 'reads held-out outcomes'; end %#ok<AGROW>
            if ~r.available
                notes{end+1} = 'not available yet in this version'; %#ok<AGROW>
            end
            if strcmp(s.run.entry, 'generalized') && ismember(r.name, ...
                    {'surrogate_assessment', 'default_protocol_comparison', 'sensitivity'}) && ...
                    ismember(Action{strcmp(names, 'surrogates')}, {'run', 'reuse'})
                % The approved calibration belongs
                % to the approved model, so the steps after a refit keep the
                % approved package. (The refit precedes them in the registry,
                % so its action is already set.)
                notes{end+1} = 'approved package, not the refit'; %#ok<AGROW>
            end
        elseif strcmp(Action{i}, 'shipped')
            A = study.artifacts(s.run.entry);
            A = A(strcmp({A.step}, r.name));
            if all(cellfun(@isempty, {A.setting}))
                notes{end+1} = 'from the shipped results'; %#ok<AGROW>
            else
                notes{end+1} = ['from the file of the setting ' strjoin({A.setting}, ', ')]; %#ok<AGROW>
            end
        end
        Notes{i} = strjoin(notes, '; ');
    end
    % Why a step of the route is not part of this call: its run switch
    % (settings 0.2) or a reason it was left out (study.resolve_settings).
    if isfield(s.run, 'selection')
        leftOut = s.run.selection.leftOut;
        for i = 1:n
            if ~isempty(Action{i}), continue; end
            hit = find(strcmp({leftOut.step}, names{i}), 1);
            if ~isempty(hit)
                Notes{i} = ['left out: ' leftOut(hit).reason];
            elseif strcmp(s.run.selection.source, 'switches') && ...
                    ismember(names{i}, s.run.selection.switchedOff)
                Notes{i} = sprintf('switched off (s.run.%s.%s)', s.run.entry, names{i});
            end
        end
    end
    Step = names(:);
    Cost = {registry.cost}';
    if strcmp(s.run.mode, 'reproduce')
        Cost(:) = {'rendering only'};
    elseif strcmp(s.run.scale, 'example')
        Cost = example_costs(s.run.entry, names, Cost);
    end
    P = table(Step, Action, Cost, Notes);
end

function Cost = example_costs(entry, names, Cost)
%EXAMPLE_COSTS Estimated costs of the reduced steps of an example run ('Scale','example').
    switch entry
        case 'fixed'
            E = {'inversion', 'one cell, 200/250-step chains: about 10-20 min'; ...
                'conditional_inversion', 'two cells, 200/250-step chains: about 35 min'; ...
                'gp_mean_inversion', 'one cell, 200/250-step chains: about 20 min; its best fit 2-3 min'; ...
                'recovery', 'the example cell: a few minutes'; ...
                'design_study', 'the example cell: about 2 min'};
        otherwise
            E = {'surrogates', '5 GP iterations per fit: about 17 min'; ...
                'screen', '7 protocols x 15 material points: seconds'; ...
                'objective_supplement', 'the example subset: seconds'};
    end
    for k = 1:size(E, 1)
        Cost{strcmp(names, E{k, 1})} = ['example: ' E{k, 2}];
    end
end

function tf = step_present(s, r, native)
%STEP_PRESENT True when step R completed in this run (the run record lists it,
%   study.run_record) or the run folder holds every artifact of R as an
%   intermediate placed there (study.placed_intermediate).
    tf = false;
    if ~native || (strcmp(r.name, 'surrogates') && ...
            strcmp(s.(s.run.entry).surrogates.modelSource, 'use_shipped'))
        return;
    end
    tf = ~isempty(study.run_record('step', s.paths.run, s.run.entry, r.name));
    if tf, return; end
    A = study.artifacts(s.run.entry);
    A = A(strcmp({A.step}, r.name));
    tf = ~isempty(A) && all(arrayfun(@(a) study.placed_intermediate(s.paths.run, a.path), A));
end

function tf = step_shipped(s, r)
%STEP_SHIPPED True when the shipped results (or the files the settings name)
%   hold every artifact step R writes (study.artifact_source, as
%   study.resolve_input reads them). The fixed route's surrogates count as
%   shipped only with modelSource 'use_shipped' (A.3): with a refit, the later
%   steps read this run's models. The
%   generalized steps after a refit keep the approved package (B.3).
    if strcmp(s.run.entry, 'fixed') && strcmp(r.name, 'surrogates') && ...
            ~strcmp(s.fixed.surrogates.modelSource, 'use_shipped')
        tf = false;
        return;
    end
    A = study.artifacts(s.run.entry);
    A = A(strcmp({A.step}, r.name));
    tf = ~isempty(A) && all(arrayfun(@(a) isfile(study.artifact_source(s, a)), A));
end
