function manifest = saved_posterior_eigendecomposition_figures(cfg,options)
%SAVED_POSTERIOR_EIGENDECOMPOSITION_FIGURES The figures of the posterior-covariance eigendecomposition.
%   MANIFEST = plotting.saved_posterior_eigendecomposition_figures(CFG,
%   OPTIONS) draws, per scenario, from the saved eigensystem tables of the
%   recovery: the consensus axis loadings, the directional contraction by
%   case, the similarity of the sloppiest axes and directions across cases
%   and the replicate eigensystem stability, and returns the manifest.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    if ~analysis_enabled(cfg)
        manifest=empty_manifest();
        return
    end
    sourceRoot=eigensystem_root(cfg);
    outputRoot=fullfile(cfg.paths.stage07,'identifiability', ...
        'posterior_eigendecomposition');
    if ~isfolder(outputRoot),mkdir(outputRoot);end
    paths=struct( ...
        'directions',fullfile(sourceRoot,'posterior_eigendirections.csv'), ...
        'availability',fullfile(sourceRoot,'availability.csv'), ...
        'consensus',fullfile(sourceRoot,'consensus_axes.csv'), ...
        'crossScenario',fullfile(sourceRoot,'cross_scenario_comparison.csv'), ...
        'replicate',fullfile(sourceRoot, ...
            'replicate_eigensystem_stability.csv'), ...
        'jointFull',fullfile(sourceRoot, ...
            'joint_geometry_replicate_full_4d.csv'), ...
        'jointWeak',fullfile(sourceRoot, ...
            'joint_geometry_replicate_weak_pair.csv'));
    statusParts={};parts={};
    if ~isfile(paths.directions)||~isfile(paths.availability)
        missing=strings(0,1);
        if ~isfile(paths.directions),missing(end+1)="posterior_eigendirections";end
        if ~isfile(paths.availability),missing(end+1)="availability";end
        statusParts{end+1}=status_row('required_tables','not_generated', ...
            strjoin(missing,'|'),0);
        write_status(outputRoot,statusParts);
        manifest=empty_manifest();
        return
    end

    directions=readtable(paths.directions,'Delimiter',',','TextType','string', ...
        'VariableNamingRule','preserve');
    availability=readtable(paths.availability,'Delimiter',',','TextType','string', ...
        'VariableNamingRule','preserve');
    validate_direction_schema(cfg,directions);
    validate_availability_schema(cfg,availability);
    if ismember('EigensystemValid',directions.Properties.VariableNames)
        directions=directions(to_logical(directions.EigensystemValid),:);
    else
        directions=directions(isfinite(double(directions.Eigenvalue)),:);
    end
    scenarios=analysis_scenarios(cfg);
    caseOrder=analysis_case_ids(cfg);

    if isfile(paths.jointFull)&&isfile(paths.jointWeak)
        jointFull=readtable(paths.jointFull,'Delimiter',',','TextType','string', ...
            'VariableNamingRule','preserve');
        jointWeak=readtable(paths.jointWeak,'Delimiter',',','TextType','string', ...
            'VariableNamingRule','preserve');
        validate_joint_geometry_schema(cfg,jointFull,'full_4d');
        validate_joint_geometry_schema(cfg,jointWeak,'weak_pair');
        parts{end+1}=joint_lambda_figure(cfg,jointFull,jointWeak, ...
            paths.jointFull,paths.jointWeak);
        parts{end+1}=joint_angle_gap_figure(cfg,jointFull,jointWeak, ...
            paths.jointFull,paths.jointWeak);
        statusParts{end+1}=status_row('joint_geometry_replicate_figures', ...
            'generated','',2);
    else
        statusParts{end+1}=status_row('joint_geometry_replicate_figures', ...
            'not_generated','joint_geometry_tables_missing',0);
    end

    parts{end+1}=availability_figure(cfg,availability,scenarios,caseOrder, ...
        paths.availability);
    statusParts{end+1}=status_row('availability','generated','', ...
        height(availability));
    for s=1:numel(scenarios)
        scenario=scenarios(s);
        scenarioRows=string(directions.Scenario)==scenario;
        if ~any(scenarioRows)
            statusParts{end+1}=status_row(scenario+'_directional_contraction', ...
                'not_generated','no_valid_direction_rows',0); %#ok<AGROW>
            continue
        end
        one=directions(scenarioRows,:);
        parts{end+1}=contraction_figure(cfg,one,scenario,caseOrder, ...
            paths.directions); %#ok<AGROW>
        statusParts{end+1}=status_row(scenario+'_directional_contraction', ...
            'generated','',numel(unique(double(one.CaseID)))); %#ok<AGROW>
    end

    mode=lower(char(string(options.Mode)));
    if ~strcmp(mode,'aggregate')
        for s=1:numel(scenarios)
            scenario=scenarios(s);
            scenarioRows=string(directions.Scenario)==scenario;
            if ~any(scenarioRows),continue;end
            one=directions(scenarioRows,:);
            parts{end+1}=loading_figure(cfg,one,scenario,1,caseOrder, ...
                paths.directions); %#ok<AGROW>
            parts{end+1}=loading_figure(cfg,one,scenario,4,caseOrder, ...
                paths.directions); %#ok<AGROW>
            for axisName=["tightest_axis" "sloppiest_axis"]
                similarityPath=fullfile(sourceRoot,'similarity', ...
                    char(scenario+'_'+axisName+'_similarity.csv'));
                [row,generated,reason]=similarity_figure(cfg,similarityPath, ...
                    scenario,axisName,caseOrder,'publication');
                if generated,parts{end+1}=row;end %#ok<AGROW>
                statusParts{end+1}=status_row( ...
                    scenario+'_'+axisName+'_similarity', ...
                    generated_text(generated),reason,double(generated)); ...
                    %#ok<AGROW>
            end
            if isfile(paths.consensus)
                consensus=readtable(paths.consensus,'Delimiter',',','TextType','string', ...
                    'VariableNamingRule','preserve');
                [row,generated,reason]=consensus_figure(cfg,consensus, ...
                    scenario,paths.consensus);
                if generated,parts{end+1}=row;end %#ok<AGROW>
                statusParts{end+1}=status_row( ...
                    scenario+'_consensus_axes',generated_text(generated), ...
                    reason,double(generated)); %#ok<AGROW>
            else
                statusParts{end+1}=status_row( ...
                    scenario+'_consensus_axes','not_generated', ...
                    'consensus_axes_table_missing',0); %#ok<AGROW>
            end
        end
        if isfile(paths.crossScenario)
            cross=readtable(paths.crossScenario,'Delimiter',',','TextType','string', ...
                'VariableNamingRule','preserve');
            [row,generated,reason]=cross_scenario_figure( ...
                cfg,cross,caseOrder,paths.crossScenario);
            if generated,parts{end+1}=row;end
            statusParts{end+1}=status_row('cross_scenario_comparison', ...
                generated_text(generated),reason,double(generated));
        else
            statusParts{end+1}=status_row('cross_scenario_comparison', ...
                'not_generated','cross_scenario_table_missing',0);
        end
    end

    if strcmp(mode,'full')
        for s=1:numel(scenarios)
            scenario=scenarios(s);
            for subspace=["tight2d" "sloppy2d"]
                similarityPath=fullfile(sourceRoot,'similarity', ...
                    char(scenario+'_'+subspace+'_similarity.csv'));
                [row,generated,reason]=similarity_figure(cfg,similarityPath, ...
                    scenario,subspace,caseOrder,'diagnostic');
                if generated,parts{end+1}=row;end %#ok<AGROW>
                statusParts{end+1}=status_row( ...
                    scenario+'_'+subspace+'_similarity', ...
                    generated_text(generated),reason,double(generated)); ...
                    %#ok<AGROW>
            end
        end
        if isfile(paths.replicate)
            replicate=readtable(paths.replicate,'Delimiter',',','TextType','string', ...
                'VariableNamingRule','preserve');
            for s=1:numel(scenarios)
                [row,generated,reason]=replicate_figure(cfg,replicate, ...
                    scenarios(s),caseOrder,paths.replicate);
                if generated,parts{end+1}=row;end %#ok<AGROW>
                statusParts{end+1}=status_row( ...
                    scenarios(s)+'_replicate_stability', ...
                    generated_text(generated),reason,double(generated)); ...
                    %#ok<AGROW>
            end
        else
            statusParts{end+1}=status_row('replicate_stability', ...
                'not_generated','replicate_stability_table_missing',0);
        end
    end
    write_status(outputRoot,statusParts);
    manifest=combine(parts);
end

function row=availability_figure(cfg,T,scenarios,caseOrder,source)
    valid=to_logical(T.EigensystemValid);
    available=to_logical(T.CertifiedPosteriorAvailable);
    included=to_logical(T.IncludedInCrossScenarioComparison);
    values=zeros(numel(scenarios),numel(caseOrder));
    for s=1:numel(scenarios)
        for c=1:numel(caseOrder)
            hit=string(T.Scenario)==scenarios(s)&double(T.CaseID)==caseOrder(c);
            if nnz(hit)~=1,continue;end
            values(s,c)=double(available(hit))+double(valid(hit))+ ...
                double(included(hit));
        end
    end
    fig=figure('Position',[40 80 1280 360]);imagesc(values,[0 3]);
    map=[0.80 0.80 0.80;0.95 0.64 0.18;0.22 0.60 0.78;0.10 0.55 0.30];
    colormap(fig,map);bar=colorbar;bar.Ticks=0:3;
    bar.TickLabels={'missing','posterior only','valid eigensystem','matched valid'};
    xticks(1:numel(caseOrder));xticklabels(string(caseOrder));xtickangle(35);
    yticks(1:numel(scenarios));yticklabels(scenarios);
    xlabel('CaseID (canonical order)');title( ...
        'Posterior eigensystem availability and cross-scenario matching');
    row=plotting.export_saved_figure(fig,cfg, ...
        'identifiability/posterior_eigendecomposition', ...
        'posterior_eigensystem_availability',{source},'aggregate', ...
        struct('Scenario',["measurement_plus_gp" "gp_only"],'Design','all_six'));
end

function row=contraction_figure(cfg,T,scenario,caseOrder,source)
    labels=direction_labels();colors=lines(4);
    fig=figure('Position',[40 80 1060 530]);hold on;
    for c=1:numel(caseOrder)
        values=nan(1,4);
        for rank=1:4
            hit=double(T.CaseID)==caseOrder(c)& ...
                double(T.DirectionRank)==rank;
            if nnz(hit)==1
                values(rank)=double(T.DirectionalContraction(hit));
            end
        end
        present=isfinite(values);
        if any(present)
            plot(find(present),values(present),'-','Color',[0.80 0.80 0.80], ...
                'LineWidth',0.65);
        end
    end
    for rank=1:4
        hit=double(T.DirectionRank)==rank;
        values=double(T.DirectionalContraction(hit));
        values=values(isfinite(values));
        if isempty(values),continue;end
        offsets=linspace(-0.16,0.16,numel(values)).';
        scatter(rank+offsets,values,20, ...
            repmat(colors(rank,:),numel(values),1),'filled', ...
            'MarkerFaceAlpha',0.58);
        quartiles=quantile(values,[0.25 0.50 0.75]);
        errorbar(rank,quartiles(2),quartiles(2)-quartiles(1), ...
            quartiles(3)-quartiles(2),'o','Color',colors(rank,:), ...
            'MarkerFaceColor',colors(rank,:),'LineWidth',2.1,'CapSize',14);
    end
    xlim([0.5 4.5]);xticks(1:4);xticklabels(labels);xtickangle(18);
    ylabel('Directional contraction, 1 - sqrt(eigenvalue)');grid on;
    title(sprintf('%s: prior-standardized posterior directions (N = %d)', ...
        strrep(char(scenario),'_',' '),numel(unique(double(T.CaseID)))), ...
        'Interpreter','none');
    row=plotting.export_saved_figure(fig,cfg, ...
        'identifiability/posterior_eigendecomposition', ...
        char(scenario+'_directional_contraction_by_case'),{source}, ...
        'publication',struct('Scenario',scenario,'Design','all_six'));
end

function row=loading_figure(cfg,T,scenario,rank,caseOrder,source)
    parameterNames=canonical_parameters(cfg);
    loadingNames="Loading_"+parameterNames;
    present=intersect(caseOrder,unique(double( ...
        T.CaseID(double(T.DirectionRank)==rank)),'stable'),'stable');
    values=nan(numel(present),4);near=false(numel(present),1);
    for c=1:numel(present)
        hit=double(T.CaseID)==present(c)&double(T.DirectionRank)==rank;
        assert(nnz(hit)==1, ...
            'plotting:saved_posterior_eigendecomposition_figures:DirectionKey', ...
            ['The saved eigendirection table has %d rows for case %d and direction %d, ' ...
             'not one; rerun the step ''recovery''.'],nnz(hit),present(c),rank);
        for p=1:4,values(c,p)=double(T.(loadingNames(p))(hit));end
        if rank==1
            near(c)=to_logical(T.NearDegenerateAbove(hit));
        else
            near(c)=to_logical(T.NearDegenerateBelow(hit));
        end
    end
    fig=figure('Position',[40 50 1040 760]);
    layout=tiledlayout(2,1,'Padding','compact','TileSpacing','compact');
    first=nexttile(layout,1);imagesc(first,values,[-1 1]);
    colormap(first,blue_white_red());colorbar(first);
    xticks(first,1:4);xticklabels(first,parameterNames);xtickangle(first,20);
    yticks(first,1:numel(present));yticklabels(first,string(present));
    ylabel(first,'CaseID (canonical order)');
    axisLabel=direction_labels();
    title(first,sprintf('%s: %s sign-aligned standardized loadings', ...
        strrep(char(scenario),'_',' '),axisLabel{rank}),'Interpreter','none');
    second=nexttile(layout,2);imagesc(second,double(near).',[0 1]);
    colormap(second,[0.88 0.88 0.88;0.85 0.33 0.10]);
    xticks(second,1:numel(present));xticklabels(second,string(present));
    xtickangle(second,35);yticks(second,1);yticklabels(second, ...
        {'adjacent-gap warning'});xlabel(second,'CaseID');
    if rank==1,name='tightest_direction_loading_heatmap'; ...
    else,name='sloppiest_direction_loading_heatmap';end
    row=plotting.export_saved_figure(fig,cfg, ...
        'identifiability/posterior_eigendecomposition', ...
        char(scenario+'_'+name),{source},'publication',struct('Scenario',scenario,'Design','all_six'));
end

function [row,generated,reason]=similarity_figure( ...
        cfg,pathValue,scenario,kind,caseOrder,scope)
    row=empty_manifest();generated=false;reason="";
    if ~isfile(pathValue),reason="similarity_table_missing";return;end
    T=readtable(pathValue,'Delimiter',',','TextType','string','VariableNamingRule','preserve');
    [values,cases]=plotting.posterior_similarity_matrix(T,caseOrder);
    if isempty(cases),reason="no_similarity_rows";return;end
    fig=figure('Position',[50 50 900 760]);plotting.blank_missing(imagesc(values,[0 1]));
    axis image;colorbar;colormap(fig,parula(256));
    xticks(1:numel(cases));xticklabels(string(cases));xtickangle(40);
    yticks(1:numel(cases));yticklabels(string(cases));
    xlabel('CaseID');ylabel('CaseID');
    title(sprintf('%s: %s similarity',strrep(char(scenario),'_',' '), ...
        strrep(char(kind),'_',' ')),'Interpreter','none');
    row=plotting.export_saved_figure(fig,cfg, ...
        'identifiability/posterior_eigendecomposition', ...
        char(scenario+'_'+kind+'_similarity'),{pathValue},scope,struct('Scenario',scenario,'Design','all_six'));
    generated=true;
end

function [row,generated,reason]=consensus_figure(cfg,T,scenario,source)
    row=empty_manifest();generated=false;reason="";
    required=["Scenario" "AxisLabel" "DominantProjectorEigenvalue" ...
        "Loading_m3_f_RD" "Loading_m3_e_RD" ...
        "Loading_log10_k0_RD" "Loading_Thickness_RD"];
    if ~all(ismember(required,string(T.Properties.VariableNames)))
        reason="consensus_table_schema_mismatch";return
    end
    axesWanted=["tightest_axis" "sloppiest_axis"];
    one=T(string(T.Scenario)==scenario& ...
        ismember(string(T.AxisLabel),axesWanted),:);
    if height(one)~=2,reason="consensus_axes_unavailable";return;end
    [~,order]=ismember(axesWanted,string(one.AxisLabel));one=one(order,:);
    parameters=canonical_parameters(cfg);values=nan(4,2);
    for p=1:4,values(p,:)=double(one.("Loading_"+parameters(p))).';end
    concentrations=double(one.DominantProjectorEigenvalue);
    fig=figure('Position',[50 80 1050 510]);bar(values);
    xticks(1:4);xticklabels(parameters);xtickangle(20);
    ylabel('Sign-aligned prior-standardized loading');
    legend({'tightest axis','sloppiest axis'},'Location','southoutside', ...
        'Orientation','horizontal');
    title(sprintf(['%s: cohort consensus axes; projector concentrations ' ...
        '%.3f / %.3f'],strrep(char(scenario),'_',' '), ...
        concentrations(1),concentrations(2)),'Interpreter','none');
    row=plotting.export_saved_figure(fig,cfg, ...
        'identifiability/posterior_eigendecomposition', ...
        char(scenario+'_consensus_axis_loadings'),{source},'publication',struct('Scenario',scenario,'Design','all_six'));
    generated=true;
end

function [row,generated,reason]=cross_scenario_figure(cfg,T,caseOrder,source)
    row=empty_manifest();generated=false;reason="";
    required=["CaseID" "DirectionRank" ...
        "DirectionalContractionDifference" "AxisAlignment" ...
        "Tight2DSubspaceSimilarity" "Sloppy2DSubspaceSimilarity"];
    if ~all(ismember(required,string(T.Properties.VariableNames)))
        reason="cross_scenario_table_schema_mismatch";return
    end
    if ~ismember('Matched',T.Properties.VariableNames)
        reason="cross_scenario_matched_field_missing";return
    end
    T=T(to_logical(T.Matched),:);
    cases=intersect(caseOrder,unique(double(T.CaseID),'stable'),'stable');
    if isempty(cases),reason="zero_matched_cases";return;end
    fig=figure('Position',[20 50 1280 760]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
    nexttile;hold on;colors=lines(4);
    for rank=1:4
        hit=double(T.DirectionRank)==rank;
        values=double(T.DirectionalContractionDifference(hit));
        values=values(isfinite(values));
        scatter(repmat(rank,numel(values),1),values,20, ...
            repmat(colors(rank,:),numel(values),1),'filled', ...
            'MarkerFaceAlpha',0.6);
        if ~isempty(values)
            q=quantile(values,[0.25 0.50 0.75]);
            errorbar(rank,q(2),q(2)-q(1),q(3)-q(2),'o', ...
                'Color',colors(rank,:),'MarkerFaceColor',colors(rank,:), ...
                'LineWidth',2,'CapSize',12);
        end
    end
    yline(0,'k--');xticks(1:4);xticklabels(direction_labels());
    xtickangle(18);ylabel('\Delta contraction (measurement+GP - GP only)');
    title('Matched directional contraction differences');grid on;
    nexttile;axis_alignment_panel(T);
    nexttile;subspace_panel(T,cases);
    nexttile;axis off;text(0,0.80,sprintf('Exact matched CaseIDs: N = %d', ...
        numel(cases)),'FontWeight','bold');
    text(0,0.60,strjoin(string(cases),', '),'Interpreter','none');
    sgtitle('measurement_plus_gp versus gp_only posterior eigensystems', ...
        'Interpreter','none');
    row=plotting.export_saved_figure(fig,cfg, ...
        'identifiability/posterior_eigendecomposition', ...
        'matched_cross_scenario_eigensystem_comparison',{source},'publication', ...
        struct('Scenario',["measurement_plus_gp" "gp_only"],'Design','all_six'));
    generated=true;
end

function axis_alignment_panel(T)
    hold on;ranks=[1 4];labels={'tightest axis','sloppiest axis'};
    colors=lines(2);
    for i=1:2
        hit=double(T.DirectionRank)==ranks(i);
        values=double(T.AxisAlignment(hit));values=values(isfinite(values));
        scatter(repmat(i,numel(values),1),values,22, ...
            repmat(colors(i,:),numel(values),1),'filled', ...
            'MarkerFaceAlpha',0.62);
        if ~isempty(values)
            q=quantile(values,[0.25 0.50 0.75]);
            errorbar(i,q(2),q(2)-q(1),q(3)-q(2),'o', ...
                'Color',colors(i,:),'MarkerFaceColor',colors(i,:), ...
                'LineWidth',2,'CapSize',12);
        end
    end
    xlim([0.5 2.5]);ylim([0 1.05]);xticks(1:2);xticklabels(labels);
    ylabel('Sign-invariant axis alignment');title('Matched axis alignment');
    grid on;
end

function subspace_panel(T,cases)
    firstPerCase=false(height(T),1);
    for c=1:numel(cases)
        hit=find(double(T.CaseID)==cases(c),1);
        if ~isempty(hit),firstPerCase(hit)=true;end
    end
    tight=double(T.Tight2DSubspaceSimilarity(firstPerCase));
    sloppy=double(T.Sloppy2DSubspaceSimilarity(firstPerCase));
    values={tight,sloppy};hold on;colors=lines(2);
    for i=1:2
        one=values{i};one=one(isfinite(one));
        scatter(repmat(i,numel(one),1),one,22, ...
            repmat(colors(i,:),numel(one),1),'filled', ...
            'MarkerFaceAlpha',0.62);
        if ~isempty(one)
            q=quantile(one,[0.25 0.50 0.75]);
            errorbar(i,q(2),q(2)-q(1),q(3)-q(2),'o', ...
                'Color',colors(i,:),'MarkerFaceColor',colors(i,:), ...
                'LineWidth',2,'CapSize',12);
        end
    end
    xlim([0.5 2.5]);xticks(1:2);xticklabels({'tight 2-D','sloppy 2-D'});
    ylim([0 1.05]);
    ylabel('Projector similarity');title('Matched subspace similarity');grid on;
end

function [row,generated,reason]=replicate_figure( ...
        cfg,T,scenario,caseOrder,source)
    row=empty_manifest();generated=false;reason="";
    required=["Scenario" "CaseID" "DirectionRank" ...
        "RelativeEigenvalueDifference" "AxisAlignment" ...
        "Tight2DSubspaceSimilarity" "Sloppy2DSubspaceSimilarity" ...
        "Replicate2Available" "Replicate2EigensystemValid" "WarningStatus"];
    if ~all(ismember(required,string(T.Properties.VariableNames)))
        reason="replicate_table_schema_mismatch";return
    end
    one=T(string(T.Scenario)==scenario,:);
    if isempty(one),reason="scenario_rows_unavailable";return;end
    available=to_logical(one.Replicate2Available);
    replicateValid=to_logical(one.Replicate2EigensystemValid);
    comparable=available&replicateValid& ...
        isfinite(double(one.PrimaryEigenvalue))& ...
        isfinite(double(one.Replicate2Eigenvalue));
    fig=figure('Position',[20 50 1280 760]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
    nexttile;rank_scatter(one,comparable,'RelativeEigenvalueDifference', ...
        'Relative eigenvalue difference');
    nexttile;rank_scatter(one,comparable,'AxisAlignment', ...
        'Sign-invariant axis alignment');ylim([0 1.05]);
    nexttile;
    cases=intersect(caseOrder,unique(double(one.CaseID(comparable)),'stable'), ...
        'stable');subspace_panel(one(comparable,:),cases);
    nexttile;
    comparableCases=unique(double(one.CaseID(comparable)));
    unavailableCases=unique(double(one.CaseID(~available)));
    invalidCases=unique(double(one.CaseID(available&~replicateValid)));
    warningFlag=false(height(one),1);
    warningFlag(available)=~ismember(lower(string( ...
        one.WarningStatus(available))),["ok" "none" "pass" "" ...
        "available_no_configured_warning"]);
    warningCases=unique(double(one.CaseID(warningFlag)));
    bar([numel(comparableCases) numel(unavailableCases) ...
        numel(invalidCases) numel(warningCases)]);
    xticks(1:4);xticklabels({'comparable','unavailable','invalid','warning'});
    xtickangle(20);ylabel('CaseID count');title('Saved replicate-2 inventory');
    sgtitle(sprintf('%s: warning-only replicate eigensystem stability', ...
        strrep(char(scenario),'_',' ')),'Interpreter','none');
    row=plotting.export_saved_figure(fig,cfg, ...
        'identifiability/posterior_eigendecomposition', ...
        char(scenario+'_replicate_eigensystem_stability'),{source}, ...
        'diagnostic',struct('Scenario',scenario,'Design','all_six'));
    generated=true;
end

function validate_joint_geometry_schema(cfg,T,scope)
    required=["Scenario" "CaseID" "GeometryScope" ...
        "ReplicatePairAvailable" "AvailabilityReason" ...
        "LambdaMaxReplicate1" "LambdaMaxReplicate2" ...
        "LambdaMaxAbsoluteDifference" ...
        "SymmetricLambdaMaxRelativeDifference" ...
        "NormalizedCovarianceFrobeniusDifference" ...
        "LeadingEigenvectorAbsoluteAlignment" ...
        "LeadingEigenvectorAngleDegrees" "LeadingEigengapReplicate1" ...
        "LeadingEigengapReplicate2" "TraceReplicate1" ...
        "TraceReplicate2" "LogDeterminantReplicate1" ...
        "LogDeterminantReplicate2" "RetainedDrawCountReplicate1" ...
        "RetainedDrawCountReplicate2"];
    expected=numel(analysis_case_ids(cfg))*numel(analysis_scenarios(cfg));
    assert(all(ismember(required,string(T.Properties.VariableNames)))&& ...
        height(T)==expected&&all(string(T.GeometryScope)==string(scope)), ...
        'plotting:saved_posterior_eigendecomposition_figures:JointGeometrySchema', ...
        'A joint-geometry replicate table has an invalid saved schema.');
    keys=string(T.Scenario)+"|"+string(T.CaseID);
    assert(numel(unique(keys))==expected, ...
        'plotting:saved_posterior_eigendecomposition_figures:JointGeometryKeys', ...
        ['The saved joint-geometry table needs one row per scenario and case (%d); ' ...
         'it has %d distinct; rerun the step ''recovery''.'],expected,numel(unique(keys)));
end

function row=joint_lambda_figure(cfg,fullTable,weakTable,fullPath,weakPath)
    tables={fullTable,weakTable};labels={'full 4-D','weak pair'};
    scenarios=["measurement_plus_gp" "gp_only"];
    colors=[0.00 0.45 0.70;0.85 0.33 0.10];
    fig=figure('Position',[60 80 1040 470]);
    tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    for i=1:2
        nexttile;hold on;allValues=[];
        for s=1:2
            T=tables{i};hit=to_logical(T.ReplicatePairAvailable)& ...
                string(T.Scenario)==scenarios(s);
            x=double(T.LambdaMaxReplicate1(hit));
            y=double(T.LambdaMaxReplicate2(hit));
            valid=isfinite(x)&isfinite(y);x=x(valid);y=y(valid);
            scatter(x,y,30,repmat(colors(s,:),numel(x),1),'filled', ...
                'DisplayName',strrep(char(scenarios(s)),'_',' '));
            allValues=[allValues;x;y]; %#ok<AGROW>
        end
        if isempty(allValues)
            text(0.5,0.5,'No accepted replicate pairs', ...
                'HorizontalAlignment','center');axis off;
        else
            limits=equal_limits(allValues);plot(limits,limits,'k--', ...
                'DisplayName','equal \lambda_{max}');
            xlim(limits);ylim(limits);axis square;grid on;
            xlabel('\lambda_{max}, replicate 1');
            ylabel('\lambda_{max}, replicate 2');legend('Location','best');
        end
        title(labels{i});
    end
    sgtitle('Accepted-level joint geometry: factual replicate comparison');
    row=plotting.export_saved_figure(fig,cfg, ...
        'identifiability/posterior_eigendecomposition', ...
        'lambda_max_replicate_1_vs_replicate_2',{fullPath,weakPath}, ...
        'diagnostic',struct('Scenario',["measurement_plus_gp" "gp_only"],'Design','all_six'));
end

function row=joint_angle_gap_figure(cfg,fullTable,weakTable,fullPath,weakPath)
    tables={fullTable,weakTable};labels={'full 4-D','weak pair'};
    fig=figure('Position',[60 80 1040 470]);
    tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    for i=1:2
        nexttile;hold on;T=tables{i};
        available=to_logical(T.ReplicatePairAvailable);
        angle=double(T.LeadingEigenvectorAngleDegrees(available));
        gap1=double(T.LeadingEigengapReplicate1(available));
        gap2=double(T.LeadingEigengapReplicate2(available));
        valid1=isfinite(angle)&isfinite(gap1);
        valid2=isfinite(angle)&isfinite(gap2);
        if ~any(valid1)&&~any(valid2)
            text(0.5,0.5,'No accepted replicate pairs', ...
                'HorizontalAlignment','center');axis off;
        else
            scatter(gap1(valid1),angle(valid1),32,[0.00 0.45 0.70], ...
                'filled','DisplayName','replicate 1 eigengap');
            scatter(gap2(valid2),angle(valid2),38,[0.85 0.33 0.10], ...
                'x','LineWidth',1.2,'DisplayName','replicate 2 eigengap');
            xlabel('Leading eigengap, \lambda_{max}-\lambda_{next}');
            ylabel('Leading-eigenvector angle (degrees)');grid on;
            legend('Location','best');
        end
        title(labels{i});
    end
    sgtitle(['Principal-axis angle shown with both replicate eigengaps; ' ...
        'manual review evidence']);
    row=plotting.export_saved_figure(fig,cfg, ...
        'identifiability/posterior_eigendecomposition', ...
        'principal_angle_versus_leading_eigengap',{fullPath,weakPath}, ...
        'diagnostic',struct('Scenario',["measurement_plus_gp" "gp_only"],'Design','all_six'));
end

function limits=equal_limits(values)
    values=double(values(:));values=values(isfinite(values));
    low=min(values);high=max(values);
    if low==high
        pad=max(1,abs(low))*0.05;
    else
        pad=0.05*(high-low);
    end
    limits=[low-pad high+pad];
end

function rank_scatter(T,available,variable,yLabel)
    hold on;colors=lines(4);
    for rank=1:4
        hit=available&double(T.DirectionRank)==rank;
        values=double(T.(variable)(hit));values=values(isfinite(values));
        scatter(repmat(rank,numel(values),1),values,22, ...
            repmat(colors(rank,:),numel(values),1),'filled', ...
            'MarkerFaceAlpha',0.62);
    end
    xticks(1:4);xticklabels(direction_labels());xtickangle(18);
    ylabel(yLabel);grid on;
end

function validate_direction_schema(cfg,T)
    parameters=canonical_parameters(cfg);
    required=["Scenario" "CaseID" "Design" "DirectionRank" ...
        "DirectionLabel" "Eigenvalue" "DirectionalPosteriorSDRatio" ...
        "DirectionalContraction" "PosteriorVarianceFraction" ...
        "EigensystemValid" ...
        "SignFlipApplied" "GapBelow" "GapAbove" ...
        "NearDegenerateBelow" "NearDegenerateAbove" ...
        "CertifiedStepCount" "CertificationMechanism" ...
        "PosteriorArtifactReference" "Loading_"+parameters];
    assert(all(ismember(required,string(T.Properties.VariableNames))), ...
        'plotting:saved_posterior_eigendecomposition_figures:DirectionSchema', ...
        'posterior_eigendirections.csv does not satisfy the saved-table contract.');
    assert(all(string(T.Design)=="all_six")&& ...
        all(ismember(string(T.Scenario),analysis_scenarios(cfg)))&& ...
        all(ismember(double(T.CaseID),analysis_case_ids(cfg)))&& ...
        all(ismember(double(T.DirectionRank),1:4)), ...
        'plotting:saved_posterior_eigendecomposition_figures:DirectionScope', ...
        ['The saved eigendirection table has rows outside the all_six design, the ' ...
         'analysed scenarios and cases or directions 1 to 4; rerun the step ' ...
         '''recovery''.']);
    keys=string(T.Scenario)+"|"+string(T.CaseID)+"|"+ ...
        string(T.DirectionRank);
    expected=numel(analysis_case_ids(cfg))*numel(analysis_scenarios(cfg))* ...
        numel(canonical_parameters(cfg));
    assert(height(T)==expected&&numel(unique(keys))==expected, ...
        'plotting:saved_posterior_eigendecomposition_figures:DirectionKeys', ...
        'The saved direction table must contain four unique rows per cell.');
end

function validate_availability_schema(cfg,T)
    required=["Scenario" "CaseID" "Expected" ...
        "CertifiedPosteriorAvailable" "EigensystemValid" ...
        "IncludedInScenarioSummary" "IncludedInCrossScenarioComparison" ...
        "ExclusionReason"];
    assert(all(ismember(required,string(T.Properties.VariableNames))), ...
        'plotting:saved_posterior_eigendecomposition_figures:AvailabilitySchema', ...
        ['The saved availability table lacks the column(s) %s; rerun the step ' ...
         '''recovery''.'],strjoin(setdiff(required,string(T.Properties.VariableNames)),', '));
    keys=string(T.Scenario)+"|"+string(T.CaseID);
    expected=numel(analysis_case_ids(cfg))*numel(analysis_scenarios(cfg));
    assert(height(T)==expected&&numel(unique(keys))==expected, ...
        'plotting:saved_posterior_eigendecomposition_figures:AvailabilityKeys', ...
        'Availability must contain one unique row per expected scenario/case.');
end

function parameters=canonical_parameters(cfg)
    parameters=string(cfg.paramNames(:)).';
    expected=["m3_f_RD" "m3_e_RD" "log10_k0_RD" "Thickness_RD"];
    assert(isequal(parameters,expected), ...
        'plotting:saved_posterior_eigendecomposition_figures:ParameterOrder', ...
        ['The configured parameters must be m3_f_RD, m3_e_RD, log10_k0_RD and ' ...
         'Thickness_RD, in this order.']);
end

function scenarios=analysis_scenarios(cfg)
%ANALYSIS_SCENARIOS The scenarios of the eigen-analysis (settings A.7).
    scenarios=reshape(string(cfg.analysis.posteriorEigendecomposition.scenarios),1,[]);
end

function ids=analysis_case_ids(cfg)
%ANALYSIS_CASE_IDS The cases of the eigen-analysis: those of the inversion.
    ids=reshape(double(cfg.analysis.posteriorEigendecomposition.caseIDs),1,[]);
end

function root=eigensystem_root(cfg)
    root=study.source_folder(cfg,'posterior_eigendecomposition');
end

function tf=analysis_enabled(cfg)
%ANALYSIS_ENABLED The eigen-analysis setting (A.7).
    tf=logical(cfg.analysis.runPosteriorCovarianceEigendecomposition);
end

function labels=direction_labels()
    labels={'tightest_direction','intermediate_direction_1', ...
        'intermediate_direction_2','sloppiest_direction'};
end

function value=to_logical(input)
    if islogical(input),value=input;return;end
    if isnumeric(input),value=input~=0;return;end
    value=ismember(lower(string(input)),["true" "1"]);
end

function textValue=generated_text(generated)
    if generated,textValue="generated";else,textValue="not_generated";end
end

function T=status_row(item,status,reason,count)
    T=table(string(item),string(status),string(reason),double(count), ...
        'VariableNames',{'Item','Status','Reason','Count'});
end

function write_status(root,parts)
    if isempty(parts)
        T=table('Size',[0 4],'VariableTypes', ...
            {'string','string','string','double'}, ...
            'VariableNames',{'Item','Status','Reason','Count'});
    else
        T=vertcat(parts{:});
    end
    utils.atomic_write_table(fullfile(root, ...
        'posterior_eigendecomposition_figure_status.csv'),T);
end

function map=blue_white_red()
    n=256;half=n/2;
    left=[linspace(0.10,1,half).' linspace(0.25,1,half).' ones(half,1)];
    right=[ones(half,1) linspace(1,0.20,half).' ...
        linspace(1,0.12,half).'];
    map=[left;right];
end

function T=combine(parts)
    if isempty(parts),T=empty_manifest();else,T=vertcat(parts{:});end
end

function T=empty_manifest()
    T=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5), ...
        'VariableNames',{'Category','Figure','RelativePath','Scope', ...
        'SourceArtifacts'});
end
