function draws = gaussian_draws(meanVector,covariance,nDraws,seed)
%GAUSSIAN_DRAWS Independent Gaussian draws with a fixed seed.
%   DRAWS = design_study.gaussian_draws(MEANVECTOR, COVARIANCE, NDRAWS, SEED)
%   returns NDRAWS draws (NDRAWS-by-P) of the Gaussian with mean MEANVECTOR
%   (P values) and the positive-definite COVARIANCE (P-by-P), generated
%   with the seed SEED (Mersenne twister).
%   Side effects: none (the random number generator's state is restored).
    meanVector = meanVector(:);
    assert(isscalar(nDraws) && nDraws==fix(nDraws) && nDraws>0 && ...
        isscalar(seed) && isfinite(seed), ...
        'design_study:gaussian_draws:Configuration', ...
        'nDraws and seed must be positive finite integers.');
    [L,flag] = chol((covariance+covariance.')/2,'lower');
    assert(flag==0,'design_study:gaussian_draws:Covariance', ...
        'Covariance must be positive definite.');
    previous = rng;
    cleanup = onCleanup(@() rng(previous));
    rng(seed,'twister');
    draws = meanVector.'+randn(nDraws,numel(meanVector))*L.';
end

