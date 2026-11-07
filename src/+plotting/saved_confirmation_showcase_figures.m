function manifest = saved_confirmation_showcase_figures(cfg, ~)
%SAVED_CONFIRMATION_SHOWCASE_FIGURES The posteriors of the showcase material under the four protocols.
%   MANIFEST = plotting.saved_confirmation_showcase_figures(CFG, OPTIONS)
%   draws, for the showcase material of the compared confirmation
%   (plotting.confirmation_showcase: the rule of the settings, fixed before
%   the results), from the saved results of generalized/06_confirmation/data:
%     showcase_marginals  the marginal posterior density of each material
%                         parameter under each protocol (the campaign's
%                         saved densities of the provider's draws), with the
%                         truth;
%     showcase_corner     the corner plot: on the diagonal the marginals, below
%                         it for each protocol the regions that hold 50 % and
%                         90 % of the provider's retained draws (a 60 x 60
%                         histogram of every draw over the prior box,
%                         smoothed), with the truth.
%   Nothing is drawn before the step compare has run, nor when no material
%   meets the rule. MANIFEST: the rows of the figures written.
%   Side effects: writes the figures (study.export_figure) and closes them.
%   Computation: seconds.

    manifest = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', 'SourceArtifacts'});
    root = study.source_folder(cfg, 'confirmation');
    campaign = fullfile(root, 'campaign');
    sources = {fullfile(root, 'cell_status.csv'), ...
        fullfile(campaign, 'configuration', 'confirmation_configuration.json'), ...
        fullfile(campaign, 'summaries', 'posterior_marginal_density.csv'), ...
        fullfile(campaign, 'summaries', 'posterior_parameter_summary.csv')};
    if ~isfile(fullfile(campaign, 'status', 'confirmation_status.json')) || ~all(cellfun(@isfile, sources))
        return;
    end
    status = utils.read_csv_table(sources{1}, {'Protocol', 'ProtocolRole', 'Design', 'Status', ...
        'ProviderSampler', 'Reason'});
    configuration = jsondecode(fileread(sources{2}));
    % The confirmation's observation design (the summaries above are its own).
    design = char(string(configuration.design));
    status = status(status.Design == design, :);
    protocols = string({configuration.protocols.Protocol});
    id = plotting.confirmation_showcase(cfg, status, configuration.materials, protocols);
    if isnan(id), return; end
    % The figures come from the step compare (the analysis's command is that
    % of its first step, the design).
    cfg.layout.command = strrep(cfg.layout.command, '{''export_design''}', '{''compare''}');
    names = reshape(cellstr(string(configuration.parameter_names)), 1, []);
    bounds = double(configuration.prior_bounds);
    density = utils.read_csv_table(sources{3}, {'Protocol', 'ProtocolRole', 'Parameter'});
    parameters = utils.read_csv_table(sources{4}, {'Protocol', 'ProtocolRole', 'Parameter', ...
        'CertifiedSampler', 'CertificationMechanism', 'ExecutionStatus', 'FailureReason'});
    truth = arrayfun(@(p) one(parameters, id, protocols(1), names{p}, 'Truth'), 1:numel(names));
    colors = lines(numel(protocols));
    cells = struct('CaseID', id);
    rule = rule_text(cfg.stage9bConfirmation.showcase);

    fig = figure('Visible', 'off', 'Position', [40 40 1200 360]);
    layout = tiledlayout(fig, 1, numel(names), 'Padding', 'compact', 'TileSpacing', 'compact');
    handles = gobjects(1, numel(protocols));
    for p = 1:numel(names)
        ax = nexttile(layout); hold(ax, 'on');
        for k = 1:numel(protocols)
            handles(k) = marginal(ax, density, id, protocols(k), names{p}, colors(k, :));
        end
        xline(ax, truth(p), 'k--', 'LineWidth', 1.2);
        xlim(ax, bounds(p, :));
        xlabel(ax, plotting.display_name('parameter', names{p}, true), 'Interpreter', 'tex');
        ylabel(ax, 'posterior density'); grid(ax, 'on');
    end
    lg = legend(ax, handles, legend_labels(protocols), 'Orientation', 'horizontal');
    lg.Layout.Tile = 'south';
    title(layout, {sprintf('Material %d: marginal posteriors under the four protocols; dashed: truth', ...
        id), sprintf('(design %s; showcase: %s)', design, rule)}, 'Interpreter', 'none');
    manifest = [manifest; plotting.export_saved_figure(fig, cfg, 'figures', 'showcase_marginals', ...
        sources, 'publication', cells)];

    draws = cell(1, numel(protocols));
    drawSources = cell(1, numel(protocols));
    for k = 1:numel(protocols)
        [draws{k}, drawSources{k}] = provider_draws(root, design, id, protocols(k));
    end
    m = numel(names);
    fig = figure('Visible', 'off', 'Position', [20 20 1050 950]);
    layout = tiledlayout(fig, m, m, 'Padding', 'compact', 'TileSpacing', 'compact');
    for r = 1:m
        for c = 1:m
            ax = nexttile(layout); hold(ax, 'on');
            if c > r
                axis(ax, 'off');
                continue;
            end
            if r == c
                for k = 1:numel(protocols)
                    marginal(ax, density, id, protocols(k), names{c}, colors(k, :));
                end
                xline(ax, truth(c), 'k--', 'LineWidth', 1.0);
                xlim(ax, bounds(c, :));
            else
                for k = 1:numel(protocols)
                    regions(ax, draws{k}(:, c), draws{k}(:, r), bounds(c, :), bounds(r, :), ...
                        colors(k, :));
                end
                plot(ax, truth(c), truth(r), 'kx', 'MarkerSize', 9, 'LineWidth', 1.8);
                xlim(ax, bounds(c, :)); ylim(ax, bounds(r, :));
            end
            if r == m
                xlabel(ax, plotting.display_name('parameter', names{c}, true), 'Interpreter', 'tex');
            end
            if c == 1 && r > 1
                ylabel(ax, plotting.display_name('parameter', names{r}, true), 'Interpreter', 'tex');
            end
            grid(ax, 'on');
        end
    end
    lines_ = gobjects(1, numel(protocols));
    ax = nexttile(layout, m);
    for k = 1:numel(protocols)
        lines_(k) = plot(ax, NaN, NaN, '-', 'Color', colors(k, :), 'LineWidth', 1.6);
    end
    legend(ax, lines_, legend_labels(protocols), 'Location', 'northeast');
    title(layout, {sprintf(['Material %d: the regions holding 50 %% and 90 %% of every retained ' ...
        'draw of the provider under each protocol; x: truth'], id), ...
        sprintf('(design %s; showcase: %s)', design, rule)}, 'Interpreter', 'none');
    manifest = [manifest; plotting.export_saved_figure(fig, cfg, 'figures', 'showcase_corner', ...
        [sources drawSources], 'publication', cells)];
end

function h = marginal(ax, density, id, protocol, name, color)
%MARGINAL The saved marginal density of one cell and parameter.
    rows = density(density.MaterialCaseID == id & density.Protocol == protocol & ...
        density.Parameter == string(name), :);
    assert(~isempty(rows), 'plotting:saved_confirmation_showcase_figures:Density', ...
        'The saved densities lack material %d, protocol %s, parameter %s.', id, protocol, name);
    h = plot(ax, double(rows.GridValue), double(rows.Density), '-', 'Color', color, 'LineWidth', 1.6);
end

function regions(ax, x, y, xBounds, yBounds, color)
%REGIONS The contours that enclose 50 % and 90 % of the draws (x, y), from a smoothed 60 x 60 histogram.
    edgesX = linspace(xBounds(1), xBounds(2), 61);
    edgesY = linspace(yBounds(1), yBounds(2), 61);
    counts = histcounts2(x, y, edgesX, edgesY);
    kernel = [1 2 1; 2 4 2; 1 2 1] / 16;
    smooth = conv2(counts, kernel, 'same');
    smooth = smooth / sum(smooth(:));
    sorted = sort(smooth(:), 'descend');
    mass = cumsum(sorted);
    levels = [sorted(find(mass >= 0.90, 1)), sorted(find(mass >= 0.50, 1))];
    levels = unique(levels(levels > 0));
    if isempty(levels), return; end
    centersX = (edgesX(1:end-1) + edgesX(2:end)) / 2;
    centersY = (edgesY(1:end-1) + edgesY(2:end)) / 2;
    if isscalar(levels), levels = [levels levels]; end
    contour(ax, centersX, centersY, smooth.', levels, 'LineColor', color, 'LineWidth', 1.2);
end

function [X, source] = provider_draws(root, design, id, protocol)
%PROVIDER_DRAWS Every retained draw of the provider replicate of one cell (data/draws).
    source = fullfile(root, 'draws', char(protocol), design, sprintf('case_%d.mat', id));
    assert(isfile(source), 'plotting:saved_confirmation_showcase_figures:Draws', ...
        'The draws of material %d, protocol %s, are missing: %s.', id, protocol, source);
    saved = load(source, 'draws');
    replicates = saved.draws.replicates;
    k = find([replicates.replicateID] == double(saved.draws.providerReplicateID), 1);
    assert(isscalar(k), 'plotting:saved_confirmation_showcase_figures:Provider', ...
        'The draw file %s lacks its provider replicate.', source);
    X = double(replicates(k).drawsPhysical);
end

function v = one(parameters, id, protocol, name, column)
    hit = parameters.MaterialCaseID == id & parameters.Protocol == protocol & ...
        parameters.Parameter == string(name);
    assert(nnz(hit) == 1, 'plotting:saved_confirmation_showcase_figures:Parameter', ...
        'The posterior parameter summary must hold one row of material %d, %s, %s.', id, ...
        protocol, name);
    v = double(parameters.(column)(hit));
end

function labels = legend_labels(protocols)
%LEGEND_LABELS The protocols as legend entries ('default' is a reserved word of MATLAB text: escaped).
    labels = cellstr(strrep(protocols, '_', ' '));
    reserved = ismember(labels, {'default', 'remove', 'factory'});
    labels(reserved) = strcat('\', labels(reserved));
end

function text = rule_text(rule)
    if isnumeric(rule)
        text = 'showcase material of the settings';
    else
        text = 'the first material of the design with four certified cells';
    end
end
