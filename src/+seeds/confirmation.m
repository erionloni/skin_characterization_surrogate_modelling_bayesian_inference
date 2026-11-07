function [seed, record] = confirmation(cfg, caseID, protocol, sampler, replicateID, stepCount, design)
%CONFIRMATION The seed of one MCMC request of the confirmation.
%   [SEED, RECORD] = seeds.confirmation(CFG, CASEID, PROTOCOL, SAMPLER,
%   REPLICATEID, STEPCOUNT, DESIGN) returns the seed of a request of the
%   confirmation cell of the material CASEID (a CaseID of the fixed dataset),
%   the protocol PROTOCOL (its row in the protocols of the settings, B.7) and
%   the observation design DESIGN (all_six, d2_only: inversion.design_registry),
%   for the replicate and the level STEPCOUNT (one of cfg.mcmc.levels): the
%   rule cfg.seeds.rules.confirmation (settings 0.6),
%       base + design * design number + case * CaseID
%            + protocol * protocol row + level * level number
%            + replicate * replicate,
%   the design number being the design's position in
%   inversion.design_registry (all_six 1, d2_only 2) and the level number the
%   position of STEPCOUNT in cfg.mcmc.levels. No confirmation seed is
%   recorded; a seed of the rule must differ from every recorded seed
%   (seeds.check_new). The rule is defined for the production sampler AIES.
%   RECORD: the request's axes, the seed, its source ('rule') and the
%   request as readable text (request).
%   Side effects: none (reads the recorded tables once per session).

    levels = reshape(double(cfg.mcmc.levels), 1, []);
    assert(isscalar(stepCount) && ismember(stepCount, levels), 'seeds:confirmation:Level', ...
        'The step count %g is not one of the configured levels %s.', stepCount, mat2str(levels));
    design = char(string(design));
    designNumber = find(strcmp({inversion.design_registry().name}, design));
    assert(isscalar(designNumber), 'seeds:confirmation:Design', ...
        'The confirmation design %s is not a design of the inversion.', design);
    sampler = upper(strtrim(char(string(sampler))));
    text = sprintf('confirmation case %d, protocol %d, %s, %s, replicate %d, %d steps', ...
        caseID, protocol, design, sampler, replicateID, stepCount);
    assert(strcmp(sampler, 'AIES'), 'seeds:confirmation:Sampler', ...
        'The confirmation''s seed rule covers AIES only (%s).', text);
    seed = seeds.rule(cfg.seeds.rules.confirmation, struct('design', designNumber, 'case', caseID, ...
        'protocol', protocol, 'level', find(levels == stepCount), 'replicate', replicateID));
    seeds.check_new(cfg, seed, ['the MCMC request ' text]);
    record = struct('caseID', double(caseID), 'protocol', double(protocol), 'design', design, ...
        'sampler', sampler, 'replicateID', double(replicateID), 'stepCount', double(stepCount), ...
        'seed', seed, 'source', 'rule', 'request', text);
end
