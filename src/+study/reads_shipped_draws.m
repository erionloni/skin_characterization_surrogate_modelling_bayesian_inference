function tf = reads_shipped_draws(cfg)
%READS_SHIPPED_DRAWS True when the analyses of CFG read the posterior draws shipped in thesis_results/.
%   TF = study.reads_shipped_draws(CFG) is true in reproduce mode
%   (study.is_publication) and in a rerun of recovery, the design study or
%   the ratio-error curves in a run without an inversion of its own, for which study.native_config sets
%   CFG.native.shippedDraws. Otherwise the analyses
%   read the posteriors of the run's own inversion campaign.
%   Side effects: none.
    tf = study.is_publication(cfg) || (isfield(cfg, 'native') && isstruct(cfg.native) && ...
        isfield(cfg.native, 'shippedDraws') && ~isempty(cfg.native.shippedDraws));
end
