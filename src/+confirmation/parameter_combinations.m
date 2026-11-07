function result = parameter_combinations(cfg)
%PARAMETER_COMBINATIONS Which weak-pair combinations the confirmation's posteriors determine, and how a focused protocol changes them.
%   RESULT = confirmation.parameter_combinations(CFG) reads the posteriors
%   of the confirmation (CFG.native.combinationsSource: the
%   06_confirmation data folder of this run, which its step compare wrote,
%   or of the shipped results): cell_status.csv (every material, protocol
%   and observation design with its protocol role and status) and the full
%   draws of both replicates of every cell with a posterior
%   (draws/<protocol>/<design>/case_<CaseID>.mat, draws/index.csv). For the
%   designs of the settings (B.8) it analyses each replicate on its own
%   (never pooled), as the parameter combinations of the fixed route
%   (recovery.parameter_combinations, A.12; the shared parts in
%   recovery.combination_support), in the prior-standardized coordinates
%   z = (theta - prior mean) / prior SD of the four material parameters:
%     weak pair    the best- and the worst-determined combination of the
%                  weak pair (the confirmation's target parameters, B.7)
%                  from its 2 x 2 block of C_z, next to the individual SD
%                  ratios, with the label "identified combination" (a
%                  description, not a test) and, where the draws allow it,
%                  the same in log form with the power law m3e^a k0^b
%     marginals    for the best four-parameter combination, the best
%                  weak-pair combination and its log form: the projected
%                  draws against the prior sample and the truth (SD ratio,
%                  95 % width ratio, the truth inside the central 50 % and
%                  95 % intervals) and the densities the figures draw
%     consensus    per design, protocol and replicate the consensus of each
%                  best combination (recovery.consensus_projector), each
%                  material's angle to it and the spread; the certified
%                  cells alone in the columns ending in _certified_only
%     protocols    per design, material, focused protocol and replicate, on
%                  the matched cohort (a posterior, certified or healthy
%                  fallback, under the protocol and under the default): the
%                  rotation of the best weak-pair combination from the
%                  default's (the angle between the two directions, 0 to 90
%                  degrees, and the signed difference of their angles in
%                  the plane of the pair), the ratio of their SD ratios
%                  (below 1: the focused protocol determines its best
%                  combination more sharply), the ratios of the individual
%                  SD ratios, the same for the log form where both cells
%                  allow it, and the replicate differences of both cells
%                  (the angle between the best directions of the two
%                  replicates, the relative difference of their SD ratios):
%                  the run-to-run variation a protocol effect must exceed
%     summary      per design, focused protocol and replicate: the matched
%                  materials, the median and quartiles of the rotation and
%                  of the ratio of SD ratios, the materials whose best
%                  combination the protocol determines more sharply, the
%                  median replicate angle, and the angle between the
%                  protocol's consensus and the default's; the pairs of two
%                  certified cells alone in the columns ending in
%                  _certified_only
%   Writes below CFG.paths.confirmationCombinations: cohort.csv (every
%   cell: status, provider, replicates and their draws), cells.csv,
%   marginals.csv, densities.csv, consensus.csv, protocols.csv and
%   protocol_summary.csv (these two only when some material has a posterior
%   under a focused protocol and under the default). The projected draws
%   are not stored: the draws give them again. Descriptive: no sampler and
%   no GP run.
%   RESULT has the fields cells (the cohort's rows), replicates (rows of
%   cells.csv) and root.
%   Side effects: writes the files above.
%   Computation: about a minute (every draw of each cell).

    C = cfg.analysis.confirmationCombinations;
    source = cfg.native.combinationsSource;
    statusFile = fullfile(source, 'cell_status.csv');
    indexFile = fullfile(source, 'draws', 'index.csv');
    assert(isfile(statusFile) && isfile(indexFile), 'confirmation:parameter_combinations:NoDraws', ...
        ['The parameter combinations of the confirmation need its status table and draws (%s, %s): ' ...
         'run the step compare first, or use shipped results that hold the confirmation.'], ...
        statusFile, indexFile);
    status = utils.read_csv_table(statusFile, {'Protocol', 'ProtocolRole', 'Design', 'Status', ...
        'ProviderSampler', 'Reason'});
    index = utils.read_csv_table(indexFile, {'CellID', 'Scenario', 'Design', 'ConditionCode', 'State', ...
        'ReplicateIDs', 'File', 'ProviderSource', 'PartnerSource', 'MissingReplicateReason'});
    index.Protocol = string(extractBefore(index.File, '/'));
    designs = unique(status.Design, 'stable');
    if ~((ischar(C.designs) || isstring(C.designs)) && strcmp(char(C.designs), 'all'))
        designs = designs(ismember(designs, string(C.designs)));
    end
    status = status(ismember(status.Design, designs), :);
    reference = unique(status.Protocol(status.ProtocolRole == "default"));
    assert(isscalar(reference), 'confirmation:parameter_combinations:Reference', ...
        'The confirmation needs exactly one default protocol in %s (found %d).', statusFile, numel(reference));
    E = cfg.analysis.posteriorEigendecomposition;
    eigenOptions = {'NearDegenerateGap', E.nearDegenerateGapThreshold, ...
        'NegativeEigenvalueTolerance', E.negativeEigenvalueTolerance, 'SymmetryTolerance', E.symmetryTolerance};
    support = @recovery.combination_support;
    pairNames = reshape(cellstr(string(cfg.stage9bConfirmation.targetParameterNames)), 1, []);
    model = [];
    cohortRows = cell(height(status), 1);
    cellParts = {}; marginalParts = {}; densityParts = {};
    for k = 1:height(status)
        row = status(k, :);
        file = index.File(index.CaseID == row.MaterialCaseID & index.Design == row.Design & ...
            index.Protocol == row.Protocol);
        if isempty(file)
            cohortRows{k} = cohort_row(row, [], [0 0], "no posterior: " + row.Status);
            continue;
        end
        assert(isscalar(file), 'confirmation:parameter_combinations:Index', ...
            'The draw index %s lists case %d, %s, %s more than once.', indexFile, row.MaterialCaseID, ...
            row.Protocol, row.Design);
        saved = load(fullfile(source, 'draws', strrep(char(file), '/', filesep)), 'draws');
        D = saved.draws;
        if isempty(model)
            model = coordinates(D, pairNames, C);
            prior = support('prior_sample', C, model.bounds, model.weak, model.forms.logged);
        end
        check_coordinates(D, model, file);
        replicates = cell(1, 2); counts = [0 0];
        for j = 1:numel(D.replicates)
            r = double(D.replicates(j).replicateID);
            replicates{r} = double(D.replicates(j).drawsPhysical);
            counts(r) = size(replicates{r}, 1);
        end
        truth = reshape(double(D.truth), 1, []);
        [logValid, logReason] = support('log_form_check', replicates, model.weak, model.forms.logged, ...
            model.names, model.bounds, C.logForm);
        state = state_of(D);
        notes = strings(1, 0);
        if ~isempty(char(string(D.missingReplicateReason)))
            notes(end+1) = string(D.missingReplicateReason); %#ok<AGROW>
        end
        for r = find(counts > 0)
            A = support('replicate_analysis', replicates{r}, truth, model.bounds, model.names, model.weak, ...
                prior, model.forms, logValid, C, eigenOptions);
            if ~A.valid
                notes(end+1) = sprintf('replicate %d: %s', r, A.reason); %#ok<AGROW>
                continue;
            end
            key = key_table(row, state, r);
            cellParts{end+1, 1} = [key, support('cell_columns', A, [], model.names, model.weak, model.forms, ...
                prior, logReason)]; %#ok<AGROW>
            marginalParts{end+1, 1} = [repmat(key, height(A.marginals), 1), A.marginals]; %#ok<AGROW>
            densityParts{end+1, 1} = [repmat(key, height(A.densities), 1), A.densities]; %#ok<AGROW>
        end
        cohortRows{k} = cohort_row(row, D, counts, strjoin(notes, '; '));
    end
    assert(~isempty(cellParts), 'confirmation:parameter_combinations:NoPosterior', ...
        'No cell of the confirmation (designs of B.8) has a posterior to analyse in %s.', source);
    cohort = vertcat(cohortRows{:});
    cells = vertcat(cellParts{:});
    [consensus, cells] = support('consensus_rows', cells, model.names, model.weak, prior, model.forms, ...
        {'Design', 'Protocol'});
    pair = model.names(model.weak);
    protocols = protocol_rows(cells, reference, pair);
    summary = protocol_summary(protocols, consensus, reference, pair);
    root = cfg.paths.confirmationCombinations;
    if ~isfolder(root), mkdir(root); end
    utils.atomic_write_table(fullfile(root, 'cohort.csv'), cohort);
    utils.atomic_write_table(fullfile(root, 'cells.csv'), cells);
    utils.atomic_write_table(fullfile(root, 'marginals.csv'), vertcat(marginalParts{:}));
    utils.atomic_write_table(fullfile(root, 'densities.csv'), vertcat(densityParts{:}));
    utils.atomic_write_table(fullfile(root, 'consensus.csv'), consensus);
    if ~isempty(protocols)
        % Without a material that has a posterior under a focused protocol
        % and under the default, there is nothing to compare.
        utils.atomic_write_table(fullfile(root, 'protocols.csv'), protocols);
        utils.atomic_write_table(fullfile(root, 'protocol_summary.csv'), summary);
    end
    result = struct('cells', height(cohort), 'replicates', height(cells), 'root', root);
end

function M = coordinates(D, pairNames, C)
%COORDINATES The parameters, bounds and weak pair of the draw files, and how the weak pair enters the log form.
%   logged: the natural log of the parameter (the settings' log-form
%   parameters); log10: its model coordinate is the log10 of a physical
%   parameter (a name log10_<name>), whose name the power law uses;
%   powerLaw: every coordinate is a logarithm.
    M.names = reshape(cellstr(string(D.parameterNames)), 1, []);
    M.bounds = double(D.bounds);
    [found, M.weak] = ismember(pairNames, M.names);
    assert(all(found) && numel(M.weak) == 2, 'confirmation:parameter_combinations:WeakPair', ...
        'The target parameters %s are not two of the draws'' parameters %s.', strjoin(pairNames, ', '), ...
        strjoin(M.names, ', '));
    pair = M.names(M.weak);
    F.logged = ismember(pair, cellstr(string(C.logForm.parameters)));
    F.log10 = startsWith(pair, 'log10_') & ~F.logged;
    F.physicalNames = pair;
    F.physicalNames(F.log10) = extractAfter(pair(F.log10), 'log10_');
    F.powerLaw = all(F.logged | F.log10);
    F.labels = strcat('z(', pair, ')');
    F.logLabels = F.labels;
    F.logLabels(F.logged) = strcat('z(ln ', pair(F.logged), ')');
    M.forms = F;
end

function check_coordinates(D, M, file)
    same = isequal(reshape(cellstr(string(D.parameterNames)), 1, []), M.names) && ...
        isequal(double(D.bounds), M.bounds);
    assert(same, 'confirmation:parameter_combinations:Coordinates', ...
        'The draw file %s has other parameters or bounds than the first file analysed.', file);
end

function state = state_of(D)
    if logical(D.certified)
        state = "certified";
    else
        state = "healthy fallback";
    end
end

function T = key_table(row, state, r)
    T = table(double(row.MaterialCaseID), string(row.Protocol), string(row.ProtocolRole), ...
        string(row.Design), string(state), r, 'VariableNames', {'CaseID', 'Protocol', 'ProtocolRole', ...
        'Design', 'Status', 'Replicate'});
end

function T = cohort_row(row, D, counts, note)
    sampler = ""; level = NaN; replicate = NaN; state = "unavailable";
    if ~isempty(D)
        sampler = string(D.sampler); level = double(D.stepCount);
        replicate = double(D.providerReplicateID); state = state_of(D);
    end
    T = table(double(row.MaterialCaseID), string(row.Protocol), string(row.ProtocolRole), ...
        string(row.Design), state, sampler, level, replicate, nnz(counts > 0), counts(1), counts(2), ...
        string(note), 'VariableNames', {'CaseID', 'Protocol', 'ProtocolRole', 'Design', 'Status', ...
        'ProviderSampler', 'ProviderSteps', 'ProviderReplicate', 'Replicates', 'Replicate1Draws', ...
        'Replicate2Draws', 'Note'});
end

function T = protocol_rows(cells, reference, pair)
%PROTOCOL_ROWS Per design, material, focused protocol and replicate: the best weak-pair combination against the default's.
    rows = {};
    best = strcat('Best_w_', pair); logBest = strcat('LogBest_w_', pair);
    for design = reshape(unique(cells.Design, 'stable'), 1, [])
        inDesign = cells(cells.Design == design, :);
        base = inDesign(inDesign.Protocol == reference, :);
        for protocol = reshape(unique(inDesign.Protocol(inDesign.Protocol ~= reference), 'stable'), 1, [])
            focused = inDesign(inDesign.Protocol == protocol, :);
            for i = 1:height(focused)
                f = focused(i, :);
                d = base(base.CaseID == f.CaseID & base.Replicate == f.Replicate, :);
                if isempty(d), continue; end
                spread = @(T, id) replicate_spread(T(T.CaseID == id, :), best);
                [baseAngle, baseSD] = spread(base, f.CaseID);
                [focusedAngle, focusedSD] = spread(focused, f.CaseID);
                logRotation = NaN; logSigned = NaN; logRatio = NaN;
                if all(isfinite([d{1, logBest} f{1, logBest}]))
                    [logRotation, logSigned] = rotation(d{1, logBest}, f{1, logBest});
                    logRatio = f.LogBest_SDRatio / d.LogBest_SDRatio;
                end
                [angle, signed] = rotation(d{1, best}, f{1, best});
                one = table(design, f.CaseID, protocol, d.Status, f.Status, f.Replicate, ...
                    direction(d{1, best}), direction(f{1, best}), angle, signed, ...
                    d.Best_SDRatio, f.Best_SDRatio, f.Best_SDRatio / d.Best_SDRatio, ...
                    'VariableNames', {'Design', 'CaseID', 'Protocol', 'DefaultStatus', 'ProtocolStatus', ...
                    'Replicate', 'DefaultDirection', 'ProtocolDirection', 'Rotation', 'SignedRotation', ...
                    'DefaultBest_SDRatio', 'ProtocolBest_SDRatio', 'Best_SDRatioRatio'});
                for j = 1:2
                    one.(['Default_SDRatio_' pair{j}]) = d.(['SDRatio_' pair{j}]);
                    one.(['Protocol_SDRatio_' pair{j}]) = f.(['SDRatio_' pair{j}]);
                    one.(['SDRatioRatio_' pair{j}]) = f.(['SDRatio_' pair{j}]) / d.(['SDRatio_' pair{j}]);
                end
                one.DefaultIdentified = d.Identified;
                one.ProtocolIdentified = f.Identified;
                one.LogRotation = logRotation;
                one.LogSignedRotation = logSigned;
                one.LogBest_SDRatioRatio = logRatio;
                one.DefaultReplicateAngle = baseAngle;
                one.ProtocolReplicateAngle = focusedAngle;
                one.DefaultReplicateSDDifference = baseSD;
                one.ProtocolReplicateSDDifference = focusedSD;
                rows{end+1, 1} = one; %#ok<AGROW>
            end
        end
    end
    if isempty(rows)
        T = table();
    else
        T = vertcat(rows{:});
    end
end

function a = direction(w)
%DIRECTION The angle of a weak-pair direction in the plane of the pair (degrees; first weight >= 0).
    a = atan2d(w(2), w(1));
end

function [angle, signed] = rotation(a, b)
%ROTATION The angle between two weak-pair directions (0 to 90 degrees) and the signed difference of their angles.
%   Directions are axes (w and -w are the same combination): the signed
%   difference is taken into (-90, 90].
    angle = acosd(recovery.axis_similarity(a, b));
    signed = direction(b) - direction(a);
    signed = mod(signed + 90, 180) - 90;
    if signed == -90, signed = 90; end
end

function [angle, sdDifference] = replicate_spread(T, best)
%REPLICATE_SPREAD The two replicates of one cell: the angle between their best directions and the relative difference of their SD ratios.
    angle = NaN; sdDifference = NaN;
    r1 = T(T.Replicate == 1, :); r2 = T(T.Replicate == 2, :);
    if isempty(r1) || isempty(r2), return; end
    angle = acosd(recovery.axis_similarity(r1{1, best}, r2{1, best}));
    sdDifference = abs(r1.Best_SDRatio - r2.Best_SDRatio) / mean([r1.Best_SDRatio r2.Best_SDRatio]);
end

function T = protocol_summary(protocols, consensus, reference, pair)
%PROTOCOL_SUMMARY Per design, focused protocol and replicate: the matched materials and the protocol's effect.
    rows = {};
    if isempty(protocols), T = table(); return; end
    keys = unique(protocols(:, {'Design', 'Protocol'}), 'stable');
    for g = 1:height(keys)
        for r = reshape(unique(protocols.Replicate).', 1, [])
            P = protocols(protocols.Design == keys.Design(g) & protocols.Protocol == keys.Protocol(g) & ...
                protocols.Replicate == r, :);
            if isempty(P), continue; end
            certified = P(P.DefaultStatus == "certified" & P.ProtocolStatus == "certified", :);
            row = [keys(g, :), table(r, 'VariableNames', {'Replicate'})];
            part = summary_part(P);
            partCertified = summary_part(certified);
            partCertified.Properties.VariableNames = strcat(partCertified.Properties.VariableNames, ...
                '_certified_only');
            between = consensus_angle(consensus, keys.Design(g), keys.Protocol(g), reference, r, pair);
            rows{end+1, 1} = [row, part, between, partCertified]; %#ok<AGROW>
        end
    end
    T = vertcat(rows{:});
end

function T = summary_part(P)
    n = height(P);
    q = @(x, p) quantile_or_nan(x, p);
    T = table(n, q(P.Rotation, 0.5), q(P.Rotation, 0.25), q(P.Rotation, 0.75), max([P.Rotation; NaN]), ...
        q(P.Best_SDRatioRatio, 0.5), q(P.Best_SDRatioRatio, 0.25), q(P.Best_SDRatioRatio, 0.75), ...
        nnz(P.Best_SDRatioRatio < 1), q(max(P.DefaultReplicateAngle, P.ProtocolReplicateAngle), 0.5), ...
        nnz(P.Rotation > max(P.DefaultReplicateAngle, P.ProtocolReplicateAngle)), ...
        nnz(logical(P.DefaultIdentified)), nnz(logical(P.ProtocolIdentified)), ...
        'VariableNames', {'MatchedMaterials', 'MedianRotation', 'Q25Rotation', 'Q75Rotation', ...
        'MaxRotation', 'MedianBest_SDRatioRatio', 'Q25Best_SDRatioRatio', 'Q75Best_SDRatioRatio', ...
        'SharperCount', 'MedianReplicateAngle', 'RotationAboveReplicateAngleCount', ...
        'DefaultIdentifiedCount', 'ProtocolIdentifiedCount'});
end

function v = quantile_or_nan(x, p)
    x = x(isfinite(x));
    if isempty(x), v = NaN; else, v = quantile(x, p); end
end

function T = consensus_angle(consensus, design, protocol, reference, r, pair)
%CONSENSUS_ANGLE The angle between the protocol's consensus of the best weak-pair combinations and the default's.
    pick = @(p) consensus(consensus.Design == design & consensus.Protocol == p & consensus.Replicate == r & ...
        consensus.Combination == "weak_pair_best", :);
    a = pick(reference); b = pick(protocol);
    angle = NaN; signed = NaN;
    columns = strcat('ConsensusWeight_', pair);
    if ~isempty(a) && ~isempty(b) && all(isfinite([a{1, columns} b{1, columns}]))
        [angle, signed] = rotation(a{1, columns}, b{1, columns});
    end
    T = table(angle, signed, 'VariableNames', {'ConsensusRotation', 'ConsensusSignedRotation'});
end
