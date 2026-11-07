function confirmation_combinations(cfg, ~)
%CONFIRMATION_COMBINATIONS Step 'combinations' of the generalized route: the weak-pair combinations of the confirmation.
%   study.steps.confirmation_combinations(CFG, STEPSINCALL) analyses, per
%   material, protocol, observation design and replicate of the
%   confirmation, which combinations of the weak pair the posterior
%   determines, and how each focused protocol rotates or sharpens the best
%   one against the default protocol on the matched materials
%   (confirmation.parameter_combinations; settings B.8), on the draws of
%   this run's step compare or on the shipped ones, and writes
%   <run>/generalized/06_confirmation/data/combinations. CFG comes from
%   study.native_config.
%   Computation: about a minute.
%   Side effects: writes the outputs above below the run folder.
    confirmation.parameter_combinations(cfg);
end
