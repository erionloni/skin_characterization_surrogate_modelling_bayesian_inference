function [A,status] = load_conditional_provider(cfg,record,varargin)
%LOAD_CONDITIONAL_PROVIDER The posterior of the selected provider of one conditional inversion cell.
%   Reproduce mode reads the shipped draws (certified or healthy fallback);
%   a rerun its own conditional campaign: the certified provider or, for a
%   cell that did not certify, its healthy completed fallback
%   (inversion.load_conditional_available_posterior, the rule of the
%   thesis's cells).
%   [A, STATUS] = recovery.load_conditional_provider(CFG, RECORD) returns
%   the provider and whether it was loaded, is valid and is certified.
%   [A, STATUS] = recovery.load_conditional_provider(CFG, RECORD, SAMPLER,
%   REPLICATE, LEVEL) returns one replicate of the cell at LEVEL steps (from
%   the shipped draws, or inversion.load_conditional_posterior_artifact), as
%   recovery.load_posterior_provider does for a canonical cell.
%   Side effects: none.
    if study.reads_shipped_draws(cfg)
        % The selected providers' full draws shipped in thesis_results/.
        [A,status]=study.load_shipped_posterior(cfg,record,varargin{:});
        return
    end
    if isempty(varargin)
        [A,status]=inversion.load_conditional_available_posterior(cfg,record);
    else
        [A,status]=inversion.load_conditional_posterior_artifact(cfg,record,varargin{:});
    end
end
