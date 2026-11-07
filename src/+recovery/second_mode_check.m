function result = second_mode_check(cfg)
%SECOND_MODE_CHECK Is a cell's second walker group a second region of good fit, or stuck walkers?
%   RESULT = recovery.second_mode_check(CFG) examines the cell of the
%   settings (A.7, CFG.analysis.secondModeCheck; thesis: case 215,
%   gp_self_det, all_six, whose walkers split in both replicates),
%   descriptively: no MCMC, no change of any status. Coordinates
%   in prior widths are (x - lower) / (upper - lower) per parameter; a
%   distance in prior widths is the largest over the parameters.
%     a) Walker groups: the walkers of both replicates, by their median
%        positions over the retained draws; two walkers are in one group when
%        their medians differ by at most groupDistance in every parameter
%        (single linkage). Groups in order of size; B is the median point of
%        the second group. Each group's median and largest log-likelihood
%        (the draw files' logLikelihood).
%     b) The fit at B and at the truth: the GP mean minus the cell's
%        observation for the six pressures, and the cell's log-likelihood
%        (inversion.cell_likelihood).
%     c) Local refinement from B and, as a control, from the truth: fmincon
%        (the optimizer of the settings) on the cell's negative
%        log-likelihood inside the prior bounds.
%     d) The negative log-likelihood along the straight line from the truth
%        to B (pathPoints points, the ends included).
%     e) Realistic noise: delta = 0.5 sum_k r_k^2 / s_k^2 with r_k the GP mean
%        at B (and at the end of the refinement from B) minus the GP mean at
%        the truth, s_k^2 = (measurement CV x GP mean at the truth)^2 + the
%        calibrated emulator variance at the truth (measurement_plus_gp) or
%        the calibrated emulator variance alone (gp_only); and the shares of
%        the retained draws of the case's cells in shareScenarios (the cell's
%        design, both replicates) within neighbourhood prior widths of B and
%        of the truth.
%     f) The angles between the direction truth -> B and the eigendirections
%        of the case's posterior in directionScenario (the cell's design;
%        the eigen-analysis of this run, else the shipped one), the
%        sloppy two-dimensional subspace (the directions of the two largest
%        eigenvalues), and the best- and worst-determined combinations of
%        the weak pair (the parameter combinations of this run, else the
%        shipped ones; replicate 1), the plane of the pair, and within it
%        the worst-determined combination.
%     g) The cases of the fixed dataset whose COMSOL pressures lie closest to
%        the case's: the root mean square, over the outputs both have, of the
%        difference in units of the measurement CV times the case's pressure.
%   The class follows the rule of the settings, fixed in advance: EXACT
%   SECOND SOLUTION when the refinement from B ends at least exactDistance
%   prior widths from the truth in some parameter with a log-likelihood
%   within exactLogLikelihood of the truth's; else NEAR-EQUIVALENT SOLUTION
%   when delta (measurement_plus_gp) at B is below nearDelta; else TRAP.
%   Writes walkers.csv, walker_groups.csv, points.csv, path.csv,
%   realistic_noise.csv, draw_shares.csv, directions.csv,
%   comsol_neighbours.csv and second_mode_check.json into
%   CFG.paths.secondModeCheck; RESULT is the record of the JSON file.
%   Computation: about a minute (GP evaluations one point at a time).
%   Side effects: writes the files above.

    S = cfg.analysis.secondModeCheck;
    out = cfg.paths.secondModeCheck;
    if ~isfolder(out), mkdir(out); end
    P = parameters.parameter_space(cfg);
    names = reshape(cellstr(P.names), 1, []);
    outputs = reshape(cellstr(P.outputNames), 1, []);
    lower = P.bounds(:, 1).'; width = (P.bounds(:, 2) - P.bounds(:, 1)).';
    unit = @(X) (X - lower) ./ width;
    record = struct('caseID', S.caseID, 'scenario', S.scenario, 'design', S.design);

    % a) The cell's posterior, both replicates of its provider's level.
    [replicates, provider, reason] = load_replicates(cfg, record);
    if isempty(replicates)
        % The cell has no posterior where this run reads posteriors (e.g. an
        % example run whose inversion covers other cases): nothing to check.
        result = struct('schema_version', 'second_mode_check_v1', 'cell', record, ...
            'class', 'NOT AVAILABLE', 'reason', reason, 'files', {{}}, 'mcmc_runs_performed', 0, ...
            'status_changed', false);
        utils.atomic_write_json(fullfile(out, 'second_mode_check.json'), result, 'AllowReplace', true);
        fprintf('[recovery] second-mode check of case %d %s %s: not available (%s).\n', S.caseID, ...
            S.scenario, S.design, reason);
        return;
    end
    truth = reshape(double(provider.truth), 1, []);
    cellRecord = struct('caseID', S.caseID, 'scenario', S.scenario, 'design', S.design, ...
        'stepCount', provider.stepCount, 'truth', truth, 'observation', provider.observation);
    saved = load(cfg.files.gp, 'gp');
    L = inversion.cell_likelihood(cfg, saved.gp, cellRecord);
    for k = 1:numel(replicates)
        if ~isempty(replicates(k).logLikelihood), continue; end
        % A posterior record without the field (a run's own campaign): the cell's likelihood at its draws.
        A = replicates(k).sampleArray;
        draws = reshape(permute(A, [1 3 2]), [], size(A, 2));
        replicates(k).logLikelihood = L.logLikelihoodBatch(draws, S.gpEvaluationBatchSize);
        replicates(k).logLikelihoodSource = 'evaluated';
    end
    [walkers, groups] = walker_groups(replicates, unit, S.groupDistance, truth, names);
    assert(height(groups) >= 1, 'recovery:second_mode_check:NoWalkers', 'The cell has no walkers.');
    groupSummary = group_summary(replicates, walkers, groups, unit, truth, names);
    if height(groups) < 2
        record = finish(out, S, cellRecord, provider, 'NO SECOND GROUP', struct(), {}, walkers, groupSummary);
        result = record;
        return;
    end
    B = double(groups{2, strcat('Median_', names)});

    % b) and c) The fit at B and at the truth, and the local refinements.
    options = optimoptions('fmincon', 'Algorithm', S.optimizer.algorithm, ...
        'OptimalityTolerance', S.optimizer.optimalityTolerance, 'StepTolerance', S.optimizer.stepTolerance, ...
        'MaxIterations', S.optimizer.maxIterations, ...
        'MaxFunctionEvaluations', S.optimizer.maxFunctionEvaluations, 'Display', 'off');
    objective = @(u) -L.logLikelihood(lower + u .* width);
    [fromB, infoB] = refine(objective, unit(B), options);
    [fromTruth, infoTruth] = refine(objective, unit(truth), options);
    refinedB = lower + fromB .* width;
    refinedTruth = lower + fromTruth .* width;
    points = point_table({'truth', 'B', 'refined_from_B', 'refined_from_truth'}, ...
        [truth; B; refinedB; refinedTruth], {struct(), struct(), infoB, infoTruth}, L, unit, truth, B, ...
        names, outputs);

    % d) The path from the truth to B.
    t = linspace(0, 1, S.pathPoints).';
    X = truth + t .* (B - truth);
    pathTable = [table(t, 'VariableNames', {'Position'}), array2table(X, 'VariableNames', names), ...
        table(-L.logLikelihood(X), 'VariableNames', {'NegativeLogLikelihood'})];
    ends = max(pathTable.NegativeLogLikelihood([1 end]));
    barrier = max(pathTable.NegativeLogLikelihood) - ends;

    % e) Realistic noise, and the draws of the case near B and near the truth.
    noise = realistic_noise(L, truth, {'B', 'refined_from_B'}, [B; refinedB], cfg.meas_cv, outputs);
    shares = draw_shares(cfg, S, unit, B, truth);

    % f) The direction truth -> B against the eigendirections of the case's
    % posterior and its combinations of the weak pair.
    directions = [direction_angles(cfg, S, unit(B) - unit(truth)); ...
        weak_pair_angles(cfg, S, unit(B) - unit(truth))];
    directionSource = 'not available: no eigen-analysis of the case in this run or shipped';
    if ~isempty(directions), directionSource = char(directions.Source(1)); end

    % g) The COMSOL cases with the closest pressures.
    neighbours = comsol_neighbours(cfg, S, unit, names);

    % The class, by the rule fixed in advance.
    rule = S.classification;
    truthLogLikelihood = points.LogLikelihood(points.Point == "truth");
    endLogLikelihood = points.LogLikelihood(points.Point == "refined_from_B");
    endDistance = max(abs(fromB - unit(truth)));
    deltaB = noise.Delta(noise.Point == "B" & noise.NoiseModel == "measurement_plus_gp");
    if endDistance >= rule.exactDistance && endLogLikelihood >= truthLogLikelihood - rule.exactLogLikelihood
        verdict = 'EXACT SECOND SOLUTION';
    elseif deltaB < rule.nearDelta
        verdict = 'NEAR-EQUIVALENT SOLUTION';
    else
        verdict = 'TRAP';
    end
    numbers = struct('B', B, 'truth', truth, ...
        'bDistanceFromTruth', max(abs(unit(B) - unit(truth))), ...
        'logLikelihoodTruth', truthLogLikelihood, ...
        'logLikelihoodB', points.LogLikelihood(points.Point == "B"), ...
        'refinedFromBDistanceFromTruth', endDistance, ...
        'refinedFromBDistanceFromB', max(abs(fromB - unit(B))), ...
        'logLikelihoodRefinedFromB', endLogLikelihood, ...
        'refinedFromTruthDistanceFromTruth', max(abs(fromTruth - unit(truth))), ...
        'pathBarrierAboveEnds', barrier, ...
        'deltaMeasurementPlusGPAtB', deltaB, ...
        'deltaGPOnlyAtB', noise.Delta(noise.Point == "B" & noise.NoiseModel == "gp_only"), ...
        'deltaMeasurementPlusGPAtRefinedB', noise.Delta(noise.Point == "refined_from_B" & ...
            noise.NoiseModel == "measurement_plus_gp"), ...
        'directionsSource', directionSource);
    write(out, 'points.csv', points);
    write(out, 'path.csv', pathTable);
    write(out, 'realistic_noise.csv', noise);
    write(out, 'draw_shares.csv', shares);
    write(out, 'directions.csv', directions);
    write(out, 'comsol_neighbours.csv', neighbours);
    result = finish(out, S, cellRecord, provider, verdict, numbers, ...
        {'points.csv', 'path.csv', 'realistic_noise.csv', 'draw_shares.csv', 'directions.csv', ...
        'comsol_neighbours.csv'}, walkers, groupSummary);
    fprintf('[recovery] second-mode check of case %d %s %s: %s.\n', S.caseID, S.scenario, S.design, verdict);
end

function [replicates, provider, reason] = load_replicates(cfg, record)
%LOAD_REPLICATES Both replicates of the provider's level of one cell, with their draws and log-likelihood.
%   REPLICATES is empty, and REASON says why, when the cell has no posterior.
    replicates = struct('replicateID', {}, 'sampleArray', {}, 'logLikelihood', {}, 'logLikelihoodSource', {});
    provider = struct();
    reason = '';
    [A, status] = recovery.load_posterior_provider(cfg, record);
    if ~(status.loaded && status.valid)
        reason = sprintf('the cell has no posterior in this run''s source of posteriors: %s', status.reason);
        return;
    end
    level = double(A.request.stepCount);
    provider = struct('truth', A.truth, 'observation', A.observation, 'stepCount', level, ...
        'state', status.state, 'certified', status.certified);
    for r = 1:2
        [R, s] = recovery.load_posterior_provider(cfg, record, 'AIES', r, level);
        if ~(s.loaded && s.valid), continue; end
        replicates(end+1) = struct('replicateID', r, 'sampleArray', double(R.sampleArray), ...
            'logLikelihood', field_or_empty(R, 'logLikelihood'), ...
            'logLikelihoodSource', char(string(field_or_empty(R, 'logLikelihoodSource')))); %#ok<AGROW>
    end
    assert(~isempty(replicates), 'recovery:second_mode_check:Replicates', ...
        'Case %d %s %s: no replicate of level %d loaded.', record.caseID, record.scenario, record.design, level);
end

function value = field_or_empty(A, name)
    value = [];
    if isfield(A, name), value = A.(name); end
end

function [walkers, groups] = walker_groups(replicates, unit, distance, truth, names)
%WALKER_GROUPS The walkers of all replicates grouped by their median positions (single linkage).
    rows = {};
    for r = 1:numel(replicates)
        A = replicates(r).sampleArray;                  % iteration x parameter x walker
        medians = squeeze(median(A, 1)).';             % walker x parameter
        for w = 1:size(medians, 1)
            rows(end+1, :) = {replicates(r).replicateID, w, medians(w, :)}; %#ok<AGROW>
        end
    end
    M = vertcat(rows{:, 3});
    U = unit(M);
    n = size(U, 1);
    label = 1:n;
    for i = 1:n
        for j = i + 1:n
            if max(abs(U(i, :) - U(j, :))) <= distance
                old = label(j); label(label == old) = label(i);
            end
        end
    end
    [ids, ~, member] = unique(label, 'stable');
    count = accumarray(member(:), 1);
    centre = zeros(numel(ids), size(M, 2));
    for g = 1:numel(ids), centre(g, :) = median(M(member == g, :), 1); end
    toTruth = max(abs(unit(centre) - unit(truth)), [], 2);
    [~, order] = sortrows([-count, toTruth]);
    rank = zeros(numel(ids), 1); rank(order) = 1:numel(ids);
    walkers = [table(cell2mat(rows(:, 1)), cell2mat(rows(:, 2)), rank(member), ...
        'VariableNames', {'Replicate', 'Walker', 'Group'}), ...
        array2table(M, 'VariableNames', strcat('Median_', names))];
    groups = [table((1:numel(ids)).', count(order), toTruth(order), ...
        'VariableNames', {'Group', 'WalkerCount', 'DistanceFromTruth'}), ...
        array2table(centre(order, :), 'VariableNames', strcat('Median_', names))];
end

function T = group_summary(replicates, walkers, groups, unit, truth, names)
%GROUP_SUMMARY Each group in each replicate and in both: its walkers, median point and log-likelihood.
    T = table();
    for g = 1:height(groups)
        for r = [reshape([replicates.replicateID], 1, []), 0]
            mine = walkers.Group == g;
            if r > 0, mine = mine & walkers.Replicate == r; end
            if ~any(mine), continue; end
            values = [];
            source = '';
            for k = 1:numel(replicates)
                if r > 0 && replicates(k).replicateID ~= r, continue; end
                which = walkers.Walker(mine & walkers.Replicate == replicates(k).replicateID);
                if isempty(which) || isempty(replicates(k).logLikelihood), continue; end
                A = replicates(k).sampleArray;
                ll = reshape(replicates(k).logLikelihood, size(A, 1), size(A, 3));   % iteration x walker
                values = [values; reshape(ll(:, which), [], 1)]; %#ok<AGROW>
                source = replicates(k).logLikelihoodSource;
            end
            centre = median(walkers{mine, strcat('Median_', names)}, 1);
            scope = "both";
            if r > 0, scope = string(r); end
            row = [table(g, scope, nnz(mine), max(abs(unit(centre) - unit(truth))), ...
                median_or_nan(values), max_or_nan(values), string(source), 'VariableNames', ...
                {'Group', 'Replicate', 'WalkerCount', 'DistanceFromTruth', 'LogLikelihoodMedian', ...
                'LogLikelihoodMax', 'LogLikelihoodSource'}), array2table(centre, 'VariableNames', ...
                strcat('Median_', names))];
            T = [T; row]; %#ok<AGROW>
        end
    end
end

function v = median_or_nan(x)
    v = NaN; if ~isempty(x), v = median(x); end
end

function v = max_or_nan(x)
    v = NaN; if ~isempty(x), v = max(x); end
end

function [u, info] = refine(objective, start, options)
%REFINE The local minimum of the negative log-likelihood from START (prior-width coordinates), inside the bounds.
    [u, ~, flag, output] = fmincon(objective, start, [], [], [], [], zeros(size(start)), ones(size(start)), ...
        [], options);
    info = struct('ExitFlag', flag, 'Iterations', output.iterations, 'FunctionEvaluations', output.funcCount);
end

function T = point_table(labels, X, infos, L, unit, truth, B, names, outputs)
%POINT_TABLE The points with their distances, log-likelihood, GP means and residuals.
    prediction = L.prediction(X);
    mu = prediction.GPMean;
    T = table();
    for k = 1:numel(labels)
        info = infos{k};
        flag = NaN; iterations = NaN; evaluations = NaN;
        if isfield(info, 'ExitFlag')
            flag = info.ExitFlag; iterations = info.Iterations; evaluations = info.FunctionEvaluations;
        end
        row = [table(string(labels{k}), 'VariableNames', {'Point'}), ...
            array2table(X(k, :), 'VariableNames', names), ...
            table(max(abs(unit(X(k, :)) - unit(truth))), max(abs(unit(X(k, :)) - unit(B))), ...
            'VariableNames', {'DistanceFromTruth', 'DistanceFromB'}), ...
            array2table(unit(X(k, :)) - unit(truth), 'VariableNames', strcat('FromTruth_', names)), ...
            table(L.logLikelihood(X(k, :)), 'VariableNames', {'LogLikelihood'}), ...
            array2table(mu(k, :), 'VariableNames', strcat('GPMean_', outputs)), ...
            array2table(mu(k, :) - L.observation, 'VariableNames', strcat('Residual_', outputs)), ...
            table(flag, iterations, evaluations, 'VariableNames', {'ExitFlag', 'Iterations', ...
            'FunctionEvaluations'})];
        T = [T; row]; %#ok<AGROW>
    end
end

function T = realistic_noise(L, truth, labels, X, cv, outputs)
%REALISTIC_NOISE delta between each point and the truth under the measurement + GP and the GP-only noise.
    at = L.prediction(truth);
    pts = L.prediction(X);
    models = {'measurement_plus_gp', (cv * at.GPMean).^2 + at.CalibratedEmulatorVariance; ...
        'gp_only', at.CalibratedEmulatorVariance};
    T = table();
    for k = 1:numel(labels)
        r = pts.GPMean(k, :) - at.GPMean;
        for m = 1:size(models, 1)
            s2 = models{m, 2};
            row = [table(string(labels{k}), string(models{m, 1}), 0.5 * sum(r.^2 ./ s2), ...
                'VariableNames', {'Point', 'NoiseModel', 'Delta'}), ...
                array2table(r, 'VariableNames', strcat('MeanDifference_', outputs)), ...
                array2table(s2, 'VariableNames', strcat('Variance_', outputs))];
            T = [T; row]; %#ok<AGROW>
        end
    end
end

function T = draw_shares(cfg, S, unit, B, truth)
%DRAW_SHARES The share of the retained draws of the case's cells within the neighbourhood of B and of the truth.
    T = table();
    for k = 1:numel(S.shareScenarios)
        record = struct('caseID', S.caseID, 'scenario', S.shareScenarios{k}, 'design', S.design);
        [A, status] = recovery.load_posterior_provider(cfg, record);
        if ~(status.loaded && status.valid)
            T = [T; share_row(record, NaN, status.state, NaN, NaN, NaN, S.neighbourhood)]; %#ok<AGROW>
            continue;
        end
        level = double(A.request.stepCount);
        for r = 1:2
            [R, s] = recovery.load_posterior_provider(cfg, record, 'AIES', r, level);
            if ~(s.loaded && s.valid), continue; end
            U = unit(double(R.drawsPhysical));
            nearB = mean(all(abs(U - unit(B)) <= S.neighbourhood, 2));
            nearTruth = mean(all(abs(U - unit(truth)) <= S.neighbourhood, 2));
            T = [T; share_row(record, r, status.state, size(U, 1), nearB, nearTruth, S.neighbourhood)]; %#ok<AGROW>
        end
    end
end

function row = share_row(record, replicate, state, count, nearB, nearTruth, neighbourhood)
    row = table(string(record.scenario), string(record.design), replicate, string(state), count, nearB, ...
        nearTruth, neighbourhood, 'VariableNames', {'Scenario', 'Design', 'Replicate', 'State', 'DrawCount', ...
        'ShareNearB', 'ShareNearTruth', 'Neighbourhood'});
end

function T = direction_angles(cfg, S, d)
%DIRECTION_ANGLES The angles between the direction D (prior widths) and the case's posterior eigendirections.
%   From this run's eigen-analysis when it covers the case, else from the
%   shipped one (a run that reads the shipped draws); empty when neither has
%   the case.
    candidates = {fullfile(cfg.paths.posteriorEigendecomposition, 'posterior_eigendirections.csv'), "this run"};
    if isfield(cfg, 'native') && isfield(cfg.native, 'shippedDraws')
        candidates(end+1, :) = {fullfile(cfg.native.shippedDraws.results, 'fixed', '05_recovery', 'data', ...
            'eigen_analysis', 'posterior_eigendirections.csv'), "shipped"};
    end
    T = table();
    rows = table();
    for c = 1:size(candidates, 1)
        if ~isfile(candidates{c, 1}), continue; end
        E = utils.read_csv_table(candidates{c, 1}, {'Scenario', 'Design', 'DirectionLabel'});
        rows = E(E.CaseID == S.caseID & E.Scenario == string(S.directionScenario) & ...
            E.Design == string(S.design), :);
        source = candidates{c, 2};
        if ~isempty(rows), break; end
    end
    if isempty(rows), return; end
    loadings = rows{:, startsWith(rows.Properties.VariableNames, 'Loading_')};
    d = d / norm(d);
    names = {'Scenario', 'Design', 'DirectionRank', 'DirectionLabel', 'Eigenvalue', 'AngleDegrees', 'Source'};
    for k = 1:height(rows)
        v = loadings(k, :) / norm(loadings(k, :));
        angle = acosd(min(1, abs(d * v.')));
        T = [T; table(rows.Scenario(k), rows.Design(k), rows.DirectionRank(k), rows.DirectionLabel(k), ...
            rows.Eigenvalue(k), angle, source, 'VariableNames', names)]; %#ok<AGROW>
    end
    if height(rows) >= 2
        % The sloppy two-dimensional subspace: the directions of the two largest eigenvalues.
        [~, order] = sort(rows.Eigenvalue, 'descend');
        V = orth(loadings(order(1:2), :).');
        angle = acosd(min(1, norm(V.' * d.')));
        T = [T; table(rows.Scenario(1), rows.Design(1), NaN, "sloppy_2d_subspace", NaN, angle, source, ...
            'VariableNames', names)];
    end
end

function T = weak_pair_angles(cfg, S, d)
%WEAK_PAIR_ANGLES The angles between the direction D (prior widths) and the case's combinations of the weak pair.
%   From the parameter combinations (recovery.parameter_combinations) of this
%   run when they cover the case, else from the shipped ones: the best- and the
%   worst-determined combination of the weak pair of replicate 1 of the cell
%   in directionScenario (the cell's design), as directions of the four
%   parameters (zero weight on the other two), the angle between D and the
%   plane of the pair, and within that plane the angle between D's projection
%   and the worst-determined combination. Eigenvalue: the combination's
%   squared SD ratio. Empty when neither run nor shipped results have the cell.
    T = table();
    candidates = cell(0, 2);
    if isfield(cfg.paths, 'combinations')
        candidates(end+1, :) = {fullfile(cfg.paths.combinations, 'cells.csv'), "this run"};
    end
    if isfield(cfg, 'native') && isfield(cfg.native, 'shippedDraws')
        candidates(end+1, :) = {fullfile(cfg.native.shippedDraws.results, 'fixed', '05_recovery', 'data', ...
            'combinations', 'cells.csv'), "shipped"};
    end
    row = table(); source = "";
    for c = 1:size(candidates, 1)
        if ~isfile(candidates{c, 1}), continue; end
        C = utils.read_csv_table(candidates{c, 1}, {'Scenario', 'Design', 'Status', 'LogFormReason'});
        row = C(C.CaseID == S.caseID & C.Scenario == string(S.directionScenario) & ...
            C.Design == string(S.design) & C.Replicate == 1, :);
        source = candidates{c, 2};
        if ~isempty(row), break; end
    end
    if isempty(row), return; end
    names = cellstr(string(cfg.paramNames));
    weak = cfg.analysis.weakPairIndices;
    d = reshape(d, 1, []) / norm(d);
    columns = {'Scenario', 'Design', 'DirectionRank', 'DirectionLabel', 'Eigenvalue', 'AngleDegrees', 'Source'};
    one = @(label, eigenvalue, angle) table(row.Scenario, row.Design, NaN, string(label), eigenvalue, angle, ...
        source, 'VariableNames', columns);
    worst = [row.(['Worst_w_' names{weak(1)}]), row.(['Worst_w_' names{weak(2)}])];
    combinations = struct('label', {'weak_pair_best_combination', 'weak_pair_worst_combination'}, ...
        'w', {[row.(['Best_w_' names{weak(1)}]), row.(['Best_w_' names{weak(2)}])], worst}, ...
        'sd', {row.Best_SDRatio, row.Worst_SDRatio});
    for k = 1:numel(combinations)
        w = zeros(1, numel(names)); w(weak) = combinations(k).w;
        T = [T; one(combinations(k).label, combinations(k).sd^2, acosd(min(1, abs(d * w.') / norm(w))))]; %#ok<AGROW>
    end
    inPlane = d(weak);
    T = [T; one('weak_pair_plane', NaN, acosd(min(1, norm(inPlane))))];
    if norm(inPlane) > 0
        T = [T; one('weak_pair_worst_combination_in_plane', row.Worst_SDRatio^2, ...
            acosd(min(1, abs(inPlane * worst.') / (norm(inPlane) * norm(worst)))))];
    end
end

function T = comsol_neighbours(cfg, S, unit, names)
%COMSOL_NEIGHBOURS The cases of the fixed dataset whose COMSOL pressures lie closest to the case's.
    d = utils.load_plain_mat(cfg.files.dataset, 'X_train', 'Y_train', 'trainCaseIDs', 'X_validation', 'Y_validation', ...
        'validationCaseIDs', 'developmentOutputAvailability', 'externalOutputAvailability');
    X = [d.X_train; d.X_validation];
    Y = [d.Y_train; d.Y_validation];
    available = [d.developmentOutputAvailability; d.externalOutputAvailability] & isfinite(Y);
    ids = [d.trainCaseIDs(:); d.validationCaseIDs(:)];
    split = [repmat("development", numel(d.trainCaseIDs), 1); repmat("external", numel(d.validationCaseIDs), 1)];
    me = find(ids == S.caseID);
    assert(isscalar(me), 'recovery:second_mode_check:Case', 'Case %d is not in the fixed dataset.', S.caseID);
    scale = cfg.meas_cv * Y(me, :);
    distance = nan(numel(ids), 1); compared = zeros(numel(ids), 1);
    for i = 1:numel(ids)
        both = available(i, :) & available(me, :);
        compared(i) = nnz(both);
        if i == me || ~any(both), continue; end
        distance(i) = sqrt(mean(((Y(i, both) - Y(me, both)) ./ scale(both)).^2));
    end
    [~, order] = sort(distance);
    order = order(isfinite(distance(order)));
    order = order(1:min(S.comsolNeighbours, numel(order)));
    delta = unit(X(order, :)) - unit(X(me, :));
    T = [table((1:numel(order)).', ids(order), split(order), distance(order), compared(order), ...
        'VariableNames', {'Rank', 'CaseID', 'Split', 'PressureDistance', 'OutputsCompared'}), ...
        array2table(X(order, :), 'VariableNames', names), ...
        array2table(delta, 'VariableNames', strcat('FromCase_', names)), ...
        table(max(abs(delta), [], 2), 'VariableNames', {'ParameterDistance'})];
end

function record = finish(out, S, cellRecord, provider, verdict, numbers, files, walkers, groups)
%FINISH Write the walker tables and the record of the check.
    write(out, 'walkers.csv', walkers);
    write(out, 'walker_groups.csv', groups);
    record = struct('schema_version', 'second_mode_check_v1', ...
        'cell', struct('caseID', S.caseID, 'scenario', S.scenario, 'design', S.design, ...
        'state', provider.state, 'certified', provider.certified, 'stepCount', cellRecord.stepCount), ...
        'class', verdict, 'numbers', numbers, ...
        'rule', S.classification, 'settings', rmfield(S, 'classification'), ...
        'files', {[{'walkers.csv', 'walker_groups.csv'}, files]}, ...
        'mcmc_runs_performed', 0, 'status_changed', false);
    utils.atomic_write_json(fullfile(out, 'second_mode_check.json'), record, 'AllowReplace', true);
end

function write(out, name, T)
    utils.atomic_write_table(fullfile(out, name), T);
end
