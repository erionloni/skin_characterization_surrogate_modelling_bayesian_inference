function [estimate,handles] = render_posterior_marginal(draws,bounds,varargin)
%RENDER_POSTERIOR_MARGINAL Draw a marginal density with its mode and central intervals.
%   [ESTIMATE, HANDLES] = plotting.render_posterior_marginal(DRAWS, BOUNDS,
%   ...) draws, into the current axes, the smoothed marginal density of
%   DRAWS within BOUNDS (plotting.posterior_marginal_density), its mode and
%   the central 50% and 95% intervals, and returns the estimate and the
%   graphics handles.
%   Options (name-value): 'Color' (RGB, default [0 0.45 0.70]), 'LineStyle'
%   ('-'), 'LineWidth' (1.7), 'DisplayName' ('posterior'),
%   'ShowCentralIntervals' (false: draw the 50% and 95% interval bars) and
%   'IntervalRow' (1: the row of the bars below the density, for several
%   densities on one axis).
%   Side effects: draws into the current axes.
    parser=inputParser;
    addParameter(parser,'Color',[0.00 0.45 0.70], ...
        @(x)isnumeric(x)&&numel(x)==3);
    addParameter(parser,'LineStyle','-',@(x)ischar(x)||isstring(x));
    addParameter(parser,'LineWidth',1.7,@(x)isnumeric(x)&&isscalar(x));
    addParameter(parser,'DisplayName','posterior',@(x)ischar(x)||isstring(x));
    addParameter(parser,'ShowCentralIntervals',false, ...
        @(x)islogical(x)&&isscalar(x));
    addParameter(parser,'IntervalRow',1,@(x)isnumeric(x)&&isscalar(x)&& ...
        isfinite(x)&&x>=1&&x==fix(x));
    parse(parser,varargin{:});
    color=reshape(double(parser.Results.Color),1,[]);
    estimate=plotting.posterior_marginal_density(draws,'Bounds',bounds);
    hold on;
    handles.density=plot(estimate.grid,estimate.density, ...
        'Color',color,'LineStyle',char(parser.Results.LineStyle), ...
        'LineWidth',double(parser.Results.LineWidth), ...
        'DisplayName',char(string(parser.Results.DisplayName)));
    values=[estimate.posteriorMean estimate.posteriorMedian ...
        estimate.marginalMode];
    markers={'o','s','^'};
    names={'posterior mean','posterior median','marginal mode'};
    fields={'mean','median','mode'};
    for i=1:3
        y=interp1(estimate.grid,estimate.density,values(i),'linear','extrap');
        handles.(fields{i})=plot(values(i),max(y,0),markers{i}, ...
            'Color',color,'MarkerFaceColor','white','MarkerSize',6, ...
            'LineWidth',1.2,'DisplayName',names{i});
    end
    handles.interval95=gobjects(0);handles.interval50=gobjects(0);
    if parser.Results.ShowCentralIntervals
        peak=max(estimate.density);
        baseline=-peak*(0.035+0.055*(double(parser.Results.IntervalRow)-1));
        lightColor=0.70+0.30*color;
        handles.interval95=plot([estimate.q025 estimate.q975], ...
            [baseline baseline],'-','Color',lightColor,'LineWidth',2, ...
            'DisplayName','central 95% interval');
        handles.interval50=plot([estimate.q25 estimate.q75], ...
            [baseline baseline],'-','Color',color,'LineWidth',5, ...
            'DisplayName','central 50% interval');
    end
end
