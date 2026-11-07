function [A,status] = load_posterior_provider(cfg,record,varargin)
%LOAD_POSTERIOR_PROVIDER The posterior of the selected provider of one inversion cell.
%   [A, STATUS] = recovery.load_posterior_provider(CFG, RECORD) loads the
%   posterior of the cell RECORD: in reproduce mode and in a rerun without
%   an inversion of its own, the selected provider's full draws shipped in
%   thesis_results/, certified or a healthy fallback
%   (study.load_shipped_posterior, study.reads_shipped_draws); otherwise
%   the certified posterior of the run's own campaign
%   below CFG.paths.stage04 (inversion.load_certified_posterior).
%   [A, STATUS] = recovery.load_posterior_provider(CFG, RECORD, SAMPLER,
%   REPLICATE, LEVEL) loads one member of the accepted replicate pair (from
%   the shipped draws, or inversion.load_posterior_artifact); a single
%   fallback cannot make paired geometry.
%   STATUS says whether a posterior was loaded, is valid and is certified.
%   Side effects: none.
    if study.reads_shipped_draws(cfg)
        % The selected providers' full draws shipped in thesis_results/.
        [A,status]=study.load_shipped_posterior(cfg,record,varargin{:});
        return
    end
    if isempty(varargin)
        [A,status]=inversion.load_certified_posterior(cfg,record);
    else
        [A,status]=inversion.load_posterior_artifact(cfg,record,varargin{:});
    end
end
