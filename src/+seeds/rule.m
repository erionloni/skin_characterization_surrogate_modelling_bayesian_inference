function seed = rule(seedRule, numbers)
%RULE The seed of a request without a recorded seed: a base seed plus fixed multiples of its numbers.
%   SEED = seeds.rule(RULE, NUMBERS) returns
%       RULE.base + sum over the axes of RULE.(axis) * NUMBERS.(axis).
%   RULE is one rule of the settings (cfg.seeds.rules): the base seed and a
%   multiplier per axis. NUMBERS gives the request's number on every axis
%   (a CaseID, a condition code, a replicate, ...), each a non-negative
%   integer. Every number must stay below the ratio of the next larger
%   multiplier to its own, so that two requests never share a seed and each
%   group of digits of the seed reads as one of the numbers; the seed must
%   lie between 1 and 2^31-2.
%   Side effects: none.

    axes = setdiff(fieldnames(seedRule), {'base'}, 'stable');
    given = fieldnames(numbers);
    assert(isequal(sort(axes), sort(given)), 'seeds:rule:Axes', ...
        'The seed rule has the axes %s; the request gives %s.', ...
        strjoin(axes, ', '), strjoin(given, ', '));
    multipliers = cellfun(@(name) double(seedRule.(name)), axes);
    [multipliers, order] = sort(multipliers, 'descend');
    axes = axes(order);
    seed = double(seedRule.base);
    for k = 1:numel(axes)
        value = double(numbers.(axes{k}));
        assert(isscalar(value) && isfinite(value) && value >= 0 && value == fix(value), ...
            'seeds:rule:Number', ...
            'The %s number of a seed must be a non-negative integer.', axes{k});
        if k > 1
            assert(value * multipliers(k) < multipliers(k - 1), 'seeds:rule:NumberRange', ...
                'The %s number %d is too large for its seed rule (at most %d).', ...
                axes{k}, value, ceil(multipliers(k - 1) / multipliers(k)) - 1);
        end
        seed = seed + multipliers(k) * value;
    end
    assert(seed >= 1 && seed <= 2^31 - 2, 'seeds:rule:Range', ...
        'The seed rule gives %d, outside 1 to 2147483646; lower its base seed.', seed);
end
