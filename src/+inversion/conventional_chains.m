function C = conventional_chains(runs)
%CONVENTIONAL_CHAINS Align and combine genuinely independent AM chains.
%   Each RUNS cell is one independently seeded UQLab analysis whose sample
%   array is [iteration x parameter x independent chain]. Analyses are
%   aligned on their most recent common retained length. The third dimension
%   is combined only because AM chains are independent; this helper
%   must never be used for interacting AIES walkers.
%   C = inversion.conventional_chains(RUNS) returns the aligned chains
%   (iteration-by-parameter-by-chain), their counts and the number of
%   independent time states.
%   Side effects: none.

    assert(iscell(runs) && ~isempty(runs), ...
        'inversion:conventional_chains:Empty', ...
        'At least one independent UQLab analysis is required.');
    nAnalysis = numel(runs);
    nParam = size(runs{1}, 2);
    nIteration = min(cellfun(@(x) size(x, 1), runs));
    assert(nIteration >= 4, 'inversion:conventional_chains:TooShort', ...
        'At least four retained iterations are required.');

    aligned = cell(nAnalysis, 1);
    nChainsPerAnalysis = zeros(nAnalysis, 1);
    combined = zeros(nIteration, nParam, 0);
    for r = 1:nAnalysis
        run = runs{r};
        assert(isnumeric(run) && size(run, 2) == nParam && size(run, 3) >= 1, ...
            'inversion:conventional_chains:Shape', ...
            'Each analysis must be iteration x parameter x independent chain.');
        assert(all(isfinite(run(:))), ...
            'inversion:conventional_chains:NonFinite', ...
            'Conventional-chain samples must be finite.');
        aligned{r} = run(end-nIteration+1:end, :, :);
        nChainsPerAnalysis(r) = size(run, 3);
        combined = cat(3, combined, aligned{r});
    end

    C.alignedRuns = aligned;
    C.combinedChains = combined;
    C.pooled = reshape(permute(combined, [1 3 2]), [], nParam);
    C.nIterations = nIteration;
    C.nIndependentAnalyses = nAnalysis;
    C.nChainsPerAnalysis = nChainsPerAnalysis;
    C.nIndependentChains = sum(nChainsPerAnalysis);
    C.maximumIndependentTimeStates = nIteration * C.nIndependentChains;
    C.definition = 'aligned_independent_AM_MH_chains_v1';
end
