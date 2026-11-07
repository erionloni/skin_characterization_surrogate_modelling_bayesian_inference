function M = chain_movement(theta, bounds, cfg)
%CHAIN_MOVEMENT Movement and frozen-state diagnostics of independent Adaptive Metropolis chains.
%   M = inversion.chain_movement(THETA, BOUNDS, CFG) computes the movement
%   diagnostics of inversion.movement for THETA (iteration-by-parameter-by-
%   independent chain; BOUNDS: parameter-by-2) and labels them as
%   diagnostics of independent chains (M.nIndependentChains,
%   M.stateSemantics); AIES walkers, which interact, are never labelled so.
%   Side effects: none.

    M = inversion.movement(theta, bounds, cfg);
    M.nIndependentChains = size(theta, 3);
    M.stateSemantics = 'independent_chains';
    M.definition = 'per_independent_MCMC_chain_normalized_state_movement_v1';
end
