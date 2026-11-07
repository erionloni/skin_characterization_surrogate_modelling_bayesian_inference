function value = option_value(opts,name,fallback)
%OPTION_VALUE The field NAME of the options struct OPTS, or FALLBACK.
%   VALUE = inversion.option_value(OPTS, NAME, FALLBACK) returns OPTS.(NAME)
%   when OPTS has that field and it is not empty, else FALLBACK.
%   Side effects: none.
    if isfield(opts,name) && ~isempty(opts.(name))
        value = opts.(name);
    else
        value = fallback;
    end
end
