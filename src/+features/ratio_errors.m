function R = ratio_errors(mu, y, D)
%RATIO_ERRORS How well predicted pressures reproduce the observed cycle-to-cycle ratios.
%   R = features.ratio_errors(MU, Y, D) takes predicted closing pressures MU
%   (N x 6, the GP means at N parameter values, mbar), the observed pressures
%   Y (1 x 6, mbar), both in the canonical order, and the shared definitions
%   D (features.definitions), and returns, per row of MU:
%     u                  log(MU) - log(Y), the relative errors of the six
%                        pressures (N x 6, natural log)
%     e                  A*u: the errors of the four within-probe log-ratios
%                        D2 c2/c1, D2 c3/c1, D6 c2/c1, D6 c3/c1 (N x 4)
%     d                  the combined ratio discrepancy in units of c (N x 1):
%                        sqrt(((a1^2 - a1 b1 + b1^2) + (a2^2 - a2 b2 + b2^2))
%                        / (6 c^2)) with (a1, b1) = e(:,1:2), (a2, b2) =
%                        e(:,3:4); the same as sqrt(e' (c^2 A A')^-1 e / 4),
%                        weighted for the shared cycle-1 denominator of the
%                        two ratios of a probe
%     dLevel             the level discrepancy (N x 1): sqrt(3 (mean(u(1:3))^2
%                        + mean(u(4:6))^2) / (2 c^2)); 4 d^2 + 2 dLevel^2 =
%                        sum(u.^2)/c^2
%     ratioErrorPercent  100 e (N x 4)
%     doubleRatioPercent 100 (e(:,1) - e(:,3)), the error of the double ratio
%                        R21 in percent (N x 1)
%   It checks its inputs: six positive finite observed pressures, and finite
%   positive predictions with six columns.
%   Side effects: none.

    assert(isnumeric(mu) && size(mu, 2) == 6 && all(isfinite(mu), 'all') && all(mu > 0, 'all'), ...
        'features:ratio_errors:Predictions', ...
        'The predictions must be finite positive pressures with six columns (canonical order).');
    assert(isnumeric(y) && numel(y) == 6 && all(isfinite(y)) && all(y > 0), ...
        'features:ratio_errors:Observation', ...
        'The observation must be six finite positive closing pressures (canonical order).');
    c = D.c;
    R.u = log(double(mu)) - log(reshape(double(y), 1, 6));
    R.e = R.u * D.A.';
    a1 = R.e(:, 1); b1 = R.e(:, 2); a2 = R.e(:, 3); b2 = R.e(:, 4);
    R.d = sqrt(((a1.^2 - a1.*b1 + b1.^2) + (a2.^2 - a2.*b2 + b2.^2)) / (6 * c^2));
    R.dLevel = sqrt(3 * (mean(R.u(:, 1:3), 2).^2 + mean(R.u(:, 4:6), 2).^2) / (2 * c^2));
    R.ratioErrorPercent = 100 * R.e;
    R.doubleRatioPercent = 100 * (R.e(:, 1) - R.e(:, 3));
end
