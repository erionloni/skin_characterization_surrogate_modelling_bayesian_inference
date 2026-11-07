function manifest=saved_surrogate_quality_audit_figures(cfg,options)
%SAVED_SURROGATE_QUALITY_AUDIT_FIGURES Render the saved development audit.
%   MANIFEST = plotting.saved_surrogate_quality_audit_figures(CFG, OPTIONS)
%   draws the figures of the development audit of the route's surrogates
%   (study.source_folder 'surrogate_audit') and returns their manifest.
%   This bounded renderer reads only the audit CSV/JSON evidence. It never
%   loads model MAT files, fits/evaluates a surrogate, or calls an upstream
%   numerical stage. Missing optional local-variance evidence is recorded as
%   skipped rather than converted to fabricated figure values.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    if nargin<2||isempty(options),options=struct();end
    mode=option_text(options,'Mode',default_mode(cfg));
    assert(ismember(mode,{'aggregate','publication','full'}), ...
        'plotting:saved_surrogate_quality_audit_figures:Mode', ...
        'Mode must be aggregate, publication, or full.');
    if ~audit_enabled(cfg),manifest=empty_manifest();return;end

    sourceRoot=audit_root(cfg);source=source_paths(sourceRoot);
    outputRoot=fullfile(cfg.paths.stage07,'surrogate','quality_audit');
    if ~isfolder(outputRoot),mkdir(outputRoot);end
    [complete,reason]=source_status_complete(source.status);
    if ~complete
        manifest=empty_manifest();
        availability=availability_row("all_audit_figures","publication", ...
            false,reason,{source.status});
        finish_outputs(outputRoot,mode,manifest,portable_sources(availability,cfg));return
    end

    plotting.style();
    specs=figure_specs(cfg,source);
    rows=cell(0,1);availability=cell(numel(specs),1);
    for index=1:numel(specs)
        one=specs{index};
        if ~scope_in_mode(one.scope,mode)
            availability{index}=availability_row(one.name,one.scope,false, ...
                "excluded_by_figure_mode",one.sources);continue
        end
        missing=one.sources(~cellfun(@isfile,one.sources));
        if ~isempty(missing)
            availability{index}=availability_row(one.name,one.scope,false, ...
                "missing_saved_source",one.sources);continue
        end
        try
            rows{end+1,1}=one.builder(); %#ok<AGROW>
            availability{index}=availability_row(one.name,one.scope,true,"", ...
                one.sources);
        catch ME
            if strcmp(ME.identifier, ...
                    'plotting:saved_surrogate_quality_audit_figures:Unavailable')
                availability{index}=availability_row(one.name,one.scope,false, ...
                    string(ME.message),one.sources);
            else
                rethrow(ME)
            end
        end
    end
    if isempty(rows),manifest=empty_manifest();else,manifest=vertcat(rows{:});end
    availability=vertcat(availability{:});
    finish_outputs(outputRoot,mode,manifest,portable_sources(availability,cfg));
end

function availability=portable_sources(availability,cfg)
%PORTABLE_SOURCES Repository-relative source paths in reproduce mode (8.6).
    if ~study.is_publication(cfg),return;end
    for i=1:height(availability)
        parts=strsplit(char(availability.SourceArtifacts(i)),' | ');
        parts=parts(~cellfun(@isempty,parts));
        parts=cellfun(@(p)study.portable_path(p,cfg.layout),parts, ...
            'UniformOutput',false);
        availability.SourceArtifacts(i)=string(strjoin(parts,' | '));
    end
end

function specs=figure_specs(cfg,p)
    specs={ ...
        spec('cv_metric_distributions','aggregate',{p.cvPerFold}, ...
            @()cv_metric_distributions(cfg,p.cvPerFold)), ...
        spec('cv_per_output_oof_error','aggregate',{p.cvPooled}, ...
            @()per_output_oof_error(cfg,p.cvPooled)), ...
        spec('cv_raw_predictive_interval_inclusion','aggregate',{p.cvPooled}, ...
            @()raw_interval_inclusion(cfg,p.cvPooled)), ...
        spec('same_data_gp_mean_seed_stability','publication',{p.sameMean}, ...
            @()same_data_mean_stability(cfg,p.sameMean)), ...
        spec('same_data_gp_sd_seed_stability','publication',{p.sameSD}, ...
            @()same_data_sd_stability(cfg,p.sameSD)), ...
        spec('development_training_convergence','publication',{p.convergence}, ...
            @()training_convergence(cfg,p.convergence)), ...
        spec('variance_model_proper_scores','publication',{p.crossfitMetrics}, ...
            @()variance_model_scores(cfg,p.crossfitMetrics)), ...
        spec('variance_model_interval_inclusion','publication',{p.crossfitMetrics}, ...
            @()variance_model_coverage(cfg,p.crossfitMetrics)), ...
        spec('local_shape_calibration_bins','publication',{p.localBins}, ...
            @()local_shape_bins(cfg,p.localBins)), ...
        spec('standardized_residual_qq_pit','publication',{p.pit}, ...
            @()residual_qq_pit(cfg,p.pit)), ...
        spec('shrunk_residual_correlation','publication',{p.correlation}, ...
            @()residual_correlation(cfg,p.correlation)), ...
        spec('diagonal_vs_correlated_joint_score','publication',{p.jointScore}, ...
            @()joint_score(cfg,p.jointScore)), ...
        spec('variance_scale_gamma_bootstrap_intervals','publication',{p.bootstrap}, ...
            @()bootstrap_intervals(cfg,p.bootstrap))};
end

function value=spec(name,scope,sources,builder)
    value=struct('name',char(name),'scope',char(scope), ...
        'sources',{sources},'builder',builder);
end

function row=cv_metric_distributions(cfg,pathValue)
    T=saved_table(pathValue,{'Repeat','Fold','Kernel','OutputIndex','R2', ...
        'NRMSE_range','RMSStandardizedResidual','GaussianNLPD'});
    metrics={'R2','NRMSE_range','RMSStandardizedResidual','GaussianNLPD'};
    labels={'R^2','range-normalized RMSE','RMS standardized residual', ...
        'Gaussian NLPD'};kernels=ordered_text(T,'Kernel');
    fig=figure('Visible','off','Position',[60 60 1180 760]);
    layout=tiledlayout(fig,2,2,'Padding','compact','TileSpacing','compact');
    for metricIndex=1:numel(metrics)
        nexttile;hold on;values=[];groups=strings(0,1);
        for kernelIndex=1:numel(kernels)
            one=T(string(T.Kernel)==kernels(kernelIndex),:);
            key=unique([double(one.Repeat) double(one.Fold)],'rows','stable');
            aggregate=nan(size(key,1),1);
            for keyIndex=1:size(key,1)
                selected=double(one.Repeat)==key(keyIndex,1)& ...
                    double(one.Fold)==key(keyIndex,2);
                aggregate(keyIndex)=mean(double(one.(metrics{metricIndex})(selected)), ...
                    'omitnan');
            end
            values=[values;aggregate]; %#ok<AGROW>
            groups=[groups;repmat(kernels(kernelIndex),numel(aggregate),1)]; ...
                %#ok<AGROW>
        end
        boxchart(categorical(groups,kernels),values,'MarkerStyle','.');
        xlabel('kernel');ylabel(labels{metricIndex});
    end
    title(layout,['Repeated five-fold development cross-validation ' ...
        '(equal-output fold summaries)']);
    row=export_one(fig,cfg,'cv_metric_distributions',{pathValue},'aggregate');
end

function row=per_output_oof_error(cfg,pathValue)
    T=saved_table(pathValue,{'Repeat','Kernel','OutputIndex','Output', ...
        'RMSE','NRMSE_range'});outputs=ordered_outputs(T);
    kernels=ordered_text(T,'Kernel');st=plotting.style();
    metrics={'RMSE','NRMSE_range'};labels={'RMSE [mbar]', ...
        'range-normalized RMSE'};
    fig=figure('Visible','off','Position',[60 60 1180 520]);
    layout=tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
    for metricIndex=1:2
        nexttile;hold on;
        for kernelIndex=1:numel(kernels)
            [center,spread]=output_summary(T,kernels(kernelIndex),outputs, ...
                metrics{metricIndex});
            x=(1:numel(outputs)).'+offset(kernelIndex,numel(kernels));
            errorbar(x,center,spread,'o-','Color',palette(st,kernelIndex), ...
                'MarkerFaceColor',palette(st,kernelIndex), ...
                'DisplayName',kernels(kernelIndex));
        end
        output_ticks(outputs);ylabel(labels{metricIndex});xlabel('output');
    end
    legend('Location','southoutside','Orientation','horizontal');
    title(layout,'Pooled development OOF error (mean \pm SD across repetitions)');
    row=export_one(fig,cfg,'cv_per_output_oof_error',{pathValue},'aggregate');
end

function row=raw_interval_inclusion(cfg,pathValue)
    fields={'Coverage50_percent','Coverage80_percent', ...
        'Coverage90_percent','Coverage95_percent'};levels=[50 80 90 95];
    T=saved_table(pathValue,[{'Repeat','Kernel','OutputIndex','Output'} fields]);
    kernels=ordered_text(T,'Kernel');outputs=ordered_outputs(T);st=plotting.style();
    fig=figure('Visible','off','Position',[50 50 1280 470]);
    layout=tiledlayout(fig,1,numel(kernels),'Padding','compact','TileSpacing','compact');
    for kernelIndex=1:numel(kernels)
        nexttile;hold on;matrix=nan(numel(outputs),numel(fields));
        for outputIndex=1:numel(outputs)
            selected=string(T.Kernel)==kernels(kernelIndex)& ...
                string(T.Output)==outputs(outputIndex);
            for levelIndex=1:numel(fields)
                matrix(outputIndex,levelIndex)=mean( ...
                    double(T.(fields{levelIndex})(selected)),'omitnan');
            end
            plot(levels,matrix(outputIndex,:),'-','Color',[.78 .78 .78], ...
                'HandleVisibility','off');
        end
        plot(levels,mean(matrix,1,'omitnan'),'-o','Color', ...
            palette(st,kernelIndex),'MarkerFaceColor',palette(st,kernelIndex), ...
            'DisplayName','equal-output mean');
        plot(levels,levels,'k--','DisplayName','nominal reference');
        xlim([47 98]);ylim([0 100]);xticks(levels);xlabel('nominal level [%]');
        ylabel('development OOF truth inclusion [%]');title(kernels(kernelIndex));
    end
    legend('Location','southoutside','Orientation','horizontal');
    title(layout,'Raw UQLab predictive-interval inclusion');
    row=export_one(fig,cfg,'cv_raw_predictive_interval_inclusion', ...
        {pathValue},'aggregate');
end

function row=same_data_mean_stability(cfg,pathValue)
    T=saved_table(pathValue,{'Kernel','OutputIndex','Output','ProbeIndex', ...
        'SDGPMeanAcrossSeeds','MeanAbsolutePairwiseDifference', ...
        'MaximumAbsolutePairwiseDifference'});
    kernels=ordered_text(T,'Kernel');outputs=ordered_outputs(T);st=plotting.style();
    fig=figure('Visible','off','Position',[60 60 1180 520]);
    layout=tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
    fields={'SDGPMeanAcrossSeeds','MeanAbsolutePairwiseDifference'};
    labels={'SD of GP means across seeds [mbar]', ...
        'mean absolute pairwise GP-mean difference [mbar]'};
    for panel=1:2
        nexttile;hold on;
        for kernelIndex=1:numel(kernels)
            med=nan(numel(outputs),1);upper=med;
            for outputIndex=1:numel(outputs)
                selected=string(T.Kernel)==kernels(kernelIndex)& ...
                    string(T.Output)==outputs(outputIndex);
                values=double(T.(fields{panel})(selected));
                med(outputIndex)=median(values,'omitnan');
                upper(outputIndex)=max(values,[],'omitnan');
            end
            plot(1:numel(outputs),med,'o-','Color',palette(st,kernelIndex), ...
                'MarkerFaceColor',palette(st,kernelIndex), ...
                'DisplayName',kernels(kernelIndex)+" median");
            plot(1:numel(outputs),upper,'--','Color',palette(st,kernelIndex), ...
                'DisplayName',kernels(kernelIndex)+" maximum");
        end
        output_ticks(outputs);ylabel(labels{panel});xlabel('output');
    end
    legend('Location','southoutside','Orientation','horizontal');
    title(layout,'Same-data HGA seed stability on the truth-free probe design');
    row=export_one(fig,cfg,'same_data_gp_mean_seed_stability',{pathValue}, ...
        'publication');
end

function row=same_data_sd_stability(cfg,pathValue)
    T=saved_table(pathValue,{'Scope','Kernel','OutputIndex','Output','Metric','Value'});
    T=T(string(T.Scope)=="across_probe_summary",:);
    require_rows(T,'same-data predictive-SD summary rows unavailable');
    kernels=ordered_text(T,'Kernel');outputs=ordered_outputs(T);st=plotting.style();
    pairs={{'predictive_sd_cv_median','predictive_sd_cv_maximum'}, ...
        {'predictive_sd_ratio_median','predictive_sd_ratio_maximum'}};
    labels={'predictive-SD coefficient of variation', ...
        'maximum/minimum predictive-SD ratio'};
    fig=figure('Visible','off','Position',[60 60 1180 520]);
    layout=tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
    for panel=1:2
        nexttile;hold on;
        for kernelIndex=1:numel(kernels)
            for statisticIndex=1:2
                values=nan(numel(outputs),1);
                for outputIndex=1:numel(outputs)
                    selected=string(T.Kernel)==kernels(kernelIndex)& ...
                        string(T.Output)==outputs(outputIndex)& ...
                        string(T.Metric)==pairs{panel}{statisticIndex};
                    if any(selected),values(outputIndex)=double(T.Value(find(selected,1)));end
                end
                style='-';word="median";if statisticIndex==2,style='--';word="maximum";end
                plot(1:numel(outputs),values,['o' style], ...
                    'Color',palette(st,kernelIndex),'DisplayName', ...
                    kernels(kernelIndex)+" "+word);
            end
        end
        output_ticks(outputs);ylabel(labels{panel});xlabel('output');
    end
    legend('Location','southoutside','Orientation','horizontal');
    title(layout,'Same-data predictive-SD surface stability across HGA seeds');
    row=export_one(fig,cfg,'same_data_gp_sd_seed_stability',{pathValue}, ...
        'publication');
end

function row=training_convergence(cfg,pathValue)
    T=saved_table(pathValue,{'Repeat', ...
        'NominalGlobalDevelopmentCaseCount','ModelFamily','Candidate', ...
        'OutputIndex','NRMSE_range','RMSE','Cohort','FitStatus'});
    if ~ismember('ActualTrainingCaseCount',T.Properties.VariableNames)
        T.ActualTrainingCaseCount=double( ...
            T.NominalGlobalDevelopmentCaseCount);
    end
    T=T(string(T.Cohort)=="temporary_development_validation"& ...
        string(T.FitStatus)=="completed",:);
    require_rows(T,'development-only training-convergence rows unavailable');
    candidates=ordered_text(T,'Candidate');
    sizes=sort(unique(double(T.NominalGlobalDevelopmentCaseCount)));
    actualSizes=arrayfun(@(nominal)mean(double(T.ActualTrainingCaseCount( ...
        double(T.NominalGlobalDevelopmentCaseCount)==nominal)), ...
        'omitnan'),sizes);
    st=plotting.style();metrics={'NRMSE_range','RMSE'};
    labels={'equal-output range-normalized RMSE','equal-output RMSE [mbar]'};
    fig=figure('Visible','off','Position',[60 60 1180 520]);
    layout=tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
    for panel=1:2
        nexttile;hold on;
        for candidateIndex=1:numel(candidates)
            center=nan(numel(sizes),1);spread=center;
            for sizeIndex=1:numel(sizes)
                one=T(string(T.Candidate)==candidates(candidateIndex)& ...
                    double(T.NominalGlobalDevelopmentCaseCount)== ...
                    sizes(sizeIndex),:);
                repeats=unique(double(one.Repeat));pooled=nan(numel(repeats),1);
                for repeatIndex=1:numel(repeats)
                    pooled(repeatIndex)=mean(double(one.(metrics{panel})( ...
                        double(one.Repeat)==repeats(repeatIndex))),'omitnan');
                end
                center(sizeIndex)=mean(pooled,'omitnan');
                spread(sizeIndex)=std(pooled,0,'omitnan');
            end
            errorbar(actualSizes,center,spread,'o-','Color', ...
                palette(st,candidateIndex),'MarkerFaceColor', ...
                palette(st,candidateIndex),'DisplayName',candidates(candidateIndex));
        end
        xlabel('mean actual per-output development training cases');
        ylabel(labels{panel});xticks(actualSizes);
    end
    legend('Location','southoutside','Orientation','horizontal');
    title(layout,['Development-only convergence: global nested nominal subsets; ' ...
        'actual finite-output training counts on x-axis']);
    row=export_one(fig,cfg,'development_training_convergence',{pathValue}, ...
        'publication');
end

function row=variance_model_scores(cfg,pathValue)
    T=saved_table(pathValue,{'CalibrationFold','Kernel','Candidate', ...
        'OutputIndex','GaussianNLPD','GaussianCRPS','UnavailableReason'});
    T=T(double(T.CalibrationFold)>0&double(T.OutputIndex)==0,:);
    T=T(isfinite(double(T.GaussianNLPD))|isfinite(double(T.GaussianCRPS)),:);
    require_rows(T,'cross-fitted variance-model proper scores unavailable');
    metrics={'GaussianNLPD','GaussianCRPS'};labels={'Gaussian NLPD','Gaussian CRPS'};
    fig=figure('Visible','off','Position',[60 60 1180 520]);
    layout=tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
    group=string(T.Kernel)+" | "+string(T.Candidate);order=unique(group,'stable');
    for panel=1:2
        nexttile;boxchart(categorical(group,order),double(T.(metrics{panel})), ...
            'MarkerStyle','.');xtickangle(30);ylabel(labels{panel});
        xlabel('kernel | diagonal variance candidate');
    end
    title(layout,'Held-out calibration-fold proper scores (equal output weight)');
    row=export_one(fig,cfg,'variance_model_proper_scores',{pathValue}, ...
        'publication');
end

function row=variance_model_coverage(cfg,pathValue)
    fields={'Coverage50_percent','Coverage80_percent', ...
        'Coverage90_percent','Coverage95_percent'};levels=[50 80 90 95];
    T=saved_table(pathValue,[{'CalibrationFold','Kernel','Candidate', ...
        'OutputIndex'} fields]);
    T=T(double(T.CalibrationFold)==0&double(T.OutputIndex)==0,:);
    finite=false(height(T),1);
    for i=1:numel(fields),finite=finite|isfinite(double(T.(fields{i})));end
    T=T(finite,:);require_rows(T,'cross-fitted variance-model inclusion unavailable');
    kernels=ordered_text(T,'Kernel');candidates=ordered_text(T,'Candidate');
    st=plotting.style();fig=figure('Visible','off','Position',[50 50 1280 470]);
    layout=tiledlayout(fig,1,numel(kernels),'Padding','compact','TileSpacing','compact');
    for kernelIndex=1:numel(kernels)
        nexttile;hold on;
        for candidateIndex=1:numel(candidates)
            one=T(string(T.Kernel)==kernels(kernelIndex)& ...
                string(T.Candidate)==candidates(candidateIndex),:);
            if isempty(one),continue;end
            values=nan(1,numel(fields));
            for levelIndex=1:numel(fields)
                values(levelIndex)=double(one.(fields{levelIndex})(1));
            end
            if any(isfinite(values))
                plot(levels,values,'-o','Color',palette(st,candidateIndex), ...
                    'DisplayName',candidates(candidateIndex));
            end
        end
        plot(levels,levels,'k--','DisplayName','nominal reference');
        xlim([47 98]);ylim([0 100]);xticks(levels);xlabel('nominal level [%]');
        ylabel('cross-fitted truth inclusion [%]');title(kernels(kernelIndex));
    end
    legend('Location','southoutside','Orientation','horizontal');
    title(layout,'Case-balanced central predictive-interval inclusion');
    row=export_one(fig,cfg,'variance_model_interval_inclusion',{pathValue}, ...
        'publication');
end

function row=local_shape_bins(cfg,pathValue)
    T=saved_table(pathValue,{'Kernel','Candidate','OutputIndex','Bin', ...
        'EmpiricalRMSE','MeanPredictedSD','CaseCount'});
    T=T(isfinite(double(T.EmpiricalRMSE))&isfinite(double(T.MeanPredictedSD)),:);
    require_rows(T,'local-shape evidence unavailable after variance-semantics check');
    kernels=ordered_text(T,'Kernel');candidates=ordered_text(T,'Candidate');
    st=plotting.style();fig=figure('Visible','off','Position',[50 50 1280 470]);
    layout=tiledlayout(fig,1,numel(kernels),'Padding','compact','TileSpacing','compact');
    for kernelIndex=1:numel(kernels)
        nexttile;hold on;
        for candidateIndex=1:numel(candidates)
            one=T(string(T.Kernel)==kernels(kernelIndex)& ...
                string(T.Candidate)==candidates(candidateIndex),:);
            bins=sort(unique(double(one.Bin)));empirical=nan(size(bins));predicted=empirical;
            for binIndex=1:numel(bins)
                selected=double(one.Bin)==bins(binIndex);
                empirical(binIndex)=mean(double(one.EmpiricalRMSE(selected)),'omitnan');
                predicted(binIndex)=mean(double(one.MeanPredictedSD(selected)),'omitnan');
            end
            plot(bins,empirical,'o-','Color',palette(st,candidateIndex), ...
                'DisplayName',candidates(candidateIndex)+" empirical RMSE");
            plot(bins,predicted,'--','Color',palette(st,candidateIndex), ...
                'DisplayName',candidates(candidateIndex)+" predicted SD");
        end
        xlabel('predicted local-shape quantile bin');ylabel('equal-output mean [mbar]');
        title(kernels(kernelIndex));
    end
    legend('Location','southoutside','Orientation','horizontal');
    title(layout,'Held-out calibration-fold local-shape evidence');
    row=export_one(fig,cfg,'local_shape_calibration_bins',{pathValue}, ...
        'publication');
end

function row=residual_qq_pit(cfg,pitPath)
%RESIDUAL_QQ_PIT The PIT of the cross-fitted standardized residuals, per kernel and variance model.
%   The Q-Q panel is not drawn: it averaged the quantiles of equal rank across
%   outputs with different case counts. The per-output Q-Q points are
%   residual_distribution/qq_points.csv (surrogates.residual_distribution_summaries).
    P=saved_table(pitPath,{'Kernel','Candidate','OutputIndex','PITBin', ...
        'PITBinFraction'});
    kernels=ordered_text(P,'Kernel');candidates=ordered_text(P,'Candidate');
    if isempty(kernels)||isempty(candidates)
        unavailable('standardized-residual PIT evidence unavailable');
    end
    st=plotting.style();fig=figure('Visible','off', ...
        'Position',[30 30 640 max(520,330*numel(kernels))]);
    layout=tiledlayout(fig,numel(kernels),1,'Padding','compact','TileSpacing','compact');
    handles=gobjects(1,numel(candidates));
    for kernelIndex=1:numel(kernels)
        nexttile;hold on;
        for candidateIndex=1:numel(candidates)
            one=P(string(P.Kernel)==kernels(kernelIndex)& ...
                string(P.Candidate)==candidates(candidateIndex),:);
            uniqueRows=unique(one(:,{'OutputIndex','PITBin','PITBinFraction'}), ...
                'rows','stable');bins=sort(unique(double(uniqueRows.PITBin)));
            fraction=nan(size(bins));
            for binIndex=1:numel(bins)
                fraction(binIndex)=mean(double(uniqueRows.PITBinFraction( ...
                    double(uniqueRows.PITBin)==bins(binIndex))),'omitnan');
            end
            handles(candidateIndex)=plot(bins,fraction,'-o','Color',palette(st,candidateIndex), ...
                'DisplayName',candidates(candidateIndex));
        end
        if ~isempty(bins),yline(1/numel(bins),'k--','uniform reference');end
        xlabel('PIT bin');ylabel('mean bin fraction across outputs');
        title(kernels(kernelIndex)+' | PIT');
    end
    % The variance models only, in two columns: the one-column figure is narrow.
    legend(handles,'Location','southoutside','NumColumns',2);
    title(layout,'Cross-fitted standardized-residual PIT evidence');
    row=plotting.export_saved_figure(fig,cfg,'surrogate/quality_audit', ...
        'standardized_residual_qq_pit',{pitPath},'publication',[]);
end
function row=residual_correlation(cfg,pathValue)
    T=saved_table(pathValue,{'Kernel','CalibrationFold','Candidate', ...
        'OutputIndex1','Output1','OutputIndex2','Output2','Correlation', ...
        'MatrixValid'});
    valid=logical_column(T.MatrixValid)&isfinite(double(T.Correlation));T=T(valid,:);
    require_rows(T,'valid shrunk residual-correlation evidence unavailable');
    kernels=ordered_text(T,'Kernel');candidates=ordered_text(T,'Candidate');
    outputs=ordered_matrix_outputs(T);
    fig=figure('Visible','off','Position',[20 20 max(1000,380*numel(candidates)), ...
        max(500,310*numel(kernels))]);
    layout=tiledlayout(fig,numel(kernels),numel(candidates), ...
        'Padding','compact','TileSpacing','compact');
    for kernelIndex=1:numel(kernels)
        for candidateIndex=1:numel(candidates)
            nexttile;one=T(string(T.Kernel)==kernels(kernelIndex)& ...
                string(T.Candidate)==candidates(candidateIndex),:);
            matrix=nan(numel(outputs));
            for i=1:numel(outputs)
                for j=1:numel(outputs)
                    selected=double(one.OutputIndex1)==i&double(one.OutputIndex2)==j;
                    matrix(i,j)=mean(double(one.Correlation(selected)),'omitnan');
                end
            end
            imagesc(matrix,[-1 1]);axis image;colorbar;
            xticks(1:numel(outputs));xticklabels(outputs);xtickangle(30);
            yticks(1:numel(outputs));yticklabels(outputs);
            title(kernels(kernelIndex)+" | "+candidates(candidateIndex));
        end
    end
    colormap(fig,parula);title(layout, ...
        'Mean held-out-fold shrinkage residual correlation');
    row=export_one(fig,cfg,'shrunk_residual_correlation',{pathValue}, ...
        'publication');
end

function row=joint_score(cfg,pathValue)
    T=saved_table(pathValue,{'Kernel','CalibrationFold','Candidate', ...
        'CorrelationValid','CorrelatedMinusDiagonal'});
    T=T(logical_column(T.CorrelationValid)& ...
        isfinite(double(T.CorrelatedMinusDiagonal)),:);
    require_rows(T,'held-out diagonal/correlated joint-score evidence unavailable');
    group=string(T.Kernel)+" | "+string(T.Candidate);order=unique(group,'stable');
    fig=figure('Visible','off','Position',[60 60 1100 520]);
    boxchart(categorical(group,order),double(T.CorrelatedMinusDiagonal), ...
        'MarkerStyle','.');yline(0,'k--','zero difference');xtickangle(30);
    xlabel('kernel | diagonal variance candidate');
    ylabel('correlated minus diagonal joint Gaussian NLPD');
    title('Held-out calibration-fold diagonal/correlated score difference');
    row=export_one(fig,cfg,'diagonal_vs_correlated_joint_score',{pathValue}, ...
        'publication');
end

function row=bootstrap_intervals(cfg,pathValue)
%BOOTSTRAP_INTERVALS The CaseID-cluster bootstrap interval of the tempered exponent gamma, per kernel.
%   The variance-scale panels are not drawn: they put the scales of different
%   variance models (s^2, tau^2 h, tau^2 h^gamma, of different magnitude) on
%   one linear axis. Their intervals stay in the saved table.
    T=saved_table(pathValue,{'Kernel','Quantity','Candidate','OutputIndex', ...
        'Output','FiniteBootstrapReplicates','CentralEstimate','Q025','Q975'});
    finite=double(T.FiniteBootstrapReplicates)>0& ...
        isfinite(double(T.CentralEstimate))&isfinite(double(T.Q025))& ...
        isfinite(double(T.Q975));T=T(finite,:);
    require_rows(T,'finite CaseID-cluster bootstrap intervals unavailable');
    kernels=ordered_text(T,'Kernel');
    gamma=T(string(T.Quantity)=="gamma",:);
    if isempty(gamma),unavailable('gamma bootstrap rows unavailable');end
    st=plotting.style();
    fig=figure('Visible','off','Position',[30 30 520 520]);
    hold on;
    for kernelIndex=1:numel(kernels)
        one=gamma(string(gamma.Kernel)==kernels(kernelIndex),:);
        if isempty(one),continue;end
        center=double(one.CentralEstimate(1));lo=double(one.Q025(1));hi=double(one.Q975(1));
        errorbar(kernelIndex,center,center-lo,hi-center,'o', ...
            'Color',palette(st,kernelIndex),'MarkerFaceColor',palette(st,kernelIndex));
    end
    % Fixed x-limits: automatic limits of these error bars varied between MATLAB
    % sessions.
    xticks(1:numel(kernels));xticklabels(kernels);xtickangle(25);ylim([0 1]);
    xlim([0.5 numel(kernels)+0.5]);
    ylabel('shared tempered exponent \gamma');
    title('CaseID-cluster bootstrap interval of \gamma');
    row=export_one(fig,cfg,'variance_scale_gamma_bootstrap_intervals', ...
        {pathValue},'publication');
end
function row=export_one(fig,cfg,name,sources,scope)
    row=plotting.export_saved_figure(fig,cfg,'surrogate/quality_audit', ...
        name,sources,scope,[]);
end

function [center,spread]=output_summary(T,kernel,outputs,metric)
    center=nan(numel(outputs),1);spread=center;
    for outputIndex=1:numel(outputs)
        selected=string(T.Kernel)==kernel&string(T.Output)==outputs(outputIndex);
        values=double(T.(metric)(selected));center(outputIndex)=mean(values,'omitnan');
        spread(outputIndex)=std(values,0,'omitnan');
    end
end

function T=saved_table(pathValue,required)
    if ~isfile(pathValue),unavailable("missing saved source: "+string(pathValue));end
    try
        [~,~,extension]=fileparts(pathValue);
        if strcmpi(extension,'.mat')
            % The shipped results hold the two largest audit tables as
            % compressed MAT: exactly the table readtable returns for the CSV,
            % stored as plain values (utils.plain_mat_encode).
            saved=utils.load_plain_mat(pathValue,'T');T=saved.T;
        else
            T=readtable(pathValue,'TextType','string','Delimiter',',', ...
                'VariableNamingRule','preserve');
        end
    catch ME
        unavailable("unreadable saved table: "+string(ME.message));
    end
    if isempty(T)||height(T)==0||~all(ismember(required,T.Properties.VariableNames))
        unavailable("saved table empty or lacks required factual columns: "+ ...
            string(pathValue));
    end
end

function require_rows(T,reason)
    if isempty(T)||height(T)==0,unavailable(reason);end
end

function unavailable(reason)
    error('plotting:saved_surrogate_quality_audit_figures:Unavailable','%s', ...
        char(string(reason)));
end

function outputs=ordered_outputs(T)
    if isempty(T),outputs=strings(1,0);return;end
    [~,rows]=unique(double(T.OutputIndex),'stable');
    [~,order]=sort(double(T.OutputIndex(rows)));outputs=string(T.Output(rows(order))).';
end

function outputs=ordered_matrix_outputs(T)
    [~,rows]=unique(double(T.OutputIndex1),'stable');
    [~,order]=sort(double(T.OutputIndex1(rows)));outputs=string(T.Output1(rows(order))).';
end

function values=ordered_text(T,name)
    if isempty(T),values=strings(1,0);else,values=unique(string(T.(name)),'stable').';end
end

function output_ticks(outputs)
    xticks(1:numel(outputs));xticklabels(outputs);xtickangle(28);
end

function value=offset(index,count)
    value=(index-(count+1)/2)*min(.18,.72/max(count,1));
end

function value=palette(st,index)
    value=st.palette(1+mod(index-1,size(st.palette,1)),:);
end

function value=logical_column(column)
    if islogical(column)
        value=column;
    elseif isnumeric(column)
        value=column~=0;
    else
        value=ismember(lower(string(column)),["true" "1" "yes"]);
    end
end

function row=availability_row(name,scope,generated,reason,sources)
    row=table(string(name),string(scope),logical(generated),string(reason), ...
        strjoin(string(sources),' | '),'VariableNames', ...
        {'Figure','Scope','Generated','ExclusionReason','SourceArtifacts'});
end

function finish_outputs(root,mode,manifest,availability)
    inventoryPath=fullfile(root,'surrogate_quality_audit_figure_inventory.csv');
    availabilityPath=fullfile(root, ...
        'surrogate_quality_audit_figure_availability.csv');
    utils.atomic_write_table(inventoryPath,manifest);
    utils.atomic_write_table(availabilityPath,availability);
    status=struct('schema_version', ...
        'saved_surrogate_quality_audit_figures_status_v3', ...
        'status','complete','mode',mode, ...
        'generated_figure_count',height(manifest), ...
        'skipped_figure_count',sum(~availability.Generated), ...
        'source_tables_only',true,'model_mat_files_loaded',0, ...
        'gp_evaluations_performed',0,'surrogate_fits_performed',0, ...
        'cross_validation_runs_performed',0, ...
        'numbered_stage_runs_performed',0, ...
        'likelihood_evaluations_performed',0,'mcmc_runs_performed',0, ...
        'numerical_stage_outputs_modified',false);
    utils.atomic_write_json(fullfile(root, ...
        'surrogate_quality_audit_figures_status.json'),status, ...
        'AllowReplace',true);
end

function paths=source_paths(root)
    paths=struct( ...
        'cvPerFold',fullfile(root,'kernel_cross_validation', ...
            'kernel_cv_metrics_per_fold.csv'), ...
        'cvPooled',fullfile(root,'kernel_cross_validation', ...
            'kernel_cv_metrics_pooled_oof.csv'), ...
        'sameMean',fullfile(root,'same_data_seed_stability', ...
            'same_data_mean_stability.csv'), ...
        'sameSD',fullfile(root,'same_data_seed_stability', ...
            'same_data_sd_stability.csv'), ...
        'convergence',fullfile(root,'training_convergence', ...
            'training_convergence_per_output_metrics.csv'), ...
        'crossfitMetrics',fullfile(root,'calibration_crossfit', ...
            'variance_calibration_crossfit_metrics.csv'), ...
        'localBins',fullfile(root,'variance_model_comparison', ...
            'local_shape_calibration_bins.csv'), ...
        'qq',table_file(root,'residual_distribution','qq_data'), ...
        'pit',table_file(root,'residual_distribution','pit_data'), ...
        'correlation',fullfile(root,'residual_correlation', ...
            'residual_correlation_shrunk.csv'), ...
        'jointScore',fullfile(root,'residual_correlation', ...
            'diagonal_vs_correlated_score_comparison.csv'), ...
        'bootstrap',fullfile(root,'variance_model_comparison', ...
            'cluster_bootstrap_intervals.csv'), ...
        'status',fullfile(root,'status','surrogate_quality_audit_status.json'));
end

function [complete,reason]=source_status_complete(pathValue)
    complete=false;reason="source_status_missing_or_unreadable";
    if ~isfile(pathValue),return;end
    try
        status=jsondecode(fileread(pathValue));
    catch
        return
    end
    if ~isstruct(status)||~isscalar(status),reason="source_status_invalid";return;end
    if isfield(status,'status')
        value=lower(string(status.status));complete=startsWith(value,"complete");
        if complete,reason="";else,reason="source_status_"+value;end
    else
        reason="source_status_has_no_status_field";
    end
end

function value=scope_in_mode(scope,mode)
    order=struct('aggregate',1,'publication',2,'full',3);
    value=order.(mode)>=order.(scope);
end

function pathValue=table_file(root,folder,stem)
%TABLE_FILE Saved audit table: the CSV of a run, or its MAT copy when shipped.
    pathValue=fullfile(root,folder,[stem '.csv']);
    matPath=fullfile(root,folder,[stem '.mat']);
    if ~isfile(pathValue)&&isfile(matPath),pathValue=matPath;end
end

function root=audit_root(cfg)
    root=study.source_folder(cfg,'surrogate_audit');
end

function value=audit_enabled(cfg)
    value=isfield(cfg,'stage2')&& ...
        isfield(cfg.stage2,'runSurrogateQualityAudit')&& ...
        logical(cfg.stage2.runSurrogateQualityAudit);
end

function value=option_text(options,name,fallback)
    value=fallback;if isfield(options,name),value=options.(name);end
    value=lower(char(string(value)));
end

function value=default_mode(cfg)
%DEFAULT_MODE The figure mode of the settings (0.4).
    value=cfg.fig.mode;
end

function T=empty_manifest()
    T=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5), ...
        'VariableNames',{'Category','Figure','RelativePath','Scope', ...
        'SourceArtifacts'});
end
