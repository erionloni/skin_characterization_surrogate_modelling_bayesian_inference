function manifest=saved_generalized_surrogate_figures(cfg)
%SAVED_GENERALIZED_SURROGATE_FIGURES The figures of the generalized surrogates' assessment.
%   MANIFEST = plotting.saved_generalized_surrogate_figures(CFG) draws, from
%   the saved assessment tables of the approved generalized surrogates, the
%   predictions against COMSOL (GP and PCE), the residuals and their Q-Q
%   plot, the predictive coverage, the per-output error summary and the
%   training, cross-validation and held-out comparison, and returns the
%   manifest.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    assert(strcmp(cfg.dataMode,'real_extended'), ...
        'plotting:saved_generalized_surrogate_figures:Route', ...
        ['This renderer works on the generalized route ' ...
         '(study.project_config(S,''Route'',''real_extended'')); the configuration is for ' ...
         'route ''%s''.'],cfg.dataMode);
    plotting.style();
    root=study.source_folder(cfg,'surrogate_assessment');
    predictionPath=fullfile(root,'validation_predictions.csv');
    cohortPath=fullfile(root,'training_cv_internal_heldout_metrics.csv');
    assert(isfile(predictionPath)&&isfile(cohortPath), ...
        'plotting:saved_generalized_surrogate_figures:MissingTables', ...
        ['The generalized assessment lacks %s or %s; rerun the step ' ...
         '''surrogate_assessment''.'],predictionPath,cohortPath);
    % Only this family's images; stale ones are removed once it finished.
    before=plotting.family_images(fullfile(cfg.paths.stage02,'validation','figures','surrogate'));
    T=readtable(predictionPath,'Delimiter',',','TextType','string');
    C=readtable(cohortPath,'Delimiter',',','TextType','string');
    required={'Output','COMSOL','GPMean','PCEMean','GPResidual', ...
        'PCEResidual','CalibratedEmulatorSD', ...
        'CalibratedStandardizedResidual','CalibratedIncluded50', ...
        'CalibratedIncluded80','CalibratedIncluded90', ...
        'CalibratedIncluded95'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'plotting:saved_generalized_surrogate_figures:PredictionSchema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''surrogate_assessment''.', ...
        char(string(predictionPath)),strjoin(setdiff(required,T.Properties.VariableNames),', '));
    outputs=unique(T.Output,'stable');parts=cell(7,1);
    parts{1}=prediction_figure(T,outputs,'GPMean','GP', ...
        'predicted_vs_comsol_gp',cfg,predictionPath);
    parts{2}=prediction_figure(T,outputs,'PCEMean','PCE', ...
        'predicted_vs_comsol_pce',cfg,predictionPath);
    parts{3}=residual_pattern(T,outputs,cfg,predictionPath);
    parts{4}=qq_figure(T,outputs,cfg,predictionPath);
    parts{5}=coverage_figure(T,outputs,cfg,predictionPath);
    parts{6}=error_summary(C,outputs,cfg,cohortPath);
    parts{7}=cohort_comparison(C,outputs,cfg,cohortPath);
    manifest=vertcat(parts{:});
    plotting.remove_stale_images(before);
end

function row=prediction_figure(T,outputs,field,label,name,cfg,source)
    fig=figure('Position',[80 80 1100 650]);
    tiledlayout(2,ceil(numel(outputs)/2),'Padding','compact', ...
        'TileSpacing','compact');
    for i=1:numel(outputs)
        nexttile;take=T.Output==outputs(i);
        truth=double(T.COMSOL(take));prediction=double(T.(field)(take));
        valid=isfinite(truth)&isfinite(prediction);
        scatter(truth(valid),prediction(valid),25,'filled');hold on;
        limits=safe_limits([truth(valid);prediction(valid)]);
        plot(limits,limits,'k--');xlim(limits);ylim(limits);axis square;
        title(outputs(i),'Interpreter','none');xlabel('COMSOL [mbar]');
        ylabel(label+" prediction [mbar]");
    end
    sgtitle(label+" "+assessment_label(T)+" predictions");
    row=export_stage2(fig,cfg,name,{source},'publication');
end

function row=residual_pattern(T,outputs,cfg,source)
    fig=figure('Position',[80 80 1100 650]);
    tiledlayout(2,ceil(numel(outputs)/2),'Padding','compact', ...
        'TileSpacing','compact');
    for i=1:numel(outputs)
        nexttile;take=T.Output==outputs(i);
        truth=double(T.COMSOL(take));
        scatter(truth,double(T.GPResidual(take)),20,'filled');hold on;
        scatter(truth,double(T.PCEResidual(take)),20,'filled');yline(0,'k--');
        title(outputs(i),'Interpreter','none');xlabel('COMSOL [mbar]');
        ylabel('prediction residual [mbar]');
    end
    legend({'GP','PCE'},'Location','southoutside','Orientation','horizontal');
    sgtitle(assessment_label(T)+" GP/PCE residuals");
    row=export_stage2(fig,cfg,'residuals_gp_pce',{source},'aggregate');
end

function row=qq_figure(T,outputs,cfg,source)
    fig=figure('Position',[80 80 1100 650]);
    tiledlayout(2,ceil(numel(outputs)/2),'Padding','compact', ...
        'TileSpacing','compact');
    for i=1:numel(outputs)
        nexttile;take=T.Output==outputs(i);
        values=sort(double(T.CalibratedStandardizedResidual(take)));
        values=values(isfinite(values));n=numel(values);
        probabilities=((1:n).'-0.5)/max(n,1);
        theoretical=sqrt(2)*erfinv(2*probabilities-1);
        scatter(theoretical,values,22,'filled');hold on;
        limits=safe_limits([theoretical;values]);plot(limits,limits,'k--');
        xlim(limits);ylim(limits);axis square;
        title(outputs(i),'Interpreter','none');xlabel('normal quantile');
        ylabel('standardized residual');
    end
    sgtitle('Tempered-calibrated GP residual Q-Q diagnostics');
    row=export_stage2(fig,cfg,'residual_qq_gp',{source},'aggregate');
end

function row=coverage_figure(T,outputs,cfg,source)
    fields={'CalibratedIncluded50','CalibratedIncluded80', ...
        'CalibratedIncluded90','CalibratedIncluded95'};
    levels=[50 80 90 95];coverage=nan(numel(outputs),numel(fields));
    for i=1:numel(outputs)
        take=T.Output==outputs(i);
        for j=1:numel(fields)
            values=T.(fields{j})(take);coverage(i,j)=100*mean(values);
        end
    end
    fig=figure('Position',[80 80 1050 500]);bar(coverage);hold on;
    xticks(1:numel(outputs));xticklabels(outputs);xtickangle(20);ylim([0 105]);
    ylabel('empirical inclusion [%]');
    legend(string(levels)+"% nominal",'Location','southoutside', ...
        'Orientation','horizontal');
    title('Tempered-calibrated GP predictive interval inclusion');
    row=export_stage2(fig,cfg,'gp_predictive_coverage',{source},'aggregate');
end

function row=error_summary(C,outputs,cfg,source)
    take=ismember(C.Cohort,["internal_heldout","external_test"]);
    G=C(take & C.Family=="gp",:);P=C(take & C.Family=="pce",:);
    G=sortrows(G,'OutputIndex');P=sortrows(P,'OutputIndex');
    fig=figure('Position',[80 80 980 480]);bar([double(G.NRMSE_range) ...
        double(P.NRMSE_range)]);xticks(1:numel(outputs));xticklabels(outputs);
    xtickangle(20);ylabel('NRMSE [held-out truth range]');
    legend({'GP','PCE'},'Location','southoutside','Orientation','horizontal');
    title('Held-out assessment error by output');
    row=export_stage2(fig,cfg,'per_output_error_summary',{source},'aggregate');
end

function row=cohort_comparison(C,outputs,cfg,source)
    G=C(C.Family=="gp",:);cohorts=["training" "cross_validation" ...
        "internal_heldout"];values=nan(numel(outputs),numel(cohorts));
    if any(G.Cohort=="external_test"),cohorts(3)="external_test";end
    for i=1:numel(outputs)
        for j=1:numel(cohorts)
            take=G.Output==outputs(i)&G.Cohort==cohorts(j);
            if nnz(take)==1,values(i,j)=double(G.NRMSE_range(take));end
        end
    end
    % A cohort without any value (the records hold no cross-validation
    % predictions of the approved GP) is left out rather than drawn as empty bars.
    kept=any(isfinite(values),1);
    fig=figure('Position',[80 80 1050 500]);bar(values(:,kept));
    xticks(1:numel(outputs));xticklabels(outputs);xtickangle(20);
    ylabel('NRMSE [cohort truth range]');legend(cohorts(kept), ...
        'Location','southoutside','Orientation','horizontal');
    heading='Canonical generalized GP training/CV/assessment comparison';
    if ~all(kept)
        heading={heading,sprintf('no GP values for %s (not drawn)', ...
            strjoin(strrep(cohorts(~kept),'_',' '),', '))};
    end
    title(heading);
    row=export_stage2(fig,cfg,'training_cv_internal_heldout',{source},'aggregate');
end

function label=assessment_label(T)
    label="internal-held-out";
    if ismember('MethodologicalRole',T.Properties.VariableNames)&& ...
            all(string(T.MethodologicalRole)=="external_test")
        label="external-test";
    end
end

function row=export_stage2(fig,cfg,name,sources,scope)
    local=cfg;local.paths.stage07=fullfile(cfg.paths.stage02, ...
        'validation','figures');
    row=plotting.export_saved_figure(fig,local,'surrogate',name,sources,scope,[]);
end

function limits=safe_limits(values)
    values=values(isfinite(values));
    if isempty(values),limits=[0 1];return;end
    limits=[min(values) max(values)];
    if limits(1)==limits(2)
        delta=max(1,abs(limits(1)))*0.05;limits=limits+[-delta delta];
    end
end
