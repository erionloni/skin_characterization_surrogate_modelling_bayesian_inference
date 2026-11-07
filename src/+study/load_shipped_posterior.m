function [A, status] = load_shipped_posterior(cfg, record, varargin)
%LOAD_SHIPPED_POSTERIOR Posterior draws of one inversion cell, from the shipped full draws.
%   [A, STATUS] = study.load_shipped_posterior(CFG, RECORD) returns the
%   selected provider of one inversion cell from the shipped draws: what
%   recovery.load_posterior_provider returns in reproduce mode, and in a
%   rerun of recovery or the design study that uses the shipped draws.
%   RECORD names the cell (caseID, scenario, design,
%   and conditionCode for a conditional cell). The provider is the one the
%   thesis campaign selected (the campaign's status table,
%   thesis_results/fixed/<04|07|09>/data/cell_status.csv; 09 for the scenario
%   gp_mean_det of the GP-mean inversion); the draws are in
%   thesis_results/fixed/<04|07|09>/data/
%   draws/, in the file that draws/index.csv names for
%   the cell: every retained draw of both replicates at the provider's
%   level, at full precision (schema shipped_posterior_draws_v2, or v3,
%   which adds the log-likelihood of every retained draw;
%   study.write_cell_draws).
%   [A, STATUS] = study.load_shipped_posterior(CFG, RECORD, SAMPLER,
%   REPLICATE, LEVEL) returns one replicate of the cell at LEVEL steps, as
%   inversion.load_posterior_artifact does for a run's own campaign (the
%   paired geometry of the eigendecomposition reads replicate 2).
%   The results folder comes from CFG.layout in reproduce mode and from
%   CFG.native.shippedDraws in a rerun.
%
%   Every selected provider is loaded, certified or a healthy fallback
%   (STATUS.certified says which), except in a rerun with
%   CFG.native.shippedDraws.certifiedOnly (the design study's summary of the
%   certified cells alone), which loads certified providers only. Nothing is
%   re-certified, pooled or promoted.
%
%   A holds the fields of a run's own posterior record that the analyses and
%   renderers use: drawsPhysical (draws x 4, model coordinates: m3_f_RD,
%   m3_e_RD, log10(k0_RD), Thickness_RD), sampleArray (retained iteration x
%   parameter x walker), parameterNames, bounds, truth, observation, health,
%   request, logLikelihood and logLikelihoodSource (schema v3: the
%   log-likelihood of every retained draw, row by row with drawsPhysical, and
%   'sampler' or 'evaluated'; empty for v2), samplesPooled (false),
%   certification (for the provider
%   of a certified cell the certification pointer as
%   inversion.load_certified_posterior returns it; for a healthy fallback
%   certified false, certificationMechanism
%   NONCERTIFIED_HEALTHY_COMPLETED_REQUEST, the provider and its state; for
%   one replicate the provider and its state), paths.posteriorPath,
%   certificationPath, and shipped (the
%   replicates in the file, the draw count, the source of the draws).
%   Conditional cells add drawsFree and the free/fixed parameter indices.
%   STATUS has the fields of recovery.load_posterior_provider; a replicate
%   that loaded has state 'complete_reusable', as for a run's own campaign.
%   Side effects: none.

    A = struct([]);
    status = struct('state', 'unavailable', 'loaded', false, 'valid', false, ...
        'certified', false, 'reason', '', 'errorIdentifier', '', 'cellID', '', ...
        'providerAvailable', false);
    conditional = is_conditional(cfg, record);
    % A cell of the GP-mean inversion (scenario gp_mean_det): its draws are
    % those of fixed/09_gp_mean_inversion.
    gpMean = strcmp(char(string(record.scenario)), 'gp_mean_det');
    [results, certifiedOnly] = draw_source(cfg, conditional || gpMean);
    campaign = fullfile(results, 'fixed', '04_inversion', 'data');
    if conditional
        campaign = fullfile(results, 'fixed', '07_conditional_inversion', 'data');
    elseif gpMean
        campaign = fullfile(results, 'fixed', '09_gp_mean_inversion', 'data');
    end
    folder = fullfile(campaign, 'draws');
    evidence = fullfile(campaign, 'cell_status.csv');
    index = read_index(fullfile(folder, 'index.csv'));
    hit = index.CaseID == double(record.caseID) & index.Scenario == string(record.scenario) & ...
        index.Design == string(record.design);
    if conditional && isfield(record, 'conditionID') && ~isempty(record.conditionID)
        % By the condition's id (its fixed parameters), so that a renamed label finds its cells.
        hit = hit & endsWith(index.CellID, "|condition_" + string(record.conditionID));
    elseif conditional
        hit = hit & index.ConditionCode == string(record.conditionCode);
    else
        hit = hit & index.ConditionCode == "";
    end
    if ~any(hit)
        status.reason = unavailable_reason(evidence, record, conditional);
        return;
    end
    assert(nnz(hit) == 1, 'study:load_shipped_posterior:Multiplicity', ...
        'More than one shipped provider for case %d %s %s.', record.caseID, ...
        record.scenario, record.design);
    row = index(hit, :);
    status.cellID = char(row.CellID);
    status.providerAvailable = true;
    status.state = char(row.State);
    status.certified = logical(row.Certified);
    if ~row.Certified && certifiedOnly
        status.reason = 'noncertified_provider_excluded_from_certified_only_summary';
        return;
    end
    % Read from the fixed location the index names (no hash check).
    file = fullfile(folder, strrep(char(row.File), '/', filesep));
    assert(isfile(file), 'study:load_shipped_posterior:FileMissing', ...
        'Shipped posterior draws missing: %s', file);
    S = load(file, 'draws');
    D = S.draws;
    assert(ismember(D.schemaVersion, {'shipped_posterior_draws_v2', 'shipped_posterior_draws_v3'}), ...
        'study:load_shipped_posterior:Schema', ...
        'The draws in %s have schema %s; this code reads shipped_posterior_draws_v2 and v3.', ...
        file, D.schemaVersion);
    replicateIDs = [D.replicates.replicateID];
    if isempty(varargin)
        k = find(replicateIDs == D.providerReplicateID);
    else
        [sampler, replicate, level] = varargin{:};
        k = find(replicateIDs == double(replicate));
        if ~strcmpi(char(string(sampler)), D.sampler) || double(level) ~= D.stepCount || isempty(k)
            status.state = 'missing';
            status.reason = sprintf(['%s replicate %d at %d steps is not in the shipped ' ...
                'draws of %s (they hold %s replicate(s) %s at %d steps%s).'], ...
                char(string(sampler)), double(replicate), double(level), D.cellID, D.sampler, ...
                strjoin(string(replicateIDs), ' and '), D.stepCount, missing_note(D));
            return;
        end
    end
    R = D.replicates(k);
    A = struct();
    A.drawsPhysical = R.drawsPhysical;
    P = size(R.drawsPhysical, 2);
    % Rows are the retained sample array flattened walker by walker.
    A.sampleArray = permute(reshape(R.drawsPhysical, R.retainedIterations, R.walkers, P), [1 3 2]);
    A.parameterNames = D.parameterNames;
    A.bounds = D.bounds;
    A.truth = D.truth;
    A.observation = D.observation;
    A.health = R.health;
    A.request = R.request;
    % Schema v3: the log-likelihood of every retained draw and its source; empty for v2.
    A.logLikelihood = zeros(0, 1);
    A.logLikelihoodSource = '';
    if isfield(R, 'logLikelihood')
        A.logLikelihood = R.logLikelihood;
        A.logLikelihoodSource = D.logLikelihoodSource;
    end
    A.samplesPooled = false;
    if isempty(varargin) && D.certified
        % The certification pointer, as a run's own campaign gives it.
        A.certification = D.certification;
    elseif isempty(varargin)
        % A healthy fallback: its provider, not certified, recorded as the
        % thesis's analysis of the combined cells recorded it (mechanism
        % NONCERTIFIED_HEALTHY_COMPLETED_REQUEST; recovery.posterior_provider_provenance).
        A.certification = struct('certified', false, ...
            'certificationMechanism', 'NONCERTIFIED_HEALTHY_COMPLETED_REQUEST', ...
            'provider', struct('sampler', D.sampler, 'replicateID', R.replicateID, ...
            'stepCount', D.stepCount, 'samplesPooled', false), 'state', D.state);
    else
        A.certification = struct('provider', struct('sampler', D.sampler, ...
            'replicateID', R.replicateID, 'stepCount', D.stepCount), 'state', D.state);
    end
    A.paths = struct('posteriorPath', file);
    A.certificationPath = evidence;
    A.shipped = struct('replicateIDs', replicateIDs, 'drawCount', size(R.drawsPhysical, 1), ...
        'source', R.source);
    if conditional
        A.drawsFree = R.drawsFree;
        A.freeParameterIndices = D.freeParameterIndices;
        A.fixedParameterIndices = D.fixedParameterIndices;
        A.freeParameterNames = D.freeParameterNames;
        A.parameterRoles = D.parameterRoles;
        A.condition = D.condition;
    end
    status.loaded = true;
    status.valid = true;
    status.reason = '';
    if ~isempty(varargin), status.state = 'complete_reusable'; end
end

function tf = is_conditional(cfg, record)
%IS_CONDITIONAL True for a cell of the conditional inversion that is not its reference (the canonical all_six cell).
%   The reference is the condition that fixes nothing: id baseline, or the
%   reference label of the settings (A.9) when the record names no id.
    tf = isfield(record, 'conditionCode') && ~isempty(record.conditionCode);
    if ~tf, return; end
    if isfield(record, 'conditionID') && ~isempty(record.conditionID)
        tf = ~strcmp(char(string(record.conditionID)), 'baseline');
    else
        tf = ~strcmp(char(string(record.conditionCode)), cfg.conditionalInversion.referenceCode);
    end
end

function [results, certifiedOnly] = draw_source(cfg, own)
%DRAW_SOURCE The results folder of the shipped draws, and whether only certified providers load.
%   Reproduce mode: CFG.layout, every provider; the canonical cells of a
%   rerun's conditional inversion that took them from the shipped results,
%   of a rerun's ratio-error curves computed on the shipped draws and of a
%   rerun's GP-mean inversion: CFG.layout.canonicalResults (study.reproduce);
%   the cells of the analysis itself (OWN: a conditional or GP-mean cell)
%   are those of CFG.layout.results. A rerun that uses the shipped draws:
%   CFG.native.shippedDraws (study.native_config).
    if study.is_publication(cfg)
        results = cfg.layout.results;
        if ~own && isfield(cfg.layout, 'canonicalResults') && ~isempty(cfg.layout.canonicalResults)
            results = cfg.layout.canonicalResults;
        end
        certifiedOnly = false;
    else
        results = cfg.native.shippedDraws.results;
        certifiedOnly = cfg.native.shippedDraws.certifiedOnly;
    end
end

function note = missing_note(D)
    note = '';
    if ~isempty(D.missingReplicateReason)
        note = sprintf('; %s', D.missingReplicateReason);
    end
end

function T = read_index(pathValue)
    persistent cache
    if isempty(cache), cache = containers.Map('KeyType', 'char', 'ValueType', 'any'); end
    info = dir(pathValue);
    assert(isscalar(info), 'study:load_shipped_posterior:IndexMissing', ...
        'The shipped posterior draws have no index: %s', pathValue);
    key = sprintf('%s|%s|%d', pathValue, info.date, info.bytes);
    if isKey(cache, key), T = cache(key); return; end
    T = utils.read_csv_table(pathValue, {'CellID', 'Scenario', 'Design', 'ConditionCode', ...
        'State', 'ReplicateIDs', 'File', 'ProviderSource', 'PartnerSource', ...
        'MissingReplicateReason'});
    cache(key) = T;
end

function reason = unavailable_reason(evidence, record, conditional)
%UNAVAILABLE_REASON The recorded reason why a canonical cell has no provider (its status table).
    reason = 'provider_not_shipped';
    if conditional || ~isfile(evidence), return; end
    T = utils.read_csv_table(evidence, {'Scenario', 'Design', 'Status', 'Reason'});
    hit = T.CaseID == double(record.caseID) & T.Scenario == string(record.scenario) & ...
        T.Design == string(record.design);
    if nnz(hit) == 1 && ~ismember(T.Status(hit), ["certified", "healthy fallback"])
        reason = char(T.Reason(hit));
    end
end
