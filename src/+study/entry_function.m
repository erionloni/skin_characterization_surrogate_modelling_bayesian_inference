function f = entry_function(entry)
%ENTRY_FUNCTION Name of the entry-point function of one route.
%   F = study.entry_function(ENTRY) maps 'fixed' and 'generalized' to
%   run_fixed_study and run_generalized_study.
%   Side effects: none.
    switch char(string(entry))
        case 'fixed', f = 'run_fixed_study';
        case 'generalized', f = 'run_generalized_study';
        otherwise
            error('study:entry_function:UnknownRoute', ...
                'Unknown route "%s". Use fixed or generalized.', char(string(entry)));
    end
end
