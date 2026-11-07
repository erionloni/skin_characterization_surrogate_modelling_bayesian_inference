function [S_first,S_total,S2,names,groups] = derived_sobol(model,P,cfg)
%DERIVED_SOBOL Sobol indices for deterministic transforms of raw pressures.
%   Every ratio/drop is evaluated from the same six-output surrogate prediction
%   at each A/B/hybrid design point.
%   [S_FIRST, S_TOTAL, S2, NAMES, GROUPS] = sensitivity.derived_sobol(MODEL,
%   P, CFG) returns the Sobol indices of the 16 derived features
%   (sensitivity.derived_features) of the surrogate MODEL's mean
%   prediction, with the settings of CFG (sensitivity.sobol_evaluator).
%   Side effects: creates UQLab objects in the session and draws the Monte
%   Carlo sample from the current random number generator.
%   Computation: minutes (UQLab predictions).

    % The fixed route evaluates each Sobol sample in one call; the
    % generalized route in batches of the settings' size (0.3).
    batchSize=Inf;
    if strcmp(cfg.dataMode,'real_extended')
        batchSize=cfg.realExtended.predictionBatchSize;
    end
    evaluator = @(X) derived_from_model(model,X,batchSize);
    [S_first,S_total,S2] = sensitivity.sobol_evaluator(evaluator,P,cfg);
    [~,names,groups] = sensitivity.derived_features(ones(1,6));
end

function D = derived_from_model(model,X,batchSize)
    Y = surrogates.evaluate(model,X,'mean',batchSize);
    D = sensitivity.derived_features(Y);
end
