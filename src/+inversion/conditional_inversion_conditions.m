function condition = conditional_inversion_conditions(cfg, id)
%CONDITIONAL_INVERSION_CONDITIONS The conditions of the conditional inversion: parameters fixed at the case truth.
%   These conditions are a methodological identifiability analysis. The
%   condition that fixes nothing (A in the thesis) is the canonical all_six
%   cell and is never run or copied by the conditional inversion; every other
%   condition fixes its parameters at the held-out case's synthetic truth and
%   infers the others.
%
%   CONDITIONS = inversion.conditional_inversion_conditions(CFG) returns the
%   conditions of the settings' table (A.9, cfg.conditionalInversion,
%   study.conditional_design) in its order. CONDITION =
%   inversion.conditional_inversion_conditions(CFG, ID) returns the one
%   whose code (its label), id or tag is ID. Fields: code, id and tag (from
%   the fixed set: <names>_fixed, or baseline), label and description, the
%   fixed and free parameter indices and names, mask (1 = free), role,
%   scheduledScenarios, canonicalReference, supplementaryExecution.
%   Side effects: none.

    assert(isstruct(cfg) && isfield(cfg, 'conditionalInversion') && ...
        isfield(cfg.conditionalInversion, 'conditions'), ...
        'inversion:conditional_inversion_conditions:Configuration', ...
        'The conditions of the conditional inversion come from the settings (A.9).');
    conditions = cfg.conditionalInversion.conditions;
    if nargin < 2 || isempty(id)
        condition = conditions;
        return;
    end
    key = char(string(id));
    hit = find(strcmp({conditions.code}, key) | strcmp({conditions.id}, key) | ...
        strcmp({conditions.tag}, key));
    assert(isscalar(hit), 'inversion:conditional_inversion_conditions:UnknownCondition', ...
        'Condition "%s" is not in the condition table of the settings (A.9: %s).', key, ...
        strjoin({conditions.code}, ', '));
    condition = conditions(hit);
end
