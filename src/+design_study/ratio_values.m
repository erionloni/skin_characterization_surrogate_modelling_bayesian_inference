function ratios = ratio_values(outputs,denominatorFloor)
%RATIO_VALUES The four cycle ratios of many pressure vectors.
%   RATIOS = design_study.ratio_values(OUTPUTS, DENOMINATORFLOOR) returns
%   [p2_D2/p1_D2, p3_D2/p1_D2, p2_D6/p1_D6, p3_D6/p1_D6] for every row of
%   OUTPUTS (N-by-6 closing pressures): N-by-4. A denominator at or below
%   DENOMINATORFLOOR (default 1e-10) is refused, never clamped.
%   Side effects: none.
    if nargin < 2 || isempty(denominatorFloor), denominatorFloor = 1e-10; end
    assert(isnumeric(outputs) && size(outputs,2)==6 && ...
        all(isfinite(outputs(:))), ...
        'design_study:ratio_values:Shape', ...
        'outputs must be a finite N-by-6 matrix.');
    denominators = outputs(:,[1 1 4 4]);
    assert(all(abs(denominators(:))>denominatorFloor), ...
        'design_study:ratio_values:UnsafeDenominator', ...
        'At least one ratio denominator is at or below the safety floor.');
    ratios = outputs(:,[2 3 5 6])./denominators;
end

