function seeds = generalized_seeds(cfg)
%GENERALIZED_SEEDS The seeds of the generalized sensitivity's samples.
%   SEEDS = sensitivity.generalized_seeds(CFG) returns the seeds that
%   sensitivity.run_generalized draws its samples with: the master seed
%   CFG.seed plus fixed offsets for the raw GP indices (gp_raw), the
%   derived-feature indices of the GP (gp_derived; also the sample of the
%   feature sensitivity, features.feature_sensitivity) and of the PCE
%   (pce_derived), and the support audit's and the bootstrap's seeds of the
%   settings (B.4).
%   Side effects: none.
    policy = cfg.realExtended.stage3;
    seeds = struct('gp_raw', cfg.seed + 31011, 'gp_derived', cfg.seed + 31012, ...
        'pce_derived', cfg.seed + 31013, 'support', policy.supportAuditSeed, ...
        'bootstrap', policy.fixedSurrogateBootstrapSeed);
end
