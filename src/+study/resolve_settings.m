function s = resolve_settings(entry, varargin)
%RESOLVE_SETTINGS Settings for one call of an entry point.
%   S = study.resolve_settings(ENTRY, NAME, VALUE, ...) reads
%   study_settings.m (or the struct of the option 'Settings'), refuses it
%   when a setting is missing, unknown or invalid (study.validate_settings),
%   applies the name-value options of this call and validates again, for
%   the route ENTRY ('fixed' or 'generalized'). The options are one-off
%   overrides of settings or controls of the call; the run record keeps
%   them (study.run_record). S adds what the call decides: S.run.entry,
%   S.run.steps, S.run.inPlace, the absolute S.paths (repository, output,
%   results, run), S.provenance and the controls S.advanced. Paths of the
%   settings are relative to the repository folder unless absolute.
%
%   Name-value options accepted by every entry point (the setting they
%   override in brackets):
%     'Steps'            step name or cell array of step names: a one-off
%                        override of the run switches of the settings (0.2)
%                        for this call. Default: the steps whose switch is
%                        true (s.run.<route>.<step>); in rerun mode without
%                        the steps whose results can only be the shipped
%                        ones (the surrogates with modelSource
%                        'use_shipped', a step this version does not
%                        rerun) and, with 'Scale','example', without the
%                        steps that have no example. S.run.selection
%                        records where the steps came from and what was
%                        left out, and why. The analysis switches apply
%                        inside the steps in both cases.
%     'Mode'             'reproduce' or 'rerun' (run.mode)
%     'Plan'             true: print the plan and whether the call would be
%                        refused, compute nothing (run.plan)
%     'ConfirmExpensive' true: allow steps marked expensive (run.confirmExpensive)
%     'Scale'            'thesis' (the settings of the thesis) or 'example' (run.scale)
%                        (Mode 'rerun': a small version of the whole study in
%                        about 10-30 minutes, labelled as a demonstration;
%                        settings given explicitly in the call still apply):
%                          fixed        'Cases' 131, 'InversionCells' 3 (the
%                                       measurement_plus_gp x d6_only cell),
%                                       'ConditionalCells' [1 2] (without
%                                       'Settings' the campaign E and F in
%                                       measurement_plus_gp, run again, not
%                                       taken from the shipped results; the
%                                       step is optional; the GP-mean
%                                       inversion likewise: its cell of case
%                                       131), 'PartialCampaign',
%                                       'DemonstrationSteps' [200 250]; no
%                                       'ConfirmExpensive' needed
%                          generalized  'DemonstrationGPIterations' 5 when the
%                                       refit is requested; 7 protocols x 15
%                                       material points when a step of the
%                                       protocol screening is requested (the
%                                       confirmation's steps after
%                                       export_design have no example)
%     'RunName'          name of the run folder under the output folder (run.name)
%     'OutputFolder'     folder that receives the run folder (paths.output)
%     'ResultsFolder'    shipped results read by 'reproduce' (paths.results)
%     'UQLabRoot'        UQLab installation folder (paths.uqlabRoot)
%     'CornerGallery'    'canonical' or 'all' (figures.cornerGallery)
%     'Formats'          figure formats, e.g. {'png','pdf'} (figures.formats)
%     'Resolution'       raster resolution in dpi (figures.resolution)
%     'Logging'          'quiet', 'info' or 'debug' (logging.level)
%     'Settings'         a complete settings struct replacing study_settings.m
%                        (s = study_settings(); change fields; pass s); it is
%                        validated like the file
%     'InPlace'          true (maintainers, reproduce mode only): write
%                        figures/, tables/ and the READMEs into the shipped
%                        results folder itself; the run folder keeps the run
%                        record and the renderers' bookkeeping
%   Advanced, step-specific overrides:
%     'Cases'            CaseIDs to invert or render in this call, in their
%                        order (the settings' fixed.inversion.cases otherwise)
%     'FixedDataFile'    fixed-route dataset CSV (fixed.dataset.file); its
%                        CaseIDs must be the 452 cases of the frozen
%                        calibration (study.check_fixed_dataset)
%     'ConfirmationObservationFiles'  folder with the reviewed COMSOL
%                        observations of the confirmation design, for
%                        'import_observations': reviewed_export.csv (one row
%                        per COMSOL solve), source_provenance.json and the
%                        acceptance record direct_data_acceptance.json
%     'ConfirmationCells'  cells of the prepared confirmation campaign that
%                        'run_cells' runs: 'all' (default: every cell not yet
%                        run) or indices of its task table (for jobs on a
%                        cluster)
%     'InversionCells'   cells of the inversion grid ('Cases' x 3 scenarios
%                        x 6 designs) this call runs: 'all' (default: every
%                        cell not yet run; then the campaign is finalized),
%                        'prepare' (write the cell task table only), or grid
%                        indices (for jobs on a cluster; a last call with
%                        'all' finalizes the campaign)
%     'ConditionalCells' cells of the conditional inversion this call runs:
%                        'all' (default: every cell to run that has not run;
%                        then the campaign is finalized), 'prepare' (write
%                        the task table only), or indices of its task table
%                        (<run>/_run/inversion/conditional_inversion/
%                        orchestration/conditional_tasks.csv; for jobs on a
%                        cluster; a last call with 'all' finalizes)
%     'GPMeanCells'      cells of the GP-mean inversion (settings A.13) this
%                        call runs: 'all' (default: every cell that has not
%                        run; then the campaign is finalized), 'prepare'
%                        (write the task table only), or indices of its task
%                        table (<run>/_run/inversion/gp_mean_inversion/
%                        cell_task_table.csv; for jobs on a cluster; a last
%                        call with 'all' finalizes)
%     'PartialCampaign'  true: publish the cells run so far without
%                        finalizing the campaign, of the inversion, the
%                        conditional inversion and the GP-mean inversion;
%                        the other cells stay missing (small tests and
%                        demonstrations)
%     'ScreeningCandidates', 'ScreeningMaterials'  row indices of the 730
%                        candidate protocols and of the 1000 material points
%                        that the step 'screen' evaluates (tests only; the
%                        run records an incomplete design)
%     'DemonstrationSteps'  chain length per MCMC level, e.g. [200 250]
%                        (demonstrations and smoke tests only: every request
%                        keeps its level, seed and certification policy, the
%                        sampler runs the shorter chain; not thesis evidence).
%                        The fixed route's inversion, conditional
%                        inversion and GP-mean inversion, and the
%                        confirmation, whose step
%                        'prepare' fixes them for its cells; a campaign
%                        continues with the chains it was prepared with
%     'SurrogateOutputs' outputs (1-6) whose GP and PCE the generalized step
%                        'surrogates' fits in this call: 'all' (default: every
%                        output not fitted yet; then the ensembles are
%                        written) or output indices (for example one process
%                        or cluster job per output; a last call with 'all'
%                        writes the ensembles)
%     'DemonstrationGPIterations'  iteration limit (1-19) of every GP
%                        optimization of the generalized step 'surrogates';
%                        the declared multi-start selection keeps its first
%                        two starts (demonstrations and smoke tests only;
%                        the thesis fits used UQLab's default of 20, and 100
%                        for the selection; not thesis evidence)
%
%   The step 'surrogates' fits models; with the setting modelSource
%   'use_shipped' (the thesis setting, A.3 and B.3) it is refused and left
%   out of the default steps, and the later steps read the shipped models.
%   Side effects: none (no folder is created here).

    root = study.root();
    parser = inputParser;
    parser.FunctionName = study.entry_function(entry);
    parser.KeepUnmatched = false;
    addParameter(parser, 'Settings', struct(), @(x) isstruct(x) && isscalar(x));
    addParameter(parser, 'Steps', {}, @(x) ischar(x) || isstring(x) || iscellstr(x));
    addParameter(parser, 'Mode', '', @text);
    addParameter(parser, 'Plan', [], @(x) isempty(x) || is_flag(x));
    addParameter(parser, 'ConfirmExpensive', [], @(x) isempty(x) || is_flag(x));
    addParameter(parser, 'Scale', '', @text);
    addParameter(parser, 'RunName', '', @text);
    addParameter(parser, 'OutputFolder', '', @text);
    addParameter(parser, 'ResultsFolder', '', @text);
    addParameter(parser, 'UQLabRoot', '', @text);
    addParameter(parser, 'CornerGallery', '', @text);
    addParameter(parser, 'Formats', {}, @(x) ischar(x) || isstring(x) || iscellstr(x));
    addParameter(parser, 'Resolution', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
    addParameter(parser, 'Logging', '', @text);
    addParameter(parser, 'Cases', [], @(x) isnumeric(x) && all(x(:) == fix(x(:))));
    addParameter(parser, 'FixedDataFile', '', @text);
    addParameter(parser, 'InPlace', false, @is_flag);
    addParameter(parser, 'ConfirmationObservationFiles', '', @text);
    addParameter(parser, 'ConfirmationCells', 'all', @(x) text(x) || ...
        (isnumeric(x) && ~isempty(x) && all(x(:) >= 1 & x(:) == fix(x(:)))));
    addParameter(parser, 'InversionCells', 'all', @(x) text(x) || ...
        (isnumeric(x) && ~isempty(x) && all(x(:) >= 1 & x(:) == fix(x(:)))));
    addParameter(parser, 'ConditionalCells', 'all', @(x) text(x) || ...
        (isnumeric(x) && ~isempty(x) && all(x(:) >= 1 & x(:) == fix(x(:)))));
    addParameter(parser, 'GPMeanCells', 'all', @(x) text(x) || ...
        (isnumeric(x) && ~isempty(x) && all(x(:) >= 1 & x(:) == fix(x(:)))));
    addParameter(parser, 'PartialCampaign', false, @is_flag);
    addParameter(parser, 'ScreeningCandidates', [], @(x) isnumeric(x) && all(x(:) >= 1 & x(:) == fix(x(:))));
    addParameter(parser, 'ScreeningMaterials', [], @(x) isnumeric(x) && all(x(:) >= 1 & x(:) == fix(x(:))));
    addParameter(parser, 'DemonstrationSteps', [], @(x) isnumeric(x) && ...
        all(x(:) >= 2 & x(:) == fix(x(:))));
    addParameter(parser, 'SurrogateOutputs', 'all', @(x) text(x) || ...
        (isnumeric(x) && ~isempty(x) && all(x(:) >= 1 & x(:) == fix(x(:)))));
    addParameter(parser, 'DemonstrationGPIterations', [], @(x) isempty(x) || ...
        (isnumeric(x) && isscalar(x) && x >= 1 && x == fix(x)));
    parse(parser, varargin{:});
    o = parser.Results;

    if isempty(fieldnames(o.Settings))
        s = study_settings();
        study.validate_settings(s);
    else
        s = o.Settings;
        study.validate_settings(s, 'the option ''Settings''');
    end

    % One-off overrides of settings by this call.
    lowered = @(x) lower(char(string(x)));
    if ~isempty(o.Mode), s.run.mode = lowered(o.Mode); end
    if ~isempty(o.Plan), s.run.plan = logical(o.Plan); end
    if ~isempty(o.ConfirmExpensive), s.run.confirmExpensive = logical(o.ConfirmExpensive); end
    if ~isempty(o.Scale), s.run.scale = lowered(o.Scale); end
    if ~isempty(o.RunName), s.run.name = char(string(o.RunName)); end
    if ~isempty(o.OutputFolder), s.paths.output = char(string(o.OutputFolder)); end
    if ~isempty(o.ResultsFolder), s.paths.results = char(string(o.ResultsFolder)); end
    if ~isempty(o.UQLabRoot), s.paths.uqlabRoot = char(string(o.UQLabRoot)); end
    if ~isempty(o.CornerGallery), s.figures.cornerGallery = lowered(o.CornerGallery); end
    if ~isempty(o.Formats), s.figures.formats = reshape(lower(cellstr(o.Formats)), 1, []); end
    if ~isempty(o.Resolution), s.figures.resolution = o.Resolution; end
    if ~isempty(o.Logging), s.logging.level = lowered(o.Logging); end
    if ~isempty(o.FixedDataFile), s.fixed.dataset.file = char(string(o.FixedDataFile)); end
    study.validate_settings(s, 'the settings with the options of this call');

    s.run.entry = char(string(entry));
    registry = study.steps(s.run.entry);
    source = s.(s.run.entry).surrogates.modelSource;
    requested = cellstr(o.Steps);
    switches = s.run.(s.run.entry);
    names = {registry.name};
    s.run.selection = struct('source', 'Steps', ...
        'switchedOff', {names(~cellfun(@(n) logical(switches.(n)), names))}, ...
        'leftOut', struct('step', {}, 'reason', {}));
    if isempty(requested)
        % The run switches of the settings (0.2).
        s.run.selection.source = 'switches';
        requested = names(cellfun(@(n) logical(switches.(n)), names));
        if strcmp(s.run.mode, 'rerun')
            leave = @(step, reason) struct('step', step, 'reason', reason);
            if strcmp(source, 'use_shipped') && ismember('surrogates', requested)
                % The thesis models are used; nothing is fitted.
                s.run.selection.leftOut(end+1) = leave('surrogates', ...
                    'modelSource ''use_shipped'': the shipped models, nothing is fitted');
            end
            for r = reshape(registry(~[registry.available] & ismember(names, requested)), 1, [])
                s.run.selection.leftOut(end+1) = leave(r.name, ...
                    'shipped evidence: this version does not rerun it');
            end
            if strcmp(s.run.scale, 'example')
                left = {s.run.selection.leftOut.step};
                for r = reshape(registry(~[registry.example] & ismember(names, requested) & ...
                        ~ismember(names, left)), 1, [])
                    s.run.selection.leftOut(end+1) = leave(r.name, 'no example version');
                end
            end
            requested = setdiff(requested, {s.run.selection.leftOut.step}, 'stable');
        end
    end
    unknown = setdiff(requested, {registry.name});
    assert(isempty(unknown), 'study:settings:UnknownStep', ...
        'Unknown step(s) for %s: %s. Available steps: %s.', study.entry_function(s.run.entry), ...
        strjoin(unknown, ', '), strjoin({registry.name}, ', '));
    if strcmp(s.run.mode, 'rerun') && ismember('surrogates', requested) && strcmp(source, 'use_shipped')
        section = 'A.3';
        if strcmp(s.run.entry, 'generalized'), section = 'B.3'; end
        error('study:settings:ModelSource', ...
            ['The step ''surrogates'' fits the surrogates, and setting %s.surrogates.modelSource ' ...
             '(section %s of the settings file) is ''use_shipped'': the thesis models, no ' ...
             'fitting. Set it to ''refit_audit_selected'' or ''refit_manual'' to refit.'], ...
            s.run.entry, section);
    end
    order = cellfun(@(n) find(strcmp({registry.name}, n)), requested);
    [~, sorted] = sort(order);
    s.run.steps = requested(sorted);

    s.paths.repository = root;
    s.paths.output = absolute(root, s.paths.output);
    s.paths.results = absolute(root, s.paths.results);
    if isempty(s.run.name)
        s.run.name = sprintf('%s_%s', s.run.entry, ...
            char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyyMMdd''T''HHmmss''Z''')));
    end
    s.paths.run = fullfile(s.paths.output, s.run.name);
    % A render in place writes the figures, tables and READMEs into the
    % shipped results (study.output_root); the run folder keeps its record.
    s.run.inPlace = logical(o.InPlace);
    assert(~s.run.inPlace || strcmp(s.run.mode, 'reproduce'), 'study:settings:InPlace', ...
        ['''InPlace'' only applies to reproduce mode: a rerun never writes into the ' ...
         'shipped results.']);

    s.provenance.uqlabRootSource = 'settings';
    s.paths.uqlabRoot = strtrim(char(string(s.paths.uqlabRoot)));
    if isempty(s.paths.uqlabRoot)
        % The one environment variable the code reads; recorded in the manifest.
        s.paths.uqlabRoot = strtrim(getenv('UQLAB_ROOT'));
        s.provenance.uqlabRootSource = 'UQLAB_ROOT environment variable';
        if isempty(s.paths.uqlabRoot)
            s.provenance.uqlabRootSource = 'not set';
        end
    end
    s.advanced.cases = reshape(double(o.Cases), 1, []);
    s.advanced.confirmationObservationFiles = absolute(root, o.ConfirmationObservationFiles);
    s.advanced.confirmationCells = o.ConfirmationCells;
    if text(o.ConfirmationCells)
        s.advanced.confirmationCells = lower(char(string(o.ConfirmationCells)));
        assert(strcmp(s.advanced.confirmationCells, 'all'), 'study:settings:ConfirmationCells', ...
            '''ConfirmationCells'' must be ''all'' or task indices of the prepared campaign.');
    else
        s.advanced.confirmationCells = unique(reshape(double(o.ConfirmationCells), 1, []));
    end
    s.advanced.inversionCells = o.InversionCells;
    if text(o.InversionCells)
        s.advanced.inversionCells = lower(char(string(o.InversionCells)));
        assert(ismember(s.advanced.inversionCells, {'all', 'prepare'}), ...
            'study:settings:InversionCells', ...
            '''InversionCells'' must be ''all'', ''prepare'' or grid cell indices.');
    else
        s.advanced.inversionCells = reshape(double(o.InversionCells), 1, []);
    end
    s.advanced.conditionalCells = o.ConditionalCells;
    if text(o.ConditionalCells)
        s.advanced.conditionalCells = lower(char(string(o.ConditionalCells)));
        assert(ismember(s.advanced.conditionalCells, {'all', 'prepare'}), ...
            'study:settings:ConditionalCells', ...
            '''ConditionalCells'' must be ''all'', ''prepare'' or task indices of the prepared campaign.');
    else
        s.advanced.conditionalCells = unique(reshape(double(o.ConditionalCells), 1, []));
    end
    s.advanced.gpMeanCells = o.GPMeanCells;
    if text(o.GPMeanCells)
        s.advanced.gpMeanCells = lower(char(string(o.GPMeanCells)));
        assert(ismember(s.advanced.gpMeanCells, {'all', 'prepare'}), ...
            'study:settings:GPMeanCells', ...
            '''GPMeanCells'' must be ''all'', ''prepare'' or task indices of the prepared campaign.');
    else
        s.advanced.gpMeanCells = unique(reshape(double(o.GPMeanCells), 1, []));
    end
    s.advanced.partialCampaign = logical(o.PartialCampaign);
    s.advanced.screeningCandidates = reshape(double(o.ScreeningCandidates), 1, []);
    s.advanced.screeningMaterials = reshape(double(o.ScreeningMaterials), 1, []);
    s.advanced.demonstrationSteps = reshape(double(o.DemonstrationSteps), 1, []);
    s.advanced.surrogateOutputs = o.SurrogateOutputs;
    if text(o.SurrogateOutputs)
        s.advanced.surrogateOutputs = lower(char(string(o.SurrogateOutputs)));
        assert(strcmp(s.advanced.surrogateOutputs, 'all'), 'study:settings:SurrogateOutputs', ...
            '''SurrogateOutputs'' must be ''all'' or output indices from 1 to 6.');
    else
        s.advanced.surrogateOutputs = unique(reshape(double(o.SurrogateOutputs), 1, []));
    end
    s.advanced.demonstrationGPIterations = double(o.DemonstrationGPIterations);

    if strcmp(s.run.scale, 'example')
        s = example_scale(s, parser.UsingDefaults);
    end
end

function s = example_scale(s, defaults)
%EXAMPLE_SCALE The reduced settings of an example run.
%   Only the settings that the call did not give explicitly are set; the
%   rest of the study runs at the settings of the thesis.
    assert(strcmp(s.run.mode, 'rerun'), 'study:settings:Scale', ...
        ['''Scale'',''example'' runs a small rerun of the study: pass ''Mode'',''rerun''. ' ...
         'Reproducing the shipped results needs no example.']);
    unset = @(name) ismember(name, defaults);
    switch s.run.entry
        case 'fixed'
            % One inversion cell of case 131 (measurement_plus_gp x d6_only,
            % cell 3 of the case's grid) with short demonstration chains,
            % published without finalizing the campaign.
            if unset('Cases'), s.advanced.cases = 131; end
            if unset('InversionCells'), s.advanced.inversionCells = 3; end
            if unset('PartialCampaign'), s.advanced.partialCampaign = true; end
            if unset('DemonstrationSteps'), s.advanced.demonstrationSteps = [200 250]; end
            % The conditional inversion of case 131 ('Steps' with
            % conditional_inversion): its first two cells to run (a partial
            % campaign when it has more). The shipped results hold every cell
            % of the thesis campaign, so with the settings of the thesis the
            % example's campaign is E and F in measurement_plus_gp, run again
            % instead of taken from there.
            if unset('ConditionalCells'), s.advanced.conditionalCells = [1 2]; end
            if unset('Settings')
                s.fixed.conditionalInversion.cells = {{'E', 'F'}, {'measurement_plus_gp'}};
                s.fixed.conditionalInversion.reuseShippedCells = false;
            end
        case 'generalized'
            if unset('DemonstrationGPIterations') && ismember('surrogates', s.run.steps)
                s.advanced.demonstrationGPIterations = 5;
            end
            if any(ismember({'screen', 'objective_supplement', 'rankings'}, s.run.steps))
                % A screen of 7 protocols x 15 material points.
                if unset('ScreeningCandidates')
                    s.advanced.screeningCandidates = [1 279 288 360 368 369 730];
                end
                if unset('ScreeningMaterials')
                    s.advanced.screeningMaterials = [1:5 100:100:1000];
                end
            end
            thesisOnly = intersect(s.run.steps, {'import_observations', 'prepare', 'run_cells', ...
                'compare'}, 'stable');
            if ~isempty(thesisOnly)
                error('study:settings:Scale', ['The confirmation steps after export_design have ' ...
                    'no example (requested: %s): they invert the accepted COMSOL observations of ' ...
                    'the confirmation design (thesis: about 850 core-hours on a computing cluster). ' ...
                    'reproduce_thesis_results renders the shipped results.'], ...
                    strjoin(thesisOnly, ', '));
            end
    end
end

function p = absolute(root, p)
    p = char(string(p));
    if isempty(p), return; end
    if ~(startsWith(p, filesep) || ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\'))
        p = fullfile(root, p);
    end
end

function tf = text(x)
    tf = ischar(x) || (isstring(x) && isscalar(x));
end

function tf = is_flag(x)
    tf = (islogical(x) || isnumeric(x)) && isscalar(x);
end
