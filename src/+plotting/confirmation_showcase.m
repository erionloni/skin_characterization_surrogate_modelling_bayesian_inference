function id = confirmation_showcase(cfg, status, materials, protocols)
%CONFIRMATION_SHOWCASE The showcase material of the confirmation, by the rule of the settings.
%   ID = plotting.confirmation_showcase(CFG, STATUS, MATERIALS, PROTOCOLS)
%   applies the rule CFG.stage9bConfirmation.showcase (settings B.7,
%   generalized.confirmation.showcase), fixed before the results exist and
%   never chosen by the outcome: 'first_all_certified' gives the first
%   material of MATERIALS (the design's order) whose cells of all PROTOCOLS
%   are certified in the status table STATUS (study.cell_status_columns
%   'confirmation'), NaN when none is; a MaterialCaseID gives that material.
%   Side effects: none.
    rule = cfg.stage9bConfirmation.showcase;
    if isnumeric(rule)
        assert(any(status.MaterialCaseID == rule), 'plotting:confirmation_showcase:Material', ...
            'The showcase material %d of the settings is not a material of the campaign.', rule);
        id = double(rule);
        return;
    end
    id = NaN;
    for m = reshape(double(materials), 1, [])
        certified = arrayfun(@(p) any(status.MaterialCaseID == m & status.Protocol == p & ...
            status.Status == "certified"), string(protocols));
        if all(certified)
            id = m;
            return;
        end
    end
end
