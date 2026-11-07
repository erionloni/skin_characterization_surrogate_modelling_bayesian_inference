function st = style()
%STYLE Shared figure style for every plot in the pipeline.
%   st = STYLE() applies publication defaults to the graphics root (fonts,
%   line widths, grid) and returns a struct of reusable style constants:
%
%       st.fontSize   base font size (pt)
%       st.lineWidth  default line width
%       st.figSize    default [width height] in pixels
%       st.palette    Nx3 colour-blind-friendly RGB palette (one row/parameter,
%                     so st.palette(i,:) is parameter i's colour)
%
%   Every plotting function starts with `st = plotting.style();` so figures
%   share one look-and-feel instead of per-script formatting.
%   Side effects: sets default graphics properties of the MATLAB session
%   (the renderers restore them afterwards; plotting.preserve_graphics_defaults).

    st.fontSize  = 11;
    st.lineWidth = 1.2;
    st.figSize   = [900 560];

    % Okabe-Ito colour-blind-safe palette.
    st.palette = [ ...
        0.00 0.45 0.70;   % blue    (m3_f_RD)
        0.90 0.62 0.00;   % orange  (m3_e_RD)
        0.00 0.62 0.45;   % green   (log10_k0_RD)
        0.80 0.40 0.00;   % vermilion (Thickness_RD)
        0.35 0.35 0.35;   % grey    (reference)
        0.80 0.47 0.65];  % purple  (extra)

    set(groot, ...
        'defaultAxesFontSize',        st.fontSize, ...
        'defaultAxesLineWidth',       0.75, ...
        'defaultLineLineWidth',       st.lineWidth, ...
        'defaultAxesBox',             'on', ...
        'defaultAxesXGrid',           'on', ...
        'defaultAxesYGrid',           'on', ...
        'defaultFigureColor',         'w', ...
        'defaultAxesTickLabelInterpreter', 'none', ...
        'defaultLegendInterpreter',   'none');
end
