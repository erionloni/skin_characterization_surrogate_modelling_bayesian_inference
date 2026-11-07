function manifest = saved_coverage_figures(cfg,options)
%SAVED_COVERAGE_FIGURES The coverage and recovery figures of the recovery.
%   MANIFEST = plotting.saved_coverage_figures(CFG, OPTIONS) draws, from the
%   saved summary tables of the recovery (no model, no MCMC), the coverage
%   (95% and 50%), contraction and recovery-error figures per scenario and
%   design, recovery across cases and the scenario comparison, and returns
%   the manifest (one row per figure); no figure pools the scenarios over a
%   design (their availability differs). Every cell with a posterior
%   counts, certified or a healthy fallback; each aggregate states the
%   number of cases it rests on, and cells without a value stay grey.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    root=study.source_folder(cfg,'coverage');parts={};
    summaryPath=fullfile(root,'summary_by_scenario_design.csv');
    if ~isfile(summaryPath),manifest=empty_manifest();return;end
    T=readtable(summaryPath,'Delimiter',',','TextType','string');
    required={'Scenario','Design','IncludedRows','MeanContractionAmount', ...
        'MeanTruthCovered50','MeanTruthCovered95', ...
        'AcrossCaseMeanNormAbsErrorFromPosteriorMedian'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_coverage_figures:SummarySchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''recovery''.', ...
        char(string(summaryPath)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    parts{end+1}=metric_heatmap(T,'MeanContractionAmount', ...
        'Mean posterior contraction','design_contraction',cfg, ...
        summaryPath,'publication');
    parts{end+1}=metric_heatmap(T, ...
        'AcrossCaseMeanNormAbsErrorFromPosteriorMedian', ...
        'Mean absolute recovery error from posterior median / prior range', ...
        'design_recovery_error',cfg, ...
        summaryPath,'publication');
    cellsPath=fullfile(root,'posterior_parameter_cells.csv');
    if isfile(cellsPath)
        cells=readtable(cellsPath,'Delimiter',',','TextType','string');
        parts{end+1}=recovery_figure(cells,cfg,cellsPath);
    end
    if ~strcmp(options.Mode,'publication')
        parts{end+1}=metric_heatmap(T,'MeanTruthCovered50', ...
            'Truth inclusion in 50% posterior interval','design_coverage_50', ...
            cfg,summaryPath,'aggregate');
        parts{end+1}=metric_heatmap(T,'MeanTruthCovered95', ...
            'Truth inclusion in 95% posterior interval','design_coverage', ...
            cfg,summaryPath,'aggregate');
        parts{end+1}=scenario_figure(T,cfg,summaryPath);
        statusPath=fullfile(root,'posterior_cell_status.csv');
        if isfile(statusPath)
            status=readtable(statusPath,'Delimiter',',','TextType','string');
            parts{end+1}=missingness_figure(status,cfg,statusPath);
        end
    end
    manifest=combine(parts);
end

function row=metric_heatmap(T,variable,titleText,name,cfg,source,scope)
    scenarios=string(cfg.inversion.activeScenarioTags);
    designs=string(cfg.inversion.designNames);
    values=nan(numel(scenarios),numel(designs));counts=zeros(size(values));
    for s=1:numel(scenarios)
        for d=1:numel(designs)
            rows=T.Scenario==scenarios(s)&T.Design==designs(d);
            if any(rows)
                values(s,d)=mean(double(T.(variable)(rows)),'omitnan');
                counts(s,d)=cases_with_posterior(T(rows,:),cfg);
            end
        end
    end
    fig=figure('Position',[60 90 1120 430]);plotting.blank_missing(imagesc(values));colorbar;
    xticks(1:numel(designs));xticklabels(designs);xtickangle(28);
    yticks(1:numel(scenarios));yticklabels(scenarios);
    title(sprintf(['%s (cases with a posterior, certified and healthy fallback; ' ...
        'n = cases per cell)'],titleText));
    for s=1:numel(scenarios)
        for d=1:numel(designs)
            if isfinite(values(s,d))
                text(d,s,sprintf('%.2f\nn = %d',values(s,d),counts(s,d)), ...
                    'HorizontalAlignment','center','FontWeight','bold');
            end
        end
    end
    row=plotting.export_saved_figure(fig,cfg,'robustness',name,{source},scope,'all');
end

function n=cases_with_posterior(rows,cfg)
%CASES_WITH_POSTERIOR Cases with a posterior behind summary rows (case x parameter records).
    n=sum(double(rows.IncludedRows))/numel(cfg.paramNames);
end

function row=recovery_figure(T,cfg,source)
    required={'Scenario','Design','Parameter','TruthPhysical', ...
        'PosteriorMedianPhysical','CI025Physical','CI25Physical', ...
        'CI75Physical','CI975Physical', ...
        'ArtifactLoaded'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_coverage_figures:CellSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''recovery''.', ...
        char(string(source)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    loaded=to_logical(T.ArtifactLoaded);
    selected=T.Scenario=="measurement_plus_gp"&T.Design=="all_six"&loaded;
    parameters=string(cfg.paramNames);fig=figure('Position',[50 50 1100 720]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
    for p=1:numel(parameters)
        nexttile;rows=selected&T.Parameter==parameters(p);
        truth=double(T.TruthPhysical(rows));medianValue= ...
            double(T.PosteriorMedianPhysical(rows));
        lower95=double(T.CI025Physical(rows));
        lower50=double(T.CI25Physical(rows));
        upper50=double(T.CI75Physical(rows));
        upper95=double(T.CI975Physical(rows));
        if ~isempty(truth)
            for i=1:numel(truth)
                plot([truth(i) truth(i)],[lower95(i) upper95(i)],'-', ...
                    'Color',[0.72 0.82 0.90],'LineWidth',1.2);hold on;
                plot([truth(i) truth(i)],[lower50(i) upper50(i)],'-', ...
                    'Color',[0.00 0.35 0.62],'LineWidth',3.6);
            end
            scatter(truth,medianValue,30,'filled', ...
                'MarkerFaceColor',[0.00 0.35 0.62]);
            extent=[truth;medianValue;lower95;upper95];
            extent=extent(isfinite(extent));
            limits=[min(extent) max(extent)];
            if limits(1)==limits(2),limits=limits+[-0.5 0.5];end
            plot(limits,limits,'k--');xlim(limits);ylim(limits);axis square;
        end
        xlabel('held-out truth');ylabel('posterior median');
        title(parameters(p),'Interpreter','none');
        if p==1
            % A tile without cells (a small rerun) has not held its axes yet;
            % the legend's placeholder lines must not replace one another.
            hold on;
            outer=plot(nan,nan,'-','Color',[0.72 0.82 0.90], ...
                'LineWidth',1.2);
            inner=plot(nan,nan,'-','Color',[0.00 0.35 0.62], ...
                'LineWidth',3.6);
            point=plot(nan,nan,'o','MarkerFaceColor',[0.00 0.35 0.62], ...
                'MarkerEdgeColor','none');
            truthLine=plot(nan,nan,'k--');
            legend([outer inner point truthLine], ...
                {'95% equal-tailed interval','50% equal-tailed interval', ...
                 'posterior median','perfect recovery'},'Location','best');
        end
    end
    sgtitle(sprintf(['Primary-scenario all-six recovery across held-out cases (n = %d, ' ...
        'certified and healthy fallback)'],numel(unique(T.CaseID(selected)))));
    row=plotting.export_saved_figure(fig,cfg,'robustness', ...
        'recovery_across_cases',{source},'publication', ...
        struct('Scenario','measurement_plus_gp','Design','all_six'));
end

function row=scenario_figure(T,cfg,source)
    scenarios=string(cfg.inversion.activeScenarioTags);values=nan(numel(scenarios),4);
    counts=zeros(numel(scenarios),1);
    for s=1:numel(scenarios)
        rows=T.Scenario==scenarios(s);
        counts(s)=cases_with_posterior(T(rows,:),cfg);
        values(s,:)=[mean(double(T.MeanContractionAmount(rows)),'omitnan') ...
            mean(double(T.MeanTruthCovered50(rows)),'omitnan') ...
            mean(double(T.MeanTruthCovered95(rows)),'omitnan') ...
            mean(double(T.AcrossCaseMeanNormAbsErrorFromPosteriorMedian(rows)), ...
            'omitnan')];
    end
    fig=figure('Position',[100 100 950 470]);bar(values);
    xticks(1:numel(scenarios));xtickangle(20);
    xticklabels(compose('%s (n = %d cells)',scenarios(:),counts));
    legend({'contraction','50% truth inclusion','95% truth inclusion', ...
        'mean absolute recovery error from posterior median'}, ...
        'Location','southoutside','Orientation','horizontal');
    title(['Uncertainty-scenario robustness across six observation designs (cells with a ' ...
        'posterior, certified and healthy fallback)']);
    row=plotting.export_saved_figure(fig,cfg,'robustness', ...
        'scenario_comparison',{source},'aggregate','all');
end

function row=missingness_figure(T,cfg,source)
    required={'Scenario','Design','ArtifactLoaded'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_coverage_figures:StatusSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''recovery''.', ...
        char(string(source)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    loaded=to_logical(T.ArtifactLoaded);scenarios=string( ...
        cfg.inversion.activeScenarioTags);designs=string(cfg.inversion.designNames);
    values=zeros(numel(scenarios),numel(designs));
    for s=1:numel(scenarios)
        for d=1:numel(designs)
            rows=T.Scenario==scenarios(s)&T.Design==designs(d);
            values(s,d)=sum(~loaded(rows));
        end
    end
    fig=figure('Position',[60 90 1120 420]);imagesc(values);colorbar;
    xticks(1:numel(designs));xticklabels(designs);xtickangle(28);
    yticks(1:numel(scenarios));yticklabels(scenarios);
    title('Unavailable inversion cells (no posterior) per scenario and design');
    row=plotting.export_saved_figure(fig,cfg,'robustness', ...
        'unresolved_cell_map',{source},'aggregate','all');
end

function value=to_logical(input)
    if islogical(input),value=input;return;end
    if isnumeric(input),value=input~=0;return;end
    value=ismember(lower(string(input)),["true" "1"]);
end

function T=combine(parts)
    if isempty(parts),T=empty_manifest();else,T=vertcat(parts{:});end
end

function T=empty_manifest()
    T=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5), ...
        'VariableNames',{'Category','Figure','RelativePath','Scope', ...
        'SourceArtifacts'});
end
