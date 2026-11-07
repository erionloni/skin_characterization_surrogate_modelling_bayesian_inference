function pathValue = export_table(cfg, category, name, T, sources, title, cells)
%EXPORT_TABLE Write one table into the publication layout.
%   PATHVALUE = study.export_table(CFG, CATEGORY, NAME, T, SOURCES, TITLE,
%   CELLS) writes the table T as
%     <output>/<route>/<NN_analysis>/tables/<file>.csv
%   The analysis folder and the flat file name follow from CATEGORY and NAME
%   exactly as for figures (study.figure_target); the table of a per-case
%   category goes to <output>/<route>/cases/case_<CaseID>/<step>/tables/. SOURCES are the saved files
%   the table was computed from (each must exist); TITLE is a one-line
%   description; CELLS the inversion cells it covers ([] when it is not
%   posterior-based, 'all' for every cell of its analysis, or a struct of
%   CaseID, Scenario, Design and Condition; study.index_entry).
%   The table enters the index of its analysis, from which the analysis
%   README lists it with its title, scope, caption and command.
%   Side effects: writes the CSV (atomically); adds to CFG.layout.index.

    sources = cellstr(string(sources));
    for i = 1:numel(sources)
        assert(isfile(sources{i}), 'study:export_table:SourceMissing', ...
            'Table source is not a saved file: %s', sources{i});
    end
    [route, analysis, file, where] = study.figure_target(cfg, category, name, cells);
    folder = fullfile(cfg.layout.output, route, strrep(where, '/', filesep), 'tables');
    if ~isfolder(folder), mkdir(folder); end
    pathValue = fullfile(folder, [file '.csv']);
    utils.atomic_write_table(pathValue, T);
    prefix = '';
    if ~strcmp(where, analysis), prefix = ['../' where '/']; end
    study.index_entry(cfg, 'table', {[prefix 'tables/' file '.csv']}, title, '', cells);
end
