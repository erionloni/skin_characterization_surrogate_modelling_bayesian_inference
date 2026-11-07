function check_new(cfg, seed, request)
%CHECK_NEW Refuse a seed of a seed rule that equals a recorded seed.
%   seeds.check_new(CFG, SEED, REQUEST) stops with a message naming REQUEST
%   (text) when SEED, given by a seed rule of the settings, is also a seed
%   of one of the recorded seed tables (cfg.seeds.tables): two random
%   streams would then start from the same state.
%   Side effects: reads the recorded tables once per MATLAB session.

    persistent cache
    if isempty(cache), cache = containers.Map(); end
    names = fieldnames(cfg.seeds.tables);
    files = cellfun(@(name) char(string(cfg.seeds.tables.(name))), names, 'UniformOutput', false);
    files = files(~cellfun(@isempty, files));
    id = strjoin([{cfg.seeds.folder}; files], '|');
    if ~isKey(cache, id)
        values = zeros(0, 1);
        for k = 1:numel(files)
            [header, cells] = seeds.read_table(fullfile(cfg.seeds.folder, files{k}));
            values = [values; str2double(cells(:, strcmp(header, 'Seed')))]; %#ok<AGROW>
        end
        cache(id) = unique(values);
    end
    assert(~ismember(double(seed), cache(id)), 'seeds:check_new:Collision', ...
        ['The seed rule gives %d for %s, but %d is already a recorded seed ' ...
         '(config/seeds). Change the base seed of this rule in the settings.'], ...
        double(seed), request, double(seed));
end
