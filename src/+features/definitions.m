function D = definitions(cfg)
%DEFINITIONS The shared definitions of the derived features of the closing pressures.
%   D = features.definitions(CFG) returns the one definition that the
%   ratio-error curves, the feature sensitivity and the feature accuracy use:
%     outputs  the six closing pressures in the canonical order
%              (CFG.outputNames: cycles 1, 2, 3 of probe D2, then of D6)
%     A        4 x 6 contrast matrix of the within-probe log-ratios against
%              cycle 1, rows D2 c2/c1, D2 c3/c1, D6 c2/c1, D6 c3/c1: for log
%              pressures p, A*log(p) are the four log-ratios
%     aR       1 x 6, the double ratio R21 = (p2/p1 of D2)/(p2/p1 of D6):
%              row 1 minus row 3 of A
%     c        the reference coefficient of variation of the units (settings
%              0.7, features.referenceCV; thesis 0.08: errors are read in
%              units of an 8 % relative error)
%   Logarithms are natural throughout.
%   Side effects: none.

    D.outputs = cellstr(string(cfg.outputNames));
    assert(numel(D.outputs) == 6, 'features:definitions:Outputs', ...
        'The derived features are defined for the six closing pressures (three cycles of D2 and D6).');
    D.A = [-1 1 0 0 0 0; -1 0 1 0 0 0; 0 0 0 -1 1 0; 0 0 0 -1 0 1];
    D.aR = D.A(1, :) - D.A(3, :);
    D.c = double(cfg.features.referenceCV);
end
