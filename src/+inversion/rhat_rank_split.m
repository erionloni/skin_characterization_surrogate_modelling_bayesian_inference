function rhat = rhat_rank_split(chains)
%RHAT_RANK_SPLIT Rank-normalized, folded split-Rhat per parameter.
%   Input traces must represent genuinely independent replicates, not AIES walkers.
%   RHAT = inversion.rhat_rank_split(CHAINS) returns, per parameter of
%   CHAINS (iteration-by-parameter-by-replicate), the larger of the split
%   R-hat of the rank-normalized and of the folded rank-normalized traces.
%   Side effects: none.
    split = inversion.split_chains(chains);
    [~, m, ~] = size(split);
    rhat = nan(1, m);
    for j = 1:m
        x = squeeze(split(:, j, :));
        if all(x(:) == x(1))
            rhat(j) = 1; % frozen-state gate separately rejects this case
            continue;
        end
        if any(var(x, 0, 1) == 0) && numel(unique(x(:))) > 1
            rhat(j) = Inf; continue;
        end
        z = inversion.rank_normalize(x);
        folded = inversion.rank_normalize(abs(x - median(x(:))));
        rhat(j) = max(classic_rhat(z), classic_rhat(folded));
    end
end

function value = classic_rhat(x)
    n = size(x, 1);
    W = mean(var(x, 0, 1));
    if W == 0, value = Inf; return; end
    B = n * var(mean(x, 1), 0);
    value = sqrt(((n - 1) / n * W + B / n) / W);
end
