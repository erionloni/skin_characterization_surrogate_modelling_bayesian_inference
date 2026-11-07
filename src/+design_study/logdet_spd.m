function value = logdet_spd(matrix)
%LOGDET_SPD Log determinant of a symmetric positive-definite matrix.
%   VALUE = design_study.logdet_spd(MATRIX) returns log(det(MATRIX)) from
%   the Cholesky factor of the symmetrized MATRIX; a matrix that is not
%   positive definite is refused.
%   Side effects: none.
    assert(isnumeric(matrix) && ismatrix(matrix) && ...
        size(matrix,1)==size(matrix,2) && all(isfinite(matrix(:))), ...
        'design_study:logdet_spd:Shape','Input must be a finite square matrix.');
    [L,flag] = chol((matrix+matrix.')/2,'lower');
    assert(flag==0,'design_study:logdet_spd:PositiveDefinite', ...
        'Input must be positive definite.');
    value = 2*sum(log(diag(L)));
end

