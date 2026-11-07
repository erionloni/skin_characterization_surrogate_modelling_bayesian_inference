function text = write_results_readme(root, s)
%WRITE_RESULTS_README Write the README.md of a results folder: index, cases and provenance.
%   TEXT = study.write_results_readme(ROOT, S) writes ROOT/README.md after a
%   call of study.run with the resolved settings S and returns its text.
%   ROOT is the folder the call wrote its results into (study.output_root:
%   thesis_results/ for a render in place, else the run folder). It holds
%     - the index: per route, every analysis folder present in ROOT with
%       what it holds, its numbers of figures and tables and the command
%       that re-renders it (each analysis README indexes its own files),
%       and the step folders of the route's case folders with their
%       analyses;
%     - for a render of the shipped results (reproduce mode): the case
%       overview (study.case_overview), how certified and healthy-fallback
%       cells are presented, and the shipped
%       posterior draws;
%     - how the results were produced: the settings file, and the calls of
%       the run record of S.paths.run (entry point, mode and date; the
%       MATLAB version of a render, the MATLAB and UQLab versions and the
%       steps of a rerun), with a demonstration notice for reduced settings
%       (study.demonstration);
%     - the commands that regenerate the results.
%   Side effects: writes one file.

    shipped = strcmp(s.run.mode, 'reproduce');
    record = study.run_record('read', s.paths.run);
    if shipped
        L = {'# Thesis results', '', ...
            ['The results of the thesis, one folder per analysis in scientific order. They are ' ...
             'the output of `reproduce_thesis_results`: a new run of the code writes exactly this ' ...
             'layout into `runs/<run name>/`, so a rerun can be compared with these files one by ' ...
             'one. Each analysis folder holds `figures/`, `tables/` (CSV), `data/` (the numerical ' ...
             'results the figures and tables are computed from) and a `README.md` with the index ' ...
             'of its figures and tables: title, what each shows, its scope and the command that ' ...
             're-renders it.'], ''};
        if ~same_folder(root, s.paths.results)
            L = [L, {['This run folder holds the rendered figures, tables and READMEs; the `data/` ' ...
                'they were drawn from are those of `thesis_results/`.'], ''}];
        end
    else
        L = {sprintf('# Results of run `%s`', s.run.name), '', ...
            ['Results computed by this run of the code, in the layout of `thesis_results/`: one ' ...
             'folder per analysis with `figures/`, `tables/` (CSV), `data/` and a `README.md` with ' ...
             'the index of its figures and tables. The thesis results are in `thesis_results/` of ' ...
             'the repository.'], ''};
    end
    demonstration = study.demonstration(s.paths.run);
    if ~isempty(demonstration)
        L = [L, {['> **' demonstration '**'], ''}];
    end
    L = [L, index_lines(root)];
    if shipped
        L = [L, study.case_overview(s, root), status_lines(), draws_lines(s.paths.results)];
    end
    L = [L, produced_lines(record, shipped)];
    L = [L, {'## Regenerating', '', '```matlab', ...
        'reproduce_thesis_results                  % every figure and table, from data/ only, into runs/thesis_<time>/', ...
        'run_fixed_study(''Steps'',{''sensitivity''})  % one analysis', ...
        'run_fixed_study(''Steps'',{''inversion''},''CornerGallery'',''all'')  % corner plot of every inversion cell', ...
        '```', '', ...
        ['Reproducing needs neither UQLab nor any fitting, sampling or Fisher-information ' ...
         'computation. Recomputing (`''Mode'',''rerun''`) is described in `docs/GUIDE.md`.'], ''}];
    text = strjoin(L, newline);
    fid = fopen(fullfile(root, 'README.md'), 'w', 'n', 'UTF-8');
    closer = onCleanup(@() fclose(fid));
    fwrite(fid, text, 'char');
end

function L = index_lines(root)
%INDEX_LINES Route -> analyses: one table per route of the analysis folders present in ROOT.
    A = study.analyses();
    routes = {'fixed', 'Fixed route (four material parameters, the default protocol)'; ...
        'generalized', 'Generalized route (four material and three protocol inputs)'};
    L = {'## Index', ''};
    for r = 1:size(routes, 1)
        Ar = A(strcmp({A.route}, routes{r, 1}));
        present = arrayfun(@(a) isfolder(fullfile(root, a.route, a.folder)), Ar);
        if ~any(present), continue; end
        L = [L, {['### ' routes{r, 2}], '', ...
            '| Analysis | Holds | Figures | Tables | Re-render |', '|---|---|---|---|---|'}]; %#ok<AGROW>
        for a = Ar(present)
            folder = fullfile(root, a.route, a.folder);
            L{end+1} = sprintf('| [%s](%s/%s/README.md) | %s | %d | %d | `%s(''Steps'',{''%s''})` |', ...
                a.title, a.route, a.folder, strrep(a.summary, '|', '\|'), ...
                count_stems(fullfile(folder, 'figures'), {'.png', '.pdf', '.svg'}), ...
                count_stems(fullfile(folder, 'tables'), {'.csv'}), a.entry, a.steps{1}); %#ok<AGROW>
        end
        L{end+1} = ''; %#ok<AGROW>
        L = [L, case_folder_lines(root, routes{r, 1}, Ar)]; %#ok<AGROW>
    end
end

function L = case_folder_lines(root, route, A)
%CASE_FOLDER_LINES Route -> cases: the step folders of the route's case folders and their analyses.
%   One row per step folder of cases/case_<CaseID>/ (the per-case categories
%   of study.layout) that a case of ROOT holds: its analysis, the number of
%   cases and their figures and tables.
    L = {};
    cases = dir(fullfile(root, route, 'cases', 'case_*'));
    cases = cases([cases.isdir]);
    if isempty(cases), return; end
    C = study.layout().categories;
    C = C(strcmp({C.route}, route) & startsWith({C.category}, 'case/'));
    rows = {};
    for c = C
        step = extractAfter(c.category, 'case/');
        n = 0; figures = 0; tables = 0;
        for k = 1:numel(cases)
            folder = fullfile(root, route, 'cases', cases(k).name, step);
            if ~isfolder(folder), continue; end
            n = n + 1;
            figures = figures + count_stems(fullfile(folder, 'figures'), {'.png', '.pdf', '.svg'});
            tables = tables + count_stems(fullfile(folder, 'tables'), {'.csv'});
        end
        if n == 0, continue; end
        a = A(strcmp({A.folder}, c.analysis));
        rows{end+1} = sprintf('| `cases/case_<CaseID>/%s/` | [%s](%s/%s/README.md) | %d | %d | %d |', ...
            step, a.title, route, a.folder, n, figures, tables); %#ok<AGROW>
    end
    if isempty(rows), return; end
    L = [{sprintf(['Case folders, `%s/cases/case_<CaseID>/<step>/` with `figures/` and `tables/`: ' ...
        'the outputs of single cases. The README of each analysis lists its outputs with their ' ...
        'cases; the case overview below links every case to its folders.'], route), '', ...
        '| Step folder | Analysis | Cases | Figures | Tables |', '|---|---|---|---|---|'}, rows, {''}];
end

function n = count_stems(folder, extensions)
%COUNT_STEMS Figures or tables in FOLDER (one per file name, whatever its formats).
    n = 0;
    if ~isfolder(folder), return; end
    f = dir(folder);
    f = f(~[f.isdir]);
    [~, stems, ext] = cellfun(@fileparts, {f.name}, 'UniformOutput', false);
    n = numel(unique(stems(ismember(lower(ext), extensions))));
end

function L = status_lines()
%STATUS_LINES How the posterior-based analyses present certified and healthy-fallback cells.
    L = {'## Certified and healthy-fallback cells', '', ...
        ['The inversion-based analyses (fixed `04`-`07`, generalized `06`: the confirmation) show ' ...
         'every cell with a selected provider: the certified cells (two independent AIES ' ...
         'ensembles that agree) and the healthy fallbacks (a healthy provider that was not ' ...
         'certified). The index of each analysis names, for every output, the cells it shows ' ...
         'and which of them are healthy fallbacks or unavailable; a figure of one case gives ' ...
         'its status in the title; ' ...
         'the status of every cell is in `fixed/04_inversion/tables/cell_status.csv` and ' ...
         '`fixed/07_conditional_inversion/tables/cell_status.csv`. Aggregates over cases count ' ...
         'certified and fallback cells and state their number; summary tables give next to ' ...
         'each value its value over the certified cells alone (columns ending in ' ...
         '`_certified_only`). Unavailable cells have no posterior: they stay blank (grey in ' ...
         'heatmaps) and are never shown as zero.'], ''};
end

function L = draws_lines(results)
%DRAWS_LINES The shipped posterior draws, counted from their indexes.
    canonical = fullfile(results, 'fixed', '04_inversion', 'data', 'draws', 'index.csv');
    conditional = fullfile(results, 'fixed', '07_conditional_inversion', 'data', ...
        'draws', 'index.csv');
    L = {};
    if ~isfile(canonical) || ~isfile(conditional), return; end
    C = utils.read_csv_table(canonical, {'ReplicateIDs'});
    K = utils.read_csv_table(conditional, {'ReplicateIDs'});
    single = sum(~contains([C.ReplicateIDs; K.ReplicateIDs], ';'));
    L = {'## Posterior draws', '', ...
        sprintf(['`fixed/04_inversion/data/draws/` (%d canonical cells) and ' ...
         '`fixed/07_conditional_inversion/data/draws/` (%d conditional cells) hold, ' ...
         'for every cell with a selected provider (certified, or a healthy fallback), every ' ...
         'retained draw of both replicates of the ' ...
         'provider''s level at full precision: one file per cell, in the format a run of the ' ...
         'code writes, with `index.csv`. Each file names the provider replicate and keeps, for ' ...
         'each replicate, its saved health record and request, and for a certified cell its ' ...
         'certification record. The files of %d healthy fallbacks hold the provider only, because ' ...
         'their second replicate did not finish (the reason is in the file). The draws are those of ' ...
         'the thesis runs, unchanged; nothing is thinned or subsampled. Replicates are never ' ...
         'pooled: the analyses read the provider, and the replicate-agreement analyses read ' ...
         'both. In a rerun (`''Mode'',''rerun''`), `recovery` and `design_study` compute from ' ...
         'these draws when the run has no inversion of its own.'], height(C), height(K), single), '', ...
        sprintf(['The case folders `fixed/cases/case_<CaseID>/inversion/figures/` hold the corner ' ...
         'plots of the thesis (gp_only, all six outputs, the canonical cases; settings A.10). ' ...
         '`''CornerGallery'',''all''` draws the corner plot of every available cell (%d plots) from ' ...
         'all retained draws of its provider.'], height(C)), ''};
end

function L = produced_lines(record, shipped)
%PRODUCED_LINES How the results were produced: the settings and the calls of the run record.
    L = {'## How these results were produced', ''};
    if shipped
        L{end+1} = ['- **Thesis and code:** *Surrogate Modelling and Bayesian Inference for Skin ' ...
            'Characterization from Suction Experiments*, MSc thesis, ETH Zurich, 2026; the code and ' ...
            'these results: ' ...
            '<https://github.com/erionloni/skin_characterization_surrogate_modelling_bayesian_inference>.'];
        L{end+1} = ['- **Settings:** `study_settings.m`, the one settings file of both routes; its ' ...
            'values are the thesis values.'];
        L{end+1} = ['- **`data/`:** the results of the thesis runs. The fixed-route surrogates and ' ...
            'inversions ran on a computing cluster with MATLAB R2024a, the approved generalized ' ...
            'surrogates and the best fit of the GP-mean inversion on a workstation with MATLAB ' ...
            'R2025b, all with UQLab 2.3.0.'];
    else
        L{end+1} = ['- **Settings:** those of each call below (`study_settings.m`, or the struct a ' ...
            'call passed as `''Settings''`), with the call''s name-value options; `run_record.json` ' ...
            'holds them completely.'];
    end
    calls = {};
    if ~isempty(record), calls = record.calls; end
    rendered = {};   % reproduce calls with the same date and versions share a line
    partial = {};    % reproduce calls of named steps only: one line each, after the others
    for k = 1:numel(calls)
        c = calls{k};
        date = char(extractBefore(string(c.started_utc), 'T'));
        if strcmp(c.mode, 'reproduce') && isstruct(c.arguments) && isfield(c.arguments, 'Steps') && ...
                ~isempty(c.arguments.Steps)
            partial{end+1} = sprintf(['- **Rendered by `%s` with the steps %s only** on %s with %s: the ' ...
                'analyses of these steps and this index; rendering needs no UQLab.'], c.entry_point, ...
                strjoin(cellstr(string(c.arguments.Steps)), ', '), date, ...
                strtrim(strtok(c.environment, ';'))); %#ok<AGROW>
        elseif strcmp(c.mode, 'reproduce')
            % Rendering uses MATLAB only: the MATLAB part of the environment line.
            key = sprintf('on %s with %s; rendering needs no UQLab', date, ...
                strtrim(strtok(c.environment, ';')));
            same = find(strcmp(cellfun(@(r) r{2}, rendered, 'UniformOutput', false), key), 1);
            if isempty(same)
                rendered{end+1} = {{c.entry_point}, key}; %#ok<AGROW>
            elseif ~ismember(c.entry_point, rendered{same}{1})
                rendered{same}{1}{end+1} = c.entry_point; %#ok<AGROW>
            end
        else
            ran = strjoin(cellstr(string(c.steps_run)), ', ');
            if isempty(ran), ran = 'none'; end
            source = '`study_settings.m`';
            if isstruct(c.arguments) && isfield(c.arguments, 'Settings')
                source = 'a `''Settings''` struct';
            end
            L{end+1} = sprintf('- **`%s`** (%s, scale %s) on %s with the settings of %s: steps %s; %s (%s).', ...
                c.entry_point, c.mode, c.scale, date, source, ran, c.status, c.environment); %#ok<AGROW>
        end
    end
    for k = 1:numel(rendered)
        L{end+1} = sprintf(['- **`figures/`, `tables/` and the READMEs:** rendered from ' ...
            '`data/` in reproduce mode by %s %s.'], ...
            strjoin(strcat('`', rendered{k}{1}, '`'), ', '), rendered{k}{2}); %#ok<AGROW>
    end
    L = [L, partial];
    if ~shipped
        L{end+1} = ['- `run_record.json` also holds the code version of every call and every ' ...
            'completed step with its inputs and outputs.'];
    end
    L{end+1} = '';
end

function tf = same_folder(a, b)
    tf = strcmpi(utils.absolute_path(a), utils.absolute_path(b));
end
