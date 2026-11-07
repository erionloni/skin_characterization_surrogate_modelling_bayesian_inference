function X = dispersed_initial_ensemble(bounds, nWalkers, method, parameters)
%DISPERSED_INITIAL_ENSEMBLE Initial walker positions spread over the prior box.
%   X = utils.dispersed_initial_ensemble(BOUNDS, NWALKERS, METHOD, PARAMETERS)
%   returns NWALKERS points (NWALKERS-by-P) inside the box BOUNDS (P-by-2),
%   drawn from the current random number generator: a Latin hypercube
%   (METHOD 'latin_hypercube', the default, or 'uqlab_default') or another
%   configured method.
%   Side effects: draws from the current random number generator.
    if nargin < 3 || isempty(method), method = 'latin_hypercube'; end
    if nargin < 4 || isempty(parameters), parameters = struct(); end
    m = size(bounds,1);
    switch method
        case {'latin_hypercube','uqlab_default'}
            U = lhs_design(nWalkers, m);
        case {'dispersed','maximin_latin_hypercube_32'}
            % Select the most separated of 32 deterministic LHS candidates.
            % This makes the Gate 2B dispersed policy scientifically distinct
            % from the baseline while remaining prior-wide and truth-blind.
            U = lhs_design(nWalkers, m);
            bestDistance = minimum_distance(U);
            for candidate = 2:32
                trial = lhs_design(nWalkers, m);
                trialDistance = minimum_distance(trial);
                if trialDistance > bestDistance
                    U = trial;
                    bestDistance = trialDistance;
                end
            end
        case 'uniform_random'
            U = rand(nWalkers,m);
        case 'local_box_latin_hypercube'
            center = option(parameters, 'normalizedCenter', []);
            halfWidth = option(parameters, 'normalizedHalfWidth', []);
            assert(isnumeric(center) && numel(center) == m && ...
                all(isfinite(center)) && all(center >= 0) && all(center <= 1), ...
                'utils:dispersed_initial_ensemble:InvalidLocalCenter', ...
                'normalizedCenter must contain one finite [0,1] value per parameter.');
            if isscalar(halfWidth), halfWidth = repmat(halfWidth, 1, m); end
            assert(isnumeric(halfWidth) && numel(halfWidth) == m && ...
                all(isfinite(halfWidth)) && all(halfWidth > 0), ...
                'utils:dispersed_initial_ensemble:InvalidLocalWidth', ...
                'normalizedHalfWidth must be positive and scalar or one value per parameter.');
            center = reshape(center, 1, m);
            halfWidth = reshape(halfWidth, 1, m);
            lower = max(0, center-halfWidth);
            upper = min(1, center+halfWidth);
            assert(all(upper > lower), ...
                'utils:dispersed_initial_ensemble:DegenerateLocalBox', ...
                'The clipped local initialization box has zero width.');
            U = lower + lhs_design(nWalkers, m) .* (upper-lower);
        otherwise
            error('utils:dispersed_initial_ensemble:UnknownMethod', ...
                'Unknown initialization method "%s".', method);
    end
    X = bounds(:,1).' + U .* (bounds(:,2) - bounds(:,1)).';
end

function value = option(parameters, name, fallback)
    if isstruct(parameters) && isfield(parameters, name) && ...
            ~isempty(parameters.(name))
        value = parameters.(name);
    else
        value = fallback;
    end
end

function U = lhs_design(n, m)
    U = zeros(n, m);
    for j = 1:m
        U(:,j) = ((randperm(n).' - 1) + rand(n,1)) / n;
    end
end

function value = minimum_distance(X)
    value = Inf;
    for i = 1:size(X,1)-1
        delta = X(i+1:end,:) - X(i,:);
        value = min(value, min(sqrt(sum(delta.^2, 2))));
    end
    if size(X,1) < 2, value = Inf; end
end
