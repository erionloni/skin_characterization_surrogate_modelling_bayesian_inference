function reliability = conditional_same_sampler_reliability( ...
        runs,adapter,cfg,sampler,varargin)
%CONDITIONAL_SAME_SAMPLER_RELIABILITY Assess only the sampled free dimensions.
%   Prior widths are the unchanged canonical prior widths at the free indices.
%   Fixed coordinates are never injected as degenerate sampler dimensions.
%
%   RELIABILITY = inversion.conditional_same_sampler_reliability(RUNS,
%   ADAPTER, CFG, SAMPLER, ...) applies inversion.same_sampler_reliability
%   to the free coordinates of the replicate runs RUNS and records the free
%   and fixed indices and names and the free prior widths.
%   Side effects: none.

    assert(isstruct(adapter)&&isscalar(adapter)&& ...
        isfield(adapter,'freeBounds')&&isfield(adapter,'freeParameterNames')&& ...
        isfield(adapter,'freeParameterIndices'), ...
        'inversion:conditional_same_sampler_reliability:Adapter', ...
        'A complete conditional adapter is required.');
    localCfg=cfg;
    localCfg.paramNames=adapter.freeParameterNames;
    localCfg.paramBounds=adapter.freeBounds;
    reliability=inversion.same_sampler_reliability( ...
        runs,adapter.freeBounds,localCfg,sampler,varargin{:});
    reliability.schemaVersion='conditional_mcmc_same_sampler_reliability_v1';
    reliability.conditionTag=adapter.conditionTag;
    reliability.freeParameterIndices=adapter.freeParameterIndices;
    reliability.fixedParameterIndices=adapter.fixedParameterIndices;
    reliability.freeParameterNames=adapter.freeParameterNames;
    reliability.freePriorWidths=adapter.freeBounds(:,2).'- ...
        adapter.freeBounds(:,1).';
    reliability.fixedCoordinatesTreatedAsSamplerDimensions=false;
    reliability.canonicalDrawsPooled=false;
end
