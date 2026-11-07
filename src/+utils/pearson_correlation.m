function coefficient = pearson_correlation(left,right)
%PEARSON_CORRELATION Toolbox-free Pearson coefficient for two vectors.
%   NaNs are deliberately not removed, and constant or undersized inputs
%   return NaN, matching CORR's default behavior for the active call sites.
%   COEFFICIENT = utils.pearson_correlation(LEFT, RIGHT).
%   Side effects: none.

    assert((isnumeric(left)||islogical(left))&&isvector(left)&& ...
        (isnumeric(right)||islogical(right))&&isvector(right), ...
        'utils:pearson_correlation:VectorInputs', ...
        'Pearson correlation requires two numeric or logical vectors.');
    assert(numel(left)==numel(right), ...
        'utils:pearson_correlation:LengthMismatch', ...
        'Pearson correlation vectors must have equal length.');
    if numel(left)<2
        coefficient=NaN;
        return;
    end
    matrix=corrcoef(double(left(:)),double(right(:)));
    coefficient=matrix(1,2);
end
