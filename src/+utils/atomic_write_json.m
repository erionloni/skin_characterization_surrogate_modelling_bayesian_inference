function atomic_write_json(pathValue, value, varargin)
%ATOMIC_WRITE_JSON Write a value as UTF-8 JSON, all at once.
%   utils.atomic_write_json(PATH, VALUE) writes VALUE (jsonencode) to a
%   temporary file next to PATH and moves it to PATH, so that
%   PATH is either absent, the old file or the complete new one. An existing
%   PATH is refused unless 'AllowReplace' is true.
%   Side effects: writes PATH.

    parser = inputParser;
    addParameter(parser, 'AllowReplace', false, ...
        @(x) islogical(x) && isscalar(x));
    parse(parser, varargin{:});
    allowReplace = parser.Results.AllowReplace;

    pathValue = char(string(pathValue));
    folder = fileparts(pathValue);
    if isempty(folder), folder = pwd; end
    if ~isfolder(folder), mkdir(folder); end
    if ~allowReplace
        assert(~isfile(pathValue) && ~isfolder(pathValue), ...
            'utils:atomic_write_json:DestinationExists', ...
            'Refusing to replace existing JSON: %s', pathValue);
    end
    [~,~,extension] = fileparts(pathValue);
    assert(strcmpi(extension,'.json'), ...
        'utils:atomic_write_json:Extension', ...
        'JSON publication requires a .json destination: %s',pathValue);

    temporary = utils.atomic_temporary_path(pathValue);
    cleanup = onCleanup(@() delete_if_present(temporary));
    fid = fopen(temporary, 'wb');
    assert(fid >= 0, 'utils:atomic_write_json:OpenFailed', ...
        'Cannot create temporary JSON: %s', temporary);
    closer = onCleanup(@() close_if_open(fid));
    try
        encoded = jsonencode(value, 'PrettyPrint', true);
    catch
        encoded = jsonencode(value);
    end
    bytes = unicode2native([encoded newline], 'UTF-8');
    count = fwrite(fid,bytes,'uint8');
    assert(count==numel(bytes), ...
        'utils:atomic_write_json:ShortWrite', ...
        'Incomplete JSON write: %s',temporary);
    fclose(fid);
    clear closer
    if allowReplace
        utils.atomic_move_replace(temporary,pathValue);
    else
        utils.atomic_move_no_replace(temporary,pathValue);
    end
end

function close_if_open(fid)
    if ~isempty(fopen(fid)), fclose(fid); end
end

function delete_if_present(pathValue)
    if isfile(pathValue), delete(pathValue); end
end
