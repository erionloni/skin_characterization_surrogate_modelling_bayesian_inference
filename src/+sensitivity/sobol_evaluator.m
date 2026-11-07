function [S_first, S_total, S2, extra] = sobol_evaluator(evaluator, P, cfg)
%SOBOL_EVALUATOR Canonical Sobol analysis for a vectorized forward evaluator.
%   The evaluator receives physical P-space inputs and must return one or more
%   finite scalar outputs per row. This shared primitive lets raw pressures and
%   deterministic pressure-derived features use exactly the same UQLab Sobol
%   implementation.
%   [S_FIRST, S_TOTAL, S2] = sensitivity.sobol_evaluator(EVALUATOR, P, CFG):
%   indices as sensitivity.sobol returns them.
%   [..., EXTRA] = sensitivity.sobol_evaluator(...) also returns the
%   evaluated outputs at the points of the first sample matrix
%   (EXTRA.sample1Y: independent uniform points) and the variance of each
%   output over them (EXTRA.variance, outputs x 1). UQLab's own
%   Results.TotalVariance is not used: UQLab 2.3 pools every output into
%   one variance (uq_sobol_indices: var([M_Sample1(:); M_Sample2(:)])); its
%   indices use the variance of each output.
%   Side effects: creates UQLab objects in the session and draws the Monte
%   Carlo sample from the current random number generator.
%   Computation: minutes (cfg.N_sobol evaluations of EVALUATOR per sample
%   matrix).

    assert(isa(evaluator,'function_handle') && isstruct(P) && ...
        isfield(P,'M') && P.M == numel(P.names), ...
        'sensitivity:sobol_evaluator:Configuration', ...
        'Provide a vectorized evaluator and a consistent parameter contract.');
    assert(isfield(cfg,'sobol') && isfield(cfg.sobol,'order') && ...
        isfield(cfg,'N_sobol') && isscalar(cfg.N_sobol), ...
        'sensitivity:sobol_evaluator:Configuration', ...
        'The Sobol order and sample size must be configured.');
    if cfg.sobol.order >= 2
        greaterOrderRows=nchoosek(P.M,2)*cfg.N_sobol;
        assert(~(greaterOrderRows>1e6 && greaterOrderRows<2e6), ...
            'sensitivity:sobol_evaluator:UQLab23UnsafeBatchBand', ...
            ['UQLab 2.3 does not safely evaluate greater-order Sobol ' ...
            'workloads in the verified batching band (1e6,2e6) rows. ' ...
            'Requested workload: %d rows.'],greaterOrderRows);
    end

    WrapOpts.mHandle = evaluator;
    WrapOpts.isVectorized = true;
    sessionModel = uq_createModel(WrapOpts);

    uq_selectInput(P.Input);
    uq_selectModel(sessionModel);

    SobolOpts.Type             = 'Sensitivity';
    SobolOpts.Method           = 'Sobol';
    SobolOpts.Sobol.Order      = cfg.sobol.order;
    SobolOpts.Sobol.SampleSize = cfg.N_sobol;
    analysis = uq_createAnalysis(SobolOpts, '-private');
    Res = analysis.Results;

    S_first = clip_indices(Res.FirstOrder.');
    S_total = clip_indices(Res.Total.');

    extra = struct('sample1Y', [], 'variance', []);
    if isfield(Res, 'ExpDesign') && isfield(Res.ExpDesign, 'Sample1')
        extra.sample1Y = Res.ExpDesign.Sample1.Y;
        extra.variance = reshape(var(double(extra.sample1Y), 0, 1), [], 1);
    end

    S2 = struct('indices', [], 'pairs', [], 'pairLabels', {{}});
    if cfg.sobol.order >= 2 && isfield(Res,'AllOrders') && ...
            numel(Res.AllOrders) >= 2
        S2.pairs = Res.VarIdx{2};
        S2.indices = clip_indices(Res.AllOrders{2}.');
        nPairs = size(S2.pairs,1);
        S2.pairLabels = cell(nPairs,1);
        for q = 1:nPairs
            S2.pairLabels{q} = sprintf('%s x %s', ...
                P.names{S2.pairs(q,1)},P.names{S2.pairs(q,2)});
        end
    end
end

function S = clip_indices(S)
%CLIP_INDICES Remove only small finite-sample boundary artefacts.
    S(abs(S) < 1e-10) = 0;
    S(S < 0 & S > -1e-3) = 0;
    S(S > 1 & S < 1+1e-3) = 1;
end
