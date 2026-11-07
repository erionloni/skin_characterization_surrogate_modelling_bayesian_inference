function report = check_installation(varargin)
%CHECK_INSTALLATION Check that this computer can reproduce and rerun the thesis results.
%   check_installation() prints a checklist and returns a table with one row
%   per check (Check, Status, Detail, NeededFor). Status is PASS, FAIL, WARN
%   or SKIP.
%     - MATLAB release (tested: R2024a and R2025b; at least R2021a) and
%       the base functions used to draw figures;
%     - repository folders;
%     - the settings file study_settings.m: every setting present and
%       valid (study.validate_settings);
%     - the configuration records and datasets the settings select and the
%       shipped results (presence; no hashes);
%     - UQLab (the thesis used 2.3.0) and the Optimization and Global
%       Optimization toolboxes, which are needed only to rerun steps
%       (Mode 'rerun').
%   A FAIL in a check that reproduce mode needs raises an error at the end,
%   so "matlab -batch check_installation" exits with a non-zero status.
%
%   Options (name-value):
%     'UQLabRoot'   UQLab installation to check (default: study_settings.m,
%                   then the UQLAB_ROOT environment variable)
%     'StartUQLab'  true: also start UQLab once (default false)
%
%   Side effects: adds src/ to the MATLAB path; 'StartUQLab',true also adds
%   the repository and UQLab to the path and starts UQLab.

    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'src'));
    parser = inputParser;
    addParameter(parser, 'UQLabRoot', '', @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, 'StartUQLab', false, @(x) islogical(x) && isscalar(x));
    parse(parser, varargin{:});
    o = parser.Results;
    [s, settingsRow] = check_settings(o.UQLabRoot);

    rows = {};
    rows(end+1, :) = check_matlab();
    rows(end+1, :) = check_functions();
    rows(end+1, :) = check_folders(root);
    rows(end+1, :) = settingsRow;
    rows(end+1, :) = check_selected(s, 'Configuration records', @records);
    rows(end+1, :) = check_selected(s, 'Datasets', @datasets);
    rows(end+1, :) = check_results(root);
    rows(end+1, :) = check_toolboxes();
    rows(end+1, :) = check_uqlab(root, s, o.StartUQLab);

    report = cell2table(rows, 'VariableNames', {'Check', 'Status', 'Detail', 'NeededFor'});
    print_report(report);
    required = strcmp(report.NeededFor, 'reproduce and rerun');
    failed = required & strcmp(report.Status, 'FAIL');
    if any(failed)
        error('check_installation:Failed', ...
            '%d required check(s) failed: %s', nnz(failed), ...
            strjoin(report.Check(failed)', ', '));
    end
end

function [s, row] = check_settings(uqlabRoot)
%CHECK_SETTINGS The settings file is complete and valid (study.validate_settings).
    s = [];
    try
        s = study.resolve_settings('fixed', 'UQLabRoot', uqlabRoot, 'Plan', true);
        row = {'Settings file', 'PASS', sprintf('study_settings.m: %d settings, all valid', ...
            numel(study.settings_schema())), 'reproduce and rerun'};
    catch err
        row = {'Settings file', 'FAIL', err.message, 'reproduce and rerun'};
    end
end

function row = check_matlab()
%CHECK_MATLAB The release: the code was tested with R2024a and R2025b and needs at least R2021a.
    release = ['R' version('-release')];
    tested = {'R2024a', 'R2025b'};
    number = sscanf(version, '%d.%d');          % MATLAB 9.10 = R2021a
    if number(1) * 100 + number(2) < 910
        row = {'MATLAB release', 'FAIL', [release ': R2021a or newer is required (tested: R2024a, ' ...
            'R2025b)'], 'reproduce and rerun'};
    elseif ismember(release, tested)
        row = {'MATLAB release', 'PASS', release, 'reproduce and rerun'};
    else
        row = {'MATLAB release', 'WARN', [release ': not tested; the code was tested with R2024a ' ...
            'and R2025b'], 'reproduce and rerun'};
    end
end

function row = check_functions()
    names = {'exportgraphics', 'tiledlayout', 'jsondecode', 'readtable', 'quantile', 'iqr'};
    missing = names(cellfun(@(n) isempty(which(n)), names));
    if isempty(missing)
        row = {'MATLAB functions for figures and tables', 'PASS', strjoin(names, ', '), 'reproduce and rerun'};
    else
        row = {'MATLAB functions for figures and tables', 'FAIL', ...
            ['missing: ' strjoin(missing, ', ') ' (quantile/iqr need the Statistics and ' ...
             'Machine Learning Toolbox before R2022a)'], 'reproduce and rerun'};
    end
end

function row = check_folders(root)
    needed = {'src', 'config'};
    optionalNow = {'data', 'thesis_results'};
    missing = needed(~cellfun(@(f) isfolder(fullfile(root, f)), needed));
    absent = optionalNow(~cellfun(@(f) isfolder(fullfile(root, f)), optionalNow));
    if ~isempty(missing)
        row = {'Repository folders', 'FAIL', ['missing: ' strjoin(missing, ', ')], 'reproduce and rerun'};
    elseif ~isempty(absent)
        row = {'Repository folders', 'WARN', ['not present yet: ' strjoin(absent, ', ')], 'reproduce and rerun'};
    else
        row = {'Repository folders', 'PASS', 'src, config, data, thesis_results', 'reproduce and rerun'};
    end
end

function row = check_selected(s, label, list)
%CHECK_SELECTED The files and folders the settings select exist.
%   LIST(S) returns them as settings paths (relative to the repository
%   unless absolute); a folder is named with a trailing '/'.
    if isempty(s)
        row = {label, 'FAIL', 'the settings file is invalid (see above)', 'reproduce and rerun'};
        return;
    end
    paths = list(s);
    present = cellfun(@(p) exists(study.settings_path(s, p)), paths);
    if all(present)
        row = {label, 'PASS', sprintf('%d present, as the settings select', numel(paths)), ...
            'reproduce and rerun'};
    else
        row = {label, 'FAIL', ['missing: ' strjoin(paths(~present), ', ')], 'reproduce and rerun'};
    end
end

function tf = exists(p)
    if endsWith(p, {'/', '\'})
        tf = isfolder(p);
    else
        tf = isfile(p);
    end
end

function paths = records(s)
%RECORDS The configuration records the settings select (A.3, B.3, 0.6).
    tables = struct2cell(s.seeds.tables);
    paths = [{s.fixed.surrogates.auditSelection, s.fixed.surrogates.emulatorCalibration, ...
        s.generalized.surrogates.fitPolicy, s.generalized.surrogates.emulatorCalibration}, ...
        cellfun(@(t) [s.seeds.folder '/' t], reshape(tables, 1, []), 'UniformOutput', false)];
end

function paths = datasets(s)
%DATASETS The datasets the settings select (A.1, B.1).
%   The accepted confirmation observations (B.7) exist only once the COMSOL
%   campaign is accepted, so they are not required here.
    paths = {s.fixed.dataset.file, s.generalized.dataset.file};
end

function row = check_results(root)
%CHECK_RESULTS Every analysis folder of the shipped results is present.
    A = study.analyses();
    results = fullfile(root, 'thesis_results');
    absent = {};
    for i = 1:numel(A)
        folder = fullfile(results, A(i).route, A(i).folder);
        if ~isfolder(folder) || (~isfolder(fullfile(folder, 'figures')) && ...
                ~isfolder(fullfile(folder, 'tables')))
            absent{end+1} = [A(i).route '/' A(i).folder]; %#ok<AGROW>
        end
    end
    indexes = {'README.md', 'fixed/04_inversion/data/draws/index.csv'};
    absent = [absent, indexes(~cellfun(@(f) isfile(fullfile(results, strrep(f, '/', filesep))), indexes))];
    if isempty(absent)
        row = {'Shipped results', 'PASS', sprintf('%d analysis folders, the README and the draw index present', ...
            numel(A)), 'reproduce and rerun'};
    else
        row = {'Shipped results', 'FAIL', ['missing: ' strjoin(absent, ', ')], 'reproduce and rerun'};
    end
end

function row = check_toolboxes()
    have = @(licenseName, fn) logical(license('test', licenseName)) && ~isempty(which(fn));
    missing = {};
    if ~have('optimization_toolbox', 'fmincon'), missing{end+1} = 'Optimization Toolbox'; end
    if ~have('gads_toolbox', 'ga'), missing{end+1} = 'Global Optimization Toolbox'; end
    if isempty(missing)
        row = {'Toolboxes for surrogate fitting', 'PASS', ...
            'Optimization and Global Optimization Toolbox (UQLab HGA optimizer)', 'rerun'};
    else
        row = {'Toolboxes for surrogate fitting', 'WARN', ...
            ['missing: ' strjoin(missing, ', ') '; GP refits (HGA) will not run'], 'rerun'};
    end
end

function row = check_uqlab(root, s, start)
    if isempty(s)
        row = {'UQLab', 'SKIP', 'the settings file is invalid (see above)', 'rerun'};
        return;
    end
    candidate = s.paths.uqlabRoot;
    if isempty(candidate)
        row = {'UQLab', 'WARN', ['not configured: set s.paths.uqlabRoot in study_settings.m ' ...
            'or the UQLAB_ROOT environment variable (needed only for reruns)'], 'rerun'};
        return;
    end
    try
        discovery = utils.discover_uqlab(candidate);
        detail = sprintf('UQLab %s at %s (from %s)', discovery.distributionRelease, ...
            discovery.root, s.provenance.uqlabRootSource);
        if start
            utils.activate_uqlab(root, candidate, 'StartUQLab', true);
            detail = [detail '; started successfully'];
        end
        if strcmp(discovery.distributionRelease, '2.3.0')
            row = {'UQLab', 'PASS', detail, 'rerun'};
        else
            % Information, not a requirement: a rerun records the release it used.
            row = {'UQLab', 'WARN', [detail '; the thesis results were computed with ' ...
                'UQLab 2.3.0, another release may give slightly different numbers'], 'rerun'};
        end
    catch err
        row = {'UQLab', 'WARN', sprintf('%s (%s)', err.message, candidate), 'rerun'};
    end
end

function print_report(report)
    fprintf('\nInstallation check\n');
    for i = 1:height(report)
        fprintf('  [%-4s] %-42s %s\n', report.Status{i}, report.Check{i}, report.Detail{i});
    end
    fprintf('\nReproducing the shipped results needs only the checks marked "reproduce and rerun".\n');
    fprintf('Rerunning steps additionally needs UQLab and the fitting toolboxes.\n\n');
end
