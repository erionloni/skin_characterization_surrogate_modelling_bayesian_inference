function manifest=saved_default_protocol_cross_route_figures(cfg)
%SAVED_DEFAULT_PROTOCOL_CROSS_ROUTE_FIGURES The figures of the default-protocol comparison.
%   MANIFEST = plotting.saved_default_protocol_cross_route_figures(CFG) draws,
%   from the saved comparison tables of the generalized surrogates at the
%   default protocol against the fixed route's COMSOL results, the GP and
%   PCE against COMSOL, the per-output residuals, the interval coverage, the
%   error against the distance to the training support and the worst cases,
%   and returns the manifest.
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    assert(strcmp(cfg.dataMode,'real_extended'), ...
        'plotting:saved_default_protocol_cross_route_figures:Route', ...
        ['This renderer works on the generalized route ' ...
         '(study.project_config(S,''Route'',''real_extended'')); the configuration is for ' ...
         'route ''%s''.'],cfg.dataMode);
    root=study.source_folder(cfg,'default_protocol_comparison');
    predictionPath=fullfile(root,'default_protocol_predictions.csv');
    gpMetricPath=fullfile(root,'default_protocol_gp_metrics.csv');
    gpRawMetricPath=fullfile(root, ...
        'default_protocol_gp_metrics_raw_uqlab.csv');
    pceMetricPath=fullfile(root,'default_protocol_pce_metrics.csv');
    worstPath=fullfile(root,'default_protocol_worst_cases.csv');
    statusPath=fullfile(root,'default_protocol_comparison_status.json');
    required={predictionPath,gpMetricPath,gpRawMetricPath,pceMetricPath, ...
        worstPath,statusPath};
    assert(all(cellfun(@isfile,required)), ...
        'plotting:saved_default_protocol_cross_route_figures:Sources', ...
        ['The default-protocol comparison lacks the saved file(s) %s; rerun the step ' ...
         '''default_protocol_comparison''.'],strjoin(required(~cellfun(@isfile,required)),', '));
    status=jsondecode(fileread(statusPath));
    % A changed numerical status may suppress a formerly rendered family:
    % images this pass does not write again are removed once it finished,
    % so stale plots cannot enter its receipt (CLN-056).
    before=plotting.family_images(fullfile(cfg.paths.defaultProtocolCrossRoute, ...
        'figures','default_protocol_cross_route'));
    if ~startsWith(string(status.status),'completed')
        manifest=empty_manifest();
        plotting.remove_stale_images(before);
        finish_outputs(cfg,manifest,statusPath);return
    end
    T=readtable(predictionPath,'Delimiter',',','TextType','string');
    W=readtable(worstPath,'Delimiter',',','TextType','string');
    statusLabel=string(status.compatibility_status)+ ...
        " | development-only cross-route reference";
    requiredColumns={'Output','FixedCOMSOLTruth_mbar', ...
        'GeneralizedGPMean_mbar','GeneralizedPCEMean_mbar', ...
        'GPResidual_mbar','PCEResidual_mbar','GPAbsoluteError_mbar', ...
        'PCEAbsoluteError_mbar','NearestGeneralizedTrainingDistance', ...
        'PrimaryExternalSliceIncluded','GPCalibratedIncluded50', ...
        'GPCalibratedIncluded80','GPCalibratedIncluded90', ...
        'GPCalibratedIncluded95','GPRawUQLabIncluded50', ...
        'GPRawUQLabIncluded80','GPRawUQLabIncluded90', ...
        'GPRawUQLabIncluded95'};
    assert(all(ismember(requiredColumns,T.Properties.VariableNames)), ...
        'plotting:saved_default_protocol_cross_route_figures:Schema', ...
        'The saved table %s lacks the column(s) %s; rerun the step ''default_protocol_comparison''.', ...
        char(string(predictionPath)),strjoin(setdiff(requiredColumns,T.Properties.VariableNames),', '));
    plotting.style();outputs=unique(T.Output,'stable');
    parts=cell(6,1);
    parts{1}=predicted_vs_comsol(T,outputs,'GeneralizedGPMean_mbar', ...
        'generalized GP','gp_vs_fixed_comsol',cfg,predictionPath,statusLabel);
    parts{2}=predicted_vs_comsol(T,outputs,'GeneralizedPCEMean_mbar', ...
        'generalized PCE','pce_vs_fixed_comsol',cfg,predictionPath,statusLabel);
    parts{3}=residual_comparison(T,outputs,cfg,predictionPath,statusLabel);
    parts{4}=error_vs_support(T,cfg,predictionPath,statusLabel);
    parts{5}=coverage_by_output(T,outputs,cfg,predictionPath,statusLabel);
    parts{6}=worst_case_summary(W,cfg,worstPath,statusLabel);
    manifest=vertcat(parts{:});
    manifest.CompatibilityStatus=repmat( ...
        string(status.compatibility_status),height(manifest),1);
    manifest.EvidenceScope=repmat( ...
        "development_only_cross_route_reference",height(manifest),1);
    plotting.remove_stale_images(before);
    finish_outputs(cfg,manifest,statusPath);
end

function row=predicted_vs_comsol(T,outputs,field,label,name,cfg,source,statusLabel)
    fig=figure('Visible','off','Position',[50 50 1120 650]);
    tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
    for i=1:numel(outputs)
        nexttile;take=T.Output==outputs(i)&T.PrimaryExternalSliceIncluded;
        truth=double(T.FixedCOMSOLTruth_mbar(take));
        prediction=double(T.(field)(take));valid=isfinite(truth)&isfinite(prediction);
        scatter(truth(valid),prediction(valid),24,'filled');hold on;
        limits=safe_limits([truth(valid);prediction(valid)]);
        plot(limits,limits,'k--');xlim(limits);ylim(limits);axis square;
        title(outputs(i),'Interpreter','none');xlabel('fixed COMSOL [mbar]');
        ylabel([label ' [mbar]']);
    end
    sgtitle(string(label)+" at the configured default protocol | "+statusLabel, ...
        'Interpreter','none');
    row=export_one(fig,cfg,name,{source});
end

function row=residual_comparison(T,outputs,cfg,source,statusLabel)
    values=nan(numel(outputs),2);
    for i=1:numel(outputs)
        take=T.Output==outputs(i)&T.PrimaryExternalSliceIncluded;
        values(i,1)=mean(abs(double(T.GPResidual_mbar(take))),'omitnan');
        values(i,2)=mean(abs(double(T.PCEResidual_mbar(take))),'omitnan');
    end
    fig=figure('Visible','off','Position',[70 70 1000 500]);bar(values);
    xticks(1:numel(outputs));xticklabels(outputs);xtickangle(20);
    ylabel('mean absolute residual [mbar]');
    legend({'generalized GP','generalized PCE'},'Location','southoutside', ...
        'Orientation','horizontal');
    title("Default-protocol residual magnitude by output | "+statusLabel, ...
        'Interpreter','none');
    row=export_one(fig,cfg,'per_output_residual_comparison',{source});
end

function row=error_vs_support(T,cfg,source,statusLabel)
    one=T(T.PrimaryExternalSliceIncluded,:);
    fig=figure('Visible','off','Position',[70 70 1000 480]);hold on;
    scatter(double(one.NearestGeneralizedTrainingDistance), ...
        double(one.GPAbsoluteError_mbar),20,'filled');
    scatter(double(one.NearestGeneralizedTrainingDistance), ...
        double(one.PCEAbsoluteError_mbar),20,'filled');
    xlabel('nearest generalized-development distance');
    ylabel('absolute error [mbar]');
    legend({'generalized GP','generalized PCE'},'Location','best');
    title("Default-protocol error versus generalized support distance | "+ ...
        statusLabel,'Interpreter','none');
    row=export_one(fig,cfg,'error_vs_support_distance',{source});
end

function row=coverage_by_output(T,outputs,cfg,source,statusLabel)
    calibratedFields={'GPCalibratedIncluded50', ...
        'GPCalibratedIncluded80','GPCalibratedIncluded90', ...
        'GPCalibratedIncluded95'};
    rawFields={'GPRawUQLabIncluded50','GPRawUQLabIncluded80', ...
        'GPRawUQLabIncluded90','GPRawUQLabIncluded95'};
    calibrated=nan(numel(outputs),numel(calibratedFields));
    raw=nan(numel(outputs),numel(rawFields));
    for i=1:numel(outputs)
        take=T.Output==outputs(i)&T.PrimaryExternalSliceIncluded;
        for j=1:numel(calibratedFields)
            calibrated(i,j)=100*mean(logical( ...
                T.(calibratedFields{j})(take)));
            raw(i,j)=100*mean(logical(T.(rawFields{j})(take)));
        end
    end
    fig=figure('Visible','off','Position',[70 70 1120 720]);
    tiledlayout(2,1,'Padding','compact','TileSpacing','compact');
    coverage_panel(calibrated,outputs, ...
        'Active tempered-local calibrated emulator uncertainty');
    coverage_panel(raw,outputs,'Raw UQLab uncertainty reference');
    sgtitle("Default-protocol empirical interval inclusion | "+statusLabel, ...
        'Interpreter','none');
    row=export_one(fig,cfg,'interval_coverage_by_output',{source});
end

function coverage_panel(values,outputs,titleText)
    nexttile;bar(values);ylim([0 105]);
    xticks(1:numel(outputs));xticklabels(outputs);xtickangle(20);
    ylabel('empirical inclusion [%]');
    legend({'50%','80%','90%','95%'},'Location','eastoutside');
    title(titleText,'Interpreter','none');
end

function row=worst_case_summary(W,cfg,source,statusLabel)
    value=double(W.NormalizedAbsoluteError);
    labels=string(W.Family)+" | "+string(W.Output)+" | Case "+string(W.CaseID);
    fig=figure('Visible','off','Position',[70 70 1120 560]);barh(value);
    yticks(1:numel(labels));yticklabels(labels);
    xlabel('maximum normalized absolute error');
    title("Worst-case provenance by surrogate family and output | "+ ...
        statusLabel,'Interpreter','none');
    row=export_one(fig,cfg,'worst_case_provenance',{source});
end

function row=export_one(fig,cfg,name,sources)
    local=cfg;local.paths.stage07=fullfile( ...
        cfg.paths.defaultProtocolCrossRoute,'figures');
    row=plotting.export_saved_figure(fig,local, ...
        'default_protocol_cross_route',name,sources,'publication',[]);
end

function finish_outputs(cfg,manifest,statusSource)
    root=fullfile(cfg.paths.defaultProtocolCrossRoute,'figures');
    if ~isfolder(root),mkdir(root);end
    inventory=fullfile(root,'default_protocol_figure_inventory.csv');
    utils.atomic_write_table(inventory,manifest);
    numerical=jsondecode(fileread(statusSource));
    status=struct('schema_version', ...
        'default_protocol_cross_route_figures_status_v2', ...
        'status','complete','generated_figure_count',height(manifest), ...
        'source_numerical_status',numerical.status, ...
        'compatibility_status',numerical.compatibility_status, ...
        'saved_table_only',true,'gp_evaluations',0,'pce_evaluations',0, ...
        'model_fits',0);
    utils.atomic_write_json(fullfile(root, ...
        'default_protocol_figures_status.json'),status,'AllowReplace',true);
end

function T=empty_manifest()
    T=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5), ...
        'VariableNames',{'Category','Figure','RelativePath','Scope', ...
        'SourceArtifacts'});
end

function limits=safe_limits(values)
    values=values(isfinite(values));
    if isempty(values),limits=[0 1];return;end
    limits=[min(values) max(values)];
    if limits(1)==limits(2)
        delta=max(1,abs(limits(1)))*0.05;limits=limits+[-delta delta];
    end
end
