function [canonical,record] = canonical_likelihood_parameters(values,opts)
%CANONICAL_LIKELIHOOD_PARAMETERS The four model parameters the GP is evaluated at.
%   [CANONICAL, RECORD] = inversion.canonical_likelihood_parameters(VALUES,
%   OPTS) returns the sampler states VALUES (N-by-4 for the canonical
%   inversion, passed through unchanged) or, when OPTS.parameterAdapter is
%   set (conditional inversion: N-by-K free parameters), the four-parameter
%   rows with the fixed parameters at their truth
%   (inversion.expand_conditional_parameters). This is the only place where
%   inversion.gp_log_likelihood sees reduced states. RECORD says whether
%   the state was expanded, with the parameter counts and the condition.
%   Side effects: none.

    adapter=struct([]);
    if isstruct(opts)&&isscalar(opts)&&isfield(opts,'parameterAdapter')&& ...
            ~isempty(opts.parameterAdapter)
        adapter=opts.parameterAdapter;
    end
    if isempty(adapter)
        canonical=double(values);
        record=struct('conditional',false, ...
            'samplerParameterCount',size(canonical,2), ...
            'canonicalParameterCount',size(canonical,2), ...
            'conditionTag','');
        return;
    end
    canonical=inversion.expand_conditional_parameters(values,adapter);
    record=struct('conditional',true, ...
        'samplerParameterCount',size(values,2), ...
        'canonicalParameterCount',size(canonical,2), ...
        'conditionTag',adapter.conditionTag);
end
