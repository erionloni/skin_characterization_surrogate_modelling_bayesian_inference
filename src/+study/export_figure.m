function row = export_figure(fig, cfg, category, name, sources, rendererScope, cells)
%EXPORT_FIGURE Write one figure into the publication layout.
%   ROW = study.export_figure(FIG, CFG, CATEGORY, NAME, SOURCES, RENDERERSCOPE,
%   CELLS) is called by plotting.export_saved_figure in reproduce mode
%   (CFG.layout set). It writes
%     <output>/<route>/<NN_analysis>/figures/<file>.<format>   for each format
%   where the analysis folder and the file name follow from CATEGORY
%   (study.layout): deeper category levels and a prefix become part of the
%   flat file name. The output of a per-case category goes to the case
%   folder instead, <output>/<route>/cases/case_<CaseID>/<step>/figures/
%   (study.figure_target); the index of its analysis names it relative to
%   the analysis folder (../cases/...). SOURCES are the saved files the figure was drawn from;
%   CELLS the inversion cells it shows ([] when it is not posterior-based,
%   'all' for every cell of its analysis, or a struct of CaseID, Scenario,
%   Design and Condition; study.index_entry). The figure enters
%   the index of its analysis with its title, scope, caption and command;
%   the analysis README lists the index.
%
%   Every file is written to a temporary name first and renamed when
%   complete (utils.atomic_move_replace, which retries while another process
%   holds the file), so an interrupted run never leaves a truncated figure. A PNG
%   file carries no creation time (utils.strip_png_timestamps): a figure
%   with the same content gives the same file whenever it is rendered.
%
%   Without hardware-accelerated graphics MATLAB draws fewer markers than a
%   plot holds. A figure with a plot of more than 1,000 markers is then
%   refused when the shipped results are rendered in place, and written
%   with a warning and a note in the index otherwise.
%
%   ROW has the columns of plotting.export_saved_figure (Category, Figure,
%   RelativePath, Scope, SourceArtifacts); Figure is the file name without
%   extension and RelativePath is relative to the output folder. The figure
%   window is closed.
%   Side effects: writes the figure files; adds to CFG.layout.index; closes FIG.

    category = char(string(category));
    name = char(string(name));
    sources = cellstr(string(sources));
    [route, analysis, file, where] = study.figure_target(cfg, category, name, cells);
    paths = source_records(sources, cfg.layout);

    folder = fullfile(cfg.layout.output, route, strrep(where, '/', filesep), 'figures');
    if ~isfolder(folder), mkdir(folder); end
    drawnow;
    graphics = marker_rendering(fig, cfg, file);
    title = figure_title(fig);
    written = {};
    for k = 1:numel(cfg.layout.formats)
        format = cfg.layout.formats{k};
        target = fullfile(folder, [file '.' format]);
        temporary = fullfile(folder, [file '.partial.' format]);
        if isfile(temporary), delete(temporary); end
        if strcmp(format, 'png')
            exportgraphics(fig, temporary, 'Resolution', cfg.fig.resolution);
            % Without the creation time, equal figures give equal files.
            utils.strip_png_timestamps(temporary);
        else
            exportgraphics(fig, temporary, 'ContentType', 'vector');
        end
        utils.atomic_move_replace(temporary, target);
        written{end+1} = [file '.' format]; %#ok<AGROW>
    end
    if isgraphics(fig), close(fig); end
    study.index_entry(cfg, 'figure', strcat(below(analysis, where), 'figures/', written), title, ...
        graphics, cells);

    relative = strjoin({route, where, 'figures', written{1}}, '/');
    row = manifest_row(category, file, relative, rendererScope, paths);
end

function note = marker_rendering(fig, cfg, file)
%MARKER_RENDERING Refuse or record a figure with many markers drawn without hardware graphics.
%   Without hardware-accelerated graphics, MATLAB draws fewer markers than
%   a plot holds ("Displaying fewer markers to preserve interactivity"), so
%   a scatter of every posterior draw would show a subsample. NOTE is ''
%   when the figure has no plot with more than 1,000 markers or when the
%   graphics have full hardware support. Otherwise the shipped results
%   ('InPlace') are refused, and any other run gets a warning and a note in
%   the index of the analysis.
    note = '';
    objects = findall(fig, 'Type', 'scatter');
    lines = findall(fig, 'Type', 'line');
    if ~isempty(lines)
        objects = [objects; lines(~strcmp(get(lines, 'Marker'), 'none'))];
    end
    if isempty(objects) || max(arrayfun(@(h) numel(h.XData), objects)) <= 1000
        return;
    end
    level = 'Full';
    try
        axesList = findall(fig, 'Type', 'axes');
        info = rendererinfo(axesList(1));
        level = char(string(info.Details.HardwareSupportLevel));
    catch
        % rendererinfo without this field: the level stays unknown and unchecked
    end
    if strcmpi(level, 'Full'), return; end
    assert(~(isfield(cfg.layout, 'inPlace') && cfg.layout.inPlace), ...
        'study:export_figure:SoftwareGraphics', ...
        ['Hardware-accelerated graphics is unavailable (support level %s), so MATLAB ' ...
         'would draw fewer markers in %s than its data hold. The shipped results are ' ...
         'rendered with hardware graphics only: render again when it is available ' ...
         '(for example with the display switched on).'], level, file);
    note = sprintf(['rendered without hardware-accelerated graphics (support level %s): ' ...
        'MATLAB may draw fewer markers than the data hold'], level);
    warning('study:export_figure:SoftwareGraphics', '%s: %s.', file, note);
end

function prefix = below(analysis, where)
%BELOW The folder WHERE relative to the analysis folder: '' for the analysis itself.
    prefix = '';
    if ~strcmp(where, analysis), prefix = ['../' where '/']; end
end

function row = manifest_row(category, file, relative, scope, paths)
%MANIFEST_ROW The renderers' manifest row.
    row = table(string(category), string(file), string(relative), string(scope), ...
        string(strjoin(paths, ' | ')), ...
        'VariableNames', {'Category', 'Figure', 'RelativePath', 'Scope', ...
        'SourceArtifacts'});
end

function paths = source_records(sources, layout)
%SOURCE_RECORDS Portable path (study.portable_path) of every source.
    paths = cell(1, numel(sources));
    for i = 1:numel(sources)
        assert(isfile(sources{i}), 'study:export_figure:SourceMissing', ...
            'Figure source is not a saved file: %s', sources{i});
        paths{i} = study.portable_path(sources{i}, layout);
    end
end

function t = figure_title(fig)
%FIGURE_TITLE The overall title of a figure, for the index.
%   Order: a figure-level title (sgtitle or tiled-layout title), else the
%   first non-empty axes title. A subtitle of that axes follows in
%   parentheses: two figures may share a title and differ in the subtitle.
    t = '';
    candidates = [findall(fig, 'Type', 'subplottext'); ...
        findall(fig, 'Type', 'tiledlayout')];
    for i = 1:numel(candidates)
        h = candidates(i);
        if isprop(h, 'Title') && isgraphics(h.Title), h = h.Title; end
        if isprop(h, 'String'), t = text_of(h.String); end
        if ~isempty(t), return; end
    end
    axesHandles = flipud(findall(fig, 'Type', 'axes'));
    for i = 1:numel(axesHandles)
        t = text_of(axesHandles(i).Title.String);
        if isempty(t), continue; end
        if isprop(axesHandles(i), 'Subtitle') && isgraphics(axesHandles(i).Subtitle)
            s = text_of(axesHandles(i).Subtitle.String);
            if ~isempty(s), t = sprintf('%s (%s)', t, s); end
        end
        return;
    end
end

function t = text_of(value)
    t = strtrim(strjoin(cellstr(string(value)), ' '));
    t = regexprep(t, '\s+', ' ');
end
