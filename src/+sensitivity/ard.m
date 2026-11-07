function A = ard(model, P)
%ARD GP automatic-relevance-determination importance from Kriging lengths.
%   A = ARD(model, P) extracts the optimised anisotropic correlation
%   hyperparameters of the multi-output Kriging surrogate and turns them into
%   a per-output importance map that can be compared with the Sobol indices.
%
%   Fix vs. the legacy diagnostic (which ranked ARD inverted relative to
%   Sobol, corr = -0.54):
%     * model.Kriging(j).theta is the correlation LENGTH along each input, so
%       a SHORT length-scale means HIGH sensitivity -> importance = 1/theta
%       (the legacy code used theta directly, i.e. the wrong sign).
%     * UQLab auto-scales the inputs before fitting, so theta is already
%       dimensionless and comparable across inputs -> NO multiplication
%       by the prior width (the legacy range correction double-counted scale
%       and made log10_k0 look artificially smooth).
%
%   Fields: A.theta / A.importance [nOutputs x nInputs], A.meanImportance
%   [1 x nInputs], A.inputNames, A.outputNames.
%   Side effects: none.

    nOut = numel(P.outputNames);
    nIn  = P.M;

    A.theta      = nan(nOut, nIn);
    A.importance = nan(nOut, nIn);
    for j = 1:nOut
        K = kriging_component(model,j,nOut);
        if isempty(K),continue;end
        th = K.theta(:).';
        assert(numel(th) == nIn, 'ard:BadTheta', 'theta length mismatch for output %d.', j);
        A.theta(j, :) = th;
        inv = 1 ./ max(th, eps);              % short length-scale = high importance
        A.importance(j, :) = inv / sum(inv);  % normalised per output
    end

    A.meanImportance = mean(A.importance, 1, 'omitnan');
    A.inputNames     = P.names;
    A.outputNames    = P.outputNames;
end

function K = kriging_component(model,j,nOut)
%KRIGING_COMPONENT Normalize legacy multi-output and output-wise ensembles.
    if isstruct(model) && isfield(model,'models')
        assert(numel(model.models)==nOut,'ard:NotKriging', ...
            'Expected %d output-wise GP components.',nOut);
        component=model.models{j};
        if isempty(component),K=[];return;end
        assert(has_member(component,'Kriging') && ~isempty(component.Kriging), ...
            'ard:NotKriging','GP ensemble component %d is not Kriging.',j);
        K=component.Kriging(1);
    else
        assert(has_member(model,'Kriging') && numel(model.Kriging)==nOut, ...
            'ard:NotKriging', ...
            'Expected a multi-output Kriging model with %d outputs.',nOut);
        K=model.Kriging(j);
    end
end

function tf=has_member(value,name)
%HAS_MEMBER Support both plain structs and UQLab uq_model objects.
    if isstruct(value)
        tf=isfield(value,name);
        return
    end
    try
        tf=any(strcmp(fieldnames(value),name));
    catch
        tf=false;
    end
end
