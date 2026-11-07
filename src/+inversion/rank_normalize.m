function z = rank_normalize(x)
%RANK_NORMALIZE Blom normal scores of pooled midranks.
%   Z = inversion.rank_normalize(X) replaces every value of X by the normal
%   score of its rank among all values of X (ties get midranks; Blom's
%   offset (r - 3/8)/(n + 1/4)) and returns them in the shape of X.
%   Side effects: none.
    shape = size(x);
    v = x(:);
    assert(all(isfinite(v)), 'inversion:rank_normalize:NonFinite', ...
        'Rank normalization requires finite values.');
    [sorted, order] = sort(v);
    ranks = zeros(size(v));
    i = 1;
    while i <= numel(v)
        j = i;
        while j < numel(v) && sorted(j+1) == sorted(i), j = j + 1; end
        ranks(order(i:j)) = (i + j) / 2;
        i = j + 1;
    end
    p = (ranks - 3/8) / (numel(v) + 1/4);
    z = reshape(sqrt(2) * erfinv(2*p - 1), shape);
end
