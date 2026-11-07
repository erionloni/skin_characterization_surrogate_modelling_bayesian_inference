function index = write_confirmation_draws(root, target, prefix)
%WRITE_CONFIRMATION_DRAWS The full draws of every cell of a finished confirmation campaign that has a provider.
%   INDEX = study.write_confirmation_draws(ROOT, TARGET, PREFIX) reads the
%   finished confirmation campaign in ROOT
%   (confirmation.finalize_confirmation_campaign) and writes, for every cell
%   with a provider, TARGET/<protocol>/<design>/case_<CaseID>.mat (the
%   campaign's one scenario is recorded in the file and the index, not as a
%   folder, so that no file lies more than six folders below the results
%   root; a campaign with more than one scenario is refused): every
%   retained draw of both replicates of the provider's level at full
%   precision (study.write_cell_draws; the format of
%   thesis_results/fixed/04_inversion/data/draws),
%   and TARGET/index.csv, one row per file (study.cell_draws_columns).
%   The providers are those the campaign recorded, not selected again:
%     certified cells    certification/aies_certification_index.csv and the
%                        cell's certification pointer;
%     healthy fallbacks  the cells that were not certified and have a
%                        healthy completed fallback (summaries/
%                        confirmation_cell_status.csv, provider kind
%                        healthy_completed_fallback).
%   Cells without a provider have no file. The files record the campaign
%   files they come from as PREFIX/<path below ROOT>.
%   PROVIDERS = study.write_confirmation_draws(ROOT) writes nothing and
%   returns the cells with a provider (ConfirmationCellIndex, Protocol,
%   CellID, Kind, ReplicateID, StepCount), after checking that the
%   provider's posterior file is in ROOT.
%   Errors (study:confirmation:*) name the first cell that fails a check.
%   Side effects: writes TARGET, replacing earlier files.

    configuration = jsondecode(fileread(fullfile(root, 'configuration', ...
        'confirmation_configuration.json')));
    levels = double(configuration.aies_policy.levels(:).');
    replicateIDs = double(configuration.aies_policy.productionReplicateIDs(:).');
    grid = utils.read_csv_table(fullfile(root, 'cell_grid', 'confirmation_cell_grid.csv'), ...
        {'Protocol', 'ProtocolRole', 'InverseArtifactCellID', 'Scenario', 'Design'});
    scenarios = unique(string(grid.Scenario));
    must(isscalar(scenarios), 'DrawsScenario', ['The confirmation campaign %s has the scenarios %s; its ' ...
        'draws are written per protocol and design, for one scenario.'], root, strjoin(scenarios, ', '));
    certification = utils.read_csv_table(fullfile(root, 'certification', ...
        'aies_certification_index.csv'), {'Protocol', 'ProtocolRole', 'State', 'ProviderSampler'});
    fallbacks = fallback_providers(root);
    providers = table('Size', [0 6], 'VariableTypes', ...
        {'double', 'string', 'string', 'string', 'double', 'double'}, 'VariableNames', ...
        {'ConfirmationCellIndex', 'Protocol', 'CellID', 'Kind', 'ReplicateID', 'StepCount'});
    writing = nargin > 1;
    if writing
        sourceName = @(p) [prefix '/' below(p, root)];
    end
    rows = {};
    for i = 1:height(grid)
        g = grid(i, :);
        c = certification(certification.ConfirmationCellIndex == g.ConfirmationCellIndex, :);
        f = fallbacks(fallbacks.ConfirmationCellIndex == g.ConfirmationCellIndex, :);
        must(height(c) == 1, 'DrawsCertification', ...
            'Cell %d has %d rows in the certification index of %s.', ...
            g.ConfirmationCellIndex, height(c), root);
        if logical(c.Certified)
            kind = "certified"; sampler = c.ProviderSampler;
            replicateID = c.ProviderReplicateID; steps = c.ProviderStepCount;
        elseif height(f) == 1
            kind = "healthy_completed_fallback"; sampler = f.CertifiedSampler;
            replicateID = f.CertifiedReplicate; steps = f.CertifiedStepCount;
        else
            continue;
        end
        cellRecord = cell_record(g);
        cfg = struct('paths', struct('stage04', fullfile(root, 'aies', char(g.Protocol))), ...
            'mcmc', struct('levels', levels));
        paths = inversion.posterior_artifact_paths(cfg, cellRecord, char(sampler), replicateID, steps);
        must(isfile(paths.posteriorPath), 'DrawsMissing', ...
            ['The posterior of the provider of cell %d (%s) is not in %s: the campaign ' ...
             'folder must hold its request trees (aies/).'], g.ConfirmationCellIndex, ...
            cellRecord.cellID, root);
        providers(end+1, :) = {g.ConfirmationCellIndex, g.Protocol, string(cellRecord.cellID), ...
            kind, replicateID, steps}; %#ok<AGROW>
        if ~writing, continue; end

        if kind == "certified"
            [provider, status] = inversion.load_certified_posterior(cfg, cellRecord);
            must(status.loaded && double(provider.certification.provider.replicateID) ...
                == replicateID && double(provider.certification.provider.stepCount) == steps, ...
                'DrawsProvider', ['The certified provider of cell %d (%s) is not the one the ' ...
                'certification index records. %s'], g.ConfirmationCellIndex, cellRecord.cellID, ...
                status.reason);
        else
            [provider, status] = inversion.load_posterior_artifact(cfg, cellRecord, ...
                char(sampler), replicateID, steps);
            must(status.valid, 'DrawsProvider', ['The fallback provider of cell %d (%s), ' ...
                'recorded as its healthy fallback, has no complete posterior. %s'], ...
                g.ConfirmationCellIndex, cellRecord.cellID, status.reason);
            provider.truth = provider.truthMetadata.truth;
            provider.observation = provider.observationMetadata.observation;
            provider.providerEvidence = struct('sampler', char(sampler), ...
                'replicateID', replicateID, 'stepCount', steps);
        end
        other = setdiff(replicateIDs, replicateID);
        [partner, partnerStatus] = inversion.load_posterior_artifact(cfg, cellRecord, ...
            char(sampler), other(1), steps);
        reason = '';
        if ~partnerStatus.valid
            partner = [];
            reason = sprintf('replicate %d has no complete posterior at %d steps (%s)', ...
                other(1), steps, partnerStatus.state);
        end
        rows{end+1} = study.write_cell_draws([], fullfile(target, char(g.Protocol), ...
            char(cellRecord.design)), cellRecord, provider, ...
            partner, reason, [], sourceName); %#ok<AGROW>
    end
    if ~writing
        index = providers;
        return;
    end
    index = cell2table(cell(0, numel(study.cell_draws_columns())), ...
        'VariableNames', study.cell_draws_columns());
    if ~isempty(rows), index = vertcat(rows{:}); end
    if ~isfolder(target), mkdir(target); end
    utils.atomic_write_table(fullfile(target, 'index.csv'), index);
end

function F = fallback_providers(root)
%FALLBACK_PROVIDERS The healthy fallbacks of the campaign (none when every cell is certified).
%   From the cell status of every observation design: summaries/ and, for the
%   descriptive design of the complete pairs, summaries/complete_pairs/.
    F = table('Size', [0 4], 'VariableTypes', {'double', 'string', 'double', 'double'}, ...
        'VariableNames', {'ConfirmationCellIndex', 'CertifiedSampler', ...
        'CertifiedReplicate', 'CertifiedStepCount'});
    files = {fullfile(root, 'summaries', 'confirmation_cell_status.csv'), ...
        fullfile(root, 'summaries', 'complete_pairs', 'confirmation_cell_status.csv')};
    for k = 1:numel(files)
        if k > 1 && ~isfile(files{k}), continue; end
        status = utils.read_csv_table(files{k}, {'CertifiedSampler', 'ProviderKind'});
        status = status(status.ProviderKind == "healthy_completed_fallback", :);
        F = [F; status(:, F.Properties.VariableNames)]; %#ok<AGROW>
    end
end

function cellRecord = cell_record(g)
%CELL_RECORD The inversion cell of one confirmation cell (its posterior folder).
    token = regexp(char(g.InverseArtifactCellID), '^case_(\d+)\|', 'tokens', 'once');
    must(~isempty(token), 'DrawsCell', 'Unexpected inverse cell identity %s.', ...
        char(g.InverseArtifactCellID));
    cellRecord = struct('cellID', char(g.InverseArtifactCellID), 'caseID', str2double(token{1}), ...
        'scenario', char(g.Scenario), 'design', char(g.Design));
end

function p = below(pathValue, root)
%BELOW A path inside ROOT, relative to it with '/'.
    root = utils.absolute_path(root);
    pathValue = utils.absolute_path(pathValue);
    must(strncmpi(pathValue, [root filesep], numel(root) + 1), 'DrawsSource', ...
        '%s is not inside the campaign folder %s.', pathValue, root);
    p = strrep(pathValue(numel(root) + 2:end), '\', '/');
end

function must(condition, id, varargin)
    if ~condition
        error(['study:confirmation:' id], varargin{:});
    end
end
