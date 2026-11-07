function manifest = saved_second_mode_figures(cfg, ~)
%SAVED_SECOND_MODE_FIGURES The second-mode check of one cell: its figure and table in the cell's case folder.
%   MANIFEST = plotting.saved_second_mode_figures(CFG) draws, from the saved
%   results of recovery.second_mode_check (study.source_folder
%   'second_mode_check'), into cases/case_<CaseID>/recovery/:
%     <scenario>_<design>_second_mode.png        the negative log-likelihood
%       along the straight line from the truth to the second walker group's
%       point B (left) and the six residuals, GP mean minus the cell's
%       observation, at B, at the end of the refinement from B and at the
%       truth (right)
%     <scenario>_<design>_second_mode_check.csv  every number of the check
%       and its class, one quantity per row
%   Nothing is drawn when the saved results are absent (the analysis
%   second_mode_check was not run) or outside the publication layout.
%   Side effects: writes the figure and the table.

    manifest = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', 'SourceArtifacts'});
    if ~study.is_publication(cfg), return; end
    folder = study.source_folder(cfg, 'second_mode_check');
    recordPath = fullfile(folder, 'second_mode_check.json');
    if ~isfile(recordPath), return; end
    record = jsondecode(fileread(recordPath));
    if strcmp(record.class, 'NOT AVAILABLE'), return; end
    files = fullfile(folder, cellstr(record.files));
    % The text columns of each saved table (the others are numbers).
    textColumns = struct('walkers', {{}}, 'walker_groups', {{'Replicate', 'LogLikelihoodSource'}}, ...
        'points', {{'Point'}}, 'path', {{}}, 'realistic_noise', {{'Point', 'NoiseModel'}}, ...
        'draw_shares', {{'Scenario', 'Design', 'State'}}, ...
        'directions', {{'Scenario', 'Design', 'DirectionLabel', 'Source'}}, 'comsol_neighbours', {{'Split'}});
    T = struct();
    for k = 1:numel(record.files)
        [~, name] = fileparts(record.files{k});
        T.(name) = utils.read_csv_table(files{k}, textColumns.(name));
    end
    sources = [{recordPath}; files(:)];
    C = record.cell;
    cells = struct('CaseID', C.caseID, 'Scenario', C.scenario, 'Design', C.design);
    stem = sprintf('%s_%s', C.scenario, C.design);
    study.export_table(cfg, 'case/recovery', [stem '_second_mode_check'], summary(record, T), sources, ...
        sprintf(['Second-mode check of case %d %s %s: the walker groups, the fit at B and at the truth, ' ...
        'the refinements, the path, the realistic noise, the directions, the closest COMSOL cases and the ' ...
        'class'], C.caseID, strrep(C.scenario, '_', ' '), strrep(C.design, '_', ' ')), cells);
    if ~isfield(T, 'path'), return; end
    manifest = figure_row(cfg, record, T, sources, stem, cells);
end

function row = figure_row(cfg, record, T, sources, stem, cells)
    C = record.cell;
    fig = figure('Position', [100 100 1180 470]);
    layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    % Left: the path from the truth (0) to B (1).
    ax = nexttile(layout);
    nll = T.path.NegativeLogLikelihood;
    rise = nll - nll(1);
    semilogy(ax, T.path.Position, 1 + max(rise, 0), '-', 'Color', [0.14 0.48 0.63], 'LineWidth', 1.6);
    grid(ax, 'on');
    xlabel(ax, 'position on the line from the truth (0) to B (1)');
    ylabel(ax, '1 + (negative log-likelihood - its value at the truth)');
    title(ax, sprintf('the path: highest point %.3g above the higher end', record.numbers.pathBarrierAboveEnds));
    % Right: the residuals at B, at the end of the refinement from B and at the truth.
    ax = nexttile(layout);
    names = T.points.Properties.VariableNames(startsWith(T.points.Properties.VariableNames, 'Residual_'));
    labels = cellfun(@(n) plotting.display_name('output', erase(n, 'Residual_')), names, 'UniformOutput', false);
    shown = ["B", "refined_from_B", "truth"];
    values = zeros(numel(names), numel(shown));
    for k = 1:numel(shown)
        values(:, k) = T.points{T.points.Point == shown(k), names}.';
    end
    bars = bar(ax, values, 'grouped');
    colours = [0.74 0.26 0.18; 0.93 0.61 0.25; 0.14 0.48 0.63];
    for k = 1:numel(bars), bars(k).FaceColor = colours(k, :); end
    ax.XTick = 1:numel(names); ax.XTickLabel = labels; ax.TickLabelInterpreter = 'tex';
    grid(ax, 'on');
    ylabel(ax, 'GP mean - observation [mbar]');
    truthLabel = 'truth';
    if all(abs(values(:, 3)) < 1e-6)
        % gp_self_det: the observation is the GP mean at the truth.
        truthLabel = 'truth (zero: observation = GP mean)';
    end
    legend(ax, {'B', 'end of the refinement from B', truthLabel}, 'Location', 'southoutside', ...
        'Orientation', 'horizontal');
    title(ax, 'the six residuals');
    status = plotting.cell_status_label(cfg, C.caseID, C.scenario, C.design);
    if ~isempty(status), status = [' (' status ')']; end
    title(layout, sprintf('case %d %s %s%s: the second walker group B, %s', C.caseID, ...
        strrep(C.scenario, '_', ' '), strrep(C.design, '_', ' '), status, lower(record.class)));
    row = plotting.export_saved_figure(fig, cfg, 'case/recovery', [stem '_second_mode'], sources, ...
        'publication', cells);
end

function S = summary(record, T)
%SUMMARY Every number of the check, one quantity per row: Part, Quantity, Value, Unit.
    S = table('Size', [0 4], 'VariableTypes', {'string', 'string', 'string', 'string'}, ...
        'VariableNames', {'Part', 'Quantity', 'Value', 'Unit'});
    S = add(S, 'class', 'class (the rule of settings A.7, fixed in advance)', record.class, '');
    C = record.cell;
    S = add(S, 'cell', 'state of the cell', sprintf('%s, %d steps', C.state, C.stepCount), '');
    if isfield(T, 'walker_groups')
        G = T.walker_groups;
        for k = 1:height(G)
            S = add(S, 'a) walker groups', sprintf('group %d, replicate %s: walkers', G.Group(k), G.Replicate(k)), ...
                sprintf('%d', G.WalkerCount(k)), '');
            S = add(S, 'a) walker groups', sprintf('group %d, replicate %s: distance of its median point from the truth', ...
                G.Group(k), G.Replicate(k)), sprintf('%.4g', G.DistanceFromTruth(k)), 'prior widths');
            S = add(S, 'a) walker groups', sprintf('group %d, replicate %s: log-likelihood median and maximum', ...
                G.Group(k), G.Replicate(k)), sprintf('%.6g, %.6g', G.LogLikelihoodMedian(k), ...
                G.LogLikelihoodMax(k)), '');
        end
    end
    if ~isfield(T, 'points'), return; end
    n = record.numbers;
    S = add(S, 'a) walker groups', 'B (the median point of group 2)', sprintf('%.6g, ', n.B), 'model coordinates');
    S = add(S, 'a) walker groups', 'the truth', sprintf('%.6g, ', n.truth), 'model coordinates');
    S = add(S, 'b) fit', 'distance of B from the truth', sprintf('%.4g', n.bDistanceFromTruth), 'prior widths');
    S = add(S, 'b) fit', 'log-likelihood at the truth', sprintf('%.6g', n.logLikelihoodTruth), '');
    S = add(S, 'b) fit', 'log-likelihood at B', sprintf('%.6g', n.logLikelihoodB), '');
    S = add(S, 'b) fit', 'log-likelihood at B minus at the truth', ...
        sprintf('%.6g', n.logLikelihoodB - n.logLikelihoodTruth), '');
    P = T.points;
    names = P.Properties.VariableNames(startsWith(P.Properties.VariableNames, 'Residual_'));
    for point = ["truth", "B", "refined_from_B", "refined_from_truth"]
        S = add(S, 'b) fit', sprintf('residuals at %s (%s)', strrep(point, '_', ' '), ...
            strjoin(erase(names, 'Residual_'), ', ')), sprintf('%.4g, ', P{P.Point == point, names}), 'mbar');
    end
    S = add(S, 'c) refinement', 'from B: distance of the end point from the truth', ...
        sprintf('%.4g', n.refinedFromBDistanceFromTruth), 'prior widths');
    S = add(S, 'c) refinement', 'from B: distance of the end point from B', ...
        sprintf('%.4g', n.refinedFromBDistanceFromB), 'prior widths');
    S = add(S, 'c) refinement', 'from B: log-likelihood at the end point', ...
        sprintf('%.6g', n.logLikelihoodRefinedFromB), '');
    S = add(S, 'c) refinement', 'from the truth (control): distance of the end point from the truth', ...
        sprintf('%.4g', n.refinedFromTruthDistanceFromTruth), 'prior widths');
    for point = ["refined_from_B", "refined_from_truth"]
        r = P(P.Point == point, :);
        S = add(S, 'c) refinement', sprintf('%s: exit flag, iterations, evaluations', strrep(point, '_', ' ')), ...
            sprintf('%d, %d, %d', r.ExitFlag, r.Iterations, r.FunctionEvaluations), '');
    end
    S = add(S, 'd) path', 'highest negative log-likelihood on the line above the higher end', ...
        sprintf('%.6g', n.pathBarrierAboveEnds), '');
    N = T.realistic_noise;
    for k = 1:height(N)
        S = add(S, 'e) realistic noise', sprintf('delta at %s, %s noise', strrep(N.Point(k), '_', ' '), ...
            strrep(N.NoiseModel(k), '_', ' ')), sprintf('%.6g', N.Delta(k)), '');
    end
    D = T.draw_shares;
    for k = 1:height(D)
        S = add(S, 'e) realistic noise', sprintf('%s %s replicate %g: share of the draws near B / near the truth', ...
            strrep(D.Scenario(k), '_', ' '), strrep(D.Design(k), '_', ' '), D.Replicate(k)), ...
            sprintf('%.4g / %.4g (of %g draws, within %g)', D.ShareNearB(k), D.ShareNearTruth(k), ...
            D.DrawCount(k), D.Neighbourhood(k)), 'prior widths');
    end
    E = T.directions;
    for k = 1:height(E)
        S = add(S, 'f) direction', sprintf('angle between truth -> B and the %s (%s %s, %s)', ...
            strrep(E.DirectionLabel(k), '_', ' '), strrep(E.Scenario(k), '_', ' '), ...
            strrep(E.Design(k), '_', ' '), E.Source(k)), sprintf('%.4g', E.AngleDegrees(k)), 'degrees');
    end
    K = T.comsol_neighbours;
    for k = 1:height(K)
        S = add(S, 'g) COMSOL cases', sprintf('rank %d: case %d (%s), pressure distance / parameter distance', ...
            K.Rank(k), K.CaseID(k), K.Split(k)), sprintf('%.4g / %.4g (%d outputs)', K.PressureDistance(k), ...
            K.ParameterDistance(k), K.OutputsCompared(k)), 'measurement CVs / prior widths');
    end
end

function S = add(S, part, quantity, value, unit)
    value = string(value);
    value = regexprep(value, ',\s*$', '');
    S(end+1, :) = {string(part), string(quantity), value, string(unit)};
end
