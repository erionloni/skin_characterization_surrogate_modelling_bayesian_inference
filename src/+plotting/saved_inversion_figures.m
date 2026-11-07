function manifest = saved_inversion_figures(cfg,options)
%SAVED_INVERSION_FIGURES The figures of the inversion, from the saved posteriors.
%   MANIFEST = plotting.saved_inversion_figures(CFG, OPTIONS) draws, from the
%   saved posterior draws and records of the inversion (no MCMC), per
%   selected cell the credible intervals, the marginals with their
%   statistics and the corner plot (every retained draw in pairs, with the
%   correlations), per further selected cell the sampler traces and the
%   diagnostic metrics, and the corner plots of further cells (of every
%   available cell with 'CornerGallery' 'all'), and returns the manifest.
%   The cells are those of the settings (A.10; study.case_outputs 'cells',
%   'samplerDiagnostics' and 'corners'). Every
%   cell with a posterior is drawn, certified or a healthy fallback; each
%   per-cell figure states the status in its title. The per-cell figures
%   and tables are per-case outputs, in cases/case_<CaseID>/inversion/ as
%   <scenario>_<design>_<what> (marginals, statistics, intervals, corner,
%   traces, diagnostics).
%   Side effects: writes the figures and marginal-statistics tables and
%   closes the figures.
%   Computation: minutes.

    indexPath=cfg.files.certificationIndex;parts={};
    corners=corner_cells(cfg,options);
    if ~isfile(indexPath)
        write_missing_index_corner_status(cfg,corners);
        manifest=empty_manifest();return;
    end
    % The campaign's status table (study.cell_status_columns).
    T=utils.read_csv_table(indexPath,{'Scenario','Design','Status','ProviderSampler','Reason'});
    required={'CaseID','Scenario','Design','Status','ProviderSampler', ...
        'ProviderReplicate','ProviderSteps'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_inversion_figures:CertificationSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''inversion''.', ...
        char(string(indexPath)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    certified=T.Status=="certified";
    % Every cell with a selected provider: certified or a healthy fallback.
    eligible=certified|T.Status=="healthy fallback";
    if ~strcmp(options.Mode,'publication')
        parts{end+1}=certification_heatmap(T,certified,cfg,indexPath);
        parts{end+1}=accepted_level_allocation(T,certified,cfg,indexPath);
    end
    [galleryManifest,~]=corner_gallery(cfg,T,eligible,indexPath,corners);
    if ~isempty(galleryManifest),parts{end+1}=galleryManifest;end
    if strcmp(options.Mode,'aggregate')
        manifest=combine(parts);return;
    end

    % The cells of the settings (A.10 'cells' and 'samplerDiagnostics').
    cells=study.case_outputs(cfg,'cells');
    sampler=study.case_outputs(cfg,'samplerDiagnostics');
    selected=eligible&(in_selection(T,cells)|in_selection(T,sampler));
    indices=find(selected);
    for i=reshape(indices,1,[])
        record=struct('caseID',double(T.CaseID(i)), ...
            'scenario',char(T.Scenario(i)),'design',char(T.Design(i)));
        [artifact,status]=recovery.load_posterior_provider(cfg,record);
        if ~status.loaded,continue;end
        source={artifact.paths.posteriorPath,recovery.provider_evidence_path(artifact)};
        stem=sprintf('case_%d_%s_%s',record.caseID,record.scenario, ...
            record.design);
        shown=shown_cell(record,status);
        posterior=in_selection(T(i,:),cells);
        if posterior
            parts{end+1}=marginal_figure(artifact,cfg,stem,source,shown); %#ok<AGROW>
            parts{end+1}=interval_figure(artifact,cfg,stem,source,shown); %#ok<AGROW>
        end
        if strcmp(options.Mode,'full')
            % The corner plot, unless the corner gallery drew it.
            if posterior&&~in_selection(T(i,:),corners)
                parts{end+1}=pair_figure(artifact,cfg,stem,source,shown); %#ok<AGROW>
            end
            if in_selection(T(i,:),sampler)
                parts{end+1}=trace_figure(artifact,cfg,stem,source,shown); %#ok<AGROW>
                parts{end+1}=diagnostic_figure(artifact,cfg,stem,source,shown); %#ok<AGROW>
            end
        end
    end
    manifest=combine(parts);
end

function shown=shown_cell(record,status)
%SHOWN_CELL The status label, the cell (study.index_entry) and the file-name stem of a cell's outputs.
    shown=struct('label',plotting.provider_status(status),'cells',struct( ...
        'CaseID',record.caseID,'Scenario',record.scenario,'Design',record.design), ...
        'file',sprintf('%s_%s',record.scenario,record.design));
end

function tf=in_selection(T,S)
%IN_SELECTION The rows of the status table T that are cells of the selection S (study.case_outputs).
    key=@(c,s,d) compose("%d|%s|%s",double(c),string(s),string(d));
    tf=ismember(key(T.CaseID,T.Scenario,T.Design),key(S.CaseID,S.Scenario,S.Design));
end

function S=corner_cells(cfg,options)
%CORNER_CELLS The cells of the corner gallery, in the columns of study.case_outputs.
%   Every cell of the inversion grid with 'CornerGallery' 'all'; otherwise
%   the cells of the settings (A.10 'corners').
    if ~logical(options.GenerateAllPosteriorCornerPlots)
        S=study.case_outputs(cfg,'corners');
        return;
    end
    cases=reshape(double(cfg.inversion.caseIDs),[],1);
    scenarios=string(cfg.inversion.activeScenarioTags(:));
    designs=string(cfg.inversion.designNames(:));
    [d,s,c]=ndgrid(1:numel(designs),1:numel(scenarios),1:numel(cases));
    S=table(cases(c(:)),scenarios(s(:)),designs(d(:)), ...
        'VariableNames',{'CaseID','Scenario','Design'});
    assert(height(S)==double(cfg.inversion.expectedCellCount), ...
        'plotting:saved_inversion_figures:CornerGrid', ...
        ['The configured inversion grid has %d cells, not the %d the configuration ' ...
         'expects.'],height(S),double(cfg.inversion.expectedCellCount));
end

function write_missing_index_corner_status(cfg,S)
%WRITE_MISSING_INDEX_CORNER_STATUS The corner gallery's status without a status table of the inversion.
    n=height(S);falseColumn=false(n,1);
    T=table(double(S.CaseID),string(S.Scenario),string(S.Design),falseColumn, ...
        falseColumn,falseColumn,falseColumn,repmat("missing",n,1), ...
        repmat("certification_index_missing",n,1),strings(n,1),'VariableNames', ...
        {'CaseID','Scenario','Design','CertificationIndexed','Certified', ...
        'ArtifactLoaded','FigureGenerated','State','Reason','FigureRelativePath'});
    utils.atomic_write_table(fullfile(cfg.paths.stage07,'inversion', ...
        'corner_plot_status.csv'),T);
end

function [manifest,statusTable]=corner_gallery(cfg,T,eligible,indexPath,S)
%CORNER_GALLERY The corner plots of the cells S (corner_cells), and their status.
%   The status table (bookkeeping of the render) states for every cell
%   whether its corner plot was drawn, and why not.
    expected=height(S);
    caseColumn=double(S.CaseID);scenarioColumn=string(S.Scenario);
    designColumn=string(S.Design);indexedColumn=false(expected,1);
    certifiedColumn=false(expected,1);loadedColumn=false(expected,1);
    generatedColumn=false(expected,1);stateColumn=strings(expected,1);
    reasonColumn=strings(expected,1);figureColumn=strings(expected,1);
    parts={};
    for cursor=1:expected
        hit=double(T.CaseID)==caseColumn(cursor)&T.Scenario==scenarioColumn(cursor)& ...
            T.Design==designColumn(cursor);
        indexedColumn(cursor)=nnz(hit)==1;
        if nnz(hit)~=1
            stateColumn(cursor)="not_uniquely_indexed";
            if nnz(hit)==0
                reasonColumn(cursor)="cell_absent_from_certification_index";
            else
                reasonColumn(cursor)="duplicate_certification_index_rows";
            end
            continue;
        end
        rowIndex=find(hit,1);certifiedColumn(cursor)=T.Status(rowIndex)=="certified";
        if ~eligible(rowIndex)
            stateColumn(cursor)="unresolved";
            reasonColumn(cursor)=index_reason(T,rowIndex);
            continue;
        end
        record=struct('caseID',caseColumn(cursor),'scenario',char(scenarioColumn(cursor)), ...
            'design',char(designColumn(cursor)));
        [artifact,status]=recovery.load_posterior_provider(cfg,record);
        loadedColumn(cursor)=status.loaded;
        stateColumn(cursor)=string(status.state);
        reasonColumn(cursor)=string(status.reason);
        if ~status.loaded,continue;end
        stem=sprintf('case_%d_%s_%s',record.caseID,record.scenario,record.design);
        source={indexPath,artifact.paths.posteriorPath, ...
            recovery.provider_evidence_path(artifact)};
        row=pair_figure(artifact,cfg,stem,source,shown_cell(record,status));
        parts{end+1}=row; %#ok<AGROW>
        generatedColumn(cursor)=true;stateColumn(cursor)="generated";
        reasonColumn(cursor)=string(status.state);
        figureColumn(cursor)=row.RelativePath(1);
    end
    statusTable=table(caseColumn,scenarioColumn,designColumn,indexedColumn, ...
        certifiedColumn,loadedColumn,generatedColumn,stateColumn,reasonColumn, ...
        figureColumn,'VariableNames',{'CaseID','Scenario','Design', ...
        'CertificationIndexed','Certified','ArtifactLoaded','FigureGenerated', ...
        'State','Reason','FigureRelativePath'});
    statusPath=fullfile(cfg.paths.stage07,'inversion','corner_plot_status.csv');
    utils.atomic_write_table(statusPath,statusTable);
    skipped=sum(~statusTable.FigureGenerated);
    if skipped>0
        warning('plotting:saved_inversion_figures:CornerCellsSkipped', ...
            ['The corner gallery drew %d/%d cells; the %d cells without a ' ...
             'posterior are explicit in %s.'], ...
            sum(statusTable.FigureGenerated),expected,skipped,statusPath);
    end
    manifest=combine(parts);
end

function reason=index_reason(T,row)
    candidates={'Reason','FailureReason','Status','Decision'};
    reason="not_certified";
    for i=1:numel(candidates)
        if ismember(candidates{i},T.Properties.VariableNames)
            value=string(T.(candidates{i})(row));
            if strlength(value)>0,reason=value;return;end
        end
    end
end

function row=certification_heatmap(T,certified,cfg,source)
    scenarios=string(cfg.inversion.activeScenarioTags);
    designs=string(cfg.inversion.designNames);values=nan(numel(scenarios), ...
        numel(designs));
    for s=1:numel(scenarios)
        for d=1:numel(designs)
            rows=T.Scenario==scenarios(s)&T.Design==designs(d);
            if any(rows),values(s,d)=mean(double(certified(rows)));end
        end
    end
    fig=figure('Position',[60 80 1120 430]);imagesc(values,[0 1]);colorbar;
    xticks(1:numel(designs));xticklabels(designs);xtickangle(28);
    yticks(1:numel(scenarios));yticklabels(scenarios);
    title('Fraction of certified inversion cells per scenario and design');
    for s=1:numel(scenarios)
        for d=1:numel(designs)
            if isfinite(values(s,d))
                text(d,s,sprintf('%.0f%%',100*values(s,d)), ...
                    'HorizontalAlignment','center','FontWeight','bold');
            end
        end
    end
    row=plotting.export_saved_figure(fig,cfg,'inversion', ...
        'certification_overview',{source},'aggregate','all');
end

function row=accepted_level_allocation(T,certified,cfg,source)
    scenarios=string(cfg.inversion.activeScenarioTags);
    levels=reshape(double(cfg.mcmc.levels),1,[]);
    values=zeros(numel(scenarios),numel(levels));
    for s=1:numel(scenarios)
        for k=1:numel(levels)
            values(s,k)=sum(certified&T.Scenario==scenarios(s)& ...
                double(T.ProviderSteps)==levels(k));
        end
    end
    fig=figure('Position',[100 100 900 460]);bar(values,'stacked');
    xticks(1:numel(scenarios));xticklabels(scenarios);xtickangle(20);
    ylabel('certified cells');
    legend(cellstr(compose('%dk steps',levels/1000)),'Location','best');
    title('Accepted AIES replicate-pair level');
    row=plotting.export_saved_figure(fig,cfg,'inversion', ...
        'certified_level_allocation',{source},'aggregate','all');
end

function row=marginal_figure(A,cfg,stem,sources,shown)
    draws=double(A.drawsPhysical);truth=double(A.truth(:));
    names=cellstr(string(A.parameterNames));
    fig=figure('Position',[50 50 1120 720]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
    summaries=cell(numel(names),1);
    for p=1:numel(names)
        nexttile;
        [estimate,handles]=plotting.render_posterior_marginal( ...
            draws(:,p),cfg.paramBounds(p,:),'DisplayName','posterior', ...
            'ShowCentralIntervals',true);
        truthHandle=xline(truth(p),'r-','LineWidth',1.8, ...
            'DisplayName','synthetic truth');
        xlabel(names{p},'Interpreter','none');ylabel('posterior density');
        if p==1
            legend([handles.density handles.interval95 handles.interval50 ...
                handles.mean handles.median ...
                handles.mode truthHandle],{'posterior density', ...
                '95% equal-tailed interval','50% equal-tailed interval', ...
                'posterior mean', ...
                'posterior median','marginal mode','synthetic truth'}, ...
                'Location','best');
        end
        summaries{p}=plotting.posterior_marginal_summary_row( ...
            estimate,[shown.label ' posterior'],names{p},truth(p));
    end
    sgtitle(sprintf('%s (%s)',strrep(stem,'_',' '),shown.label));
    plotting.write_posterior_marginal_summary(cfg,'case/inversion', ...
        [shown.file '_marginals'],vertcat(summaries{:}),sources,shown.file,shown.cells);
    row=plotting.export_saved_figure(fig,cfg,'case/inversion', ...
        [shown.file '_marginals'],sources,'publication',shown.cells);
end

function row=interval_figure(A,cfg,stem,sources,shown)
%INTERVAL_FIGURE Posterior median, 50 % and 95 % intervals and truth, one row per parameter.
%   Each row's axis spans the parameter's prior range in the model
%   coordinates of the posterior (log10 of the permeability), labelled with
%   the parameter's symbol and unit; the parameters' ranges differ by orders
%   of magnitude, so they do not share an axis.
    draws=double(A.drawsPhysical);truth=double(A.truth(:));
    names=cellstr(string(A.parameterNames));medians=median(draws,1).';
    intervals=quantile(draws,[0.025 0.25 0.75 0.975],1).';
    bounds=double(A.bounds);m=numel(names);
    fig=figure('Position',[100 100 900 110+105*m]);
    layout=tiledlayout(fig,m,1,'Padding','compact','TileSpacing','compact');
    for p=1:m
        ax=nexttile(layout);hold(ax,'on');
        h95=plot(ax,intervals(p,[1 4]),[1 1],'-','Color',[0.72 0.82 0.90], ...
            'LineWidth',1.2);
        h50=plot(ax,intervals(p,[2 3]),[1 1],'-','Color',[0.00 0.35 0.62], ...
            'LineWidth',4);
        hMedian=plot(ax,medians(p),1,'o','MarkerFaceColor',[0.00 0.35 0.62], ...
            'MarkerEdgeColor','none');
        hTruth=plot(ax,truth(p),1,'rx','LineWidth',2,'MarkerSize',9);
        xlim(ax,bounds(p,:));ylim(ax,[0.5 1.5]);yticks(ax,[]);
        xlabel(ax,plotting.display_name('parameter',names{p},true), ...
            'Interpreter','tex');
    end
    title(layout,sprintf(['%s (%s): posterior median, intervals and truth, each over ' ...
        'its prior range'],strrep(stem,'_',' '),shown.label));
    lg=legend(ax,[h95 h50 hMedian hTruth],{'95% equal-tailed interval', ...
        '50% equal-tailed interval','posterior median','truth'}, ...
        'Orientation','horizontal');
    lg.Layout.Tile='south';
    row=plotting.export_saved_figure(fig,cfg,'case/inversion', ...
        [shown.file '_intervals'],sources,'publication',shown.cells);
end

function row=pair_figure(A,cfg,stem,sources,shown)
%PAIR_FIGURE The corner plot: every retained draw in pairs, the marginals on the diagonal, the correlations above.
    name=[shown.file '_corner'];
    % Every retained draw; the markers' transparency
    % falls with the draw count so that the density stays readable.
    allDraws=double(A.drawsPhysical);truth=double(A.truth(:));
    names=cellstr(string(A.parameterNames));n=size(allDraws,1);
    draws=allDraws;markerAlpha=min(0.15,max(0.02,0.15*sqrt(2500/max(n,1))));
    m=numel(names);fig=figure('Position',[20 20 1050 920]);
    tiledlayout(m,m,'Padding','compact','TileSpacing','compact');
    summaries=cell(m,1);
    for r=1:m
        for c=1:m
            nexttile;
            if r==c
                [estimate,handles]=plotting.render_posterior_marginal( ...
                    allDraws(:,c),cfg.paramBounds(c,:), ...
                    'DisplayName','posterior');
                truthHandle=xline(truth(c),'r-','LineWidth',1.3, ...
                    'DisplayName','synthetic truth');
                if c==1
                    legend([handles.density handles.mean handles.median ...
                        handles.mode truthHandle],{'posterior density', ...
                        'posterior mean','posterior median','marginal mode', ...
                        'synthetic truth'},'Location','best','FontSize',7);
                end
                summaries{c}=plotting.posterior_marginal_summary_row( ...
                    estimate,[shown.label ' posterior'],names{c},truth(c));
            elseif r>c
                scatter(draws(:,c),draws(:,r),5,'filled', ...
                    'MarkerFaceAlpha',markerAlpha);hold on;
                plot(truth(c),truth(r),'rx','LineWidth',1.4);
            else
                C=corrcoef(draws(:,c),draws(:,r));
                % '\\rho': in a sprintf format, '\r' is a carriage return.
                text(0.5,0.5,sprintf('\\rho = %.2f',C(1,2)), ...
                    'Units','normalized','HorizontalAlignment','center', ...
                    'FontSize',12);axis off;
            end
            if r==m&&r~=c,xlabel(names{c},'Interpreter','none');end
            if c==1&&r~=c,ylabel(names{r},'Interpreter','none');end
        end
    end
    sgtitle(sprintf('%s (%s): posterior pairs/correlations', ...
        strrep(stem,'_',' '),shown.label));
    plotting.write_posterior_marginal_summary(cfg,'case/inversion',name, ...
        vertcat(summaries{:}),sources,shown.file,shown.cells);
    row=plotting.export_saved_figure(fig,cfg,'case/inversion',name,sources, ...
        'diagnostic',shown.cells);
end

function row=trace_figure(A,cfg,stem,sources,shown)
    samples=double(A.sampleArray);names=cellstr(string(A.parameterNames));
    sampler=upper(char(string(A.certification.provider.sampler)));
    fig=figure('Position',[50 50 1120 700]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
    for p=1:numel(names)
        nexttile;values=squeeze(samples(:,p,:));
        if isvector(values),values=values(:);end
        if strcmp(sampler,'AIES')
            bands=quantile(values,[0.10 0.50 0.90],2);
            x=(1:size(values,1)).';
            fill([x;flipud(x)],[bands(:,1);flipud(bands(:,3))], ...
                [0.65 0.80 0.91],'EdgeColor','none');hold on;
            plot(x,bands(:,2),'Color',[0.00 0.35 0.60]);
            ylabel([names{p} ' (walker 10--90%, median)'], ...
                'Interpreter','none');
        else
            plot(values);ylabel(names{p},'Interpreter','none');
        end
        xlabel('retained iteration');
    end
    sgtitle(sprintf('%s (%s): %s provider traces',strrep(stem,'_',' '),shown.label,sampler));
    row=plotting.export_saved_figure(fig,cfg,'case/inversion', ...
        [shown.file '_traces'],sources,'diagnostic',shown.cells);
end

function row=diagnostic_figure(A,cfg,stem,sources,shown)
    H=A.health;names=cellstr(string(A.parameterNames));
    fig=figure('Position',[60 80 1080 420]);
    tiledlayout(1,3,'Padding','compact','TileSpacing','compact');
    nexttile;bar(double(H.rankSplitRhat));yline(1.05,'r--');
    xticks(1:numel(names));xticklabels(names);xtickangle(25);title('split R-hat');
    nexttile;bar([double(H.bulkESS(:)) double(H.tailESS(:))]);
    yline(400,'--');yline(200,':');xticks(1:numel(names));
    xticklabels(names);xtickangle(25);title('ESS');legend('bulk','tail');
    nexttile;bar(double(H.relativeSdMCSE));yline(0.05,'r--');
    xticks(1:numel(names));xticklabels(names);xtickangle(25);
    title('relative SD MCSE');
    sgtitle(sprintf('%s (%s): provider diagnostics (NaN for AIES single run)', ...
        strrep(stem,'_',' '),shown.label));
    row=plotting.export_saved_figure(fig,cfg,'case/inversion', ...
        [shown.file '_diagnostics'],sources,'diagnostic',shown.cells);
end

function T=combine(parts)
    if isempty(parts),T=empty_manifest();else,T=vertcat(parts{:});end
end

function T=empty_manifest()
    T=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5), ...
        'VariableNames',{'Category','Figure','RelativePath','Scope', ...
        'SourceArtifacts'});
end
