function discovery = discover_uqlab(candidate)
%DISCOVER_UQLAB Find the one UQLab installation in a folder.
%   DISCOVERY = utils.discover_uqlab(CANDIDATE) finds the complete UQLab
%   installation (core/, modules/ and lib/) in CANDIDATE: the installation
%   folder itself or a folder that holds one extracted installation. Fields:
%   root, core, entryPath (core/uqlab.m), installerPath, versionFile,
%   distributionRelease (the content of core/VERSION, e.g. '2.3.0'; empty
%   when the file is missing), hasExamples, hasDocumentation, and
%   allValidRoots (every installation found). Any release is accepted; the
%   thesis used UQLab 2.3.0, and every run records the release it used
%   (utils.environment_line).
%   Side effects: none (reads the folder).

    candidate = canonical_path(candidate);
    assert(isfolder(candidate), 'utils:discover_uqlab:MissingCandidate', ...
        'The UQLab folder does not exist: %s', candidate);

    directInstaller = fullfile(candidate, 'core', 'uqlab_install.m');
    if isfile(directInstaller)
        installers = dir(directInstaller);
    else
        installers = dir(fullfile(candidate, '**', 'uqlab_install.m'));
    end
    roots = {};
    records = repmat(empty_record(), 0, 1);
    for k = 1:numel(installers)
        installer = canonical_path(fullfile(installers(k).folder, installers(k).name));
        core = canonical_path(fileparts(installer));
        root = canonical_path(fileparts(core));
        if ~strcmpi(last_component(core), 'core')
            continue;
        end
        if ~(isfolder(fullfile(root, 'core')) && ...
                isfolder(fullfile(root, 'modules')) && ...
                isfolder(fullfile(root, 'lib')) && ...
                isfile(fullfile(root, 'core', 'uqlab.m')))
            continue;
        end
        versionFile = fullfile(root, 'core', 'VERSION');
        release = '';
        if isfile(versionFile), release = strtrim(fileread(versionFile)); end
        key = lower(root);
        if any(strcmp(roots, key)), continue; end
        roots{end+1} = key; %#ok<AGROW>
        record = empty_record();
        record.root = root;
        record.core = core;
        record.distributionRelease = release;
        record.installerPath = installer;
        record.entryPath = fullfile(core, 'uqlab.m');
        record.versionFile = versionFile;
        record.hasExamples = isfolder(fullfile(root, 'Examples'));
        record.hasDocumentation = isfolder(fullfile(root, 'Doc'));
        records(end+1, 1) = record; %#ok<AGROW>
    end

    if isempty(records)
        error('utils:discover_uqlab:NoValidRoot', ...
            ['No complete UQLab installation (core/uqlab.m, modules/, lib/) in "%s". ' ...
             'Set UQLabRoot to the folder of your UQLab installation.'], candidate);
    end
    if numel(records) > 1
        found = strjoin(arrayfun(@(r) sprintf('%s [%s]', ...
            r.root, empty_as(r.distributionRelease, 'release unknown')), ...
            records, 'UniformOutput', false), '; ');
        error('utils:discover_uqlab:AmbiguousRoot', ...
            ['"%s" holds %d UQLab installations: %s. Set UQLabRoot to the ' ...
             'folder of one of them.'], candidate, numel(records), found);
    end

    discovery = records(1);
    discovery.schemaVersion = 'publication_uqlab_discovery_v2';
    discovery.candidate = candidate;
    discovery.allValidRoots = records;
end

function record = empty_record()
    record = struct('root', '', 'core', '', 'distributionRelease', '', ...
        'installerPath', '', 'entryPath', '', 'versionFile', '', ...
        'hasExamples', false, 'hasDocumentation', false);
end

function value = empty_as(value, fallback)
    if isempty(value), value = fallback; end
end

function name = last_component(pathValue)
    [~, name] = fileparts(pathValue);
end

function pathValue = canonical_path(pathValue)
    pathValue = char(javaObject('java.io.File', ...
        char(string(pathValue))).getCanonicalPath());
end
