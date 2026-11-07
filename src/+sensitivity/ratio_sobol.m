function [S_first, S_total, ratioNames] = ratio_sobol(model, P, cfg)
%RATIO_SOBOL Sobol indices for the cycle-to-cycle pressure ratios.
%   [S_first, S_total, ratioNames] = RATIO_SOBOL(model, P, cfg) computes Sobol
%   indices for the four derived ratio features
%
%       r21_D2 = pcl2_D2/pcl1_D2,  r31_D2 = pcl3_D2/pcl1_D2,
%       r21_D6 = pcl2_D6/pcl1_D6,  r31_D6 = pcl3_D6/pcl1_D6,
%
%   which expose loading-history / relaxation effects (m3_e_RD, log10_k0_RD)
%   that the raw pressure levels (dominated by m3_f_RD) hide.
%
%   The ratios are wrapped in a UQLab Model so the same canonical
%   Sensitivity/Sobol engine is reused -- no bespoke Saltelli/Jansen code.
%   Returns [nRatios x nInputs] index matrices.
%   Side effects: creates UQLab objects in the session and draws the Monte
%   Carlo sample from the current random number generator.
%   Computation: seconds (UQLab predictions).

    ratioNames = {'r21_D2', 'r31_D2', 'r21_D6', 'r31_D6'};

    localCfg = cfg;
    localCfg.sobol.order = 1;
    evaluator = @(X) ratio_features(evaluate_mean(model,X));
    [S_first,S_total] = sensitivity.sobol_evaluator(evaluator,P,localCfg);
end

function R = ratio_features(Y)
%RATIO_FEATURES Map the 6 closing pressures to the 4 cycle ratios.
    R = design_study.ratio_values(Y,1e-12);
end

function mu = evaluate_mean(model,X)
%EVALUATE_MEAN The surrogate mean only: a GP's predictive variance, which the
%   ratios do not use, is not computed (CLN-044; UQLab computes the mean the
%   same way either way, so the indices are unchanged).
    mu = surrogates.evaluate(model,X,'mean');
end
