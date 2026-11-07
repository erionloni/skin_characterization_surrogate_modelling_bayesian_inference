function files = confirmation_compact_tier(root)
%CONFIRMATION_COMPACT_TIER The files of a finished confirmation campaign that thesis_results/ holds.
%   FILES = study.confirmation_compact_tier(ROOT) lists the compact tier of
%   the confirmation campaign folder ROOT, as '/'-separated paths relative
%   to ROOT, sorted: status/, certification/, summaries/, cell_grid/ (with
%   the seed schedule), pairing/, inputs/, the JSON records of
%   configuration/ and the reports (reports/*.md). The request trees
%   (aies/), MAT caches, figures (re-rendered from the summaries) and
%   console logs stay with the campaign; the draws of its providers are
%   written separately (study.write_confirmation_draws).
%   Used by study.steps.confirmation_compare.
%   Side effects: none.

    files = {};
    if ~isfolder(root), return; end
    entries = dir(fullfile(root, '**', '*'));
    entries = entries(~[entries.isdir]);
    for k = 1:numel(entries)
        full = fullfile(entries(k).folder, entries(k).name);
        relative = strrep(full(numel(root)+2:end), '\', '/');
        if ~isempty(regexp(relative, ['^(status|certification|summaries|cell_grid|pairing|inputs)/' ...
                '|^configuration/[^/]+\.json$|^reports/[^/]+\.md$'], 'once'))
            files{end+1} = relative; %#ok<AGROW>
        end
    end
    files = sort(files);
end
