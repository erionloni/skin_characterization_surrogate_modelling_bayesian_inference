function [ratios, jacobian, covariance] = ratio_transform(y, rawCovariance, denominatorFloor)
%RATIO_TRANSFORM Shared cycle-ratio transform, Jacobian, and delta covariance.
%   The canonical ratios are [p2_D2/p1_D2, p3_D2/p1_D2,
%   p2_D6/p1_D6, p3_D6/p1_D6]. Denominators close to zero fail explicitly;
%   they are never silently clamped in the design study.
%
%   [RATIOS, JACOBIAN, COVARIANCE] = design_study.ratio_transform(Y,
%   RAWCOVARIANCE, DENOMINATORFLOOR) returns the four ratios of the six
%   pressures Y, their 4-by-6 Jacobian and, when RAWCOVARIANCE (6-by-6) is
%   given, the delta-method covariance JACOBIAN*RAWCOVARIANCE*JACOBIAN'
%   (empty otherwise). DENOMINATORFLOOR defaults to 1e-12.
%   Side effects: none.

    if nargin < 2, rawCovariance = []; end
    if nargin < 3 || isempty(denominatorFloor), denominatorFloor = 1e-12; end
    assert(isnumeric(y) && isvector(y) && numel(y)==6 && all(isfinite(y)), ...
        'design_study:ratio_transform:InvalidOutput', ...
        'y must be one finite six-output vector.');
    assert(isscalar(denominatorFloor) && isfinite(denominatorFloor) && ...
        denominatorFloor>0,'design_study:ratio_transform:InvalidFloor', ...
        'denominatorFloor must be a positive finite scalar.');
    y = y(:);
    denominatorIndices = [1 1 4 4];
    numeratorIndices = [2 3 5 6];
    denominator = y(denominatorIndices);
    assert(all(abs(denominator)>denominatorFloor), ...
        'design_study:ratio_transform:UnsafeDenominator', ...
        'A ratio denominator is at or below the configured safety floor.');

    ratios = y(numeratorIndices)./denominator;
    jacobian = zeros(4,6);
    for i = 1:4
        numerator = numeratorIndices(i);
        denominatorIndex = denominatorIndices(i);
        jacobian(i,numerator) = 1/y(denominatorIndex);
        jacobian(i,denominatorIndex) = ...
            -y(numerator)/y(denominatorIndex)^2;
    end

    if isempty(rawCovariance)
        covariance = [];
        return;
    end
    assert(isnumeric(rawCovariance) && isequal(size(rawCovariance),[6 6]) && ...
        all(isfinite(rawCovariance(:))), ...
        'design_study:ratio_transform:InvalidCovariance', ...
        'rawCovariance must be a finite 6-by-6 matrix.');
    symmetryError = norm(rawCovariance-rawCovariance.','fro')/ ...
        max(norm(rawCovariance,'fro'),eps);
    assert(symmetryError<=1e-10, ...
        'design_study:ratio_transform:NonSymmetricCovariance', ...
        'rawCovariance must be symmetric.');
    covariance = jacobian*((rawCovariance+rawCovariance.')/2)*jacobian.';
    covariance = (covariance+covariance.')/2;
end
