function seed = recorded(cfg, name, key)
%RECORDED The recorded seed of a request (NaN when its table has none).
%   SEED = seeds.recorded(CFG, NAME, KEY) looks the request KEY up in the
%   recorded seed table NAME of the settings (the CSV file
%   cfg.seeds.tables.(NAME) in cfg.seeds.folder). KEY is a struct whose
%   fields are key columns of the table, with the request's values (text or
%   a whole number; '' for an empty cell). The row whose key columns hold
%   these values gives the seed. An empty file name in the settings records
%   no seed.
%   Side effects: reads each table once per MATLAB session.

    seed = NaN;
    file = char(string(cfg.seeds.tables.(name)));
    if isempty(file), return; end
    columns = fieldnames(key).';
    map = lookup_map(fullfile(cfg.seeds.folder, file), columns);
    text = key_text(cellfun(@(column) key.(column), columns, 'UniformOutput', false));
    if isKey(map, text), seed = map(text); end
end

function map = lookup_map(path, columns)
%LOOKUP_MAP The seeds of a table by the text of their key columns (cached).
    persistent cache
    if isempty(cache), cache = containers.Map(); end
    id = [path '|' strjoin(columns, ',')];
    if isKey(cache, id), map = cache(id); return; end
    [header, cells] = seeds.read_table(path);
    [found, index] = ismember([columns {'Seed'}], header);
    assert(all(found), 'seeds:recorded:Columns', ...
        'The seed table %s has no column %s.', path, ...
        strjoin(setdiff([columns {'Seed'}], header), ', '));
    map = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for i = 1:size(cells, 1)
        text = strjoin(cells(i, index(1:end-1)), '|');
        assert(~isKey(map, text), 'seeds:recorded:Duplicate', ...
            'The seed table %s records the request %s twice.', path, text);
        map(text) = str2double(cells{i, index(end)});
    end
    cache(id) = map;
end

function text = key_text(values)
%KEY_TEXT The key of a request as the table writes it: whole numbers in digits, text as it is.
    for k = 1:numel(values)
        value = values{k};
        if isnumeric(value) || islogical(value)
            if isempty(value) || isnan(value)
                values{k} = '';
            else
                values{k} = sprintf('%d', value);
            end
        else
            values{k} = char(string(value));
        end
    end
    text = strjoin(values, '|');
end
