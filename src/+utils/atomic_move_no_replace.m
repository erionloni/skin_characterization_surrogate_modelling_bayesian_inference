function atomic_move_no_replace(source, destination)
%ATOMIC_MOVE_NO_REPLACE Atomically publish one file without replacement.
%   Java NIO ATOMIC_MOVE is deliberately not used here: its specification
%   makes target-exists behavior implementation-specific and permits a POSIX
%   rename to replace the destination. Creating a same-filesystem hard link is
%   an atomic fail-if-exists operation. The private staging name is removed
%   only after the destination link exists.
%   utils.atomic_move_no_replace(SOURCE, DESTINATION) moves SOURCE to
%   DESTINATION (same folder system) and fails when DESTINATION exists.
%   Side effects: creates DESTINATION and removes SOURCE.

    source=utils.absolute_path(source);
    destination=utils.absolute_path(destination);
    assert(isfile(source), 'utils:atomic_move_no_replace:MissingSource', ...
        'Source file does not exist: %s', source);
    assert(~isfile(destination) && ~isfolder(destination), ...
        'utils:atomic_move_no_replace:DestinationExists', ...
        'Refusing to replace existing destination: %s', destination);
    sourcePath = javaObject('java.io.File', source).toPath();
    destinationPath = javaObject('java.io.File', destination).toPath();
    try
        javaMethod('createLink','java.nio.file.Files', ...
            destinationPath,sourcePath);
    catch ME
        if isfile(destination)
            error('utils:atomic_move_no_replace:DestinationExists', ...
                'Refusing to replace existing destination: %s',destination);
        end
        error('utils:atomic_move_no_replace:AtomicLinkUnsupported', ...
            ['Atomic fail-if-exists publication failed. The destination ' ...
             'filesystem must support same-filesystem hard links. %s'], ...
             ME.message);
    end
    try
        javaMethod('delete','java.nio.file.Files',sourcePath);
    catch ME
        error('utils:atomic_move_no_replace:SourceCleanupFailed', ...
            ['The immutable destination was published, but its private ' ...
             'staging link could not be removed: %s'],ME.message);
    end
end
