function fit = gp_mean_best_fit(gp, observation, bounds, options)
%GP_MEAN_BEST_FIT The parameters at which the GP mean comes closest to an observation (least squares in the prior box).
%   FIT = inversion.gp_mean_best_fit(GP, OBSERVATION, BOUNDS, OPTIONS)
%   returns theta* = argmin over theta of sum_i (y_i - mu_i(theta))^2: the
%   observation Y (the six pressures, mbar) against the GP predictive mean
%   MU of the fixed GP ensemble GP (surrogates.evaluate, the mean of the
%   likelihood's GP evaluation), theta within BOUNDS (4 x 2, the prior
%   bounds in model coordinates: log10 of the permeability). With a uniform
%   variance this is the maximum of the scenario gp_mean_det's likelihood
%   and, under the uniform prior, of its posterior.
%   The search (settings A.13): lsqnonlin (trust-region-reflective) on the
%   six residuals y - mu, with the parameters scaled to [0, 1] (the bounds
%   [0, 1]) and the Jacobian by central differences of step
%   OPTIONS.jacobianStep (scaled coordinates), evaluated in one batched GP
%   call; inside MultiStart (serial) from OPTIONS.starts(1) start points of
%   a Latin hypercube (lhsdesign with its defaults, after rng(OPTIONS.seed,
%   'twister')). When fewer than OPTIONS.minimumStartsAtBest starts reach
%   the best minimum, the search runs again with the next number of
%   OPTIONS.starts (a new hypercube of that size from the same seed); the
%   last search is kept. MultiStart groups the local solutions into
%   distinct minima with OPTIONS.distinctXTolerance (scaled coordinates)
%   and OPTIONS.distinctFunctionTolerance.
%   OPTIONS: starts, minimumStartsAtBest, seed, functionTolerance,
%   stepTolerance, optimalityTolerance, maxIterations,
%   maxFunctionEvaluations, jacobianStep, distinctXTolerance,
%   distinctFunctionTolerance, boundTolerance.
%   FIT: theta (1 x 4, model coordinates), objective (the sum of squared
%   residuals, mbar^2), gpMean and residual (1 x 6: mu(theta*) and
%   y - mu(theta*)), exitFlag (lsqnonlin's exit flag of the best
%   minimum), onLowerBound and onUpperBound (1 x 4: theta*
%   within OPTIONS.boundTolerance of a bound, in scaled coordinates),
%   startsRun (the starts of the kept search), startsAtBest (the starts
%   that reached the best minimum), startsAgree (startsAtBest >=
%   OPTIONS.minimumStartsAtBest), searches (the starts of every search
%   run), localSolverRuns, and minima: one row per distinct minimum, best
%   first (Objective, StartsReaching, ExitFlag, Theta 1 x 4).
%   Side effects: changes the global random-number state (rng).
%   Computation: per search, starts x (a few dozen GP evaluations of nine
%   points each).

    bounds = double(bounds);
    lb = bounds(:, 1).'; width = (bounds(:, 2) - bounds(:, 1)).';
    y = reshape(double(observation), 1, []);
    M = numel(lb);
    assert(all(width > 0) && numel(y) == 6, 'inversion:gp_mean_best_fit:Input', ...
        'The bounds must be increasing and the observation must hold six pressures.');
    toTheta = @(u) lb + u .* width;
    solverOptions = optimoptions('lsqnonlin', 'Algorithm', 'trust-region-reflective', ...
        'SpecifyObjectiveGradient', true, 'Display', 'off', ...
        'FunctionTolerance', options.functionTolerance, 'StepTolerance', options.stepTolerance, ...
        'OptimalityTolerance', options.optimalityTolerance, 'MaxIterations', options.maxIterations, ...
        'MaxFunctionEvaluations', options.maxFunctionEvaluations);
    problem = createOptimProblem('lsqnonlin', 'objective', @residuals, 'x0', 0.5 * ones(1, M), ...
        'lb', zeros(1, M), 'ub', ones(1, M), 'options', solverOptions);
    search = MultiStart('Display', 'off', 'UseParallel', false, 'StartPointsToRun', 'all', ...
        'XTolerance', options.distinctXTolerance, 'FunctionTolerance', options.distinctFunctionTolerance);
    starts = reshape(double(options.starts), 1, []);
    searches = zeros(1, 0);
    for n = starts
        rng(options.seed, 'twister');
        startPoints = lhsdesign(n, M);
        [u, objective, ~, output, solutions] = run(search, problem, CustomStartPointSet(startPoints));
        searches(end+1) = n; %#ok<AGROW>
        assert(~isempty(solutions), 'inversion:gp_mean_best_fit:NoSolution', ...
            'No local search from the %d start points ended with a solution.', n);
        startsAtBest = numel(solutions(1).X0);
        if startsAtBest >= options.minimumStartsAtBest, break; end
    end
    theta = toTheta(u);
    gpMean = surrogates.evaluate(gp, theta, 'mean');
    minima = struct('Objective', {}, 'StartsReaching', {}, 'ExitFlag', {}, 'Theta', {});
    for k = 1:numel(solutions)
        minima(k) = struct('Objective', solutions(k).Fval, 'StartsReaching', numel(solutions(k).X0), ...
            'ExitFlag', solutions(k).Exitflag, 'Theta', toTheta(solutions(k).X));
    end
    fit = struct('theta', theta, 'objective', objective, 'gpMean', gpMean, 'residual', y - gpMean, ...
        'exitFlag', solutions(1).Exitflag, 'onLowerBound', u <= options.boundTolerance, ...
        'onUpperBound', u >= 1 - options.boundTolerance, 'startsRun', searches(end), ...
        'startsAtBest', startsAtBest, 'startsAgree', startsAtBest >= options.minimumStartsAtBest, ...
        'searches', searches, 'localSolverRuns', output.localSolverTotal, 'minima', minima);

    function [r, J] = residuals(u)
        % y - mu at u (scaled) and its Jacobian by central differences, in one GP call.
        h = options.jacobianStep;
        points = [u; u + h * eye(M); u - h * eye(M)];
        mu = surrogates.evaluate(gp, toTheta(points), 'mean');
        r = reshape(y - mu(1, :), [], 1);
        J = -(mu(2:M + 1, :) - mu(M + 2:end, :)).' / (2 * h);
    end
end
