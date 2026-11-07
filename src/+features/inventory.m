function [E, values] = inventory(route, C)
%INVENTORY The derived features that a route's sensitivity step computes, and the catalog features they are.
%   [E, VALUES] = features.inventory(ROUTE, C) lists, for ROUTE ('fixed' or
%   'generalized'), the derived features that its sensitivity step computes:
%     fixed        the four ratios of cycles 2 and 3 to cycle 1 of each probe
%                  (sensitivity.ratio_sobol, design_study.ratio_values)
%     generalized  the 16 derived features of sensitivity.derived_features:
%                  the four ratios, the six cycle drops (mbar) and the six
%                  relative drops
%   all in the raw convention, and finds the catalog feature of C that each
%   one is. E has one row per existing feature: ExistingName; Feature (the
%   catalog feature, "" for none); Relation, "same" (equal to the catalog
%   feature in the raw convention, e.g. p2/p1 for r21), "affine" (Offset +
%   Scale times it, e.g. a relative drop, 1 - r21) or "none"; Offset; Scale.
%   The relations are found, not declared: both definitions are evaluated on
%   random pressures (a random stream of its own; the global generator is
%   untouched). VALUES is a handle, VALUES(Y), that computes the existing
%   features of N x 6 pressures Y with the existing code, in the column order
%   of E.
%   Side effects: none.

    switch route
        case 'fixed'
            names = {'r21_D2', 'r31_D2', 'r21_D6', 'r31_D6'};
            values = @(Y) design_study.ratio_values(Y, 1e-12);
        case 'generalized'
            [~, names] = sensitivity.derived_features(ones(1, 6));
            values = @(Y) sensitivity.derived_features(Y);
        otherwise
            error('features:inventory:Route', 'Unknown route "%s": fixed or generalized.', route);
    end
    stream = RandStream('twister', 'Seed', 1);
    Y = 50 + 250 * rand(stream, 200, 6);
    G = values(Y);
    raw = features.feature_values(Y, C);
    loglinear = C.Type == "loglinear";
    raw(:, loglinear) = exp(raw(:, loglinear));
    n = numel(names);
    E = table(string(names(:)), strings(n, 1), repmat("none", n, 1), zeros(n, 1), ones(n, 1), ...
        'VariableNames', {'ExistingName', 'Feature', 'Relation', 'Offset', 'Scale'});
    for i = 1:n
        g = G(:, i);
        for k = 1:height(C)
            f = raw(:, k);
            if max(abs(g - f)) <= 1e-12 * max(abs(g))
                E.Feature(i) = C.Name(k); E.Relation(i) = "same"; E.Offset(i) = 0; E.Scale(i) = 1;
                break;
            end
            design = [ones(size(f)) f];
            coefficients = design \ g;
            if E.Relation(i) == "none" && abs(coefficients(2)) > 1e-8 && ...
                    max(abs(design * coefficients - g)) <= 1e-10 * max(abs(g))
                E.Feature(i) = C.Name(k); E.Relation(i) = "affine";
                E.Offset(i) = round(coefficients(1), 12); E.Scale(i) = round(coefficients(2), 12);
            end
        end
    end
end
