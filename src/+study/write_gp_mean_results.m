function write_gp_mean_results(cfg, preparation, done)
%WRITE_GP_MEAN_RESULTS The GP-mean inversion results of a run, in the layout of thesis_results/.
%   study.write_gp_mean_results(CFG, PREPARATION, DONE) reads the GP-mean
%   campaign of this run (below CFG.paths.gpMeanInversion; settings A.13)
%   and writes to CFG.paths.gpMeanResults
%   (<run>/fixed/09_gp_mean_inversion/data):
%     cell_status.csv
%         one row per cell (study.cell_status_columns 'gp_mean'): its status,
%         certified, healthy fallback (a healthy request of a cell that did
%         not certify: the highest level first, replicate 1 first;
%         inversion.load_gp_mean_available_posterior) or unavailable (no
%         healthy request, or not run in this campaign), the provider, whether
%         it counts in the certified-only values, the reason it is not
%         certified, the health note of its terminal replicate pair
%         (study.diagnostic_notes), the chain levels it ran (its executed
%         requests) and whether it escalated.
%     posterior_parameter_cells.csv
%         per cell and parameter the posterior summary of its provider, with
%         the columns and formulas of the recovery's
%         fixed/05_recovery/data/tables/posterior_parameter_cells.csv
%         (recovery.posterior_parameter_rows): truth, posterior mean, median
%         and SD, the SD over the prior SD, the central 50 % and 95 %
%         intervals, whether the truth lies inside them, the errors; NaN for
%         a cell without a posterior.
%     comparison.csv
%         per case, parameter and scenario (the three canonical scenarios,
%         all_six, then gp_mean_det) the status of the cell and its truth,
%         posterior mean, SD, SD over the prior SD, 95 % interval, truth
%         inside, signed error of the posterior mean and the error of the
%         posterior mean over the prior width. The canonical rows are copied
%         as written from the shipped results (CFG.native.results:
%         fixed/05_recovery/data/tables/posterior_parameter_cells.csv for the
%         values, fixed/04_inversion/data/cell_status.csv for the status);
%         nothing is recomputed. Source names the file of each row.
%     draws/index.csv and gp_mean_det/all_six/case_<id>.mat
%         for each cell with a provider every retained draw of both
%         replicates of the provider's level with the log-likelihood the
%         sampler computed for each (study.write_cell_draws, schema
%         shipped_posterior_draws_v3).
%     seeds/seed_record.csv
%         the seed of every request of the campaign (each cell, replicate
%         and level; a request runs only when its level is reached), in the
%         columns of the conditional campaign's seed record, SeedSource
%         'rule' (inversion.gp_mean_seed_schedule).
%   DONE (logical, one per cell) marks the cells that have run.
%   Files carry no hashes.
%   Side effects: writes the files above, replacing earlier versions.

    root = ensure(cfg.paths.gpMeanResults);
    campaignCfg = inversion.gp_mean_campaign_config(cfg);
    P = parameters.parameter_space(cfg);
    n = preparation.grid.cellCount;
    statuses = cell(n, 1);
    parameterRows = cell(n, 1);
    draws = {};
    for k = 1:n
        cellRecord = preparation.cellRecords(k);
        if ~done(k)
            status = struct('loaded', false, 'certified', false, 'state', 'not_run', ...
                'reason', 'not run in this campaign');
            A = [];
        else
            [A, status] = inversion.load_gp_mean_available_posterior(cfg, cellRecord);
        end
        [label, rowStatus] = status_names(status);
        statuses{k} = status_row(campaignCfg, cfg, cellRecord, A, status, label, done(k));
        parameterRows{k} = recovery.posterior_parameter_rows(cellRecord, provider_or_empty(A, status), ...
            P, rowStatus);
        if ~status.loaded, continue; end
        provider = A.certification.provider;
        other = setdiff(double(cfg.mcmc.productionReplicateIDs), double(provider.replicateID));
        [B, partnerStatus] = inversion.load_posterior_artifact(campaignCfg, cellRecord, ...
            char(provider.sampler), other, double(provider.stepCount));
        if ~partnerStatus.valid, B = []; end
        if ~status.certified
            % A healthy fallback: its provider evidence, no certification.
            A = rmfield(A, 'certification');
        end
        draws{end+1} = study.write_cell_draws(cfg, fullfile(root, 'draws', ...
            char(cellRecord.scenario), char(cellRecord.design)), cellRecord, A, B, ...
            partnerStatus.reason, []); %#ok<AGROW>
    end
    statusTable = vertcat(statuses{:});
    utils.atomic_write_table(fullfile(root, 'cell_status.csv'), statusTable);
    cells = vertcat(parameterRows{:});
    utils.atomic_write_table(fullfile(root, 'posterior_parameter_cells.csv'), cells);
    utils.atomic_write_table(fullfile(root, 'comparison.csv'), comparison(cfg, statusTable, cells));
    index = cell2table(cell(0, numel(study.cell_draws_columns())), ...
        'VariableNames', study.cell_draws_columns());
    if ~isempty(draws), index = vertcat(draws{:}); end
    utils.atomic_write_table(fullfile(ensure(fullfile(root, 'draws')), 'index.csv'), index);
    utils.atomic_write_table(fullfile(ensure(fullfile(root, 'seeds')), 'seed_record.csv'), ...
        seed_record(preparation));
end

function [label, rowStatus] = status_names(status)
%STATUS_NAMES The status of a cell (certified, healthy fallback, unavailable) and the status of its summary rows.
    if status.loaded && status.certified
        label = "certified";
    elseif status.loaded
        label = "healthy fallback";
    else
        label = "unavailable";
    end
    reason = string(status.reason);
    if label == "certified", reason = ""; end
    rowStatus = struct('loaded', logical(status.loaded), 'state', char(label), ...
        'reason', char(reason));
end

function A = provider_or_empty(A, status)
    if ~status.loaded, A = []; end
end

function T = status_row(campaignCfg, cfg, cellRecord, A, status, label, hasRun)
%STATUS_ROW One cell's row of cell_status.csv (study.cell_status_columns 'gp_mean').
    sampler = ""; replicate = NaN; steps = NaN;
    if status.loaded
        provider = A.certification.provider;
        sampler = string(provider.sampler);
        replicate = double(provider.replicateID);
        steps = double(provider.stepCount);
    end
    reason = string(status.reason);
    if label == "certified", reason = ""; end
    [levels, note] = pair_levels(campaignCfg, cfg, cellRecord, hasRun);
    T = table(double(cellRecord.caseID), string(cellRecord.scenario), string(cellRecord.design), ...
        label, sampler, replicate, steps, label == "certified", reason, note, ...
        string(strjoin(string(levels), ';')), numel(levels) > 1, ...
        'VariableNames', study.cell_status_columns('gp_mean'));
end

function [levels, note] = pair_levels(campaignCfg, cfg, cellRecord, hasRun)
%PAIR_LEVELS The levels the cell ran, and the health note of its terminal replicate pair.
%   From the cell's terminal decision (certified or not; only that decision
%   is saved): LEVELS the step counts of its executed requests, NOTE the
%   R-hat / tail-ESS note of the decision's pair (study.diagnostic_notes).
    levels = zeros(1, 0);
    note = "";
    if ~hasRun, return; end
    outcome = inversion.grid_campaign_support('cell_outcome', campaignCfg, cellRecord);
    if outcome.missing, return; end
    decision = outcome.decision;
    executed = decision.executedEvidence;
    if iscell(executed), executed = [executed{:}]; end
    ran = strcmp({executed.executionState}, 'executed');
    levels = unique(double([executed(ran).stepCount]));
    if ~isfield(decision, 'evidence') || ~isfield(decision.evidence, 'aiesPairReliability'), return; end
    pair = decision.evidence.aiesPairReliability;
    if ~isfield(pair, 'ensembleTimeDiagnostics') || ~isfield(pair, 'posteriorReproducibility'), return; end
    support = pair.ensembleTimeDiagnostics;
    names = string(pair.posteriorReproducibility.parameterNames(:));
    [~, note] = study.diagnostic_notes(double(support.rankSplitRhat(:)), double(support.tailESS(:)), ...
        cfg.inversion.degenerateRhat, repmat(double(decision.stepCount), numel(names), 1), names);
end

function C = comparison(cfg, status, cells)
%COMPARISON Per case, parameter and scenario the status and the posterior summary: the canonical cells as shipped, then gp_mean_det.
%   The shipped values are read as text and converted back to the numbers
%   their 15 significant digits state, so that the table writes them as
%   they are written there.
    results = cfg.native.results;
    valuesFile = fullfile(results, 'fixed', '05_recovery', 'data', 'tables', 'posterior_parameter_cells.csv');
    statusFile = fullfile(results, 'fixed', '04_inversion', 'data', 'cell_status.csv');
    assert(isfile(valuesFile) && isfile(statusFile), 'study:gp_mean:ShippedResults', ...
        ['The comparison reads the shipped canonical cells, %s and %s; they are missing. ' ...
         'Point ''ResultsFolder'' to thesis_results/.'], valuesFile, statusFile);
    V = as_text(valuesFile);
    S = as_text(statusFile);
    numbers = {'TruthPhysical', 'PosteriorMeanPhysical', 'PosteriorSDPhysical', 'NormalizedPosteriorSD', ...
        'CI025Physical', 'CI975Physical', 'TruthCovered95', 'SignedErrorFromPosteriorMeanPhysical', ...
        'PosteriorMeanNormalizedRecoveryError'};
    scenarios = string(cfg.gpMeanInversion.comparisonScenarios);
    design = string(cfg.gpMeanInversion.design);
    parts = {};
    for c = reshape(double(cfg.gpMeanInversion.caseIDs), 1, [])
        for s = reshape(scenarios, 1, [])
            rows = V(V.CaseID == string(c) & V.Scenario == s & V.Design == design, :);
            hit = S(S.CaseID == string(c) & S.Scenario == s & S.Design == design, :);
            assert(height(hit) == 1 && height(rows) == numel(cfg.paramNames), ...
                'study:gp_mean:ShippedCell', ...
                'The shipped results do not list case %d, %s, %s once (%s, %s).', c, s, design, ...
                statusFile, valuesFile);
            values = cellfun(@(name) str2double(rows.(name)), numbers, 'UniformOutput', false);
            parts{end+1} = table(repmat(c, height(rows), 1), rows.Parameter, rows.Scenario, ...
                repmat(hit.Status, height(rows), 1), ...
                repmat(str2double(hit.InCertifiedOnlyValues), height(rows), 1), values{:}, ...
                repmat("thesis_results/fixed/05_recovery/data/tables/posterior_parameter_cells.csv", ...
                height(rows), 1), 'VariableNames', comparison_columns()); %#ok<AGROW>
        end
        mine = cells(cells.CaseID == c, :);
        one = status(status.CaseID == c, :);
        values = cellfun(@(name) double(mine.(name)), numbers, 'UniformOutput', false);
        parts{end+1} = table(repmat(c, height(mine), 1), string(mine.Parameter), string(mine.Scenario), ...
            repmat(string(one.Status), height(mine), 1), ...
            repmat(double(one.InCertifiedOnlyValues), height(mine), 1), values{:}, ...
            repmat("fixed/09_gp_mean_inversion/data/posterior_parameter_cells.csv", height(mine), 1), ...
            'VariableNames', comparison_columns()); %#ok<AGROW>
    end
    C = vertcat(parts{:});
end

function names = comparison_columns()
    names = {'CaseID', 'Parameter', 'Scenario', 'Status', 'InCertifiedOnlyValues', 'TruthPhysical', ...
        'PosteriorMeanPhysical', 'PosteriorSDPhysical', 'NormalizedPosteriorSD', 'CI025Physical', ...
        'CI975Physical', 'TruthCovered95', 'SignedErrorFromPosteriorMeanPhysical', ...
        'PosteriorMeanNormalizedRecoveryError', 'Source'};
end

function T = as_text(file)
%AS_TEXT A shipped table with every column as text, empty fields as "".
    options = detectImportOptions(file, 'Delimiter', ',', 'TextType', 'string', ...
        'VariableNamingRule', 'preserve');
    options = setvartype(options, options.VariableNames, 'string');
    T = readtable(file, options);
    for name = reshape(T.Properties.VariableNames, 1, [])
        column = T.(name{1});
        column(ismissing(column)) = "";
        T.(name{1}) = column;
    end
end

function T = seed_record(preparation)
%SEED_RECORD The seed of every request of the campaign, in the columns of the conditional campaign's seed record.
    r = preparation.seedRecords;
    T = table(repmat("gp_mean", numel(r), 1), string({r.CellID}).', repmat("", numel(r), 1), ...
        [r.CaseID].', string({r.Scenario}).', string({r.Design}).', string({r.Sampler}).', ...
        [r.ReplicateID].', [r.StepCount].', [r.Seed].', string({r.SeedSource}).', ...
        'VariableNames', {'Campaign', 'CellID', 'ConditionTag', 'CaseID', 'Scenario', 'Design', ...
        'Sampler', 'Replicate', 'StepCount', 'Seed', 'SeedSource'});
end

function folder = ensure(folder)
    if ~isfolder(folder), mkdir(folder); end
end
