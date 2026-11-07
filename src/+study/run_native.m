function completed = run_native(s, P, call)
%RUN_NATIVE Run the requested steps as step functions writing the publication layout.
%   COMPLETED = study.run_native(S, P, CALL) runs, in dependency order,
%   every step of the plan P (study.plan) whose action is 'run', for
%   resolved settings S of a rerun; CALL is the call's index in the run
%   record. For each step:
%     1. its inputs are resolved from this run or from their fixed locations
%        in the shipped results (study.resolve_input);
%     2. its configuration is built as the pre-publication stage received it, with
%        inputs and outputs in the publication layout (study.native_config);
%     3. the step function (study.steps: study.steps.<group>_<step>)
%        computes and writes <run>/<route>/<NN_analysis>/data;
%     4. the run record lists the step as completed, with its inputs,
%        outputs and timing (study.run_record).
%   The step 'figures' renders the results this run holds instead
%   (study.render_run). A step function that returns an outcome may do only
%   part of its work in one call: the inversion some cells of its campaign
%   ('InversionCells'), the generalized refit some outputs
%   ('SurrogateOutputs'), the confirmation some of its cells
%   ('ConfirmationCells'). It is complete once its results are written, and
%   the run record keeps the outcome's details (the state of the campaign,
%   the models later steps use, a demonstration budget). UQLab is started
%   once. COMPLETED is a struct with one field per step that completed: its
%   element of the run record.
%   Side effects: changes the MATLAB path and starts UQLab
%   (study.activate_environment); writes the run folder.
%   Computation: that of the steps it runs.

    registry = study.steps(s.run.entry);
    toRun = registry(ismember({registry.name}, P.Step(strcmp(P.Action, 'run'))));
    inCall = P.Step(ismember(P.Action, {'run', 'reuse'}))';
    study.activate_environment(s);
    completed = struct();
    for r = toRun
        if strcmp(r.name, 'figures')
            % Renders the results this run holds (the steps above it).
            say(s, '[study] %s: %s\n', r.name, r.summary);
            started = utc_now();
            clock = tic;
            [rendered, inputs, outputs] = study.render_run(s);
            for k = 1:numel(rendered.skipped)
                say(s, '[study] figures: %s not rendered: %s\n', ...
                    rendered.skipped(k).renderer, rendered.skipped(k).message);
            end
            completed.figures = study.run_record('complete', s, call, struct('route', ...
                s.run.entry, 'step', 'figures', 'started_utc', started, 'elapsed_seconds', ...
                toc(clock), 'inputs', {inputs}, 'outputs', {outputs}, 'details', struct()));
            continue;
        end
        io = study.step_io(s.run.entry, r.name);
        inputs = struct('key', {}, 'path', {}, 'origin', {});
        for k = 1:numel(io.inputs)
            inputs(end+1) = study.resolve_input(s, io.inputs{k}); %#ok<AGROW>
        end
        if strcmp(r.group, 'confirmation') && ismember(r.name, {'export_design', ...
                'import_observations', 'prepare'}) && ~iscell(s.generalized.confirmation.protocols)
            % The protocols 'from_screening' (settings B.7) are the leaders of
            % the screening rankings of this run or of the shipped results.
            inputs(end+1) = study.resolve_input(s, 'rankings'); %#ok<AGROW>
        end
        cfg = study.native_config(s, r.name, inputs, inCall);
        if strcmp(s.run.entry, 'generalized') && cfg.realExtended.packageBound
            inputs = [inputs, package_inputs(cfg)]; %#ok<AGROW>
        end
        if strcmp(s.run.entry, 'fixed') && strcmp(r.name, 'dataset')
            % The dataset table itself is an input of the dataset step.
            csv = struct('key', 'dataset_csv', 'path', cfg.realData.csv, 'origin', 'data');
            inputs(end+1) = csv; %#ok<AGROW>
        elseif strcmp(s.run.entry, 'generalized') && strcmp(r.name, 'dataset')
            csv = struct('key', 'dataset_csv', 'path', cfg.realExtended.csv, 'origin', 'data');
            inputs(end+1) = csv; %#ok<AGROW>
        elseif strcmp(r.group, 'screening') && strcmp(r.name, 'screen')
            % The provider's recorded sources (study.screening_provider).
            sources = cfg.native.providerSources;
            for name = reshape(fieldnames(sources), 1, [])
                inputs(end+1) = struct('key', name{1}, 'path', sources.(name{1}), ...
                    'origin', 'shipped'); %#ok<AGROW>
            end
        elseif strcmp(r.group, 'confirmation')
            inputs = [inputs, confirmation_inputs(cfg, r.name)]; %#ok<AGROW>
        end
        say(s, '[study] %s: %s\n', r.name, r.summary);
        started = utc_now();
        clock = tic;
        stepFunction = str2func(r.fn);
        details = struct();
        if nargout(r.fn) > 0
            % The step is complete, and enters the run record, only once
            % its results were written.
            outcome = stepFunction(cfg, inCall);
            if ~outcome.published, continue; end
            details = outcome.details;
        else
            stepFunction(cfg, inCall);
        end
        if strcmp(s.run.scale, 'example')
            % The results of an example run stay labelled as such, whatever
            % later calls render them (study.demonstration).
            details.scale = 'example';
        end
        completed.(r.name) = study.run_record('complete', s, call, struct('route', ...
            s.run.entry, 'step', r.name, 'started_utc', started, 'elapsed_seconds', toc(clock), ...
            'inputs', {inputs}, 'outputs', {io.outputs}, 'details', details));
    end
end

function inputs = package_inputs(cfg)
%PACKAGE_INPUTS The approved generalized package a step reads, as step inputs.
%   The dataset, GP and PCE of the shipped results and the calibration of
%   the settings (B.3).
    inputs = struct('key', {'approved_dataset', 'approved_gp', 'approved_pce', ...
        'approved_calibration'}, 'path', {cfg.files.dataset, cfg.files.gp, cfg.files.pce, ...
        cfg.paths.emulatorErrorCalibration}, 'origin', {'shipped', 'shipped', 'shipped', 'config'});
end

function inputs = confirmation_inputs(cfg, stepName)
%CONFIRMATION_INPUTS Inputs of a confirmation step that no artifact key names.
%   The fixed dataset, whose cases are the design's materials (settings
%   A.1, B.7), for the steps that build the design; the files of the
%   reviewed COMSOL observations ('ConfirmationObservationFiles') for
%   import_observations; the recorded sources of the model provider for
%   the steps that use the GP.
    inputs = struct('key', {}, 'path', {}, 'origin', {});
    if ismember(stepName, {'export_design', 'import_observations', 'prepare'})
        inputs(end+1) = struct('key', 'fixed_dataset_csv', 'path', cfg.realData.csv, 'origin', 'data');
    end
    if strcmp(stepName, 'import_observations')
        folder = cfg.native.observationFiles;
        for name = {'reviewed_export.csv', 'source_provenance.json', 'direct_data_acceptance.json'}
            inputs(end+1) = struct('key', regexprep(name{1}, '\.\w+$', ''), ...
                'path', fullfile(folder, name{1}), 'origin', 'input'); %#ok<AGROW>
        end
    end
    if ismember(stepName, {'export_design', 'prepare', 'run_cells', 'compare'})
        sources = cfg.native.providerSources;
        for name = reshape(fieldnames(sources), 1, [])
            inputs(end+1) = struct('key', name{1}, 'path', sources.(name{1}), ...
                'origin', 'shipped'); %#ok<AGROW>
        end
    end
end

function say(s, varargin)
    if ~strcmp(s.logging.level, 'quiet'), fprintf(varargin{:}); end
end

function t = utc_now()
    t = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
end
