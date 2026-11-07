function tf = is_publication(cfg)
%IS_PUBLICATION True when CFG describes a reproduce-mode run on the publication layout.
%   TF = study.is_publication(CFG) is true when CFG has the field layout,
%   which reproduce mode (study.reproduce) adds: the renderers then read the
%   shipped results and write the publication layout.
%   Side effects: none.
    tf = isstruct(cfg) && isfield(cfg, 'layout') && isstruct(cfg.layout) && ~isempty(cfg.layout);
end
