function result = gp_train_validation_metrics( ...
        trainingPredictions,validationPredictions,outputNames)
%GP_TRAIN_VALIDATION_METRICS Factual in-sample/held-out GP comparison.
%   Both cohorts pass through the identical metric implementation. Production
%   uncertainty metrics use the frozen calibrated emulator variance; raw UQLab
%   variance is retained under explicit reference-only field names. This helper
%   never evaluates or trains a GP.
%   NRMSE_range divides each cohort's RMSE by that cohort's own truth range,
%   recorded next to it as TruthRange_mbar (the cohort size is CaseCount), so
%   the training and held-out values have different denominators; the table
%   of held-out minus training differences leaves NRMSE_range out (CLN-028).
%   R2 is likewise relative to each cohort's own truth variance.
%   RESULT = recovery.gp_train_validation_metrics(TRAININGPREDICTIONS,
%   VALIDATIONPREDICTIONS, OUTPUTNAMES) returns the metrics per output and
%   cohort and their held-out minus training differences.
%   Side effects: none.

    outputNames=reshape(string(outputNames),[],1);
    assert(~isempty(outputNames)&&numel(unique(outputNames))==numel(outputNames), ...
        'recovery:gp_train_validation_metrics:OutputNames', ...
        'The output names must be distinct and not empty.');
    training=normalize_predictions(trainingPredictions,"training",outputNames);
    validation=normalize_predictions( ...
        validationPredictions,"held_out_validation",outputNames);
    predictions=[training;validation];
    trainingMetrics=cohort_metrics(training,outputNames);
    validationMetrics=cohort_metrics(validation,outputNames);
    metrics=[trainingMetrics;validationMetrics];
    differences=metric_differences(trainingMetrics,validationMetrics);
    result=struct('predictions',predictions,'metrics',metrics, ...
        'differences',differences,'gpEvaluationsPerformed',0, ...
        'surrogateFitsPerformed',0,'scientificLabelsGenerated',false);
end

function T=normalize_predictions(input,cohort,outputNames)
    assert(istable(input), ...
        'recovery:gp_train_validation_metrics:PredictionType', ...
        'The %s predictions must be a table.',cohort);
    required={'CaseID','OutputIndex','COMSOL','GPMean', ...
        'RawUQLabVariance','CalibratedEmulatorVariance'};
    assert(all(ismember(required,input.Properties.VariableNames)), ...
        'recovery:gp_train_validation_metrics:PredictionSchema', ...
        'Prediction tables require: %s.',strjoin(required,', '));
    n=height(input);CaseID=double(input.CaseID(:));
    OutputIndex=double(input.OutputIndex(:));
    uniqueKeys=unique([CaseID OutputIndex],'rows');
    assert(n>0&&all(isfinite(CaseID))&&all(CaseID==fix(CaseID))&& ...
        all(ismember(OutputIndex,1:numel(outputNames)))&& ...
        size(uniqueKeys,1)==n, ...
        'recovery:gp_train_validation_metrics:PredictionKeys', ...
        ['The %s predictions need one row per case and output, with integer case ' ...
         'IDs and output indices 1 to %d.'],cohort,numel(outputNames));
    if ismember('SourceRow',input.Properties.VariableNames)
        SourceRow=double(input.SourceRow(:));
    else
        SourceRow=nan(n,1);
    end
    Output=outputNames(OutputIndex);
    if ismember('Output',input.Properties.VariableNames)
        supplied=string(input.Output(:));
        assert(all(supplied==Output), ...
            'recovery:gp_train_validation_metrics:OutputOrder', ...
            'The Output column of the %s predictions does not match their output indices.',cohort);
    end
    COMSOL=double(input.COMSOL(:));GPMean=double(input.GPMean(:));
    RawUQLabVariance=double(input.RawUQLabVariance(:));
    CalibratedEmulatorVariance=double( ...
        input.CalibratedEmulatorVariance(:));
    assert(all(isfinite(COMSOL))&&all(isfinite(GPMean))&& ...
        all(isfinite(RawUQLabVariance))&&all(RawUQLabVariance>=0)&& ...
        all(isfinite(CalibratedEmulatorVariance))&& ...
        all(CalibratedEmulatorVariance>=0), ...
        'recovery:gp_train_validation_metrics:FinitePredictions', ...
        ['The %s predictions need finite COMSOL values and GP means and finite, ' ...
         'non-negative variances.'],cohort);
    RawUQLabSD=sqrt(RawUQLabVariance);
    CalibratedEmulatorSD=sqrt(CalibratedEmulatorVariance);
    GPResidual=GPMean-COMSOL;
    GPAbsoluteError=abs(GPResidual);
    relativeScale=zeros(n,1);relativeAvailable=false(n,1);
    for j=1:numel(outputNames)
        rows=OutputIndex==j;
        safeguard=eps(max(1,max(abs(COMSOL(rows)))));
        relativeScale(rows)=safeguard;
        relativeAvailable(rows)=abs(COMSOL(rows))>safeguard;
    end
    GPRelativeErrorPercent=nan(n,1);
    GPRelativeErrorPercent(relativeAvailable)=100*GPAbsoluteError( ...
        relativeAvailable)./abs(COMSOL(relativeAvailable));
    CalibratedStandardizedResidual=nan(n,1);
    positive=CalibratedEmulatorSD>0;
    CalibratedStandardizedResidual(positive)= ...
        GPResidual(positive)./CalibratedEmulatorSD(positive);
    RelativeErrorMissingReason=repmat("",n,1);
    RelativeErrorMissingReason(~relativeAvailable)= ...
        "truth_magnitude_at_or_below_numerical_safeguard";
    Cohort=repmat(string(cohort),n,1);
    T=table(Cohort,CaseID,SourceRow,OutputIndex,Output,COMSOL,GPMean, ...
        RawUQLabVariance,RawUQLabSD,CalibratedEmulatorVariance, ...
        CalibratedEmulatorSD,GPResidual,GPAbsoluteError, ...
        GPRelativeErrorPercent,CalibratedStandardizedResidual, ...
        relativeAvailable,relativeScale,RelativeErrorMissingReason);
end

function T=cohort_metrics(predictions,outputNames)
    n=numel(outputNames);Cohort=repmat(predictions.Cohort(1),n,1);
    OutputIndex=(1:n).';Output=outputNames;
    [CaseCount,R2,MAE,RMSE,NRMSE_range,TruthRange_mbar,MAREPercent, ...
        MaximumAbsoluteError,MaximumRelativeErrorPercent,Coverage95Percent, ...
        MeanPredictiveStd,MeanStandardizedResidual,RMSStandardizedResidual]= ...
        deal(nan(n,1));
    R2MissingReason=strings(n,1);NRMSEMissingReason=strings(n,1);
    RelativeErrorMissingReason=strings(n,1);
    CoverageMissingReason=strings(n,1);
    for j=1:n
        rows=predictions.OutputIndex==j;one=predictions(rows,:);
        assert(~isempty(one), ...
            'recovery:gp_train_validation_metrics:MissingOutput', ...
            'The predictions have no rows for output %d.',j);
        CaseCount(j)=height(one);residual=double(one.GPResidual);
        truth=double(one.COMSOL);MAE(j)=mean(abs(residual));
        RMSE(j)=sqrt(mean(residual.^2));
        truthRange=max(truth)-min(truth);
        TruthRange_mbar(j)=truthRange;
        if truthRange>eps(max(1,max(abs(truth))))
            NRMSE_range(j)=RMSE(j)/truthRange;
        else
            NRMSEMissingReason(j)="zero_empirical_truth_range";
        end
        denominator=sum((truth-mean(truth)).^2);
        if denominator>eps(max(1,sum(truth.^2)))
            R2(j)=1-sum(residual.^2)/denominator;
        else
            R2MissingReason(j)="zero_empirical_truth_variance";
        end
        relative=double(one.GPRelativeErrorPercent);
        available=isfinite(relative);
        if any(available)
            MAREPercent(j)=mean(relative(available));
            MaximumRelativeErrorPercent(j)=max(relative(available));
        else
            RelativeErrorMissingReason(j)= ...
                "no_denominator_safe_relative_errors";
        end
        MaximumAbsoluteError(j)=max(abs(residual));
        predictiveStd=double(one.CalibratedEmulatorSD);
        MeanPredictiveStd(j)=mean(predictiveStd);
        finiteStd=isfinite(predictiveStd)&predictiveStd>0;
        if any(finiteStd)
            Coverage95Percent(j)=100*mean(abs(residual(finiteStd))<= ...
                1.96*predictiveStd(finiteStd));
            standardized=residual(finiteStd)./predictiveStd(finiteStd);
            MeanStandardizedResidual(j)=mean(standardized);
            RMSStandardizedResidual(j)=sqrt(mean(standardized.^2));
        else
            CoverageMissingReason(j)="no_positive_finite_gp_predictive_sd";
        end
    end
    Units=repmat("mbar",n,1);
    T=table(Cohort,OutputIndex,Output,Units,CaseCount,R2,MAE,RMSE, ...
        NRMSE_range,TruthRange_mbar, ...
        MAREPercent,MaximumAbsoluteError,MaximumRelativeErrorPercent, ...
        Coverage95Percent,MeanPredictiveStd,MeanStandardizedResidual, ...
        RMSStandardizedResidual,R2MissingReason,NRMSEMissingReason, ...
        RelativeErrorMissingReason,CoverageMissingReason);
end

function T=metric_differences(training,validation)
    assert(isequal(training.OutputIndex,validation.OutputIndex)&& ...
        isequal(training.Output,validation.Output), ...
        'recovery:gp_train_validation_metrics:CohortOutputOrder', ...
        'The training and validation metrics must list the same outputs in the same order.');
    % NRMSE_range is not differenced: the two cohorts' values divide by
    % different truth ranges (CLN-028).
    metricNames=["R2" "MAE" "RMSE" "MAREPercent" ...
        "MaximumAbsoluteError" "MaximumRelativeErrorPercent" ...
        "Coverage95Percent" "MeanPredictiveStd" ...
        "MeanStandardizedResidual" "RMSStandardizedResidual"];
    metricUnits=["dimensionless" "mbar" "mbar" ...
        "percent" "mbar" ...
        "percent" "percent" "mbar" "dimensionless" "dimensionless"];
    n=height(training);m=numel(metricNames);OutputIndex=zeros(n*m,1);
    Output=strings(n*m,1);Metric=strings(n*m,1);Units=strings(n*m,1);
    TrainingValue=nan(n*m,1);ValidationValue=nan(n*m,1);
    cursor=0;
    for j=1:n
        for k=1:m
            cursor=cursor+1;OutputIndex(cursor)=training.OutputIndex(j);
            Output(cursor)=training.Output(j);Metric(cursor)=metricNames(k);
            Units(cursor)=metricUnits(k);
            TrainingValue(cursor)=double(training.(metricNames(k))(j));
            ValidationValue(cursor)=double(validation.(metricNames(k))(j));
        end
    end
    ValidationMinusTraining=ValidationValue-TrainingValue;
    T=table(OutputIndex,Output,Metric,Units,TrainingValue,ValidationValue, ...
        ValidationMinusTraining);
end
