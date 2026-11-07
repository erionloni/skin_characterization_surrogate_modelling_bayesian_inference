function varargout = run_record(action, varargin)
%RUN_RECORD The record of a run folder: every call of an entry point and every completed step.
%   <run>/run_record.json holds
%     calls  one element per call of an entry point on the run folder, in
%            order: entry point, mode, scale, the steps requested, run,
%            reused and taken from the shipped results, the name-value
%            arguments of the call, the complete settings, the code version
%            (git commit), the MATLAB and UQLab versions, start and end
%            time and status ('running', 'complete' or 'failed' with the
%            error); a rerun adds the steps it completed, a reproduce call
%            the analyses and figures it rendered, and a call with reduced
%            settings its demonstration notice;
%     steps  one element per completed step (its last completion): route,
%            step, the call that completed it, start and end time,
%            duration, inputs (key, path, origin: 'run', 'placed',
%            'shipped', 'data', 'config' or 'input'), outputs (locations
%            below the run folder) and the step's details (for example the
%            state of a partial inversion campaign, or 'scale' 'example').
%   The plan (study.plan), the input resolution (study.resolve_input), the
%   step 'figures' (study.render_run) and the READMEs of a rerun read it.
%   Paths are written relative to the run folder (the files a step wrote),
%   to the repository (shipped results, data/, config/) or to the user
%   folder ('~/'), so that no personal absolute path is recorded.
%
%   R = study.run_record('read', RUN)             the record of run folder
%       RUN (fields calls and steps, each a cell array of structs), or []
%       when the run has none
%   E = study.run_record('step', RUN, ROUTE, STEP) the element of STEP of
%       ROUTE ('fixed' or 'generalized'), or [] when the step has not
%       completed in RUN
%   K = study.run_record('start', S, CALL)        appends the call CALL (a
%       struct; study.run) for the resolved settings S and returns its index
%   study.run_record('finish', S, K, FIELDS)      sets the fields FIELDS (a
%       struct) of call K
%   E = study.run_record('complete', S, K, STEP)  records STEP (a struct with
%       route, step, started_utc, elapsed_seconds, inputs, outputs,
%       details) as completed by call K, replacing an earlier completion
%
%   Separate MATLAB processes may work on one run folder (cells of a
%   campaign, steps in parallel): every change reads, changes and writes
%   the record under a lock (the folder <run>/_run/run_record.lock); a read
%   that meets a record being replaced is tried again.
%   Side effects: 'start', 'finish' and 'complete' write
%   <run>/run_record.json.

    switch action
        case 'read'
            runFolder = varargin{1};
            R = [];
            if isfile(record_path(runFolder)), R = read_record(runFolder); end
            varargout{1} = R;
        case 'step'
            [runFolder, route, stepName] = varargin{1:3};
            E = [];
            if isfile(record_path(runFolder))
                R = read_record(runFolder);
                k = find_step(R, route, stepName);
                if ~isempty(k), E = R.steps{k}; end
            end
            varargout{1} = E;
        case 'start'
            [s, call] = varargin{1:2};
            call = portable_value(call);
            index = 0;
            update(s, @append_call);
            varargout{1} = index;
        case 'finish'
            [s, index, fields] = varargin{1:3};
            fields = portable_value(fields);
            update(s, @finish_call);
        case 'complete'
            [s, index, E] = varargin{1:3};
            E.call = index;
            E.finished_utc = utc_now();
            for i = 1:numel(E.inputs)
                E.inputs(i).path = portable_path(E.inputs(i).path, s.paths.run);
            end
            E.details = portable_value(E.details);
            % Lists stay JSON arrays with a single element.
            E.inputs = num2cell(reshape(E.inputs, 1, []));
            E.outputs = reshape(cellstr(E.outputs), 1, []);
            E = orderfields_as(E, {'route', 'step', 'call', 'started_utc', 'finished_utc', ...
                'elapsed_seconds', 'inputs', 'outputs', 'details'});
            update(s, @complete_step);
            varargout{1} = E;
        otherwise
            error('study:run_record:Action', 'Unknown action "%s".', action);
    end

    function R = append_call(R)
        R.calls{end+1} = call;
        index = numel(R.calls);
    end

    function R = finish_call(R)
        names = fieldnames(fields);
        for f = 1:numel(names)
            R.calls{index}.(names{f}) = fields.(names{f});
        end
    end

    function R = complete_step(R)
        k = find_step(R, E.route, E.step);
        if isempty(k), k = numel(R.steps) + 1; end
        R.steps{k} = E;
    end
end

function update(s, change)
%UPDATE Read the record, apply CHANGE and write the record back, under the lock.
%   A lock older than a minute was left by a process that stopped (an
%   update takes well under a second) and is removed.
    runFolder = s.paths.run;
    lock = fullfile(runFolder, '_run', 'run_record.lock');
    if ~isfolder(fileparts(lock)), mkdir(fileparts(lock)); end
    waiting = tic;
    while true
        [created, message, id] = mkdir(lock);
        assert(created, 'study:run_record:Lock', 'Cannot create the lock %s: %s', lock, message);
        if isempty(id), break; end
        listing = dir(lock);
        self = listing(strcmp({listing.name}, '.'));
        if ~isempty(self) && seconds(datetime('now') - ...
                datetime(self.datenum, 'ConvertFrom', 'datenum')) > 60
            [~, ~] = rmdir(lock);
            continue;
        end
        assert(toc(waiting) < 300, 'study:run_record:Busy', ...
            'The run record of %s stayed locked for five minutes (%s).', runFolder, lock);
        pause(0.05 + 0.1 * rand);
    end
    release = onCleanup(@() rmdir_quietly(lock));
    R = struct('schema', 'study_run_record_v1', 'run', s.run.name, 'calls', {{}}, 'steps', {{}});
    if isfile(record_path(runFolder)), R = read_record(runFolder); end
    R = change(R);
    utils.atomic_write_json(record_path(runFolder), R, 'AllowReplace', true);
    clear release
end

function rmdir_quietly(folder)
    [~, ~] = rmdir(folder);
end

function p = record_path(runFolder)
    p = fullfile(runFolder, 'run_record.json');
end

function R = read_record(runFolder)
%READ_RECORD The record with calls and steps as cell arrays of structs.
%   A writer replaces the record by a rename (utils.atomic_write_json). On a
%   network file system (the home folders of a computing cluster) a process
%   on another computer that is reading the record at that moment can get a
%   cut-off text, so a read that does not decode is tried again (20 times,
%   about 10 s in all) before its error is raised.
    attempts = 20;
    for attempt = 1:attempts
        try
            R = jsondecode(fileread(record_path(runFolder)));
            break
        catch ME
            if attempt == attempts, rethrow(ME); end
            pause(0.25 + 0.25 * rand);
        end
    end
    R.calls = as_cells(R.calls);
    R.steps = as_cells(R.steps);
    % A step that wrote nothing (the confirmation's run_cells once every cell
    % has run elsewhere) has the outputs [], which jsondecode returns as a
    % number: the outputs are always a row cell array of texts.
    for k = 1:numel(R.steps)
        if isfield(R.steps{k}, 'outputs')
            if isempty(R.steps{k}.outputs)
                R.steps{k}.outputs = {};
            else
                R.steps{k}.outputs = reshape(cellstr(R.steps{k}.outputs), 1, []);
            end
        end
    end
end

function c = as_cells(value)
%AS_CELLS A decoded JSON array of objects as a row cell array of structs
%   (jsondecode gives a struct array when the objects have the same fields,
%   otherwise a cell array, and [] for an empty array).
    if isempty(value)
        c = {};
    elseif isstruct(value)
        c = reshape(num2cell(value), 1, []);
    else
        c = reshape(value, 1, []);
    end
end

function k = find_step(R, route, stepName)
    k = find(cellfun(@(e) strcmp(e.route, route) && strcmp(e.step, stepName), R.steps), 1);
end

function E = orderfields_as(E, order)
    rest = setdiff(fieldnames(E), order, 'stable');
    E = orderfields(E, [order(isfield(E, order)), reshape(rest, 1, [])]);
end

function p = portable_path(p, runFolder)
%PORTABLE_PATH One path relative to the run folder, the repository or the user folder.
    p = char(string(p));
    absolute = strrep(p, '\', '/');
    for base = {{runFolder, ''}, {study.root(), ''}, {home_folder(), '~/'}}
        prefix = normalized(base{1}{1});
        if ~isempty(prefix) && strncmpi(absolute, [prefix '/'], numel(prefix) + 1)
            p = [base{1}{2} absolute(numel(prefix) + 2:end)];
            return;
        end
    end
end

function value = portable_value(value)
%PORTABLE_VALUE A struct, cell or text with every path inside the repository written relative to it
%   and every other path inside the user folder written as '~/...'
%   (settings, call arguments, error messages). Numbers and logicals are unchanged.
    repository = normalized(study.root());
    home = normalized(home_folder());
    value = walk(value);

    function v = walk(v)
        if isstruct(v)
            names = fieldnames(v);
            for k = 1:numel(v)
                for f = 1:numel(names)
                    v(k).(names{f}) = walk(v(k).(names{f}));
                end
            end
        elseif iscell(v)
            for k = 1:numel(v), v{k} = walk(v{k}); end
        elseif ischar(v) || isstring(v)
            wasString = isstring(v);
            text = strrep(char(v), '\', '/');
            text = replace_prefix(text, repository, '');
            text = replace_prefix(text, home, '~/');
            if wasString, v = string(text); else, v = text; end
        end
    end
end

function text = replace_prefix(text, prefix, replacement)
    if isempty(prefix), return; end
    if strcmpi(text, prefix)
        text = '.';
        if ~isempty(replacement), text = replacement(1:end-1); end
        return;
    end
    index = strfind(lower(text), lower([prefix '/']));
    while ~isempty(index)
        k = index(1);
        text = [text(1:k-1) replacement text(k+numel(prefix)+1:end)];
        index = strfind(lower(text), lower([prefix '/']));
    end
end

function p = normalized(p)
    p = strrep(char(string(p)), '\', '/');
    while endsWith(p, '/'), p = p(1:end-1); end
end

function p = home_folder()
%HOME_FOLDER The user folder, from the JVM rather than an environment variable (CLN-007).
    p = char(java.lang.System.getProperty('user.home'));
end

function t = utc_now()
    t = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
end
