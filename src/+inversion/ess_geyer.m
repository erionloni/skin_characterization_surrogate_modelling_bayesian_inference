function ess = ess_geyer(chains)
%ESS_GEYER Split-chain ESS with initial-positive/initial-monotone sequence.
%   ESS = inversion.ess_geyer(CHAINS) returns the effective sample size of
%   each parameter; CHAINS is [iteration x parameter x independent replicate].
%   Each chain is centred once per parameter, and the autocorrelation of a
%   lag is computed only when Geyer's pair sequence reads it (it stops at
%   the first non-positive pair); every value is computed by the same
%   expression as before, so the result is bit-identical (CLN-042).
%   ESS (1-by-parameter) is at most the number of iterations times the
%   number of chains after splitting.
%   Side effects: none.
    x = inversion.split_chains(chains);
    [n, m, c] = size(x);
    ess = nan(1, m);
    for j = 1:m
        q = squeeze(x(:, j, :));
        if numel(unique(q(:))) < 2, ess(j) = 0; continue; end
        W = mean(var(q, 0, 1));
        B = n * var(mean(q, 1), 0);
        varPlus = (n - 1) / n * W + B / n;
        if ~(varPlus > 0), ess(j) = 0; continue; end
        centered = zeros(n, c);
        for k = 1:c
            centered(:, k) = q(:, k) - mean(q(:, k));
        end
        % Geyer's initial-positive sequence starts with rho(0)+rho(1),
        % followed by rho(2)+rho(3), etc.
        pairs = zeros(0, 1);
        firstLag = 0;
        while firstLag + 1 <= n - 1
            pair = autocorrelation(centered, firstLag, n, c, W, varPlus) + ...
                autocorrelation(centered, firstLag + 1, n, c, W, varPlus);
            if pair <= 0, break; end
            pairs(end+1, 1) = pair; %#ok<AGROW>
            firstLag = firstLag + 2;
        end
        for k = 2:numel(pairs), pairs(k) = min(pairs(k), pairs(k-1)); end
        tau = max(-1 + 2 * sum(pairs), 1);
        ess(j) = min(c * n / tau, c * n);
    end
end

function rho = autocorrelation(centered, lag, n, c, W, varPlus)
%AUTOCORRELATION The combined autocorrelation of the chains at one lag (1 at lag 0).
    if lag == 0, rho = 1; return; end
    acov = 0;
    for k = 1:c
        acov = acov + sum(centered(1:n-lag, k) .* centered(1+lag:n, k)) / n;
    end
    acov = acov / c;
    rho = 1 - (W - acov) / varPlus;
end
