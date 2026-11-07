function cfg = reroot(cfg, from, to)
%REROOT Move every path of cfg.paths and cfg.files below FROM to the same place below TO.
%   CFG = study.reroot(CFG, FROM, TO): every file and folder that
%   study.project_config derives from a stage folder (FROM) keeps its name
%   below the new folder (TO). Used by study.native_config and by the
%   design study's summary of the certified cells alone
%   (study.steps.fixed_design_study).
%   Side effects: none.
    from = char(from);
    for group = {'paths', 'files'}
        names = fieldnames(cfg.(group{1}));
        for i = 1:numel(names)
            value = cfg.(group{1}).(names{i});
            if ~(ischar(value) || (isstring(value) && isscalar(value))), continue; end
            value = char(value);
            if strcmp(value, from) || startsWith(value, [from filesep])
                cfg.(group{1}).(names{i}) = [char(to) value(numel(from) + 1:end)];
            end
        end
    end
end
