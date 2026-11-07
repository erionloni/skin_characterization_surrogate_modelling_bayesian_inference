function provider = screening_provider(cfg)
%SCREENING_PROVIDER The approved generalized GP as the screening's model provider.
%   PROVIDER = study.screening_provider(CFG) builds the provider of
%   screening.generalized_provider. CFG binds the approved
%   generalized package (study.native_config). The recorded dataset result
%   and calibration application record come from their fixed locations in
%   the shipped results (CFG.native.providerSources).
%   Side effects: loads the GP ensemble.
    provider = screening.generalized_provider(cfg, cfg.native.providerSources);
end
