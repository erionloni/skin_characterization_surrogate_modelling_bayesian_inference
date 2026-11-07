function [header, cells] = read_table(path)
%READ_TABLE The header and the cells (as text) of a recorded seed table.
%   [HEADER, CELLS] = seeds.read_table(PATH) reads the CSV file PATH (comma
%   separated, no quoted commas): HEADER is a 1-by-C cell array of column
%   names, CELLS an N-by-C cell array of the cells as text.
%   Side effects: none.

    assert(isfile(path), 'seeds:read_table:Missing', 'The seed table %s does not exist.', path);
    lines = regexp(fileread(path), '\r?\n', 'split');
    lines = lines(~cellfun(@isempty, lines));
    header = strsplit(lines{1}, ',');
    cells = cell(numel(lines) - 1, numel(header));
    for i = 2:numel(lines)
        row = strsplit(lines{i}, ',', 'CollapseDelimiters', false);
        assert(numel(row) == numel(header), 'seeds:read_table:Row', ...
            'Row %d of the seed table %s has %d cells, not %d.', i, path, numel(row), numel(header));
        cells(i - 1, :) = row;
    end
end
