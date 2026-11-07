function environment = activate_uqlab(repositoryRoot, uqlabCandidate, varargin)
%ACTIVATE_UQLAB Put the repository and UQLab on the MATLAB path and start UQLab.
%   ENVIRONMENT = utils.activate_uqlab(REPO, UQLABROOT) adds the repository
%   REPO (with its src/ folder) and the UQLab installation in
%   UQLABROOT (the installation folder or a folder that contains it;
%   utils.discover_uqlab) to the MATLAB path and starts UQLab. It refuses
%   when another uqlab.m than the one in UQLABROOT would be called.
%   Options (name-value): 'StartUQLab' (default true); 'ResetToDefault'
%   (default false: restore the default MATLAB path first).
%   ENVIRONMENT records the MATLAB and UQLab versions and the UQLab folder;
%   ENVIRONMENT.line is the one-line provenance (utils.environment_line)
%   that run records carry. The code runs with any MATLAB and UQLab release;
%   nothing is compared with a required release.
%   Side effects: changes the MATLAB path; starts UQLab.

    parser = inputParser;
    addParameter(parser,'ResetToDefault',false, ...
        @(x)islogical(x)&&isscalar(x));
    addParameter(parser,'StartUQLab',true, ...
        @(x)islogical(x)&&isscalar(x));
    parse(parser,varargin{:});

    repositoryRoot = canonical_path(repositoryRoot);
    assert(isfolder(repositoryRoot),'utils:activate_uqlab:MissingRepository', ...
        'Repository root does not exist: %s',repositoryRoot);
    discovery = utils.discover_uqlab(uqlabCandidate);

    if parser.Results.ResetToDefault
        restoredefaultpath;
    else
        remove_uqlab_paths();
    end
    clear('uqlab','uq_rootPath');
    addpath(repositoryRoot,'-begin');
    addpath(fullfile(repositoryRoot,'src'),'-begin');
    addpath(discovery.core,'-begin');
    assert_single_entry(discovery.entryPath);
    if parser.Results.StartUQLab
        uqlab('-nosplash');
        assert_single_entry(discovery.entryPath);
    end
    environment = struct( ...
        'schemaVersion','publication_environment_v2', ...
        'line',utils.environment_line(discovery.root), ...
        'matlabRelease',['R' version('-release')], ...
        'matlabVersion',version, ...
        'uqlabRelease',discovery.distributionRelease, ...
        'uqlabRoot',discovery.root);
end

function remove_uqlab_paths()
    entries = strsplit(path,pathsep);
    mask = contains(lower(string(entries)),'uqlab');
    for k=find(mask)
        try
            rmpath(entries{k});
        catch
            % The entry-point check below still refuses a wrong uqlab.m.
        end
    end
end

function assert_single_entry(expected)
    matches = which('uqlab','-all');
    if ischar(matches), matches={matches}; end
    assert(isscalar(matches),'utils:activate_uqlab:PathShadowing', ...
        ['Expected one uqlab.m on the MATLAB path; found %d. Remove other ' ...
         'UQLab installations from the path.'],numel(matches));
    actual = canonical_path(matches{1});
    assert(strcmpi(actual,canonical_path(expected)), ...
        'utils:activate_uqlab:WrongEntryPoint', ...
        ['MATLAB calls the uqlab.m in %s, not the configured one in %s; remove ' ...
         'the other installation from the path.'],actual,expected);
end

function pathValue = canonical_path(pathValue)
    pathValue = char(javaObject('java.io.File', ...
        char(string(pathValue))).getCanonicalPath());
end
