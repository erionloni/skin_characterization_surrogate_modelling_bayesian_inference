function report = run_all_studies(varargin)
%RUN_ALL_STUDIES Both routes end to end.
%   run_all_studies() renders every figure and table of both routes from the
%   shipped results (Mode 'reproduce', the default), as
%   reproduce_thesis_results does.
%   run_all_studies('Mode','rerun') recomputes both routes in one run folder,
%   route by route: every step that later results build on and whose run
%   switch is true (settings 0.2), in order (the steps with endToEnd in
%   study.steps; not the side analyses: the surrogate audits, the
%   generalized refit, the conditional inversion, the ratio-error curves,
%   the parameter combinations, the feature sensitivity and the feature
%   accuracy, each printed with its own command when switched on; not the
%   fixed surrogate fit when the
%   settings use the shipped models), and then the step 'figures'. A route
%   stops before its first step that
%     - needs a computing cluster (the fixed inversion, the confirmation's
%       run_cells),
%     - needs a human decision (the confirmation's import_observations: the
%       reviewed COMSOL observations), or
%     - is expensive and 'ConfirmExpensive' is not true (the protocol
%       screen, about 1 h);
%   the figures of what the route computed are rendered, and the exact
%   commands that continue the route in the same run folder are printed.
%   With 'Scale','example' the small version of each route runs (one
%   inversion cell with short MCMC chains, a screen of 7 protocols x 15
%   material points); only the human decision stops it.
%   run_all_studies(...,'Plan',true) prints the plans without computing.
%
%   Accepts the options of run_fixed_study and run_generalized_study (see
%   study_settings.m and study.resolve_settings) except 'Steps': a route's
%   own entry point runs any subset of its steps. The run folder is
%   <output folder>/all_<UTC time> unless 'RunName' is given.
%   REPORT has one field per route (the report of study.run) and the field
%   next: the printed commands that continue the run.
%
%   Examples:
%     run_all_studies('Mode','rerun','Plan',true)
%     run_all_studies('Mode','rerun','Scale','example')
%
%   Side effects: changes the MATLAB path (src/; config/ and UQLab as the
%   steps need them); writes the run folder; rerun mode starts UQLab.
%   Computation: reproduce mode about 45 minutes; rerun mode at the thesis
%   settings about 30 minutes before the stops (with 'ConfirmExpensive',true
%   about 2 hours more: the screen and its supplement), an example about
%   30-60 minutes; 'Plan',true prints the cost of every step.

    addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));
    assert(mod(numel(varargin), 2) == 0 && ...
        all(cellfun(@(n) ischar(n) || (isstring(n) && isscalar(n)), varargin(1:2:end))), ...
        'run_all_studies:Arguments', 'The options of run_all_studies are name-value pairs.');
    names = cellfun(@char, varargin(1:2:end), 'UniformOutput', false);
    assert(~any(strcmpi(names, 'Steps')), 'run_all_studies:Steps', ...
        ['run_all_studies runs the steps of both routes end to end; run a subset with ' ...
         'run_fixed_study or run_generalized_study (''Steps'').']);
    s = study.resolve_settings('fixed', varargin{:});
    if strcmp(s.run.mode, 'reproduce')
        report = reproduce_thesis_results(varargin{:});
        return;
    end
    args = varargin;
    if ~any(strcmpi(names, 'RunName'))
        args = [args, {'RunName', ['all_' char(datetime('now', 'TimeZone', 'UTC', ...
            'Format', 'yyyyMMdd''T''HHmmss''Z'''))]}];
    end
    report = struct();
    report.next = {};
    for route = {'fixed', 'generalized'}
        s = study.resolve_settings(route{1}, args{:});
        registry = study.steps(route{1});
        chain = registry([registry.endToEnd] & [registry.available] & ...
            ~strcmp({registry.name}, 'figures'));
        if strcmp(s.(route{1}).surrogates.modelSource, 'use_shipped')
            % The thesis models are used; nothing is fitted (settings A.3, B.3).
            chain = chain(~strcmp({chain.name}, 'surrogates'));
        end
        % The run switches of the settings (0.2) choose the steps of the chain.
        on = @(r) logical(s.run.(route{1}).(r.name));
        chain = chain(arrayfun(on, chain));
        side = registry(~[registry.endToEnd] & [registry.available] & arrayfun(on, registry));
        if strcmp(s.(route{1}).surrogates.modelSource, 'use_shipped')
            side = side(~strcmp({side.name}, 'surrogates'));
        end
        if ~isempty(side)
            % Switched on, but not part of the end-to-end chain: their own calls.
            lines = side_commands(route{1}, side, s, varargin);
            fprintf('%s\n', lines{:});
            report.next = [report.next, lines];
        end
        stop = find(arrayfun(@(r) stops_route(r, s), chain), 1);
        if isempty(stop), stop = numel(chain) + 1; end
        steps = {chain(1:stop - 1).name};
        if ~isempty(steps)
            report.(route{1}) = study.run(route{1}, args{:}, 'Steps', [steps, {'figures'}]);
        end
        if stop <= numel(chain)
            lines = continuation(route{1}, chain(stop:end), s, varargin);
            fprintf('%s\n', lines{:});
            report.next = [report.next, lines];
        end
    end
end

function tf = stops_route(r, s)
%STOPS_ROUTE True when the route stops before step R: a cluster, a decision, or an unconfirmed cost.
%   An example run ('Scale','example') bounds the cost of every step, so
%   only a human decision stops it.
    example = strcmp(s.run.scale, 'example');
    tf = strcmp(r.needs, 'decision') || (~example && (strcmp(r.needs, 'cluster') || ...
        (r.expensive && ~s.run.confirmExpensive)));
end

function lines = continuation(route, rest, s, arguments)
%CONTINUATION The commands that continue a route from step REST(1) in the same run folder.
%   One command per stretch of steps that starts at a step needing a
%   cluster or a decision; each runs the route's figures afterwards.
    entry = study.entry_function(route);
    first = rest(1);
    lines = {sprintf('\n[run_all_studies] %s route: stopped before step ''%s'', which %s.', ...
        route, first.name, reason(first, s))};
    starts = [1, find(~cellfun(@isempty, {rest(2:end).needs})) + 1];
    ends = [starts(2:end) - 1, numel(rest)];
    common = kept_arguments(arguments);
    if strcmp(s.run.scale, 'example')
        lines{end+1} = '  These steps have no example; the commands run them at the thesis settings.';
    end
    for k = 1:numel(starts)
        part = rest(starts(k):ends(k));
        if k == 1
            if ~isempty(first.note), lines{end+1} = ['  ' first.note]; end %#ok<AGROW>
            lines{end+1} = '  Continue this run with:'; %#ok<AGROW>
        else
            lines{end+1} = sprintf('  then (step ''%s'' %s):', part(1).name, reason(part(1), s)); %#ok<AGROW>
            if ~isempty(part(1).note), lines{end+1} = ['  ' part(1).note]; end %#ok<AGROW>
        end
        options = '';
        if any([part.expensive]), options = ',''ConfirmExpensive'',true'; end
        if ~isempty(part(1).options), options = [options ',' part(1).options]; end %#ok<AGROW>
        stepList = strjoin(strcat('''', [{part.name}, {'figures'}], ''''), ',');
        lines{end+1} = sprintf('    %s(''Mode'',''rerun'',''RunName'',''%s''%s,''Steps'',{%s}%s)', ...
            entry, s.run.name, common, stepList, options); %#ok<AGROW>
    end
end

function lines = side_commands(route, side, s, arguments)
%SIDE_COMMANDS One command per switched-on side analysis, in the same run folder.
%   Each analysis gets its own call: the surrogate audit cannot share a call
%   with a step that reads held-out outcomes (study.run). In an example run
%   an analysis with an example version keeps the example scale.
    entry = study.entry_function(route);
    common = kept_arguments(arguments);
    example = strcmp(s.run.scale, 'example');
    lines = {sprintf(['\n[run_all_studies] %s route: %s switched on, not part of the ' ...
        'end-to-end chain; each runs with its own call:'], route, strjoin({side.name}, ', '))};
    for k = 1:numel(side)
        r = side(k);
        options = '';
        if example && r.example
            options = ',''Scale'',''example''';
        else
            if example
                lines{end+1} = sprintf('  %s has no example; the command runs it at the thesis settings.', ...
                    r.name); %#ok<AGROW>
            end
            if ~isempty(r.needs)
                lines{end+1} = sprintf('  %s %s.', r.name, reason(r, s)); %#ok<AGROW>
                if ~isempty(r.note), lines{end+1} = ['  ' r.note]; end %#ok<AGROW>
            end
            if r.expensive, options = ',''ConfirmExpensive'',true'; end
            if ~isempty(r.options), options = [options ',' r.options]; end %#ok<AGROW>
        end
        lines{end+1} = sprintf('    %s(''Mode'',''rerun'',''RunName'',''%s''%s,''Steps'',{''%s'',''figures''}%s)', ...
            entry, s.run.name, common, r.name, options); %#ok<AGROW>
    end
end

function text = reason(r, s)
    switch r.needs
        case 'cluster'
            text = sprintf('needs a computing cluster (%s)', r.cost);
        case 'decision'
            text = 'needs a human decision';
        otherwise
            if r.expensive && ~s.run.confirmExpensive
                text = sprintf('is expensive (%s) and needs ''ConfirmExpensive'',true', r.cost);
            else
                text = 'comes next';
            end
    end
end

function text = kept_arguments(arguments)
%KEPT_ARGUMENTS The call's own options that a continuation keeps, as text.
%   Mode, run name, steps, plan, scale and the confirmation of expensive
%   steps are set by each command; other options (for example
%   'OutputFolder' or 'UQLabRoot') are repeated.
    own = {'mode', 'runname', 'steps', 'plan', 'scale', 'confirmexpensive'};
    text = '';
    for k = 1:2:numel(arguments)
        name = char(arguments{k});
        if ismember(lower(name), own), continue; end
        text = [text sprintf(',''%s'',%s', name, value_text(arguments{k + 1}))]; %#ok<AGROW>
    end
end

function text = value_text(value)
    if ischar(value) || (isstring(value) && isscalar(value))
        text = ['''' strrep(char(value), '''', '''''') ''''];
    elseif islogical(value) && isscalar(value)
        text = mat2str(value);
    elseif isnumeric(value)
        text = mat2str(value);
    elseif iscellstr(value) || isstring(value)
        text = ['{' strjoin(cellfun(@value_text, cellstr(value), 'UniformOutput', false), ',') '}'];
    else
        text = sprintf('<%s>', class(value));
    end
end
