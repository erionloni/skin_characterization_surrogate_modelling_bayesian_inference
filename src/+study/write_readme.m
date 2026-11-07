function text = write_readme(root, analysis, s, index, skipped)
%WRITE_README Write README.md of one analysis folder, with the index of its figures and tables.
%   TEXT = study.write_readme(ROOT, ANALYSIS, S, INDEX, SKIPPED) writes
%   ROOT/<route>/<folder>/README.md for ANALYSIS (one element of
%   study.analyses) and returns its text. ROOT is the folder the figures and
%   tables were written to (study.output_root: a run folder, or
%   thesis_results/ for a render in place); S the resolved settings of the
%   call; INDEX the figures and tables it rendered (a containers.Map of
%   study.index_entry); SKIPPED the renderer failures of type
%   study:source_folder:NotInRun.
%
%   The README says what the folder holds and gives the index of its
%   figures and tables (file, title, what it shows, scope, the command that
%   re-renders it), the outputs of single cases that the analysis wrote to
%   the case folders (one row per output with its cases), what data/ holds,
%   the full-size intermediates that thesis_results/ does not ship with the
%   command that regenerates them, and the commands. A reproduce run renders into its own folder without
%   copying data/: its README points to the shipped data the figures and
%   tables were drawn from.
%   For a rerun that renders its own results (study.render_run,
%   S.run.renderFromRun) the README opens with what the run computed (the
%   steps the run record lists as completed, the state of an inversion
%   campaign (certified providers only), and a demonstration notice when the
%   MCMC chains were shortened), its commands re-render from the run, and
%   SKIPPED lists the renderers that were not rendered because they need
%   results the run does not hold.
%   Side effects: writes one file.

    fromRun = isfield(s.run, 'renderFromRun') && s.run.renderFromRun;
    folder = fullfile(root, analysis.route, analysis.folder);
    if ~isfolder(folder), mkdir(folder); end
    dataFolder = fullfile(folder, 'data');
    dataNote = '';
    shipped = fullfile(s.paths.results, analysis.route, analysis.folder, 'data');
    if ~isfolder(dataFolder) && isfolder(shipped)
        % A reproduce run renders into its own folder and reads the shipped
        % data where it is, without copying it. (Analyses without a data/
        % folder, such as the confirmation design, say in their summary
        % where their inputs are.)
        dataFolder = shipped;
        layout = struct('results', s.paths.results, 'run', s.paths.run);
        dataNote = sprintf(['This run folder holds the rendered figures and tables only; ' ...
            'they were drawn from the shipped data in `%s/`.'], ...
            study.portable_path(shipped, layout));
    end
    steps = strjoin(cellfun(@(x) ['''' x ''''], analysis.steps, 'UniformOutput', false), ',');
    if fromRun
        % The registry summary describes the thesis results in thesis_results/.
        L = [{sprintf('# %s', analysis.title), ''}, run_summary(root, analysis, s)];
    else
        L = {sprintf('# %s', analysis.title), '', analysis.summary, ''};
    end
    for k = 1:numel(analysis.notes)
        L = [L, analysis.notes(k), {''}]; %#ok<AGROW>
    end
    if analysis.posterior
        L = [L, posterior_lines(analysis, s)];
    end
    entries = values(index);
    entries = [entries{:}];
    if isempty(entries)
        entries = struct('kind', {}, 'files', {}, 'title', {}, 'scope', {}, 'caption', {}, ...
            'command', {}, 'note', {});
    end
    % The outputs of single cases lie in the case folders (study.figure_target).
    perCase = false(1, numel(entries));
    for k = 1:numel(entries)
        perCase(k) = startsWith(entries(k).files{1}, '../cases/');
    end
    caseEntries = entries(perCase);
    entries = entries(~perCase);
    figures = sum(strcmp({entries.kind}, 'figure'));
    tables = sum(strcmp({entries.kind}, 'table'));
    % The shipped data/ holds what the figures, tables and later steps read;
    % a run's data/ holds everything its steps wrote.
    holds = ['the saved results the figures, tables and later steps read (a rerun of the ' ...
        'steps also writes further records)'];
    if fromRun, holds = 'the numerical results the steps of this run wrote'; end
    L = [L, {'## Contents', '', '| Folder | Holds |', '|---|---|', ...
        sprintf('| `figures/` | %s |', counted(figures, 'figure', 'figures')), ...
        sprintf('| `tables/` | %s |', counted(tables, 'table (CSV)', 'tables (CSV)')), ...
        ['| `data/` | ' describe(dataFolder, holds) ' |']}];
    if ~isempty(caseEntries)
        held = {};
        n = sum(strcmp({caseEntries.kind}, 'figure'));
        if n > 0, held{end+1} = counted(n, 'figure', 'figures'); end
        n = sum(strcmp({caseEntries.kind}, 'table'));
        if n > 0, held{end+1} = counted(n, 'table (CSV)', 'tables (CSV)'); end
        L{end+1} = sprintf(['| `../cases/` | %s of single cases, in the case folders ' ...
            '(section Per-case outputs) |'], strjoin(held, ' and '));
    end
    L{end+1} = '';
    if ~isempty(dataNote)
        L = [L, {dataNote, ''}];
    end
    L = [L, index_table(entries, analysis), case_table(caseEntries, analysis)];
    dataLines = data_listing(dataFolder, [analysis.route '/' analysis.folder]);
    if ~isempty(dataLines)
        L = [L, {'Inside `data/`:', ''}, dataLines, {''}];
    end
    L = [L, omitted(analysis)];
    if fromRun
        L = [L, not_rendered(skipped)];
        L = [L, {'## Commands', '', '```matlab', ...
            sprintf('%s(''Mode'',''rerun'',''RunName'',''%s'',''Steps'',{''figures''})  %% re-render figures/ and tables/ from this run''s data/', ...
                analysis.entry, s.run.name), ...
            sprintf('%s(''Mode'',''rerun'',''Steps'',{%s},''Plan'',true)  %% show what a recomputation costs', ...
                analysis.entry, steps), ...
            '```', '', ...
            ['The `data/` of this analysis was computed by this rerun: `run_record.json` in ' ...
             'the run folder lists each step with its inputs and outputs.'], ''}];
    else
        L = [L, {'## Commands', '', '```matlab', ...
            sprintf('%s(''Steps'',{%s})                  %% re-render figures/ and tables/ from data/', ...
                analysis.entry, steps), ...
            sprintf('%s(''Mode'',''rerun'',''Steps'',{%s},''Plan'',true)  %% show what a recomputation costs', ...
                analysis.entry, steps), ...
            '```', ''}];
    end
    text = strjoin(L, newline);
    fid = fopen(fullfile(folder, 'README.md'), 'w', 'n', 'UTF-8');
    closer = onCleanup(@() fclose(fid));
    fwrite(fid, text, 'char');
end

function L = index_table(entries, analysis)
%INDEX_TABLE One row per figure and table: file, title, what it shows, scope, command.
%   Figures first, then tables, each in file-name order (the order of the
%   index keys).
    if isempty(entries)
        L = {'## Figures and tables', '', 'No figures or tables were rendered for this folder.', ''};
        return;
    end
    L = {'## Figures and tables', '', '| File | Title | Shows | Scope | Command |', ...
        '|---|---|---|---|---|'};
    for e = entries
        links = strjoin(cellfun(@(f) sprintf('[%s](%s)', file_name(f), f), e.files, ...
            'UniformOutput', false), ' ');
        [~, stem] = fileparts(e.files{1});
        shows = study.output_description(analysis.route, analysis.folder, stem);
        if ~isempty(e.note)
            shows = strtrim(sprintf('%s (%s)', shows, e.note));
        end
        if ~isempty(e.caption)
            if ~isempty(shows) && ~endsWith(shows, '.'), shows = sprintf('%s.', shows); end
            shows = strtrim(sprintf('%s %s', shows, e.caption));
        end
        L{end+1} = sprintf('| %s | %s | %s | %s | `%s` |', links, cell_text(e.title), ...
            cell_text(shows), cell_text(e.scope), e.command); %#ok<AGROW>
    end
    L{end+1} = '';
end

function L = case_table(entries, analysis)
%CASE_TABLE The outputs of single cases: one row per output, its cases linked to their files.
%   The files lie in ../cases/case_<CaseID>/<step>/{figures,tables}/
%   (study.figure_target). Figures first, then tables, each by name; the
%   cases in increasing CaseID. An output of one cell that is not certified
%   names the cell's status (the scope of study.index_entry).
    L = {};
    if isempty(entries), return; end
    % The settings that choose the cases: the case outputs (A.10); the
    % ratio-error curves draw every cell they computed (A.11), the parameter
    % combinations likewise (A.12), the confirmation every pair of its
    % design (B.7).
    section = 'section A.10 of `study_settings.m`';
    if strcmp(analysis.folder, '08_ratio_error_curves'), section = 'section A.11 of `study_settings.m`'; end
    if strcmp(analysis.folder, '09_gp_mean_inversion'), section = 'section A.13 of `study_settings.m`'; end
    if any(arrayfun(@(e) contains(string(e.files{1}), '/combinations/'), entries))
        section = 'section A.10 of `study_settings.m`; for the parameter combinations, section A.12';
    end
    if strcmp(analysis.route, 'generalized'), section = 'section B.7 of `study_settings.m`'; end
    L = {'## Per-case outputs', '', ...
        ['The outputs of single cases lie in the case folders of the route, ' ...
         '`../cases/case_<CaseID>/<step>/figures/` and `tables/`, for the cases of the settings ' ...
         '(' section '). One row per output: what it shows and its cases, ' ...
         'each linked to its file; the title of each figure names its case and the status of its ' ...
         'cells.'], '', '| Output | Shows | Cases | Command |', '|---|---|---|---|'};
    n = numel(entries);
    keys = strings(n, 1);
    ids = zeros(n, 1);
    for k = 1:n
        parts = regexp(entries(k).files{1}, '^\.\./cases/case_(\d+)/(.+)$', 'tokens', 'once');
        ids(k) = str2double(parts{1});
        keys(k) = parts{2};   % <step>/<figures or tables>/<file>
    end
    order = sortrows(table(strcmp({entries.kind}, 'table').', keys, ids, (1:n).', ...
        'VariableNames', {'IsTable', 'Key', 'CaseID', 'Entry'}));
    [outputs, ~, group] = unique(order.Key, 'stable');
    for i = 1:numel(outputs)
        rows = order(group == i, :);
        links = strings(height(rows), 1);
        for j = 1:height(rows)
            e = entries(rows.Entry(j));
            links(j) = sprintf('[%d](%s)%s', rows.CaseID(j), e.files{1}, status_note(e));
        end
        [~, stem, extension] = fileparts(outputs(i));
        step = extractBefore(outputs(i), '/');
        shows = study.output_description(analysis.route, ['case/' char(step)], stem);
        L{end+1} = sprintf('| `%s` | %s | %s | `%s` |', stem + extension, cell_text(shows), ...
            strjoin(links, ', '), entries(rows.Entry(1)).command); %#ok<AGROW>
    end
    L{end+1} = '';
end

function note = status_note(e)
%STATUS_NOTE ' (<status>)' for an output of one cell that is not certified, and the entry's note.
    note = '';
    status = regexp(e.scope, '^case \d+, [^:]+: (.+)$', 'tokens', 'once');
    if ~isempty(status) && ~strcmp(status{1}, 'certified')
        note = sprintf(' (%s)', status{1});
    end
    if ~isempty(e.note)
        note = sprintf('%s (%s)', note, e.note);
    end
end

function L = posterior_lines(analysis, s)
%POSTERIOR_LINES How a posterior-based analysis presents certified and healthy-fallback cells.
    status = '../04_inversion/tables/cell_status.csv';
    switch analysis.folder
        case '04_inversion', status = 'tables/cell_status.csv';
        case '07_conditional_inversion', status = 'tables/cell_status.csv';
        case '09_gp_mean_inversion', status = 'tables/cell_status.csv';
    end
    L = {['Posterior-based results show every cell with a selected provider together: the ' ...
        'certified cells (two independent AIES ensembles that agree) and the healthy fallbacks ' ...
        '(a healthy provider that was not certified). Unavailable cells have no posterior and ' ...
        'stay blank. The index names, for each output, the cells it shows and which of them ' ...
        'are healthy fallbacks or unavailable; a figure of one case gives its status in the ' ...
        'title. Summary tables give next to each value its value over the certified cells ' ...
        'alone (columns ending in `_certified_only`).'], ''};
    if strcmp(analysis.folder, '06_confirmation')
        % The confirmation's status table exists once its campaign is compared
        % (the step compare writes data/cell_status.csv of the results read).
        status = '';
        if isfile(fullfile(s.paths.results, analysis.route, analysis.folder, 'data', ...
                'cell_status.csv'))
            status = 'tables/cell_status.csv';
        end
    end
    if ~isempty(status)
        L = [L, {sprintf('The status of every cell: [`cell_status.csv`](%s).', status), ''}];
    end
end

function name = file_name(relative)
    [~, stem, extension] = fileparts(relative);
    name = [stem extension];
end

function t = cell_text(t)
    t = strrep(char(string(t)), '|', '\|');
end

function t = counted(n, one, many)
    if n == 1
        t = sprintf('1 %s', one);
    else
        t = sprintf('%d %s', n, many);
    end
end

function L = omitted(analysis)
%OMITTED The full-size intermediates of the analysis that thesis_results/ does not ship.
    I = study.omitted_intermediates(analysis.route, analysis.folder);
    L = {};
    if isempty(I), return; end
    L = {'## Full-size intermediates not shipped', '', ...
        ['A run of this analysis also writes the intermediate outputs below into its ' ...
         '`data/` folder. thesis_results/ does not ship them because of their size; the command ' ...
         'regenerates them at full size in the run folder (runtime on one workstation).'], '', ...
        '| File in `data/` | Holds | Regenerate with | Runtime |', '|---|---|---|---|'};
    for i = 1:numel(I)
        count = '';
        if I(i).count > 1, count = sprintf(' (%d files)', I(i).count); end
        if isempty(I(i).steps)
            command = 'not rerun by this version: thesis evidence';
            runtime = '';
        else
            registry = study.steps(I(i).entry);
            steps = registry(ismember({registry.name}, I(i).steps));
            confirm = '';
            if any([steps.expensive]), confirm = ',''ConfirmExpensive'',true'; end
            command = sprintf('`%s(''Mode'',''rerun'',''Steps'',{%s}%s)`', ...
                study.entry_function(I(i).entry), ...
                strjoin(strcat('''', I(i).steps, ''''), ','), confirm);
            runtime = strjoin({steps.cost}, ' + ');
        end
        L{end+1} = sprintf('| `%s`%s | %s | %s | %s |', I(i).path, count, I(i).what, ...
            command, runtime); %#ok<AGROW>
    end
    L{end+1} = '';
end

function L = not_rendered(skipped)
%NOT_RENDERED The renderers a rerun did not run, and the results they need.
    L = {};
    if isempty(skipped), return; end
    L = {'## Not rendered in this run', '', ...
        ['These renderers need results of steps that this run did not compute; their ' ...
         'figures and tables are in the shipped `thesis_results/`:'], ''};
    for i = 1:numel(skipped)
        L{end+1} = sprintf('- `%s`: %s', skipped(i).renderer, skipped(i).message); %#ok<AGROW>
    end
    L{end+1} = '';
end

function d = describe(folder, what)
    n = count_files(folder);
    if n == 0
        d = [what ' (none)'];
    else
        d = sprintf('%s: %s', what, files_text(n));
    end
end

function t = files_text(n)
%FILES_TEXT "1 file" or "<n> files".
    if n == 1, t = '1 file'; else, t = sprintf('%d files', n); end
end

function n = count_files(folder)
    n = 0;
    if ~isfolder(folder), return; end
    f = dir(fullfile(folder, '**', '*'));
    n = sum(~[f.isdir]);
end

function L = data_listing(folder, analysis)
%DATA_LISTING One line per first-level entry of data/, with file counts and,
%   where registered (study.data_description), what the entry holds. A
%   folder without files is not listed (git keeps no empty folders).
    L = {};
    if ~isfolder(folder), return; end
    entries = dir(folder);
    entries = entries(~ismember({entries.name}, {'.', '..'}));
    files = entries(~[entries.isdir]);
    dirs = entries([entries.isdir]);
    dirs = dirs(arrayfun(@(d) count_files(fullfile(folder, d.name)) > 0, dirs));
    for i = 1:numel(dirs)
        meaning = study.data_description(analysis, dirs(i).name);
        separator = '';
        if ~isempty(meaning), separator = ': '; end
        L{end+1} = sprintf('- `%s/` (%s)%s%s', dirs(i).name, ...
            files_text(count_files(fullfile(folder, dirs(i).name))), separator, meaning); %#ok<AGROW>
    end
    if ~isempty(files)
        names = sort({files.name});
        shown = names(1:min(numel(names), 12));
        more = '';
        if numel(names) > 12, more = sprintf(' and %d more', numel(names) - 12); end
        L{end+1} = ['- files: `' strjoin(shown, '`, `') '`' more];
    end
end

function L = run_summary(root, analysis, s)
%RUN_SUMMARY Opening of the README of an analysis that a rerun computed.
%   What this run computed (the steps the run record lists as completed),
%   the state of an inversion campaign, and the demonstration notice when
%   the MCMC chains of the run were shortened (study.demonstration).
    ran = {};
    notes = {};
    for k = 1:numel(analysis.steps)
        R = study.run_record('step', root, s.run.entry, analysis.steps{k});
        if isempty(R), continue; end
        ran{end+1} = ['`' analysis.steps{k} '`']; %#ok<AGROW>
        if isfield(R, 'details') && isfield(R.details, 'campaign_cells')
            d = R.details;
            state = 'the campaign is complete and finalized';
            if ~logical(d.campaign_complete)
                state = 'a partial campaign: the other cells were not run and count as missing';
            end
            if isfield(d, 'cells_to_run')
                % The conditional inversion: cells to run, reused and skipped.
                notes{end+1} = sprintf(['Conditional campaign: %d cells; %d of the %d cells to run ' ...
                    'were run, %d taken from the shipped results, %d not run (canonical baseline ' ...
                    'status); %s.'], d.campaign_cells, d.cells_done, d.cells_to_run, ...
                    d.cells_reused, d.cells_skipped, state); %#ok<AGROW>
            elseif isfield(d, 'campaign') && strcmp(d.campaign, 'confirmation')
                % The confirmation's step run_cells enters the run record once
                % every cell has run; its step compare finalizes.
                unavailable = 0;
                if isfield(d, 'cells_unavailable'), unavailable = d.cells_unavailable; end
                pairsText = '';
                if isfield(d, 'cells_complete_pairs') && d.cells_complete_pairs > 0
                    pairsText = sprintf(' (%d of them on the complete pairs, descriptive)', ...
                        d.cells_complete_pairs);
                end
                notes{end+1} = sprintf(['Confirmation campaign: %d cells%s; %d run, %d without an ' ...
                    'accepted COMSOL observation (unavailable).'], d.campaign_cells, pairsText, ...
                    d.cells_done, unavailable); %#ok<AGROW>
            else
                notes{end+1} = sprintf('Inversion campaign: %d of %d grid cells run; %s.', ...
                    d.cells_done, d.campaign_cells, state); %#ok<AGROW>
            end
            if isfield(d, 'cell_environments') && ~isempty(d.cell_environments)
                % The software of the cells (they may have run elsewhere).
                notes{end} = sprintf('%s The cells ran with %s.', notes{end}, ...
                    strjoin(cellstr(string(d.cell_environments)), ' and with '));
            end
        end
    end
    L = {sprintf(['Computed by this rerun (%s; recorded in `run_record.json`). ' ...
        'The thesis results of this analysis and their description are in `thesis_results/%s/%s/`.'], ...
        strjoin(ran, ', '), analysis.route, analysis.folder), ''};
    demonstration = study.demonstration(root);
    if ~isempty(demonstration)
        L = [L, {['**' demonstration '**'], ''}];
    end
    for k = 1:numel(notes)
        L = [L, {notes{k}, ''}]; %#ok<AGROW>
    end
    if analysis.posterior && strcmp(analysis.route, 'fixed') && ...
            ~strcmp(analysis.folder, '09_gp_mean_inversion')
        % (The confirmation and the GP-mean campaign select their fallbacks
        % themselves.)
        L = [L, {['A run''s own inversion campaign selects certified providers only. A run ' ...
            'without an inversion of its own reads the draws shipped in `thesis_results/`, ' ...
            'healthy fallbacks included; those come from the recovery of the incomplete ' ...
            'thesis campaign.'], ''}];
    end
end
