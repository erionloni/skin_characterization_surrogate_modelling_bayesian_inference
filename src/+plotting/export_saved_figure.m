function row = export_saved_figure(fig,cfg,category,name,sources,scope,cells)
%EXPORT_SAVED_FIGURE Write one figure and return its row of the renderers' manifest.
%   ROW = plotting.export_saved_figure(FIG, CFG, CATEGORY, NAME, SOURCES,
%   SCOPE, CELLS) writes FIG in the configured formats: in reproduce mode
%   through study.export_figure (publication layout, the analysis index),
%   otherwise below the category's figure folder of the run. SOURCES are
%   the saved files it was drawn from; SCOPE its figure scope; CELLS the
%   inversion cells it shows: [] when it is not posterior-based, 'all' for
%   every cell of its analysis, or a struct of the CaseID, Scenario, Design
%   and Condition shown (study.index_entry states their status). ROW:
%   Category, Figure, RelativePath, Scope, SourceArtifacts.
%   Side effects: writes the figure files and closes FIG.
    category=char(string(category));name=char(string(name));
    if isempty(scope),scope='aggregate';end
    sources=cellstr(string(sources));
    if isfield(cfg,'layout')&&isstruct(cfg.layout)&&~isempty(cfg.layout)
        % Reproduce mode: publication layout, flat figures/ per analysis.
        row=study.export_figure(fig,cfg,category,name,sources,scope,cells);
        return
    end
    targetDir=fullfile(cfg.paths.stage07,category);
    if ~isfolder(targetDir),mkdir(targetDir);end
    target=fullfile(targetDir,[name '.png']);
    % Written completely under a temporary name, then renamed (CLN-056): an
    % interrupted export never leaves a truncated figure at the final path.
    temporary=fullfile(targetDir,[name '.partial.png']);
    if isfile(temporary),delete(temporary);end
    % The axes toolbar of a visible figure can be captured by the export
    % (MATLAB: "Exported image displays axes toolbar").
    hide_axes_toolbars(fig);
    drawnow;
    try
        exportgraphics(fig,temporary,'Resolution',cfg.fig.resolution);
    catch
        print(fig,temporary,'-dpng',sprintf('-r%d',cfg.fig.resolution));
    end
    utils.strip_png_timestamps(temporary);
    utils.atomic_move_replace(temporary,target);
    if isgraphics(fig),close(fig);end
    relative=strrep(fullfile(category,[name '.png']),'\','/');
    sourceText=portable_sources(sources,cfg.paths.runRoot);
    row=table(string(category),string(name),string(relative), ...
        string(scope),sourceText, ...
        'VariableNames',{'Category','Figure','RelativePath','Scope', ...
        'SourceArtifacts'});
end

function hide_axes_toolbars(fig)
    handles=findall(fig,'Type','axes');
    for i=1:numel(handles)
        try
            handles(i).Toolbar.Visible='off';
        catch
            % Axes without an interactive toolbar (e.g. some chart types).
        end
    end
end

function relativeText=portable_sources(sources,runRoot)
    if isempty(sources)
        relativeText="";return;
    end
    runRoot=utils.absolute_path(runRoot);
    prefix=[runRoot filesep];
    relative=strings(numel(sources),1);
    for i=1:numel(sources)
        source=utils.absolute_path(sources{i});
        if ispc
            contained=startsWith(lower(source),lower(prefix));
        else
            contained=startsWith(source,prefix);
        end
        assert(contained&&isfile(source), ...
            'plotting:export_saved_figure:SourceBoundary', ...
            'Every figure source must be a saved file inside the run root.');
        relative(i)=string(strrep(source(numel(prefix)+1:end),'\','/'));
    end
    relativeText=strjoin(relative,' | ');
end
