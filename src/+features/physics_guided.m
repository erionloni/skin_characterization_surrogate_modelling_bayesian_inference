function G = physics_guided(cfg, C)
%PHYSICS_GUIDED The features of the observation design physics_guided_full_rank_six, matched to the catalog.
%   G = features.physics_guided(CFG, C) evaluates the design's transform
%   (inversion.physics_guided_full_rank_values) and every pressure and
%   catalog feature of C (features.catalog; a log-linear feature as
%   prod(p .^ w)) on random pressures (a random stream of its own) and
%   returns one row per feature of the design: Index (1-6), Feature (the
%   output or catalog feature it equals, "" for none) and Formula (for a
%   feature without a catalog entry, its log-linear form when it has one,
%   e.g. "pcl1_D2_mbar / pcl3_D6_mbar").
%   Side effects: none.

    D = features.definitions(cfg);
    stream = RandStream('twister', 'Seed', 2);
    Y = 50 + 250 * rand(stream, 200, 6);
    P = inversion.physics_guided_full_rank_values(Y, 1e-12);
    raw = features.feature_values(Y, C);
    loglinear = C.Type == "loglinear";
    raw(:, loglinear) = exp(raw(:, loglinear));
    candidates = [Y, raw];
    names = [string(D.outputs(:)); C.Name];
    n = size(P, 2);
    G = table((1:n).', strings(n, 1), strings(n, 1), 'VariableNames', {'Index', 'Feature', 'Formula'});
    for k = 1:n
        g = P(:, k);
        hit = find(max(abs(candidates - g), [], 1) <= 1e-12 * max(abs(g)), 1);
        if ~isempty(hit)
            G.Feature(k) = names(hit);
            G.Formula(k) = names(hit);
            continue;
        end
        w = log(Y) \ log(g);
        if max(abs(log(Y) * w - log(g))) <= 1e-10
            w(abs(w) < 1e-9) = 0;
            up = string(D.outputs(w > 0)); down = string(D.outputs(w < 0));
            G.Formula(k) = strjoin(up, ' * ') + " / " + strjoin(down, ' * ');
        end
    end
end
