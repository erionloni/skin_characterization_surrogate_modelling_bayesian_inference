function manifest=saved_confirmation_figures(outputRoot,cfg,varargin)
%SAVED_CONFIRMATION_FIGURES Render the figures of a compared confirmation campaign.
%   MANIFEST = plotting.saved_confirmation_figures(OUTPUTROOT, CFG, ...)
%   draws the confirmation figures from the saved tables of the campaign
%   folder OUTPUTROOT (its compact tier: status/, configuration/ and
%   summaries/; confirmation.finalize_confirmation_campaign). It never loads
%   posterior draws or models and performs no GP, likelihood, MCMC, FIM or
%   posterior-summary calculation.
%   Option 'BookkeepingRoot': folder for the figure inventory and the alias
%   table (default OUTPUTROOT/figures).
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    parser=inputParser;
    addParameter(parser,'BookkeepingRoot','',@(x)ischar(x)||(isstring(x)&&isscalar(x)));
    parse(parser,varargin{:});
    assert(isstruct(cfg)&&isfield(cfg,'paths')&& ...
        all(isfield(cfg.paths,{'root','runRoot'}))&&isfield(cfg,'fig')&& ...
        isfield(cfg.fig,'resolution'), ...
        'plotting:saved_confirmation_figures:Configuration', ...
        'The configuration lacks paths.root, paths.runRoot or fig.resolution.');
    outputRoot=utils.absolute_path(char(string(outputRoot)));
    assert(isfolder(outputRoot), ...
        'plotting:saved_confirmation_figures:Inputs', ...
        'The confirmation campaign folder %s does not exist.',outputRoot);
    bookkeeping=char(string(parser.Results.BookkeepingRoot));
    ownFolder=isempty(bookkeeping);
    if ownFolder,bookkeeping=fullfile(outputRoot,'figures');end
    if ~isfolder(bookkeeping),mkdir(bookkeeping);end

    paths=source_paths(outputRoot);
    requiredPaths=rmfield(paths,{'jointMetrics','jointChanges'});
    required=struct2cell(requiredPaths);
    missing=required(~cellfun(@isfile,required));
    assert(isempty(missing), ...
        'plotting:saved_confirmation_figures:Sources', ...
        ['The confirmation figures need the tables of a compared campaign ' ...
         '(the step ''compare''); missing: %s.'],strjoin(missing,', '));

    pairedWeak=readtable(paths.pairedWeak,'Delimiter',',','TextType','string');
    pairedParameters=readtable(paths.pairedParameters,'Delimiter',',','TextType','string');
    weakCells=readtable(paths.weakCells,'Delimiter',',','TextType','string');
    parameterCells=readtable(paths.parameterCells,'Delimiter',',','TextType','string');
    eligibility=readtable(paths.eligibility,'Delimiter',',','TextType','string');
    aggregate=readtable(paths.aggregate,'Delimiter',',','TextType','string');
    fim=readtable(paths.fim,'Delimiter',',','TextType','string');
    reconstruction=readtable(paths.reconstruction,'Delimiter',',','TextType','string');
    density=readtable(paths.density,'Delimiter',',','TextType','string');
    validate_schemas(pairedWeak,pairedParameters,weakCells,parameterCells, ...
        eligibility,aggregate,fim,reconstruction,density);

    hasJointGeometry=isfile(paths.jointMetrics)&&isfile(paths.jointChanges);
    if hasJointGeometry
        jointMetrics=readtable(paths.jointMetrics,'Delimiter',',','TextType','string');
        jointChanges=readtable(paths.jointChanges,'Delimiter',',','TextType','string');
        validate_joint_geometry_schemas(jointMetrics,jointChanges);
    end
    figureNames=expected_figure_names(hasJointGeometry);
    multiple=ismember('ComparisonRole',eligibility.Properties.VariableNames);
    if multiple
        roles=unique(eligibility.ComparisonRole,'stable');
        % Coincident objective winners reference one physical comparison.
        % Preserve aliases in numerical tables without duplicating figures.
        selectedIDs=strings(size(roles));
        for i=1:numel(roles)
            ids=unique(string(eligibility.SelectedProtocol(eligibility.ComparisonRole==roles(i))));
            assert(isscalar(ids),'plotting:saved_confirmation_figures:RoleProtocol','One protocol per role required.');
            selectedIDs(i)=ids;
        end
        aliases=table(roles,selectedIDs,'VariableNames',{'ComparisonRole','SelectedProtocol'});
        [~,keep]=unique(selectedIDs,'stable');roles=roles(keep);
        utils.atomic_write_table(fullfile(bookkeeping,'objective_role_aliases.csv'),aliases);
        originalNames=figureNames;figureNames={};
        for r=reshape(roles,1,[])
            figureNames=[figureNames cellfun(@(n)[n '_' char(r)],originalNames,'UniformOutput',false)]; %#ok<AGROW>
        end
    else
        roles="";originalNames=figureNames;
    end
    % Stale images of this family are removed once it finished (CLN-056).
    before=plotting.family_images(fullfile(outputRoot,'figures'),figureNames);
    if ~ownFolder,before=before([]);end
    plotting.style();
    common={paths.configuration,paths.status};
    allRows={};
    saved=struct('weak',pairedWeak,'parameters',pairedParameters,'eligibility',eligibility, ...
        'aggregate',aggregate,'fim',fim,'density',density,'reconstruction',reconstruction);
    if hasJointGeometry,saved.joint=jointChanges;end
    for role=reshape(roles,1,[])
    names=originalNames;
    if multiple
        names=cellfun(@(n)[n '_' char(role)],originalNames,'UniformOutput',false);
        pairedWeak=saved.weak(saved.weak.ComparisonRole==role,:);
        pairedParameters=saved.parameters(saved.parameters.ComparisonRole==role,:);
        eligibility=saved.eligibility(saved.eligibility.ComparisonRole==role,:);
        aggregate=saved.aggregate(saved.aggregate.ComparisonRole==role,:);
        fim=saved.fim(saved.fim.ComparisonRole==role,:);
        selectedIDs=unique(pairedWeak.SelectedProtocol);
        cellKeep=weakCells.ProtocolRole=="default"|ismember(weakCells.Protocol,selectedIDs);
        density=saved.density(ismember(saved.density.ConfirmationCellIndex,weakCells.ConfirmationCellIndex(cellKeep)),:);
        reconstruction=saved.reconstruction(ismember(saved.reconstruction.ConfirmationCellIndex,weakCells.ConfirmationCellIndex(cellKeep)),:);
        if hasJointGeometry,jointChanges=saved.joint(saved.joint.ComparisonRole==role,:);end
    end
    rows=cell(numel(names),1);
    rows{1}=paired_metric_figure(pairedWeak,'LambdaMax_Cq', ...
        'Weak-pair posterior covariance: \lambda_{max}',names{1}, ...
        cfg,outputRoot,[common {paths.pairedWeak}]);
    rows{2}=paired_metric_figure(pairedWeak,'Var_z_m3_e', ...
        'Standardized posterior variance: m3\_e\_RD',names{2}, ...
        cfg,outputRoot,[common {paths.pairedWeak}]);
    rows{3}=paired_metric_figure(pairedWeak,'Var_z_log10_k0', ...
        'Standardized posterior variance: log10\_k0\_RD',names{3}, ...
        cfg,outputRoot,[common {paths.pairedWeak}]);
    rows{4}=weak_interval_figure(pairedParameters,names{4},cfg, ...
        outputRoot,[common {paths.pairedParameters}]);
    rows{5}=weak_distribution_figure(pairedWeak,aggregate,names{5}, ...
        cfg,outputRoot,[common {paths.pairedWeak paths.aggregate}]);
    rows{6}=representative_overlay_figure(density,pairedParameters, ...
        eligibility,names{6},cfg,outputRoot, ...
        [common {paths.density paths.pairedParameters paths.eligibility}]);
    rows{7}=fim_consistency_figure(fim,names{7},cfg,outputRoot, ...
        [common {paths.fim}]);
    rows{8}=reconstruction_figure(reconstruction,names{8},cfg, ...
        outputRoot,[common {paths.reconstruction}]);
    if hasJointGeometry
        rows{9}=delta_lambda_replicate_figure(jointChanges,names{9}, ...
            cfg,outputRoot,[common {paths.jointChanges}]);
    end
    allRows=[allRows;rows]; %#ok<AGROW>
    end
    manifest=vertcat(allRows{:});
    if multiple
        extra=six_objective_figures(outputRoot,cfg,common,bookkeeping);
        manifest=[manifest;extra];
    end
    plotting.remove_stale_images(before);

    utils.atomic_write_table(fullfile(bookkeeping, ...
        'confirmation_figure_inventory.csv'),manifest);
end

function rows=six_objective_figures(root,cfg,common,bookkeeping)
    rows=table();registry=screening.objective_registry();
    cohortAliases=table();
    names={'lambda_max_cq','variance_log10k0','variance_m3e','variance_stiffness','variance_thickness','weak_trace'};
    titles={'Weak-pair posterior covariance: \lambda_{max}', ...
        'Standardized posterior variance: log10\_k0\_RD', ...
        'Standardized posterior variance: m3\_e\_RD', ...
        'Standardized posterior variance: m3\_f\_RD', ...
        'Standardized posterior variance: Thickness\_RD', ...
        'Weak-pair posterior covariance: trace'};
    % One set of summaries: every pair with both posteriors (certified or
    % healthy fallback). Objectives 1-3 are drawn with the main figures.
    path=fullfile(root,'summaries','six_objective_pairedMetrics.csv');
    if isfile(path)
        T=readtable(path,'Delimiter',',','TextType','string');
        roles=unique(string(T.ComparisonRole),'stable');
        aliasesPath=fullfile(bookkeeping,'objective_role_aliases.csv');
        if isfile(aliasesPath)
            aliases=readtable(aliasesPath,'Delimiter',',','TextType','string');
            [~,keep]=unique(aliases.SelectedProtocol,'stable');
            roles=intersect(roles,aliases.ComparisonRole(keep),'stable');
        end
        for role=reshape(roles,1,[])
            selected=T(string(T.ComparisonRole)==role,:);
            for o=4:6
                data=selected(string(selected.ObjectiveID)==registry.ObjectiveID(o),:);
                q=table(data.DefaultPosterior,data.SelectedPosterior,'VariableNames',{'Default_Value','Selected_Value'});
                name=['paired_default_selected_' names{o} '_' char(role)];
                row=paired_metric_figure(q,'Value',titles{o},name,cfg,root,[common {path}]);
                rows=[rows;row]; %#ok<AGROW>
            end
            for o=1:6
                data=selected(string(selected.ObjectiveID)==registry.ObjectiveID(o),:);
                paired=logical_column(data.PairAvailable);
                commonKeep=logical_column(data.PairCertified)&logical_column(data.AllArmsCertified);
                base=['paired_default_selected_' names{o} '_' char(role)];
                shared=isequal(paired,commonKeep);name=base;
                if ~shared
                    % The materials whose four cells are certified (the common
                    % all-arms cohort), under a short name: its path below
                    % thesis_results stays within 120 characters.
                    name=['paired_common_' names{o} '_' char(role)];
                    q=table(data.DefaultPosterior(commonKeep),data.SelectedPosterior(commonKeep), ...
                        'VariableNames',{'Default_Value','Selected_Value'});
                    rows=[rows;paired_metric_figure(q,'Value',titles{o},name,cfg,root,[common {path}])]; %#ok<AGROW>
                end
                cohortAliases=[cohortAliases;table(role,registry.ObjectiveID(o),nnz(paired),nnz(commonKeep), ...
                    shared,string(name),'VariableNames',{'ComparisonRole','ObjectiveID','PairwiseAvailableCount', ...
                    'CommonAllArmCertifiedCount','SameFigureAsPairwise','CommonAllArmFigure'})]; %#ok<AGROW>
            end
        end
    end
    utils.atomic_write_table(fullfile(bookkeeping,'common_all_arm_figure_aliases.csv'),cohortAliases);
end

function paths=source_paths(root)
    summaryRoot=fullfile(root,'summaries');
    paths=struct( ...
        'configuration',fullfile(root,'configuration', ...
            'confirmation_configuration.json'), ...
        'status',fullfile(root,'status','confirmation_status.json'), ...
        'pairedWeak',fullfile(summaryRoot, ...
            'paired_weak_pair_differences.csv'), ...
        'pairedParameters',fullfile(summaryRoot, ...
            'paired_parameter_differences.csv'), ...
        'weakCells',fullfile(summaryRoot, ...
            'weak_pair_posterior_covariance.csv'), ...
        'parameterCells',fullfile(summaryRoot, ...
            'posterior_parameter_summary.csv'), ...
        'eligibility',fullfile(summaryRoot,'paired_summary_eligibility.csv'), ...
        'aggregate',fullfile(summaryRoot, ...
            'matched_cohort_aggregate_summary.csv'), ...
        'fim',fullfile(summaryRoot,'fim_vs_aies_consistency.csv'), ...
        'reconstruction',fullfile(summaryRoot,'posterior_reconstruction.csv'), ...
        'density',fullfile(summaryRoot,'posterior_marginal_density.csv'));
    paths.jointMetrics=fullfile(summaryRoot, ...
        'joint_geometry_replicate_metrics.csv');
    paths.jointChanges=fullfile(summaryRoot, ...
        'paired_joint_geometry_changes.csv');
end

function validate_schemas(pairedWeak,pairedParameters,weakCells, ...
        parameterCells,eligibility,aggregate,fim,reconstruction,density)
    require_columns(pairedWeak,{'PairIndex','MaterialCaseID','SelectedProtocol', ...
        'Default_LambdaMax_Cq','Selected_LambdaMax_Cq', ...
        'Default_Var_z_m3_e','Selected_Var_z_m3_e', ...
        'Default_Var_z_log10_k0','Selected_Var_z_log10_k0'});
    require_columns(pairedParameters,{'PairIndex','MaterialCaseID', ...
        'Parameter','Truth','Default_IntervalWidth50', ...
        'Selected_IntervalWidth50','Default_IntervalWidth95', ...
        'Selected_IntervalWidth95'});
    require_columns(weakCells,{'ConfirmationCellIndex','MaterialCaseID','Protocol','ProtocolRole', ...
        'LambdaMax_Cq','Var_z_m3_e','Var_z_log10_k0','ArtifactLoaded'});
    require_columns(parameterCells,{'MaterialCaseID','ProtocolRole', ...
        'Parameter','Q025','Q25','Q75','Q975','ArtifactLoaded'});
    require_columns(eligibility,{'PairIndex','MaterialCaseID', ...
        'IncludedInPairedSummary','ExclusionReason','SelectedProtocol'});
    require_columns(aggregate,{'Scope','Metric','IncludedPairCount', ...
        'DefaultMean','DefaultMedian','SelectedMean','SelectedMedian'});
    require_columns(fim,{'PairIndex','MaterialCaseID','FIMProxyValid', ...
        'FIMProxyPredictedDeltaLambdaMax','PairedAIESCertified', ...
        'AIESObservedDeltaLambdaMax'});
    require_columns(reconstruction,{'ConfirmationCellIndex','MaterialCaseID','ProtocolRole', ...
        'OutputIndex','Output','DirectCOMSOLTruth','LatentGPMedian', ...
        'Q025','Q975','ArtifactLoaded'});
    require_columns(density,{'ConfirmationCellIndex','MaterialCaseID', ...
        'ProtocolRole','Parameter','GridValue','Density'});
end

function names=expected_figure_names(includeJointGeometry)
    names={ ...
        'paired_default_selected_lambda_max_cq', ...
        'paired_default_selected_variance_m3e', ...
        'paired_default_selected_variance_log10k0', ...
        'weak_parameter_interval_comparison', ...
        'aggregate_weak_pair_distributions', ...
        'representative_posterior_overlays', ...
        'fim_proxy_vs_aies_lambda_change', ...
        'six_pressure_reconstruction_parity'};
    if includeJointGeometry
        names{end+1}='delta_lambda_max_replicate_comparison';
    end
end

function validate_joint_geometry_schemas(metrics,changes)
    require_columns(metrics,{'MaterialCaseID','ProtocolRole', ...
        'GeometryScope','ReplicatePairAvailable','LambdaMaxReplicate1', ...
        'LambdaMaxReplicate2','LeadingEigenvectorAngleDegrees', ...
        'LeadingEigengapReplicate1','LeadingEigengapReplicate2'});
    require_columns(changes,{'PairIndex','MaterialCaseID','GeometryScope', ...
        'MatchedGeometryAvailable','DeltaLambdaMaxReplicate1', ...
        'DeltaLambdaMaxReplicate2', ...
        'DeltaLambdaMaxReplicateDifference'});
end

function row=delta_lambda_replicate_figure(T,name,cfg,root,sources)
    scopes=["full_4d" "weak_pair"];
    labels={'full 4-D','weak pair'};
    fig=figure('Visible','off','Position',[70 80 1040 470]);
    tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    for i=1:2
        nexttile;rows=string(T.GeometryScope)==scopes(i)& ...
            logical_column(T.MatchedGeometryAvailable);
        x=double(T.DeltaLambdaMaxReplicate1(rows));
        y=double(T.DeltaLambdaMaxReplicate2(rows));
        valid=isfinite(x)&isfinite(y);x=x(valid);y=y(valid);
        if isempty(x)
            no_evidence('No exactly matched replicate-pair evidence');
        else
            scatter(x,y,34,[0.20 0.52 0.72],'filled');hold on;
            limits=safe_equal_limits([x;y]);
            plot(limits,limits,'k--','DisplayName','equal replicate change');
            xlim(limits);ylim(limits);axis square;grid on;
            xlabel('\Delta\lambda_{max}, replicate 1');
            ylabel('\Delta\lambda_{max}, replicate 2');
        end
        title(labels{i});
    end
    sgtitle(['Selected minus default joint-geometry change; ' ...
        'factual replicate comparison only']);
    row=export_one(fig,cfg,root,name,sources);
end

function row=paired_metric_figure(T,metric,titleText,name,cfg,root,sources)
    defaultField=['Default_' metric];selectedField=['Selected_' metric];
    values=[double(T.(defaultField)) double(T.(selectedField))];
    valid=all(isfinite(values),2);values=values(valid,:);
    fig=figure('Visible','off','Position',[90 90 760 560]);hold on;
    if isempty(values)
        no_evidence('No paired material cases with a posterior');
    else
        for i=1:size(values,1)
            plot([1 2],values(i,:),'-','Color',[0.74 0.74 0.74], ...
                'LineWidth',0.8);
        end
        scatter(ones(size(values,1),1),values(:,1),30, ...
            [0.00 0.45 0.70],'filled');
        scatter(2*ones(size(values,1),1),values(:,2),30, ...
            [0.85 0.33 0.10],'filled');
        xlim([0.65 2.35]);xticks([1 2]);
        xticklabels({'generalized default','generalized selected'});
        ylabel(strrep(metric,'_','\_'),'Interpreter','tex');grid on;
    end
    title(titleText,'Interpreter','tex');
    row=export_one(fig,cfg,root,name,sources);
end

function row=weak_interval_figure(T,name,cfg,root,sources)
    parameters=["m3_e_RD" "log10_k0_RD"];
    labels=["m3\_e\_RD" "log10\_k0\_RD"];
    fig=figure('Visible','off','Position',[55 80 1080 470]);
    tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    for p=1:2
        nexttile;rows=string(T.Parameter)==parameters(p);
        d50=double(T.Default_IntervalWidth50(rows));
        s50=double(T.Selected_IntervalWidth50(rows));
        d95=double(T.Default_IntervalWidth95(rows));
        s95=double(T.Selected_IntervalWidth95(rows));
        valid50=isfinite(d50)&isfinite(s50);valid95=isfinite(d95)&isfinite(s95);
        hold on;
        if ~any(valid50)&&~any(valid95)
            no_evidence('No paired posterior intervals');
        else
            if any(valid95)
                scatter(d95(valid95),s95(valid95),34,[0.72 0.82 0.90], ...
                    'filled','DisplayName','95% interval width');
            end
            if any(valid50)
                scatter(d50(valid50),s50(valid50),34,[0.00 0.35 0.62], ...
                    'filled','DisplayName','50% interval width');
            end
            limits=safe_equal_limits([d50(valid50);s50(valid50); ...
                d95(valid95);s95(valid95)]);
            plot(limits,limits,'k--','DisplayName','equal width');
            xlim(limits);ylim(limits);axis square;grid on;
            xlabel('default interval width');ylabel('selected interval width');
            legend('Location','best');
        end
        title(labels(p),'Interpreter','tex');
    end
    sgtitle('Equal-tailed weak-parameter interval comparison');
    row=export_one(fig,cfg,root,name,sources);
end

function row=weak_distribution_figure(T,aggregate,name,cfg,root,sources)
    metrics={'LambdaMax_Cq','Var_z_m3_e','Var_z_log10_k0'};
    labels={'\lambda_{max}(C_q)','Var(z_{m3\_e})', ...
        'Var(z_{log10\_k0})'};
    fig=figure('Visible','off','Position',[45 70 1180 450]);
    tiledlayout(1,3,'Padding','compact','TileSpacing','compact');
    for i=1:3
        nexttile;hold on;
        d=double(T.(['Default_' metrics{i}]));
        s=double(T.(['Selected_' metrics{i}]));
        valid=isfinite(d)&isfinite(s);d=d(valid);s=s(valid);
        if isempty(d)
            no_evidence('No paired posterior values');
        else
            deterministic_cloud(1,d,[0.00 0.45 0.70]);
            deterministic_cloud(2,s,[0.85 0.33 0.10]);
            plot([0.82 1.18],[median(d) median(d)],'k-','LineWidth',2);
            plot([1.82 2.18],[median(s) median(s)],'k-','LineWidth',2);
            xlim([0.6 2.4]);xticks([1 2]);xticklabels({'default','selected'});
            grid on;
            declared=aggregate.Metric==string(metrics{i})& ...
                aggregate.Scope=="weak_pair";
            assert(nnz(declared)<=1, ...
                'plotting:saved_confirmation_figures:AggregateKey', ...
                'The saved confirmation aggregate repeats the weak-pair rows of metric %s.', ...
                string(metrics{i}));
        end
        ylabel(labels{i},'Interpreter','tex');title(labels{i},'Interpreter','tex');
    end
    sgtitle('Matched weak-pair posterior summaries');
    row=export_one(fig,cfg,root,name,sources);
end

function deterministic_cloud(x,values,color)
    n=numel(values);
    if n==1,offset=0;else,offset=linspace(-0.13,0.13,n).';end
    scatter(x+offset,values,28,repmat(color,n,1),'filled', ...
        'MarkerFaceAlpha',0.70);
end

function row=representative_overlay_figure( ...
        density,parameters,eligibility,name,cfg,root,sources)
    included=eligibility(logical_column( ...
        eligibility.IncludedInPairedSummary),:);
    if ~isempty(included),included=sortrows(included,'PairIndex');end
    maximumPairs=double(cfg.stage9bConfirmation. ...
        maximumRepresentativeOverlayPairs);
    selected=string(included.MaterialCaseID( ...
        1:min(maximumPairs,height(included))));
    target=["m3_e_RD" "log10_k0_RD"];
    columnCount=2;rowCount=max(1,numel(selected));
    fig=figure('Visible','off','Position',[35 35 1120 380*rowCount]);
    tiledlayout(rowCount,columnCount,'Padding','compact','TileSpacing','compact');
    if isempty(selected)
        nexttile([1 2]);no_evidence('No paired posterior densities');
    else
        for c=1:numel(selected)
            for p=1:2
                nexttile;hold on;
                default=density(string(density.MaterialCaseID)==selected(c)& ...
                    string(density.ProtocolRole)=="default"& ...
                    string(density.Parameter)==target(p),:);
                chosen=density(string(density.MaterialCaseID)==selected(c)& ...
                    string(density.ProtocolRole)=="selected"& ...
                    string(density.Parameter)==target(p),:);
                assert(~isempty(default)&&~isempty(chosen), ...
                    'plotting:saved_confirmation_figures:DensityRows', ...
                    ['The saved posterior densities lack the default or the selected protocol of ' ...
                     'material case %s and parameter %s.'],string(selected(c)),string(target(p)));
                plot(double(default.GridValue),double(default.Density), ...
                    '-','Color',[0.00 0.45 0.70],'LineWidth',1.7, ...
                    'DisplayName','generalized default');
                plot(double(chosen.GridValue),double(chosen.Density), ...
                    '-','Color',[0.85 0.33 0.10],'LineWidth',1.7, ...
                    'DisplayName','generalized selected');
                truthRows=parameters(string(parameters.MaterialCaseID)== ...
                    selected(c)&string(parameters.Parameter)==target(p),:);
                assert(height(truthRows)==1&&isfinite(double(truthRows.Truth)), ...
                    'plotting:saved_confirmation_figures:TruthRow', ...
                    ['The saved parameter table needs one finite true value for material case %s ' ...
                     'and parameter %s.'],string(selected(c)),string(target(p)));
                xline(double(truthRows.Truth),'k--', ...
                    'DisplayName','material truth');
                xlabel(target(p),'Interpreter','none');ylabel('density');grid on;
                title("MaterialCaseID "+selected(c),'Interpreter','none');
                if c==1&&p==1,legend('Location','best');end
            end
        end
    end
    sgtitle(sprintf(['Representative saved posterior marginal densities; ' ...
        'deterministic first %d paired CaseIDs'],numel(selected)));
    row=export_one(fig,cfg,root,name,sources);
end

function row=fim_consistency_figure(T,name,cfg,root,sources)
    valid=logical_column(T.FIMProxyValid)& ...
        logical_column(T.PairedAIESCertified)& ...
        isfinite(double(T.FIMProxyPredictedDeltaLambdaMax))& ...
        isfinite(double(T.AIESObservedDeltaLambdaMax));
    x=double(T.FIMProxyPredictedDeltaLambdaMax(valid));
    y=double(T.AIESObservedDeltaLambdaMax(valid));
    fig=figure('Visible','off','Position',[90 90 690 610]);hold on;
    if isempty(x)
        no_evidence('No jointly valid FIM-proxy/AIES pairs');
    else
        scatter(x,y,38,[0.00 0.45 0.70],'filled');
        limits=safe_equal_limits([x;y]);plot(limits,limits,'k--');
        xline(0,':','Color',[0.45 0.45 0.45]);
        yline(0,':','Color',[0.45 0.45 0.45]);
        xlim(limits);ylim(limits);axis square;grid on;
        xlabel('FIM-proxy predicted selected - default \Delta\lambda_{max}');
        ylabel('AIES posterior observed selected - default \Delta\lambda_{max}');
    end
    title('Local covariance-proxy versus posterior change');
    row=export_one(fig,cfg,root,name,sources);
end

function row=reconstruction_figure(T,name,cfg,root,sources)
    roles=["default" "selected"];
    labels=["generalized default" "generalized selected"];
    colors={[0.00 0.45 0.70],[0.85 0.33 0.10]};
    fig=figure('Visible','off','Position',[40 70 1080 500]);
    tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    for r=1:2
        nexttile;rows=string(T.ProtocolRole)==roles(r)& ...
            logical_column(T.ArtifactLoaded);
        truth=double(T.DirectCOMSOLTruth(rows));
        medianValue=double(T.LatentGPMedian(rows));
        q025=double(T.Q025(rows));q975=double(T.Q975(rows));
        valid=isfinite(truth)&isfinite(medianValue)& ...
            isfinite(q025)&isfinite(q975);
        truth=truth(valid);medianValue=medianValue(valid);
        q025=q025(valid);q975=q975(valid);hold on;
        if isempty(truth)
            no_evidence('No reconstruction rows');
        else
            errorbar(truth,medianValue,medianValue-q025,q975-medianValue, ...
                'o','Color',colors{r},'MarkerFaceColor',colors{r}, ...
                'LineWidth',0.9,'CapSize',2);
            limits=safe_equal_limits([truth;medianValue;q025;q975]);
            plot(limits,limits,'k--');xlim(limits);ylim(limits);axis square;
            grid on;xlabel('direct COMSOL pressure [mbar]');
            ylabel('latent GP median [mbar]');
        end
        title(labels(r),'Interpreter','none');
    end
    sgtitle('Six-pressure latent reconstruction from posterior draws');
    row=export_one(fig,cfg,root,name,sources);
end

function no_evidence(message)
    axis off;text(0.5,0.5,message,'Units','normalized', ...
        'HorizontalAlignment','center','Color',[0.35 0.35 0.35]);
end

function limits=safe_equal_limits(values)
    values=double(values);values=values(isfinite(values));
    if isempty(values),limits=[0 1];return;end
    limits=[min(values) max(values)];
    if limits(1)==limits(2)
        delta=max(1,abs(limits(1)))*0.08;
    else
        delta=0.05*diff(limits);
    end
    limits=limits+[-delta delta];
end

function value=logical_column(value)
    if islogical(value),return;end
    if isnumeric(value),value=value~=0;return;end
    textValue=lower(strtrim(string(value)));
    assert(all(ismember(textValue,["true" "false" "1" "0"])), ...
        'plotting:saved_confirmation_figures:LogicalColumn', ...
        'A saved logical column holds values other than true, false, 1 and 0.');
    value=textValue=="true"|textValue=="1";
end

function require_columns(T,names)
    assert(istable(T)&&all(ismember(names,T.Properties.VariableNames)), ...
        'plotting:saved_confirmation_figures:Schema', ...
        'A saved confirmation table must have the columns %s.',strjoin(cellstr(string(names)),', '));
end

function row=export_one(fig,cfg,root,name,sources)
    local=cfg;local.paths.runRoot=root;local.paths.stage07=root;
    row=plotting.export_saved_figure(fig,local,'figures',name,sources, ...
        'stage9b_confirmation_manual_review','all');
end

