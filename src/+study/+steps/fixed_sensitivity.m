function fixed_sensitivity(cfg, ~)
%FIXED_SENSITIVITY Step 'sensitivity' of the fixed route: Sobol and ARD sensitivity.
%   study.steps.fixed_sensitivity(CFG, STEPSINCALL) computes, from the GP
%   and PCE of CFG.files.gp and CFG.files.pce (fixed seed), the first-, total-
%   and second-order Sobol indices, interaction gaps, ratio-output Sobol
%   indices and ARD importance of the six closing pressures, and writes
%   <run>/fixed/03_sensitivity/data: sensitivity.mat, primary/ (GP
%   first and total order) and supporting/. CFG comes from
%   study.native_config.
%   Computation: about 2 minutes (UQLab predictions). The analysis is
%   sensitivity.run_fixed.
%   Side effects: writes the outputs above below the run folder.
    sensitivity.run_fixed(cfg);
end
