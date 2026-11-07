function report = run(entry, varargin)
%RUN Run the named steps of one route.
%   REPORT = study.run(ENTRY, NAME, VALUE, ...) is what run_fixed_study,
%   run_generalized_study, run_all_studies and reproduce_thesis_results
%   call. ENTRY is 'fixed' or 'generalized' (the protocol screening and the
%   confirmation are steps of the generalized route); the name-value
%   arguments are described in study.resolve_settings.
%
%   Order of work:
%     1. resolve settings and build the plan (study.plan);
%     2. print the plan; with 'Plan',true also say whether step 3 would
%        refuse the call, and why, then stop;
%     3. refuse, before any computation, when a prerequisite is missing, an
%        expensive step is not confirmed, a step is not available, UQLab is
%        missing, the shipped results are missing (reproduce), the fixed
%        dataset does not match the frozen calibration, or the settings
%        give no configuration (study.project_config: e.g. a manual GP that
%        the emulator calibration was not fitted for);
%     4. reproduce: render figures and tables from the shipped results
%        (study.reproduce); rerun: run the steps;
%     5. record the call and every step it completed in
%        <run>/run_record.json (study.run_record) and write the README.md of
%        the results folder (study.write_results_readme: the run folder, or
%        thesis_results/ for a render in place).
%
%   REPORT is a struct with the settings, the plan, the path of the run
%   record and, after a run, the run record's elements of the completed
%   steps (rerun) or the rendered figures (reproduce).
%
%   Side effects: creates runs/<run name>/ and writes the steps'
%   outputs there (not in plan mode); changes the MATLAB path
%   (study.reproduce, study.activate_environment) and, in rerun mode,
%   starts UQLab.
%   Computation: that of the steps ('Plan' prints it); in rerun mode it may
%   fit surrogates or run other computation.

    s = study.resolve_settings(entry, varargin{:});
    P = study.plan(s);
    report = struct('settings', s, 'plan', P, 'steps', struct(), 'record', '');
    say(s, 'info', '%s', plan_text(s, P));
    if s.run.plan
        % The checks of the call only read; nothing is computed or written.
        try
            check_ready(s, P);
        catch err
            say(s, 'info', 'The call would be refused: %s\n', err.message);
        end
        say(s, 'info', 'Plan only: nothing was computed.\n');
        return;
    end
    check_ready(s, P);
    % Figure styles set while the steps run are undone afterwards (CLN-058).
    graphics = plotting.preserve_graphics_defaults(); %#ok<NASGU>

    call = call_record(s, P, varargin);
    index = study.run_record('start', s, call);
    report.record = fullfile(s.paths.run, 'run_record.json');
    try
        if strcmp(s.run.mode, 'reproduce')
            rendered = study.reproduce(s);
            finished = struct('analyses_rendered', {rendered.analyses}, ...
                'figures_written', height(rendered.figures), ...
                'renderer_failures', {num2cell(reshape(rendered.failures, 1, []))});
            report.figures = rendered.figures;
            if ~isempty(rendered.failures)
                error('study:RenderingFailed', ...
                    ['%d renderer call(s) failed; the other figures were written. ' ...
                     'First failure (%s, in %s): %s'], numel(rendered.failures), ...
                    rendered.failures(1).renderer, rendered.failures(1).where, ...
                    rendered.failures(1).message);
            end
        else
            report.steps = study.run_native(s, P, index);
            finished = struct('steps_completed', {reshape(fieldnames(report.steps), 1, [])});
        end
    catch err
        failed = struct('status', 'failed', 'finished_utc', utc_now(), 'error', ...
            struct('identifier', err.identifier, 'message', err.message));
        if strcmp(s.run.mode, 'reproduce') && exist('finished', 'var')
            failed = merge(finished, failed);
        elseif strcmp(s.run.mode, 'rerun')
            failed.steps_completed = completed_in_call(s, index);
        end
        study.run_record('finish', s, index, failed);
        rethrow(err);
    end
    study.run_record('finish', s, index, merge(finished, ...
        struct('status', 'complete', 'finished_utc', utc_now())));
    study.write_results_readme(study.output_root(s), s);
    say(s, 'info', '[study] %s complete. Run folder: %s\n', ...
        study.entry_function(s.run.entry), s.paths.run);
end

function names = completed_in_call(s, index)
%COMPLETED_IN_CALL The steps that call INDEX completed before it failed (study.run_record).
    R = study.run_record('read', s.paths.run);
    names = {};
    if isempty(R), return; end
    mine = cellfun(@(e) isequal(double(e.call), index), R.steps);
    names = cellfun(@(e) e.step, R.steps(mine), 'UniformOutput', false);
end

function a = merge(a, b)
%MERGE The fields of B added to A.
    for name = reshape(fieldnames(b), 1, [])
        a.(name{1}) = b.(name{1});
    end
end

function check_shipped_draws(s, posteriorSteps)
%CHECK_SHIPPED_DRAWS Refuse cases for which the shipped full posterior draws hold no cells.
    index = fullfile(s.paths.results, 'fixed', '04_inversion', 'data', 'draws', ...
        'index.csv');
    if ~isfile(index)
        error('study:MissingPrerequisite', ...
            ['%s rerun(s) on the posterior draws of this run''s inversion or on the shipped ' ...
             'full draws; run "%s" has no inversion and %s holds no shipped draws. Point ' ...
             '''ResultsFolder'' to the thesis_results/ folder of the repository, or run the ' ...
             'inversion in this run first.'], strjoin(posteriorSteps, ', '), s.run.name, ...
            fileparts(index));
    end
    T = utils.read_csv_table(index, {'CellID'});
    shipped = unique(double(T.CaseID)).';
    outside = setdiff(double(s.advanced.cases), shipped);
    if ~isempty(outside)
        error('study:MissingPrerequisite', ...
            ['%s rerun(s) on the shipped full posterior draws, which hold the cases %s; ' ...
             'case(s) %s have none. Choose ''Cases'' among them, or run the inversion of ' ...
             'these cases in this run first.'], strjoin(posteriorSteps, ', '), ...
            strjoin(string(shipped), ' '), strjoin(string(outside), ' '));
    end
end

function check_ready(s, P)
%CHECK_READY Refuse, before any computation, a call that cannot succeed.
    entryFunction = study.entry_function(s.run.entry);
    if strcmp(s.run.mode, 'reproduce')
        % Reproduce reads the shipped results only: no prerequisite steps,
        % no UQLab, no confirmation of expensive steps.
        A = study.analyses();
        A = A(strcmp({A.entry}, entryFunction));
        absent = A(arrayfun(@(a) ~isfolder(fullfile(s.paths.results, a.route, a.folder)), A));
        if ~isfile(fullfile(s.paths.results, 'README.md')) || ~isempty(absent)
            error('study:ResultsMissing', ...
                ['Mode ''reproduce'' reads the shipped results, but "%s" does not ' ...
                 'hold them. Point ''ResultsFolder'' to the thesis_results/ folder of the ' ...
                 'repository, or run check_installation.'], s.paths.results);
        end
        return;
    end
    registry = study.steps(s.run.entry);
    missing = P.Step(strcmp(P.Action, 'missing'));
    running = P.Step(strcmp(P.Action, 'run'));
    if strcmp(s.run.entry, 'fixed') && ismember('inversion', missing) && ...
            ismember('conditional_inversion', running)
        % The conditional inversion compares with the canonical all_six cells:
        % those of the finalized inversion campaign of this run, or the shipped
        % ones (study.native_config).
        error('study:MissingPrerequisite', ...
            ['conditional_inversion compares with the canonical all_six cells of the finalized ' ...
             'inversion campaign of this run or of the shipped results, and run "%s" has neither. ' ...
             'Run the inversion in this run first, for example\n' ...
             '  %s(''Mode'',''rerun'',''RunName'',''%s'',''Steps'',{''inversion''},' ...
             '''ConfirmExpensive'',true)\nor add ''inversion'' to ''Steps''.'], ...
            s.run.name, entryFunction, s.run.name);
    end
    posteriorSteps = intersect(running, {'recovery', 'design_study'});
    if strcmp(s.run.entry, 'fixed') && ~isempty(posteriorSteps) && ...
            ~ismember('inversion', running) && ~study.run_has_inversion(s)
        % Without an inversion of its own, the run reads the full posterior
        % draws shipped in thesis_results/ (study.native_config).
        check_shipped_draws(s, posteriorSteps);
    end
    if ~isempty(missing)
        error('study:MissingPrerequisite', ...
            ['Cannot run %s: it needs the results of %s, which are neither ' ...
             'computed in this call nor present in run "%s" nor shipped.\nSwitch them on ' ...
             '(%s in study_settings.m, section 0.2) or add them to ''Steps'', or produce ' ...
             'them first, for example:\n  %s(''Steps'',{%s},''Mode'',''rerun'',''RunName'',''%s'')'], ...
            strjoin(s.run.steps, ', '), strjoin(missing', ', '), s.run.name, ...
            switch_names(s, missing'), entryFunction, quoted_list(missing'), s.run.name);
    end
    running = registry(ismember({registry.name}, P.Step(strcmp(P.Action, 'run'))));
    unavailable = running(~[running.available]);
    if ~isempty(unavailable)
        error('study:StepNotAvailable', ...
            ['Step(s) %s cannot be rerun with %s: their results are shipped as ' ...
             'evidence (use Mode ''reproduce'').'], ...
            strjoin({unavailable.name}, ', '), entryFunction);
    end
    if ismember('surrogate_audit', {running.name}) && any([running.readsHeldOut])
        error('study:IncompatibleSteps', ...
            ['The surrogate audit uses development cases only and cannot run in the ' ...
             'same call as a step that reads held-out outcomes (%s). Run it separately ' ...
             '(''Steps'',{''surrogate_audit''}), or switch it off for this call''s steps ' ...
             '(s.run.%s.surrogate_audit = false, study_settings.m section 0.2).'], ...
            strjoin({running([running.readsHeldOut]).name}, ', '), s.run.entry);
    end
    check_analysis_switches(s, running);
    expensive = running([running.expensive]);
    % An example run bounds the cost of every step ('Scale','example').
    if ~isempty(expensive) && ~s.run.confirmExpensive && ~strcmp(s.run.scale, 'example')
        lines = arrayfun(@(r) sprintf('  %s: %s', r.name, r.cost), expensive, ...
            'UniformOutput', false);
        error('study:ConfirmExpensive', ...
            ['These steps are expensive:\n%s\nRun them only when intended, with ' ...
             '''ConfirmExpensive'',true, or leave them out: switch them off (%s in ' ...
             'study_settings.m, section 0.2) or name the steps to run in ''Steps''.'], ...
            strjoin(lines, newline), switch_names(s, {expensive.name}));
    end
    if strcmp(s.run.entry, 'fixed') && ismember('inversion', {running.name})
        check_inversion_settings(s);
    end
    check_surrogate_settings(s, running);
    campaign = study.inversion_campaign(s.paths.run);
    if strcmp(s.run.entry, 'fixed') && ~isempty(campaign) && ~isempty(s.advanced.cases) && ...
            ~isequal(sort(s.advanced.cases), sort(campaign.caseIDs)) && ...
            any(ismember({running.name}, {'inversion', 'conditional_inversion', 'recovery', 'design_study', ...
            'ratio_error_curves', 'combinations', 'gp_mean_inversion'}))
        error('study:settings:CasesDiffer', ...
            ['Run "%s" holds the inversion campaign of cases %s; ''Cases'' %s differs. Use ' ...
             'the same cases, or a new run folder for another campaign.'], s.run.name, ...
            mat2str(campaign.caseIDs), mat2str(s.advanced.cases));
    end
    if strcmp(s.run.entry, 'fixed') && ~isempty(campaign) && ...
            any(ismember({running.name}, {'inversion', 'conditional_inversion'})) && ...
            ~isequal(campaign.demonstrationSteps, reshape(s.advanced.demonstrationSteps, 1, []))
        % A campaign's requests keep their level names when the chains are
        % shortened; mixing chain lengths in one campaign would mix evidence.
        error('study:settings:DemonstrationStepsDiffer', ...
            ['Run "%s" holds an inversion campaign %s, and this call would run it %s. ' ...
             'Continue the campaign with the same ''DemonstrationSteps'' (or ''Scale''), ' ...
             'or use a new run folder.'], s.run.name, ...
            chain_text(campaign.demonstrationSteps), chain_text(s.advanced.demonstrationSteps));
    end
    check_campaign_chains(s, running);
    check_confirmation_inputs(s, running);
    if isequal({running.name}, {'figures'}) && ...
            ~any(arrayfun(@(r) ~isempty(study.run_record('step', s.paths.run, ...
                s.run.entry, r.name)), registry))
        % A rerun's 'figures' renders the results of this run (study.render_run).
        error('study:figures:NothingToRender', ...
            ['Run "%s" holds no results of %s to render: run the steps first, or use ' ...
             'Mode ''reproduce'' to render the shipped results.'], s.run.name, entryFunction);
    end
    if isempty(s.paths.uqlabRoot) || ~isfolder(s.paths.uqlabRoot)
        error('study:UQLabMissing', ...
            ['Mode ''rerun'' needs UQLab. Set s.paths.uqlabRoot in ' ...
             'study_settings.m (or the UQLAB_ROOT environment variable), or pass ' ...
             '''UQLabRoot''. Current value: "%s".'], s.paths.uqlabRoot);
    end
    if strcmp(s.run.entry, 'fixed') && ismember('dataset', {running.name})
        study.check_fixed_dataset(study.fixed_dataset_file(s), ...
            study.settings_path(s, s.fixed.surrogates.emulatorCalibration), ...
            s.fixed.dataset.groupColumn);
    end
    if strcmp(s.run.entry, 'generalized') && ismember('dataset', {running.name})
        f = study.settings_path(s, s.generalized.dataset.file);
        assert(isfile(f), 'study:GeneralizedDatasetMissing', ...
            ['The generalized dataset was not found: %s\nRestore data/generalized/ from the ' ...
             'repository, or set generalized.dataset.file in study_settings.m.'], f);
    end
    check_configuration(s, running);
end

function check_configuration(s, running)
%CHECK_CONFIGURATION Refuse, before the run folder exists, settings that give no configuration.
%   Every step's configuration (study.native_config) is derived from the
%   settings by study.project_config, which loads and checks the records the
%   settings select: the emulator calibration against the GP (a manual GP
%   needs a calibration fitted for it, settings A.3 and B.3) and, for the
%   generalized steps after the dataset and the refit, the approved package.
%   A confirmation step also builds the design of the settings (B.7,
%   confirmation.confirmation_design: materials in the fixed dataset,
%   truths and protocols within the bounds; the protocols 'from_screening'
%   from the shipped rankings). It only reads, so it is built here once.
    route = 'real';
    if strcmp(s.run.entry, 'generalized'), route = 'real_extended'; end
    args = {'Route', route, 'RunRoot', study.work_run_root(s)};
    if strcmp(route, 'real_extended') && ~all(ismember({running.name}, {'dataset', 'surrogates'}))
        args = [args, {'BindGeneralizedPackage', true}];
    end
    cfg = study.project_config(s, args{:});
    if any(ismember({running.name}, {'export_design', 'import_observations', 'prepare'}))
        confirmation.confirmation_design(cfg);
    end
end

function check_campaign_chains(s, running)
%CHECK_CAMPAIGN_CHAINS A conditional, GP-mean or confirmation campaign continues with the chains it was prepared with.
%   Their preparation records the demonstration chain lengths
%   ('DemonstrationSteps'; none for full chains). A call that runs cells of
%   such a campaign with other lengths is refused, as for the inversion
%   campaign: mixing chain lengths in one campaign would mix evidence (the
%   confirmation's cells run with the chains of their prepared campaign, so
%   another value would not apply).
    names = {running.name};
    prepared = cell(0, 2);
    if strcmp(s.run.entry, 'fixed') && ismember('conditional_inversion', names)
        prepared(end+1, :) = {fullfile(s.paths.run, '_run', 'inversion', 'conditional_inversion', ...
            'orchestration', 'conditional_campaign_preparation.json'), 'a conditional campaign'};
    end
    if strcmp(s.run.entry, 'fixed') && ismember('gp_mean_inversion', names)
        prepared(end+1, :) = {fullfile(s.paths.run, '_run', 'inversion', 'gp_mean_inversion', ...
            'campaign_preparation.json'), 'a GP-mean campaign'};
    end
    if strcmp(s.run.entry, 'generalized') && ismember('run_cells', names)
        prepared(end+1, :) = {fullfile(s.paths.run, '_run', 'confirmation', 'configuration', ...
            'confirmation_preparation.json'), 'a confirmation campaign'};
    end
    asked = reshape(double(s.advanced.demonstrationSteps), 1, []);
    for k = 1:size(prepared, 1)
        if ~isfile(prepared{k, 1}), continue; end
        record = jsondecode(fileread(prepared{k, 1}));
        if ~isfield(record, 'demonstrationSteps'), continue; end
        steps = reshape(double(record.demonstrationSteps), 1, []);
        if ~isequal(steps, asked)
            error('study:settings:DemonstrationStepsDiffer', ...
                ['Run "%s" holds %s %s, and this call would run it %s. Continue the campaign with ' ...
                 'the same ''DemonstrationSteps'' (or ''Scale''), or use a new run folder.'], ...
                s.run.name, prepared{k, 2}, chain_text(steps), chain_text(asked));
        end
    end
end

function text = chain_text(steps)
%CHAIN_TEXT The MCMC chain lengths of a campaign, in words.
    if isempty(steps)
        text = 'with full chains (2000 and 5000 steps)';
    else
        text = sprintf('with demonstration chains of %s steps', mat2str(steps));
    end
end

function check_inversion_settings(s)
%CHECK_INVERSION_SETTINGS The inversion's cell selection and demonstration lengths are usable.
    cases = numel(s.advanced.cases);
    if cases == 0, cases = 20; end
    cells = s.advanced.inversionCells;
    n = cases * 18;   % 3 scenarios x 6 designs per case
    if isnumeric(cells) && any(cells > n)
        error('study:settings:InversionCells', ...
            ['''InversionCells'' are indices of the inversion grid of %d cells (%d cases ' ...
             'x 3 scenarios x 6 designs); got %s.'], n, cases, mat2str(cells));
    end
    steps = s.advanced.demonstrationSteps;
    if ~isempty(steps) && ~(numel(steps) == 2 && all(steps < [2000 5000]))
        error('study:settings:DemonstrationSteps', ...
            ['''DemonstrationSteps'' gives one chain length per MCMC level, each shorter ' ...
             'than its level (2000 and 5000 steps); got %s.'], mat2str(steps));
    end
end

function check_surrogate_settings(s, running)
%CHECK_SURROGATE_SETTINGS The outputs and demonstration budget of a generalized refit are usable.
    outputs = s.advanced.surrogateOutputs;
    iterations = s.advanced.demonstrationGPIterations;
    refit = strcmp(s.run.entry, 'generalized') && ismember('surrogates', {running.name});
    if ~refit && (isnumeric(outputs) || ~isempty(iterations))
        error('study:settings:SurrogateRefit', ...
            ['''SurrogateOutputs'' and ''DemonstrationGPIterations'' apply to the step ' ...
             '''surrogates'' of run_generalized_study only.']);
    end
    if isnumeric(outputs) && any(outputs > 6)
        error('study:settings:SurrogateOutputs', ...
            '''SurrogateOutputs'' are indices of the six closing pressures (1 to 6); got %s.', ...
            mat2str(outputs));
    end
    if ~isempty(iterations) && iterations >= 20
        error('study:settings:DemonstrationGPIterations', ...
            ['''DemonstrationGPIterations'' limits every GP optimization to fewer iterations ' ...
             'than the thesis fits used (UQLab''s default of 20); got %d.'], iterations);
    end
end

function check_confirmation_inputs(s, running)
%CHECK_CONFIRMATION_INPUTS The observation files of the confirmation are complete.
%   The design and the accepted observations of a run are written once:
%   a step that would overwrite them is refused. The design itself is
%   checked with the configuration (check_configuration).
    running = running(strcmp({running.group}, 'confirmation'));
    names = {running.name};
    if ismember('export_design', names)
        written(s, fullfile('generalized', '06_confirmation', 'data', 'design'), 'a confirmation design');
    end
    if ismember('import_observations', names)
        folder = s.advanced.confirmationObservationFiles;
        need = {'reviewed_export.csv', 'source_provenance.json', 'direct_data_acceptance.json'};
        if isempty(folder)
            lacking = need;
        else
            lacking = need(~cellfun(@(f) isfile(fullfile(folder, f)), need));
        end
        if ~isempty(lacking)
            error('study:confirmation:ObservationFiles', ...
                ['''import_observations'' needs ''ConfirmationObservationFiles'': a folder with ' ...
                 'the reviewed COMSOL export of the design (reviewed_export.csv, one row per ' ...
                 'solve), the COMSOL provenance (source_provenance.json) and the acceptance ' ...
                 'record (direct_data_acceptance.json). Missing: %s. Without them, leave the ' ...
                 'confirmation''s steps after export_design out: switch them off (%s in ' ...
                 'study_settings.m, section 0.2) or name the steps to run in ''Steps''.'], ...
                strjoin(lacking, ', '), switch_names(s, {'import_observations', 'prepare', ...
                'run_cells', 'compare'}));
        end
        written(s, fullfile('generalized', '06_confirmation', 'data', 'observations'), ...
            'imported confirmation observations');
    end
    cells = s.advanced.confirmationCells;
    prepared = fullfile(s.paths.run, '_run', 'confirmation', 'configuration', ...
        'confirmation_preparation.json');
    if ismember('run_cells', names) && isnumeric(cells) && isfile(prepared)
        count = double(jsondecode(fileread(prepared)).cellCount);
        if any(cells > count)
            error('study:settings:ConfirmationCells', ...
                ['''ConfirmationCells'' are task indices of the campaign prepared in run "%s" ' ...
                 '(1 to %d, _run/confirmation/cell_grid/confirmation_task_table.csv); got %s.'], ...
                s.run.name, count, mat2str(cells));
        end
    end
    if ismember('run_cells', names) && ispc
        % The deepest file of a cell: aies/<protocol>/posteriors/<scenario>/
        % <design>/case_<CaseID>/aies/replicate_02/posterior_samples_5000.mat.
        C = s.generalized.confirmation;
        if iscell(C.protocols)
            label = max(cellfun(@numel, C.protocols(:, 1)));
        else
            % 'from_screening': labels <role>_focused of the objectives.
            label = max(strlength(screening.objective_registry().ConfirmationRole)) - 1;
        end
        digits = 6;
        if isnumeric(C.materials), digits = numel(sprintf('%d', max(C.materials))); end
        longest = numel(fullfile(s.paths.run, '_run', 'confirmation')) + 96 + label + digits;
        if longest > 259
            error('study:confirmation:PathTooLong', ...
                ['The confirmation cells of run "%s" would write paths of about %d characters; ' ...
                 'Windows allows 259. Use a shorter ''OutputFolder'' or ''RunName''.'], ...
                s.run.name, longest);
        end
    end
end

function written(s, relative, what)
%WRITTEN Refuse to write into a folder of the run that already holds results.
    folder = fullfile(s.paths.run, relative);
    if isfolder(folder) && numel(dir(folder)) > 2
        error('study:confirmation:AlreadyWritten', ...
            ['Run "%s" already holds %s (%s), which is never overwritten. Use a new ' ...
             'run folder (''RunName'').'], s.run.name, what, folder);
    end
end

function m = call_record(s, P, arguments)
%CALL_RECORD The run record's element of this call (study.run_record).
%   The entry point, mode, scale, the steps of the plan, the name-value
%   arguments of the call, the complete settings, the code version and the
%   MATLAB and UQLab versions (provenance, not a check), and a
%   demonstration notice for reduced settings.
    m = struct();
    m.entry_point = study.entry_function(s.run.entry);
    m.mode = s.run.mode;
    m.scale = s.run.scale;
    m.steps_requested = s.run.steps;
    m.steps_run = P.Step(strcmp(P.Action, 'run'))';
    m.steps_reused = P.Step(strcmp(P.Action, 'reuse'))';
    m.steps_from_shipped_results = P.Step(strcmp(P.Action, 'shipped'))';
    m.status = 'running';
    m.started_utc = utc_now();
    m.finished_utc = '';
    m.arguments = name_values(arguments);
    m.settings = rmfield(s, {'provenance'});
    m.code = rmfield(study.code_version(s.paths.repository), 'repository');
    m.environment = utils.environment_line(s.paths.uqlabRoot);
    m.uqlab_root_source = s.provenance.uqlabRootSource;
    reduced = {};
    if strcmp(s.run.scale, 'example')
        reduced{end+1} = 'an example run (''Scale'',''example'')';
    end
    if ~isempty(s.advanced.screeningCandidates) || ~isempty(s.advanced.screeningMaterials)
        reduced{end+1} = 'a protocol screen of a subset';
    end
    if ~isempty(s.advanced.demonstrationSteps)
        reduced{end+1} = sprintf('MCMC chains shortened to %s steps per level', ...
            mat2str(s.advanced.demonstrationSteps));
    end
    if ~isempty(s.advanced.demonstrationGPIterations)
        reduced{end+1} = sprintf('GP optimizations limited to %d iterations', ...
            s.advanced.demonstrationGPIterations);
    end
    if ~isempty(reduced)
        m.demonstration = [strjoin(reduced, '; ') ': a demonstration, not thesis evidence'];
    end
end

function v = name_values(arguments)
%NAME_VALUES The name-value arguments of a call as a struct (a repeated name: its last value).
%   A 'Settings' struct is named only: the record keeps the complete
%   settings of the call (settings).
    v = struct();
    for k = 1:2:numel(arguments) - 1
        value = arguments{k + 1};
        if strcmpi(char(string(arguments{k})), 'Settings') && isstruct(value)
            value = 'a settings struct (the settings of this call)';
        end
        v.(char(string(arguments{k}))) = value;
    end
end

function text = plan_text(s, P)
%PLAN_TEXT The plan as printed: the steps of the call, and the steps switched off or left out with why.
    rows = P(~strcmp(P.Action, '') | ~strcmp(P.Notes, ''), :);
    lines = {sprintf('\n[study] Plan for %s (mode: %s, scale: %s, run: %s)', ...
        study.entry_function(s.run.entry), s.run.mode, s.run.scale, s.run.name)};
    lines{end+1} = sprintf('        Run folder: %s', s.paths.run);
    if strcmp(s.run.selection.source, 'Steps')
        lines{end+1} = ['        Steps chosen by ''Steps'' (for this call, instead of the run ' ...
            'switches of the settings, 0.2)'];
    else
        lines{end+1} = '        Steps chosen by the run switches of the settings (0.2)';
    end
    off = switched_off_analyses(s);
    if ~isempty(off)
        lines{end+1} = sprintf('        Analyses switched off inside these steps: %s', strjoin(off, ', '));
    end
    lines{end+1} = sprintf('        %-28s %-8s %-45s %s', 'Step', 'Action', 'Estimated cost', 'Notes');
    for i = 1:height(rows)
        action = rows.Action{i};
        cost = rows.Cost{i};
        if isempty(action), action = '-'; cost = ''; end
        lines{end+1} = sprintf('        %-28s %-8s %-45s %s', rows.Step{i}, ...
            action, cost, rows.Notes{i}); %#ok<AGROW>
    end
    text = [strjoin(lines, newline) newline];
end

function text = switch_names(s, names)
%SWITCH_NAMES The run switches of NAMES (steps or analyses) as the settings file writes them (0.2).
    text = strjoin(cellfun(@(n) sprintf('s.run.%s.%s', s.run.entry, n), cellstr(names), ...
        'UniformOutput', false), ', ');
end

function check_analysis_switches(s, running)
%CHECK_ANALYSIS_SWITCHES Refuse a running step whose analyses are all off, or an analysis whose prerequisite is off.
%   An analysis inside a step runs with its step (study.switches). One that
%   is computed from another analysis of the same call (the error budget
%   from the feature reconstruction) is refused, before any computation,
%   when that one is switched off; a step whose analyses are all switched
%   off would compute nothing. Nothing is switched on automatically.
    W = study.switches(s.run.entry);
    W = W(strcmp({W.kind}, 'analysis'));
    switches = s.run.(s.run.entry);
    steps = unique({W.step}, 'stable');
    steps = steps(ismember(steps, {running.name}));
    for k = 1:numel(steps)
        mine = W(strcmp({W.step}, steps{k}));
        on = arrayfun(@(w) logical(switches.(w.name)), mine);
        if ~any(on)
            error('study:AnalysesSwitchedOff', ...
                ['Step ''%s'' would run, but every analysis inside it is switched off (%s in ' ...
                 'study_settings.m, section 0.2): switch on the analyses to compute, or leave ' ...
                 'the step out.'], steps{k}, switch_names(s, {mine.name}));
        end
        for w = reshape(mine(on), 1, [])
            need = w.requires(~cellfun(@(n) logical(switches.(n)), w.requires));
            if ~isempty(need)
                error('study:AnalysisPrerequisite', ...
                    ['Analysis ''%s'' of step ''%s'' is computed from %s in the same call, which is ' ...
                     'switched off. Switch it on (%s in study_settings.m, section 0.2), or switch ' ...
                     '''%s'' off.'], w.name, steps{k}, strjoin(need, ', '), switch_names(s, need), ...
                    w.name);
            end
        end
    end
end

function names = switched_off_analyses(s)
%SWITCHED_OFF_ANALYSES The analyses of the call's steps whose run switch is false (settings 0.2).
    W = study.switches(s.run.entry);
    W = W(strcmp({W.kind}, 'analysis') & ismember({W.step}, s.run.steps));
    off = arrayfun(@(w) ~logical(s.run.(s.run.entry).(w.name)), W);
    names = arrayfun(@(w) sprintf('%s (%s)', w.name, w.step), W(off), 'UniformOutput', false);
end

function q = quoted_list(names)
    q = strjoin(cellfun(@(n) ['''' n ''''], names, 'UniformOutput', false), ',');
end

function t = utc_now()
    t = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
end

function say(s, level, varargin)
    levels = {'quiet', 'info', 'debug'};
    if find(strcmp(levels, s.logging.level)) >= find(strcmp(levels, level))
        fprintf(varargin{:});
    end
end
