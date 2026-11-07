function atomic_save_struct(pathValue,variables,version,varargin)
%ATOMIC_SAVE_STRUCT Atomically write one MAT file from a scalar struct.
%   utils.atomic_save_struct(PATH, VARIABLES) writes the fields of the scalar
%   struct VARIABLES as the variables of the MAT file PATH (format -v7),
%   replacing an existing file.
%   utils.atomic_save_struct(PATH, VARIABLES, VERSION) writes the format
%   VERSION, '-v7' or '-v7.3' (HDF5-based; arrays over 2 GB).
%   utils.atomic_save_struct(..., 'NoReplace', true) refuses to replace an
%   existing file: checkpoints are written once.
%   The file is written under a temporary name and then moved into place on
%   the same file system, so a reader never sees a partial file. A -v7.3
%   file is written in <run>/_run/staging when PATH lies in a run folder (a
%   folder with a _run subfolder), else next to PATH: MATLAB's HDF5-based
%   writer can fail on Windows for paths over 260 characters, which long
%   result paths reach; the move handles long paths.
%   Side effects: writes PATH and creates its folder.

    if nargin<3||isempty(version),version='-v7';end
    parser=inputParser;
    addParameter(parser,'NoReplace',false,@(x)islogical(x)&&isscalar(x));
    parse(parser,varargin{:});
    noReplace=parser.Results.NoReplace;
    assert(isstruct(variables)&&isscalar(variables), ...
        'utils:atomic_save_struct:Variables', ...
        'Variables must be supplied as one scalar struct.');
    assert(any(strcmp(version,{'-v7','-v7.3'})), ...
        'utils:atomic_save_struct:Version', ...
        'MAT version must be -v7 or -v7.3.');
    pathValue=utils.absolute_path(pathValue);
    [folder,~,extension]=fileparts(pathValue);
    assert(strcmpi(extension,'.mat'), ...
        'utils:atomic_save_struct:Extension', ...
        'Atomic MAT publication requires a .mat destination.');
    assert(~noReplace||~isfile(pathValue), ...
        'utils:atomic_save_struct:DestinationExists', ...
        'The file %s exists and is written only once; write to a new run folder.', ...
        pathValue);
    if ~isfolder(folder),mkdir(folder);end
    staging=folder;
    if strcmp(version,'-v7.3'),staging=run_staging_folder(folder);end
    temporary=utils.atomic_temporary_path(fullfile(staging,'staged.mat'));
    cleanup=onCleanup(@()delete_if_present(temporary));
    save(temporary,'-struct','variables',version);
    if noReplace
        utils.atomic_move_no_replace(temporary,pathValue);
    else
        utils.atomic_move_replace(temporary,pathValue);
    end
end

function staging=run_staging_folder(folder)
%RUN_STAGING_FOLDER <run>/_run/staging for a folder inside a run folder, else FOLDER.
    staging=folder;
    cursor=folder;
    while true
        if isfolder(fullfile(cursor,'_run'))
            staging=fullfile(cursor,'_run','staging');
            if ~isfolder(staging),mkdir(staging);end
            return
        end
        parent=fileparts(cursor);
        if isempty(parent)||strcmp(parent,cursor),return;end
        cursor=parent;
    end
end

function delete_if_present(pathValue)
    if isfile(pathValue),delete(pathValue);end
end
