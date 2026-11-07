function manifest=saved_screening_figures(outputRoot,cfg,writeRoot)
%SAVED_SCREENING_FIGURES Render the figures of a finished protocol screen.
%   MANIFEST = plotting.saved_screening_figures(OUTPUTROOT, CFG, WRITEROOT)
%   reads only the saved CSV/JSON tables of the screen in OUTPUTROOT; it
%   never loads a surrogate model, evaluates a surrogate, or screens.
%   Figures and their inventory go to WRITEROOT/figures (default:
%   OUTPUTROOT); reproduce mode passes a folder of its run, so that the
%   shipped results are only read.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    narginchk(2,3);
    if nargin<3,writeRoot=outputRoot;end
    assert(isstruct(cfg)&&isfield(cfg,'paths')&&isfield(cfg,'fig')&& ...
        isfield(cfg.fig,'resolution'), ...
        'plotting:saved_screening_figures:Configuration', ...
        'The configuration lacks paths or fig.resolution.');
    outputRoot=utils.absolute_path(char(string(outputRoot)));
    assert(isfolder(outputRoot),'plotting:saved_screening_figures:Inputs', ...
        'The screen folder %s does not exist.',outputRoot);

    paths=source_paths(outputRoot);
    required=struct2cell(paths);
    missing=required(~cellfun(@isfile,required));
    assert(isempty(missing),'plotting:saved_screening_figures:Sources', ...
        'The screening figures need the tables of a finished screen; missing: %s.', ...
        strjoin(missing,', '));
    numericalStatus=jsondecode(fileread(paths.status));
    assert(isfield(numericalStatus,'status')&&strcmp(numericalStatus.status,'complete'), ...
        'plotting:saved_screening_figures:NumericalStatus', ...
        'The screen in %s has not finished (its status is not complete).',outputRoot);

    aggregate=readtable(paths.aggregate,'Delimiter',',','TextType','string');
    measurement=readtable(paths.measurement,'Delimiter',',','TextType','string');
    operational=readtable(paths.operational,'Delimiter',',','TextType','string');
    top10=readtable(paths.top10,'Delimiter',',','TextType','string');
    defaultRelative=readtable(paths.defaultRelative,'Delimiter',',','TextType','string');
    rankShift=readtable(paths.rankShift,'Delimiter',',','TextType','string');
    rank1=jsondecode(fileread(paths.rank1));
    validate_schemas(aggregate,measurement,operational,top10, ...
        defaultRelative,rankShift,rank1);

    figureNames=expected_figure_names();
    writeRoot=utils.absolute_path(char(string(writeRoot)));
    % Stale images of this family are removed once it finished (CLN-056).
    figureFolder=fullfile(writeRoot,'figures');
    if ~isfolder(figureFolder),mkdir(figureFolder);end
    before=plotting.family_images(figureFolder,figureNames);
    plotting.style();
    common={paths.configuration,paths.status};
    rows=cell(10,1);
    rows{1}=primary_score_figure(operational,'Operational covariance', ...
        figureNames{1},cfg,writeRoot,[common {paths.operational}]);
    rows{2}=primary_score_figure(measurement,'Measurement covariance', ...
        figureNames{2},cfg,writeRoot,[common {paths.measurement}]);
    rows{3}=protocol_space_figure(operational, ...
        'MeanTargetProxyLambdaMax','Operational mean target proxy \lambda_{max}', ...
        figureNames{3},cfg,writeRoot,[common {paths.operational}]);
    rows{4}=rank_comparison_figure(rankShift,operational,figureNames{4}, ...
        cfg,writeRoot,[common {paths.rankShift paths.operational}]);
    rows{5}=protocol_space_figure(operational,'MeanTargetVar_m3_e', ...
        'Operational mean target variance: m3\_e\_RD',figureNames{5}, ...
        cfg,writeRoot,[common {paths.operational}]);
    rows{6}=protocol_space_figure(operational, ...
        'MeanTargetVar_log10_k0', ...
        'Operational mean target variance: log10\_k0\_RD',figureNames{6}, ...
        cfg,writeRoot,[common {paths.operational}]);
    rows{7}=top10_supporting_figure(top10,figureNames{7},cfg,writeRoot, ...
        [common {paths.top10}]);
    rows{8}=default_relative_figure(defaultRelative,operational, ...
        figureNames{8},cfg,writeRoot, ...
        [common {paths.defaultRelative paths.operational}]);
    rows{9}=top10_protocol_figure(top10,figureNames{9},cfg,writeRoot, ...
        [common {paths.top10}]);
    rows{10}=default_rank1_figure(operational,rank1,figureNames{10}, ...
        cfg,writeRoot,[common {paths.operational paths.rank1}]);
    manifest=vertcat(rows{:});
    plotting.remove_stale_images(before);

    utils.atomic_write_table(fullfile(writeRoot,'figures', ...
        'screening_figure_inventory.csv'),manifest);
end

function paths=source_paths(root)
    paths=struct( ...
        'configuration',fullfile(root,'configuration', ...
            'screening_configuration.json'), ...
        'status',fullfile(root,'status','screening_status.json'), ...
        'aggregate',fullfile(root,'aggregate_scores', ...
            'aggregate_protocol_scores.csv'), ...
        'defaultRelative',fullfile(root,'aggregate_scores', ...
            'default_relative_metrics.csv'), ...
        'rankShift',fullfile(root,'aggregate_scores', ...
            'measurement_operational_rank_shifts.csv'), ...
        'measurement',fullfile(root,'rankings', ...
            'measurement_covariance_ranking.csv'), ...
        'operational',fullfile(root,'rankings','operational_ranking.csv'), ...
        'top10',fullfile(root,'rankings','top10_protocols.csv'), ...
        'rank1',fullfile(root,'rankings', ...
            'operational_rank1_candidate.json'));
end

function validate_schemas(aggregate,measurement,operational,top10, ...
        defaultRelative,rankShift,rank1)
    rankingColumns={'CandidateID','CandidateIndex','SignedRate_kPa_s', ...
        'RateMagnitude_kPa_s','Log10AbsRate','Hold_s','Pause_s', ...
        'IsDefault','IsAnyProtocolBoundary','CovarianceCase','Rank', ...
        'MeanTargetProxyLambdaMax','MeanTargetVar_m3_e', ...
        'MeanTargetVar_log10_k0','MeanTargetTrace','MeanTargetLogDet', ...
        'Q90TargetProxyLambdaMax','LambdaMaxOfMeanTargetCovariance', ...
        'DeltaPrimaryScore','RelativePrimaryImprovement', ...
        'AggregateWorstDirectionSDImprovement','ValidityStatus'};
    require_columns(aggregate,{'CandidateID','CovarianceCase', ...
        'MeanTargetProxyLambdaMax'});
    require_columns(measurement,rankingColumns);
    require_columns(operational,rankingColumns);
    require_columns(top10,rankingColumns);
    require_columns(defaultRelative,{'CandidateID','CovarianceCase', ...
        'RelativePrimaryImprovement', ...
        'AggregateWorstDirectionSDImprovement','ValidityStatus'});
    require_columns(rankShift,{'CandidateID','MeasurementRank', ...
        'OperationalRank','OperationalMinusMeasurementRank'});
    assert(isfield(rank1,'CandidateID')&&isfield(rank1,'OperationalRank'), ...
        'plotting:saved_screening_figures:Rank1Schema', ...
        'The rank-1 record of the screen lacks CandidateID or OperationalRank.');
    assert(any(logical_column(operational.IsDefault))&& ...
        any(isfinite(double(operational.Rank))), ...
        'plotting:saved_screening_figures:RankingContent', ...
        ['The saved screening ranking marks no default protocol or ranks no ' ...
         'candidate; rerun the step ''screen''.']);
end

function require_columns(value,names)
    assert(istable(value)&&all(ismember(names,value.Properties.VariableNames)), ...
        'plotting:saved_screening_figures:Schema', ...
        'A saved screening table must have the columns %s.',strjoin(cellstr(string(names)),', '));
end

function names=expected_figure_names()
    names={ ...
        'operational_primary_score_all_candidates', ...
        'measurement_primary_score_all_candidates', ...
        'operational_protocol_space_heatmaps', ...
        'measurement_vs_operational_rank', ...
        'mean_target_variance_m3e_heatmaps', ...
        'mean_target_variance_log10k0_heatmaps', ...
        'top10_supporting_metrics', ...
        'default_relative_improvement', ...
        'top10_protocol_summary', ...
        'default_vs_operational_rank1_candidate'};
end

function row=primary_score_figure(ranking,label,name,cfg,root,sources)
    data=eligible_ranking(ranking);
    fig=figure('Visible','off','Position',[60 60 1040 560]);hold on;
    rank=double(data.Rank);score=double(data.MeanTargetProxyLambdaMax);
    boundary=logical_column(data.IsAnyProtocolBoundary);
    plot(rank,score,'-','Color',[0.72 0.72 0.72]);
    scatter(rank(~boundary),score(~boundary),22,[0.00 0.45 0.70],'filled');
    scatter(rank(boundary),score(boundary),22,[0.35 0.35 0.35],'filled');
    default=logical_column(data.IsDefault);
    if any(default)
        scatter(rank(default),score(default),70,[0.90 0.62 0.00], ...
            'filled','MarkerEdgeColor','k');
    end
    xlabel([label ' rank']);ylabel('Mean target proxy \lambda_{max}');
    title(label+" ranking across eligible investigated candidates", ...
        'Interpreter','none');
    legend({'rank-ordered score','interior candidate','boundary candidate', ...
        'default protocol'},'Location','best');
    row=export_one(fig,cfg,root,name,sources);
end

function row=protocol_space_figure(ranking,field,titleText,name,cfg,root,sources)
    data=eligible_ranking(ranking);
    regular=data(~logical_column(data.IsDefault),:);
    if isempty(regular),regular=data;end
    rates=sort(unique(double(regular.Log10AbsRate)));
    count=numel(rates);columns=min(3,max(1,ceil(sqrt(count))));
    rows=ceil(count/columns);
    fig=figure('Visible','off','Position',[40 40 1180 max(420,300*rows)]);
    tiledlayout(rows,columns,'Padding','compact','TileSpacing','compact');
    values=double(regular.(field));limits=safe_colour_limits(values);
    for i=1:count
        nexttile;
        scale=max(1,abs(rates(i)));
        take=abs(double(regular.Log10AbsRate)-rates(i))<=16*eps(scale);
        protocol_slice(double(regular.Hold_s(take)), ...
            double(regular.Pause_s(take)),double(regular.(field)(take)));
        xlabel('hold [s]');ylabel('pause [s]');
        title(sprintf('|rate| = %.5g kPa/s',10.^rates(i)), ...
            'Interpreter','none');
        clim(limits);colorbar;
    end
    sgtitle(titleText+" by protocol grid slice",'Interpreter','none');
    row=export_one(fig,cfg,root,name,sources);
end

function protocol_slice(holdValue,pauseValue,score)
    holdLevels=sort(unique(holdValue));pauseLevels=sort(unique(pauseValue));
    complete=numel(holdLevels)>=2&&numel(pauseLevels)>=2&& ...
        numel(score)==numel(holdLevels)*numel(pauseLevels)&& ...
        height(unique(table(holdValue,pauseValue),'rows'))==numel(score);
    if ~complete
        scatter(holdValue,pauseValue,150,score,'s','filled');
        return
    end
    gridValue=nan(numel(pauseLevels),numel(holdLevels));
    for i=1:numel(score)
        holdIndex=find(holdLevels==holdValue(i),1);
        pauseIndex=find(pauseLevels==pauseValue(i),1);
        gridValue(pauseIndex,holdIndex)=score(i);
    end
    imagesc(holdLevels,pauseLevels,gridValue);axis xy;
end

function row=rank_comparison_figure(rankShift,operational,name,cfg,root,sources)
    take=isfinite(double(rankShift.MeasurementRank))& ...
        isfinite(double(rankShift.OperationalRank));
    data=rankShift(take,:);
    fig=figure('Visible','off','Position',[60 60 760 650]);hold on;
    x=double(data.MeasurementRank);y=double(data.OperationalRank);
    scatter(x,y,24,[0.00 0.45 0.70],'filled');
    limits=safe_axis_limits([x;y]);plot(limits,limits,'k--');
    defaultID=string(operational.CandidateID( ...
        logical_column(operational.IsDefault)));
    if isscalar(defaultID)
        hit=string(data.CandidateID)==defaultID;
        if any(hit)
            scatter(x(hit),y(hit),75,[0.90 0.62 0.00], ...
                'filled','MarkerEdgeColor','k');
        end
    end
    xlim(limits);ylim(limits);axis square;
    xlabel('Measurement-covariance rank');ylabel('Operational rank');
    title('Measurement versus operational factual rankings');
    legend({'eligible candidates','equal ranks','default protocol'}, ...
        'Location','best');
    row=export_one(fig,cfg,root,name,sources);
end

function row=top10_supporting_figure(top10,name,cfg,root,sources)
    data=operational_top(top10);
    fields={'Q90TargetProxyLambdaMax','MeanTargetTrace', ...
        'MeanTargetLogDet','LambdaMaxOfMeanTargetCovariance'};
    labels={'Q90 target proxy \lambda_{max}','Mean target trace', ...
        'Mean target log determinant', ...
        '\lambda_{max} of mean target covariance'};
    fig=figure('Visible','off','Position',[40 40 1080 720]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
    for i=1:numel(fields)
        nexttile;bar(double(data.Rank),double(data.(fields{i})), ...
            'FaceColor',[0.00 0.45 0.70]);
        xlabel('Operational rank');ylabel(labels{i},'Interpreter','tex');
        title(labels{i},'Interpreter','tex');
    end
    sgtitle('Supporting metrics for the operational top-ranked grid candidates');
    row=export_one(fig,cfg,root,name,sources);
end

function row=default_relative_figure(defaultRelative,operational, ...
        name,cfg,root,sources)
    relative=defaultRelative( ...
        string(defaultRelative.CovarianceCase)== ...
        "operational_measurement_plus_emulator",:);
    joined=innerjoin(operational(:,{'CandidateID','Rank','IsDefault'}), ...
        relative(:,{'CandidateID','RelativePrimaryImprovement', ...
        'AggregateWorstDirectionSDImprovement'}),'Keys','CandidateID');
    take=isfinite(double(joined.Rank));joined=sortrows(joined(take,:),'Rank');
    fig=figure('Visible','off','Position',[60 60 1040 560]);hold on;
    plot(double(joined.Rank),double(joined.RelativePrimaryImprovement), ...
        '-','Color',[0.00 0.45 0.70]);
    plot(double(joined.Rank), ...
        double(joined.AggregateWorstDirectionSDImprovement),'-', ...
        'Color',[0.90 0.62 0.00]);
    yline(0,'k--');
    default=logical_column(joined.IsDefault);
    if any(default)
        scatter(repmat(double(joined.Rank(default)),2,1), ...
            [double(joined.RelativePrimaryImprovement(default)); ...
            double(joined.AggregateWorstDirectionSDImprovement(default))], ...
            60,'k','filled');
    end
    xlabel('Operational rank');ylabel('Default-relative fraction');
    title('Operational default-relative screening metrics');
    legend({'Relative primary improvement', ...
        'Aggregate worst-direction SD improvement','zero reference', ...
        'default protocol'},'Location','best');
    row=export_one(fig,cfg,root,name,sources);
end

function row=top10_protocol_figure(top10,name,cfg,root,sources)
    data=operational_top(top10);
    fig=figure('Visible','off','Position',[40 40 1080 410]);
    tiledlayout(1,3,'Padding','compact','TileSpacing','compact');
    protocol_panel(data,'RateMagnitude_kPa_s','|suction rate| [kPa/s]');
    protocol_panel(data,'Hold_s','hold [s]');
    protocol_panel(data,'Pause_s','pause [s]');
    sgtitle('Protocol coordinates of the operational top-ranked grid candidates');
    row=export_one(fig,cfg,root,name,sources);
end

function protocol_panel(data,field,label)
    nexttile;bar(double(data.Rank),double(data.(field)), ...
        'FaceColor',[0.00 0.45 0.70]);
    xlabel('Operational rank');ylabel(label);title(label,'Interpreter','none');
end

function row=default_rank1_figure(operational,rank1,name,cfg,root,sources)
    data=eligible_ranking(operational);
    default=operational(logical_column(operational.IsDefault),:);
    first=data(string(data.CandidateID)==string(rank1.CandidateID),:);
    assert(height(default)==1&&height(first)==1&&double(first.Rank)==1, ...
        'plotting:saved_screening_figures:Rank1Content', ...
        ['The saved screening ranking must mark one default protocol and rank the ' ...
         'rank-1 candidate first; rerun the step ''screen''.']);
    pair=[default;first];names={'default protocol','operational rank-1 candidate'};
    fig=figure('Visible','off','Position',[40 40 1060 720]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
    nexttile;bar(double(pair.MeanTargetProxyLambdaMax));
    xticks(1:2);xticklabels(names);xtickangle(12);
    ylabel('Mean target proxy \lambda_{max}');title('Primary score');
    nexttile;bar([double(pair.MeanTargetVar_m3_e) ...
        double(pair.MeanTargetVar_log10_k0)]);
    xticks(1:2);xticklabels(names);xtickangle(12);
    ylabel('Mean target marginal variance');
    legend({'m3\_e\_RD','log10\_k0\_RD'},'Location','best');
    title('Target marginal variance');
    nexttile;bar([double(pair.RelativePrimaryImprovement) ...
        double(pair.AggregateWorstDirectionSDImprovement)]);
    xticks(1:2);xticklabels(names);xtickangle(12);
    ylabel('Default-relative fraction');
    legend({'primary improvement','worst-direction SD improvement'}, ...
        'Location','best');title('Default-relative metrics');
    nexttile;yyaxis left;bar([double(pair.Hold_s) double(pair.Pause_s)]);
    ylabel('duration [s]');yyaxis right;
    plot(1:2,double(pair.RateMagnitude_kPa_s),'ko-', ...
        'MarkerFaceColor','k');ylabel('|rate| [kPa/s]');
    xticks(1:2);xticklabels(names);xtickangle(12);
    title('Protocol coordinates');
    sgtitle(['Default versus the best-ranked candidate in the ' ...
        'investigated grid']);
    row=export_one(fig,cfg,root,name,sources);
end

function data=eligible_ranking(ranking)
    take=string(ranking.ValidityStatus)=="ELIGIBLE"& ...
        isfinite(double(ranking.Rank))& ...
        isfinite(double(ranking.MeanTargetProxyLambdaMax));
    data=sortrows(ranking(take,:),'Rank');
    assert(~isempty(data), ...
        'plotting:saved_screening_figures:NoEligibleCandidates', ...
        ['The saved screening ranking has no eligible candidate with a finite rank ' ...
         'and information value.']);
end

function data=operational_top(top10)
    take=string(top10.CovarianceCase)== ...
        "operational_measurement_plus_emulator"& ...
        isfinite(double(top10.Rank));
    data=sortrows(top10(take,:),'Rank');
    assert(~isempty(data), ...
        'plotting:saved_screening_figures:NoOperationalTopRows', ...
        'The saved top-10 table has no ranked candidate of the operational scenario.');
end

function value=logical_column(value)
    if islogical(value),return;end
    if isnumeric(value),value=value~=0;return;end
    textValue=lower(strtrim(string(value)));
    assert(all(ismember(textValue,["true" "false" "1" "0"])), ...
        'plotting:saved_screening_figures:LogicalColumn', ...
        'A saved logical column holds values other than true, false, 1 and 0.');
    value=textValue=="true"|textValue=="1";
end

function limits=safe_axis_limits(values)
    values=values(isfinite(values));
    if isempty(values),limits=[0 1];return;end
    limits=[min(values) max(values)];
    if limits(1)==limits(2)
        delta=max(1,abs(limits(1)))*0.08;
        limits=limits+[-delta delta];
    else
        padding=0.04*diff(limits);limits=limits+[-padding padding];
    end
end

function limits=safe_colour_limits(values)
    values=values(isfinite(values));
    if isempty(values),limits=[0 1];return;end
    limits=[min(values) max(values)];
    if limits(1)==limits(2)
        delta=max(1,abs(limits(1)))*sqrt(eps);
        limits=limits+[-delta delta];
    end
end

function row=export_one(fig,cfg,root,name,sources)
    local=cfg;
    local.paths.runRoot=root;
    local.paths.stage07=root;
    row=plotting.export_saved_figure(fig,local,'figures',name,sources, ...
        'stage9b_screening_manual_review',[]);
end

