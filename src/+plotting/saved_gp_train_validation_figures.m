function manifest = saved_gp_train_validation_figures(cfg,options)
%SAVED_GP_TRAIN_VALIDATION_FIGURES The GP's predictions of the training and the held-out cases.
%   MANIFEST = plotting.saved_gp_train_validation_figures(CFG, OPTIONS) draws,
%   from the saved predictions of the training cases and of the held-out
%   cases, the GP against COMSOL for both cohorts per output, and returns
%   the manifest. The cohorts' metric table is not drawn (see below).
%   Side effects: writes the figures and closes them.
%   Computation: seconds.

    if nargin<2,options=struct();end
    assert(isstruct(options)&&isscalar(options), ...
        'plotting:saved_gp_train_validation_figures:Options', ...
        'The options must be one struct.');
    predictionPath=fullfile(study.source_folder(cfg, ...
        'surrogate_assessment'),'validation_predictions.csv');
    trainingPath=fullfile(study.source_folder(cfg, ...
        'surrogate_training_predictions'),'gp_training_predictions.csv');
    if ~isfile(predictionPath)||~isfile(trainingPath)
        manifest=empty_manifest();return;
    end
    training=readtable(trainingPath,'Delimiter',',','TextType','string');
    validation=readtable(predictionPath,'Delimiter',',','TextType','string');
    outputs=unique(string(validation.Output),'stable');parts={};
    parts{end+1}=gp_train_validation_figure( ...
        training,validation,outputs,cfg,{trainingPath,predictionPath});
    % The metrics of the two cohorts (gp_train_validation_metrics.csv) are
    % not drawn: the training metrics measure interpolation (about 1e-7
    % mbar) and each cohort's NRMSE divides by its own truth range.
    manifest=vertcat(parts{:});
end

function row=gp_train_validation_figure(training,validation,outputs,cfg,sources)
    required={'OutputIndex','Output','COMSOL','GPMean', ...
        'CalibratedEmulatorVariance'};
    assert(all(ismember(required,training.Properties.VariableNames))&& ...
        all(ismember(required,validation.Properties.VariableNames)), ...
        'plotting:saved_gp_train_validation_figures:PredictionSchema', ...
        ['The saved predictions %s need the columns %s; rerun the step that wrote ' ...
         'them.'],strjoin(cellstr(string(sources)),' and '),strjoin(required,', '));
    assert(isequal(unique(string(training.Output),'stable'),string(outputs))&& ...
        isequal(unique(string(validation.Output),'stable'),string(outputs)), ...
        'plotting:saved_gp_train_validation_figures:OutputOrder', ...
        'The saved predictions must list the six outputs in the study''s order.');
    colors=[0.00 0.45 0.70;0.85 0.33 0.10];
    validationCaseCount=numel(unique(double(validation.CaseID)));
    fig=figure('Position',[80 80 1100 650]);
    tiledlayout(2,ceil(numel(outputs)/2),'Padding','compact', ...
        'TileSpacing','compact');
    for i=1:numel(outputs)
        nexttile;trainingRows=string(training.Output)==string(outputs(i));
        validationRows=string(validation.Output)==string(outputs(i));
        trainingTruth=double(training.COMSOL(trainingRows));
        trainingPrediction=double(training.GPMean(trainingRows));
        validationTruth=double(validation.COMSOL(validationRows));
        validationPrediction=double(validation.GPMean(validationRows));
        trainingHandle=scatter(trainingTruth,trainingPrediction,20, ...
            colors(1,:),'filled','MarkerFaceAlpha',0.60);hold on;
        validationHandle=scatter(validationTruth,validationPrediction,34, ...
            colors(2,:),'filled','MarkerEdgeColor','k','LineWidth',0.4);
        limits=[min([trainingTruth;trainingPrediction;validationTruth; ...
            validationPrediction]) max([trainingTruth;trainingPrediction; ...
            validationTruth;validationPrediction])];
        if limits(1)==limits(2)
            delta=max(1,abs(limits(1)))*1e-6;limits=limits+[-delta delta];
        end
        diagonal=plot(limits,limits,'k--','LineWidth',1.1);
        axis square;xlim(limits);ylim(limits);grid on;
        title(outputs(i),'Interpreter','none');xlabel('COMSOL [mbar]');
        ylabel('GP prediction [mbar]');
        if i==1
            legend([trainingHandle validationHandle diagonal], ...
                {'training cases',sprintf('%d held-out validation cases', ...
                validationCaseCount), ...
                'perfect prediction'},'Location','best');
        end
    end
    sgtitle('GP training and held-out validation predictions');
    row=plotting.export_saved_figure(fig,cfg,'surrogate', ...
        'predicted_vs_comsol_gp',sources,'publication',[]);
end

function T=empty_manifest()
    T=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5), ...
        'VariableNames',{'Category','Figure','RelativePath','Scope', ...
        'SourceArtifacts'});
end
