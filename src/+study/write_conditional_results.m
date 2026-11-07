function write_conditional_results(cfg, preparation)
%WRITE_CONDITIONAL_RESULTS The conditional inversion results of a run, in the layout of thesis_results/.
%   study.write_conditional_results(CFG, PREPARATION) reads the finalized
%   conditional campaign of this run (below CFG.paths.conditionalInversion)
%   and writes to CFG.paths.conditionalResults
%   (<run>/fixed/07_conditional_inversion/data):
%     cell_status.csv
%         the campaign's status table (study.cell_status_columns
%         'conditional'): every scheduled cell and the canonical reference
%         of each case and scenario (condition baseline), in the order of
%         the campaign's availability report, with its status (certified,
%         healthy fallback or unavailable), provider, whether it counts in
%         the certified-only values and the reason it is not certified. The
%         rows of shipped cells (reused cells, and the references when the
%         canonical cells are the shipped ones) are those of the shipped
%         status tables; a cell this campaign ran or skipped is described
%         from the availability report.
%     reports/  the campaign's comparison, matched-cohort and matched-summary
%         tables, as the campaign wrote them (conditional_inversion_*.csv)
%     seeds/seed_record.csv
%         the campaign's seed record: the seed of every request of its
%         conditional cells (each cell, replicate and level; a request runs
%         only when its level is reached), in the columns of the frozen
%         record config/seeds/mcmc_seeds.csv, with SeedSource 'recorded' (a
%         request of the thesis, whose seed that record holds) or 'rule'
%         (the seed rule of the settings: a new condition or case), from the
%         campaign's seed schedule (inversion.conditional_seed_schedule). The
%         frozen record is never written.
%     draws/index.csv and <scenario>/<condition>/case_<id>.mat
%         for each cell with a posterior every retained draw of both
%         replicates of the provider's level, in the format of thesis_results/
%         (study.write_cell_draws): drawsPhysical holds
%         the four model coordinates with the fixed ones at the truth,
%         drawsFree the inferred coordinates only. A reused cell's file is
%         copied from the shipped draws. The index lists the cells by
%         scenario (the campaign's order), condition (the table's order) and
%         CaseID.
%   The canonical reference's draws are the inversion's
%   (study.write_inversion_results). A cell the run's own campaign ran has
%   its certified provider or, when it was not certified, its healthy
%   completed fallback (inversion.load_conditional_available_posterior: the
%   rule of the thesis's cells).
%   Nothing is recomputed; files carry no hashes.
%   Side effects: writes the files above, replacing earlier versions.

    root = cfg.paths.conditionalResults;
    reports = ensure(fullfile(root, 'reports'));
    sources = {cfg.files.conditionalComparison, cfg.files.conditionalAvailability, ...
        cfg.files.conditionalMatchedCohorts, cfg.files.conditionalMatchedSummary};
    for i = 1:numel(sources)
        assert(isfile(sources{i}), 'study:conditional:Report', ...
            'The finalized conditional campaign lacks %s.', sources{i});
    end
    for i = [1 3 4]
        [~, name, ext] = fileparts(sources{i});
        copyfile(sources{i}, fullfile(reports, [name ext]), 'f');
    end
    utils.atomic_write_table(fullfile(root, 'cell_status.csv'), ...
        status_table(cfg, preparation, cfg.files.conditionalAvailability));
    utils.atomic_write_table(fullfile(ensure(fullfile(root, 'seeds')), 'seed_record.csv'), ...
        seed_record(preparation));
    rows = {};
    for k = 1:numel(preparation.tasks)
        cellRecord = preparation.tasks(k).cellRecord;
        condition = inversion.conditional_inversion_conditions(cfg, cellRecord.conditionCode);
        [A, status] = inversion.load_conditional_available_posterior(cfg, cellRecord);
        if ~status.loaded, continue; end
        provider = A.certification.provider;
        other = setdiff(double(cfg.mcmc.productionReplicateIDs), double(provider.replicateID));
        [B, partnerStatus] = inversion.load_conditional_posterior_artifact(cfg, cellRecord, ...
            char(provider.sampler), other, double(provider.stepCount));
        if ~partnerStatus.valid, B = []; end
        if ~status.certified
            % A healthy fallback: its provider evidence, no certification.
            A = rmfield(A, 'certification');
        end
        rows{end+1} = study.write_cell_draws(cfg, fullfile(root, 'draws', ...
            char(cellRecord.scenario), char(condition.tag)), cellRecord, A, B, ...
            partnerStatus.reason, condition); %#ok<AGROW>
    end
    reused = reused_draws(cfg, preparation, fullfile(root, 'draws'));
    if ~isempty(reused), rows{end+1} = reused; end
    columns = study.cell_draws_columns();
    index = cell2table(cell(0, numel(columns)), 'VariableNames', columns);
    if ~isempty(rows), index = sort_index(cfg, vertcat(rows{:})); end
    utils.atomic_write_table(fullfile(ensure(fullfile(root, 'draws')), 'index.csv'), index);
end

function T = seed_record(preparation)
%SEED_RECORD The seed of every request of the campaign's conditional cells, with its source.
    r = preparation.seedSchedule.records;
    r = r(strcmp({r.scope}, 'conditional'));
    T = table(repmat("conditional", numel(r), 1), string({r.cellID}).', ...
        string({r.conditionTag}).', [r.caseID].', string({r.scenario}).', ...
        string({r.design}).', string({r.sampler}).', [r.replicateID].', [r.stepCount].', ...
        [r.seed].', string({r.source}).', 'VariableNames', {'Campaign', 'CellID', ...
        'ConditionTag', 'CaseID', 'Scenario', 'Design', 'Sampler', 'Replicate', 'StepCount', ...
        'Seed', 'SeedSource'});
end

function S = status_table(cfg, preparation, availabilityFile)
%STATUS_TABLE The status table of the campaign's scheduled cells, in the order of its availability report.
    A = utils.read_csv_table(availabilityFile, {'Scenario', 'Design', 'ConditionCode', ...
        'ConditionID', 'CertificationStatus', 'FailureReason', 'CertifiedSampler', ...
        'CertificationMechanism'});
    A = A(logical(A.Scheduled), :);
    % The status from the provider that loaded and its certification (the
    % loaders' own state names differ: certified_loaded, complete_reusable).
    loaded = logical(A.ArtifactLoaded);
    status = repmat("unavailable", height(A), 1);
    status(loaded) = "healthy fallback";
    status(loaded & A.CertificationMechanism == "CERTIFIED_AIES_REPLICATE_AGREEMENT") = "certified";
    reason = A.FailureReason;
    reason(status == "certified") = "";
    S = table(double(A.CaseID), A.Scenario, A.Design, A.ConditionID, status, ...
        A.CertifiedSampler, double(A.CertifiedReplicate), double(A.CertifiedStepCount), ...
        logical(A.InCertifiedOnlyValues), reason, ...
        'VariableNames', study.cell_status_columns('conditional'));
    [canonical, conditional] = shipped_status(cfg, preparation);
    actions = preparation.actions;
    for i = 1:height(S)
        shippedRow = [];
        if logical(A.CanonicalReference(i)) && ~isempty(canonical)
            shippedRow = canonical(canonical.CaseID == S.CaseID(i) & ...
                canonical.Scenario == S.Scenario(i) & canonical.Design == S.Design(i), :);
            shippedRow = addvars(shippedRow, S.Condition(i), 'After', 'Design', ...
                'NewVariableNames', 'Condition');
        elseif ~logical(A.CanonicalReference(i))
            action = actions(strcmp({actions.cellID}, char(A.CellID(i))));
            if isscalar(action) && strcmp(action.action, 'reuse')
                shippedRow = conditional(conditional.CaseID == S.CaseID(i) & ...
                    conditional.Scenario == S.Scenario(i) & conditional.Design == S.Design(i) & ...
                    conditional.Condition == S.Condition(i), :);
                assert(height(shippedRow) == 1, 'study:conditional:ShippedStatus', ...
                    'The shipped status table does not list the reused cell %s once.', A.CellID(i));
            end
        end
        if ~isempty(shippedRow)
            assert(height(shippedRow) == 1, 'study:conditional:ShippedStatus', ...
                'The shipped status table does not list %s once.', A.CellID(i));
            % The columns of this table: the inversion's table also has HealthNote.
            S(i, :) = shippedRow(:, S.Properties.VariableNames);
        end
    end
end

function [canonical, conditional] = shipped_status(cfg, preparation)
%SHIPPED_STATUS The shipped status tables whose rows the run's table takes: canonical (shipped baseline), conditional (reused cells).
    canonical = []; conditional = [];
    textColumns = {'Scenario', 'Design', 'Condition', 'Status', 'ProviderSampler', 'Reason'};
    if strcmp(preparation.canonicalBarrier.source, 'shipped')
        canonical = utils.read_csv_table(fullfile(cfg.native.shippedDraws.results, 'fixed', ...
            '04_inversion', 'data', 'cell_status.csv'), textColumns);
    end
    if any(strcmp({preparation.actions.action}, 'reuse'))
        conditional = utils.read_csv_table(fullfile(cfg.native.shippedDraws.results, 'fixed', ...
            '07_conditional_inversion', 'data', 'cell_status.csv'), textColumns);
    end
end

function index = reused_draws(cfg, preparation, folder)
%REUSED_DRAWS The draw files of the reused cells, copied from the shipped draws, and their index rows ([] for none).
    index = [];
    reused = preparation.actions(strcmp({preparation.actions.action}, 'reuse'));
    if isempty(reused), return; end
    source = fullfile(cfg.native.shippedDraws.results, 'fixed', '07_conditional_inversion', ...
        'data', 'draws');
    shipped = utils.read_csv_table(fullfile(source, 'index.csv'), {'CellID', 'Scenario', ...
        'Design', 'ConditionCode', 'State', 'ReplicateIDs', 'File', 'ProviderSource', ...
        'PartnerSource', 'MissingReplicateReason'});
    parts = {};
    for k = 1:numel(reused)
        row = shipped(shipped.CellID == string(reused(k).cellID), :);
        if isempty(row), continue; end
        assert(height(row) == 1, 'study:conditional:ShippedDraws', ...
            'The shipped draw index lists the cell %s more than once.', reused(k).cellID);
        file = fullfile(folder, strrep(char(row.File), '/', filesep));
        ensure(fileparts(file));
        copyfile(fullfile(source, strrep(char(row.File), '/', filesep)), file, 'f');
        row.ConditionCode(:) = string(reused(k).conditionCode);
        parts{end+1} = row; %#ok<AGROW>
    end
    if ~isempty(parts), index = vertcat(parts{:}); end
end

function index = sort_index(cfg, index)
%SORT_INDEX The draw index by scenario (the campaign's order), condition (the table's order) and CaseID.
    if isempty(index), return; end
    conditions = inversion.conditional_inversion_conditions(cfg);
    reference = conditions([conditions.canonicalReference]);
    [~, scenarioRank] = ismember(string(index.Scenario), string(reference.scheduledScenarios));
    [~, conditionRank] = ismember(string(index.ConditionCode), string({conditions.code}));
    [~, order] = sortrows([scenarioRank, conditionRank, double(index.CaseID)]);
    index = index(order, :);
end

function folder = ensure(folder)
    if ~isfolder(folder), mkdir(folder); end
end
