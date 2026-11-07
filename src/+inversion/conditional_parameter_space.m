function P = conditional_parameter_space(cfg,condition,thetaTruth)
%CONDITIONAL_PARAMETER_SPACE Reduced UQLab prior for oracle conditioning.
%   The free marginals inherit exactly the corresponding canonical uniform
%   prior ranges. Fixed coordinates are absent from the sampler state and are
%   restored only through P.expand before the canonical GP is evaluated.
%
%   P = inversion.conditional_parameter_space(CFG, CONDITION, THETATRUTH)
%   returns the prior of the condition's free parameters (as
%   parameters.parameter_space, with the canonical bounds at the free
%   indices), the fixed values from THETATRUTH (1-by-4), and P.expand /
%   P.project between the free and the four model parameters.
%   Side effects: creates the UQLab input object of the reduced prior.

    adapter=inversion.conditional_adapter(cfg,condition,thetaTruth);
    for i=1:adapter.samplerDimension
        InputOpts.Marginals(i).Name=adapter.freeParameterNames{i};
        InputOpts.Marginals(i).Type='Uniform';
        InputOpts.Marginals(i).Parameters=adapter.freeBounds(i,:);
    end
    P=struct( ...
        'names',{adapter.freeParameterNames}, ...
        'units',{adapter.freeParameterUnits}, ...
        'bounds',adapter.freeBounds, ...
        'M',adapter.samplerDimension, ...
        'outputNames',{cellstr(string(cfg.outputNames(:))).'}, ...
        'Input',uq_createInput(InputOpts), ...
        'adapter',adapter, ...
        'isConditional',true, ...
        'canonicalNames',{adapter.canonicalParameterNames}, ...
        'canonicalBounds',adapter.canonicalBounds);
    lo=P.bounds(:,1).';hi=P.bounds(:,2).';
    P.normalize=@(X)(X-lo)./(hi-lo);
    P.denormalize=@(U)lo+U.*(hi-lo);
    P.expand=@(X)inversion.expand_conditional_parameters(X,adapter);
    P.project=@(X)inversion.project_conditional_parameters(X,adapter);
end
