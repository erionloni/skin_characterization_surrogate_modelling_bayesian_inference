function manifest = saved_fixed_dataset_figures(cfg, ~)
%SAVED_FIXED_DATASET_FIGURES Overview figures of the fixed-route dataset.
%   MANIFEST = plotting.saved_fixed_dataset_figures(CFG, OPTIONS) reads the
%   fixed dataset CFG.realData.csv (setting fixed.dataset.file; thesis: the
%   452 cases of data/fixed/fixed_dataset.csv) and draws, in the fixed-route
%   dataset folder:
%     dataset_output_distributions          histogram of each closing pressure
%                                           (15 equal-width bins over its observed
%                                           values; missing values omitted, not imputed)
%     dataset_mean_cycle_pressures          mean pressure per probe and cycle, each
%                                           over its own observed cases
%     dataset_mean_cycle_pressures_complete_cases
%                                           the same over the complete cases
%                                           (thesis: 306); the table also
%                                           holds their SD and range
%     dataset_availability_patterns         which outputs are observed (1) or
%                                           missing (0), per availability pattern
%   The plotted numbers are also written as tables next to the figures.
%   Nothing is fitted or computed beyond counts, means, SDs, ranges and
%   histograms.
%   OPTIONS is unused (same signature as the other renderers).
%   Ported from the meeting-additions adapter (generate_meeting.py, dataset()).
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    source = cfg.realData.csv;
    assert(isfile(source), 'plotting:saved_fixed_dataset_figures:Dataset', ...
        'The fixed dataset is missing: %s (setting fixed.dataset.file).', source);
    outputs = cellstr(string(cfg.outputNames(:))).';
    D = readtable(source, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    Y = D{:, outputs};
    complete = all(isfinite(Y), 2);
    parts = {};

    % Closing-pressure distributions.
    fig = figure('Position', [60 60 1300 700]);
    layout = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    rows = {};
    stats = cell(numel(outputs), 1);
    for j = 1:numel(outputs)
        z = Y(isfinite(Y(:, j)), j);
        edges = linspace(min(z), max(z), 16);
        counts = histcounts(z, edges);
        nexttile(layout);
        histogram('BinEdges', edges, 'BinCounts', counts, 'FaceColor', [0.38 0.65 0.80], ...
            'EdgeColor', [0.19 0.27 0.34]);
        title(plotting.display_name('output', outputs{j}), 'Interpreter', 'tex');
        xlabel('closing pressure [mbar]');
        ylabel('number of cases');
        text(0.97, 0.95, sprintf('N = %d', numel(z)), 'Units', 'normalized', ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
        rows{end+1} = table(repmat(string(outputs{j}), 15, 1), edges(1:end-1).', ...
            edges(2:end).', counts.', repmat(numel(z), 15, 1), 'VariableNames', ...
            {'Output', 'Left', 'Right', 'Count', 'Observed'}); %#ok<AGROW>
        stats{j} = table(string(outputs{j}), numel(z), height(D) - numel(z), mean(z), ...
            std(z), min(z), max(z), 'VariableNames', {'Output', 'Observed', 'Missing', ...
            'Mean', 'SD', 'Minimum', 'Maximum'});
    end
    title(layout, sprintf('Fixed dataset (%d cases): closing-pressure distributions', height(D)));
    T = vertcat(rows{:});
    parts{end+1} = export(fig, cfg, 'dataset_output_distributions', source, T, ...
        'Histogram counts of each closing pressure (15 equal-width bins over its observed values)');

    % Mean pressure by probe and cycle, output-specific cohorts.
    S = vertcat(stats{:});
    fig = cycle_bars(reshape(S.Mean, 3, 2), 'Mean closing pressure by probe and cycle');
    subtitle('each bar over the cases where that pressure is observed');
    parts{end+1} = export(fig, cfg, 'dataset_mean_cycle_pressures', source, S, ...
        'Observed count, mean, SD and range of each closing pressure');

    % Same, over the complete cases.
    means = mean(Y(complete, :), 1);
    C = table(string(outputs(:)), means(:), repmat(nnz(complete), numel(outputs), 1), ...
        std(Y(complete, :), 0, 1).', min(Y(complete, :), [], 1).', max(Y(complete, :), [], 1).', ...
        'VariableNames', {'Output', 'Mean', 'N', 'SD', 'Minimum', 'Maximum'});
    fig = cycle_bars(reshape(means, 3, 2), 'Mean closing pressure by probe and cycle');
    subtitle(sprintf('matched cohort: the %d complete cases', nnz(complete)));
    parts{end+1} = export(fig, cfg, 'dataset_mean_cycle_pressures_complete_cases', source, C, ...
        sprintf('Mean, SD and range of each closing pressure over the %d complete cases', nnz(complete)));

    % Availability patterns (1 observed, 0 missing).
    observed = double(isfinite(Y));
    patterns = strings(height(D), 1);
    for i = 1:height(D)
        patterns(i) = strjoin(string(observed(i, :)), '');
    end
    [unique_patterns, ~, index] = unique(patterns);
    counts = accumarray(index, 1);
    [counts, order] = sort(counts, 'descend');
    unique_patterns = unique_patterns(order);
    P = table(unique_patterns, counts, 'VariableNames', {'Pattern', 'Count'});
    matrix = cell2mat(arrayfun(@(p) double(char(p)) - '0', unique_patterns, 'UniformOutput', false));
    fig = figure('Position', [80 80 900 420]);
    imagesc(matrix, [0 1]);
    colormap(fig, [0.97 0.97 0.97; 0.20 0.45 0.65]);
    ax = gca;
    ax.TickLabelInterpreter = 'tex';
    xticks(1:numel(outputs)); xticklabels(plotting.display_name('output', outputs));
    yticks(1:height(P));
    yticklabels(compose('%s (N = %d)', P.Pattern, P.Count));
    for r = 1:size(matrix, 1)
        for c = 1:size(matrix, 2)
            text(c, r, sprintf('%d', matrix(r, c)), 'HorizontalAlignment', 'center', ...
                'Color', [1 1 1] * (matrix(r, c) == 1));
        end
    end
    grid off;
    title('Output availability patterns (1 observed, 0 missing; missing is not zero pressure)');
    parts{end+1} = export(fig, cfg, 'dataset_availability_patterns', source, P, ...
        'Number of cases per output availability pattern');
    manifest = vertcat(parts{:});
end

function fig = cycle_bars(values, titleText)
%CYCLE_BARS Grouped bars: cycles 1-3 on the x axis, probes D2 and D6 as groups.
    fig = figure('Position', [80 80 760 440]);
    b = bar(1:3, values, 0.8);
    b(1).DisplayName = 'probe D2';
    b(2).DisplayName = 'probe D6';
    xticks(1:3); xticklabels({'cycle 1', 'cycle 2', 'cycle 3'});
    ylabel('mean closing pressure [mbar]');
    legend('Location', 'northeast');
    title(titleText);
end

function row = export(fig, cfg, name, source, T, tableTitle)
    if study.is_publication(cfg)
        study.export_table(cfg, 'dataset', name, T, {source}, tableTitle,[]);
    end
    row = plotting.export_saved_figure(fig, cfg, 'dataset', name, {source}, 'publication',[]);
end
