function [records, schedule] = gp_mean_seed_schedule(cfg, grid, inversionCases, resultsFolder)
%GP_MEAN_SEED_SCHEDULE The seeds of the GP-mean inversion, checked against every seed used so far.
%   [RECORDS, SCHEDULE] = inversion.gp_mean_seed_schedule(CFG, GRID,
%   INVERSIONCASES, RESULTSFOLDER) returns the seed of every request of the
%   GP-mean cells GRID (inversion.build_gp_mean_inversion_grid): per cell,
%   level (CFG.mcmc.levels) and replicate (CFG.mcmc.productionReplicateIDs)
%   the AIES seed of seeds.mcmc, which no recorded seed holds, so the seed
%   rule of the settings (0.6): base + case * CaseID + scenario * 4 (the
%   number of gp_mean_det, inversion.scenario_registry) + design * 1
%   (all_six) + level * level number + replicate, condition 0. The schedule
%   is frozen by that rule (the rule of the thesis) and the scenario's
%   number; the results record it (data/seeds/seed_record.csv).
%   Before any request runs it checks that the seeds differ from each other
%   and from every seed used so far:
%     - the recorded seeds of config/seeds (seeds.check_new, inside seeds.mcmc);
%     - the canonical and conditional requests of the fixed route's settings
%       (inversion.conditional_seed_schedule over the grid of A.9 and the
%       inversion's cases INVERSIONCASES, data.inversion_cases);
%     - every seed shipped in RESULTSFOLDER (thesis_results/): the column
%       Seed of each CSV file whose name contains "seed" (the conditional
%       campaign's seed record, the confirmation's seed schedule).
%   RECORDS: one element per request, with the fields of the canonical seed
%   schedule (inversion.grid_campaign_support 'seed_schedule': CellIndex,
%   CellID, CaseID, Scenario, Design, Sampler, ReplicateID, StepCount,
%   Seed, Request) and SeedSource ('rule'); SCHEDULE the same as a table.
%   Side effects: none (reads the seed tables and the shipped seed files).
%   Computation: seconds.

    replicates = reshape(double(cfg.mcmc.productionReplicateIDs), 1, []);
    levels = reshape(double(cfg.mcmc.levels), 1, []);
    assert(isequal(replicates, [1 2]) && isequal(levels, [2000 5000]), ...
        'inversion:gp_mean_seed_schedule:ProductionSeedAxes', ...
        ['The production policy runs two independent replicates per level at 2000 and ' ...
         '5000 steps.']);
    assert(isstruct(grid) && isfield(grid, 'cells') && ...
        all(strcmp({grid.cells.scenario}, 'gp_mean_det')), ...
        'inversion:gp_mean_seed_schedule:Grid', 'The GP-mean grid is required.');
    used = used_seeds(cfg, inversionCases, resultsFolder);

    template = struct('CellIndex', NaN, 'CellID', '', 'CaseID', NaN, 'Scenario', '', ...
        'Design', '', 'Sampler', '', 'ReplicateID', NaN, 'StepCount', NaN, 'Seed', NaN, ...
        'Request', '', 'SeedSource', '');
    records = repmat(template, 1, grid.cellCount * numel(levels) * numel(replicates));
    cursor = 0;
    for c = 1:grid.cellCount
        cellRecord = grid.cells(c);
        for level = levels
            for replicate = replicates
                [seed, record] = seeds.mcmc(cfg, cellRecord.caseID, cellRecord.scenario, ...
                    cellRecord.design, [], 'AIES', replicate, level);
                assert(strcmp(record.source, 'rule'), ...
                    'inversion:gp_mean_seed_schedule:RecordedSeed', ...
                    'The request %s has a recorded seed; the GP-mean inversion has none.', ...
                    record.request);
                assert(~ismember(double(seed), used), ...
                    'inversion:gp_mean_seed_schedule:UsedSeed', ...
                    'The seed %d of %s is a seed used before.', double(seed), record.request);
                cursor = cursor + 1;
                records(cursor) = struct('CellIndex', double(cellRecord.cellIndex), ...
                    'CellID', cellRecord.cellID, 'CaseID', double(cellRecord.caseID), ...
                    'Scenario', cellRecord.scenario, 'Design', cellRecord.design, ...
                    'Sampler', record.sampler, 'ReplicateID', double(record.replicateID), ...
                    'StepCount', double(record.stepCount), 'Seed', double(seed), ...
                    'Request', record.request, 'SeedSource', record.source);
            end
        end
    end
    values = [records.Seed];
    assert(numel(unique(values)) == numel(values), ...
        'inversion:gp_mean_seed_schedule:Collision', ...
        'Two requests of the GP-mean inversion have the same seed.');
    schedule = struct2table(records);
end

function used = used_seeds(cfg, inversionCases, resultsFolder)
%USED_SEEDS Every seed of the fixed route's settings and of the shipped results, as one sorted vector.
    ids = reshape(double([inversionCases.case_id]), 1, []);
    selected = reshape(double(cfg.conditionalInversion.caseIDs), 1, []);
    [present, where] = ismember(selected, ids);
    assert(all(present), 'inversion:gp_mean_seed_schedule:ConditionalCases', ...
        'The conditional cases %s must be cases of the inversion (%s).', mat2str(selected), ...
        mat2str(ids));
    conditionalGrid = inversion.build_conditional_inversion_grid(cfg, inversionCases(where));
    fixedRoute = inversion.conditional_seed_schedule(cfg, conditionalGrid, inversionCases);
    used = reshape(double(fixedRoute.numericSeeds), [], 1);
    assert(isfolder(resultsFolder), 'inversion:gp_mean_seed_schedule:Results', ...
        'The shipped results %s are needed to check the seeds against every seed used so far.', ...
        resultsFolder);
    files = dir(fullfile(resultsFolder, '**', '*seed*.csv'));
    shippedCount = 0;
    for k = 1:numel(files)
        T = utils.read_csv_table(fullfile(files(k).folder, files(k).name), {});
        if ~ismember('Seed', T.Properties.VariableNames), continue; end
        used = [used; double(T.Seed(:))]; %#ok<AGROW>
        shippedCount = shippedCount + 1;
    end
    assert(shippedCount > 0, 'inversion:gp_mean_seed_schedule:ShippedSeeds', ...
        'No shipped seed record with a column Seed below %s.', resultsFolder);
    used = unique(used(isfinite(used)));
end
