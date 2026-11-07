function temporary = atomic_temporary_path(destination)
%ATOMIC_TEMPORARY_PATH Unique same-directory staging path with final extension.
%   The compact basename avoids pushing otherwise valid Windows paths beyond
%   legacy path-length limits. Keeping the destination extension last allows
%   MATLAB writers that infer format from the filename to work correctly.
%   TEMPORARY = utils.atomic_temporary_path(DESTINATION) returns such a
%   path next to DESTINATION.
%   Side effects: none.

    destination = utils.absolute_path(destination);
    [folder,~,extension] = fileparts(destination);
    if isempty(folder),folder=pwd;end
    assert(isfolder(folder), ...
        'utils:atomic_temporary_path:ParentMissing', ...
        'Destination parent must exist: %s',folder);
    assert(~isempty(extension), ...
        'utils:atomic_temporary_path:ExtensionRequired', ...
        'An extension-preserving temporary path requires a destination extension.');
    token = erase(char(javaMethod('randomUUID','java.util.UUID')),'-');
    token = token(1:20);
    temporary = fullfile(folder,['.router-' token extension]);
    assert(~isfile(temporary)&&~isfolder(temporary), ...
        'utils:atomic_temporary_path:Collision', ...
        'Generated temporary path already exists: %s',temporary);
    assert(strcmpi(fileparts_extension(temporary),extension), ...
        'utils:atomic_temporary_path:ExtensionMismatch', ...
        'Temporary path does not preserve destination extension.');
end

function extension = fileparts_extension(pathValue)
    [~,~,extension] = fileparts(pathValue);
end
