function manifest = saved_confirmation_pair_figures(cfg, ~)
%SAVED_CONFIRMATION_PAIR_FIGURES The marginal posteriors of each focused-versus-default pair of the confirmation.
%   MANIFEST = plotting.saved_confirmation_pair_figures(CFG, OPTIONS) draws,
%   from the saved results of generalized/06_confirmation/data, for every
%   comparison whose two cells have a posterior (certified or healthy
%   fallback), the marginal posterior density of each material parameter
%   under the focused protocol and under the default in one panel (the
%   campaign's saved densities of the providers' draws), over the prior
%   range, with the truth:
%     per case (cases/case_<MaterialCaseID>/confirmation), one figure per
%       pair and observation design, <design>_<protocol>_vs_default_marginals:
%       every pair of the confirmation's design (settings B.7 design) and,
%       with a descriptive design of the complete pairs (B.7
%       completePairsDesign), every complete pair;
%     complete_pairs_marginals (the analysis folder): the complete pairs
%       together, one row per pair, titled with what they are ("<n> pairs
%       with all six pressures; descriptive, not representative of the
%       protocols").
%   Nothing is drawn before the step compare has run. MANIFEST: the rows of
%   the figures written.
%   Side effects: writes the figures (study.export_figure) and closes them.
%   Computation: seconds per figure.

    manifest = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', 'SourceArtifacts'});
    root = study.source_folder(cfg, 'confirmation');
    campaign = fullfile(root, 'campaign');
    configurationFile = fullfile(campaign, 'configuration', 'confirmation_configuration.json');
    statusFile = fullfile(root, 'cell_status.csv');
    comparisonsFile = fullfile(campaign, 'cell_grid', 'pairwise_comparisons.csv');
    if ~isfile(fullfile(campaign, 'status', 'confirmation_status.json')) || ...
            ~all(cellfun(@isfile, {configurationFile, statusFile, comparisonsFile}))
        return;
    end
    % The figures come from the step compare (the analysis's command is that
    % of its first step, the design).
    cfg.layout.command = strrep(cfg.layout.command, '{''export_design''}', '{''compare''}');
    configuration = jsondecode(fileread(configurationFile));
    status = utils.read_csv_table(statusFile, {'Protocol', 'ProtocolRole', 'Design', 'Status', ...
        'ProviderSampler', 'Reason'});
    comparisons = utils.read_csv_table(comparisonsFile, {'Protocol', 'ObjectiveID', ...
        'ComparisonRole', 'Design', 'DesignRole'});
    names = reshape(cellstr(string(configuration.parameter_names)), 1, []);
    bounds = double(configuration.prior_bounds);
    designs = {char(string(configuration.design)), 'summaries', 'primary'};
    if isfield(configuration, 'complete_pairs_design') && ~isempty(configuration.complete_pairs_design)
        designs(2, :) = {char(string(configuration.complete_pairs_design)), ...
            fullfile('summaries', 'complete_pairs'), 'complete_pairs'};
    end
    for d = 1:size(designs, 1)
        [design, folder, role] = designs{d, :};
        sources = {statusFile, comparisonsFile, fullfile(campaign, folder, 'posterior_marginal_density.csv'), ...
            fullfile(campaign, folder, 'posterior_parameter_summary.csv')};
        if ~all(cellfun(@isfile, sources)), continue; end
        density = utils.read_csv_table(sources{3}, {'Protocol', 'ProtocolRole', 'Parameter'});
        parameters = utils.read_csv_table(sources{4}, {'Protocol', 'ProtocolRole', 'Parameter', ...
            'CertifiedSampler', 'CertificationMechanism', 'ExecutionStatus', 'FailureReason'});
        S = status(status.Design == design, :);
        C = comparisons(comparisons.Design == design, :);
        defaultProtocol = S.Protocol(find(S.ProtocolRole == "default", 1));
        matched = false(height(C), 1);
        for i = 1:height(C)
            matched(i) = has_posterior(S, C.MaterialCaseID(i), defaultProtocol) && ...
                has_posterior(S, C.MaterialCaseID(i), C.Protocol(i));
        end
        C = C(matched, :);
        note = '';
        if strcmp(role, 'complete_pairs')
            note = sprintf(['%d pairs with all %s pressures; descriptive, not representative of ' ...
                'the protocols'], height(comparisons(comparisons.Design == design, :)), words(design));
        end
        for i = 1:height(C)
            id = C.MaterialCaseID(i);
            fig = figure('Visible', 'off', 'Position', [40 40 1200 360]);
            layout = tiledlayout(fig, 1, numel(names), 'Padding', 'compact', 'TileSpacing', 'compact');
            handles = pair_panels(layout, density, parameters, id, C.Protocol(i), defaultProtocol, ...
                names, bounds);
            lg = legend(handles(end, :), legend_labels([C.Protocol(i) defaultProtocol]), ...
                'Orientation', 'horizontal');
            lg.Layout.Tile = 'south';
            heading = {sprintf('Material %d: %s against %s, marginal posteriors; dashed: truth', id, ...
                strrep(C.Protocol(i), '_', ' '), defaultProtocol), sprintf('(design %s)', design)};
            if ~isempty(note), heading{2} = sprintf('(design %s; %s)', design, note); end
            title(layout, heading, 'Interpreter', 'none');
            cells = struct('CaseID', id, 'Design', string(design), ...
                'Condition', [C.Protocol(i) defaultProtocol]);
            manifest = [manifest; plotting.export_saved_figure(fig, cfg, 'case/confirmation', ...
                sprintf('%s_%s_vs_default_marginals', design, C.Protocol(i)), sources, ...
                'supplement', cells)]; %#ok<AGROW>
        end
        if strcmp(role, 'complete_pairs') && height(C) > 0
            fig = figure('Visible', 'off', 'Position', [40 40 1200 max(260, 210 * height(C))]);
            layout = tiledlayout(fig, height(C), numel(names), 'Padding', 'compact', ...
                'TileSpacing', 'compact');
            for i = 1:height(C)
                handles = pair_panels(layout, density, parameters, C.MaterialCaseID(i), C.Protocol(i), ...
                    defaultProtocol, names, bounds);
                % The empty second line lifts the heading above the axis exponent (x10^-3).
                title(nexttile(layout, (i - 1) * numel(names) + 1), {sprintf('material %d, %s', ...
                    C.MaterialCaseID(i), strrep(C.Protocol(i), '_', ' ')), ''});
            end
            lg = legend(handles(end, :), {'focused protocol', '\default'}, 'Orientation', 'horizontal');
            lg.Layout.Tile = 'south';
            title(layout, {sprintf(['The complete pairs (design %s): marginal posteriors under the ' ...
                'focused protocol and the default; dashed: truth'], design), sprintf('(%s)', note)}, ...
                'Interpreter', 'none');
            cells = struct('Design', string(design));
            manifest = [manifest; plotting.export_saved_figure(fig, cfg, 'figures', ...
                'complete_pairs_marginals', sources, 'supplement', cells)]; %#ok<AGROW>
        end
    end
end

function handles = pair_panels(layout, density, parameters, id, protocol, defaultProtocol, names, bounds)
%PAIR_PANELS One panel per parameter: the marginals of the focused protocol and the default, and the truth.
    colors = lines(2);
    handles = gobjects(numel(names), 2);
    for p = 1:numel(names)
        ax = nexttile(layout); hold(ax, 'on');
        handles(p, 1) = marginal(ax, density, id, protocol, names{p}, colors(1, :));
        handles(p, 2) = marginal(ax, density, id, defaultProtocol, names{p}, colors(2, :));
        xline(ax, truth(parameters, id, protocol, names{p}), 'k--', 'LineWidth', 1.2);
        xlim(ax, bounds(p, :));
        xlabel(ax, plotting.display_name('parameter', names{p}, true), 'Interpreter', 'tex');
        ylabel(ax, 'posterior density'); grid(ax, 'on');
    end
end

function h = marginal(ax, density, id, protocol, name, color)
%MARGINAL The saved marginal density of one cell and parameter.
    rows = density(density.MaterialCaseID == id & density.Protocol == protocol & ...
        density.Parameter == string(name), :);
    assert(~isempty(rows), 'plotting:saved_confirmation_pair_figures:Density', ...
        'The saved densities lack material %d, protocol %s, parameter %s.', id, protocol, name);
    h = plot(ax, double(rows.GridValue), double(rows.Density), '-', 'Color', color, 'LineWidth', 1.6);
end

function v = truth(parameters, id, protocol, name)
%TRUTH The material's true value of one parameter (the posterior parameter summary).
    hit = parameters.MaterialCaseID == id & parameters.Protocol == protocol & ...
        parameters.Parameter == string(name);
    assert(nnz(hit) == 1, 'plotting:saved_confirmation_pair_figures:Parameter', ...
        'The posterior parameter summary must hold one row of material %d, %s, %s.', id, ...
        protocol, name);
    v = double(parameters.Truth(hit));
end

function tf = has_posterior(status, id, protocol)
    tf = any(status.MaterialCaseID == id & status.Protocol == protocol & ...
        status.Status ~= "unavailable");
end

function labels = legend_labels(protocols)
%LEGEND_LABELS The protocols as legend entries ('default' is a reserved word of MATLAB text: escaped).
    labels = cellstr(strrep(protocols, '_', ' '));
    reserved = ismember(labels, {'default', 'remove', 'factory'});
    labels(reserved) = strcat('\', labels(reserved));
end

function text = words(design)
%WORDS The pressures of a design in words ("six", "D2").
    switch design
        case 'all_six', text = 'six';
        case 'd2_only', text = 'D2';
        otherwise, text = design;
    end
end
