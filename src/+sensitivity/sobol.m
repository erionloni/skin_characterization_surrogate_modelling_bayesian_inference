function [S_first, S_total, S2] = sobol(model, P, cfg)
%SOBOL Canonical Sobol sensitivity indices for a surrogate model.
%   [S_first, S_total] = SOBOL(model, P, cfg) runs UQLab's built-in
%   Sensitivity/Sobol analysis on a (multi-output) GP or PCE metamodel and
%   returns the first- and total-order indices as [nOutputs x nInputs]
%   matrices (rows = closing pressures, columns = parameters).
%
%   [S_first, S_total, S2] = SOBOL(...) additionally returns the higher-order
%   indices up to cfg.sobol.order. For order >= 2, S2 holds the second-order
%   (pairwise interaction) indices:
%       S2.indices    [nOutputs x nPairs]  second-order Sobol index per output
%       S2.pairs      [nPairs x 2]         the two input indices of each pair
%       S2.pairLabels {nPairs x 1}         human-readable 'm3_f_RD x m3_e_RD' labels
%   S2 is empty-valued when cfg.sobol.order < 2.
%
%   One implementation for both surrogate families: the surrogate is wrapped in
%   a lightweight in-session UQLab model and its Sobol indices are estimated by
%   Monte Carlo (cfg.N_sobol samples; second-order MC indices are noisier, hence
%   the large sample size). Wrapping makes the analysis robust to surrogates
%   trained in an earlier session and reloaded from disk (an unwrapped reloaded
%   model is not registered and cannot be selected).
%
%   Side effects: creates UQLab objects in the session and draws the Monte
%   Carlo sample from the current random number generator.
%   Computation: minutes (cfg.N_sobol UQLab predictions per sample matrix).

    % The fixed route evaluates each Sobol sample in one call; the
    % generalized route in batches of the settings' size (0.3).
    batchSize=Inf;
    if strcmp(cfg.dataMode,'real_extended')
        batchSize=cfg.realExtended.predictionBatchSize;
    end
    evaluator = @(X) surrogates.evaluate(model,X,'mean',batchSize);
    [S_first, S_total, S2] = sensitivity.sobol_evaluator(evaluator, P, cfg);
end
