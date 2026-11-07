function [T, sources] = confirmation_result_tables(cfg, role)
%CONFIRMATION_RESULT_TABLES The comparison tables of a compared confirmation campaign.
%   [T, SOURCES] = plotting.confirmation_result_tables(CFG) reads the saved
%   results of the confirmation (generalized/06_confirmation/data: the status
%   table, the campaign's compact tier and the draws) and returns, for the
%   comparisons of each focused protocol with the default (one shared
%   default cell per material) in the confirmation's observation design
%   (T.design; settings B.7 design), on the matched cohort of each comparison
%   (the materials whose two cells have a posterior, certified or healthy
%   fallback; the certified-only values over the materials whose two cells
%   are certified):
%     T.sdRatios        per matched material, focused protocol and material
%                       parameter: the posterior SD over the prior SD under
%                       the protocol and under the default, their ratio (1 is
%                       no change), whether the parameter is a target of the
%                       protocol's objective, the replicate discrepancy of
%                       both cells (the normalized Wasserstein distance
%                       between the two replicates at the provider's level,
%                       inversion.posterior_reproducibility, and the relative
%                       difference of their posterior SDs; NaN for a cell with
%                       one replicate), the status of both cells and both
%                       recovery errors (|posterior median - truth| over the
%                       prior width);
%     T.sdRatioSummary  per focused protocol and target parameter: the matched
%                       materials, the fraction with a smaller SD than under
%                       the default, the median and quartiles of the SD ratio
%                       and the median replicate SD difference (the larger of
%                       the two cells), each followed by its certified-only
%                       value;
%     T.objectiveSummary per focused protocol and objective of the screen (the
%                       six, the protocol's own marked): the matched materials,
%                       the fraction improved (the six-objective comparison's
%                       Improved), the median and quartiles of the ratio of the
%                       posterior objective under the protocol to that under
%                       the default, with certified-only values;
%     T.fimAgreement    per focused protocol and objective: the pairs with both
%                       posteriors and a valid FIM proxy, the fraction whose
%                       FIM-predicted and posterior change have the same sign
%                       and the Spearman rank correlation of the two changes,
%                       with certified-only values;
%     T.recoveryError   per protocol (the default first) and material
%                       parameter, on the common cohort (the materials whose
%                       four cells have a posterior): the materials and the
%                       median and quartiles of the recovery error, with
%                       certified-only values (the four cells certified);
%     T.showcase        the showcase material of the setting
%                       generalized.confirmation.showcase ('first_all_certified':
%                       the first material of the design whose four cells
%                       are certified; NaN when none is), and T.parameterNames.
%   The target parameters of an objective are those of its covariance formula
%   (screening.objective_registry). SOURCES are the files read.
%   [T, SOURCES] = plotting.confirmation_result_tables(CFG, 'complete_pairs')
%   returns the same T.sdRatios, T.sdRatioSummary and T.objectiveSummary for
%   the descriptive design of the complete pairs (settings B.7
%   completePairsDesign: the pairs whose two rows have all its pressures;
%   their summaries in summaries/complete_pairs/), each with the column Note
%   that says what these pairs are; T is [] when the campaign has no such
%   design. ('primary' is the default.)
%   Side effects: none. Computation: reads the draws of the matched cells
%   (seconds to a minute).

    if nargin < 2, role = 'primary'; end
    root = study.source_folder(cfg, 'confirmation');
    campaign = fullfile(root, 'campaign');
    configurationFile = fullfile(campaign, 'configuration', 'confirmation_configuration.json');
    assert(isfile(configurationFile), 'plotting:confirmation_result_tables:Sources', ...
        'The compared confirmation lacks: %s.', configurationFile);
    configuration = jsondecode(fileread(configurationFile));
    design = char(string(configuration.design));
    summaries = 'summaries';
    if strcmp(role, 'complete_pairs')
        design = '';
        if isfield(configuration, 'complete_pairs_design')
            design = char(string(configuration.complete_pairs_design));
        end
        if isempty(design), T = []; sources = {}; return; end
        summaries = fullfile('summaries', 'complete_pairs');
    end
    sources = {fullfile(root, 'cell_status.csv'), ...
        fullfile(campaign, 'cell_grid', 'pairwise_comparisons.csv'), ...
        fullfile(campaign, summaries, 'posterior_parameter_summary.csv'), ...
        fullfile(campaign, summaries, 'six_objective_pairedMetrics.csv'), ...
        configurationFile, fullfile(root, 'draws', 'index.csv')};
    missing = sources(~cellfun(@isfile, sources));
    assert(isempty(missing), 'plotting:confirmation_result_tables:Sources', ...
        'The compared confirmation lacks: %s.', strjoin(missing, ', '));
    status = utils.read_csv_table(sources{1}, {'Protocol', 'ProtocolRole', 'Design', 'Status', ...
        'ProviderSampler', 'Reason'});
    status = status(status.Design == design, :);
    pairs = utils.read_csv_table(sources{2}, {'Protocol', 'ObjectiveID', 'ComparisonRole', ...
        'Design', 'DesignRole'});
    pairs = pairs(pairs.Design == design, :);
    parameters = utils.read_csv_table(sources{3}, {'Protocol', 'ProtocolRole', 'Parameter', ...
        'CertifiedSampler', 'CertificationMechanism', 'ExecutionStatus', 'FailureReason'});
    objectives = utils.read_csv_table(sources{4}, {'ComparisonRole', 'Protocol', 'ObjectiveID'});
    names = reshape(cellstr(string(configuration.parameter_names)), 1, []);
    bounds = double(configuration.prior_bounds);
    registry = screening.objective_registry();

    T.design = design;
    T.parameterNames = names;
    T.sdRatios = sd_ratios(cfg, root, status, pairs, parameters, names, bounds, registry, design);
    T.sdRatioSummary = sd_ratio_summary(T.sdRatios);
    T.objectiveSummary = objective_summary(objectives, registry);
    if strcmp(role, 'complete_pairs')
        note = sprintf(['%d pairs with all %s pressures; descriptive, not representative ' ...
            'of the protocols'], height(pairs), design_words(design));
        T.note = note;
        for field = {'sdRatios', 'sdRatioSummary', 'objectiveSummary'}
            T.(field{1}).Note = repmat(string(note), height(T.(field{1})), 1);
        end
        return;
    end
    T.fimAgreement = fim_agreement(objectives, registry);
    T.recoveryError = recovery_error(status, parameters, names, configuration);
    T.showcase = plotting.confirmation_showcase(cfg, status, configuration.materials, ...
        {configuration.protocols.Protocol});
end

function text = design_words(design)
%DESIGN_WORDS The pressures of a design in words ("six", "D2").
    switch design
        case 'all_six', text = 'six';
        case 'd2_only', text = 'D2';
        otherwise, text = design;
    end
end

function S = sd_ratios(cfg, root, status, pairs, parameters, names, bounds, registry, design)
%SD_RATIOS Per matched material, focused protocol and parameter: SD over prior SD of both cells and their replicate discrepancy.
    rows = {};
    defaultProtocol = status.Protocol(find(status.ProtocolRole == "default", 1));
    thresholds = inversion.mcmc_diagnostic_thresholds(cfg);
    discrepancy = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for protocol = reshape(unique(pairs.Protocol, 'stable'), 1, [])
        P = pairs(pairs.Protocol == protocol, :);
        objective = P.ObjectiveID(1);
        target = target_parameters(registry, objective, names);
        matched = false(height(P), 1);
        for i = 1:height(P)
            matched(i) = has_posterior(status, P.MaterialCaseID(i), defaultProtocol) && ...
                has_posterior(status, P.MaterialCaseID(i), protocol);
        end
        P = P(matched, :);
        for i = 1:height(P)
            id = P.MaterialCaseID(i);
            [ws, ds] = cell_discrepancy(discrepancy, root, design, id, protocol, bounds, thresholds);
            [wd, dd] = cell_discrepancy(discrepancy, root, design, id, defaultProtocol, bounds, ...
                thresholds);
            certified = is_certified(status, id, protocol) && is_certified(status, id, defaultProtocol);
            for p = 1:numel(names)
                x = value(parameters, id, protocol, names{p}, 'PosteriorSDOverPriorSD');
                a = value(parameters, id, defaultProtocol, names{p}, 'PosteriorSDOverPriorSD');
                rows{end+1} = table(protocol, objective, id, string(names{p}), ...
                    ismember(names{p}, target), height(P), cell_status(status, id, protocol), ...
                    cell_status(status, id, defaultProtocol), certified, x, a, x / a, ws(p), wd(p), ...
                    ds(p), dd(p), ...
                    value(parameters, id, protocol, names{p}, ...
                        'NormalizedAbsoluteRecoveryErrorFromPosteriorMedian'), ...
                    value(parameters, id, defaultProtocol, names{p}, ...
                        'NormalizedAbsoluteRecoveryErrorFromPosteriorMedian'), ...
                    'VariableNames', sd_columns()); %#ok<AGROW>
            end
        end
    end
    if isempty(rows)
        S = cell2table(cell(0, numel(sd_columns())), 'VariableNames', sd_columns());
    else
        S = vertcat(rows{:});
    end
end

function names = sd_columns()
    names = {'Protocol', 'ObjectiveID', 'MaterialCaseID', 'Parameter', 'IsTargetParameter', ...
        'MatchedMaterialCount', 'Status', 'DefaultStatus', 'InCertifiedOnlyValues', ...
        'PosteriorSDOverPriorSD', 'DefaultPosteriorSDOverPriorSD', 'SDRatioToDefault', ...
        'ReplicateWasserstein', 'DefaultReplicateWasserstein', 'ReplicateSDRelativeDifference', ...
        'DefaultReplicateSDRelativeDifference', 'RecoveryError', 'DefaultRecoveryError'};
end

function S = sd_ratio_summary(R)
%SD_RATIO_SUMMARY Per focused protocol and target parameter: N, fraction smaller, median and quartiles of the SD ratio.
    R = R(logical(R.IsTargetParameter), :);
    keys = unique(R(:, {'Protocol', 'ObjectiveID', 'Parameter'}), 'stable');
    S = utils.add_certified_only(sd_summary_rows(R, keys, false), sd_summary_rows(R, keys, true), ...
        {'Protocol', 'ObjectiveID', 'Parameter'});
end

function S = sd_summary_rows(R, keys, certifiedOnly)
    names = {'MatchedMaterialCount', 'FractionSmallerThanDefault', 'MedianSDRatioToDefault', ...
        'Q25SDRatioToDefault', 'Q75SDRatioToDefault', 'MedianReplicateSDRelativeDifference'};
    parts = cell(height(keys), 1);
    for i = 1:height(keys)
        hit = R.Protocol == keys.Protocol(i) & R.Parameter == keys.Parameter(i);
        if certifiedOnly, hit = hit & logical(R.InCertifiedOnlyValues); end
        C = R(hit, :);
        ratio = quartiles(C.SDRatioToDefault);
        spread = median(max(C.ReplicateSDRelativeDifference, ...
            C.DefaultReplicateSDRelativeDifference), 'omitnan');
        if isempty(C), spread = NaN; end
        parts{i} = [keys(i, :), table(height(C), fraction(C.SDRatioToDefault < 1, height(C)), ...
            ratio(2), ratio(1), ratio(3), spread, 'VariableNames', names)];
    end
    S = stack(parts, keys, names);
end

function S = objective_summary(O, registry)
%OBJECTIVE_SUMMARY Per focused protocol and objective: matched materials, fraction improved, the ratio's median and quartiles.
    O = O(logical(O.PairAvailable), :);
    keys = objective_keys(O, registry);
    S = utils.add_certified_only(objective_rows(O, keys, false), objective_rows(O, keys, true), ...
        {'Protocol', 'ComparisonRole', 'ObjectiveID', 'IsTargetObjective'});
end

function S = objective_rows(O, keys, certifiedOnly)
    names = {'MatchedMaterialCount', 'FractionImproved', 'MedianRatioToDefault', ...
        'Q25RatioToDefault', 'Q75RatioToDefault'};
    parts = cell(height(keys), 1);
    for i = 1:height(keys)
        hit = O.Protocol == keys.Protocol(i) & O.ObjectiveID == keys.ObjectiveID(i);
        if certifiedOnly, hit = hit & logical(O.PairCertified); end
        C = O(hit, :);
        ratio = quartiles(double(C.SelectedPosterior) ./ double(C.DefaultPosterior));
        parts{i} = [keys(i, :), table(height(C), fraction(logical(C.Improved), height(C)), ...
            ratio(2), ratio(1), ratio(3), 'VariableNames', names)];
    end
    S = stack(parts, keys, names);
end

function S = fim_agreement(O, registry)
%FIM_AGREEMENT Per focused protocol and objective: same direction of the FIM-predicted and posterior change, rank correlation.
    O = O(logical(O.PairAvailable) & logical(O.FIMValid), :);
    keys = objective_keys(O, registry);
    S = utils.add_certified_only(fim_rows(O, keys, false), fim_rows(O, keys, true), ...
        {'Protocol', 'ComparisonRole', 'ObjectiveID', 'IsTargetObjective'});
end

function S = fim_rows(O, keys, certifiedOnly)
    names = {'ComparedMaterialCount', 'FractionSameDirection', 'SpearmanRankCorrelation', ...
        'MedianFIMChange', 'MedianPosteriorChange'};
    parts = cell(height(keys), 1);
    for i = 1:height(keys)
        hit = O.Protocol == keys.Protocol(i) & O.ObjectiveID == keys.ObjectiveID(i);
        if certifiedOnly, hit = hit & logical(O.PairCertified); end
        C = O(hit, :);
        predicted = double(C.FIMSelectedMinusDefault);
        observed = double(C.SelectedMinusDefault);
        rho = NaN;
        if height(C) >= 3, rho = corr(predicted, observed, 'Type', 'Spearman'); end
        parts{i} = [keys(i, :), table(height(C), ...
            fraction(sign(predicted) == sign(observed), height(C)), rho, ...
            median(predicted, 'omitnan'), median(observed, 'omitnan'), 'VariableNames', names)];
    end
    S = stack(parts, keys, names);
end

function keys = objective_keys(O, registry)
%OBJECTIVE_KEYS The (protocol, objective) rows of the six-objective comparison, the protocol's own objective marked.
    keys = unique(O(:, {'Protocol', 'ComparisonRole', 'ObjectiveID'}), 'stable');
    keys.IsTargetObjective = false(height(keys), 1);
    for i = 1:height(keys)
        keys.IsTargetObjective(i) = any(registry.ConfirmationRole == keys.ComparisonRole(i) & ...
            registry.ObjectiveID == keys.ObjectiveID(i));
    end
end

function S = stack(parts, keys, names)
%STACK The summary rows, or a table with the columns and no rows.
    if isempty(parts)
        S = [keys, array2table(zeros(0, numel(names)), 'VariableNames', names)];
    else
        S = vertcat(parts{:});
    end
end

function S = recovery_error(status, parameters, names, configuration)
%RECOVERY_ERROR Per protocol and parameter over the materials whose four cells have a posterior.
    protocols = string({configuration.protocols.Protocol});
    materials = reshape(double(configuration.materials), 1, []);
    common = materials(arrayfun(@(id) all(arrayfun(@(p) has_posterior(status, id, p), protocols)), ...
        materials));
    certifiedCommon = materials(arrayfun(@(id) all(arrayfun(@(p) is_certified(status, id, p), ...
        protocols)), materials));
    rows = {};
    for p = protocols
        for k = 1:numel(names)
            qa = quartiles(recovery_errors(parameters, common, p, names{k}));
            qc = quartiles(recovery_errors(parameters, certifiedCommon, p, names{k}));
            rows{end+1} = table(p, string(names{k}), numel(common), numel(certifiedCommon), ...
                qa(2), qc(2), qa(1), qc(1), qa(3), qc(3), 'VariableNames', {'Protocol', 'Parameter', ...
                'MaterialCount', 'MaterialCount_certified_only', 'MedianRecoveryError', ...
                'MedianRecoveryError_certified_only', 'Q25RecoveryError', ...
                'Q25RecoveryError_certified_only', 'Q75RecoveryError', ...
                'Q75RecoveryError_certified_only'}); %#ok<AGROW>
        end
    end
    S = vertcat(rows{:});
end

function v = recovery_errors(parameters, ids, protocol, name)
%RECOVERY_ERRORS The recovery errors of the posterior median of the materials IDS under PROTOCOL.
    hit = ismember(parameters.MaterialCaseID, ids) & parameters.Protocol == protocol & ...
        parameters.Parameter == string(name);
    v = double(parameters.NormalizedAbsoluteRecoveryErrorFromPosteriorMedian(hit));
end

function names = target_parameters(registry, objective, parameterNames)
%TARGET_PARAMETERS The parameters of an objective's covariance formula (screening.objective_registry).
    formula = registry.PerTissueFormula(registry.ObjectiveID == objective);
    assert(isscalar(formula), 'plotting:confirmation_result_tables:Objective', ...
        'The objective %s is not one of the screen''s objectives.', objective);
    indices = unique(str2double(regexp(char(formula), '\d+', 'match')));
    names = parameterNames(indices);
end

function tf = has_posterior(status, id, protocol)
    tf = any(status.MaterialCaseID == id & status.Protocol == protocol & ...
        status.Status ~= "unavailable");
end

function tf = is_certified(status, id, protocol)
    tf = any(status.MaterialCaseID == id & status.Protocol == protocol & status.Status == "certified");
end

function s = cell_status(status, id, protocol)
    hit = status.MaterialCaseID == id & status.Protocol == protocol;
    assert(nnz(hit) == 1, 'plotting:confirmation_result_tables:Status', ...
        'The status table must list material %d and protocol %s once.', id, protocol);
    s = status.Status(hit);
end

function v = value(parameters, id, protocol, name, column)
    hit = parameters.MaterialCaseID == id & parameters.Protocol == protocol & ...
        parameters.Parameter == string(name);
    assert(nnz(hit) == 1, 'plotting:confirmation_result_tables:Parameter', ...
        'The posterior parameter summary must hold one row of material %d, %s, %s.', id, ...
        protocol, name);
    v = double(parameters.(column)(hit));
end

function [distance, sdDifference] = cell_discrepancy(cache, root, design, id, protocol, bounds, thresholds)
%CELL_DISCREPANCY The certification's replicate metric of one cell, per parameter (NaN with one replicate).
    key = sprintf('%d|%s', id, protocol);
    if isKey(cache, key)
        stored = cache(key); distance = stored{1}; sdDifference = stored{2}; return;
    end
    file = fullfile(root, 'draws', char(protocol), design, sprintf('case_%d.mat', id));
    assert(isfile(file), 'plotting:confirmation_result_tables:Draws', ...
        'The draws of material %d, protocol %s, are missing: %s.', id, protocol, file);
    saved = load(file, 'draws');
    replicates = saved.draws.replicates;
    m = size(bounds, 1);
    distance = nan(1, m); sdDifference = nan(1, m);
    if numel(replicates) >= 2
        X = double(replicates(1).drawsPhysical); Y = double(replicates(2).drawsPhysical);
        report = inversion.posterior_reproducibility(reshape(X, size(X, 1), size(X, 2), 1), ...
            reshape(Y, size(Y, 1), size(Y, 2), 1), bounds, thresholds);
        distance = reshape(report.normalizedWassersteinDistance, 1, []);
        sdDifference = reshape(abs(report.posteriorSD(1, :) - report.posteriorSD(2, :)) ./ ...
            mean(report.posteriorSD, 1), 1, []);
    end
    cache(key) = {distance, sdDifference}; %#ok<NASGU> a containers.Map: kept for the next pair
end

function q = quartiles(values)
%QUARTILES The 25 %, 50 % and 75 % quantiles of the finite values (NaN when there are none).
    values = values(isfinite(values));
    if isempty(values), q = nan(1, 3); return; end
    q = reshape(quantile(values, [0.25 0.50 0.75]), 1, 3);
end

function f = fraction(flags, n)
    f = NaN;
    if n > 0, f = nnz(flags) / n; end
end
