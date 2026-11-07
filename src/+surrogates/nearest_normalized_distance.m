function d = nearest_normalized_distance(queryX, referenceX, bounds)
%NEAREST_NORMALIZED_DISTANCE Distance to a reference design on fixed bounds.
%   D = surrogates.nearest_normalized_distance(QUERYX, REFERENCEX, BOUNDS)
%   uses the same 2-by-M [lower; upper]
%   normalization for every query and reference set. In cross-validation,
%   omitted rows are excluded from REFERENCEX but never from BOUNDS, so fold
%   distances remain directly comparable.
%   D: one distance per row of QUERYX (in the unit box of BOUNDS).
%   Side effects: none.
    validateattributes(queryX,{'numeric'},{'2d','real','finite'});
    validateattributes(referenceX,{'numeric'}, ...
        {'2d','real','finite','ncols',size(queryX,2),'nonempty'});
    validateattributes(bounds,{'numeric'}, ...
        {'size',[2 size(queryX,2)],'real','finite'});
    lo=bounds(1,:);hi=bounds(2,:);width=hi-lo;
    if any(width<=0)
        error('surrogates:nearest_normalized_distance:DegenerateBounds', ...
            'Every canonical normalization dimension must have positive width.');
    end
    q=(queryX-lo)./width;
    r=(referenceX-lo)./width;
    d=nan(size(queryX,1),1);
    for i=1:size(queryX,1)
        d(i)=min(sqrt(sum((r-q(i,:)).^2,2)));
    end
end
