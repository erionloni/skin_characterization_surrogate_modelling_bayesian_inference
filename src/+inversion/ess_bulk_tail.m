function [bulkESS, tailESS] = ess_bulk_tail(chains)
%ESS_BULK_TAIL Bulk and tail ESS of independent replicate traces.
%   [BULKESS, TAILESS] = inversion.ess_bulk_tail(CHAINS) returns, per
%   parameter of CHAINS (iteration-by-parameter-by-independent replicate),
%   the ESS of the rank-normalized traces (bulk) and the smaller of the
%   ESS of the indicators of the 5% and 95% tails (tail), each with
%   inversion.ess_geyer. Ranks are taken per parameter.
%   Side effects: none.
    [~, m, ~] = size(chains);
    ranked = nan(size(chains));
    low = false(size(chains)); high = false(size(chains));
    for j = 1:m
        x = chains(:, j, :);
        ranked(:, j, :) = inversion.rank_normalize(x);
        q = quantile(x(:), [0.05 0.95]);
        low(:, j, :) = x <= q(1); high(:, j, :) = x >= q(2);
    end
    bulkESS = inversion.ess_geyer(ranked);
    lowerESS = inversion.ess_geyer(double(low));
    upperESS = inversion.ess_geyer(double(high));
    tailESS = min(lowerESS, upperESS);
end
