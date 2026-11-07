function [seed, source] = surrogate_fit(cfg, route, model, output, degree, fold)
%SURROGATE_FIT The seed of one surrogate fit.
%   [SEED, SOURCE] = seeds.surrogate_fit(CFG, ROUTE, MODEL, OUTPUT, DEGREE,
%   FOLD) returns the seed of a fit of the route ROUTE ('fixed' or
%   'generalized'): MODEL 'gp' or 'pce' for output OUTPUT (1-6), DEGREE the
%   polynomial degree of a generalized PCE candidate ([] otherwise), FOLD 0
%   for the fit on all development cases or the cross-validation fold; MODEL
%   'cv_folds' (OUTPUT, DEGREE and FOLD []) the seed of the generalized
%   route's shared assignment of material groups to folds.
%   The seeds of the thesis fits are recorded in
%   config/seeds/surrogate_fit_seeds.csv (cfg.seeds.tables.surrogateFits;
%   the fixed GP of output 6 has the reviewed seed 221754153, the medoid of
%   five same-data fits of the surrogate audit). A fit without a recorded
%   seed (a cross-validation fold of a generalized GP, a new PCE degree)
%   takes the seed of the rule cfg.seeds.rules.surrogateFit:
%       base + route * (1 fixed, 2 generalized) + model * (1 GP, 2 PCE,
%       0 fold assignment) + output * OUTPUT + degree * DEGREE + fold * FOLD.
%   SOURCE is 'recorded' or 'rule'.
%   Side effects: none (reads the recorded table once per session).

    route = char(string(route));
    model = char(string(model));
    routeNumber = find(strcmp({'fixed', 'generalized'}, route));
    modelNumber = find(strcmp({'cv_folds', 'gp', 'pce'}, model)) - 1;
    assert(isscalar(routeNumber) && isscalar(modelNumber), 'seeds:surrogate_fit:Fit', ...
        'Unknown surrogate fit: route %s, model %s.', route, model);
    seed = seeds.recorded(cfg, 'surrogateFits', struct('Route', route, 'Model', model, ...
        'Output', output, 'Degree', degree, 'Fold', fold));
    source = 'recorded';
    if isnan(seed)
        source = 'rule';
        numbers = struct('route', routeNumber, 'model', modelNumber, 'output', ...
            zero_if_empty(output), 'degree', zero_if_empty(degree), 'fold', zero_if_empty(fold));
        seed = seeds.rule(cfg.seeds.rules.surrogateFit, numbers);
        seeds.check_new(cfg, seed, sprintf('the %s %s fit of output %d, degree %d, fold %d', ...
            route, model, numbers.output, numbers.degree, numbers.fold));
    end
end

function value = zero_if_empty(value)
    if isempty(value), value = 0; end
end
