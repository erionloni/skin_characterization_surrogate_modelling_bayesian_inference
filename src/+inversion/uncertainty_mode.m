function mode = uncertainty_mode(opts)
%UNCERTAINTY_MODE The uncertainty mode of a likelihood request.
%   MODE = inversion.uncertainty_mode(OPTS) returns OPTS.uncertaintyMode as a
%   character vector: 'measurement_plus_gp', 'gp_only' or
%   'numerical_floor_only' (the three canonical scenarios). Errors when the
%   field is missing, empty or another value.
%   Used by inversion.gp_log_likelihood and inversion.raw_observation_variance.
%   Side effects: none.
    assert(isfield(opts,'uncertaintyMode')&&~isempty(opts.uncertaintyMode), ...
        'inversion:uncertainty_mode:UncertaintyMode', ...
        'opts.uncertaintyMode is required.');
    mode=char(string(opts.uncertaintyMode));
    assert(ismember(mode, ...
        {'measurement_plus_gp','gp_only','numerical_floor_only'}), ...
        'inversion:uncertainty_mode:UncertaintyMode', ...
        'Unsupported uncertainty mode "%s".',mode);
end
