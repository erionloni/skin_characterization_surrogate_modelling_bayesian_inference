function write_inversion_results(cfg, preparation, done)
%WRITE_INVERSION_RESULTS The inversion results of a run, in the layout of thesis_results/.
%   study.write_inversion_results(CFG, PREPARATION, DONE) reads the campaign
%   of this run (the terminal decisions and certified posteriors of its
%   cells below CFG.paths.stage04) and writes to CFG.paths.inversionResults
%   (<run>/fixed/04_inversion/data):
%     cell_status.csv
%         the campaign's status table, one row per grid cell (CaseID,
%         Scenario, Design): Status certified or unavailable (no certified
%         provider after the last level, or not run in this campaign; Reason
%         says which); the provider
%         (ProviderSampler, ProviderReplicate, ProviderSteps);
%         InCertifiedOnlyValues (true for a certified cell: it counts in the
%         certified-only values of the summaries); Reason, why the cell is not
%         certified (empty for a certified cell); HealthNote, the undefined or
%         degenerate warning diagnostics of its pairs (study.diagnostic_notes).
%         Same columns as in thesis_results/, where the status can also be
%         healthy fallback.
%     draws/index.csv and <scenario>/<design>/case_<id>.mat
%         for each certified cell every retained draw of both replicates of
%         the provider's level, in the format of thesis_results/
%         (study.write_cell_draws), so that the run's
%         figures render with the code of reproduce mode.
%     diagnostics/pair_reliability_diagnostics.csv
%         the replicate-pair certification criteria (normalized Wasserstein
%         distance, 2.5%/97.5% quantile differences) and the warning
%         diagnostics (ensemble-time R-hat, tail and bulk ESS) of every
%         completed pair of every cell and level, one row per parameter, with
%         HealthNote: an undefined or degenerate R-hat, a tail ESS of 0
%         (study.diagnostic_notes; certification is unchanged).
%   DONE (logical, one per grid cell) marks the cells that have run; the
%   others are unavailable, with the reason "not run in this campaign". A
%   run's own campaign selects certified
%   providers only: the healthy non-certified fallbacks in
%   thesis_results/ come from the recovery of the incomplete thesis campaign.
%   Nothing is recomputed: rows copy the saved records. Files carry no
%   hashes.
%   Side effects: writes the files above, replacing earlier versions.

    root = cfg.paths.inversionResults;
    n = preparation.grid.cellCount;
    statuses = cell(n, 1);
    draws = {};
    pairs = {};
    for k = 1:n
        cellRecord = preparation.cellRecords(k);
        if ~done(k)
            statuses{k} = status_row(cellRecord, struct([]), "");
            continue;
        end
        entry = inversion.grid_campaign_support('cell_entry', cfg, cellRecord);
        mine = {};
        for level = reshape(double(cfg.mcmc.levels), 1, [])
            paths = inversion.posterior_artifact_paths(cfg, cellRecord, 'AIES', 1, level);
            if isfile(paths.reliabilityPath)
                mine{end+1} = pair_rows(cfg, cellRecord, level, paths.reliabilityPath); %#ok<AGROW>
            end
        end
        note = "";
        if ~isempty(mine)
            P = vertcat(mine{:});
            [~, note] = study.diagnostic_notes(P.EnsembleTimeRhat, P.EnsembleTimeTailESS, ...
                cfg.inversion.degenerateRhat, P.StepCount, P.Parameter);
        end
        pairs = [pairs, mine]; %#ok<AGROW>
        statuses{k} = status_row(cellRecord, entry, note);
        if logical(entry.certified)
            [A, status] = inversion.load_certified_posterior(cfg, cellRecord);
            assert(status.loaded, 'study:inversion:Provider', ...
                'The certified provider of %s did not load: %s', cellRecord.cellID, status.reason);
            provider = A.certification.provider;
            other = setdiff(double(cfg.mcmc.productionReplicateIDs), double(provider.replicateID));
            [B, partnerStatus] = inversion.load_posterior_artifact(cfg, cellRecord, ...
                char(provider.sampler), other, double(provider.stepCount));
            if ~partnerStatus.valid, B = []; end
            draws{end+1} = study.write_cell_draws(cfg, fullfile(root, 'draws', ...
                char(cellRecord.scenario), char(cellRecord.design)), cellRecord, A, B, ...
                partnerStatus.reason, []); %#ok<AGROW>
        end
    end
    utils.atomic_write_table(fullfile(ensure(root), ...
        'cell_status.csv'), vertcat(statuses{:}));
    index = draw_index_template();
    if ~isempty(draws), index = vertcat(draws{:}); end
    utils.atomic_write_table(fullfile(ensure(fullfile(root, 'draws')), 'index.csv'), index);
    pairTable = pair_template();
    if ~isempty(pairs), pairTable = vertcat(pairs{:}); end
    utils.atomic_write_table(fullfile(ensure(fullfile(root, 'diagnostics')), ...
        'pair_reliability_diagnostics.csv'), pairTable);
end

function T = status_row(cellRecord, entry, note)
%STATUS_ROW One cell's row of cell_status.csv (study.cell_status_columns), with its health note.
    if isempty(entry)
        status = "unavailable"; reason = "not run in this campaign";
        certified = false; sampler = ""; replicate = NaN; steps = NaN;
    else
        certified = logical(entry.certified);
        status = "unavailable";
        reason = string(entry.reason);
        if certified, status = "certified"; reason = ""; end
        sampler = string(entry.providerSampler);
        replicate = double(entry.providerReplicateID);
        steps = double(entry.providerStepCount);
    end
    if isempty(replicate), replicate = NaN; end
    if isempty(steps), steps = NaN; end
    T = table(double(cellRecord.caseID), string(cellRecord.scenario), string(cellRecord.design), ...
        status, sampler, replicate, steps, certified, reason, string(note), ...
        'VariableNames', study.cell_status_columns('inversion'));
end

function T = pair_rows(cfg, cellRecord, level, recordPath)
%PAIR_ROWS The replicate-pair evidence of one cell and level, one row per parameter.
    record = jsondecode(fileread(recordPath));
    pair = record.evidence.aiesPairReliability;
    rows = {};
    if isfield(pair, 'posteriorReproducibility') && isfield(pair, 'ensembleTimeDiagnostics')
        dist = pair.posteriorReproducibility;
        support = pair.ensembleTimeDiagnostics;
        names = cellstr(string(dist.parameterNames));
        for j = 1:numel(names)
            row = table(string(cellRecord.cellID), double(cellRecord.caseID), ...
                string(cellRecord.scenario), string(cellRecord.design), "", level, "rerun", ...
                string(record.status), double(logical(record.certified)), ...
                logical(pair.reliable), logical(pair.structuralHealthPass), string(names{j}), ...
                pick(dist.normalizedWassersteinDistance, j), double(dist.wassersteinThreshold), ...
                pick(dist.normalizedQ025Difference, j), pick(dist.normalizedQ975Difference, j), ...
                double(dist.quantileThreshold), pick(support.rankSplitRhat, j), ...
                double(support.rankSplitRhatThreshold), pick(support.tailESS, j), NaN, ...
                pick(support.bulkESS, j), double(support.bulkESSThreshold), ...
                logical(record.warningDiagnosticsAffectCertification), ...
                string(run_relative(cfg, recordPath)), study.diagnostic_notes(pick(support.rankSplitRhat, j), ...
                pick(support.tailESS, j), cfg.inversion.degenerateRhat), 'VariableNames', pair_columns());
            rows{end+1} = row; %#ok<AGROW>
        end
    else
        % A pair whose requests failed to execute has no distributions to compare.
        rows{end+1} = table(string(cellRecord.cellID), double(cellRecord.caseID), ...
            string(cellRecord.scenario), string(cellRecord.design), "", level, "rerun", ...
            string(record.status), double(logical(record.certified)), false, false, "", ...
            NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
            logical(record.warningDiagnosticsAffectCertification), ...
            string(run_relative(cfg, recordPath)), study.diagnostic_notes(NaN, NaN, cfg.inversion.degenerateRhat), ...
            'VariableNames', pair_columns());
    end
    T = vertcat(rows{:});
end

function value = pick(values, j)
    values = double(values);
    value = NaN;
    if numel(values) >= j, value = values(j); end
end

function p = run_relative(cfg, pathValue)
%RUN_RELATIVE A path inside the run folder, relative to it with '/'.
%   Both paths are canonicalized (utils.absolute_path) as the campaign code
%   canonicalizes its stage folder.
    run = utils.absolute_path(cfg.native.run);
    pathValue = utils.absolute_path(pathValue);
    assert(strncmpi(pathValue, [run filesep], numel(run) + 1), 'study:inversion:OutsideRun', ...
        '%s is not inside the run folder %s.', pathValue, run);
    p = strrep(pathValue(numel(run) + 2:end), '\', '/');
end

function folder = ensure(folder)
    if ~isfolder(folder), mkdir(folder); end
end

function T = draw_index_template()
    T = cell2table(cell(0, numel(study.cell_draws_columns())), ...
        'VariableNames', study.cell_draws_columns());
end

function names = pair_columns()
    names = {'CellID', 'CaseID', 'Scenario', 'Design', 'Condition', 'StepCount', 'Campaign', ...
        'PairStatus', 'PairCertified', 'PairReliable', 'StructuralHealthPass', 'Parameter', ...
        'NormalizedWasserstein', 'WassersteinThreshold', 'NormalizedQ025Difference', ...
        'NormalizedQ975Difference', 'QuantileThreshold', 'EnsembleTimeRhat', ...
        'RhatWarningThreshold', 'EnsembleTimeTailESS', 'EnsembleTimeBulkESSRecordedV1', ...
        'EnsembleTimeBulkESSCorrected', 'BulkESSWarningThreshold', ...
        'WarningDiagnosticsAffectCertification', 'ReliabilityRecord', 'HealthNote'};
end

function T = pair_template()
    T = cell2table(cell(0, numel(pair_columns())), 'VariableNames', pair_columns());
end
