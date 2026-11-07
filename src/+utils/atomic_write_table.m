function atomic_write_table(pathValue,tableValue,varargin)
%ATOMIC_WRITE_TABLE Publish a CSV table through a same-directory atomic move.
%   The staging filename retains .csv as its final extension so MATLAB never
%   has to infer the format from a UUID suffix.
%   utils.atomic_write_table(PATH, TABLEVALUE) writes the table TABLEVALUE
%   to PATH (a .csv file), replacing an earlier version.
%   Side effects: writes PATH.

    assert(istable(tableValue),'utils:atomic_write_table:NotTable', ...
        'The value to publish must be a MATLAB table.');
    pathValue=utils.absolute_path(pathValue);
    [folder,~,extension]=fileparts(pathValue);
    assert(strcmpi(extension,'.csv'), ...
        'utils:atomic_write_table:CSVRequired', ...
        'Atomic table publication currently requires a .csv destination.');
    if ~isfolder(folder),mkdir(folder);end
    temporary=utils.atomic_temporary_path(pathValue);
    cleanup=onCleanup(@()delete_if_present(temporary));
    writetable(tableValue,temporary,'FileType','text','Delimiter',',', ...
        varargin{:});
    utils.atomic_move_replace(temporary,pathValue);
end

function delete_if_present(pathValue)
    if isfile(pathValue),delete(pathValue);end
end
