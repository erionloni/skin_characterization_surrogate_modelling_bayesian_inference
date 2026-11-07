function q = weighted_quantile(x, probs, w)
%WEIGHTED_QUANTILE Quantiles of a (optionally) weighted sample.
%   q = WEIGHTED_QUANTILE(x, probs) returns the quantiles of x at the
%   probability levels in probs (unweighted).
%   q = WEIGHTED_QUANTILE(x, probs, w) weights each sample by w.
%
%   Uses the Hazen plotting-position weighted empirical CDF with linear
%   interpolation between order statistics -- robust to zero/duplicate
%   weights (replaces the legacy interp1-on-raw-CDF helper that broke when
%   many importance weights were zero). Single source of truth for the whole
%   pipeline.
%   Side effects: none.

    x     = x(:);
    probs = probs(:).';
    if nargin < 3 || isempty(w)
        w = ones(size(x));
    end
    w = w(:);

    ok = isfinite(x) & isfinite(w) & w > 0;
    x  = x(ok);
    w  = w(ok);
    if isempty(x) || sum(w) <= 0
        q = nan(size(probs));
        return;
    end

    [xs, order] = sort(x);
    ws = w(order);

    % Hazen plotting positions: cumulative weight to the centre of each point.
    cw = cumsum(ws);
    pp = (cw - 0.5 * ws) / sum(ws);

    if isscalar(xs)
        q = repmat(xs, size(probs));
        return;
    end

    % De-duplicate identical positions so interp1 stays monotonic.
    [pp, iu] = unique(pp, 'stable');
    xs = xs(iu);

    q = interp1(pp, xs, probs, 'linear');
    q(probs <= pp(1))   = xs(1);     % clamp below the first plotting position
    q(probs >= pp(end)) = xs(end);   % clamp above the last
end
