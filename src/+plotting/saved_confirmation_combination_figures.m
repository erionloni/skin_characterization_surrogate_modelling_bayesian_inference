function manifest = saved_confirmation_combination_figures(cfg, ~)
%SAVED_CONFIRMATION_COMBINATION_FIGURES The weak-pair combinations of the confirmation, and what a focused protocol changes.
%   MANIFEST = plotting.saved_confirmation_combination_figures(CFG, OPTIONS)
%   draws, from the saved results of confirmation.parameter_combinations
%   (study.source_folder 'combinations' of the generalized route), into the
%   confirmation analysis (file names starting with combinations_):
%     tables   _cells (per material, protocol, design and replicate: the
%              best-determined combinations with their SD ratios, the label
%              and the log form), _marginals (per cell, replicate and best
%              combination: its marginal against its prior, and the truth),
%              _summary (per design, protocol, replicate and best
%              combination: the consensus, the spread of the directions,
%              medians and counts; the certified cells alone in the columns
%              ending in _certified_only), _protocols (per design, material,
%              focused protocol and replicate: the rotation and the ratio of
%              the SD ratios of the best weak-pair combination against the
%              default protocol's, with the replicate differences of both
%              cells), _protocol_summary (per design, focused protocol and
%              replicate: medians, quartiles and counts on the matched
%              materials; the pairs of certified cells alone in the columns
%              ending in _certified_only)
%     figures  per observation design: _<design>_weak_pair_sd_ratios (per
%              protocol and material the SD ratio of the best weak-pair
%              combination next to the SD ratios of its two parameters, both
%              replicates, the log form where it applies, and half the
%              smaller SD ratio, below which a combination is labelled
%              identified); _<design>_weak_pair_directions (per protocol the
%              direction of the best weak-pair combination of each material,
%              as its angle in the plane of the pair, with the protocol's
%              consensus and the default's); _<design>_protocol_effect (per
%              focused protocol and matched material the rotation of the best
%              combination from the default's, next to the larger of the two
%              cells' replicate angles, and the ratio of its SD ratio to the
%              default's)
%   and per material and design, in its case folder
%   (cases/case_<id>/combinations/figures/):
%     <design>_combination_marginals  per protocol the marginal of the best
%              weak-pair combination, replicate 1 with its mean, median, mode
%              and central intervals, replicate 2 dashed, with its prior and
%              the truth
%     <design>_weak_pair_scatter      per protocol every draw of the weak
%              pair of replicate 1, with its best (solid) and worst (dashed)
%              direction through the mean over +/- 2 SD, replicate 2's best
%              direction in grey, and the truth
%   The scatter reads the confirmation's draws (study.source_folder
%   'confirmation'; the shipped ones for a run whose combinations used
%   them). OPTIONS is unused.
%   Side effects: writes the tables and figures and closes the figures.
%   Computation: seconds per material (the scatter reads the cells' draws).

    manifest = empty_manifest();
    if ~study.is_publication(cfg), return; end
    folder = study.source_folder(cfg, 'combinations');
    names = {'cohort', 'cells', 'marginals', 'densities', 'consensus', 'protocols', 'protocol_summary'};
    paths = struct();
    for k = 1:numel(names), paths.(names{k}) = fullfile(folder, [names{k} '.csv']); end
    if ~isfile(paths.cells), return; end
    text = {'Protocol', 'ProtocolRole', 'Design', 'Status', 'ProviderSampler', 'Note', 'LogFormReason', ...
        'Combination', 'Formula', 'Curve', 'DefaultStatus', 'ProtocolStatus'};
    read = @(p) read_table(p, text);
    cohort = read(paths.cohort); cells = read(paths.cells); marginals = read(paths.marginals);
    densities = read(paths.densities); consensus = read(paths.consensus);
    protocols = read(paths.protocols); summary = read(paths.protocol_summary);
    pair = weak_pair(cells);
    materials = case_order(cfg, cells);
    designs = reshape(unique(cells.Design, 'stable'), 1, []);
    order = protocol_order(cells);
    reference = unique(cells.Protocol(cells.ProtocolRole == "default"));
    scope = struct('CaseID', materials, 'Design', designs, 'Condition', order);
    study.export_table(cfg, 'combinations', 'cells', cells, {paths.cells, paths.cohort}, ...
        ['Per material, protocol, design and replicate: the best-determined combinations with their ' ...
         'SD ratios, the label and the log form'], scope);
    study.export_table(cfg, 'combinations', 'marginals', marginals, {paths.marginals}, ...
        'Per cell, replicate and best combination: its marginal against its prior, and the truth', scope);
    study.export_table(cfg, 'combinations', 'summary', consensus, {paths.consensus}, ...
        ['Per design, protocol, replicate and best combination: the consensus, the spread of the ' ...
         'directions, medians and counts (the certified cells alone in the columns ending in ' ...
         '_certified_only)'], scope);
    if ~isempty(protocols)
        study.export_table(cfg, 'combinations', 'protocols', protocols, {paths.protocols}, ...
            ['Per design, material, focused protocol and replicate: the rotation and the ratio of the ' ...
             'SD ratios of the best weak-pair combination against the default protocol''s, with the ' ...
             'replicate differences of both cells'], scope);
        study.export_table(cfg, 'combinations', 'protocol_summary', summary, {paths.protocol_summary}, ...
            ['Per design, focused protocol and replicate: the matched materials, the median and ' ...
             'quartiles of the rotation and of the ratio of the SD ratios, the materials determined ' ...
             'more sharply (the pairs of certified cells alone in the columns ending in ' ...
             '_certified_only)'], scope);
    end
    factor = cfg.analysis.confirmationCombinations.labelFactor;
    parts = {};
    for design = designs
        D = cells(cells.Design == design, :);
        protocolsHere = order(ismember(order, D.Protocol));
        designScope = struct('CaseID', materials, 'Design', design, 'Condition', protocolsHere);
        parts{end+1} = sd_ratio_figure(cfg, D, pair, materials, protocolsHere, factor, design, ...
            {paths.cells}, designScope); %#ok<AGROW>
        parts{end+1} = direction_figure(cfg, D, consensus(consensus.Design == design, :), pair, materials, ...
            protocolsHere, reference, design, {paths.cells, paths.consensus}, designScope); %#ok<AGROW>
        P = protocols;
        if ~isempty(P), P = P(P.Design == design, :); end
        if ~isempty(P)
            S = summary(summary.Design == design, :);
            parts{end+1} = effect_figure(cfg, P, S, materials, protocolsHere(protocolsHere ~= reference), ...
                reference, design, {paths.protocols, paths.protocol_summary}, designScope); %#ok<AGROW>
        end
    end
    drawsRoot = draws_root(cfg);
    for design = designs
        for id = reshape(materials, 1, [])
            C = cells(cells.Design == design & cells.CaseID == id, :);
            if isempty(C), continue; end
            shown = order(ismember(order, C.Protocol));
            mine = @(T) T(T.Design == design & T.CaseID == id, :);
            files = arrayfun(@(p) fullfile(drawsRoot, char(p), char(design), sprintf('case_%d.mat', id)), ...
                shown, 'UniformOutput', false);
            sources = [{paths.cells, paths.marginals, paths.densities}, files];
            caseScope = struct('CaseID', id, 'Design', design, 'Condition', shown);
            label = sprintf('Material %d, design %s', id, design);
            parts{end+1} = marginal_figure(cfg, C, mine(marginals), mine(densities), shown, pair, label, ...
                [char(design) '_combination_marginals'], sources, caseScope); %#ok<AGROW>
            parts{end+1} = scatter_figure(cfg, C, files, shown, mine(cohort), pair, label, ...
                [char(design) '_weak_pair_scatter'], sources, caseScope); %#ok<AGROW>
        end
    end
    manifest = vertcat(manifest, parts{:});
end

function T = read_table(path, text)
%READ_TABLE A saved table with its text columns as text; a missing or empty file (nothing to compare) is an empty table.
    T = table();
    if ~isfile(path), return; end
    fid = fopen(path, 'r');
    line = fgetl(fid);
    fclose(fid);
    if ~ischar(line) || isempty(strtrim(line)), return; end
    columns = strsplit(strtrim(line), ',');
    T = utils.read_csv_table(path, text(ismember(text, columns)));
end

function pair = weak_pair(cells)
%WEAK_PAIR The two parameters of the weak pair, from the columns of cells.csv (SDRatio_<parameter>).
    columns = cells.Properties.VariableNames;
    pair = extractAfter(columns(startsWith(columns, 'SDRatio_')), 'SDRatio_');
    assert(numel(pair) == 2, 'plotting:saved_confirmation_combination_figures:Pair', ...
        'The saved combinations name %d weak-pair parameters, not two.', numel(pair));
end

function ids = case_order(cfg, cells)
%CASE_ORDER The materials in the order of the confirmation's materials (B.7), then any others ascending.
    present = unique(double(cells.CaseID));
    ids = present;
    if isfield(cfg, 'stage9bConfirmation') && isfield(cfg.stage9bConfirmation, 'materials')
        listed = reshape(double(cfg.stage9bConfirmation.materials), [], 1);
        ids = [listed(ismember(listed, present)); setdiff(present, listed)];
    end
end

function order = protocol_order(cells)
%PROTOCOL_ORDER The default protocol first, then the focused ones in the order of the saved cells.
    order = unique(cells.Protocol, 'stable');
    first = unique(cells.Protocol(cells.ProtocolRole == "default"));
    order = [first; order(~ismember(order, first))];
    order = reshape(order, 1, []);
end

function root = draws_root(cfg)
%DRAWS_ROOT The confirmation's draws that the combinations analysed.
%   The analysis's own data folder; for a run whose combinations read the
%   shipped draws (study.reproduce sets the canonical results), those.
    root = fullfile(study.source_folder(cfg, 'confirmation'), 'draws');
    if ~isfolder(root) && isfield(cfg.layout, 'canonicalResults') && ~isempty(cfg.layout.canonicalResults)
        root = fullfile(cfg.layout.canonicalResults, 'generalized', '06_confirmation', 'data', 'draws');
    end
end

function text = protocol_name(protocol)
    text = strrep(char(protocol), '_', ' ');
end

function text = tex_name(name, logged)
%TEX_NAME The parameter in a formula: a short symbol (ln ... when the log form took its natural log).
    switch name
        case 'm3_f_RD', text = 'm_{3f}';
        case 'm3_e_RD', text = 'm_{3e}';
        case 'log10_k0_RD', text = 'log_{10}k_0';
        case 'Thickness_RD', text = 't';
        otherwise, text = plotting.display_name('parameter', name);
    end
    if logged, text = ['ln ' text]; end
end

function text = tex_formula(w, labels)
%TEX_FORMULA A combination as text: its weights on z(<parameter>).
    parts = strings(1, numel(w));
    for j = 1:numel(w)
        parts(j) = sprintf('%+.2f z(%s)', w(j), labels{j});
    end
    text = char(strjoin(parts, ' '));
end

function c = face(colour, replicate)
    c = colour;
    if replicate == 2, c = 'none'; end
end

function a = direction_angle(T, prefix, pair)
%DIRECTION_ANGLE The angle of a weak-pair direction in the plane of the pair (degrees; first weight >= 0).
    a = atan2d(T.([prefix pair{2}]), T.([prefix pair{1}]));
end

function row = sd_ratio_figure(cfg, cells, pair, materials, protocols, factor, design, sources, scope)
%SD_RATIO_FIGURE Per protocol and material: the SD ratio of the best weak-pair combination next to each parameter's.
    fig = figure('Visible', 'off', 'Position', [40 40 1250 max(420, 210 * numel(protocols) + 120)]);
    layout = tiledlayout(fig, numel(protocols), 1, 'Padding', 'compact', 'TileSpacing', 'compact');
    band = legend_band(fig, layout);
    colours = struct('first', [0.00 0.45 0.70], 'second', [0.85 0.37 0.01], 'best', [0 0 0], ...
        'log', [0.00 0.60 0.50], 'limit', [0.55 0.55 0.55]);
    shown = gobjects(1, 0);
    for p = 1:numel(protocols)
        ax = nexttile(layout); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
        for r = 1:2
            T = cells(cells.Protocol == protocols(p) & cells.Replicate == r, :);
            if isempty(T), continue; end
            [~, at] = ismember(double(T.CaseID), materials);
            x = at + 0.3 * (r - 1.5);
            limit = factor * min(T.(['SDRatio_' pair{1}]), T.(['SDRatio_' pair{2}]));
            h = [plot(ax, x, limit, '_', 'Color', colours.limit, 'MarkerSize', 12, 'LineWidth', 1.5), ...
                plot(ax, x, T.(['SDRatio_' pair{1}]), 's', 'Color', colours.first, 'MarkerSize', 6, ...
                    'MarkerFaceColor', face(colours.first, r)), ...
                plot(ax, x, T.(['SDRatio_' pair{2}]), '^', 'Color', colours.second, 'MarkerSize', 6, ...
                    'MarkerFaceColor', face(colours.second, r)), ...
                plot(ax, x, T.Best_SDRatio, 'o', 'Color', colours.best, 'MarkerSize', 7, ...
                    'MarkerFaceColor', face(colours.best, r)), ...
                plot(ax, x, T.LogBest_SDRatio, 'd', 'Color', colours.log, 'MarkerSize', 6, ...
                    'MarkerFaceColor', face(colours.log, r))];
            if isempty(shown) && r == 1, shown = h; end
        end
        first = cells(cells.Protocol == protocols(p) & cells.Replicate == 1, :);
        top = max([1.15; 1.05 * first.(['SDRatio_' pair{1}]); 1.05 * first.(['SDRatio_' pair{2}])]);
        xlim(ax, [0.4 numel(materials) + 0.6]); ylim(ax, [0 top]);
        xticks(ax, 1:numel(materials)); xticklabels(ax, string(materials));
        ylabel(ax, 'SD ratio');
        title(ax, sprintf(['%s: the best combination is labelled identified for %d of %d materials, ' ...
            'its log form for %d (replicate 1)'], protocol_name(protocols(p)), nnz(logical(first.Identified)), ...
            height(first), nnz(logical(first.LogIdentified))), 'Interpreter', 'none');
    end
    xlabel(ax, 'material (CaseID)');
    legend_row(band, legend_proxies(band, shown), {sprintf('%g x the smaller SD ratio of the pair', factor), ...
        ['SD ratio of ' plotting.display_name('parameter', pair{1})], ...
        ['SD ratio of ' plotting.display_name('parameter', pair{2})], 'best combination of the pair', ...
        'best combination in log form (log coordinates)'});
    title(layout, {sprintf(['Confirmation, design %s: the best-determined combination of the weak pair ' ...
        'against each of its parameters alone'], design), ...
        ['SD ratio: posterior SD over prior SD (1: the prior width); open: replicate 2; below the grey ' ...
         'mark: "identified combination", a description, not a test']}, 'Interpreter', 'none');
    row = plotting.export_saved_figure(fig, cfg, 'combinations', sprintf('%s_weak_pair_sd_ratios', design), ...
        sources, 'publication', scope);
end

function row = direction_figure(cfg, cells, consensus, pair, materials, protocols, reference, design, ...
        sources, scope)
%DIRECTION_FIGURE Per protocol the direction of the best weak-pair combination of each material, with the consensus.
    fig = figure('Visible', 'off', 'Position', [40 40 1250 max(420, 210 * numel(protocols) + 120)]);
    layout = tiledlayout(fig, numel(protocols), 1, 'Padding', 'compact', 'TileSpacing', 'compact');
    band = legend_band(fig, layout);
    labels = cellfun(@(p) plotting.display_name('parameter', p), pair, 'UniformOutput', false);
    pick = @(p) consensus(consensus.Protocol == p & consensus.Replicate == 1 & ...
        consensus.Combination == "weak_pair_best", :);
    angleOf = @(Q) atan2d(Q.(['ConsensusWeight_' pair{2}]), Q.(['ConsensusWeight_' pair{1}]));
    R = pick(reference);
    blue = [0 0.45 0.70];
    shown = gobjects(1, 0);
    for p = 1:numel(protocols)
        ax = nexttile(layout); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
        Q = pick(protocols(p));
        lines = gobjects(1, 0);
        if ~isempty(Q) && isfinite(angleOf(Q))
            yline(ax, angleOf(Q), 'k-', 'LineWidth', 1.4);
            lines = plot(ax, NaN, NaN, 'k-', 'LineWidth', 1.4);
        end
        if protocols(p) ~= reference && ~isempty(R) && isfinite(angleOf(R))
            yline(ax, angleOf(R), 'Color', [0.5 0.5 0.5], 'LineStyle', ':', 'LineWidth', 1.6);
            lines = [lines plot(ax, NaN, NaN, 'Color', [0.5 0.5 0.5], 'LineStyle', ':', 'LineWidth', 1.6)]; %#ok<AGROW>
        end
        for r = 1:2
            T = cells(cells.Protocol == protocols(p) & cells.Replicate == r, :);
            if isempty(T), continue; end
            [~, at] = ismember(double(T.CaseID), materials);
            h = plot(ax, at + 0.3 * (r - 1.5), direction_angle(T, 'Best_w_', pair), 'o', 'Color', blue, ...
                'MarkerSize', 7, 'MarkerFaceColor', face(blue, r));
            if r == 1 && numel(shown) < 3, shown = [h lines]; end
        end
        xlim(ax, [0.4 numel(materials) + 0.6]); ylim(ax, [-90 90]);
        xticks(ax, 1:numel(materials)); xticklabels(ax, string(materials));
        yticks(ax, -90:45:90);
        yticklabels(ax, {['-90: ' labels{2} ' alone'], ['-45: z(' labels{1} ') - z(' labels{2} ')'], ...
            ['0: ' labels{1} ' alone'], ['45: z(' labels{1} ') + z(' labels{2} ')'], ['90: ' labels{2} ' alone']});
        set(ax, 'TickLabelInterpreter', 'tex');
        ylabel(ax, 'direction [degrees]');
        heading = protocol_name(protocols(p));
        if ~isempty(Q) && Q.Cells > 0
            heading = sprintf('%s: consensus %s; angle of the materials to it: median %.0f, largest %.0f degrees (replicate 1, %d materials)', ...
                heading, tex_formula([Q.(['ConsensusWeight_' pair{1}]) Q.(['ConsensusWeight_' pair{2}])], labels), ...
                Q.MedianAngleToConsensus, Q.MaxAngleToConsensus, Q.Cells);
        end
        title(ax, heading, 'Interpreter', 'tex', 'FontWeight', 'normal');
    end
    xlabel(ax, 'material (CaseID)');
    entries = {'best combination of the pair (open: replicate 2)', 'consensus of the protocol', ...
        sprintf('consensus of the %s protocol', protocol_name(reference))};
    legend_row(band, legend_proxies(band, shown), entries(1:numel(shown)));
    title(layout, {sprintf(['Confirmation, design %s: the direction of the best-determined combination of ' ...
        'the weak pair, per protocol'], design), ['the angle of its weights in the plane of the two ' ...
        'prior-standardized parameters; consensus: the leading eigenvector of the materials'' mean projector']}, ...
        'Interpreter', 'none');
    row = plotting.export_saved_figure(fig, cfg, 'combinations', sprintf('%s_weak_pair_directions', design), ...
        sources, 'publication', scope);
end

function row = effect_figure(cfg, P, S, materials, focused, reference, design, sources, scope)
%EFFECT_FIGURE Per focused protocol and matched material: the rotation of the best combination and the ratio of its SD ratio.
    fig = figure('Visible', 'off', 'Position', [40 40 1250 700]);
    layout = tiledlayout(fig, 2, numel(focused), 'Padding', 'compact', 'TileSpacing', 'compact');
    band = legend_band(fig, layout);
    blue = [0 0.45 0.70]; grey = [0.55 0.55 0.55];
    shown = gobjects(1, 0);
    for p = 1:numel(focused)
        top = nexttile(layout, p); hold(top, 'on'); box(top, 'on'); grid(top, 'on');
        bottom = nexttile(layout, numel(focused) + p); hold(bottom, 'on'); box(bottom, 'on'); grid(bottom, 'on');
        yline(bottom, 1, 'k-', 'LineWidth', 1);
        for r = 1:2
            T = P(P.Protocol == focused(p) & P.Replicate == r, :);
            if isempty(T), continue; end
            [~, at] = ismember(double(T.CaseID), materials);
            x = at + 0.3 * (r - 1.5);
            yardstick = plot(top, x, max(T.DefaultReplicateAngle, T.ProtocolReplicateAngle), '_', 'Color', grey, ...
                'MarkerSize', 12, 'LineWidth', 1.6);
            rotation = plot(top, x, T.Rotation, 'o', 'Color', blue, 'MarkerSize', 7, ...
                'MarkerFaceColor', face(blue, r));
            plot(bottom, x, T.Best_SDRatioRatio, 'o', 'Color', [0 0 0], 'MarkerSize', 7, ...
                'MarkerFaceColor', face([0 0 0], r));
            if isempty(shown) && r == 1, shown = [rotation yardstick]; end
        end
        for ax = [top bottom]
            xlim(ax, [0.4 numel(materials) + 0.6]); xticks(ax, 1:numel(materials));
            xticklabels(ax, string(materials));
        end
        ylim(top, [0 90]); yticks(top, 0:15:90);
        set(bottom, 'YScale', 'log');
        values = P.Best_SDRatioRatio(P.Protocol == focused(p) & isfinite(P.Best_SDRatioRatio) & ...
            P.Best_SDRatioRatio > 0);
        if ~isempty(values)
            span = max(abs(log10(values)));
            span = max(span * 1.15, log10(1.5));
            ylim(bottom, 10 .^ [-span span]);
        end
        one = S(S.Protocol == focused(p) & S.Replicate == 1, :);
        text1 = {protocol_name(focused(p))}; text2 = {''};
        if ~isempty(one)
            text1 = {sprintf('%s against %s, %d matched materials', protocol_name(focused(p)), ...
                protocol_name(reference), one.MatchedMaterials), sprintf(['rotation median %.0f deg, ' ...
                'replicate angle median %.0f deg'], one.MedianRotation, one.MedianReplicateAngle)};
            text2 = {sprintf('SD ratio / default''s: median %.2f', one.MedianBest_SDRatioRatio), ...
                sprintf('sharper for %d of %d materials (replicate 1)', one.SharperCount, one.MatchedMaterials)};
        end
        title(top, text1, 'Interpreter', 'none', 'FontWeight', 'normal', 'FontSize', 9);
        title(bottom, text2, 'Interpreter', 'none', 'FontWeight', 'normal', 'FontSize', 9);
        if p == 1
            ylabel(top, 'rotation [degrees]');
            ylabel(bottom, 'SD ratio / default''s');
        end
        xlabel(bottom, 'material (CaseID)');
    end
    legend_row(band, legend_proxies(band, shown), {'focused protocol against the default (open: replicate 2)', ...
        'the larger replicate angle of the two cells'});
    title(layout, {sprintf(['Confirmation, design %s: does a focused protocol rotate or sharpen the best ' ...
        'combination of the weak pair?'], design), ['top: the angle between its best direction and the ' ...
        'default''s; grey: the larger angle between the two replicates of a cell'], ['bottom: its SD ratio ' ...
        'over the default''s (below 1: determined more sharply); materials with a posterior under both ' ...
        'protocols']}, 'Interpreter', 'none');
    row = plotting.export_saved_figure(fig, cfg, 'combinations', sprintf('%s_protocol_effect', design), ...
        sources, 'publication', scope);
end

function row = marginal_figure(cfg, C, M, D, protocols, pair, label, name, sources, cells)
%MARGINAL_FIGURE Per protocol the marginal of the cell's best weak-pair combination against its prior, both replicates.
    fig = figure('Visible', 'off', 'Position', [40 40 max(700, 330 * numel(protocols)) 470]);
    layout = tiledlayout(fig, 1, numel(protocols), 'Padding', 'compact', 'TileSpacing', 'compact');
    band = legend_band(fig, layout);
    labels = cellfun(@(p) tex_name(p, false), pair, 'UniformOutput', false);
    blue = [0.00 0.45 0.70]; shown = gobjects(1, 0);
    for p = 1:numel(protocols)
        ax = nexttile(layout); hold(ax, 'on'); box(ax, 'on');
        one = M(M.Protocol == protocols(p) & M.Combination == "weak_pair_best", :);
        m1 = one(one.Replicate == 1, :);
        if isempty(m1)
            text(ax, 0.5, 0.5, 'replicate 1 not available', 'Units', 'normalized', ...
                'HorizontalAlignment', 'center');
            axis(ax, 'off');
            continue;
        end
        curve = @(r, kind) D(D.Protocol == protocols(p) & D.Combination == "weak_pair_best" & ...
            D.Replicate == r & D.Curve == kind, :);
        p1 = curve(1, "prior");
        area(ax, p1.X, p1.Density, 'FaceColor', [0.88 0.88 0.88], 'EdgeColor', [0.6 0.6 0.6]);
        prior = plot(ax, NaN, NaN, 's', 'MarkerSize', 10, 'MarkerFaceColor', [0.88 0.88 0.88], ...
            'MarkerEdgeColor', [0.6 0.6 0.6]);
        handles = draw_marginal(ax, curve(1, "posterior"), m1, blue, '-', true);
        m2 = one(one.Replicate == 2, :);
        second = gobjects(1, 0);
        if ~isempty(m2)
            second = draw_marginal(ax, curve(2, "posterior"), m2, [0.30 0.30 0.30], '--', false);
            second = second.density;
        end
        xline(ax, m1.Truth, 'Color', [1 0 0], 'LineStyle', '-', 'LineWidth', 1.8);
        truth = plot(ax, NaN, NaN, 'Color', [1 0 0], 'LineStyle', '-', 'LineWidth', 1.8);
        xlim(ax, [m1.Lower m1.Upper]);
        xlabel(ax, 'combination u = w^T z', 'Interpreter', 'tex');
        if p == 1, ylabel(ax, 'density'); end
        first = C(C.Protocol == protocols(p) & C.Replicate == 1, :);
        status = '';
        if ~isempty(first), status = sprintf(' (%s)', first.Status(1)); end
        ratio2 = '';
        if ~isempty(m2), ratio2 = sprintf(' (replicate 2: %.2f)', m2.SDRatio); end
        weights = [first.(['Best_w_' pair{1}])(1) first.(['Best_w_' pair{2}])(1)];
        title(ax, {[protocol_name(protocols(p)) status], tex_formula(weights, labels), ...
            sprintf('SD ratio %.2f%s; 95%% width %.2f', m1.SDRatio, ratio2, m1.WidthRatio95)}, ...
            'Interpreter', 'tex', 'FontWeight', 'normal', 'FontSize', 9);
        if isempty(shown)
            shown = [prior handles.density handles.interval95 handles.interval50 handles.mean handles.median ...
                handles.mode second truth];
        end
    end
    entries = {'prior', 'posterior, replicate 1', '95% interval', '50% interval', 'mean', 'median', 'mode'};
    if numel(shown) == 9, entries{end+1} = 'posterior, replicate 2'; end
    entries{end+1} = 'truth';
    legend_row(band, legend_proxies(band, shown), entries);
    title(layout, {sprintf('%s: the best-determined combination of the weak pair under each protocol', label), ...
        ['prior-standardized coordinates z (prior SD 1); each protocol''s own best combination; SD ratio and ' ...
         '95% width: the draws against the prior sample']}, 'Interpreter', 'none');
    row = plotting.export_saved_figure(fig, cfg, 'case/combinations', name, sources, 'publication', cells);
end

function handles = draw_marginal(ax, D, M, colour, style, intervals)
%DRAW_MARGINAL A saved marginal as the inversion's marginals draw it: density, mean, median, mode, intervals.
    handles.density = plot(ax, D.X, D.Density, 'Color', colour, 'LineStyle', style, 'LineWidth', 1.7);
    values = [M.Mean M.Median M.Mode];
    markers = {'o', 's', '^'}; fields = {'mean', 'median', 'mode'};
    for i = 1:3
        y = interp1(D.X, D.Density, values(i), 'linear', 'extrap');
        handles.(fields{i}) = plot(ax, values(i), max(y, 0), markers{i}, 'Color', colour, ...
            'MarkerFaceColor', 'white', 'MarkerSize', 6, 'LineWidth', 1.2);
    end
    handles.interval95 = gobjects(0); handles.interval50 = gobjects(0);
    if intervals
        baseline = -0.035 * max(D.Density);
        handles.interval95 = plot(ax, [M.Q025 M.Q975], [baseline baseline], '-', ...
            'Color', 0.70 + 0.30 * colour, 'LineWidth', 2);
        handles.interval50 = plot(ax, [M.Q25 M.Q75], [baseline baseline], '-', 'Color', colour, 'LineWidth', 5);
    end
end

function row = scatter_figure(cfg, C, files, protocols, cohort, pair, label, name, sources, cells)
%SCATTER_FIGURE Per protocol every draw of the weak pair of replicate 1, with the best and worst directions.
    fig = figure('Visible', 'off', 'Position', [40 40 max(700, 330 * numel(protocols)) 470]);
    layout = tiledlayout(fig, 1, numel(protocols), 'Padding', 'compact', 'TileSpacing', 'compact');
    band = legend_band(fig, layout);
    shown = gobjects(1, 0);
    for p = 1:numel(protocols)
        ax = nexttile(layout); hold(ax, 'on'); box(ax, 'on');
        T1 = C(C.Protocol == protocols(p) & C.Replicate == 1, :);
        T2 = C(C.Protocol == protocols(p) & C.Replicate == 2, :);
        if isempty(T1) || ~isfile(files{p})
            text(ax, 0.5, 0.5, 'replicate 1 not available', 'Units', 'normalized', ...
                'HorizontalAlignment', 'center');
            axis(ax, 'off');
            continue;
        end
        saved = load(files{p}, 'draws');
        Dr = saved.draws;
        names = reshape(cellstr(string(Dr.parameterNames)), 1, []);
        [~, weak] = ismember(pair, names);
        bounds = double(Dr.bounds(weak, :));
        priorSD = (bounds(:, 2) - bounds(:, 1)).' / sqrt(12);
        replicates = cell(1, 2);
        for j = 1:numel(Dr.replicates)
            replicates{double(Dr.replicates(j).replicateID)} = double(Dr.replicates(j).drawsPhysical(:, weak));
        end
        X = replicates{1};
        alpha = min(0.15, max(0.02, 0.15 * sqrt(2500 / size(X, 1))));
        draws = scatter(ax, X(:, 1), X(:, 2), 5, 'filled', 'MarkerFaceAlpha', alpha);
        best = segment(ax, mean(X, 1), [T1.(['Best_w_' pair{1}]) T1.(['Best_w_' pair{2}])], T1.Best_SDRatio, ...
            priorSD, '-', [0 0 0]);
        worst = segment(ax, mean(X, 1), [T1.(['Worst_w_' pair{1}]) T1.(['Worst_w_' pair{2}])], ...
            T1.Worst_SDRatio, priorSD, '--', [0 0 0]);
        other = gobjects(1, 0);
        if ~isempty(T2) && ~isempty(replicates{2})
            other = segment(ax, mean(replicates{2}, 1), [T2.(['Best_w_' pair{1}]) T2.(['Best_w_' pair{2}])], ...
                T2.Best_SDRatio, priorSD, '-', [0.6 0.6 0.6]);
        end
        truth = double(Dr.truth(:)).';
        mark = plot(ax, truth(weak(1)), truth(weak(2)), 'rx', 'LineWidth', 1.4, 'MarkerSize', 9);
        uistack(best, 'top'); uistack(worst, 'top'); uistack(mark, 'top');
        xlim(ax, bounds(1, :)); ylim(ax, bounds(2, :));
        xlabel(ax, plotting.display_name('parameter', pair{1}, true), 'Interpreter', 'tex');
        if p == 1, ylabel(ax, plotting.display_name('parameter', pair{2}, true), 'Interpreter', 'tex'); end
        status = cohort.Status(cohort.Protocol == protocols(p));
        if isempty(status), status = ""; end
        title(ax, {sprintf('%s (%s)', protocol_name(protocols(p)), status(1)), ...
            sprintf('best SD ratio %.2f, worst %.2f', T1.Best_SDRatio, T1.Worst_SDRatio)}, ...
            'Interpreter', 'none', 'FontWeight', 'normal', 'FontSize', 9);
        if isempty(shown), shown = [draws best worst other mark]; end
    end
    entries = {'posterior draw (replicate 1)', 'best-determined direction (+/- 2 SD)', ...
        'worst-determined direction (+/- 2 SD)'};
    if numel(shown) == 5, entries{end+1} = 'best direction of replicate 2'; end
    entries{end+1} = 'truth';
    legend_row(band, legend_proxies(band, shown), entries);
    title(layout, {sprintf('%s: the weak pair under each protocol', label), ['every retained draw of ' ...
        'replicate 1; the directions run through the posterior mean over +/- 2 posterior SD along each']}, ...
        'Interpreter', 'none');
    row = plotting.export_saved_figure(fig, cfg, 'case/combinations', name, sources, 'diagnostic', cells);
end

function h = segment(ax, centre, w, sdRatio, priorSD, style, colour)
%SEGMENT A direction w of the prior-standardized pair through CENTRE over +/- 2 SD, in model coordinates.
    step = 2 * sdRatio * (w .* priorSD);
    h = plot(ax, centre(1) + [-1 1] * step(1), centre(2) + [-1 1] * step(2), style, 'Color', colour, ...
        'LineWidth', 2);
end

function band = legend_band(fig, layout)
%LEGEND_BAND A hidden axes across the bottom of the figure for the legend; the layout lies above it.
    share = 0.07;
    layout.OuterPosition = [0 share 1 1 - share];
    band = axes(fig, 'Units', 'normalized', 'Position', [0 0 1 share]);
    hold(band, 'on');
end

function proxies = legend_proxies(ax, handles)
%LEGEND_PROXIES Copies of drawn objects without data in AX, so that its legend shows them as drawn.
    proxies = reshape(copyobj(handles, ax), 1, []);
    for k = 1:numel(proxies)
        set(proxies(k), 'XData', NaN, 'YData', NaN, 'HandleVisibility', 'on');
        if isprop(proxies(k), 'MarkerFaceAlpha')
            set(proxies(k), 'MarkerFaceAlpha', 0.6);
        end
    end
end

function legend_row(ax, handles, labels)
%LEGEND_ROW A one-row legend in the hidden axes of the legend band.
    legend(ax, handles, labels, 'Orientation', 'horizontal', 'NumColumns', numel(handles), ...
        'Location', 'north', 'Interpreter', 'tex');
    axis(ax, 'off');
end

function M = empty_manifest()
    M = table('Size', [0 5], 'VariableTypes', repmat({'string'}, 1, 5), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', 'SourceArtifacts'});
end
