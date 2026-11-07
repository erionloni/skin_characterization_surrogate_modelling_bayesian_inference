function manifest = saved_design_study_figures(cfg,options)
%SAVED_DESIGN_STUDY_FIGURES The figures of the design study, from its saved tables.
%   MANIFEST = plotting.saved_design_study_figures(CFG, OPTIONS) draws, per
%   scenario, the design rankings and their bootstrap uncertainty, the FIM
%   against the posterior, the posterior uncertainty and correlation, the
%   covariance and trace decompositions and the condition numbers, from the
%   saved tables of the design study (no GP, no MCMC), and returns the
%   manifest, for every scenario of the inversion; and the 95 % ellipse of
%   the target posterior of the cases and scenarios of the settings (A.10
%   'targetEllipse'). The matched cases of a scenario are those with a
%   posterior for every design compared, certified or a healthy fallback; a
%   case's figure states the status of its cell.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    parts={};scenarios=string(cfg.inversion.activeScenarioTags);
    for s=1:numel(scenarios)
        tag=char(scenarios(s));root=fullfile(study.source_folder(cfg, ...
            'design_study'),'scenarios',tag,'tables');
        summaryPath=fullfile(root,'design_summary.csv');
        if ~isfile(summaryPath),continue;end
        T=readtable(summaryPath,'Delimiter',',','TextType','string');
        required={'Design','MeanQInformation','MeanFullInformation', ...
            'MeanDUtility','MeanNormalizedPosteriorSD', ...
            'MeanContractionAmount'};
        assert(all(ismember(required,T.Properties.VariableNames)), ...
            'plotting:saved_design_study_figures:SummarySchema', ...
            'The saved table %s lacks the column(s) %s; rerun the step ''design_study''.', ...
            char(string(summaryPath)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
        rankingAvailable=all(isfinite(double(T.MeanQInformation)))&& ...
            (~ismember('MatchedCaseCount',T.Properties.VariableNames)|| ...
            all(double(T.MatchedCaseCount)>0));
        bootstrapPath=fullfile(root,'rank_bootstrap_summary.csv');
        if isfile(bootstrapPath)
            B=readtable(bootstrapPath,'Delimiter',',','TextType','string');
        else
            B=table();
        end
        if rankingAvailable
            parts{end+1}=ranking_figure(T,B,cfg,tag,summaryPath, ...
                bootstrapPath); %#ok<AGROW>
            parts{end+1}=fim_posterior_figure(T,cfg,tag,summaryPath); %#ok<AGROW>
        end
        if rankingAvailable&&isfile(bootstrapPath)
            parts{end+1}=rank_uncertainty_figure(B,cfg,tag, ...
                bootstrapPath); %#ok<AGROW>
        end
        if ~strcmp(options.Mode,'publication')
            if rankingAvailable
                parts{end+1}=information_figure(T,cfg,tag,summaryPath); %#ok<AGROW>
                parts{end+1}=uncertainty_figure(T,cfg,tag,summaryPath); %#ok<AGROW>
            end
            dimensionPath=fullfile(root,'subset_dimensionality.csv');
            if isfile(dimensionPath)
                dimensions=readtable(dimensionPath,'Delimiter',',','TextType','string');
                parts{end+1}=dimension_figure(dimensions,cfg,tag, ...
                    dimensionPath); %#ok<AGROW>
            end
            covariancePath=fullfile(root,'posterior_covariance_reference.csv');
            if isfile(covariancePath)
                covariance=readtable(covariancePath,'Delimiter',',','TextType','string');
                if ~isempty(covariance)
                    parts{end+1}=correlation_figure(covariance,cfg, ...
                        tag,covariancePath); %#ok<AGROW>
                end
            end
            svdPath=fullfile(root,'svd_directions.csv');
            if isfile(svdPath)
                svd=readtable(svdPath,'Delimiter',',','TextType','string');
                if ~isempty(svd)
                    parts{end+1}=singular_value_figure( ...
                        svd,cfg,tag,svdPath); %#ok<AGROW>
                    parts{end+1}=weak_loading_figure( ...
                        svd,cfg,tag,svdPath); %#ok<AGROW>
                end
            end
            fimPath=fullfile(root,'fim_metrics.csv');
            if isfile(fimPath)
                fim=readtable(fimPath,'Delimiter',',','TextType','string');
                if ~isempty(fim)
                    parts{end+1}=condition_figure( ...
                        fim,cfg,tag,fimPath); %#ok<AGROW>
                end
            end
            decompositionPath=fullfile(root, ...
                'covariance_decomposition_variance.csv');
            if isfile(decompositionPath)
                decomposition=readtable(decompositionPath,'Delimiter',',','TextType','string');
                if ~isempty(decomposition)&&any(decomposition.Design=="all_six")
                    parts{end+1}=decomposition_figure( ...
                        decomposition,cfg,tag,decompositionPath); %#ok<AGROW>
                end
            end
            tracePath=fullfile(root, ...
                'covariance_decomposition_trace_shares.csv');
            if isfile(tracePath)
                trace=readtable(tracePath,'Delimiter',',','TextType','string');
                if ~isempty(trace)&&any(trace.Design=="all_six")
                    parts{end+1}=decomposition_trace_figure( ...
                        trace,cfg,tag,tracePath); %#ok<AGROW>
                end
            end
            reliabilityPath=fullfile(root, ...
                'posterior_reliability_eligibility.csv');
            if isfile(reliabilityPath)
                reliability=readtable(reliabilityPath,'Delimiter',',','TextType','string');
                parts{end+1}=reliability_figure( ...
                    reliability,cfg,tag,reliabilityPath); %#ok<AGROW>
            end
            parameterPath=fullfile(root,'posterior_parameter_reference.csv');
            if isfile(parameterPath)&&isfile(covariancePath)&& ...
                    exist('covariance','var')&&~isempty(covariance)
                parameters=readtable(parameterPath,'Delimiter',',','TextType','string');
                if ~isempty(parameters)
                    parts{end+1}=q_ellipse_figures(parameters,covariance, ...
                        cfg,tag,{parameterPath,covariancePath}); %#ok<AGROW>
                end
            end
        end
        sequencePath=fullfile(root,'sequential_information.csv');
        if isfile(sequencePath)&&strcmp(options.Mode,'full')
            sequence=readtable(sequencePath,'Delimiter',',','TextType','string');
            if ~isempty(sequence)
                parts{end+1}=sequence_figure(sequence,cfg,tag, ...
                    sequencePath); %#ok<AGROW>
            end
        end
    end
    manifest=combine(parts);
end

function row=ranking_figure(T,B,cfg,tag,summaryPath,bootstrapPath)
    [values,order]=sort(double(T.MeanQInformation),'descend');
    designs=T.Design(order);lower=zeros(size(values));upper=zeros(size(values));
    sources={summaryPath};
    if ~isempty(B)&&all(ismember({'Metric','Design','BootstrapCI025', ...
            'BootstrapCI975'},B.Properties.VariableNames))
        Q=B(B.Metric=="q_information",:);sources{end+1}=bootstrapPath;
        for i=1:numel(designs)
            hit=find(Q.Design==designs(i),1);
            if ~isempty(hit)
                lower(i)=values(i)-double(Q.BootstrapCI025(hit));
                upper(i)=double(Q.BootstrapCI975(hit))-values(i);
            end
        end
    end
    fig=figure('Position',[80 80 1030 500]);bar(values);hold on;
    errorbar(1:numel(values),values,max(lower,0),max(upper,0), ...
        'k.','LineWidth',1.2);
    xticks(1:numel(designs));xticklabels(designs);xtickangle(28);
    ylabel('target-q covariance log-volume reduction [nats]');
    title([strrep(tag,'_',' ') ': design ranking']);
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_design_ranking'],sources,'publication',struct('Scenario',tag));
end

function row=information_figure(T,cfg,tag,source)
    fig=figure('Position',[80 80 1050 470]);
    bar([double(T.MeanQInformation) double(T.MeanFullInformation)]);
    xticks(1:height(T));xticklabels(T.Design);xtickangle(28);
    ylabel('covariance log-volume reduction [nats]');
    legend({'target q','all parameters'},'Location','southoutside', ...
        'Orientation','horizontal');
    title([strrep(tag,'_',' ') ': posterior information by design']);
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_target_q_information'],{source},'aggregate',struct('Scenario',tag));
end

function row=uncertainty_figure(T,cfg,tag,source)
    fig=figure('Position',[80 80 1050 470]);
    bar([double(T.MeanNormalizedPosteriorSD) ...
        double(T.MeanContractionAmount)]);
    xticks(1:height(T));xticklabels(T.Design);xtickangle(28);
    ylabel('normalized scale');legend({'posterior SD','contraction'}, ...
        'Location','southoutside','Orientation','horizontal');
    title([strrep(tag,'_',' ') ': posterior uncertainty and contraction']);
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_posterior_uncertainty'],{source},'aggregate',struct('Scenario',tag));
end

function row=fim_posterior_figure(T,cfg,tag,source)
    x=double(T.MeanQInformation);y=double(T.MeanDUtility);
    finite=isfinite(x)&isfinite(y);indices=find(finite);
    fig=figure('Position',[100 100 780 610]);
    scatter(x(finite),y(finite),55,'filled');hold on;
    for i=1:numel(indices)
        text(x(indices(i)),y(indices(i)),"  "+T.Design(indices(i)), ...
            'Interpreter','none');
    end
    xlabel('posterior target-q information');ylabel('local FIM D-optimal utility');
    title([strrep(tag,'_',' ') ': FIM versus posterior information']);
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_fim_vs_posterior'],{source},'publication',struct('Scenario',tag));
end

function row=rank_uncertainty_figure(B,cfg,tag,source)
    required={'Metric','Design','ProbabilityRank1','ProbabilityTop3'};
    assert(all(ismember(required,B.Properties.VariableNames)), ...
        'plotting:saved_design_study_figures:BootstrapSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''design_study''.', ...
        char(string(source)),strjoin(setdiff(required,B.Properties.VariableNames),', '));
    Q=B(B.Metric=="q_information",:);
    fig=figure('Position',[80 80 1030 470]);
    bar([double(Q.ProbabilityRank1) double(Q.ProbabilityTop3)]);
    xticks(1:height(Q));xticklabels(Q.Design);xtickangle(28);ylim([0 1]);
    ylabel('paired-case bootstrap probability');
    legend({'rank 1 credit','top 3'},'Location','southoutside', ...
        'Orientation','horizontal');
    title([strrep(tag,'_',' ') ': design-ranking uncertainty']);
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_ranking_uncertainty'],{source},'publication',struct('Scenario',tag));
end

function row=dimension_figure(T,cfg,tag,source)
    required={'Design','LikelihoodOutputDimension', ...
        'QInformationPerLikelihoodOutput'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_design_study_figures:DimensionSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''design_study''.', ...
        char(string(source)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    keep=isfinite(double(T.QInformationPerLikelihoodOutput));rows=find(keep);
    fig=figure('Position',[80 80 870 560]);
    scatter(double(T.LikelihoodOutputDimension(keep)), ...
        double(T.QInformationPerLikelihoodOutput(keep)),65,'filled');hold on;
    for i=1:numel(rows)
        text(double(T.LikelihoodOutputDimension(rows(i))), ...
            double(T.QInformationPerLikelihoodOutput(rows(i))), ...
            "  "+T.Design(rows(i)),'Interpreter','none');
    end
    xlabel('likelihood output dimension');
    ylabel('target-q information per likelihood output');
    title([strrep(tag,'_',' ') ': information by output-subset dimension']);
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_subset_dimension_information'],{source},'aggregate',struct('Scenario',tag));
end

function row=correlation_figure(T,cfg,tag,source)
    required={'Design','RowParameter','ColumnParameter','Correlation'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_design_study_figures:CovarianceSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''design_study''.', ...
        char(string(source)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    available=unique(T.Design,'stable');selected=intersect( ...
        string(cfg.inversion.designNames),available,'stable');
    if any(selected=="all_six")
        design="all_six";
    elseif ~isempty(selected)
        design=selected(1);
    else
        design=available(1);
    end
    names=string(cfg.paramNames);values=nan(numel(names));
    for r=1:numel(names)
        for c=1:numel(names)
            rows=T.Design==design&T.RowParameter==names(r)& ...
                T.ColumnParameter==names(c);
            values(r,c)=mean(double(T.Correlation(rows)),'omitnan');
        end
    end
    fig=figure('Position',[100 100 720 590]);plotting.blank_missing(imagesc(values,[-1 1]));colorbar;
    xticks(1:numel(names));xticklabels(names);xtickangle(25);
    yticks(1:numel(names));yticklabels(names);
    title(sprintf('%s: mean posterior correlation (%s)', ...
        strrep(tag,'_',' '),strrep(char(design),'_',' ')));
    for r=1:numel(names)
        for c=1:numel(names)
            if isfinite(values(r,c))
                text(c,r,sprintf('%.2f',values(r,c)), ...
                    'HorizontalAlignment','center','FontWeight','bold');
            end
        end
    end
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_posterior_correlation'],{source},'aggregate', ...
        struct('Scenario',tag,'Design',char(design)));
end

function row=singular_value_figure(T,cfg,tag,source)
    required={'Design','DirectionIndex','NormalizedSingularValue'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_design_study_figures:SVDTableSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''design_study''.', ...
        char(string(source)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    designs=unique(T.Design,'stable');directions=sort(unique( ...
        double(T.DirectionIndex)));
    values=nan(numel(directions),numel(designs));
    for d=1:numel(designs)
        for k=1:numel(directions)
            rows=T.Design==designs(d)&double(T.DirectionIndex)==directions(k);
            values(k,d)=median(double(T.NormalizedSingularValue(rows)), ...
                'omitnan');
        end
    end
    % Only positive values are drawn: a design without full rank has zero
    % singular values (its numerical rank is in the design ranking table).
    values(~(values>0))=NaN;
    fig=figure('Position',[80 80 1000 550]);
    semilogy(directions,values,'-o');
    xlabel('singular direction');ylabel('median normalized singular value');
    title({[strrep(tag,'_',' ') ': covariance-whitened singular spectra'], ...
        'zero singular values not drawn (numerical rank: design ranking table)'});
    legend(designs,'Location','eastoutside');
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_singular_value_waterfall'],{source},'aggregate',struct('Scenario',tag));
end

function row=weak_loading_figure(T,cfg,tag,source)
    required={'Design','DirectionIndex','Loading_m3f','Loading_m3e', ...
        'Loading_log10k0','Loading_Thickness'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_design_study_figures:SVDLoadingSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''design_study''.', ...
        char(string(source)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    designs=unique(T.Design,'stable');weak=max(double(T.DirectionIndex));
    variables={'Loading_m3f','Loading_m3e','Loading_log10k0', ...
        'Loading_Thickness'};
    values=nan(numel(designs),numel(variables));
    for d=1:numel(designs)
        rows=T.Design==designs(d)&double(T.DirectionIndex)==weak;
        for p=1:numel(variables)
            values(d,p)=mean(abs(double(T.(variables{p})(rows))),'omitnan');
        end
    end
    fig=figure('Position',[80 80 900 560]);plotting.blank_missing(imagesc(values));colorbar;
    xticks(1:4);xticklabels(string(cfg.paramNames));xtickangle(20);
    yticks(1:numel(designs));yticklabels(designs);
    title([strrep(tag,'_',' ') ': mean absolute weakest-direction loading']);
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_weakest_direction_loadings'],{source},'aggregate',struct('Scenario',tag));
end

function row=condition_figure(T,cfg,tag,source)
    required={'Design','ConditionNumber'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_design_study_figures:FIMConditionSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''design_study''.', ...
        char(string(source)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    % Only finite condition numbers are drawn: a design without full rank
    % has an infinite one (its numerical rank is in the design ranking table).
    values=double(T.ConditionNumber);finite=isfinite(values);
    fig=figure('Position',[80 80 1050 520]);
    boxchart(categorical(T.Design(finite),unique(T.Design,'stable')),log10(values(finite)));
    ylabel('log10 condition number');xtickangle(25);
    title({[strrep(tag,'_',' ') ': local FIM conditioning by design'], ...
        sprintf('%d infinite condition numbers not drawn (numerical rank: design ranking table)', ...
        nnz(~finite))});
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_condition_number_distribution'],{source},'aggregate',struct('Scenario',tag));
end

function row=decomposition_figure(T,cfg,tag,source)
    required={'Design','Own_m3f','Own_m3e','Own_log10k0', ...
        'Own_Thickness','SignedCovarianceTotal'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_design_study_figures:DecompositionSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''design_study''.', ...
        char(string(source)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    rows=T.Design=="all_six";
    values=[mean(double(T.Own_m3f(rows)),'omitnan'), ...
        mean(double(T.Own_m3e(rows)),'omitnan'), ...
        mean(double(T.Own_log10k0(rows)),'omitnan'), ...
        mean(double(T.Own_Thickness(rows)),'omitnan'), ...
        mean(double(T.SignedCovarianceTotal(rows)),'omitnan')];
    fig=figure('Position',[90 90 850 480]);bar(values);
    xticks(1:5);xticklabels([string(cfg.paramNames) "signed covariance"]);
    xtickangle(22);ylabel('mean ratio-variance contribution');
    title([strrep(tag,'_',' ') ': all-six covariance decomposition']);
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_covariance_decomposition'],{source},'aggregate',struct('Scenario',tag));
end

function row=decomposition_trace_figure(T,cfg,tag,source)
    required={'Design','Component','SignedTraceContribution', ...
        'NormalizedAbsoluteTraceShare'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_design_study_figures:DecompositionTraceSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''design_study''.', ...
        char(string(source)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    T=T(T.Design=="all_six",:);components=unique(T.Component,'stable');
    signed=nan(numel(components),1);shares=signed;
    for i=1:numel(components)
        rows=T.Component==components(i);
        signed(i)=mean(double(T.SignedTraceContribution(rows)),'omitnan');
        shares(i)=mean(double(T.NormalizedAbsoluteTraceShare(rows)),'omitnan');
    end
    fig=figure('Position',[70 70 1150 470]);
    tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    nexttile;bar(signed);ylabel('signed trace contribution');title('Signed');
    xticks(1:numel(components));xticklabels(components);xtickangle(30);
    nexttile;bar(shares);ylabel('normalized absolute share');title('Magnitude');
    xticks(1:numel(components));xticklabels(components);xtickangle(30);
    sgtitle([strrep(tag,'_',' ') ': posterior covariance trace decomposition']);
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_covariance_trace_decomposition'],{source},'aggregate',struct('Scenario',tag));
end

function row=reliability_figure(T,cfg,tag,source)
    required={'CaseID','Design','CellReliable'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_design_study_figures:ReliabilitySchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''design_study''.', ...
        char(string(source)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    caseValues=string(T.CaseID);
    cases=unique(caseValues,'stable');designs=unique(T.Design,'stable');
    values=nan(numel(cases),numel(designs));
    for c=1:numel(cases)
        for d=1:numel(designs)
            rows=caseValues==cases(c)&T.Design==designs(d);
            if any(rows),values(c,d)=double(T.CellReliable(find(rows,1)));end
        end
    end
    fig=figure('Position',[70 70 1050 620]);plotting.blank_missing(imagesc(values,[0 1]));colorbar;
    xticks(1:numel(designs));xticklabels(designs);xtickangle(28);
    yticks(1:numel(cases));yticklabels(cases);
    xlabel('design');ylabel('case ID');
    title([strrep(tag,'_',' ') ': posterior reliability matrix']);
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_reliability_matrix'],{source},'diagnostic',struct('Scenario',tag));
end

function manifest=q_ellipse_figures(P,C,cfg,tag,sources)
%Q_ELLIPSE_FIGURES The target-q ellipse of each case of the settings (A.10 'targetEllipse') in scenario TAG.
%   A case without an all_six posterior in the saved tables of the scenario
%   has no ellipse.
    requiredP={'CaseID','Design','Parameter','PosteriorMeanU'};
    requiredC={'CaseID','Design','RowParameter','ColumnParameter','CovarianceU'};
    assert(all(ismember(requiredP,P.Properties.VariableNames))&& ...
        all(ismember(requiredC,C.Properties.VariableNames)), ...
        'plotting:saved_design_study_figures:QEllipseSchema', ...
        ['The saved posterior tables %s lack the column(s) %s; rerun the step ' ...
         '''design_study''.'],strjoin(cellstr(string(sources)),' and '), ...
        strjoin([setdiff(requiredP,P.Properties.VariableNames) ...
        setdiff(requiredC,C.Properties.VariableNames)],', '));
    selection=study.case_outputs(cfg,'targetEllipse');
    available=unique(string(P.CaseID(P.Design=="all_six")),'stable');
    parts={};
    for caseID=reshape(intersect(string(selection.CaseID(selection.Scenario==string(tag))), ...
            available,'stable'),1,[])
        parts{end+1}=q_ellipse_figure(P,C,cfg,tag,sources,caseID); %#ok<AGROW>
    end
    manifest=combine(parts);
end

function row=q_ellipse_figure(P,C,cfg,tag,sources,caseID)
%Q_ELLIPSE_FIGURE The 95 % ellipse of the all_six posterior of m3_e_RD and log10_k0_RD of one case (CASEID, text).
    target=["m3_e_RD" "log10_k0_RD"];
    parameterCaseIDs=string(P.CaseID);covarianceCaseIDs=string(C.CaseID);
    mu=nan(2,1);covariance=nan(2);
    for i=1:2
        rows=parameterCaseIDs==caseID&P.Design=="all_six"& ...
            P.Parameter==target(i);
        if ~any(rows),row=empty_manifest_row();return;end
        mu(i)=double(P.PosteriorMeanU(find(rows,1)));
        for j=1:2
            rows=covarianceCaseIDs==caseID&C.Design=="all_six"& ...
                C.RowParameter==target(i)&C.ColumnParameter==target(j);
            if ~any(rows),row=empty_manifest_row();return;end
            covariance(i,j)=double(C.CovarianceU(find(rows,1)));
        end
    end
    [vectors,values]=eig((covariance+covariance.')/2);
    values=diag(max(diag(values),0));angle=linspace(0,2*pi,240);
    ellipse=mu+vectors*sqrt(values)*(sqrt(5.991)* ...
        [cos(angle);sin(angle)]);
    fig=figure('Position',[100 100 640 560]);
    plot(ellipse(1,:),ellipse(2,:),'LineWidth',2);hold on;
    plot(mu(1),mu(2),'ko','MarkerFaceColor','k');axis equal;
    xlabel(target(1),'Interpreter','none');ylabel(target(2),'Interpreter','none');
    status=plotting.cell_status_label(cfg,caseID,tag,'all_six');
    if ~isempty(status),status=[' (' status ')'];end
    title(sprintf('%s: case %s all-six target-q 95%% ellipse%s', ...
        strrep(tag,'_',' '),char(caseID),status));
    % A per-case output: cases/case_<id>/design_study/<scenario>_target_q_ellipse.
    row=plotting.export_saved_figure(fig,cfg,'case/design_study', ...
        [tag '_target_q_ellipse'],sources,'diagnostic', ...
        struct('CaseID',double(str2double(caseID)),'Scenario',tag,'Design','all_six'));
end

function row=empty_manifest_row()
    row=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5), ...
        'VariableNames',{'Category','Figure','RelativePath','Scope', ...
        'SourceArtifacts'});
end

function row=sequence_figure(T,cfg,tag,source)
    required={'Sequence','Step','QInformation'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_design_study_figures:SequenceSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''design_study''.', ...
        char(string(source)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    fig=figure('Position',[100 100 850 500]);hold on;
    sequences=unique(T.Sequence,'stable');
    for i=1:numel(sequences)
        rows=T.Sequence==sequences(i);steps=unique(double(T.Step(rows)));
        values=nan(size(steps));
        for k=1:numel(steps)
            values(k)=mean(double(T.QInformation(rows& ...
                double(T.Step)==steps(k))),'omitnan');
        end
        plot(steps,values,'-o','DisplayName',sequences(i),'LineWidth',1.5);
    end
    xlabel('registered nested-design step');ylabel('mean target-q information');
    legend('Location','best');
    title([strrep(tag,'_',' ') ': sequential registered-design information']);
    row=plotting.export_saved_figure(fig,cfg,'stage9', ...
        [tag '_sequential_information'],{source},'diagnostic',struct('Scenario',tag));
end

function T=combine(parts)
    if isempty(parts),T=empty_manifest();else,T=vertcat(parts{:});end
end

function T=empty_manifest()
    T=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5), ...
        'VariableNames',{'Category','Figure','RelativePath','Scope', ...
        'SourceArtifacts'});
end
