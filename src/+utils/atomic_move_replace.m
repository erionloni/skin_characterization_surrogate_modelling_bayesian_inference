function atomic_move_replace(source, destination)
%ATOMIC_MOVE_REPLACE Rename a file within one file system, replacing the destination.
%   utils.atomic_move_replace(SOURCE, DESTINATION) moves SOURCE onto
%   DESTINATION in one rename, retrying a few times when the file system
%   refuses briefly (a file held open by another process).
%   Side effects: replaces DESTINATION and removes SOURCE.

    source=utils.absolute_path(source);
    destination=utils.absolute_path(destination);
    assert(isfile(source), 'utils:atomic_move_replace:MissingSource', ...
        'Source file does not exist: %s',source);
    assert(~isfolder(destination), ...
        'utils:atomic_move_replace:DestinationDirectory', ...
        'Refusing to replace a directory: %s',destination);
    sourcePath = javaObject('java.io.File',source).toPath();
    destinationPath = javaObject('java.io.File',destination).toPath();
    atomicOption = javaMethod( ...
        'valueOf','java.nio.file.StandardCopyOption','ATOMIC_MOVE');
    replaceOption = javaMethod( ...
        'valueOf','java.nio.file.StandardCopyOption','REPLACE_EXISTING');
    options = javaArray('java.nio.file.CopyOption',2);
    options(1) = atomicOption;
    options(2) = replaceOption;
    % On Windows a sync client or file indexer can hold a just-written
    % destination for a moment (access denied): the same atomic move is
    % retried a few times before giving up. There is no non-atomic fallback.
    attempts = 5;
    for attempt = 1:attempts
        try
            javaMethod('move','java.nio.file.Files', ...
                sourcePath,destinationPath,options);
            return
        catch ME
            if attempt == attempts
                error('utils:atomic_move_replace:AtomicMoveFailed', ...
                    ['Atomic replacement failed; refusing a non-atomic fallback ' ...
                     'for publication state: %s'],ME.message);
            end
            pause(0.25 * attempt);
        end
    end
end
