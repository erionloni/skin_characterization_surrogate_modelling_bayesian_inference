function result = parameter_combinations(cfg)
%PARAMETER_COMBINATIONS Which combinations of the parameters the posteriors determine, and the compensation behind them.
%   RESULT = recovery.parameter_combinations(CFG) reads, for every cell of
%   the settings (A.12: cases, scenarios, design all_six), the posterior of
%   the selected provider (recovery.load_posterior_provider: this run's
%   campaign or the shipped full draws, certified or a healthy fallback)
%   and analyses each replicate on its own (never pooled), in the
%   prior-standardized coordinates of the recovery's eigen-analysis,
%   z = (theta - prior mean) / prior SD: a unit-length combination w'z has
%   prior variance 1, and its SD ratio (posterior SD over prior SD) is
%   sqrt(w' C_z w).
%     four-dimensional  the eigen-directions of C_z
%                       (recovery.posterior_covariance_eigensystem, the
%                       thresholds of A.7) with their SD ratios; the
%                       tightest is the best-determined combination
%     weak pair         the eigen-directions of the 2 x 2 block of C_z of
%                       the weak pair (A.7): the best- and the
%                       worst-determined combination, next to the individual
%                       SD ratios; "identified combination" when the best SD
%                       ratio is at most the settings' factor times the
%                       smaller individual one (a description, not a test).
%                       Weights of the weak pair: the first one
%                       non-negative; each also per unit of the model
%                       coordinate (weight / prior SD)
%     log form          the same in log coordinates: the natural log of the
%                       settings' parameters (the other weak-pair parameter
%                       enters as its model coordinate, log10 k0 for the
%                       thesis), each standardized by its prior mean and SD
%                       from the prior sample, and as the power law
%                       m3e^a k0^b (exponents on the natural logs) when every
%                       coordinate is a logarithm. A cell uses it when every
%                       draw of both replicates is positive and each
%                       replicate's quantile of the settings lies at least
%                       the settings' share of the prior range above the
%                       lower bound; otherwise it is not applicable, and the
%                       reason is recorded
%     marginals         for each best combination (four-dimensional, weak
%                       pair, its log form) the projected draws u = w'z
%                       against the prior sample's u and the truth's: SD
%                       ratio and 95 % width ratio from the draws, the truth
%                       inside the central 50 % and 95 % intervals, and the
%                       density estimates the figures draw
%                       (plotting.posterior_marginal_density)
%   and per cell, at the truth, the compensation predicted by the GP: the
%   Jacobian of the six GP means whitened by the scenario's observation
%   covariance at the truth (design_study.finite_difference_jacobian with
%   the design study's step, A.8), in the same coordinates: the angle
%   between the sensitivity vectors of the weak pair (near 180 degrees: a
%   change of one is undone by the same change of the other), the
%   collinearity index of Brun, Reichert and Kuensch (2001) of the pair and
%   of all four parameters, and the least-informative direction of the pair
%   (the 2 x 2 block of the Fisher information: the other two parameters at
%   the truth) with its angle to each replicate's worst-determined
%   weak-pair direction. Across the cells of a scenario and replicate: the
%   consensus of each best combination (recovery.consensus_projector), each
%   cell's angle to it and the spread, for all cells and for the certified
%   ones alone.
%   Writes below CFG.paths.combinations:
%     cohort.csv      the cells: status, provider, replicates and their draws
%     cells.csv       per cell and replicate: the combinations, SD ratios,
%                     labels, the log form, the compensation and the angles
%     directions.csv  per cell, replicate and direction: the four-dimensional
%                     eigen-directions (loadings, SD ratios)
%     marginals.csv   per cell, replicate and best combination: the formula
%                     and the summaries of its marginal and of its prior
%     densities.csv   the same rows: the posterior density (on the range of
%                     the draws) and the prior density (on the prior
%                     support), the curves of the marginal figures
%     consensus.csv   per scenario, replicate and best combination: the
%                     consensus, the spread of the directions, medians and
%                     counts; the certified cells alone in the columns
%                     ending in _certified_only
%   The projected draws are not stored: the shipped draws give them again.
%   The parts that the confirmation's combinations share (the prior sample,
%   the log-form check, the analysis of one replicate, its row of cells.csv,
%   the consensus) are in recovery.combination_support.
%   Side effects: writes the files above.
%   Computation: about a minute (every draw of each cell; the GP at the truths).

    C = cfg.analysis.combinations;
    names = reshape(cellstr(string(cfg.paramNames)), 1, []);
    bounds = double(cfg.paramBounds);
    weak = reshape(double(cfg.analysis.weakPairIndices), 1, []);
    E = cfg.analysis.posteriorEigendecomposition;
    eigenOptions = {'NearDegenerateGap', E.nearDegenerateGapThreshold, ...
        'NegativeEigenvalueTolerance', E.negativeEigenvalueTolerance, 'SymmetryTolerance', E.symmetryTolerance};
    forms = log_forms(cfg, C, names, weak);
    support = @recovery.combination_support;
    prior = support('prior_sample', C, bounds, weak, forms.logged);
    saved = load(cfg.files.gp, 'gp');
    records = cell_records(cfg, C);
    cohortRows = cell(numel(records), 1);
    cellParts = {}; directionParts = {}; marginalParts = {}; densityParts = {};
    for k = 1:numel(records)
        record = records(k);
        [P, status] = recovery.load_posterior_provider(cfg, record);
        if ~status.loaded
            cohortRows{k} = cohort_row(record, status, [], [0 0], "no posterior: " + string(status.reason));
            continue;
        end
        provider = P.certification.provider;
        truth = reshape(double(P.truth), 1, []);
        replicates = cell(1, 2); counts = [0 0]; notes = strings(1, 0);
        for r = 1:2
            [R, s] = recovery.load_posterior_provider(cfg, record, char(string(provider.sampler)), r, ...
                double(provider.stepCount));
            if ~s.loaded
                notes(end+1) = sprintf('replicate %d not available: %s', r, s.reason); %#ok<AGROW>
                continue;
            end
            replicates{r} = double(R.drawsPhysical);
            counts(r) = size(replicates{r}, 1);
        end
        [logValid, logReason] = support('log_form_check', replicates, weak, forms.logged, names, bounds, ...
            C.logForm);
        K = compensation(cfg, saved.gp, truth, record.scenario, weak, bounds);
        state = state_of(status);
        for r = find(counts > 0)
            A = support('replicate_analysis', replicates{r}, truth, bounds, names, weak, prior, forms, ...
                logValid, C, eigenOptions);
            if ~A.valid
                notes(end+1) = sprintf('replicate %d: %s', r, A.reason); %#ok<AGROW>
                continue;
            end
            key = key_table(record, state, r);
            cellParts{end+1, 1} = [key, support('cell_columns', A, K, names, weak, forms, prior, ...
                logReason)]; %#ok<AGROW>
            directionParts{end+1, 1} = [repmat(key, height(A.directions), 1), A.directions]; %#ok<AGROW>
            marginalParts{end+1, 1} = [repmat(key, height(A.marginals), 1), A.marginals]; %#ok<AGROW>
            densityParts{end+1, 1} = [repmat(key, height(A.densities), 1), A.densities]; %#ok<AGROW>
        end
        cohortRows{k} = cohort_row(record, status, provider, counts, strjoin(notes, '; '));
    end
    assert(~isempty(cellParts), 'recovery:parameter_combinations:NoPosterior', ...
        'No cell of the settings (A.12) has a posterior to analyse in this run.');
    cohort = vertcat(cohortRows{:});
    cells = vertcat(cellParts{:});
    [consensus, cells] = support('consensus_rows', cells, names, weak, prior, forms, {'Scenario'});
    root = cfg.paths.combinations;
    if ~isfolder(root), mkdir(root); end
    utils.atomic_write_table(fullfile(root, 'cohort.csv'), cohort);
    utils.atomic_write_table(fullfile(root, 'cells.csv'), cells);
    utils.atomic_write_table(fullfile(root, 'directions.csv'), vertcat(directionParts{:}));
    utils.atomic_write_table(fullfile(root, 'marginals.csv'), vertcat(marginalParts{:}));
    utils.atomic_write_table(fullfile(root, 'densities.csv'), vertcat(densityParts{:}));
    utils.atomic_write_table(fullfile(root, 'consensus.csv'), consensus);
    result = struct('cells', height(cohort), 'replicates', height(cells), 'root', root);
end

function records = cell_records(cfg, C)
%CELL_RECORDS The cells of the settings: every selected case in every selected scenario, design all_six.
    cases = reshape(double(cfg.inversion.caseIDs), 1, []);
    if ~((ischar(C.cases) || isstring(C.cases)) && strcmp(char(C.cases), 'all'))
        cases = reshape(double(C.cases), 1, []);
    end
    records = struct('cellID', {}, 'caseID', {}, 'scenario', {}, 'design', {});
    for scenario = reshape(cellstr(string(C.scenarios)), 1, [])
        for c = cases
            records(end+1) = struct('cellID', sprintf('case_%d|%s|%s', c, scenario{1}, C.design), ...
                'caseID', c, 'scenario', scenario{1}, 'design', char(C.design)); %#ok<AGROW>
        end
    end
end

function F = log_forms(cfg, C, names, weak)
%LOG_FORMS How each weak-pair coordinate enters the log form.
%   logged(j): the natural log of the j-th weak-pair parameter (the
%   settings' log-form parameters); log10(j): its model coordinate is the
%   log10 of a dataset column (A.1, fixed.dataset.logColumn), whose name
%   the power law uses; powerLaw: every coordinate is a logarithm.
    F.logged = ismember(names(weak), cellstr(string(C.logForm.parameters)));
    F.log10 = false(1, 2);
    F.physicalNames = names(weak);
    if isfield(cfg, 'realData') && isfield(cfg.realData, 'k0Col') && ~isempty(cfg.realData.k0Col)
        F.log10 = weak == cfg.realData.k0Col & ~F.logged;
        F.physicalNames(F.log10) = cfg.realData.inputCols(cfg.realData.k0Col);
    end
    F.powerLaw = all(F.logged | F.log10);
    F.labels = strcat('z(', names(weak), ')');
    F.logLabels = F.labels;
    F.logLabels(F.logged) = strcat('z(ln ', names(weak(F.logged)), ')');
end

function K = compensation(cfg, gp, truth, scenario, weak, bounds)
%COMPENSATION The weak pair's compensation predicted at the truth by the GP's whitened Jacobian.
    policy = design_study.real_scenario_policy(scenario);
    lower = bounds(:, 1).'; width = (bounds(:, 2) - bounds(:, 1)).';
    prediction = surrogates.evaluate_canonical_gp(gp, truth, cfg);
    variance = inversion.raw_observation_variance(prediction.GPMean, prediction.CalibratedEmulatorVariance, ...
        cfg, struct('uncertaintyMode', policy.uncertaintyMode, 'measurementCV', cfg.meas_cv), 1:6);
    forward = @(u) gp_mean(gp, lower + reshape(u, 1, []) .* width, cfg);
    J = design_study.finite_difference_jacobian(forward, (truth - lower) ./ width, ...
        cfg.stage9.finiteDifferenceStep, diag(variance(:)));
    % From the unit box to the prior-standardized coordinates: du/dz is
    % 1/sqrt(12) for every parameter of a uniform prior.
    S = J.whitenedMatrix / sqrt(12);
    a = S(:, weak(1)); b = S(:, weak(2));
    K.angle = acosd(min(1, max(-1, (a.' * b) / (norm(a) * norm(b)))));
    K.collinearityPair = collinearity(S(:, weak));
    K.collinearityAll = collinearity(S);
    F = S(:, weak).' * S(:, weak);
    [V, D] = eig((F + F.') / 2);
    [~, order] = sort(real(diag(D)), 'ascend');
    K.leastInformative = recovery.combination_support('pair_sign', real(V(:, order(1))));
    K.stepDifference = max(J.relativeStepDifferenceWhitened);
end

function mu = gp_mean(gp, theta, cfg)
    prediction = surrogates.evaluate_canonical_gp(gp, theta, cfg);
    mu = prediction.GPMean;
end

function gamma = collinearity(S)
%COLLINEARITY The collinearity index of Brun, Reichert and Kuensch (2001) of the columns of S.
%   1 / sqrt(smallest eigenvalue of S~' S~), S~ the columns scaled to unit
%   length; 1 for orthogonal columns, Inf for linearly dependent ones.
    S = S ./ vecnorm(S);
    G = S.' * S;
    gamma = 1 / sqrt(max(min(eig((G + G.') / 2)), 0));
end

function T = key_table(record, state, r)
    T = table(double(record.caseID), string(record.scenario), string(record.design), string(state), r, ...
        'VariableNames', {'CaseID', 'Scenario', 'Design', 'Status', 'Replicate'});
end

function state = state_of(status)
    state = "unavailable";
    if status.loaded && status.certified, state = "certified";
    elseif status.loaded, state = "healthy fallback"; end
end

function T = cohort_row(record, status, provider, counts, note)
    sampler = ""; level = NaN; replicate = NaN;
    if ~isempty(provider)
        sampler = string(provider.sampler); level = double(provider.stepCount);
        if isfield(provider, 'replicateID'), replicate = double(provider.replicateID); end
    end
    T = table(double(record.caseID), string(record.scenario), string(record.design), state_of(status), ...
        sampler, level, replicate, nnz(counts > 0), counts(1), counts(2), string(note), ...
        'VariableNames', {'CaseID', 'Scenario', 'Design', 'Status', 'ProviderSampler', 'ProviderSteps', ...
        'ProviderReplicate', 'Replicates', 'Replicate1Draws', 'Replicate2Draws', 'Note'});
end
