function C = catalog(cfg)
%CATALOG The derived features of the settings (0.7), one row each.
%   C = features.catalog(CFG) returns the feature catalog of
%   CFG.features.catalog as a table: Name, Family, Type ('loglinear' or
%   'raw'), Weights (1 x 6: w of a log-linear feature, log f = w * log(p);
%   a of a raw one), Denominator (1 x 6: b of a raw quotient
%   f = (a * p) / (b * p); zeros for f = a * p and for a log-linear
%   feature), Unit, Status ('core' or 'exploratory'), Hypothesis and Formula
%   (the definition as text, in the output names). The pressures p are the
%   six outputs in the order of CFG.outputNames (features.definitions). The
%   settings validation checks the entries (study.settings_schema).
%   Side effects: none.

    D = features.definitions(cfg);
    rows = cfg.features.catalog;
    n = size(rows, 1);
    C = table(strings(n, 1), strings(n, 1), strings(n, 1), zeros(n, 6), zeros(n, 6), strings(n, 1), ...
        strings(n, 1), strings(n, 1), strings(n, 1), 'VariableNames', {'Name', 'Family', 'Type', ...
        'Weights', 'Denominator', 'Unit', 'Status', 'Hypothesis', 'Formula'});
    for k = 1:n
        C.Name(k) = string(rows{k, 1}); C.Family(k) = string(rows{k, 2}); C.Type(k) = string(rows{k, 3});
        weights = rows{k, 4};
        if C.Type(k) == "raw"
            C.Weights(k, :) = double(weights{1});
            if numel(weights) > 1, C.Denominator(k, :) = double(weights{2}); end
        else
            C.Weights(k, :) = double(weights);
        end
        C.Unit(k) = string(rows{k, 5}); C.Status(k) = string(rows{k, 6}); C.Hypothesis(k) = string(rows{k, 7});
        C.Formula(k) = formula(C(k, :), string(D.outputs));
    end
end

function text = formula(row, outputs)
%FORMULA The definition of one feature as text, e.g. "log f = log pcl2_D2_mbar - log pcl1_D2_mbar".
    if row.Type == "loglinear"
        text = "log f = " + combination(row.Weights, "log " + outputs);
    elseif any(row.Denominator)
        text = "f = (" + combination(row.Weights, outputs) + ") / (" + ...
            combination(row.Denominator, outputs) + ")";
    else
        text = "f = " + combination(row.Weights, outputs);
    end
end

function text = combination(weights, terms)
%COMBINATION A weighted sum as text, e.g. "-log p1 + log p2" or "1/3 log p1 + ...".
    text = "";
    for j = find(weights)
        w = weights(j);
        coefficient = "";
        if abs(abs(w) - 1) > 1e-12, coefficient = strtrim(string(rats(abs(w)))) + " "; end
        if strlength(text) == 0
            sign = ""; if w < 0, sign = "-"; end
        else
            sign = " + "; if w < 0, sign = " - "; end
        end
        text = text + sign + coefficient + terms(j);
    end
end
