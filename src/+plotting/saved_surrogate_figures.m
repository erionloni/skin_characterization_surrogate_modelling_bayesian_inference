function manifest = saved_surrogate_figures(cfg,options)
%SAVED_SURROGATE_FIGURES The figures of the fixed surrogates' assessment, from its saved tables.
%   MANIFEST = plotting.saved_surrogate_figures(CFG, OPTIONS) draws, from the
%   saved assessment tables (no fit, no prediction), the predictions of the
%   GP and PCE against COMSOL, the residuals and their Q-Q plot, the
%   predictive coverage, the GP-PCE comparison and the training against
%   held-out metrics, and returns the manifest.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.
    parts={};
    predictionPath=fullfile(study.source_folder(cfg, ...
        'surrogate_assessment'),'validation_predictions.csv');
    if isfile(predictionPath)
        T=readtable(predictionPath,'Delimiter',',','TextType','string');
        required={'Output','COMSOL','GPMean','GPResidual', ...
            'CalibratedEmulatorSD','CalibratedStandardizedResidual', ...
            'PCEMean','PCEResidual'};
        assert(all(ismember(required,T.Properties.VariableNames)), ...
            'plotting:saved_surrogate_figures:PredictionSchema', ...
            'The saved table %s lacks the column(s) %s; rerun the step ''surrogate_assessment''.', ...
            char(string(predictionPath)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
        outputs=unique(T.Output,'stable');
        gpReporting=plotting.saved_gp_train_validation_figures(cfg,options);
        if isempty(gpReporting)
            parts{end+1}=predicted_figure(T,outputs,'GPMean','GP', ...
                'predicted_vs_comsol_gp',cfg,predictionPath,'publication');
        else
            parts{end+1}=gpReporting;
        end
        if ~strcmp(options.Mode,'publication')
            parts{end+1}=predicted_figure(T,outputs,'PCEMean','PCE', ...
                'predicted_vs_comsol_pce',cfg,predictionPath,'aggregate');
            parts{end+1}=residual_pattern_figure(T,outputs,cfg,predictionPath);
            parts{end+1}=residual_figure(T,outputs,cfg,predictionPath);
            parts{end+1}=comparison_figure(T,outputs,cfg,predictionPath);
            parts{end+1}=predictive_coverage_figure( ...
                T,outputs,cfg,predictionPath);
        end
    end
    manifest=combine(parts);
end

function row=predicted_figure(T,outputs,predictionVariable,label,name,cfg, ...
        source,scope)
    fig=figure('Position',[80 80 1100 650]);
    tiledlayout(2,ceil(numel(outputs)/2),'Padding','compact', ...
        'TileSpacing','compact');
    for i=1:numel(outputs)
        nexttile;rows=T.Output==outputs(i);
        observed=double(T.COMSOL(rows));predicted=double(T.(predictionVariable)(rows));
        scatter(observed,predicted,28,'filled');hold on;
        limits=[min([observed;predicted]) max([observed;predicted])];
        plot(limits,limits,'k--');axis square;xlim(limits);ylim(limits);
        title(outputs(i),'Interpreter','none');xlabel('COMSOL [mbar]');
        ylabel([label ' prediction [mbar]']);
    end
    sgtitle([label ' frozen-validation predictions']);
    row=plotting.export_saved_figure(fig,cfg,'surrogate',name,{source},scope,[]);
end

function row=residual_figure(T,outputs,cfg,source)
    fig=figure('Position',[80 80 1100 650]);
    tiledlayout(2,ceil(numel(outputs)/2),'Padding','compact', ...
        'TileSpacing','compact');
    for i=1:numel(outputs)
        nexttile;rows=T.Output==outputs(i);
        values=sort(double(T.CalibratedStandardizedResidual(rows)));
        values=values(isfinite(values));n=numel(values);
        probabilities=((1:n).'-0.5)/max(n,1);
        theoretical=sqrt(2)*erfinv(2*probabilities-1);
        scatter(theoretical,values,24,'filled');hold on;
        limits=[min([theoretical;values]) max([theoretical;values])];
        plot(limits,limits,'k--');axis square;
        title(outputs(i),'Interpreter','none');xlabel('normal quantile');
        ylabel('GP standardized residual');
    end
    sgtitle('Frozen-validation GP residual Q-Q diagnostics');
    row=plotting.export_saved_figure(fig,cfg,'surrogate', ...
        'residual_qq_gp',{source},'aggregate',[]);
end

function row=residual_pattern_figure(T,outputs,cfg,source)
    fig=figure('Position',[80 80 1100 650]);
    tiledlayout(2,ceil(numel(outputs)/2),'Padding','compact', ...
        'TileSpacing','compact');
    for i=1:numel(outputs)
        nexttile;rows=T.Output==outputs(i);
        observed=double(T.COMSOL(rows));
        scatter(observed,double(T.GPResidual(rows)),22,'filled');hold on;
        scatter(observed,double(T.PCEResidual(rows)),22,'filled');yline(0,'k--');
        xlabel('COMSOL [mbar]');ylabel('prediction residual [mbar]');
        title(outputs(i),'Interpreter','none');
    end
    legend({'GP','PCE'},'Location','southoutside','Orientation','horizontal');
    sgtitle('Frozen-validation residual patterns');
    row=plotting.export_saved_figure(fig,cfg,'surrogate', ...
        'residuals_gp_pce',{source},'aggregate',[]);
end

function row=comparison_figure(T,outputs,cfg,source)
    gp=zeros(numel(outputs),1);pce=gp;
    for i=1:numel(outputs)
        rows=T.Output==outputs(i);truth=double(T.COMSOL(rows));
        gp(i)=r_squared(truth,double(T.GPMean(rows)));
        pce(i)=r_squared(truth,double(T.PCEMean(rows)));
    end
    fig=figure('Position',[100 100 1000 480]);
    bar([gp pce]);xticks(1:numel(outputs));xticklabels(outputs);
    xtickangle(20);ylabel('validation R^2');legend({'GP','PCE'}, ...
        'Location','southoutside','Orientation','horizontal');
    title('Canonical GP/PCE frozen-validation comparison');
    row=plotting.export_saved_figure(fig,cfg,'surrogate', ...
        'gp_pce_comparison',{source},'aggregate',[]);
end

function row=predictive_coverage_figure(T,outputs,cfg,source)
    coverage=nan(numel(outputs),1);
    for i=1:numel(outputs)
        rows=T.Output==outputs(i);
        residual=abs(double(T.GPResidual(rows)));
        predictiveStd=double(T.CalibratedEmulatorSD(rows));
        finite=isfinite(residual)&isfinite(predictiveStd);
        if any(finite)
            coverage(i)=100*mean(residual(finite)<=1.96*predictiveStd(finite));
        end
    end
    fig=figure('Position',[100 100 900 450]);
    bar(coverage);hold on;yline(95,'k--','95% nominal');ylim([0 105]);
    xticks(1:numel(outputs));xticklabels(outputs);xtickangle(20);
    ylabel('empirical validation coverage [%]');
    title('Production calibrated GP 95% interval coverage');
    row=plotting.export_saved_figure(fig,cfg,'surrogate', ...
        'gp_predictive_coverage',{source},'aggregate',[]);
end

function value=r_squared(truth,prediction)
    denominator=sum((truth-mean(truth)).^2);
    value=1-sum((truth-prediction).^2)/denominator;
end

function T=combine(parts)
    if isempty(parts)
        T=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5), ...
            'VariableNames',{'Category','Figure','RelativePath','Scope', ...
            'SourceArtifacts'});
    else
        T=vertcat(parts{:});
    end
end
