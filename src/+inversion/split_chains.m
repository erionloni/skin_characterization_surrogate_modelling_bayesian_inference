function split = split_chains(chains)
%SPLIT_CHAINS Split independent traces in half along the iteration dimension.
%   CHAINS is [iteration x parameter x independent replicate].
%   SPLIT = inversion.split_chains(CHAINS) returns the first and the last
%   half of every trace as separate traces (floor(iterations/2) by
%   parameter by twice the replicates).
%   Side effects: none.
    [n, m, c] = size(chains);
    half = floor(n / 2);
    assert(half >= 2 && c >= 2, 'inversion:split_chains:TooSmall', ...
        'At least four iterations and two independent replicates are required.');
    split = nan(half, m, 2*c);
    split(:, :, 1:c) = chains(1:half, :, :);
    split(:, :, c+1:end) = chains(n-half+1:n, :, :);
end
