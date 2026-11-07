function manifest = saved_conditional_inversion_figures(cfg,options)
%SAVED_CONDITIONAL_INVERSION_FIGURES Plot saved oracle-condition evidence.
%   All summaries come from saved inversion tables and all selected marginals
%   come from the saved posterior files of the selected providers, certified
%   or healthy fallbacks (named in the titles). This function performs no
%   likelihood evaluation, surrogate fit, inversion, or sample pooling.
%   MANIFEST = plotting.saved_conditional_inversion_figures(CFG, OPTIONS)
%   draws, for the conditions the saved results hold (labelled and ordered
%   as in the settings' condition table, A.9; plotting.conditional_inversion_metrics),
%   for the figure parameters of A.9 (figureParameters):
%     - per scenario in which at least two conditions besides the reference
%       ran: the posterior spread, the recovery error and the 50 % and 95 %
%       truth inclusion of all its conditions on their matched cohort
%       (<scenario>_normalized_posterior_sd, _median_recovery_error,
%       _coverage50, _coverage95);
%     - per condition of the primary scenario besides the reference: its
%       comparison with the reference on their matched cohort
%       (<scenario>_<reference>_vs_<condition>);
%     - the selected posteriors of the cases of the settings (A.10
%       'conditionalPosteriors'), in the case folders;
%   and returns the manifest (one row per figure).
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    parts={};
    outputRoot=fullfile(cfg.paths.stage07,'inversion','conditional');
    if ~isfolder(outputRoot),mkdir(outputRoot);end
    sourceRoot=study.source_folder(cfg,'conditional_inversion');
    paths=struct( ...
        'comparison',configured_file(cfg,'conditionalComparison', ...
            fullfile(sourceRoot,'reports', ...
                'conditional_inversion_comparison.csv')), ...
        'status',fullfile(sourceRoot,'cell_status.csv'), ...
        'matched',configured_file(cfg,'conditionalMatchedCohorts', ...
            fullfile(sourceRoot,'reports', ...
                'conditional_inversion_matched_cohorts.csv')), ...
        'matchedSummary',configured_file(cfg,'conditionalMatchedSummary', ...
            fullfile(sourceRoot,'reports', ...
                'conditional_inversion_matched_summary.csv')));
    required=struct2cell(paths);
    statusRows={};
    if ~all(cellfun(@isfile,required))
        names=string(fieldnames(paths));
        missing=names(~cellfun(@isfile,required));
        statusRows{end+1}=status_row('conditional_reports','not_generated', ...
            0,0,"missing_saved_artifacts:"+strjoin(missing,'|'));
        utils.atomic_write_table(fullfile(outputRoot, ...
            'conditional_figure_status.csv'),vertcat(statusRows{:}));
        manifest=empty_manifest();return;
    end

    comparison=readtable(paths.comparison,'Delimiter',',','TextType','string', ...
        'VariableNamingRule','preserve');
    % The conditional campaign's status table (study.cell_status_columns).
    statusTable=readtable(paths.status,'Delimiter',',','TextType','string', ...
        'VariableNamingRule','preserve');
    requiredStatus=study.cell_status_columns('conditional');
    assert(all(ismember(requiredStatus,statusTable.Properties.VariableNames)), ...
        'plotting:saved_conditional_inversion_figures:StatusSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''conditional_inversion''.', ...
        char(string(paths.status)),strjoin(setdiff(requiredStatus,statusTable.Properties.VariableNames),', '));
    matched=readtable(paths.matched,'Delimiter',',','TextType','string', ...
        'VariableNamingRule','preserve');
    metrics=plotting.conditional_inversion_metrics(cfg,comparison,matched);
    conditions=metrics.conditions;
    expectedCaseCount=numel(metrics.cases);
    commonSources={paths.comparison,paths.status,paths.matched, ...
        paths.matchedSummary};
    palette=lines(numel(inversion.conditional_inversion_conditions(cfg)));

    % The plotted values, next to the figures' staging folder.
    for G=reshape(metrics.groups,1,[])
        members=conditions(G.members);
        if strcmp(G.kind,'conditions')
            for spec=figure_specs()
                utils.atomic_write_table(fullfile(outputRoot, ...
                    [char(G.scenario) spec.suffix '.csv']),G.metrics.(spec.metric));
            end
        else
            utils.atomic_write_table(fullfile(outputRoot,char(pair_name(G.scenario,members)+".csv")), ...
                pair_rows(G));
        end
        utils.atomic_write_table(fullfile(outputRoot,char(G.scenario+"_"+ ...
            strjoin([members.code],"_")+"_matched_cohort.csv")),G.cohort);
    end

    for G=reshape(metrics.groups,1,[])
        members=conditions(G.members);
        analysis=G.scenario+"_"+strjoin([members.code],"_");
        exact=strjoin([members.code],"_");
        n=G.cohort.MatchedN(1);
        if strcmp(G.kind,'conditions')
            if n>0
                colors=palette([members.rank],:);
                for spec=figure_specs()
                    csvPath=fullfile(outputRoot,[char(G.scenario) spec.suffix '.csv']);
                    titleText=sprintf('%s: %s under oracle conditions %s', ...
                        strrep(char(G.scenario),'_','\_'),spec.title,range_text(members));
                    if spec.coverage==0
                        parts{end+1}=trajectory_figure(cfg,G.metrics.(spec.metric), ...
                            spec.label,titleText,[char(G.scenario) spec.suffix], ...
                            [commonSources {csvPath}],members,colors,metrics.parameters,G.scenario); %#ok<AGROW>
                    else
                        parts{end+1}=coverage_figure(cfg,G.metrics.(spec.metric), ...
                            spec.coverage,titleText,[char(G.scenario) spec.suffix], ...
                            [commonSources {csvPath}],members,colors,metrics.parameters,G.scenario); %#ok<AGROW>
                    end
                end
                statusRows{end+1}=status_row(analysis,'generated',n,expectedCaseCount, ...
                    "exact_"+exact+"_matched_intersection"); %#ok<AGROW>
            else
                statusRows{end+1}=status_row(analysis,'not_generated',0,expectedCaseCount, ...
                    "zero_exact_"+exact+"_matched_cases"); %#ok<AGROW>
            end
        else
            if n>0
                csvPath=fullfile(outputRoot,char(pair_name(G.scenario,members)+".csv"));
                parts{end+1}=pair_figure(cfg,pair_rows(G),[commonSources {csvPath}], ...
                    members,metrics.parameters,G.scenario); %#ok<AGROW>
                statusRows{end+1}=status_row(analysis,'generated',n,expectedCaseCount, ...
                    "exact_"+exact+"_matched_intersection"); %#ok<AGROW>
            else
                statusRows{end+1}=status_row(analysis,'not_generated',0,expectedCaseCount, ...
                    "zero_exact_"+exact+"_matched_cases"); %#ok<AGROW>
            end
        end
    end

    selectedStatus=empty_selected_status();
    if ~strcmp(char(string(options.Mode)),'aggregate')
        selection=study.case_outputs(cfg,'conditionalPosteriors');
        selectedCases=reshape(selection.CaseID,1,[]);
        [selectedManifest,selectedStatus]=selected_overlays( ...
            cfg,comparison,selectedCases,commonSources,conditions,palette,metrics.parameters);
        if ~isempty(selectedManifest),parts{end+1}=selectedManifest;end
    end
    utils.atomic_write_table(fullfile(outputRoot, ...
        'selected_posterior_status.csv'),selectedStatus);
    if isempty(statusRows)
        statusRows{end+1}=status_row('conditional_comparisons','not_generated',0, ...
            expectedCaseCount,'no_scenario_with_two_conditions_or_primary_condition');
    end
    utils.atomic_write_table(fullfile(outputRoot, ...
        'conditional_figure_status.csv'),vertcat(statusRows{:}));
    manifest=combine(parts);
end

function specs=figure_specs()
%FIGURE_SPECS The four figures of a scenario's conditions: metric, file suffix, title, axis label.
    specs=struct( ...
        'metric',{'NormalizedPosteriorSD','PosteriorMedianNormalizedRecoveryError', ...
            'Covered50','Covered95'}, ...
        'suffix',{'_normalized_posterior_sd','_median_recovery_error','_coverage50', ...
            '_coverage95'}, ...
        'title',{'posterior spread','truth recovery','50% truth inclusion','95% truth inclusion'}, ...
        'label',{'Normalized posterior SD','Median normalized recovery error','',''}, ...
        'coverage',{0,0,50,95});
end

function text=range_text(members)
%RANGE_TEXT The conditions of a figure title: a range (A--D) when they are consecutive rows of the table.
    ranks=[members.rank];
    if numel(ranks)>=3&&all(diff(ranks)==1)
        text=char(members(1).code+"--"+members(end).code);
    else
        text=char(strjoin([members.code],", "));
    end
end

function positions=fixed_positions(members,parameterIndex)
%FIXED_POSITIONS The positions (1..n) of the conditions that fix the parameter: no posterior there.
    positions=find(arrayfun(@(c) ismember(parameterIndex,c.fixedIndices),members));
end

function label_fixed(positions)
%LABEL_FIXED Marks the positions of a fixed parameter ("fixed at the truth") inside the current axes.
    if isempty(positions),return;end
    limits=ylim;
    for position=reshape(positions,1,[])
        text(position,limits(1)+0.03*diff(limits),'fixed at the truth','Rotation',90, ...
            'HorizontalAlignment','left','Color',[0.45 0.45 0.45]);
    end
end

function name=pair_name(scenario,members)
    name=string(scenario)+"_"+members(1).code+"_vs_"+members(2).code;
end

function T=pair_rows(G)
%PAIR_ROWS The four metrics of a pair figure, one table (spread, recovery error, 50 % and 95 % inclusion).
    T=vertcat(G.metrics.NormalizedPosteriorSD,G.metrics.PosteriorMedianNormalizedRecoveryError, ...
        G.metrics.Covered50,G.metrics.Covered95);
end

function row=trajectory_figure(cfg,T,yLabel,titleText,name,sources,members,colors,parameters,scenario)
    codes=[members.savedCode];n=numel(codes);
    [~,parameterIndices]=ismember(parameters,string(cfg.paramNames));
    caseIDs=unique(double(T.CaseID(T.IncludedInMatchedCohort)),'stable');
    fig=figure('Position',[30 80 1220 520]);
    tiledlayout(1,numel(parameters),'Padding','compact','TileSpacing','compact');
    for p=1:numel(parameters)
        nexttile;hold on;
        fixedAt=fixed_positions(members,parameterIndices(p));
        for c=1:numel(caseIDs)
            values=nan(1,n);
            for q=1:n
                hit=double(T.CaseID)==caseIDs(c)&T.Parameter==parameters(p)& ...
                    T.ConditionCode==codes(q)&T.MetricAvailable;
                if nnz(hit)==1,values(q)=double(T.MetricValue(hit));end
            end
            available=isfinite(values);
            if any(available)
                plot(find(available),values(available),'-', ...
                    'Color',[0.78 0.78 0.78],'LineWidth',0.65);
            end
        end
        for q=1:n
            if ismember(q,fixedAt),continue;end
            hit=T.Parameter==parameters(p)&T.ConditionCode==codes(q)& ...
                T.MetricAvailable;
            values=double(T.MetricValue(hit));
            if isempty(values)
                text(q,0,'metric NA / N=0','Rotation',90, ...
                    'HorizontalAlignment','left','Color',[0.45 0.45 0.45]);
                continue;
            end
            scatter(repmat(q,numel(values),1),values,17, ...
                repmat(colors(q,:),numel(values),1),'filled', ...
                'MarkerFaceAlpha',0.58);
            quartiles=quantile(values,[0.25 0.50 0.75]);
            errorbar(q,quartiles(2),quartiles(2)-quartiles(1), ...
                quartiles(3)-quartiles(2),'o','Color',colors(q,:), ...
                'MarkerFaceColor',colors(q,:),'LineWidth',2.1, ...
                'CapSize',14);
            text(q,quartiles(3),sprintf(' N=%d',numel(values)), ...
                'VerticalAlignment','bottom','HorizontalAlignment','center');
        end
        xlim([0.5 n+0.5]);xticks(1:n);xticklabels(cellstr([members.tick]));
        xtickangle(18);ylabel(yLabel);title(parameters(p),'Interpreter','none');
        grid on;
        label_fixed(fixedAt);
    end
    sgtitle(sprintf('%s (exact matched N = %d)',titleText,numel(caseIDs)), ...
        'Interpreter','tex');
    row=plotting.export_saved_figure(fig,cfg,'inversion/conditional', ...
        name,sources,'publication',struct('Scenario',char(scenario)));
end

function row=coverage_figure(cfg,T,coveragePercent,titleText,name,sources,members,colors,parameters,scenario)
    codes=[members.savedCode];n=numel(codes);
    [~,parameterIndices]=ismember(parameters,string(cfg.paramNames));
    matchedN=max(double(T.MatchedN));
    fig=figure('Position',[30 80 1220 520]);
    tiledlayout(1,numel(parameters),'Padding','compact','TileSpacing','compact');
    for p=1:numel(parameters)
        nexttile;hold on;values=nan(1,n);counts=zeros(1,n);
        fixedAt=fixed_positions(members,parameterIndices(p));
        for q=1:n
            hit=T.Parameter==parameters(p)&T.ConditionCode==codes(q);
            if any(hit)
                counts(q)=max(double(T.SummaryN(hit)));
                available=double(T.CoverageProportion(hit));
                available=available(isfinite(available));
                if ~isempty(available),values(q)=available(1);end
            end
        end
        handles=bar(1:n,values,0.72,'FaceColor','flat');
        handles.CData=colors;
        for q=1:n
            if isfinite(values(q))
                text(q,values(q),sprintf(' %d/%d',round(values(q)*counts(q)), ...
                    counts(q)),'HorizontalAlignment','center', ...
                    'VerticalAlignment','bottom');
            elseif ~ismember(q,fixedAt)
                text(q,0.03,'metric NA / N=0','Rotation',90, ...
                    'HorizontalAlignment','left','Color',[0.45 0.45 0.45]);
            end
        end
        ylim([0 1.08]);xlim([0.5 n+0.5]);xticks(1:n);
        xticklabels(cellstr([members.tick]));xtickangle(18);
        ylabel(sprintf('%d%% truth-inclusion proportion',coveragePercent));
        title(parameters(p),'Interpreter','none');grid on;
        label_fixed(fixedAt);
    end
    sgtitle(sprintf('%s (exact matched N = %d)',titleText,matchedN), ...
        'Interpreter','tex');
    row=plotting.export_saved_figure(fig,cfg,'inversion/conditional', ...
        name,sources,'publication',struct('Scenario',char(scenario)));
end

function row=pair_figure(cfg,T,sources,members,parameters,scenario)
%PAIR_FIGURE A condition against the reference: spread, recovery error and truth inclusion per parameter.
    codes=[members.savedCode];shown=[members.code];
    metrics=["NormalizedPosteriorSD", ...
        "PosteriorMedianNormalizedRecoveryError","Covered50","Covered95"];
    labels={'Normalized posterior SD','Median normalized recovery error', ...
        '50% truth-inclusion proportion','95% truth-inclusion proportion'};
    P=numel(parameters);
    [~,parameterIndices]=ismember(parameters,string(cfg.paramNames));
    x=reshape([1;2]+3*(0:P-1),1,[]);
    xlabels=reshape([parameters+" "+shown(1);parameters+" "+shown(2)],1,[]);
    colors=[0.18 0.47 0.75;0.84 0.33 0.20];
    caseIDs=unique(double(T.CaseID(T.IncludedInMatchedCohort)),'stable');
    % Positions of a parameter that the condition fixes (no posterior there).
    fixedAt=[];
    for p=1:P
        if ismember(parameterIndices(p),members(2).fixedIndices),fixedAt(end+1)=x(2*p);end %#ok<AGROW>
    end
    fig=figure('Position',[20 40 1300 800]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
    for m=1:4
        nexttile;hold on;metricRows=T.Metric==metrics(m);
        if m<3
            for p=1:P
                for c=1:numel(caseIDs)
                    values=nan(1,2);
                    for q=1:2
                        hit=metricRows&T.Parameter==parameters(p)& ...
                            T.ConditionCode==codes(q)& ...
                            double(T.CaseID)==caseIDs(c)&T.MetricAvailable;
                        if nnz(hit)==1,values(q)=double(T.MetricValue(hit));end
                    end
                    if all(isfinite(values))
                        positions=x((p-1)*2+(1:2));
                        plot(positions,values,'-','Color',[0.78 0.78 0.78], ...
                            'LineWidth',0.65);
                    end
                end
            end
        end
        for p=1:P
            for q=1:2
                index=(p-1)*2+q;
                hit=metricRows&T.Parameter==parameters(p)& ...
                    T.ConditionCode==codes(q)&T.MetricAvailable;
                values=double(T.MetricValue(hit));
                if isempty(values),continue;end
                if m>=3
                    center=mean(values~=0);
                    bar(x(index),center,0.72,'FaceColor',colors(q,:));
                    text(x(index),center,sprintf(' %d/%d',sum(values~=0), ...
                        numel(values)),'HorizontalAlignment','center', ...
                        'VerticalAlignment','bottom');
                else
                    scatter(repmat(x(index),numel(values),1),values,18, ...
                        repmat(colors(q,:),numel(values),1),'filled', ...
                        'MarkerFaceAlpha',0.58);
                    quartiles=quantile(values,[0.25 0.50 0.75]);
                    errorbar(x(index),quartiles(2), ...
                        quartiles(2)-quartiles(1),quartiles(3)-quartiles(2), ...
                        'o','Color',colors(q,:),'MarkerFaceColor',colors(q,:), ...
                        'LineWidth',2,'CapSize',12);
                end
            end
        end
        xlim([0.3 3*P-0.3]);xticks(x);xticklabels(xlabels);xtickangle(22);
        ylabel(labels{m});grid on;
        if m>=3,ylim([0 1.08]);end
        label_fixed(fixedAt);
    end
    sgtitle(sprintf('%s: all-free %s versus %s-fixed %s (exact matched N = %d)', ...
        char(scenario),shown(1),strjoin(members(2).fixedNames,'-and-'),shown(2), ...
        numel(caseIDs)),'Interpreter','none');
    row=plotting.export_saved_figure(fig,cfg,'inversion/conditional', ...
        char(pair_name(scenario,members)),sources,'publication', ...
        struct('Scenario',char(scenario),'Condition',[members.id]));
end

function [manifest,statusTable]=selected_overlays( ...
        cfg,comparison,caseIDs,commonSources,conditions,palette,parameters)
    scenarios=reshape(unique(string(comparison.Scenario),'stable'),1,[]);
    % Per scenario: the reference and the conditions that ran in it.
    conditionSets=cell(1,numel(scenarios));
    for s=1:numel(scenarios)
        ran=unique(string(comparison.ConditionCode(string(comparison.Scenario)==scenarios(s)& ...
            as_logical(comparison.Scheduled))));
        conditionSets{s}=conditions([conditions.reference]| ...
            ismember([conditions.savedCode],ran));
    end
    records={};caseArtifacts=cell(numel(caseIDs),numel(scenarios));
    for c=1:numel(caseIDs)
        for s=1:numel(scenarios)
            members=conditionSets{s};artifacts=cell(1,numel(members));
            loaded=false(1,numel(members));fallback=false(1,numel(members));
            for q=1:numel(members)
                code=members(q).savedCode;
                cellRows=comparison.CaseID==caseIDs(c)& ...
                    string(comparison.Scenario)==scenarios(s)& ...
                    string(comparison.ConditionCode)==code;
                conditionIDs=unique(string(comparison.ConditionID(cellRows)));
                conditionIDs=conditionIDs(strlength(conditionIDs)>0);
                conditionID="";
                if isscalar(conditionIDs),conditionID=conditionIDs;end
                scheduled=any(as_logical(comparison.Scheduled(cellRows)));
                recorded=any(as_logical(comparison.ArtifactLoaded(cellRows)));
                attempted=any(cellRows)&&scheduled&&recorded;
                state="not_loaded";
                posterior="";certification="";
                if ~any(cellRows)
                    reason="comparison_row_missing";
                elseif ~scheduled
                    reason="not_scheduled";
                elseif ~recorded
                    reason=first_nonempty(string(comparison.FailureReason(cellRows)), ...
                        "saved_artifact_unavailable");
                else
                    record=struct('caseID',caseIDs(c), ...
                        'scenario',char(scenarios(s)),'design','all_six', ...
                        'conditionCode',char(code), ...
                        'conditionID',char(conditionID));
                    if members(q).reference
                        [artifact,status]=recovery.load_posterior_provider(cfg,record);
                    else
                        [artifact,status]= ...
                            recovery.load_conditional_provider(cfg,record);
                    end
                    state=string(status.state);reason=string(status.reason);
                    loaded(q)=logical(status.loaded);
                    if loaded(q)
                        artifacts{q}=artifact;
                        fallback(q)=~logical(status.certified);
                        posterior=run_relative( ...
                            artifact.paths.posteriorPath,cfg);
                        certification=run_relative( ...
                            recovery.provider_evidence_path(artifact),cfg);
                    end
                end
                records{end+1}=table(caseIDs(c),scenarios(s),code, ...
                    conditionID,scheduled,recorded,attempted,loaded(q), ...
                    state,reason,posterior,certification, ...
                    'VariableNames',{'CaseID','Scenario','ConditionCode', ...
                    'ConditionID','Scheduled','ComparisonArtifactLoaded', ...
                    'LoaderAttempted','LoaderLoaded','LoaderState','Reason', ...
                    'PosteriorPath','CertificationPath'}); %#ok<AGROW>
            end
            caseArtifacts{c,s}=struct('conditions',members, ...
                'artifacts',{artifacts},'loaded',loaded,'fallback',fallback);
        end
    end
    if isempty(records)
        statusTable=empty_selected_status();
    else
        statusTable=vertcat(records{:});
    end

    parts={};
    for c=1:numel(caseIDs)
        anyLoaded=any(cellfun(@(E) any(E.loaded),caseArtifacts(c,:)));
        if ~anyLoaded,continue;end
        sources=commonSources;
        for s=1:numel(scenarios)
            evidence=caseArtifacts{c,s};
            for q=find(evidence.loaded)
                artifact=evidence.artifacts{q};
                sources=[sources {artifact.paths.posteriorPath, ...
                    recovery.provider_evidence_path(artifact)}]; %#ok<AGROW>
            end
        end
        parts{end+1}=selected_case_figure(cfg,caseIDs(c),caseArtifacts(c,:), ...
            sources,scenarios,palette,parameters); %#ok<AGROW>
    end
    manifest=combine(parts);
end

function row=selected_case_figure(cfg,caseID,evidence,sources,scenarios,palette,parameters)
    [~,parameterIndices]=ismember(parameters,string(cfg.paramNames));
    % The conditions with a curve in some panel (a condition that fixes a
    % panel's parameter has none there): the legend names every one.
    drawn=[];
    for s=1:numel(scenarios)
        E=evidence{s};
        for q=find(E.loaded)
            if any(~ismember(parameterIndices,E.conditions(q).fixedIndices))&& ...
                    (isempty(drawn)||~ismember(E.conditions(q).code,[drawn.code]))
                if isempty(drawn),drawn=E.conditions(q);else,drawn(end+1)=E.conditions(q);end %#ok<AGROW>
            end
        end
    end
    truth=[];
    fig=figure('Position',[30 40 1220 760]);
    tiledlayout(numel(scenarios),numel(parameters),'Padding','compact','TileSpacing','compact');
    summaries={};panelIndex=0;
    for s=1:numel(scenarios)
        E=evidence{s};
        for p=1:numel(parameters)
            panelIndex=panelIndex+1;
            nexttile;hold on;bounds=double(cfg.paramBounds(parameterIndices(p),:));
            handles=gobjects(0);labels=strings(0);
            estimatorHandles=gobjects(0);
            intervalEstimates=cell(1,numel(E.conditions));
            intervalColors=cell(1,numel(E.conditions));
            for q=1:numel(E.conditions)
                if ~E.loaded(q),continue;end
                artifact=E.artifacts{q};
                oneTruth=double(artifact.truth(:));
                if isempty(truth),truth=oneTruth;else
                    assert(max(abs(oneTruth-truth))<=1e-10* ...
                        max(1,max(abs(truth))), ...
                        'plotting:saved_conditional_inversion_figures:TruthMismatch', ...
                        ['The saved conditional posteriors of one case disagree on its true ' ...
                         'parameters; rerun the step ''conditional_inversion''.']);
                end
                % A parameter fixed at the truth has no posterior: no curve.
                if ismember(parameterIndices(p),E.conditions(q).fixedIndices)
                    continue;
                end
                draws=free_parameter_draws( ...
                    artifact,E.conditions(q).reference,parameterIndices(p));
                color=palette(E.conditions(q).rank,:);
                [estimate,oneHandles]=plotting.render_posterior_marginal( ...
                    draws,bounds,'LineWidth',1.8, ...
                    'Color',color, ...
                    'DisplayName',E.conditions(q).code);
                interval=equal_tailed_intervals(draws, ...
                    oneTruth(parameterIndices(p)));
                intervalEstimates{q}=interval;
                intervalColors{q}=color;
                handles(end+1)=oneHandles.density; %#ok<AGROW>
                labels(end+1)=E.conditions(q).code; %#ok<AGROW>
                if isempty(estimatorHandles)
                    estimatorHandles=[oneHandles.mean oneHandles.median ...
                        oneHandles.mode];
                else
                    set([oneHandles.mean oneHandles.median oneHandles.mode], ...
                        'HandleVisibility','off');
                end
                series=scenarios(s)+"/"+E.conditions(q).code;
                summaryRow=plotting.posterior_marginal_summary_row( ...
                    estimate,series,parameters(p), ...
                    oneTruth(parameterIndices(p)));
                summaryRow.CI025Physical=interval.q025;
                summaryRow.CI25Physical=interval.q25;
                summaryRow.CI75Physical=interval.q75;
                summaryRow.CI975Physical=interval.q975;
                summaryRow.CI50WidthPhysical=interval.q75-interval.q25;
                summaryRow.CI95WidthPhysical=interval.q975-interval.q025;
                summaryRow.Covered50=interval.covered50;
                summaryRow.Covered95=interval.covered95;
                summaries{end+1}=summaryRow; %#ok<AGROW>
            end
            intervalHandles=render_equal_tailed_interval_bars( ...
                intervalEstimates,intervalColors);
            if ~isempty(truth)
                truthHandle=xline(truth(parameterIndices(p)),'k--', ...
                    'LineWidth',1.5,'DisplayName','synthetic truth');
            end
            xlabel(parameters(p),'Interpreter','none');ylabel('posterior density');
            title(scenarios(s),'Interpreter','none');xlim(bounds);grid on;
            if ~isempty(handles)&&panelIndex==1
                [handles,labels]=with_drawn_conditions(handles,labels,drawn,palette);
                legend([handles estimatorHandles truthHandle intervalHandles], ...
                    [cellstr(labels(:));{'posterior mean'; ...
                    'posterior median';'marginal mode';'synthetic truth'; ...
                    '95% equal-tailed interval'; ...
                    '50% equal-tailed interval'}], ...
                    'Location','southoutside','NumColumns',4, ...
                    'Interpreter','none');
            elseif ~isempty(handles)
                set([handles estimatorHandles truthHandle intervalHandles], ...
                    'HandleVisibility','off');
            else
                text(mean(bounds),0,'No saved posterior', ...
                    'HorizontalAlignment','center');
            end
        end
    end
    fallbacks=strings(0);
    for s=1:numel(scenarios)
        fallbacks=[fallbacks scenarios(s)+"/"+[evidence{s}.conditions(evidence{s}.fallback).code]]; %#ok<AGROW>
    end
    if isempty(fallbacks),fallbacks="none";end
    sgtitle(sprintf(['Case %d: weak-parameter conditional posterior overlays ' ...
        '(each curve is one unpooled posterior; healthy fallback: %s)'],caseID, ...
        strjoin(fallbacks,', ')),'Interpreter','none');
    % A per-case output: cases/case_<id>/conditional_inversion/selected_posteriors.
    name='selected_posteriors';
    plotting.write_posterior_marginal_summary(cfg,'case/conditional_inversion', ...
        name,vertcat(summaries{:}),sources,'',struct('CaseID',caseID));
    row=plotting.export_saved_figure(fig,cfg,'case/conditional_inversion', ...
        name,sources,'publication',struct('CaseID',caseID));
end

function [handles,labels]=with_drawn_conditions(handles,labels,drawn,palette)
%WITH_DRAWN_CONDITIONS The legend entries of every drawn condition, in the table's order.
%   A condition without a curve in this panel (it fixes the panel's
%   parameter) gets an empty line of its colour.
    ranks=zeros(1,numel(labels));
    for k=1:numel(labels)
        ranks(k)=drawn([drawn.code]==labels(k)).rank;
    end
    for c=drawn(~ismember([drawn.code],labels))
        handles(end+1)=plot(NaN,NaN,'-','LineWidth',1.8,'Color',palette(c.rank,:), ...
            'DisplayName',c.code); %#ok<AGROW>
        labels(end+1)=c.code; %#ok<AGROW>
        ranks(end+1)=c.rank; %#ok<AGROW>
    end
    [~,order]=sort(ranks);
    handles=handles(order);labels=labels(order);
end

function interval=equal_tailed_intervals(draws,truth)
    values=double(draws(:));values=values(isfinite(values));
    assert(~isempty(values), ...
        'plotting:saved_conditional_inversion_figures:IntervalDraws', ...
        'A conditional interval requires finite saved posterior draws.');
    q=quantile(values,[0.025 0.25 0.75 0.975]);
    interval=struct('q025',q(1),'q25',q(2),'q75',q(3),'q975',q(4), ...
        'median',median(values), ...
        'covered50',double(truth>=q(2)&&truth<=q(3)), ...
        'covered95',double(truth>=q(1)&&truth<=q(4)));
end

function handles=render_equal_tailed_interval_bars(estimates,colors)
    handles=gobjects(0);available=find(~cellfun(@isempty,estimates));
    if isempty(available),return;end
    limits=ylim;maximum=max(limits(2),eps);
    for rank=1:numel(available)
        index=available(rank);interval=estimates{index};color=colors{index};
        level=maximum*(0.035+0.04*(rank-1));
        lightColor=0.68+0.32*reshape(double(color),1,[]);
        outer=plot([interval.q025 interval.q975],[level level],'-', ...
            'Color',lightColor,'LineWidth',1.25, ...
            'DisplayName','95% equal-tailed interval');
        inner=plot([interval.q25 interval.q75],[level level],'-', ...
            'Color',color,'LineWidth',4.0, ...
            'DisplayName','50% equal-tailed interval');
        plot(interval.median,level,'o','Color',color, ...
            'MarkerFaceColor',color,'MarkerSize',4.5,'LineWidth',0.8, ...
            'HandleVisibility','off');
        if rank==1
            handles=[outer inner];
        else
            set([outer inner],'HandleVisibility','off');
        end
    end
end

function draws=free_parameter_draws(artifact,reference,parameterIndex)
% Fixed-to-truth reconstruction columns are never presented as posteriors.
    if reference
        assert(isfield(artifact,'drawsPhysical')&& ...
            size(artifact.drawsPhysical,2)==4, ...
            'plotting:saved_conditional_inversion_figures:CanonicalDraws', ...
            ['The saved condition-A posterior lacks its four-parameter draws ' ...
             '(drawsPhysical); rerun the step ''conditional_inversion''.']);
        draws=double(artifact.drawsPhysical(:,parameterIndex));
        return;
    end
    required={'drawsFree','freeParameterIndices','fixedParameterIndices', ...
        'parameterRoles'};
    assert(all(isfield(artifact,required)), ...
        'plotting:saved_conditional_inversion_figures:ConditionalDrawSchema', ...
        'Conditional posterior lacks explicit free/fixed coordinate roles.');
    free=reshape(double(artifact.freeParameterIndices),1,[]);
    fixed=reshape(double(artifact.fixedParameterIndices),1,[]);
    assert(isempty(intersect(free,fixed))&& ...
        isequal(sort([free fixed]),1:4)&& ...
        string(artifact.parameterRoles(parameterIndex))=="FREE", ...
        'plotting:saved_conditional_inversion_figures:FixedCoordinate', ...
        'A fixed-to-truth coordinate cannot be plotted as a posterior marginal.');
    location=find(free==parameterIndex);
    assert(isscalar(location)&&size(artifact.drawsFree,2)==numel(free), ...
        'plotting:saved_conditional_inversion_figures:FreeCoordinate', ...
        ['The free draws of a saved conditional posterior do not match its free ' ...
         'parameters; rerun the step ''conditional_inversion''.']);
    draws=double(artifact.drawsFree(:,location));
end

function pathValue=configured_file(cfg,name,fallback)
    pathValue=fallback;
    if isfield(cfg,'files')&&isfield(cfg.files,name)
        pathValue=cfg.files.(name);
    end
end

function value=as_logical(input)
    if islogical(input),value=input;return;end
    if isnumeric(input),value=input~=0;return;end
    value=ismember(lower(string(input)),["true" "1"]);
end

function value=first_nonempty(values,fallback)
    values=values(strlength(values)>0);
    if isempty(values),value=string(fallback);else,value=values(1);end
end

function relative=run_relative(pathValue,cfg)
%RUN_RELATIVE A file of the results, relative to their folder; a shipped canonical cell, relative to the repository.
%   The canonical cells of a rerun's conditional inversion that took them
%   from the shipped results (CFG.layout.canonicalResults) are named by
%   their path in the repository (thesis_results/...).
    pathValue=utils.absolute_path(pathValue);
    roots={utils.absolute_path(cfg.paths.runRoot)};
    if isfield(cfg,'layout')&&isfield(cfg.layout,'canonicalResults')&& ...
            ~isempty(cfg.layout.canonicalResults)
        roots{end+1}=fileparts(utils.absolute_path(cfg.layout.canonicalResults));
    end
    for k=1:numel(roots)
        prefix=[roots{k} filesep];
        if ispc
            contained=startsWith(lower(pathValue),lower(prefix));
        else
            contained=startsWith(pathValue,prefix);
        end
        if contained
            relative=string(strrep(pathValue(numel(prefix)+1:end),'\','/'));
            return
        end
    end
    error('plotting:saved_conditional_inversion_figures:SourceBoundary', ...
        'The file %s lies outside the folder %s.',pathValue,roots{1});
end

function T=status_row(analysis,status,matchedN,expectedN,reason)
    T=table(string(analysis),string(status),double(matchedN), ...
        double(expectedN),string(reason), ...
        'VariableNames',{'Analysis','Status','MatchedN','ExpectedN','Reason'});
end

function T=empty_selected_status()
    T=table('Size',[0 12],'VariableTypes', ...
        {'double','string','string','string','logical','logical','logical', ...
        'logical','string','string','string','string'}, ...
        'VariableNames',{'CaseID','Scenario','ConditionCode','ConditionID', ...
        'Scheduled','ComparisonArtifactLoaded','LoaderAttempted','LoaderLoaded', ...
        'LoaderState','Reason','PosteriorPath','CertificationPath'});
end

function T=combine(parts)
    if isempty(parts),T=empty_manifest();else,T=vertcat(parts{:});end
end

function T=empty_manifest()
    T=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5), ...
        'VariableNames',{'Category','Figure','RelativePath','Scope', ...
        'SourceArtifacts'});
end
