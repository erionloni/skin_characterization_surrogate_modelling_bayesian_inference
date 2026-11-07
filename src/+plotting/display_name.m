function text = display_name(kind, name, withUnit)
%DISPLAY_NAME TeX label of a parameter, output, scenario or design for figures.
%   TEXT = plotting.display_name(KIND, NAME) returns the label used on axes,
%   ticks and legends; KIND is 'parameter', 'output', 'scenario' or
%   'design'. TEXT = plotting.display_name(KIND, NAME, true) appends the
%   unit for parameters and outputs. Labels follow the thesis notation:
%     m3_f_RD      -> m_{3f,RD}               (dimensionless)
%     m3_e_RD      -> m_{3e,RD}               (dimensionless)
%     log10_k0_RD  -> log_{10}(k_{0,RD})      (k_0 in mm^4/(N s))
%     Thickness_RD -> t_{RD} [mm]
%     pcl1_D2_mbar -> p^{D2}_{cl,1} [mbar]    (cycles 1-3, probes D2/D6)
%   Parameters are shown in the model coordinates the posterior lives in:
%   log10 of the permeability, not the permeability itself.
%   NAME may be a cell or string array (TEXT is then a cell array). Unknown
%   names are returned unchanged with underscores escaped.
%   Use with the 'tex' interpreter. Side effects: none.

    if nargin < 3, withUnit = false; end
    if iscell(name) || (isstring(name) && ~isscalar(name))
        text = cellfun(@(n) plotting.display_name(kind, n, withUnit), cellstr(string(name)), ...
            'UniformOutput', false);
        return;
    end
    name = char(string(name));
    switch lower(kind)
        case 'parameter'
            switch name
                case 'm3_f_RD', text = 'm_{3f,RD}'; unit = '[-]';
                case 'm3_e_RD', text = 'm_{3e,RD}'; unit = '[-]';
                case 'log10_k0_RD', text = 'log_{10}(k_{0,RD})'; unit = '[k_0 in mm^4/(N s)]';
                case 'Thickness_RD', text = 't_{RD}'; unit = '[mm]';
                otherwise, text = escape(name); unit = '';
            end
        case 'output'
            token = regexp(name, '^pcl(\d)_(D\d)(_mbar)?$', 'tokens', 'once');
            if isempty(token)
                text = escape(name); unit = '';
            else
                text = sprintf('p^{%s}_{cl,%s}', token{2}, token{1}); unit = '[mbar]';
            end
        case 'scenario'
            unit = '';
            switch name
                case 'measurement_plus_gp', text = 'Measurement + GP';
                case 'gp_only', text = 'GP only';
                case 'gp_self_det', text = 'GP self-consistency (diagnostic)';
                case 'gp_mean_det', text = 'GP mean, COMSOL data';
                otherwise, text = escape(name);
            end
        case 'design'
            unit = '';
            switch name
                case 'all_six', text = 'All six';
                case 'd2_only', text = 'D2 only';
                case 'd6_only', text = 'D6 only';
                case 'cycle_1_only', text = 'Cycle 1 only';
                case 'ratios_only', text = 'Ratios only';
                case 'physics_guided_full_rank_six', text = 'Physics-guided six';
                otherwise, text = escape(name);
            end
        otherwise
            error('plotting:display_name:Kind', 'Unknown label kind "%s".', kind);
    end
    if withUnit && ~isempty(unit)
        text = [text ' ' unit];
    end
end

function t = escape(name)
    t = strrep(name, '_', '\_');
end
