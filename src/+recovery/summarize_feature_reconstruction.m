function summary = summarize_feature_reconstruction(longForm,varargin)
%SUMMARIZE_FEATURE_RECONSTRUCTION Two-step, equal-feature reconstruction summary.
%   The long table is the sole numerical input.  Case-level values are first
%   aggregated separately for each scalar feature; matrix-cell summaries then
%   give every scalar feature equal weight.  Consequently a nine-coordinate
%   diagnostic family does not receive more weight merely because it has more
%   coordinates than another evaluation space.
%   SUMMARY = recovery.summarize_feature_reconstruction(LONGFORM, ...)
%   returns the per-feature and the matrix-cell summaries.
%   Option (name-value): 'MatchedCohorts', a table of matched cohorts whose
%   summary rows are appended (default none).
%   Side effects: none.

    parser=inputParser;
    parser.FunctionName='recovery.summarize_feature_reconstruction';
    addParameter(parser,'MatchedCohorts',table(),@istable);
    parse(parser,varargin{:});

    required={'Scenario','CaseID','FittingDesign','EvaluationSpace', ...
        'EvaluationClass','ScalarFeature','FeatureID','FeatureFamily', ...
        'FeatureIndex','Units','Truth','PosteriorMean','PosteriorMedian', ...
        'Q025','Q975','IntervalWidth','SignedMedianError', ...
        'AbsoluteMedianError','FeatureScale','NormalizedAbsoluteError', ...
        'NormalizedMetricAvailable','NormalizationUnavailableReason', ...
        'Covered95','ArtifactLoaded','CertifiedStepCount', ...
        'CertificationMechanism','PosteriorArtifactReference','CohortType', ...
        'ExecutionStatus','FailureReason'};
    assert(istable(longForm)&&~isempty(longForm)&& ...
        all(ismember(required,longForm.Properties.VariableNames)), ...
        'recovery:summarize_feature_reconstruction:LongFormSchema', ...
        'The feature-reconstruction long table does not satisfy its contract.');
    T=normalize_types(longForm);
    if ~isempty(parser.Results.MatchedCohorts)
        T=append_matched_rows(T,parser.Results.MatchedCohorts);
    end
    perFeature=per_feature_summary(T);
    [matrixSummary,maximumDeviation]=matrix_summary(T,perFeature);
    [worstFeaturePerCase,worstFeatureFrequency]=worst_feature_outputs(T);
    summary=struct( ...
        'schemaVersion','posterior_feature_reconstruction_summary_v2', ...
        'perFeatureSummary',perFeature, ...
        'matrixSummary',matrixSummary, ...
        'perFeature',perFeature, ...
        'matrix',matrixSummary, ...
        'maximumDeviation',maximumDeviation, ...
        'worstFeaturePerCase',worstFeaturePerCase, ...
        'worstFeatureFrequency',worstFeatureFrequency, ...
        'absoluteLossPointEstimator','posterior_median', ...
        'squaredLossPointEstimator','posterior_mean', ...
        'aggregationOrder', ...
            'cases_within_scalar_feature_then_equal_weight_across_features', ...
        'nineFeatureFamilyMultiplicityWeighting',false, ...
        'scientificInterpretationGenerated',false);
end

function T=append_matched_rows(T,membership)
    required={'Scenario','CaseID','IncludedInMatchedCohort'};
    assert(all(ismember(required,membership.Properties.VariableNames)), ...
        'recovery:summarize_feature_reconstruction:MatchedSchema', ...
        'Matched-cohort membership does not satisfy its contract.');
    membership.Scenario=string(membership.Scenario);
    membership.CaseID=double(membership.CaseID);
    membership.IncludedInMatchedCohort=to_logical( ...
        membership.IncludedInMatchedCohort);
    keep=false(height(T),1);
    for i=1:height(membership)
        keep=keep|(T.Scenario==membership.Scenario(i)& ...
            T.CaseID==membership.CaseID(i));
    end
    matched=T(keep,:);
    matched.CohortType(:)="matched_all_six_designs";
    for i=1:height(membership)
        rows=matched.Scenario==membership.Scenario(i)& ...
            matched.CaseID==membership.CaseID(i);
        if ~membership.IncludedInMatchedCohort(i)
            matched.AggregationEligible(rows)=false;
            reason="excluded_from_exact_matched_six_design_cohort";
            if ismember('ExclusionReason',membership.Properties.VariableNames)
                one=string(membership.ExclusionReason(i));
                if strlength(one)>0,reason=one;end
            end
            existing=matched.FailureReason(rows);
            existing(strlength(existing)==0)=reason;
            append=strlength(existing)>0&~contains(existing,reason);
            existing(append)=existing(append)+";"+reason;
            matched.FailureReason(rows)=existing;
        end
    end
    T.CohortType(:)="row_specific_available";
    T=[T;matched];
end

function T=normalize_types(T)
    stringNames={'Scenario','FittingDesign','EvaluationSpace', ...
        'EvaluationClass','ScalarFeature','FeatureID','FeatureFamily','Units', ...
        'NormalizationUnavailableReason','CertificationMechanism', ...
        'PosteriorArtifactReference','CohortType','ExecutionStatus','FailureReason'};
    for i=1:numel(stringNames),T.(stringNames{i})=string(T.(stringNames{i}));end
    numericNames={'CaseID','FeatureIndex','Truth','PosteriorMean', ...
        'PosteriorMedian','Q025','Q975','IntervalWidth','SignedMedianError', ...
        'AbsoluteMedianError','FeatureScale','NormalizedAbsoluteError', ...
        'Covered95','CertifiedStepCount'};
    for i=1:numel(numericNames),T.(numericNames{i})=double(T.(numericNames{i}));end
    T.NormalizedMetricAvailable=to_logical(T.NormalizedMetricAvailable);
    T.ArtifactLoaded=to_logical(T.ArtifactLoaded);
    T.AggregationEligible=T.ArtifactLoaded;
    if ismember('ReconstructionValid',T.Properties.VariableNames)
        T.AggregationEligible=T.AggregationEligible& ...
            to_logical(T.ReconstructionValid);
    end
    T=add_loss_consistent_fields(T);
end

function T=add_loss_consistent_fields(T)
% Point predictions follow their reported loss: median for L1, mean for L2.
    scale=T.FeatureScale;scale(~T.NormalizedMetricAvailable)=NaN;
    metrics=recovery.loss_consistent_point_errors( ...
        T.Truth,T.PosteriorMean,T.PosteriorMedian,scale);
    T.SignedErrorFromPosteriorMean= ...
        metrics.signedErrorFromPosteriorMean;
    T.SignedErrorFromPosteriorMedian= ...
        metrics.signedErrorFromPosteriorMedian;
    T.AbsoluteErrorFromPosteriorMedian= ...
        metrics.absoluteErrorFromPosteriorMedian;
    T.SquaredErrorFromPosteriorMean=metrics.squaredErrorFromPosteriorMean;
    T.NormalizedAbsoluteErrorFromPosteriorMedian= ...
        metrics.normalizedAbsoluteErrorFromPosteriorMedian;
    T.NormalizedSquaredErrorFromPosteriorMean= ...
        metrics.normalizedSquaredErrorFromPosteriorMean;

    % Retain the established fields as compatibility aliases with explicit
    % loss-consistent definitions. New consumers should use the fields above.
    T.SignedMedianError=T.SignedErrorFromPosteriorMedian;
    T.AbsoluteMedianError=T.AbsoluteErrorFromPosteriorMedian;
    T.NormalizedAbsoluteError= ...
        T.NormalizedAbsoluteErrorFromPosteriorMedian;
end

function output=per_feature_summary(T)
    groupNames={'Scenario','FittingDesign','EvaluationSpace', ...
        'EvaluationClass','FeatureID','ScalarFeature','FeatureFamily', ...
        'FeatureIndex','Units','CohortType'};
    groups=stable_groups(T,groupNames);parts=cell(numel(groups),1);
    for i=1:numel(groups)
        rows=groups(i).rows;one=T(rows,:);prefix=group_prefix(one,groupNames);
        nativeValid=one.AggregationEligible&isfinite(one.Truth)& ...
            isfinite(one.PosteriorMean)&isfinite(one.PosteriorMedian)& ...
            isfinite(one.Q025)& ...
            isfinite(one.Q975)&isfinite(one.SignedMedianError)& ...
            isfinite(one.AbsoluteMedianError)&isfinite(one.IntervalWidth)& ...
            isfinite(one.Covered95);
        normalizedValid=nativeValid&one.NormalizedMetricAvailable& ...
            isfinite(one.NormalizedAbsoluteErrorFromPosteriorMedian)& ...
            isfinite(one.NormalizedSquaredErrorFromPosteriorMean);
        expectedIDs=unique(one.CaseID,'stable');
        includedIDs=unique(one.CaseID(nativeValid),'stable');
        excludedIDs=expectedIDs(~ismember(expectedIDs,includedIDs));
        [excludedText,reasonText]=exclusion_text(one,nativeValid,excludedIDs);
        scales=unique(one.FeatureScale(isfinite(one.FeatureScale)));
        assert(numel(scales)<=1, ...
            'recovery:summarize_feature_reconstruction:FeatureScaleMismatch', ...
            'One scalar feature cannot use multiple normalization scales.');
        if isempty(scales),scale=NaN;else,scale=scales;end
        normalizedAvailable=any(one.NormalizedMetricAvailable);
        unavailable=unique(one.NormalizationUnavailableReason( ...
            ~one.NormalizedMetricAvailable& ...
            strlength(one.NormalizationUnavailableReason)>0),'stable');
        row=prefix;
        row.ExpectedCaseCount=numel(expectedIDs);
        row.IncludedCaseCount=numel(includedIDs);
        row.ExcludedCaseCount=numel(excludedIDs);
        row.IncludedCaseIDs=strjoin(string(includedIDs.'),',');
        row.ExcludedCaseIDs=excludedText;row.ExclusionReasons=reasonText;
        row.FeatureScale=scale;
        row.NormalizedMetricAvailable=normalizedAvailable;
        row.NormalizationUnavailableReason=strjoin(unavailable,';');
        row.AcrossCaseMeanNormalizedAbsoluteErrorFromPosteriorMedian= ...
            mean_or_nan(one.NormalizedAbsoluteErrorFromPosteriorMedian( ...
            normalizedValid));
        row.AcrossCaseMedianNormalizedAbsoluteErrorFromPosteriorMedian= ...
            median_or_nan(one.NormalizedAbsoluteErrorFromPosteriorMedian( ...
            normalizedValid));
        row.AcrossCaseNormalizedMSEFromPosteriorMean=mean_or_nan( ...
            one.NormalizedSquaredErrorFromPosteriorMean(normalizedValid));
        row.AcrossCaseNormalizedRMSEFromPosteriorMean=sqrt( ...
            row.AcrossCaseNormalizedMSEFromPosteriorMean);
        row.MaximumNormalizedAbsoluteErrorFromPosteriorMedian=max_or_nan( ...
            one.NormalizedAbsoluteErrorFromPosteriorMedian(normalizedValid));
        row.AcrossCaseMeanSignedErrorFromPosteriorMean=mean_or_nan( ...
            one.SignedErrorFromPosteriorMean(nativeValid));
        row.AcrossCaseMAEFromPosteriorMedian=mean_or_nan( ...
            one.AbsoluteErrorFromPosteriorMedian(nativeValid));
        row.AcrossCaseMSEFromPosteriorMean=mean_or_nan( ...
            one.SquaredErrorFromPosteriorMean(nativeValid));
        row.AcrossCaseRMSEFromPosteriorMean=sqrt( ...
            row.AcrossCaseMSEFromPosteriorMean);
        row=add_summary_compatibility_aliases(row);
        row.MedianIntervalWidth=median_or_nan(one.IntervalWidth(nativeValid));
        row.Coverage95=mean_or_nan(one.Covered95(nativeValid));
        parts{i}=row;
    end
    output=vertcat(parts{:});
end

function [output,maximumOutput]=matrix_summary(T,perFeature)
    groupNames={'Scenario','FittingDesign','EvaluationSpace', ...
        'EvaluationClass','CohortType'};
    groups=stable_groups(T,groupNames);
    outputParts=cell(numel(groups),1);maximumParts=cell(numel(groups),1);
    for i=1:numel(groups)
        rows=groups(i).rows;one=T(rows,:);prefix=group_prefix(one,groupNames);
        featureRows=perFeature.Scenario==prefix.Scenario& ...
            perFeature.FittingDesign==prefix.FittingDesign& ...
            perFeature.EvaluationSpace==prefix.EvaluationSpace& ...
            perFeature.EvaluationClass==prefix.EvaluationClass& ...
            perFeature.CohortType==prefix.CohortType;
        F=perFeature(featureRows,:);
        [~,order]=sort(double(F.FeatureIndex));F=F(order,:);
        expectedFeatures=unique(one.FeatureID,'stable');
        assert(height(F)==numel(expectedFeatures), ...
            'recovery:summarize_feature_reconstruction:FeatureAggregation', ...
            'Every matrix cell must contain one summary per scalar feature.');
        normalized=F.NormalizedMetricAvailable& ...
            isfinite(F.AcrossCaseMeanNormalizedAbsoluteErrorFromPosteriorMedian)& ...
            isfinite(F.AcrossCaseNormalizedMSEFromPosteriorMean);
        units=unique(F.Units,'stable');
        nativeAvailable=isscalar(units);
        nativeReason="";
        if ~nativeAvailable,nativeReason="mixed_feature_units";end
        [includedIDs,excludedIDs,reasonText]=matrix_case_cohort( ...
            one,expectedFeatures);

        row=prefix;
        row.MatrixClass=matrix_class(prefix.EvaluationClass);
        row.NumberScalarFeatures=height(F);
        row.NormalizedFeatureCount=sum(normalized);
        row.AcrossCaseMeanNormalizedAbsoluteErrorFromPosteriorMedian= ...
            mean_or_nan(F. ...
            AcrossCaseMeanNormalizedAbsoluteErrorFromPosteriorMedian( ...
            normalized));
        row.AcrossCaseMedianNormalizedAbsoluteErrorFromPosteriorMedian= ...
            mean_or_nan(F. ...
            AcrossCaseMedianNormalizedAbsoluteErrorFromPosteriorMedian( ...
            normalized));
        row.AcrossCaseNormalizedMSEFromPosteriorMean=mean_or_nan( ...
            F.AcrossCaseNormalizedMSEFromPosteriorMean(normalized));
        row.AcrossCaseNormalizedRMSEFromPosteriorMean=sqrt( ...
            row.AcrossCaseNormalizedMSEFromPosteriorMean);
        row.MaximumNormalizedAbsoluteErrorFromPosteriorMedian=max_or_nan( ...
            F.MaximumNormalizedAbsoluteErrorFromPosteriorMedian(normalized));
        row.NativeMetricsAvailable=nativeAvailable;
        row.NativeMetricUnavailableReason=nativeReason;
        if nativeAvailable
            row.AcrossCaseMeanSignedErrorFromPosteriorMean=mean_or_nan( ...
                F.AcrossCaseMeanSignedErrorFromPosteriorMean);
            row.AcrossCaseMAEFromPosteriorMedian=mean_or_nan( ...
                F.AcrossCaseMAEFromPosteriorMedian);
            row.AcrossCaseMSEFromPosteriorMean=mean_or_nan( ...
                F.AcrossCaseMSEFromPosteriorMean);
            row.AcrossCaseRMSEFromPosteriorMean=sqrt( ...
                row.AcrossCaseMSEFromPosteriorMean);
            row.MedianIntervalWidth=mean_or_nan(F.MedianIntervalWidth);
        else
            row.AcrossCaseMeanSignedErrorFromPosteriorMean=NaN;
            row.AcrossCaseMAEFromPosteriorMedian=NaN;
            row.AcrossCaseMSEFromPosteriorMean=NaN;
            row.AcrossCaseRMSEFromPosteriorMean=NaN;
            row.MedianIntervalWidth=NaN;
        end
        row=add_summary_compatibility_aliases(row);
        row.Coverage95=mean_or_nan(F.Coverage95);
        row.ExpectedCaseCount=numel(unique(one.CaseID,'stable'));
        row.IncludedCaseCount=numel(includedIDs);
        row.ExcludedCaseCount=numel(excludedIDs);
        row.IncludedCaseIDs=strjoin(string(includedIDs.'),',');
        row.ExcludedCaseIDs=strjoin(string(excludedIDs.'),',');
        row.ExclusionReasons=reasonText;
        row.EqualScalarFeatureWeighting=true;
        outputParts{i}=row;
        maximumParts{i}=maximum_row(prefix,one);
    end
    output=vertcat(outputParts{:});
    maximumOutput=vertcat(maximumParts{:});
end

function row=maximum_row(prefix,T)
    valid=T.AggregationEligible&T.NormalizedMetricAvailable& ...
        isfinite(T.NormalizedAbsoluteErrorFromPosteriorMedian)& ...
        isfinite(T.Truth)& ...
        isfinite(T.PosteriorMedian)&isfinite(T.SignedMedianError)& ...
        isfinite(T.AbsoluteMedianError);
    row=prefix;row.MaximumAvailable=any(valid);
    if any(valid)
        candidates=find(valid);[value,local]=max( ...
            T.NormalizedAbsoluteErrorFromPosteriorMedian(valid));
        index=candidates(local);
        row.MaximumNormalizedAbsoluteErrorFromPosteriorMedian=value;
        row.MaximumNormalizedAbsoluteError=value;
        row.CaseID=T.CaseID(index);row.ScalarFeature=T.ScalarFeature(index);
        row.FeatureID=T.FeatureID(index);row.FeatureIndex=T.FeatureIndex(index);
        row.Units=T.Units(index);row.Truth=T.Truth(index);
        row.PosteriorMedian=T.PosteriorMedian(index);
        row.SignedErrorFromPosteriorMedian= ...
            T.SignedErrorFromPosteriorMedian(index);
        row.AbsoluteErrorFromPosteriorMedian= ...
            T.AbsoluteErrorFromPosteriorMedian(index);
        row.SignedNativeError=T.SignedMedianError(index);
        row.AbsoluteNativeError=T.AbsoluteMedianError(index);
        row.PosteriorArtifactReference=T.PosteriorArtifactReference(index);
    else
        row.MaximumNormalizedAbsoluteErrorFromPosteriorMedian=NaN;
        row.MaximumNormalizedAbsoluteError=NaN;row.CaseID=NaN;
        row.ScalarFeature="";row.FeatureID="";row.FeatureIndex=NaN;
        row.Units="";row.Truth=NaN;row.PosteriorMedian=NaN;
        row.SignedErrorFromPosteriorMedian=NaN;
        row.AbsoluteErrorFromPosteriorMedian=NaN;
        row.SignedNativeError=NaN;row.AbsoluteNativeError=NaN;
        row.PosteriorArtifactReference="";
    end
end

function row=add_summary_compatibility_aliases(row)
    row.MeanNormalizedAbsoluteError= ...
        row.AcrossCaseMeanNormalizedAbsoluteErrorFromPosteriorMedian;
    row.MedianNormalizedAbsoluteError= ...
        row.AcrossCaseMedianNormalizedAbsoluteErrorFromPosteriorMedian;
    row.NormalizedMSE=row.AcrossCaseNormalizedMSEFromPosteriorMean;
    row.NormalizedRMSE=row.AcrossCaseNormalizedRMSEFromPosteriorMean;
    row.MaximumNormalizedAbsoluteError= ...
        row.MaximumNormalizedAbsoluteErrorFromPosteriorMedian;
    row.MeanSignedNativeError= ...
        row.AcrossCaseMeanSignedErrorFromPosteriorMean;
    row.MeanNativeAbsoluteError=row.AcrossCaseMAEFromPosteriorMedian;
    row.NativeMSE=row.AcrossCaseMSEFromPosteriorMean;
    row.NativeRMSE=row.AcrossCaseRMSEFromPosteriorMean;
end

function [perCase,frequency]=worst_feature_outputs(T)
% Select one canonical feature argmax per case, then count selections.
    groupNames={'Scenario','FittingDesign','EvaluationSpace', ...
        'EvaluationClass','CohortType'};
    groups=stable_groups(T,groupNames);caseParts={};partCount=0;
    for g=1:numel(groups)
        oneGroup=T(groups(g).rows,:);prefix=group_prefix(oneGroup,groupNames);
        caseIDs=unique(oneGroup.CaseID,'stable');
        for c=1:numel(caseIDs)
            one=oneGroup(oneGroup.CaseID==caseIDs(c),:);
            [~,order]=sortrows([double(one.FeatureIndex) (1:height(one)).']);
            one=one(order,:);
            valid=one.AggregationEligible&one.NormalizedMetricAvailable& ...
                isfinite(one.NormalizedAbsoluteErrorFromPosteriorMedian)& ...
                isfinite(one.AbsoluteErrorFromPosteriorMedian)& ...
                isfinite(one.Truth)&isfinite(one.PosteriorMedian);
            row=prefix;row.CaseID=caseIDs(c);row.WorstFeatureAvailable=any(valid);
            if any(valid)
                maximum=max(one.NormalizedAbsoluteErrorFromPosteriorMedian(valid));
                tied=valid&one.NormalizedAbsoluteErrorFromPosteriorMedian==maximum;
                selected=find(tied,1,'first');
                row.FeatureID=one.FeatureID(selected);
                row.ScalarFeature=one.ScalarFeature(selected);
                row.FeatureFamily=one.FeatureFamily(selected);
                row.FeatureIndex=one.FeatureIndex(selected);
                row.Units=one.Units(selected);
                row.NormalizedAbsoluteErrorFromPosteriorMedian=maximum;
                row.AbsoluteErrorFromPosteriorMedian= ...
                    one.AbsoluteErrorFromPosteriorMedian(selected);
                row.Truth=one.Truth(selected);
                row.PosteriorMedian=one.PosteriorMedian(selected);
                row.TieOccurred=nnz(tied)>1;row.TiedFeatureCount=nnz(tied);
                row.TiedFeatureIDs=strjoin(one.FeatureID(tied),',');
                row.TieBreakPolicy="lowest_canonical_feature_index";
                row.PosteriorArtifactReference= ...
                    one.PosteriorArtifactReference(selected);
                row.ExclusionReason="";
            else
                row.FeatureID="";row.ScalarFeature="";row.FeatureFamily="";
                row.FeatureIndex=NaN;row.Units="";
                row.NormalizedAbsoluteErrorFromPosteriorMedian=NaN;
                row.AbsoluteErrorFromPosteriorMedian=NaN;row.Truth=NaN;
                row.PosteriorMedian=NaN;row.TieOccurred=false;
                row.TiedFeatureCount=0;row.TiedFeatureIDs="";
                row.TieBreakPolicy="lowest_canonical_feature_index";
                row.PosteriorArtifactReference="";
                reasons=unique(one.FailureReason(strlength( ...
                    one.FailureReason)>0),'stable');
                if isempty(reasons),reasons="no_available_normalized_feature";end
                row.ExclusionReason=strjoin(reasons,';');
            end
            partCount=partCount+1;caseParts{partCount,1}=row; %#ok<AGROW>
        end
    end
    perCase=vertcat(caseParts{:});

    groups=stable_groups(T,groupNames);frequencyParts={};partCount=0;
    for g=1:numel(groups)
        oneGroup=T(groups(g).rows,:);prefix=group_prefix(oneGroup,groupNames);
        cases=perCase;
        for n=1:numel(groupNames)
            cases=cases(cases.(groupNames{n})==prefix.(groupNames{n}),:);
        end
        included=cases.WorstFeatureAvailable;
        features=unique(oneGroup(:,{'FeatureID','ScalarFeature', ...
            'FeatureFamily','FeatureIndex','Units'}),'rows','stable');
        [~,order]=sort(double(features.FeatureIndex));features=features(order,:);
        for f=1:height(features)
            row=prefix;
            row.FeatureID=features.FeatureID(f);
            row.ScalarFeature=features.ScalarFeature(f);
            row.FeatureFamily=features.FeatureFamily(f);
            row.FeatureIndex=features.FeatureIndex(f);row.Units=features.Units(f);
            row.WorstFeatureCount=sum(included& ...
                cases.FeatureID==features.FeatureID(f));
            row.IncludedCaseCount=sum(included);
            row.ExpectedCaseCount=height(cases);
            row.ExcludedCaseCount=row.ExpectedCaseCount-row.IncludedCaseCount;
            if row.IncludedCaseCount>0
                row.WorstFeatureFraction= ...
                    row.WorstFeatureCount/row.IncludedCaseCount;
            else
                row.WorstFeatureFraction=NaN;
            end
            row.TiedCaseCount=sum(included&cases.TieOccurred);
            row.TieBreakPolicy="lowest_canonical_feature_index";
            partCount=partCount+1;frequencyParts{partCount,1}=row; %#ok<AGROW>
        end
    end
    frequency=vertcat(frequencyParts{:});
end

function [includedIDs,excludedIDs,reasonText]=matrix_case_cohort(T,features)
    caseIDs=unique(T.CaseID,'stable');included=false(size(caseIDs));
    reasons=strings(size(caseIDs));
    for c=1:numel(caseIDs)
        rows=T.CaseID==caseIDs(c);one=T(rows,:);
        valid=one.AggregationEligible&isfinite(one.Truth)& ...
            isfinite(one.PosteriorMedian)&isfinite(one.Q025)& ...
            isfinite(one.Q975)&isfinite(one.IntervalWidth)& ...
            isfinite(one.Covered95);
        included(c)=all(ismember(features,one.FeatureID(valid)));
        if ~included(c)
            bad=one(~valid,:);pieces=unique(bad.FailureReason( ...
                strlength(bad.FailureReason)>0),'stable');
            if isempty(pieces),pieces="incomplete_scalar_feature_set";end
            reasons(c)=string(caseIDs(c))+":"+strjoin(pieces,';');
        end
    end
    includedIDs=caseIDs(included);excludedIDs=caseIDs(~included);
    reasonText=strjoin(reasons(~included),'|');
end

function [excludedText,reasonText]=exclusion_text(T,valid,excludedIDs)
    excludedText=strjoin(string(excludedIDs.'),',');
    pieces=strings(numel(excludedIDs),1);
    for i=1:numel(excludedIDs)
        rows=T.CaseID==excludedIDs(i)&~valid;
        reasons=unique(T.FailureReason(rows& ...
            strlength(T.FailureReason)>0),'stable');
        if isempty(reasons),reasons="reconstruction_unavailable";end
        pieces(i)=string(excludedIDs(i))+":"+strjoin(reasons,';');
    end
    reasonText=strjoin(pieces,'|');
end

function groups=stable_groups(T,names)
    key=strings(height(T),1);
    for i=1:numel(names),key=key+"|"+string(T.(names{i}));end
    uniqueKeys=unique(key,'stable');
    groups=repmat(struct('rows',false(height(T),1)),numel(uniqueKeys),1);
    for i=1:numel(uniqueKeys),groups(i).rows=key==uniqueKeys(i);end
end

function prefix=group_prefix(T,names)
    prefix=table();
    for i=1:numel(names),prefix.(names{i})=T.(names{i})(1);end
end

function value=matrix_class(evaluationClass)
    if evaluationClass=="core_active"
        value="core_active_6_by_6";
    else
        value="expanded_6_by_9";
    end
end

function value=mean_or_nan(input)
    input=double(input);input=input(isfinite(input));
    if isempty(input),value=NaN;else,value=mean(input);end
end

function value=median_or_nan(input)
    input=double(input);input=input(isfinite(input));
    if isempty(input),value=NaN;else,value=median(input);end
end

function value=max_or_nan(input)
    input=double(input);input=input(isfinite(input));
    if isempty(input),value=NaN;else,value=max(input);end
end

function value=to_logical(input)
    if islogical(input),value=input;return;end
    if isnumeric(input),value=input~=0;return;end
    value=ismember(lower(string(input)),["true" "1"]);
end
