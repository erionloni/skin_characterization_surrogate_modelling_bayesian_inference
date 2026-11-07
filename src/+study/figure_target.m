function [route, analysis, file, folder] = figure_target(cfg, category, name, cells)
%FIGURE_TARGET Analysis folder and flat file name of one rendered figure or table.
%   [ROUTE, ANALYSIS, FILE, FOLDER] = study.figure_target(CFG, CATEGORY, NAME, CELLS) maps a
%   renderer figure (CATEGORY as passed to plotting.export_saved_figure, and
%   NAME) to its place in the publication layout:
%     <route>/<ANALYSIS>/figures/<FILE>.<format>
%   The longest category of study.layout that matches CATEGORY decides the
%   analysis folder. Deeper category levels and the category's prefix are
%   joined into FILE, so every figure keeps a unique, descriptive name in one
%   flat folder:
%     'inversion/cross_design', 'gp_only_m3_e_RD_difference_vs_all_six'
%       -> fixed, 04_inversion, cross_design_gp_only_m3_e_RD_difference_vs_all_six
%   A prefix is not repeated when NAME already starts with it.
%   A category that two analyses of a route share (the generalized 'figures'
%   of the protocol screening and of the confirmation) goes to the analysis
%   being rendered (CFG.layout.analysis).
%   FOLDER is the folder below the route that the output goes to: ANALYSIS,
%   or, for a per-case category ('case/<step>'), the case folder
%   'cases/case_<CaseID>/<step>' of the one case that the cells it shows
%   belong to (CELLS: a struct with the field CaseID; study.index_entry):
%     'case/inversion', 'gp_only_all_six_corner' (cells of case 131)
%       -> fixed, 04_inversion, gp_only_all_six_corner, cases/case_131/inversion
%   Side effects: none.

    L = study.layout();
    route = cfg.layout.route;
    categories = L.categories(strcmp({L.categories.route}, route));
    category = strrep(char(string(category)), '\', '/');
    rendered = '';
    if isfield(cfg.layout, 'analysis'), rendered = char(cfg.layout.analysis); end
    best = [];
    for i = 1:numel(categories)
        c = categories(i).category;
        if strcmp(category, c) || startsWith(category, [c '/'])
            if isempty(best) || numel(c) > numel(best.category) || ...
                    (numel(c) == numel(best.category) && strcmp(categories(i).analysis, rendered))
                best = categories(i);
            end
        end
    end
    assert(~isempty(best), 'study:figure_target:UnknownCategory', ...
        'Figure category "%s" of the %s route has no analysis folder (study.layout).', ...
        category, route);
    analysis = best.analysis;
    deeper = strtrim(extractAfter(category, strlength(best.category)));
    deeper = regexprep(char(deeper), '^/', '');
    parts = {};
    if ~isempty(deeper)
        parts = strsplit(deeper, '/');
    end
    name = char(string(name));
    stem = strjoin([parts, {name}], '_');
    prefix = best.prefix;
    if ~isempty(prefix) && ~startsWith(stem, prefix)
        stem = [prefix stem];
    end
    file = regexprep(stem, '[^A-Za-z0-9_.-]', '_');
    folder = analysis;
    if startsWith(best.category, 'case/')
        if nargin < 4, cells = []; end
        ids = [];
        if isstruct(cells) && isfield(cells, 'CaseID'), ids = unique(double([cells.CaseID])); end
        assert(isscalar(ids), 'study:figure_target:CaseOutput', ...
            'The per-case output %s (category %s) must show the cells of exactly one case.', ...
            file, category);
        folder = sprintf('cases/case_%d/%s', ids, extractAfter(best.category, 'case/'));
    end
end
