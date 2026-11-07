function manifest = saved_cross_design_figures(cfg,options)
%SAVED_CROSS_DESIGN_FIGURES The six designs compared from the saved posterior tables.
%   MANIFEST = plotting.saved_cross_design_figures(CFG, OPTIONS) draws, per
%   scenario and parameter, the difference of each design from all_six and
%   the normalized posterior widths across cases (plotting.cross_design_metrics),
%   from the saved tables only, and the six-design marginal overlays of the
%   cases and scenarios of the settings (A.10 'designMarginals'), and
%   returns the manifest. Every cell with a posterior counts, certified or
%   a healthy fallback.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    if ~isfield(options,'GenerateCrossDesignComparisons')|| ...
            ~logical(options.GenerateCrossDesignComparisons)
        manifest=empty_manifest();return;
    end
    parts={};
    outputRoot=fullfile(cfg.paths.stage07,'inversion','cross_design');
    if ~isfolder(outputRoot),mkdir(outputRoot);end
    cellsPath=fullfile(study.source_folder(cfg,'coverage'), ...
        'posterior_parameter_cells.csv');
    if isfile(cellsPath)
        cells=readtable(cellsPath,'Delimiter',',','TextType','string');
        summaries=plotting.cross_design_metrics(cfg,cells);
        for s=1:numel(summaries)
            [rows,paths]=write_scenario_tables(cfg,summaries(s),outputRoot);
            parts=[parts rows]; %#ok<AGROW>
            matchedN=nnz(summaries(s).allDesignCohort. ...
                IncludedInAllDesignComparison);
            if matchedN==0
                warning('plotting:saved_cross_design_figures:NoMatchedCases', ...
                    ['No CaseID has a posterior for all six designs ' ...
                     'in scenario %s; its all-design figures were skipped.'], ...
                    summaries(s).scenario);
            else
                parts{end+1}=heatmap_figure(cfg,summaries(s), ...
                    {cellsPath,paths.median,paths.cohort}); %#ok<AGROW>
                for p=1:numel(cfg.paramNames)
                    parts{end+1}=case_distribution_figure(cfg,summaries(s), ...
                        cfg.paramNames{p},{cellsPath,paths.metrics, ...
                        paths.cohort}); %#ok<AGROW>
                end
            end
            for p=1:numel(cfg.paramNames)
                parameter=cfg.paramNames{p};
                rows=string(summaries(s).differences.Parameter)==parameter;
                if any(rows)
                    parts{end+1}=difference_figure(cfg,summaries(s), ...
                        parameter,{cellsPath,paths.differences, ...
                        paths.pairwise}); %#ok<AGROW>
                else
                    warning(['plotting:saved_cross_design_figures:' ...
                        'NoPairwiseCases'],['No design-versus-all_six pair ' ...
                        'has a matched CaseID for %s / %s; only this ' ...
                        'difference figure was skipped.'], ...
                        summaries(s).scenario,parameter);
                end
            end
        end
    end
    if ~strcmp(options.Mode,'aggregate')
        [~,overlayManifest]=selected_overlays(cfg,outputRoot);
        if ~isempty(overlayManifest),parts{end+1}=overlayManifest;end
    end
    manifest=combine(parts);
end

function [parts,paths]=write_scenario_tables(~,R,root)
    tag=char(string(R.scenario));
    paths=struct( ...
        'availability',fullfile(root,[tag '_design_availability.csv']), ...
        'cohort',fullfile(root,[tag '_all_design_matched_cohort.csv']), ...
        'metrics',fullfile(root,[tag '_matched_normalized_sd_cases.csv']), ...
        'median',fullfile(root,[tag '_median_normalized_posterior_sd.csv']), ...
        'pairwise',fullfile(root,[tag '_pairwise_cohorts_vs_all_six.csv']), ...
        'differences',fullfile(root,[tag '_matched_differences_vs_all_six.csv']));
    utils.atomic_write_table(paths.availability,R.availability);
    utils.atomic_write_table(paths.cohort,R.allDesignCohort);
    utils.atomic_write_table(paths.metrics,R.matchedCaseMetrics);
    utils.atomic_write_table(paths.median,R.medianNormalizedSD);
    utils.atomic_write_table(paths.pairwise,R.pairwiseCohorts);
    utils.atomic_write_table(paths.differences,R.differences);
    parts={};
end

function row=heatmap_figure(cfg,R,sources)
    values=double(R.medianMatrix);designs=string(cfg.inversion.designNames);
    parameters=string(cfg.paramNames);n=nnz( ...
        R.allDesignCohort.IncludedInAllDesignComparison);
    fig=figure('Position',[50 60 1040 600]);plotting.blank_missing(imagesc(values));colorbar;
    xticks(1:numel(parameters));xticklabels(parameters);xtickangle(20);
    yticks(1:numel(designs));yticklabels(designs);
    title(sprintf('%s: median normalized posterior SD (matched N = %d)', ...
        strrep(R.scenario,'_',' '),n));
    for d=1:numel(designs)
        for p=1:numel(parameters)
            if isfinite(values(d,p))
                text(p,d,sprintf('%.3f',values(d,p)), ...
                    'HorizontalAlignment','center','FontWeight','bold');
            end
        end
    end
    row=plotting.export_saved_figure(fig,cfg,'inversion/cross_design', ...
        [R.scenario '_median_normalized_posterior_sd_heatmap'], ...
        sources,'publication',struct('Scenario',R.scenario));
end

function row=case_distribution_figure(cfg,R,parameter,sources)
    designs=string(cfg.inversion.designNames);T=R.matchedCaseMetrics;
    fig=figure('Position',[80 100 1040 510]);hold on;
    colors=lines(numel(designs));
    for d=1:numel(designs)
        rows=string(T.Design)==designs(d)&string(T.Parameter)==parameter;
        values=double(T.NormalizedPosteriorSD(rows));
        caseIDs=double(T.CaseID(rows));
        [caseIDs,order]=sort(caseIDs);values=values(order); %#ok<ASGLU>
        offsets=linspace(-0.16,0.16,max(1,numel(values))).';
        scatter(d+offsets,values,22,repmat(colors(d,:),numel(values),1), ...
            'filled','MarkerFaceAlpha',0.65);hold on;
        q=quantile(values,[0.25 0.50 0.75]);
        plot([d d],[q(1) q(3)],'-','Color',colors(d,:),'LineWidth',5);
        plot(d+[-0.22 0.22],[q(2) q(2)],'k-','LineWidth',2);
    end
    xlim([0.5 numel(designs)+0.5]);xticks(1:numel(designs));
    xticklabels(designs);xtickangle(25);ylabel('normalized posterior SD');
    n=nnz(R.allDesignCohort.IncludedInAllDesignComparison);
    title(sprintf('%s: %s across all-six matched cases (N = %d)', ...
        strrep(R.scenario,'_',' '),parameter,n),'Interpreter','none');
    grid on;
    row=plotting.export_saved_figure(fig,cfg,'inversion/cross_design', ...
        sprintf('%s_%s_normalized_sd_cases',R.scenario,parameter), ...
        sources,'publication',struct('Scenario',R.scenario));
end

function row=difference_figure(cfg,R,parameter,sources)
    designs=string(cfg.inversion.designNames(2:end));T=R.differences;
    fig=figure('Position',[80 100 1000 500]);hold on;
    colors=lines(numel(designs));
    for d=1:numel(designs)
        rows=string(T.ComparisonDesign)==designs(d)& ...
            string(T.Parameter)==parameter;
        values=double(T.DeltaNormalizedPosteriorSD(rows));
        values=values(isfinite(values));
        if isempty(values)
            text(d,0,'N=0','HorizontalAlignment','center', ...
                'VerticalAlignment','bottom','Color',[0.55 0.15 0.15]);
            continue;
        end
        offsets=linspace(-0.16,0.16,max(1,numel(values))).';
        scatter(d+offsets,values,22,repmat(colors(d,:),numel(values),1), ...
            'filled','MarkerFaceAlpha',0.65);
        q=quantile(values,[0.25 0.50 0.75]);
        plot([d d],[q(1) q(3)],'-','Color',colors(d,:),'LineWidth',5);
        plot(d+[-0.22 0.22],[q(2) q(2)],'k-','LineWidth',2);
        text(d,q(3),sprintf(' N=%d',numel(values)), ...
            'VerticalAlignment','bottom','HorizontalAlignment','center');
    end
    yline(0,'k--','all\_six parity');xlim([0.5 numel(designs)+0.5]);
    xticks(1:numel(designs));xticklabels(designs);xtickangle(25);
    ylabel('\Delta normalized posterior SD (design - all\_six)');grid on;
    title(sprintf('%s: matched %s differences versus all_six', ...
        strrep(R.scenario,'_',' '),parameter),'Interpreter','none');
    row=plotting.export_saved_figure(fig,cfg,'inversion/cross_design', ...
        sprintf('%s_%s_difference_vs_all_six',R.scenario,parameter), ...
        sources,'publication',struct('Scenario',R.scenario));
end

function [statusTable,manifest]=selected_overlays(cfg,root)
%SELECTED_OVERLAYS The six-design overlays of the cases and scenarios of the settings (A.10 'designMarginals').
    designs=string(cfg.inversion.designNames(:));
    pairs=study.case_outputs(cfg,'designMarginals');
    n=height(pairs)*numel(designs);
    caseColumn=zeros(n,1);scenarioColumn=strings(n,1);designColumn=strings(n,1);
    loadedColumn=false(n,1);stateColumn=strings(n,1);reasonColumn=strings(n,1);
    posteriorColumn=strings(n,1);certificationColumn=strings(n,1);
    artifacts=cell(height(pairs),numel(designs));
    artifactLoaded=false(height(pairs),numel(designs));
    artifactCertified=false(height(pairs),numel(designs));
    cursor=0;
    for k=1:height(pairs)
        for d=1:numel(designs)
            cursor=cursor+1;
            record=struct('caseID',pairs.CaseID(k),'scenario',char(pairs.Scenario(k)), ...
                'design',char(designs(d)));
            [artifact,status]=recovery.load_posterior_provider(cfg,record);
            artifacts{k,d}=artifact;
            artifactLoaded(k,d)=logical(status.loaded);
            artifactCertified(k,d)=logical(status.loaded)&&logical(status.certified);
            caseColumn(cursor)=pairs.CaseID(k);scenarioColumn(cursor)=pairs.Scenario(k);
            designColumn(cursor)=designs(d);loadedColumn(cursor)=status.loaded;
            stateColumn(cursor)=string(status.state);
            reasonColumn(cursor)=string(status.reason);
            if status.loaded
                posteriorColumn(cursor)=relative_path( ...
                    artifact.paths.posteriorPath,cfg.paths.runRoot);
                certificationColumn(cursor)=relative_path( ...
                    recovery.provider_evidence_path(artifact),cfg.paths.runRoot);
            end
        end
    end
    statusTable=table(caseColumn,scenarioColumn,designColumn,loadedColumn, ...
        stateColumn,reasonColumn,posteriorColumn,certificationColumn, ...
        'VariableNames',{'CaseID','Scenario','Design','ArtifactLoaded', ...
        'State','Reason','PosteriorRelativePath','CertificationRelativePath'});
    statusPath=fullfile(root,'selected_cross_design_availability.csv');
    utils.atomic_write_table(statusPath,statusTable);

    parts={};
    for k=1:height(pairs)
        available=reshape(artifactLoaded(k,:),[],1);
        if ~any(available),continue;end
        sources={statusPath};loadedArtifacts=artifacts(k,available);
        loadedArtifacts=reshape(loadedArtifacts,1,[]);
        for a=1:numel(loadedArtifacts)
            sources=[sources {loadedArtifacts{a}.paths.posteriorPath, ...
                recovery.provider_evidence_path(loadedArtifacts{a})}]; %#ok<AGROW>
        end
        parts{end+1}=overlay_figure(cfg,pairs.CaseID(k),pairs.Scenario(k), ...
            designs,reshape(artifacts(k,:),[],1),available, ...
            reshape(artifactCertified(k,:),[],1),sources); %#ok<AGROW>
    end
    manifest=combine(parts);
end

function row=overlay_figure( ...
        cfg,caseID,scenario,designs,artifacts,loaded,certified,sources)
    colors=lines(numel(designs));parameters=string(cfg.paramNames);
    loaded=logical(loaded(:));
    assert(all(~loaded|~cellfun(@isempty,artifacts)), ...
        'plotting:saved_cross_design_figures:LoadedArtifactMissing', ...
        'A posterior marked as loaded has no saved artifact; rerun the step ''inversion''.');
    first=find(loaded,1);
    truth=double(artifacts{first}.truth(:));
    for d=find(loaded).'
        otherTruth=double(artifacts{d}.truth(:));
        assert(max(abs(otherTruth-truth))<=1e-10*max(1,max(abs(truth))), ...
            'plotting:saved_cross_design_figures:TruthMismatch', ...
            'Cross-design artifacts bind different truths for CaseID %d.',caseID);
    end
    fig=figure('Position',[30 40 1200 760]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
    legendHandles=gobjects(0);legendLabels=strings(0);
    estimatorHandles=gobjects(0);truthLegendHandle=gobjects(0);
    intervalHandles=gobjects(0);
    summaries={};
    for p=1:numel(parameters)
        nexttile;hold on;bounds=double(cfg.paramBounds(p,:));
        for d=1:numel(designs)
            if ~loaded(d),continue;end
            draws=double(artifacts{d}.drawsPhysical(:,p));
            [estimate,handles]=plotting.render_posterior_marginal( ...
                draws,bounds,'Color',colors(d,:),'DisplayName',designs(d), ...
                'ShowCentralIntervals',true,'IntervalRow',d);
            handle=handles.density;
            if p==1
                legendHandles(end+1)=handle; %#ok<AGROW>
                legendLabels(end+1)=designs(d); %#ok<AGROW>
                if isempty(estimatorHandles)
                    estimatorHandles=[handles.mean handles.median handles.mode];
                    intervalHandles=[handles.interval50 handles.interval95];
                else
                    set([handles.mean handles.median handles.mode ...
                        handles.interval50 handles.interval95], ...
                        'HandleVisibility','off');
                end
            else
                set([handles.density handles.mean handles.median handles.mode ...
                    handles.interval50 handles.interval95], ...
                    'HandleVisibility','off');
            end
            summaries{end+1}=plotting.posterior_marginal_summary_row( ...
                estimate,designs(d),parameters(p),truth(p)); %#ok<AGROW>
        end
        truthHandle=xline(truth(p),'k--','LineWidth',1.6, ...
            'DisplayName','synthetic truth');
        if p==1,truthLegendHandle=truthHandle;else
            set(truthHandle,'HandleVisibility','off');
        end
        xlabel(parameters(p),'Interpreter','none');ylabel('posterior density');
        xlim(bounds);grid on;
    end
    missing=strjoin(designs(~loaded),' | ');
    if strlength(missing)==0,missing='none';end
    fallback=strjoin(designs(loaded&~logical(certified(:))),' | ');
    if strlength(fallback)==0,fallback='none';end
    sgtitle(sprintf(['Case %d, %s: design posterior marginals (%d/6); healthy ' ...
        'fallback: %s; unavailable: %s'],caseID,strrep(char(scenario),'_',' '), ...
        nnz(loaded),char(fallback),char(missing)),'Interpreter','none');
    if ~isempty(legendHandles)
        legend([legendHandles estimatorHandles intervalHandles ...
            truthLegendHandle], ...
            [cellstr(legendLabels(:));{'posterior mean';'posterior median'; ...
            'marginal mode';'central 50% interval'; ...
            'central 95% interval';'synthetic truth'}], ...
            'Location','southoutside','NumColumns',5,'Interpreter','none');
    end
    % A per-case output: cases/case_<id>/inversion/<scenario>_design_marginals.
    name=sprintf('%s_design_marginals',scenario);
    cells=struct('CaseID',caseID,'Scenario',scenario);
    plotting.write_posterior_marginal_summary(cfg, ...
        'case/inversion',name,vertcat(summaries{:}),sources,'',cells);
    row=plotting.export_saved_figure(fig,cfg, ...
        'case/inversion',name,sources,'publication',cells);
end

function relative=relative_path(pathValue,root)
    pathValue=utils.absolute_path(pathValue);root=utils.absolute_path(root);
    prefix=[root filesep];
    if ispc
        assert(startsWith(lower(pathValue),lower(prefix)), ...
            'plotting:saved_cross_design_figures:PathBoundary', ...
            'The file %s lies outside the folder %s.',pathValue,root);
    else
        assert(startsWith(pathValue,prefix), ...
            'plotting:saved_cross_design_figures:PathBoundary', ...
            'The file %s lies outside the folder %s.',pathValue,root);
    end
    relative=string(strrep(pathValue(numel(prefix)+1:end),'\','/'));
end

function T=combine(parts)
    if isempty(parts),T=empty_manifest();else,T=vertcat(parts{:});end
end

function T=empty_manifest()
    T=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5), ...
        'VariableNames',{'Category','Figure','RelativePath','Scope', ...
        'SourceArtifacts'});
end
