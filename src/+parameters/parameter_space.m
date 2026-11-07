function P = parameter_space(cfg)
%PARAMETER_SPACE The prior box of the material parameters and its UQLab input object.
%   P = parameters.parameter_space(CFG) returns the single source of truth for the inverse
%   problem's parametrisation:
%
%       P.names        1xM cellstr  parameter names
%       P.units        1xM cellstr  parameter units
%       P.bounds       Mx2 double   [lower, upper] of the uniform prior box
%       P.M            scalar       number of parameters
%       P.outputNames  1x6 cellstr  closing-pressure names
%       P.Input        UQLab INPUT object (uniform marginals over the box)
%       P.normalize    @(X) -> U    map design box to the [0,1]^M unit cube
%       P.denormalize  @(U) -> X    inverse map
%
%   Permeability is parametrised in log10 space (uniform prior in that
%   coordinate) in every material route, so no further transform is needed.
%   CFG is the configuration of a step (study.project_config): the fixed
%   route (four inputs) or the generalized route (seven inputs).
%   Requires UQLab on the path (utils.activate_uqlab).
%   Side effects: creates the UQLab input object (the session's current
%   input).

    switch cfg.dataMode
        case {'real', 'real_extended'}
            P.names       = cfg.paramNames;
            P.units       = cfg.paramUnits;
            P.bounds      = cfg.paramBounds;
            P.outputNames = cfg.outputNames;
        otherwise
            error('parameters:parameter_space:UnknownDataMode', ...
                'Unsupported data route "%s".', cfg.dataMode);
    end
    P.M = size(P.bounds, 1);

    for i = 1:P.M
        InputOpts.Marginals(i).Name       = P.names{i};
        InputOpts.Marginals(i).Type       = 'Uniform';
        InputOpts.Marginals(i).Parameters = P.bounds(i, :);
    end
    P.Input = uq_createInput(InputOpts);

    lo = P.bounds(:, 1).';
    hi = P.bounds(:, 2).';
    P.normalize   = @(X) (X - lo) ./ (hi - lo);
    P.denormalize = @(U) lo + U .* (hi - lo);
end
