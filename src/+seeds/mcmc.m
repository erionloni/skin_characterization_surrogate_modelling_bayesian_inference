function [seed, record] = mcmc(cfg, caseID, scenario, design, fixedParameters, ...
        sampler, replicateID, stepCount)
%MCMC The seed of one MCMC request of the fixed route.
%   [SEED, RECORD] = seeds.mcmc(CFG, CASEID, SCENARIO, DESIGN,
%   FIXEDPARAMETERS, SAMPLER, REPLICATEID, STEPCOUNT) returns the seed of the
%   request: the case CASEID, the scenario and observation design, the
%   indices of the material parameters fixed at the case truth
%   (FIXEDPARAMETERS; [] for the canonical inversion, where all four are
%   free), the sampler, the replicate and the level (STEPCOUNT, one of
%   cfg.mcmc.levels).
%   A request of the thesis campaigns has the seed recorded in
%   config/seeds/mcmc_seeds.csv (cfg.seeds.tables.mcmc), the frozen record
%   of the thesis runs. Any other request (a new case or condition, another
%   level list) gets the seed of the rule cfg.seeds.rules.mcmc:
%       base + case * CaseID + condition * condition code
%            + scenario * scenario number + design * design number
%            + level * level number + replicate * replicate,
%   where the condition code adds 1, 2, 4 and 8 for m3_f, m3_e, log10_k0
%   and thickness fixed (0: the canonical inversion), so that it follows
%   from the fixed parameters and not from a condition's name; the scenario
%   number is the scenario's number in inversion.scenario_registry (1 to 3
%   the canonical scenarios in their order, 4 the side scenario
%   gp_mean_det), the design number the position in
%   inversion.design_registry and the level number the position of
%   STEPCOUNT in cfg.mcmc.levels. A seed of the rule must differ from every
%   recorded seed (seeds.check_new). The rule is defined for the production
%   sampler AIES.
%   RECORD: the request's axes, the seed, its source ('recorded' or
%   'rule') and the request as readable text (request).
%   Side effects: none (reads the recorded tables once per session).

    levels = reshape(double(cfg.mcmc.levels), 1, []);
    assert(isscalar(stepCount) && ismember(stepCount, levels), 'seeds:mcmc:Level', ...
        'The step count %g is not one of the configured levels %s.', stepCount, mat2str(levels));
    assert(isscalar(replicateID) && replicateID >= 1 && replicateID == fix(replicateID), ...
        'seeds:mcmc:Replicate', 'The replicate must be a positive integer.');
    assert(isscalar(caseID) && isnumeric(caseID) && caseID >= 1 && caseID == fix(caseID), ...
        'seeds:mcmc:Case', 'The CaseID must be a positive integer.');
    scenario = inversion.scenario_registry(scenario).tag;
    design = inversion.design_registry(design).name;
    sampler = upper(strtrim(char(string(sampler))));
    if strcmp(sampler, 'ADAPTIVE_METROPOLIS'), sampler = 'AM'; end
    fixedParameters = unique(reshape(double(fixedParameters), 1, []));
    assert(all(ismember(fixedParameters, 1:4)), 'seeds:mcmc:FixedParameters', ...
        'The fixed parameters must be indices 1 to 4 of the material parameters.');
    code = sum(2 .^ (fixedParameters - 1));
    [campaign, tag] = thesis_campaign(fixedParameters);
    text = sprintf('case %d, %s, %s, condition code %d, %s, replicate %d, %d steps', ...
        caseID, scenario, design, code, sampler, replicateID, stepCount);

    source = 'recorded';
    seed = NaN;
    if ~isempty(campaign)
        seed = seeds.recorded(cfg, 'mcmc', struct('Campaign', campaign, 'CaseID', caseID, ...
            'Scenario', scenario, 'Design', design, 'ConditionTag', tag, 'Sampler', sampler, ...
            'Replicate', replicateID, 'StepCount', stepCount));
    end
    if isnan(seed)
        assert(strcmp(sampler, 'AIES'), 'seeds:mcmc:Sampler', ...
            'No seed is recorded for the %s request (%s) and the seed rule covers AIES only.', ...
            sampler, text);
        source = 'rule';
        [~, scenarioNumber] = inversion.scenario_registry(scenario);
        designNumber = find(strcmp({inversion.design_registry().name}, design));
        seed = seeds.rule(cfg.seeds.rules.mcmc, struct('case', caseID, 'condition', code, ...
            'scenario', scenarioNumber, 'design', designNumber, ...
            'level', find(levels == stepCount), 'replicate', replicateID));
        seeds.check_new(cfg, seed, ['the MCMC request ' text]);
    end
    record = struct('caseID', double(caseID), 'scenario', scenario, 'design', design, ...
        'fixedParameters', fixedParameters, 'conditionCode', code, 'sampler', sampler, ...
        'replicateID', double(replicateID), 'stepCount', double(stepCount), ...
        'seed', seed, 'source', source, 'request', text);
end

function [campaign, tag] = thesis_campaign(fixedParameters)
%THESIS_CAMPAIGN The campaign and condition name under which the frozen record lists a request.
%   The canonical campaign fixes no parameter; the conditional campaign
%   fixed thickness (4), m3_f (1) or both. Other sets have no record.
    campaign = ''; tag = '';
    if isempty(fixedParameters)
        campaign = 'canonical';
    elseif isequal(fixedParameters, 4)
        campaign = 'conditional'; tag = 'thickness_fixed';
    elseif isequal(fixedParameters, 1)
        campaign = 'conditional'; tag = 'm3f_fixed';
    elseif isequal(fixedParameters, [1 4])
        campaign = 'conditional'; tag = 'm3f_and_thickness_fixed';
    end
end
