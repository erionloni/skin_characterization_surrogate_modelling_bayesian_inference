function validate_settings(s, origin)
%VALIDATE_SETTINGS Refuse a settings struct that lacks a setting, holds an unknown one or an invalid value.
%   study.validate_settings(S) checks S (study_settings.m, or the struct of
%   the option 'Settings') against study.settings_schema:
%     - a setting of the schema that S lacks stops with
%       "setting <name> missing in section <section> of the settings file";
%     - a field of S that is no setting stops with the closest valid name
%       (a typo);
%     - a value that its check refuses stops with what the setting accepts.
%   study.validate_settings(S, ORIGIN) names ORIGIN in the messages (e.g.
%   'the option ''Settings''') instead of the settings file.
%   Nothing has a default: every setting comes from the settings file.
%   Side effects: none.

    if nargin < 2, origin = 'the settings file'; end
    schema = study.settings_schema();
    names = {schema.name};
    present = leaves(s, '');
    unknown = setdiff(present, names, 'stable');
    if ~isempty(unknown)
        error('study:settings:Unknown', ...
            'Unknown setting %s in %s; did you mean %s? (study_settings.m lists every setting.)', ...
            unknown{1}, origin, closest(unknown{1}, names));
    end
    missing = setdiff(names, present, 'stable');
    if ~isempty(missing)
        k = find(strcmp(names, missing{1}), 1);
        error('study:settings:Missing', 'setting %s missing in section %s of %s', ...
            missing{1}, schema(k).section, origin);
    end
    for k = 1:numel(schema)
        message = schema(k).check(value_at(s, schema(k).name));
        if ~isempty(message)
            error('study:settings:Invalid', ...
                'setting %s (section %s of %s) must be %s.', schema(k).name, ...
                schema(k).section, origin, message);
        end
    end
end

function names = leaves(v, prefix)
%LEAVES The field paths of the values below V (a field holding a struct is followed).
    names = {};
    if ~(isstruct(v) && isscalar(v))
        names = {prefix};
        return;
    end
    for f = reshape(fieldnames(v), 1, [])
        path = f{1};
        if ~isempty(prefix), path = [prefix '.' f{1}]; end
        names = [names, leaves(v.(f{1}), path)]; %#ok<AGROW>
    end
end

function v = value_at(s, name)
    v = s;
    for part = strsplit(name, '.')
        v = v.(part{1});
    end
end

function best = closest(name, names)
%CLOSEST The valid name nearest to NAME (fewest single-character edits).
    distances = cellfun(@(n) edit_distance(lower(name), lower(n)), names);
    [~, k] = min(distances);
    best = names{k};
end

function d = edit_distance(a, b)
%EDIT_DISTANCE Levenshtein distance of two texts.
    m = numel(a); n = numel(b);
    previous = 0:n;
    for i = 1:m
        current = [i, zeros(1, n)];
        for j = 1:n
            current(j + 1) = min([previous(j + 1) + 1, current(j) + 1, ...
                previous(j) + (a(i) ~= b(j))]);
        end
        previous = current;
    end
    d = previous(end);
end
