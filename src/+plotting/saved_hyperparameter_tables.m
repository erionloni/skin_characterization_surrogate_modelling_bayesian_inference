function manifest = saved_hyperparameter_tables(cfg, ~)
%SAVED_HYPERPARAMETER_TABLES The fitted hyperparameters of the GP surrogates, one row per closing pressure.
%   MANIFEST = plotting.saved_hyperparameter_tables(CFG, OPTIONS) writes the
%   table gp_hyperparameters (CSV) into the
%   tables/ folder of the analysis 02_surrogates of the route
%   CFG.layout.route, from the saved results:
%     fixed route        the GP's fit record gpInfo in
%                        data/models/gp_surrogate.mat (the production
%                        GP in thesis_results/, or a rerun's own fit);
%     generalized route  data/surrogates/final_candidate_hyperparameters.csv,
%                        the record of the approved Matern-3/2 GP (thesis_results/),
%                        or, in a rerun that refitted the GP,
%                        canonical_gp_hyperparameters.csv of that refit.
%   Per output: kernel, optimizer, nugget, fit seed, the ARD length scale
%   theta of every input (UQLab's normalized input coordinates,
%   dimensionless) and the process variance (mbar^2); from the approved
%   generalized record also the constant trend coefficient beta (mbar),
%   which the other records do not hold. Every number is copied from the
%   saved record; nothing is recomputed, and UQLab is not needed. Last, one
%   flag per length scale, AtUpperBound_<input>: 1 when theta lies above
%   CFG.fig.thetaAtUpperBound (settings 0.4), at the upper bound 10 of
%   UQLab's optimization, which the fits keep.
%   MANIFEST is an empty figure manifest (tables only). OPTIONS is unused.
%   Outside reproduce mode (no CFG.layout) it does nothing.
%   Side effects: writes the table (CSV) and enters it in the index of the analysis.
%   Computation: seconds.

    manifest = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', ...
        'SourceArtifacts'});
    if ~study.is_publication(cfg), return; end
    folder = study.source_folder(cfg, 'surrogate_models');
    switch cfg.layout.route
        case 'fixed'
            pathValue = fullfile(folder, 'gp_surrogate.mat');
            T = fixed_table(pathValue);
            model = 'the fixed route''s GP';
        case 'generalized'
            pathValue = fullfile(folder, 'final_candidate_hyperparameters.csv');
            if isfile(pathValue)
                T = approved_table(pathValue);
                model = 'the approved Matern-3/2 GP of the generalized route';
            else
                pathValue = fullfile(folder, 'canonical_gp_hyperparameters.csv');
                T = refit_table(pathValue);
                model = 'the refitted GP of the generalized route';
            end
        otherwise
            return;
    end
    limit = double(cfg.fig.thetaAtUpperBound);
    T = flag_upper_bound(T, limit);
    study.export_table(cfg, 'surrogate', 'gp_hyperparameters', T, {pathValue}, ...
        sprintf(['Hyperparameters of %s, one row per closing pressure: ARD length ' ...
        'scales theta in UQLab''s normalized input coordinates (dimensionless), ' ...
        'process variance in mbar^2; AtUpperBound_<input> 1 for a theta above %g, at the ' ...
        'upper bound 10 of the optimization'], model, limit),[]);
end

function T = flag_upper_bound(T, limit)
%FLAG_UPPER_BOUND One flag per length scale: 1 when theta lies above LIMIT (settings 0.4).
    names = string(T.Properties.VariableNames(startsWith(T.Properties.VariableNames, 'Theta_')));
    for k = 1:numel(names)
        T.("AtUpperBound_" + extractAfter(names(k), "Theta_")) = double(T.(names(k)) > limit);
    end
end

function T = fixed_table(pathValue)
%FIXED_TABLE The fit record gpInfo of the fixed GP as one row per output.
    assert(isfile(pathValue), 'plotting:saved_hyperparameter_tables:MissingModel', ...
        'The fixed GP %s is missing; rerun the step ''surrogates''.', pathValue);
    S = load(pathValue, 'gpInfo');
    assert(isfield(S, 'gpInfo'), 'plotting:saved_hyperparameter_tables:MissingRecord', ...
        'The fixed GP %s holds no fit record gpInfo; rerun the step ''surrogates''.', ...
        pathValue);
    info = S.gpInfo;
    inputs = string(info.inputOrder(:)).';
    Output = string(info.outputOrder(:));
    n = numel(Output);
    if isfield(info, 'childSeeds')
        FitSeed = double(info.childSeeds(:));
    else
        FitSeed = repmat(double(info.randomNumberStream.componentSeed), n, 1);
    end
    T = table(Output, repmat(string(info.kernel), n, 1), ...
        repmat(string(info.optimMethod), n, 1), repmat(double(info.nugget), n, 1), ...
        FitSeed, 'VariableNames', {'Output', 'Kernel', 'Optimizer', 'Nugget', 'FitSeed'});
    theta = double(info.ardThetaUQLabNormalizedCoordinates);
    for k = 1:numel(inputs)
        T.("Theta_" + inputs(k)) = theta(:, k);
    end
    T.ProcessVariance_mbar2 = double(info.processVarianceMbar2(:));
end

function T = approved_table(pathValue)
%APPROVED_TABLE The approved model's long record (one row per output and input) as one row per output.
    H = readtable(pathValue, 'Delimiter', ',', 'TextType', 'string', ...
        'VariableNamingRule', 'preserve');
    outputIndex = unique(H.OutputIndex, 'sorted');
    inputs = sortrows(unique(H(:, {'InputIndex', 'Input'}), 'rows'), 'InputIndex');
    n = numel(outputIndex);
    Output = strings(n, 1); Kernel = strings(n, 1); Optimizer = strings(n, 1);
    Nugget = nan(n, 1); FitSeed = nan(n, 1); variance = nan(n, 1); beta = nan(n, 1);
    theta = nan(n, height(inputs));
    for i = 1:n
        rows = sortrows(H(H.OutputIndex == outputIndex(i), :), 'InputIndex');
        assert(isequal(rows.InputIndex, inputs.InputIndex), ...
            'plotting:saved_hyperparameter_tables:Inputs', ...
            'Output %d of %s does not list every input once.', outputIndex(i), pathValue);
        Output(i) = rows.Output(1); Kernel(i) = rows.Kernel(1);
        Optimizer(i) = rows.Optimizer(1); Nugget(i) = rows.Nugget(1);
        FitSeed(i) = rows.FitSeed(1); variance(i) = rows.ProcessVariance(1);
        beta(i) = rows.TrendCoefficients(1);
        theta(i, :) = rows.Theta.';
    end
    T = table(Output, Kernel, Optimizer, Nugget, FitSeed);
    for k = 1:height(inputs)
        T.("Theta_" + inputs.Input(k)) = theta(:, k);
    end
    T.ProcessVariance_mbar2 = variance;
    T.TrendBeta_mbar = beta;
end

function T = refit_table(pathValue)
%REFIT_TABLE The hyperparameter table of a generalized refit (surrogates.fit_generalized).
    assert(isfile(pathValue), 'plotting:saved_hyperparameter_tables:MissingRecord', ...
        ['The generalized hyperparameter record is missing (%s); run the step ' ...
         '''surrogates''.'], pathValue);
    R = readtable(pathValue, 'Delimiter', ',', 'TextType', 'string', ...
        'VariableNamingRule', 'preserve');
    T = table(R.Output, R.Kernel, R.Optimizer, R.Nugget, R.FullFitComponentSeed, ...
        'VariableNames', {'Output', 'Kernel', 'Optimizer', 'Nugget', 'FitSeed'});
    names = R.Properties.VariableNames(startsWith(R.Properties.VariableNames, 'Theta_'));
    for k = 1:numel(names)
        T.(names{k}) = R.(names{k});
    end
    T.ProcessVariance_mbar2 = R.ProcessVariance_mbar2;
end
