function strip_png_timestamps(pathValue)
%STRIP_PNG_TIMESTAMPS Remove the creation time from a PNG file, so that equal figures give equal files.
%   utils.strip_png_timestamps(PATH) rewrites the PNG file PATH without its
%   tIME chunk and without the tEXt chunk with the keyword "Creation Time",
%   both of which exportgraphics writes with the current time. The image
%   data and every other chunk (size, resolution, "Software") stay
%   byte-identical, so a figure with the same content gives the same file
%   whenever it is rendered, and a re-render changes only the figures whose
%   content changed. A file without these chunks is left as it is.
%   Side effects: rewrites PATH.

    fid = open_retrying(pathValue, 'r');
    assert(fid > 0, 'utils:strip_png_timestamps:Read', 'Cannot read %s.', pathValue);
    data = fread(fid, Inf, '*uint8');
    fclose(fid);
    signature = uint8([137 80 78 71 13 10 26 10]).';
    assert(numel(data) >= 8 && isequal(data(1:8), signature), ...
        'utils:strip_png_timestamps:NotPNG', '%s is not a PNG file.', pathValue);
    keep = true(size(data));
    % Chunk layout: length (4 bytes, big-endian), type (4), data (length), CRC (4).
    i = 9;
    while i + 11 <= numel(data)
        len = double(data(i)) * 2^24 + double(data(i+1)) * 2^16 + ...
            double(data(i+2)) * 2^8 + double(data(i+3));
        type = char(data(i+4:i+7).');
        last = i + 11 + len;
        assert(last <= numel(data), 'utils:strip_png_timestamps:Truncated', ...
            'The PNG file %s is truncated.', pathValue);
        drop = strcmp(type, 'tIME');
        if strcmp(type, 'tEXt')
            body = data(i+8:i+7+len).';
            separator = find(body == 0, 1);
            drop = ~isempty(separator) && strcmp(char(body(1:separator-1)), 'Creation Time');
        end
        if drop
            keep(i:last) = false;
        end
        i = last + 1;
    end
    if all(keep), return; end
    fid = open_retrying(pathValue, 'w');
    assert(fid > 0, 'utils:strip_png_timestamps:Write', 'Cannot write %s.', pathValue);
    fwrite(fid, data(keep), 'uint8');
    fclose(fid);
end

function fid = open_retrying(pathValue, mode)
%OPEN_RETRYING Open a file, retrying while another process holds it.
%   On Windows a sync client or file indexer can hold a just-written file
%   for a moment; the open is retried a few times, as
%   utils.atomic_move_replace retries its move.
    attempts = 5;
    for attempt = 1:attempts
        fid = fopen(pathValue, mode);
        if fid > 0 || attempt == attempts, return; end
        pause(0.25 * attempt);
    end
end
