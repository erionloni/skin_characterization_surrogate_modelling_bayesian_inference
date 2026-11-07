function [aligned,flipped,pivotIndex] = align_vector_sign(vector)
%ALIGN_VECTOR_SIGN Apply a deterministic display sign to one real vector.
%   The entry with largest absolute magnitude is made positive. MATLAB's
%   first-index MAX rule resolves exact ties in canonical coordinate order.
%   [ALIGNED, FLIPPED, PIVOTINDEX] = recovery.align_vector_sign(VECTOR)
%   returns the vector with that sign, whether it was flipped and the index
%   of the entry that decided the sign.
%   Side effects: none.

    assert(isnumeric(vector)&&isreal(vector)&&isvector(vector)&& ...
        ~isempty(vector)&&all(isfinite(vector(:))), ...
        'recovery:align_vector_sign:Vector', ...
        'vector must be a nonempty finite real numeric vector.');
    wasRow=isrow(vector);aligned=double(vector(:));
    [largestMagnitude,pivotIndex]=max(abs(aligned));
    assert(largestMagnitude>0,'recovery:align_vector_sign:ZeroVector', ...
        'A zero vector has no defined display sign.');
    flipped=aligned(pivotIndex)<0;
    if flipped,aligned=-aligned;end
    if wasRow,aligned=aligned.';end
end
