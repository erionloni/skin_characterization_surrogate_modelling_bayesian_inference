function write_gp_mean_best_fit(cfg, preparation)
%WRITE_GP_MEAN_BEST_FIT The best fit of the GP-mean inversion per case, in the layout of thesis_results/.
%   study.write_gp_mean_best_fit(CFG, PREPARATION) computes, for every cell
%   of the GP-mean campaign PREPARATION (inversion.prepare_gp_mean_campaign),
%   the parameters at which the GP mean comes closest to the cell's
%   observation (inversion.gp_mean_best_fit with the search of settings
%   A.13: the scenario's answer, since its posterior is practically a
%   point; no sampler) and writes to <CFG.paths.gpMeanResults>/best_fit:
%     best_fit.csv       per case and parameter: the truth, theta*, the error
%                        theta* - truth and its absolute value over the prior
%                        width, the bounds and whether theta* lies on one;
%                        per case the objective at theta* and at the truth
%                        (sums of squared residuals, mbar^2), lsqnonlin's
%                        exit flag, the starts of the search, the distinct
%                        minima and the starts that reached the best one
%     residuals.csv      per case and output: the COMSOL pressure, the GP
%                        mean at theta* and at the truth and the residuals
%                        (pressure - GP mean), mbar
%     local_minima.csv   per case every distinct minimum, best first: its
%                        objective, the starts that reached it, the exit
%                        flag and its parameters
%   Model coordinates (log10 of the permeability) throughout. The GP is the
%   shipped one (CFG.files.gp), the observation the cell's (the held-out
%   COMSOL pressures of its design's outputs, as the campaign's cells use
%   them).
%   Files carry no hashes.
%   Side effects: writes the three files, replacing earlier versions;
%   changes the global random-number state.
%   Computation: per case one MultiStart search (about 2-3 minutes).

    folder = fullfile(cfg.paths.gpMeanResults, 'best_fit');
    if ~isfolder(folder), mkdir(folder); end
    saved = load(cfg.files.gp, 'gp');
    gp = saved.gp;
    P = parameters.parameter_space(cfg);
    names = string(P.names(:));
    lowerBound = P.bounds(:, 1); upperBound = P.bounds(:, 2); width = upperBound - lowerBound;
    outputNames = string(cfg.outputNames(:));
    options = cfg.gpMeanInversion.bestFit;
    records = preparation.cellRecords;
    fits = cell(numel(records), 1); minima = cell(numel(records), 1); residuals = cell(numel(records), 1);
    for k = 1:numel(records)
        record = records(k);
        design = inversion.design_registry(record.design);
        outputs = design.sourceOutputIndices;
        heldout = reshape(double(record.heldout_response), 1, []);
        observation = heldout(outputs);
        truth = reshape(double(record.truth), [], 1);
        fit = inversion.gp_mean_best_fit(gp, observation, P.bounds, options);
        atTruth = surrogates.evaluate(gp, truth.', 'mean');
        atTruth = atTruth(outputs);
        objectiveAtTruth = sum((observation - atTruth) .^ 2);
        n = numel(names);
        deviation = fit.theta(:) - truth;
        fits{k} = table(repmat(double(record.caseID), n, 1), names, truth, fit.theta(:), deviation, ...
            abs(deviation) ./ width, lowerBound, upperBound, fit.onLowerBound(:), fit.onUpperBound(:), ...
            repmat(fit.objective, n, 1), repmat(objectiveAtTruth, n, 1), repmat(fit.exitFlag, n, 1), ...
            repmat(fit.startsRun, n, 1), repmat(numel(fit.minima), n, 1), repmat(fit.startsAtBest, n, 1), ...
            repmat(fit.startsAgree, n, 1), 'VariableNames', {'CaseID', 'Parameter', 'TruthPhysical', ...
            'BestFitPhysical', 'ErrorPhysical', 'NormalizedAbsoluteError', 'LowerBound', 'UpperBound', ...
            'OnLowerBound', 'OnUpperBound', 'Objective', 'ObjectiveAtTruth', 'ExitFlag', 'StartsRun', ...
            'LocalMinima', 'StartsAtBest', 'StartsAgree'});
        m = numel(outputs);
        residuals{k} = table(repmat(double(record.caseID), m, 1), outputNames(outputs), observation(:), ...
            fit.gpMean(:), fit.residual(:), atTruth(:), observation(:) - atTruth(:), ...
            'VariableNames', {'CaseID', 'Output', 'ObservedPressure', 'GPMeanAtBestFit', ...
            'ResidualAtBestFit', 'GPMeanAtTruth', 'ResidualAtTruth'});
        q = numel(fit.minima);
        thetas = vertcat(fit.minima.Theta);
        minima{k} = [table(repmat(double(record.caseID), q, 1), (1:q).', [fit.minima.Objective].', ...
            [fit.minima.StartsReaching].', [fit.minima.ExitFlag].', repmat(fit.startsRun, q, 1), ...
            'VariableNames', {'CaseID', 'Minimum', 'Objective', 'StartsReaching', 'ExitFlag', 'StartsRun'}), ...
            array2table(thetas, 'VariableNames', cellstr(names))];
        fprintf(['[study] GP-mean best fit, case %d: objective %.4g mbar^2 (at the truth %.4g), %d minima, ' ...
            '%d of %d starts at the best\n'], record.caseID, fit.objective, objectiveAtTruth, q, ...
            fit.startsAtBest, fit.startsRun);
    end
    utils.atomic_write_table(fullfile(folder, 'best_fit.csv'), vertcat(fits{:}));
    utils.atomic_write_table(fullfile(folder, 'residuals.csv'), vertcat(residuals{:}));
    utils.atomic_write_table(fullfile(folder, 'local_minima.csv'), vertcat(minima{:}));
end
