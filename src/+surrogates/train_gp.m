function [model, info] = train_gp(X, Y, cfg, opts)
%TRAIN_GP Train scalar or multi-output GP/Kriging surrogate models.
%   [model, info] = TRAIN_GP(X, Y, cfg) fits ordinary anisotropic (ARD)
%   Kriging for every supplied Y column. The complete-data compatibility path
%   supplies all six columns at once; the partial-output path calls this owner
%   once for each finite scalar-output cohort. Both use
%   the configured fixed production correlation (Matérn-3/2 on the real
%   route) and UQLab's hybrid genetic algorithm (HGA) for hyperparameter
%   optimisation.
%
%   HGA is a global+local optimiser: it avoids the bad local optima that a
%   single-start BFGS falls into (a known Kriging failure mode), which matters
%   for the small designs expected from COMSOL. model.Kriging(j).theta holds
%   the per-output correlation lengths used by the ARD diagnostic.
%
%   The trend, correlation type, kernel, nugget and optimizer are those of
%   the configuration (cfg.gp: the settings' modelSource, A.3 and B.3).
%   [model, info] = TRAIN_GP(X, Y, cfg, opts) overrides them, for the
%   kernel/optimizer-comparison study of the audit and the fits of a policy:
%       opts.kernel       UQLab Corr.Family name
%       opts.nugget       Regression.SigmaNSQ
%       opts.optimMethod  UQLab Optim.Method name
%       opts.trend        UQLab Trend.Type
%       opts.correlation  UQLab Corr.Type
%       opts.optimMaxIter positive integer GA/local iteration ceiling; omitted
%                         retains the installed UQLab defaults unchanged;
%                         ignored with opts.fixedTheta (nothing is optimized).
%       opts.fixedTheta   the correlation length scales (one per input, in
%                         UQLab's scaling): no hyperparameter optimization
%                         (UQLab Optim.Method 'none'), for a GP without a
%                         nugget only; the refit_manual option
%
%   info.trainTime [s], info.kernel, info.nugget, info.optimMethod,
%   info.trend and info.correlationType record what was used.
%   Side effects: creates UQLab Kriging models in the session.
%   Computation: seconds to minutes per output.

    if nargin < 4, opts = struct(); end
    assert(isstruct(opts)&&isscalar(opts)&&all(ismember(fieldnames(opts), ...
        {'kernel','nugget','optimMethod','optimMaxIter','modelFamily','candidate', ...
        'trend','correlation','fixedTheta'})), ...
        'surrogates:train_gp:Options','Unsupported scalar GP fitting option.');
    kernel      = cfg.gp.kernel;
    nugget      = cfg.gp.nugget;
    optimMethod = cfg.gp.optim_method;
    trend       = cfg.gp.trend;
    correlation = cfg.gp.correlation;
    if isfield(opts, 'kernel') && ~isempty(opts.kernel), kernel = opts.kernel; end
    if isfield(opts, 'nugget') && ~isempty(opts.nugget), nugget = opts.nugget; end
    if isfield(opts, 'optimMethod') && ~isempty(opts.optimMethod), optimMethod = opts.optimMethod; end
    if isfield(opts, 'trend') && ~isempty(opts.trend), trend = opts.trend; end
    if isfield(opts, 'correlation') && ~isempty(opts.correlation), correlation = opts.correlation; end
    fixedTheta = [];
    if isfield(opts, 'fixedTheta') && ~isempty(opts.fixedTheta)
        fixedTheta = reshape(double(opts.fixedTheta), 1, []);
        % UQLab 2.3 fits a GP with a nugget of at least eps as a GP
        % regression and cannot skip the optimization of its hyperparameters.
        assert(numel(fixedTheta) == size(X, 2) && all(isfinite(fixedTheta) & fixedTheta > 0) && ...
            nugget < eps, 'surrogates:train_gp:FixedTheta', ...
            ['A fixed theta needs one positive length scale per input (%d) and a GP without ' ...
             'a nugget.'], size(X, 2));
        optimMethod = 'none';
    end

    MetaOpts.Type     = 'Metamodel';
    MetaOpts.MetaType = 'Kriging';
    MetaOpts.ExpDesign.X = X;
    MetaOpts.ExpDesign.Y = Y;                 % N-by-J, J=1 or the complete six

    MetaOpts.Trend.Type   = trend;             % thesis: ordinary
    MetaOpts.Corr.Family  = kernel;
    MetaOpts.Corr.Type    = correlation;       % thesis: Ellipsoidal (anisotropic, ARD)
    MetaOpts.Optim.Method = optimMethod;       % thesis: HGA (global + local refinement)
    if ~isempty(fixedTheta)
        % No optimization: UQLab uses the given length scales (the GP
        % variance follows from them).
        MetaOpts.Optim.InitialValue = fixedTheta;
    end
    MetaOpts.Regression.SigmaNSQ = nugget;
    % Fixed length scales are not optimized: an iteration limit (a
    % demonstration budget) has nothing to limit.
    limited = isfield(opts,'optimMaxIter') && isempty(fixedTheta);
    if limited
        validateattributes(opts.optimMaxIter,{'numeric'}, ...
            {'scalar','real','finite','integer','positive'});
        assert(strcmpi(optimMethod,'HGA'), ...
            'surrogates:train_gp:BudgetOptimizer', ...
            'The bounded iteration override currently supports HGA only.');
        MetaOpts.Optim.MaxIter=double(opts.optimMaxIter);
    end

    t = tic;
    model = uq_createModel(MetaOpts);
    info.trainTime  = toc(t);
    info.kernel     = kernel;
    info.nugget     = nugget;
    info.optimMethod = optimMethod;
    info.trend = trend;
    info.correlationType = correlation;
    if ~isempty(fixedTheta), info.fixedTheta = fixedTheta; end
    if limited
        actual=[model.Internal.Kriging.Optim];
        assert(all([actual.MaxIter]==double(opts.optimMaxIter)), ...
            'surrogates:train_gp:BudgetPropagation', ...
            'UQLab did not apply the requested optimizer iteration limit (%d).',double(opts.optimMaxIter));
        info.requestedOptimMaxIter=double(opts.optimMaxIter);
        info.effectiveOptimMaxIter=[actual.MaxIter];
    end
end
