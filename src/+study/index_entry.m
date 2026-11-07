function index_entry(cfg, kind, files, title, note, cells)
%INDEX_ENTRY Enter one rendered figure or table into the index of its analysis.
%   study.index_entry(CFG, KIND, FILES, TITLE, NOTE, CELLS) records, in
%   CFG.layout.index (a containers.Map that study.reproduce keeps per
%   analysis), the figure or table (KIND 'figure' or 'table') written as
%   FILES (below the analysis folder, e.g. {'figures/x.png', 'figures/x.pdf'})
%   with its TITLE, its scope, a caption line, the command that re-renders
%   it and a NOTE ('' or a remark on how it was drawn). CELLS names the
%   inversion cells it shows: [] for an output that is not posterior-based,
%   'all' for every cell of its analysis, or a struct whose fields CaseID,
%   Scenario, Design and Condition each list the values shown (a missing
%   field: every value); a struct with CaseID and PosteriorBased false is an
%   output of that one case that is not posterior-based (its case folder,
%   study.figure_target). With the status of the analysis's cells
%   (CFG.layout.cellStatus, study.cell_status):
%     scope    "not posterior-based"; "case <id>, <scenario>, <design>:
%              <status>" for one cell; "case <id>: certified and healthy
%              fallback" for several cells of one case; otherwise "<n> cases:
%              certified and healthy fallback";
%     caption  for several cells, one line naming the healthy fallbacks and
%              the unavailable cells among them ('' when all are certified).
%   The analysis README lists the index (study.write_readme). Without an
%   index (a renderer called outside study.reproduce) nothing is recorded.
%   Side effects: changes CFG.layout.index (a handle).
    if ~isfield(cfg.layout, 'index') || ~isa(cfg.layout.index, 'containers.Map'), return; end
    files = cellstr(string(files));
    [scope, caption] = describe_cells(cfg, cells);
    cfg.layout.index(files{1}) = struct('kind', kind, 'files', {files}, ...
        'title', study.plain_text(title), 'scope', scope, 'caption', caption, ...
        'command', cfg.layout.command, 'note', note);
end

function [scope, caption] = describe_cells(cfg, cells)
%DESCRIBE_CELLS The scope and the caption line of the cells an output shows.
    caption = '';
    if isempty(cells) || (isstruct(cells) && isfield(cells, 'PosteriorBased') && ~any(cells.PosteriorBased))
        scope = 'not posterior-based';
        return;
    end
    assert(isstruct(cells) || strcmp(cells, 'all'), 'study:index_entry:Cells', ...
        'The cells of an output are [], ''all'' or a struct of CaseID, Scenario, Design, Condition.');
    S = cfg.layout.cellStatus;
    if isstruct(cells)
        for name = reshape(fieldnames(cells), 1, [])
            S = S(ismember(S.(name{1}), cast_like(cells.(name{1}), S.(name{1}))), :);
        end
    end
    if isempty(S)
        scope = 'certified and healthy fallback';
    elseif height(S) == 1
        scope = sprintf('case %d, %s: %s', S.CaseID, cell_name(S), S.Status);
    else
        cases = unique(S.CaseID);
        if isscalar(cases)
            scope = sprintf('case %d: certified and healthy fallback', cases);
        else
            scope = sprintf('%d cases: certified and healthy fallback', numel(cases));
        end
        parts = {};
        labels = ["Healthy fallback", "Unavailable"];
        members = {S.Status == "healthy fallback", S.Status == "unavailable"};
        for k = 1:numel(labels)
            one = S(members{k}, :);
            if isempty(one), continue; end
            groups = unique(cell_name(one));   % sorted: scenario, design, condition
            text = strings(numel(groups), 1);
            for g = 1:numel(groups)
                ids = one.CaseID(cell_name(one) == groups(g));
                text(g) = sprintf('%s: %s', groups(g), strjoin(string(ids.'), ', '));
            end
            parts{end+1} = sprintf('%s: %s', labels(k), strjoin(text, '; ')); %#ok<AGROW>
        end
        caption = strjoin(parts, '. ');
        if ~isempty(caption), caption = [caption '.']; end
    end
end

function names = cell_name(S)
%CELL_NAME Scenario, design and condition of cells, e.g. "gp_only, all_six, m3f_fixed".
    names = S.Scenario + ", " + S.Design;
    conditional = S.Condition ~= "";
    names(conditional) = names(conditional) + ", " + S.Condition(conditional);
end

function v = cast_like(v, like)
    if isnumeric(like)
        v = double(v);
    else
        v = string(v);
    end
end
