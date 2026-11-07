function atomic_write_text(pathValue,textValue)
%ATOMIC_WRITE_TEXT Write text as UTF-8, all at once.
%   utils.atomic_write_text(PATH, TEXTVALUE) writes TEXTVALUE to a temporary
%   file next to PATH and moves it to PATH, replacing an earlier version.
%   Side effects: writes PATH.

    pathValue=utils.absolute_path(pathValue);
    [folder,~,extension]=fileparts(pathValue);
    assert(~isempty(extension), ...
        'utils:atomic_write_text:ExtensionRequired', ...
        'Text publication requires a filename extension.');
    if ~isfolder(folder),mkdir(folder);end
    temporary=utils.atomic_temporary_path(pathValue);
    cleanup=onCleanup(@()delete_if_present(temporary));
    fid=fopen(temporary,'wb');
    assert(fid>=0,'utils:atomic_write_text:OpenFailed', ...
        'Cannot create temporary text artifact: %s',temporary);
    closer=onCleanup(@()close_if_open(fid));
    bytes=unicode2native(char(string(textValue)),'UTF-8');
    count=fwrite(fid,bytes,'uint8');
    assert(count==numel(bytes),'utils:atomic_write_text:ShortWrite', ...
        'Incomplete UTF-8 write: %s',temporary);
    fclose(fid);
    clear closer
    utils.atomic_move_replace(temporary,pathValue);
end

function close_if_open(fid)
    if ~isempty(fopen(fid)),fclose(fid);end
end

function delete_if_present(pathValue)
    if isfile(pathValue),delete(pathValue);end
end
