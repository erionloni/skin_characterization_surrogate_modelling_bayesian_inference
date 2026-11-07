function confirmation_prepare(cfg, ~)
%CONFIRMATION_PREPARE Step 'prepare': the confirmation campaign's cells, seeds and task table.
%   study.steps.confirmation_prepare(CFG, STEPSINCALL) prepares the
%   confirmation campaign of the design of the settings (B.7) from its
%   accepted observations (CFG.stage9bConfirmation.observationsFile: this
%   run's step import_observations, or the setting
%   generalized.confirmation.observations, whose thesis table is
%   data/confirmation/confirmation_observations.csv), joined to the design
%   by their exact values. It builds one inverse cell per material and
%   protocol (the four material parameters unknown, the protocol known;
%   measurement_plus_gp, all_six; the reference protocol's cell shared by
%   the comparisons of its material), the paired comparisons of every
%   selected protocol with the reference, and the seed of every MCMC
%   request from the rule of the settings (seeds.confirmation: the
%   material's CaseID, the protocol's row, the level and the replicate).
%   The task table, seed schedule, configurations and preparation are
%   written below <run>/_run/confirmation (CFG.native.campaignRoot); nothing
%   is sampled (confirmation.prepare_confirmation_campaign, with the
%   model provider of study.screening_provider).
%   CFG comes from study.native_config.
%   Computation: about a minute.
%   Side effects: writes the outputs above below the run folder.

    confirmation.prepare_confirmation_campaign(cfg, study.screening_provider(cfg), ...
        cfg.stage9bConfirmation.observationsFile, cfg.native.campaignRoot);
end
