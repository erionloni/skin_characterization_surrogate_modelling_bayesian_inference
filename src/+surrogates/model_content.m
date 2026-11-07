function content = model_content(ensemble)
%MODEL_CONTENT What determines the predictions of a fitted surrogate ensemble, as plain data.
%   CONTENT = surrogates.model_content(ENSEMBLE) describes the fitted models
%   of a GP or PCE ensemble (the struct of surrogates.load_ensemble, or of a
%   model file, with its models in ENSEMBLE.models) by what their
%   predictions depend on: per model, its type, training inputs and outputs,
%   and for a Kriging model the correlation family, the ARD scales (theta),
%   the trend coefficients (beta) and the process variance (sigmaSQ), for a
%   PCE the basis indices and coefficients; with the ensemble's input and
%   output names and bounds when it records them. A checkpoint that depends
%   on a model stores this description and is reused only for an equal one
%   (isequaln). An empty ENSEMBLE gives an empty description.
%   Side effects: none.

    content = struct('inputNames', {{}}, 'outputNames', {{}}, 'inputBounds', [], ...
        'models', {{}});
    if isempty(ensemble), return; end
    assert(isstruct(ensemble) && isscalar(ensemble) && isfield(ensemble, 'models') && ...
        iscell(ensemble.models), 'surrogates:model_content:Ensemble', ...
        'A surrogate ensemble holds its fitted models in the cell array ''models''.');
    if isfield(ensemble, 'inputNames'), content.inputNames = cellstr(string(ensemble.inputNames)); end
    if isfield(ensemble, 'outputNames'), content.outputNames = cellstr(string(ensemble.outputNames)); end
    if isfield(ensemble, 'inputBounds'), content.inputBounds = double(ensemble.inputBounds); end
    content.models = cellfun(@one_model, ensemble.models, 'UniformOutput', false);
end

function one = one_model(model)
%ONE_MODEL The type, training data and fitted parameters of one UQLab metamodel.
    type = char(string(model.Options.MetaType));
    one = struct('type', type, 'X', double(model.ExpDesign.X), 'Y', double(model.ExpDesign.Y));
    switch lower(type)
        case 'kriging'
            one.correlationFamily = char(string(model.Internal.Kriging(1).GP.Corr.Family));
            one.theta = double(model.Kriging(1).theta);
            one.beta = double(model.Kriging(1).beta);
            one.sigmaSQ = double(model.Internal.Kriging(1).GP.sigmaSQ);
        case 'pce'
            one.indices = full(double(model.PCE(1).Basis.Indices));
            one.coefficients = double(model.PCE(1).Coefficients);
        otherwise
            error('surrogates:model_content:Type', ...
                'A surrogate is a Kriging or PCE metamodel, not %s.', type);
    end
end
