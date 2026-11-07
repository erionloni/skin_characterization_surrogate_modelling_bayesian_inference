function label = cell_status_label(cfg, caseID, scenario, design)
%CELL_STATUS_LABEL The status of one inversion cell, for a figure title.
%   LABEL = plotting.cell_status_label(CFG, CASEID, SCENARIO, DESIGN) is the
%   status the analysis's saved results record for the cell
%   (CFG.layout.cellStatus, study.cell_status): 'certified', 'healthy
%   fallback' or 'unavailable'; '' when the status is not known (no status
%   table, or a renderer called outside reproduce mode).
%   Side effects: none.
    label = '';
    if ~isfield(cfg, 'layout') || ~isstruct(cfg.layout) || ~isfield(cfg.layout, 'cellStatus')
        return;
    end
    S = cfg.layout.cellStatus;
    hit = S.CaseID == double(str2double(string(caseID))) & S.Scenario == string(scenario) & ...
        S.Design == string(design) & S.Condition == "";
    if nnz(hit) == 1, label = char(S.Status(hit)); end
end
