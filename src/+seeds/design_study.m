function seed = design_study(cfg, purpose, scenario, caseID)
%DESIGN_STUDY The seed of a random draw of the design study.
%   SEED = seeds.design_study(CFG, 'rank_bootstrap', SCENARIO) is the base
%   seed of the rank bootstrap of the scenario SCENARIO (the pairwise
%   comparison p of metric i uses mod(base + 10000 i + p, 2147483646) + 1,
%   the all-design bootstrap of metric i base + i - 1; design_study.generate).
%   SEED = seeds.design_study(CFG, 'ratio_validation', SCENARIO, CASEID) is
%   the seed of the Monte Carlo check of the ratio delta method for the case
%   CASEID.
%   The thesis seeds are recorded in config/seeds/design_study_seeds.csv
%   (cfg.seeds.tables.designStudy). Without a recorded seed, the rank
%   bootstrap takes the seed of the rule cfg.seeds.rules.rankBootstrap
%   (base + scenario * the scenario's number in inversion.scenario_registry)
%   and the ratio check the scenario's rank-bootstrap seed plus
%   cfg.seeds.rules.ratioValidation (offset + case * CaseID).
%   Side effects: none (reads the recorded table once per session).

    scenario = inversion.scenario_registry(scenario).tag;
    if nargin < 4, caseID = []; end
    seed = seeds.recorded(cfg, 'designStudy', struct('Purpose', purpose, ...
        'Scenario', scenario, 'CaseID', caseID));
    if ~isnan(seed), return; end
    switch purpose
        case 'rank_bootstrap'
            number = find(strcmp({inversion.scenario_registry().tag}, scenario));
            seed = seeds.rule(cfg.seeds.rules.rankBootstrap, struct('scenario', number));
            request = sprintf('the rank bootstrap of %s', scenario);
        case 'ratio_validation'
            base = seeds.design_study(cfg, 'rank_bootstrap', scenario);
            rule = cfg.seeds.rules.ratioValidation;
            seed = seeds.rule(struct('base', base + rule.offset, 'case', rule.case), ...
                struct('case', double(caseID)));
            request = sprintf('the ratio check of case %d in %s', double(caseID), scenario);
        otherwise
            error('seeds:design_study:Purpose', 'Unknown design-study seed purpose %s.', purpose);
    end
    seeds.check_new(cfg, seed, request);
end
