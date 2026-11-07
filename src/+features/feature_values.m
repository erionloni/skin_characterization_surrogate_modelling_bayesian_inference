function F = feature_values(Y, C)
%FEATURE_VALUES The catalog features of closing pressures.
%   F = features.feature_values(Y, C) returns, for Y (N x 6 positive
%   pressures, mbar, in the order of the outputs) and catalog rows C
%   (features.catalog), the N x height(C) feature values: for a log-linear
%   feature its logarithm, log(Y) * w' (the log convention); for a raw one
%   Y * a', divided by Y * b' when b is given (the raw convention).
%   Side effects: none.

    assert(isnumeric(Y) && size(Y, 2) == 6 && all(isfinite(Y), 'all') && all(Y > 0, 'all'), ...
        'features:feature_values:Pressures', 'Expected N x 6 positive finite pressures.');
    Y = double(Y);
    F = zeros(size(Y, 1), height(C));
    logY = log(Y);
    for k = 1:height(C)
        if C.Type(k) == "loglinear"
            F(:, k) = logY * C.Weights(k, :).';
        elseif any(C.Denominator(k, :))
            F(:, k) = (Y * C.Weights(k, :).') ./ (Y * C.Denominator(k, :).');
        else
            F(:, k) = Y * C.Weights(k, :).';
        end
    end
end
