function [meanPrediction, predictiveVariance] = evaluate(model, X, kind, batchSize)
%EVALUATE Evaluate a native UQLab model or a surrogate output ensemble.
%   [MU,V] = SURROGATES.EVALUATE(MODEL,X,KIND) is the shared evaluation
%   adapter for the historical multi-output UQLab models and the independently
%   checkpointed real_extended output ensembles. KIND is 'gp' or 'pce'.  A
%   missing ensemble output remains NaN; it is never replaced by zero.
%   KIND 'mean' (or 'gp_mean') asks for the mean only: a GP's predictive
%   variance is then not computed. BATCHSIZE (default Inf) evaluates X in
%   blocks of rows.
%   MU and V: rows of X by outputs (mbar and mbar^2).
%   Side effects: none.
%   Computation: UQLab predictions.

    arguments
        model
        X (:,:) double
        kind (1,:) char = ''
        batchSize (1,1) double = Inf
    end
    assert((isinf(batchSize)&&batchSize>0)||(isfinite(batchSize)&& ...
        batchSize>=1&&batchSize==fix(batchSize)), ...
        'surrogates:evaluate:BatchSize','BatchSize must be a positive integer or Inf.');
    if size(X,1)>batchSize
        meanPrediction=[];predictiveVariance=[];
        for first=1:batchSize:size(X,1)
            rows=first:min(first+batchSize-1,size(X,1));
            [mu,v]=surrogates.evaluate(model,X(rows,:),kind);
            if first==1
                meanPrediction=nan(size(X,1),size(mu,2));
                predictiveVariance=nan(size(X,1),size(v,2));
            end
            meanPrediction(rows,:)=mu;predictiveVariance(rows,:)=v;
        end
        return
    end

    if isstruct(model) && isfield(model, 'models')
        if isempty(kind) && isfield(model, 'family')
            kind = char(model.family);
        end
        nOutput = numel(model.models);
        meanPrediction = nan(size(X,1), nOutput);
        predictiveVariance = nan(size(X,1), nOutput);
        for outputIndex = 1:nOutput
            child = model.models{outputIndex};
            if isempty(child), continue; end
            if strcmpi(kind, 'gp')
                [mu, variance] = uq_evalModel(child, X);
                meanPrediction(:,outputIndex) = mu(:);
                predictiveVariance(:,outputIndex) = ...
                    checked_predictive_variance(variance(:));
            else
                mu = uq_evalModel(child, X);
                meanPrediction(:,outputIndex) = mu(:);
            end
        end
        return;
    end

    if strcmpi(kind, 'gp')
        [meanPrediction, predictiveVariance] = uq_evalModel(model, X);
        predictiveVariance = checked_predictive_variance(predictiveVariance);
    else
        meanPrediction = uq_evalModel(model, X);
        predictiveVariance = nan(size(meanPrediction));
    end
end

function variance=checked_predictive_variance(variance)
% UQLab may return a negative value only at floating-point roundoff scale.
% Materially negative predictive variances fail instead of being repaired.
    variance=double(variance);
    assert(all(isfinite(variance(:))|isnan(variance(:))), ...
        'surrogates:evaluate:NonfiniteGPVariance','Check failed: surrogates:evaluate:NonfiniteGPVariance.');
    finite=variance(isfinite(variance));
    if isempty(finite),return;end
    tolerance=1e-12*max(1,max(abs(finite)));
    assert(all(finite>=-tolerance), ...
        'surrogates:evaluate:MaterialNegativeGPVariance', ...
        ['UQLab returned predictive variance below the documented ' ...
         '1e-12 relative roundoff tolerance.']);
    variance(variance<0)=0;
end
