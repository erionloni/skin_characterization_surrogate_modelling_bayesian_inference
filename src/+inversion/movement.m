function M = movement(theta, bounds, cfg)
%MOVEMENT Per-walker movement/frozen-state diagnostics in normalized space.
%   THETA is [iteration x parameter x walker].
%   M = inversion.movement(THETA, BOUNDS, CFG) returns, per walker, the
%   number of distinct states and the fraction of iterations with a move
%   (coordinates normalized by BOUNDS), which walkers are frozen or move
%   less than CFG.mcmcDiagnostics.v2.frozenMovementFraction, and whether
%   any does.
%   Side effects: none.
    assert(isnumeric(theta) && size(theta,2) == size(bounds,1) && size(bounds,2) == 2, ...
        'inversion:movement:Shape', 'Theta must be T x M x W with M x 2 bounds.');
    assert(all(isfinite(theta(:))), 'inversion:movement:NonFinite', ...
        'Movement diagnostics require finite samples.');
    assert(all(bounds(:,2) > bounds(:,1)), 'inversion:movement:Bounds', ...
        'Every upper bound must exceed its lower bound.');
    width = reshape(bounds(:,2) - bounds(:,1), 1, [], 1);
    lo = reshape(bounds(:,1), 1, [], 1);
    u = (theta - lo) ./ width;
    [n, ~, w] = size(u);
    step = squeeze(sqrt(sum(diff(u, 1, 1).^2, 2)));
    if w == 1, step = step(:); end
    moved = step > sqrt(eps);
    M.movementFraction = sum(moved, 1) / max(n - 1, 1);
    M.uniqueStateCount = zeros(1, w);
    M.longestStationaryRun = zeros(1, w);
    M.normalizedRange = zeros(w, size(u,2));
    for k = 1:w
        states = squeeze(u(:, :, k));
        M.uniqueStateCount(k) = size(unique(states, 'rows'), 1);
        M.normalizedRange(k, :) = max(states, [], 1) - min(states, [], 1);
        M.longestStationaryRun(k) = longest_run(~moved(:, k));
    end
    M.frozen = M.uniqueStateCount < 2;
    M.lowMovement = M.movementFraction < cfg.mcmcDiagnostics.v2.frozenMovementFraction;
    M.anyFrozen = any(M.frozen);
    M.anyLowMovement = any(M.lowMovement);
    M.definition = 'per_interacting_walker_normalized_state_movement_v1';
end

function longest = longest_run(stationaryTransitions)
    longest = 0; current = 0;
    for i = 1:numel(stationaryTransitions)
        if stationaryTransitions(i), current = current + 1; longest = max(longest, current);
        else, current = 0;
        end
    end
end
