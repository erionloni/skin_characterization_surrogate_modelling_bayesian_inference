function D = duplicate_state_detector(runs, bounds, tolerance)
%DUPLICATE_STATE_DETECTOR Detect duplicated analyses and state trajectories.
%   RUNS contains independently executed analyses, each T x M x S. Exact or
%   near-exact duplication is assessed in normalized coordinates. For AIES,
%   sampler states are interacting walkers; duplication is still a corruption
%   diagnostic, never a claim that walkers are independent chains.
%   D = inversion.duplicate_state_detector(RUNS, BOUNDS, TOLERANCE) reports
%   duplicated analyses and duplicated state trajectories within
%   TOLERANCE (in coordinates normalized by BOUNDS), the fraction of
%   duplicated states and whether any duplicate exists.
%   Side effects: none.

    if nargin < 3 || isempty(tolerance), tolerance = 1e-12; end
    assert(iscell(runs) && ~isempty(runs), ...
        'inversion:duplicate_state_detector:Empty', ...
        'At least one analysis is required.');
    nRun = numel(runs);
    runDuplicate = false(nRun);
    statePairs = cell(nRun,1);
    duplicateStates = 0;
    totalStates = 0;
    normalizedRuns = cell(nRun,1);
    for r = 1:nRun
        X = normalize_array(runs{r}, bounds);
        normalizedRuns{r} = X;
        nState = size(X,3);
        totalStates = totalStates + nState;
        pairs = zeros(0,2);
        for a = 1:nState-1
            for b = a+1:nState
                if max(abs(X(:,:,a)-X(:,:,b)),[],'all') <= tolerance
                    pairs(end+1,:) = [a b]; %#ok<AGROW>
                end
            end
        end
        statePairs{r} = pairs;
        if ~isempty(pairs), duplicateStates = duplicateStates + numel(unique(pairs(:))); end
    end
    for a = 1:nRun-1
        for b = a+1:nRun
            A = normalizedRuns{a}; B = normalizedRuns{b};
            n = min(size(A,1),size(B,1));
            s = min(size(A,3),size(B,3));
            runDuplicate(a,b) = max(abs(A(end-n+1:end,:,1:s)- ...
                B(end-n+1:end,:,1:s)),[],'all') <= tolerance;
            runDuplicate(b,a) = runDuplicate(a,b);
        end
    end
    duplicatedRuns = find(any(runDuplicate,2));
    D.analysisPairMatrix = runDuplicate;
    D.duplicatedAnalyses = duplicatedRuns(:).';
    D.statePairs = statePairs;
    D.anyDuplicateAnalysis = ~isempty(duplicatedRuns);
    D.anyDuplicateStateTrajectory = any(cellfun(@(x)~isempty(x),statePairs));
    D.duplicateStateFraction = duplicateStates/max(totalStates,1);
    D.anyDuplicate = D.anyDuplicateAnalysis || D.anyDuplicateStateTrajectory;
    D.tolerance = tolerance;
    D.definition = 'normalized_full_trajectory_duplicate_detector_v1';
end

function U = normalize_array(X,bounds)
    assert(isnumeric(X) && ndims(X)==3 && size(X,2)==size(bounds,1) && ...
        all(isfinite(X(:))), ...
        'inversion:duplicate_state_detector:Shape', ...
        'Each run must be a finite T x M x S array.');
    lo = reshape(bounds(:,1),1,[],1);
    width = reshape(bounds(:,2)-bounds(:,1),1,[],1);
    U = (X-lo)./width;
end
