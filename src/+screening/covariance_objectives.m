function values=covariance_objectives(C)
%COVARIANCE_OBJECTIVES The six screening objectives of one 4-by-4 material covariance.
%   VALUES = screening.covariance_objectives(C) returns, for the covariance
%   C of the four material parameters (m3_f, m3_e, log10 k0, thickness) in
%   prior-standard-deviation units, the six objectives of
%   screening.objective_registry (all minimized): the largest eigenvalue of
%   the (m3_e, log10 k0) block, var(log10 k0), var(m3_e), var(m3_f),
%   var(thickness) and var(m3_e) + var(log10 k0). It serves the FIM proxy
%   and empirical posterior covariances alike: no regularization, no
%   dimension is dropped. C must be symmetric and positive semidefinite.
%   Side effects: none.
    assert(isnumeric(C)&&isreal(C)&&isequal(size(C),[4 4])&& ...
        all(isfinite(C),'all'),'screening:covariance_objectives:Shape', ...
        'A finite real 4-by-4 prior-SD material covariance is required.');
    scale=max(norm(C,'fro'),realmin);
    assert(norm(C-C.','fro')<=1e-12*scale, ...
        'screening:covariance_objectives:Symmetry','Covariance must be symmetric.');
    assert(min(eig((C+C.')/2))>=-1e-12*scale, ...
        'screening:covariance_objectives:PSD','Covariance must be positive semidefinite.');
    values=[max(eig(C([2 3],[2 3]))) C(3,3) C(2,2) C(1,1) C(4,4) C(2,2)+C(3,3)];
end
