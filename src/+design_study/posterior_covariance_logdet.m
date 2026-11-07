function value = posterior_covariance_logdet(matrix,draws)
%POSTERIOR_COVARIANCE_LOGDET Empirical covariance logdet without regularization.
% Preserve the ordinary SPD path exactly. If forming the Gram matrix loses
% positive definiteness in floating point, require exact binding to COV(draws)
% and resolvable full column rank of the centered draws, then use
% det(Cov(draws)) = det(R)^2/(N-1)^D. No matrix or draw is modified.
%
%   VALUE = design_study.posterior_covariance_logdet(MATRIX, DRAWS) returns
%   the log determinant of the posterior covariance MATRIX, computed from
%   the draws DRAWS (N-by-P) where the Gram matrix loses definiteness.
%   Side effects: none.
    covariance=(matrix+matrix.')/2;
    [~,flag]=chol(covariance,'lower');
    if flag==0
        value=design_study.logdet_spd(matrix);
        return
    end
    assert(isnumeric(draws)&&isreal(draws)&&ismatrix(draws)&& ...
        size(draws,1)>size(draws,2)&&size(draws,2)==size(matrix,1)&& ...
        all(isfinite(draws),'all'), ...
        'design_study:posterior_covariance_logdet:Draws', ...
        'A full-rank empirical covariance requires finite matching draws.');
    expected=cov(draws);expected=(expected+expected.')/2;
    assert(isequal(covariance,expected), ...
        'design_study:posterior_covariance_logdet:CovarianceBinding', ...
        ['A non-SPD matrix is not the unchanged empirical covariance of ' ...
         'the supplied posterior draws; no numerical repair is permitted.']);
    shifted=draws-draws(1,:);
    centered=shifted-mean(shifted,1);
    [~,factor]=qr(centered,0);
    singularValues=svd(factor);
    % Standard scale-relative numerical rank resolution of the draw matrix,
    % not a posterior acceptance threshold or covariance eigenvalue floor.
    tolerance=max(size(centered))*eps(singularValues(1));
    assert(singularValues(end)>tolerance, ...
        'design_study:posterior_covariance_logdet:RankDeficient', ...
        ['Centered posterior draws lack resolvable full column rank; ' ...
         'the full-dimensional covariance log-volume is unavailable.']);
    value=2*sum(log(abs(diag(factor))))- ...
        size(draws,2)*log(size(draws,1)-1);
    assert(isfinite(value),'design_study:posterior_covariance_logdet:Nonfinite', ...
        'The empirical full-rank covariance log determinant must be finite.');
end
