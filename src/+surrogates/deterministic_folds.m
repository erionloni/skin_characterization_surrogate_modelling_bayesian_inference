function fold = deterministic_folds(n, k, seed)
%DETERMINISTIC_FOLDS Reproducible balanced fold IDs independent of ambient RNG.
%   Each input row is the indivisible unit; audit callers pass one row per
%   CaseID so that all six outputs remain grouped in the assigned fold.
%   FOLD = surrogates.deterministic_folds(N, K, SEED) returns the fold (1 to
%   K) of each of the N rows, with fold sizes differing by at most one.
%   Side effects: none (the random number generator's state is restored).
    validateattributes(n,{'numeric'},{'scalar','integer','positive'});
    validateattributes(k,{'numeric'},{'scalar','integer','>=',2,'<=',n});
    validateattributes(seed,{'numeric'},{'scalar','integer','nonnegative'});
    state=rng;cleanup=onCleanup(@()rng(state));
    rng(seed,'twister');order=randperm(n);fold=zeros(n,1);
    fold(order)=mod(0:n-1,k)+1;
    counts=accumarray(fold,1,[k 1]);
    assert(max(counts)-min(counts)<=1, ...
        'surrogates:deterministic_folds:Unbalanced', ...
        'Deterministic fold allocation must differ by at most one row.');
end
