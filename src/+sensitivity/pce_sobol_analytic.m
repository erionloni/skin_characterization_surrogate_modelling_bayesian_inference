function [S_first, S_total, S2] = pce_sobol_analytic(pce, P, cfg) %#ok<INUSD>
%PCE_SOBOL_ANALYTIC Analytic Sobol indices from the PCE coefficients.
%   [S_first, S_total, S2] = PCE_SOBOL_ANALYTIC(pce, P, cfg) computes exact
%   first-, total- and pairwise second-order Sobol indices directly from the
%   orthonormal PCE expansion -- no Monte Carlo. For Y = sum_a c_a psi_a with
%   orthonormal basis psi (UQLab Legendre on the uniform inputs),
%       Var[Y] = sum_{a ~= 0} c_a^2,
%   and a Sobol index is the share of that variance carried by the basis terms
%   whose set of ACTIVE inputs (non-zero multi-index entries) matches the
%   requested index set:
%       S_i    : terms active in input i only            (first-order)
%       S_Ti   : terms active in input i (any others too) (total-order)
%       S_ij   : terms active in inputs i and j only      (second-order)
%   Computed per output of the multi-output PCE.
%
%   Returns the same shapes as SENSITIVITY.SOBOL: S_first/S_total [nOut x nIn];
%   S2.indices [nOut x nPairs], S2.pairs [nPairs x 2], S2.pairLabels {nPairs}.
%   The basis-index/coefficient fields are read defensively; if a PCE output is
%   constant (zero variance) its indices are returned as 0.
%   Side effects: none.

    M     = P.M;
    components = pce_components(pce);
    nOut  = numel(components);
    pairs = nchoosek(1:M, 2);
    nPairs = size(pairs, 1);

    S_first = nan(nOut, M);
    S_total = nan(nOut, M);
    S2ind   = nan(nOut, nPairs);

    for j = 1:nOut
        component = components{j};
        if isempty(component)
            continue;
        end
        c = component.Coefficients(:);
        A = full(component.Basis.Indices);   % [nTerms x M] multi-indices alpha
        active = A > 0;                        % inputs each term involves
        nz = sum(active, 2);                   % number of active inputs per term
        c2 = c.^2;
        V  = sum(c2(nz > 0));                  % total variance (exclude constant)
        if ~(V > 0) || ~isfinite(V)
            S_first(j,:)=0;
            S_total(j,:)=0;
            S2ind(j,:)=0;
            continue;   % constant / degenerate output -> all indices 0
        end
        for i = 1:M
            S_first(j, i) = sum(c2(active(:, i) & nz == 1)) / V;
            S_total(j, i) = sum(c2(active(:, i))) / V;
        end
        for q = 1:nPairs
            sel = active(:, pairs(q, 1)) & active(:, pairs(q, 2)) & nz == 2;
            S2ind(j, q) = sum(c2(sel)) / V;
        end
    end

    % analytic indices are non-negative by construction; clip only float noise
    S_first(S_first < 0 & S_first > -1e-9) = 0;
    S_total(S_total < 0 & S_total > -1e-9) = 0;
    S2ind(S2ind   < 0 & S2ind   > -1e-9) = 0;

    S2.indices    = S2ind;
    S2.pairs      = pairs;
    S2.pairLabels = cell(nPairs, 1);
    for q = 1:nPairs
        S2.pairLabels{q} = sprintf('%s x %s', P.names{pairs(q, 1)}, P.names{pairs(q, 2)});
    end
end

function components = pce_components(pce)
%PCE_COMPONENTS Normalize legacy multi-output and output-wise ensemble layouts.
    if isstruct(pce) && isfield(pce,'models')
        components=cell(size(pce.models));
        for j=1:numel(pce.models)
            model=pce.models{j};
            if isempty(model),components{j}=[];continue;end
            assert(has_member(model,'PCE') && ~isempty(model.PCE), ...
                'sensitivity:pce_sobol_analytic:InvalidEnsemble', ...
                'PCE ensemble component %d has no PCE representation.',j);
            components{j}=model.PCE(1);
        end
    else
        assert(has_member(pce,'PCE'), ...
            'sensitivity:pce_sobol_analytic:InvalidModel', ...
            'Expected a UQLab PCE model or output-wise PCE ensemble.');
        components=arrayfun(@(x)x,pce.PCE,'UniformOutput',false);
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
