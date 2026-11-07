function result = reproduce(s)
%REPRODUCE Render figures and tables of the requested analyses from shipped results.
%   RESULT = study.reproduce(S) is the 'reproduce' mode of study.run. For
%   every analysis folder of S.run.entry that one of the requested steps
%   produces (the step 'figures' selects all of them), it runs the renderers
%   of study.renderers on the saved results in S.paths.results and writes
%     <output>/<route>/<NN_analysis>/figures/   figures
%     <output>/<route>/<NN_analysis>/tables/    tables (CSV)
%     <output>/<route>/<NN_analysis>/README.md  with the index of both
%   where <output> is the run folder, or thesis_results/ itself for a render
%   in place (study.output_root). Posterior-based results show certified
%   and healthy-fallback cells together; the index of each analysis states
%   which cells an output shows and their status (study.cell_status,
%   study.index_entry). Renderer bookkeeping (status tables, figure
%   inventories) goes to <run>/_run/render/, also for a render in place.
%
%   No model is fitted, no sampler runs, no likelihood is evaluated and UQLab
%   is not needed.
%
%   RESULT is a struct with fields analyses (route/folder rendered), figures
%   (one manifest table) and failures (renderer, message, identifier,
%   and where: the function and line that raised the error).
%   Side effects: writes the files above; for a render in place, first
%   removes the figures/ and tables/ of each analysis it renders.
%   Computation: seconds to minutes per analysis (45 minutes for every
%   route).

    A = selected_analyses(s);
    result = struct('analyses', {{}}, 'figures', table(), 'failures', ...
        struct('renderer', {}, 'message', {}, 'identifier', {}, 'where', {}));
    if isempty(A), return; end

    restoreDefaults = plotting.preserve_graphics_defaults(); %#ok<NASGU>
    set(groot, 'defaultFigureVisible', 'off');
    plotting.style();

    base = struct();
    manifests = {};
    for i = 1:numel(A)
        a = A(i);
        firstFailure = numel(result.failures) + 1;
        if s.run.inPlace
            clear_rendered(s, a);
        end
        R = study.renderers(a.route, a.folder);
        R = R(switched_on_renderers(s, a, R));
        if ~isempty(R) && ~isfield(base, a.route)
            base.(a.route) = base_config(s, a.route);
        end
        % The figures and tables of the analysis, for its README
        % (study.index_entry; containers.Map is a handle).
        index = containers.Map('KeyType', 'char', 'ValueType', 'any');
        for k = 1:numel(R)
            say(s, 'info', '[reproduce] %s/%s %s\n', a.route, a.folder, R(k).name);
            try
                % Configured per renderer: its source folders belong to the
                % renderer's call.
                cfg = configure(base.(a.route), s, a, index, R(k).name);
                rows = R(k).fn(cfg, render_options(cfg, R(k).options));
            catch err
                where = failure_location(err);
                result.failures(end+1) = struct('renderer', R(k).name, ...
                    'message', err.message, 'identifier', err.identifier, 'where', where);
                if strcmp(err.identifier, 'study:source_folder:NotInRun')
                    say(s, 'info', '   not rendered: %s\n', err.message);
                else
                    say(s, 'info', '   FAILED in %s: %s\n', where, err.message);
                end
                continue;
            end
            if isempty(rows), continue; end
            % Some renderers add their own columns; the run keeps the common ones.
            rows = rows(:, {'Category', 'Figure', 'RelativePath', 'Scope', ...
                'SourceArtifacts'});
            manifests{end+1} = rows; %#ok<AGROW>
        end
        own = result.failures(firstFailure:end);
        study.write_readme(study.output_root(s), a, s, index, ...
            own(strcmp({own.identifier}, 'study:source_folder:NotInRun')));
        result.analyses{end+1} = [a.route '/' a.folder];
    end
    if ~isempty(manifests)
        result.figures = vertcat(manifests{:});
    end
end

function clear_rendered(s, a)
%CLEAR_RENDERED Remove the previously rendered figures and tables of one analysis.
%   Only for 'InPlace' runs (maintainers regenerating thesis_results/): figures/
%   and tables/ are entirely produced by this mode, so they are rebuilt from
%   scratch, and so are the analysis's step folders in the case folders
%   (<route>/cases/case_<CaseID>/<step>/, the per-case categories of
%   study.layout); a case folder left empty goes too. data/ is never touched.
    root = study.output_root(s);
    folders = {fullfile(root, a.route, a.folder, 'figures'), ...
        fullfile(root, a.route, a.folder, 'tables'), ...
        fullfile(s.paths.run, '_run', 'render', a.route, a.folder)};
    C = study.layout().categories;
    C = C(strcmp({C.route}, a.route) & strcmp({C.analysis}, a.folder) & startsWith({C.category}, 'case/'));
    cases = dir(fullfile(root, a.route, 'cases', 'case_*'));
    cases = cases([cases.isdir]);
    for c = C
        for k = 1:numel(cases)
            folders{end+1} = fullfile(root, a.route, 'cases', cases(k).name, ...
                extractAfter(c.category, 'case/')); %#ok<AGROW>
        end
    end
    for k = 1:numel(folders)
        if isfolder(folders{k}), rmdir(folders{k}, 's'); end
    end
    for k = 1:numel(cases)
        folder = fullfile(root, a.route, 'cases', cases(k).name);
        if isfolder(folder) && numel(dir(folder)) <= 2
            % An empty folder that cannot be removed does no harm (git keeps none).
            [~, ~] = rmdir(folder);
        end
    end
end

function A = selected_analyses(s)
%SELECTED_ANALYSES Analysis folders produced by the requested steps.
%   'figures' named in 'Steps' selects every analysis; with the run switches
%   (settings 0.2) the analyses of the switched-on steps are rendered.
    A = study.analyses();
    A = A(strcmp({A.entry}, study.entry_function(s.run.entry)));
    if ismember('figures', s.run.steps) && strcmp(s.run.selection.source, 'Steps'), return; end
    keep = arrayfun(@(a) any(ismember(a.steps, s.run.steps)), A);
    A = A(keep);
end

function keep = switched_on_renderers(s, a, R)
%SWITCHED_ON_RENDERERS False for a renderer of analysis folder A that draws something not selected.
%   The analyses inside a step and the steps that share an analysis folder
%   with other steps name their renderers (study.switches). A renderer of
%   the folder is not called, so its figures and tables are not drawn, when
%   its step is not among the steps of the call (the step 'figures' named
%   in 'Steps' selects every step) or its analysis is switched off in the
%   settings (0.2).
    keep = true(1, numel(R));
    every = ismember('figures', s.run.steps) && strcmp(s.run.selection.source, 'Steps');
    selected = @(step) every || ismember(step, s.run.steps);
    W = study.switches(a.route);
    for w = reshape(W(strcmp({W.kind}, 'step') & ismember({W.name}, a.steps)), 1, [])
        if selected(w.name), continue; end
        keep(ismember({R.name}, w.renderers)) = false;
    end
    for w = reshape(W(strcmp({W.kind}, 'analysis') & ismember({W.step}, a.steps)), 1, [])
        if selected(w.step) && logical(s.run.(a.route).(w.name)), continue; end
        keep(ismember({R.name}, w.renderers)) = false;
    end
end

function cfg = base_config(s, route)
%BASE_CONFIG Scientific constants of the route (parameters, cohort, designs).
%   The configuration of the settings S (study.project_config); no folder is
%   created and nothing is computed.
    stageRoute = 'real';
    if strcmp(route, 'generalized'), stageRoute = 'real_extended'; end
    runRoot = fullfile(s.paths.run, '_run', 'work', stageRoute, 'runs', s.run.name);
    cases = {};
    campaign = study.inversion_campaign(s.paths.results);
    if strcmp(route, 'fixed') && isfield(s.run, 'renderFromRun') && s.run.renderFromRun && ...
            ~isempty(campaign)
        % A rerun's figures cover the cases of its own inversion campaign;
        % the cohort-dependent settings follow from them.
        cases = {'InversionCaseIDs', campaign.caseIDs};
    end
    cfg = study.project_config(s, 'Route', stageRoute, 'RunRoot', runRoot, cases{:});
end

function cfg = configure(cfg, s, a, index, renderer)
%CONFIGURE Configuration of one renderer call in the publication layout.
%   The command of the index re-renders the analysis: the first step of the
%   analysis, or the step whose own renderer RENDERER is (study.switches).
    cfg.layout = struct();
    cfg.layout.route = a.route;
    cfg.layout.analysis = a.folder;
    cfg.layout.results = s.paths.results;
    cfg.layout.output = study.output_root(s);
    cfg.layout.run = s.paths.run;
    % Rendering the shipped results themselves (maintainers, 'InPlace').
    cfg.layout.inPlace = s.run.inPlace;
    % Posterior-based analyses: certified and healthy-fallback cells together.
    cfg.layout.posterior = a.posterior;
    cfg.layout.formats = s.figures.formats;
    % Rendering a rerun's own results (study.render_run): a source folder
    % the run does not hold is an error, not an empty figure set.
    cfg.layout.strictSources = isfield(s.run, 'renderFromRun') && s.run.renderFromRun;
    % The canonical all_six cells of a rerun's conditional inversion that took
    % them from the shipped results (its campaign's baselines; study.native_config):
    % its renderers read them there (study.load_shipped_posterior).
    cfg.layout.canonicalResults = '';
    if cfg.layout.strictSources && strcmp(a.folder, '07_conditional_inversion') && ...
            strcmp(shipped_baselines(s.paths.run), 'shipped')
        cfg.layout.canonicalResults = s.run.shippedResults;
    end
    % The ratio-error curves of a rerun without an inversion of its own were
    % computed on the shipped draws (study.native_config): their renderer
    % draws the marginals from them.
    if cfg.layout.strictSources && strcmp(a.folder, '08_ratio_error_curves') && ~study.run_has_inversion(s)
        cfg.layout.canonicalResults = s.run.shippedResults;
    end
    % The GP-mean inversion is compared with the shipped canonical cells
    % (study.write_gp_mean_results): its figure of one case's four scenarios
    % draws their marginals from the shipped draws, its own from the run's.
    if cfg.layout.strictSources && strcmp(a.folder, '09_gp_mean_inversion') && ~study.run_has_inversion(s)
        cfg.layout.canonicalResults = s.run.shippedResults;
    end
    % Likewise the parameter combinations (the recovery analysis): their
    % renderer draws the weak-pair scatter from the draws.
    if cfg.layout.strictSources && strcmp(a.folder, '05_recovery') && ~study.run_has_inversion(s)
        cfg.layout.canonicalResults = s.run.shippedResults;
    end
    % And those of the confirmation, computed on the shipped draws when the
    % run has no confirmation of its own (study.native_config).
    if cfg.layout.strictSources && strcmp(a.folder, '06_confirmation') && ...
            ~isfile(fullfile(s.paths.run, 'generalized', '06_confirmation', 'data', 'draws', 'index.csv'))
        cfg.layout.canonicalResults = s.run.shippedResults;
    end
    step = a.steps{1};
    W = study.switches(a.route);
    owner = W(strcmp({W.kind}, 'step') & ismember({W.name}, a.steps) & ...
        cellfun(@(r) ismember(renderer, r), {W.renderers}));
    if ~isempty(owner), step = owner(1).name; end
    cfg.layout.command = sprintf('%s(''Steps'',{''%s''})', a.entry, step);
    if cfg.layout.strictSources
        cfg.layout.command = sprintf('%s(''Mode'',''rerun'',''RunName'',''%s'',''Steps'',{''figures''})', ...
            a.entry, s.run.name);
    end
    cfg.layout.index = index;
    cfg.layout.cornerGallery = s.figures.cornerGallery;
    cfg.fig.resolution = s.figures.resolution;
    % Everything a renderer writes besides figures (status tables, figure
    % inventories, plotted intermediate tables) goes below the run's _run/
    % folder: the stage folders of the configuration are moved there.
    staging = fullfile(s.paths.run, '_run', 'render', a.route, a.folder);
    legacyRoot = cfg.paths.runRoot;
    names = fieldnames(cfg.paths);
    for i = 1:numel(names)
        value = cfg.paths.(names{i});
        if (ischar(value) || isstring(value)) && startsWith(char(value), legacyRoot)
            cfg.paths.(names{i}) = [staging char(extractAfter(char(value), numel(legacyRoot)))];
        end
    end
    cfg.paths.stage07 = fullfile(staging, 'figures');
    % Fields that renderers and the provider loader read directly. The file
    % fields of the pre-publication layout are dropped, so that no renderer can
    % read a stale stage path.
    cfg.paths.runRoot = s.paths.results;
    cfg.files = struct();
    if strcmp(a.route, 'fixed') && strcmp(a.folder, '04_inversion')
        cfg.files.certificationIndex = fullfile(study.source_folder(cfg, 'inversion'), ...
            'cell_status.csv');
    end
    % The status of every cell the analysis draws on, for the index.
    cfg.layout.cellStatus = study.cell_status(cfg);
    % The surrogate audit is shipped for both routes.
    cfg.stage2.runSurrogateQualityAudit = true;
end

function options = render_options(cfg, overrides)
%RENDER_OPTIONS Figure selection: every figure family the renderers can draw.
%   The per-case outputs are those of the settings (A.10, study.case_outputs);
%   OVERRIDES (study.renderers) are the options of one renderer.
    options = struct();
    options.Mode = 'full';
    options.GenerateCrossDesignComparisons = logical(cfg.fig.generateCrossDesignComparisons);
    options.GenerateAllPosteriorCornerPlots = strcmp(cfg.layout.cornerGallery, 'all');
    names = fieldnames(overrides);
    for i = 1:numel(names)
        options.(names{i}) = overrides.(names{i});
    end
end


function where = failure_location(err)
%FAILURE_LOCATION Function and line of the repository code that raised ERR.
%   The first stack frame inside the repository (an error raised in a MATLAB
%   function names the renderer line that called it); '' without a stack.
    where = '';
    if isempty(err.stack), return; end
    root = [study.root() filesep];
    inside = find(strncmpi({err.stack.file}, root, numel(root)), 1);
    if isempty(inside), inside = 1; end
    where = sprintf('%s (line %d)', err.stack(inside).name, err.stack(inside).line);
end

function say(s, level, varargin)
    levels = {'quiet', 'info', 'debug'};
    if find(strcmp(levels, s.logging.level)) >= find(strcmp(levels, level))
        fprintf(varargin{:});
    end
end

function source = shipped_baselines(run)
%SHIPPED_BASELINES Where the conditional campaign of the run took its canonical cells: 'shipped', 'campaign' or ''.
    source = '';
    file = fullfile(run, '_run', 'inversion', 'conditional_inversion', 'orchestration', ...
        'conditional_campaign_preparation.json');
    if ~isfile(file), return; end
    P = jsondecode(fileread(file));
    if isfield(P, 'baselineSource'), source = char(P.baselineSource); end
end
