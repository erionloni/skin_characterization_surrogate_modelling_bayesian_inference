function [ensemble,resolver] = load_ensemble(pathValue, family)
%LOAD_ENSEMBLE Load a surrogate artifact, directly or through its resolver.
%   [ENSEMBLE, RESOLVER] = surrogates.load_ensemble(PATH, FAMILY) loads the
%   GP or PCE (FAMILY 'gp' or 'pce') of the file PATH. A file with the
%   variable FAMILY holds the model itself (RESOLVER is an empty struct).
%   The generalized route stores a small resolver instead (variable
%   <FAMILY>Resolver, returned as RESOLVER) that names its ensemble file:
%   the ensemble is read at the recorded path or, in the layout of thesis_results/
%   and of a run folder, under the same file name in
%   <data>/surrogates/<family>/ensembles/, next to the resolver's models/
%   folder. Files are read as they are, without hash checks.
%   Side effects: none.

    arguments
        pathValue (1,:) char
        family (1,:) char
    end
    assert(isfile(pathValue), 'surrogates:load_ensemble:MissingArtifact', ...
        'The surrogate file %s does not exist.', pathValue);
    loaded = load(pathValue);
    directName = lower(family);
    resolverName = [directName 'Resolver'];

    resolver=struct();
    if isfield(loaded, directName)
        ensemble = loaded.(directName);
        return;
    end
    assert(isfield(loaded, resolverName), ...
        'surrogates:load_ensemble:BadResolver', ...
        'The file %s holds neither a %s model nor a %s.', pathValue, ...
        directName, resolverName);
    resolver = loaded.(resolverName);
    assert(isstruct(resolver) && all(isfield(resolver, {'family','artifactPath'})), ...
        'surrogates:load_ensemble:IncompleteResolver', ...
        'The resolver in %s does not name its ensemble file.', pathValue);
    assert(strcmpi(resolver.family, family), ...
        'surrogates:load_ensemble:FamilyMismatch', ...
        'The resolver in %s is for a %s, not a %s.', pathValue, ...
        resolver.family, family);
    resolvedPath = char(string(resolver.artifactPath));
    if ~is_absolute(resolvedPath)
        % Publication resolvers record artifacts relative to the run root.
        % cfg.files.gp/pce lives at <run>/<route>/02_surrogates/data/models/
        % (thesis_results/ is laid out the same way), so the run root is four
        % folders above the resolver's folder.
        runRoot=fileparts(utils.absolute_path(pathValue));
        for up=1:4, runRoot=fileparts(runRoot); end
        resolvedPath=fullfile(runRoot,strrep(resolvedPath,'/',filesep));
    end
    if ~isfile(resolvedPath)
        % The recorded path names the layout of the run that wrote the
        % resolver; thesis_results/ and new runs keep the ensemble, under the same
        % file name, next to the resolver.
        [~, artifactStem, artifactExt] = fileparts(resolvedPath);
        stageRoot=fileparts(fileparts(utils.absolute_path(pathValue)));
        localCandidate = fullfile(stageRoot,'surrogates',lower(family), ...
            'ensembles',[artifactStem artifactExt]);
        assert(isfile(localCandidate), ...
            'surrogates:load_ensemble:MissingResolvedArtifact', ...
            ['The ensemble file named by the resolver %s is missing: neither ' ...
             '%s nor %s exists.'], pathValue, resolvedPath, localCandidate);
        resolvedPath = localCandidate;
    end
    payload = load(resolvedPath);
    assert(isfield(payload, directName), ...
        'surrogates:load_ensemble:MissingEnsemble', ...
        'The ensemble file %s holds no %s.', resolvedPath, directName);
    ensemble = payload.(directName);
end

function tf=is_absolute(pathValue)
    tf=javaObject('java.io.File',char(string(pathValue))).isAbsolute();
end
