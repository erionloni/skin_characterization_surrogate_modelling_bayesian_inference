function [model, info] = train_pce(X, Y, cfg)
%TRAIN_PCE Train scalar or multi-output sparse PCE surrogate models.
%   [model, info] = TRAIN_PCE(X, Y, cfg) fits degree-adaptive sparse PCE for
%   every supplied Y column. The complete-data compatibility path supplies all
%   six columns; the partial-output path calls this owner once per finite
%   scalar-output cohort. Both use Bayesian Compressive Sensing (BCS).
%
%   BCS is preferred over LARS: the Luethen et al. (2021) sparse-PCE benchmark
%   ranks it among the most robust solvers for the small, noiseless designs
%   expected from an expensive COMSOL model. Hyperbolic q-norm truncation
%   keeps high-order interaction terms sparse.
%
%   info.trainTime is the wall-clock training time [s]; info.LOO holds the
%   leave-one-out error per output when UQLab reports it.
%   Side effects: creates UQLab PCE models in the session.
%   Computation: seconds to minutes per output.

    MetaOpts.Type     = 'Metamodel';
    MetaOpts.MetaType = 'PCE';
    MetaOpts.Method   = cfg.pce.method;        % BCS
    MetaOpts.Degree   = cfg.pce.degrees;       % degree-adaptive 1:6
    MetaOpts.TruncOptions.qNorm = cfg.pce.q_norm;
    % PCE requires the authoritative UQLab input object.  Bind it explicitly
    % so a fresh fit or audit process cannot depend on ambient state left by the dataset step.
    P = parameters.parameter_space(cfg);
    MetaOpts.Input = P.Input;
    MetaOpts.ExpDesign.X = X;
    MetaOpts.ExpDesign.Y = Y;                  % N-by-J, J=1 or the complete six

    t = tic;
    model = uq_createModel(MetaOpts);
    info.trainTime = toc(t);

    nOut = size(Y, 2);
    info.LOO = nan(nOut, 1);
    for j = 1:nOut
        if any(strcmp(fieldnames(model),'Error')) && numel(model.Error) >= j && ...
                isfield(model.Error(j), 'LOO')
            info.LOO(j) = model.Error(j).LOO;
        end
    end
end
