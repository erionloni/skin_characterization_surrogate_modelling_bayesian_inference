function [completionSummary,completionBins,missingnessSummary,missingnessBins] = ...
        feasibility_sensitivity(caseRegistry,inputNames)
%FEASIBILITY_SENSITIVITY Separate observed completion from missingness.
%   [COMPLETIONSUMMARY, COMPLETIONBINS, MISSINGNESSSUMMARY, MISSINGNESSBINS] =
%   sensitivity.feasibility_sensitivity(CASEREGISTRY, INPUTNAMES).
%   Completion associations are conditional on both probes having recorded
%   canonical classifications. CaseIDs affected by an unavailable probe never
%   enter the observed-noncompletion comparison. Missingness associations are
%   evaluated separately over all expected CaseIDs.
%
%   This is intentionally separate from pressure Sobol sensitivity. It is not
%   called Sobol and makes no independent-input claim.
%   CASEREGISTRY: the generalized case registry; INPUTNAMES: its seven
%   inputs. The four tables summarize the completion and the missingness
%   rates overall and in bins of each input.
%   Side effects: none.

    required=[string(inputNames(:));"complete_pair_flag"; ...
        "D2_availability";"D6_availability"];
    assert(istable(caseRegistry)&&all(ismember(required, ...
        string(caseRegistry.Properties.VariableNames))), ...
        'sensitivity:feasibility_sensitivity:Schema', ...
        ['The case registry requires the requested inputs, complete_pair_flag, ' ...
        'D2_availability, and D6_availability.']);

    complete=logical(caseRegistry.complete_pair_flag);
    recorded=logical(caseRegistry.D2_availability) & ...
        logical(caseRegistry.D6_availability);
    missing=~recorded;
    observedNoncomplete=recorded & ~complete;
    assert(~any(complete & ~recorded), ...
        'sensitivity:feasibility_sensitivity:CompletionWithoutRecord', ...
        'A complete pair cannot have an unavailable canonical probe outcome.');
    if ismember('any_missing_flag',caseRegistry.Properties.VariableNames)
        assert(isequal(logical(caseRegistry.any_missing_flag),missing), ...
            'sensitivity:feasibility_sensitivity:MissingFlagMismatch', ...
            'any_missing_flag disagrees with the two probe-availability fields.');
    end

    n=numel(inputNames);
    completeMean=nan(n,1);
    observedNoncompleteMean=nan(n,1);
    completionSMD=nan(n,1);
    completionPointBiserial=nan(n,1);
    minCompletionRate=nan(n,1);
    maxCompletionRate=nan(n,1);
    completionRateRange=nan(n,1);
    recordedMean=nan(n,1);
    missingMean=nan(n,1);
    missingnessSMD=nan(n,1);
    missingnessPointBiserial=nan(n,1);
    minMissingRate=nan(n,1);
    maxMissingRate=nan(n,1);
    missingRateRange=nan(n,1);
    completionBins=table();
    missingnessBins=table();

    for j=1:n
        x=double(caseRegistry{:,inputNames{j}});
        assert(all(isfinite(x)), ...
            'sensitivity:feasibility_sensitivity:NonfiniteInput', ...
            'Input %s contains nonfinite CaseID values.',inputNames{j});

        completeValues=x(complete);
        observedNoncompleteValues=x(observedNoncomplete);
        completeMean(j)=mean(completeValues);
        observedNoncompleteMean(j)=mean(observedNoncompleteValues);
        completionSMD(j)=standardized_difference( ...
            completeValues,observedNoncompleteValues);
        completionPointBiserial(j)=point_biserial( ...
            x(recorded),complete(recorded));
        local=completion_bin_table(x,complete,recorded,inputNames{j},sum(missing));
        if ~isempty(local)
            minCompletionRate(j)=min(local.complete_fraction_among_recorded);
            maxCompletionRate(j)=max(local.complete_fraction_among_recorded);
            completionRateRange(j)=maxCompletionRate(j)-minCompletionRate(j);
            completionBins=[completionBins;local]; %#ok<AGROW>
        end

        recordedValues=x(recorded);
        missingValues=x(missing);
        recordedMean(j)=mean(recordedValues);
        missingMean(j)=mean(missingValues);
        missingnessSMD(j)=standardized_difference(missingValues,recordedValues);
        missingnessPointBiserial(j)=point_biserial(x,missing);
        local=missingness_bin_table(x,missing,inputNames{j});
        if ~isempty(local)
            minMissingRate(j)=min(local.missing_fraction_all_expected);
            maxMissingRate(j)=max(local.missing_fraction_all_expected);
            missingRateRange(j)=maxMissingRate(j)-minMissingRate(j);
            missingnessBins=[missingnessBins;local]; %#ok<AGROW>
        end
    end

    input=string(inputNames(:));
    analysisScope=repmat( ...
        "both_probes_recorded_canonical_classifications_only",n,1);
    schemaVersion=repmat( ...
        "real_extended_observed_completion_association_v2",n,1);
    eligibleRecordedCaseCount=repmat(sum(recorded),n,1);
    excludedMissingCaseCount=repmat(sum(missing),n,1);
    completeCount=repmat(sum(complete),n,1);
    observedNoncompleteCount=repmat(sum(observedNoncomplete),n,1);
    completionSummary=table(input,schemaVersion,analysisScope, ...
        eligibleRecordedCaseCount,excludedMissingCaseCount,completeCount, ...
        observedNoncompleteCount,completeMean,observedNoncompleteMean, ...
        completionSMD,completionPointBiserial,minCompletionRate, ...
        maxCompletionRate,completionRateRange, ...
        'VariableNames',{'input','schema_version','analysis_scope', ...
        'eligible_recorded_case_count','excluded_missing_case_count', ...
        'complete_count','observed_noncomplete_count','complete_mean', ...
        'observed_noncomplete_mean', ...
        'standardized_mean_difference_complete_vs_observed_noncomplete', ...
        'point_biserial_correlation_completion_among_recorded', ...
        'minimum_binned_completion_fraction_among_recorded', ...
        'maximum_binned_completion_fraction_among_recorded', ...
        'binned_completion_fraction_range_among_recorded'});

    analysisScope=repmat("all_expected_caseids_missingness_only",n,1);
    schemaVersion=repmat( ...
        "real_extended_missingness_association_v1",n,1);
    expectedCaseCount=repmat(height(caseRegistry),n,1);
    recordedCaseCount=repmat(sum(recorded),n,1);
    missingCaseCount=repmat(sum(missing),n,1);
    missingnessSummary=table(input,schemaVersion,analysisScope, ...
        expectedCaseCount,recordedCaseCount,missingCaseCount,recordedMean, ...
        missingMean,missingnessSMD,missingnessPointBiserial,minMissingRate, ...
        maxMissingRate,missingRateRange, ...
        'VariableNames',{'input','schema_version','analysis_scope', ...
        'expected_case_count','recorded_case_count','missing_case_count', ...
        'recorded_mean','missing_mean', ...
        'standardized_mean_difference_missing_vs_recorded', ...
        'point_biserial_correlation_missingness_all_expected', ...
        'minimum_binned_missing_fraction_all_expected', ...
        'maximum_binned_missing_fraction_all_expected', ...
        'binned_missing_fraction_range_all_expected'});
end

function T=completion_bin_table(x,complete,recorded,inputName,missingCount)
    eligibleX=x(recorded);
    eligibleComplete=complete(recorded);
    edges=unique(utils.weighted_quantile(eligibleX,linspace(0,1,6)));
    T=table();
    for k=1:max(numel(edges)-1,0)
        take=bin_membership(eligibleX,edges,k);
        if ~any(take),continue;end
        caseCount=sum(take);
        completeCount=sum(eligibleComplete(take));
        row=table(string(inputName), ...
            "real_extended_observed_completion_bins_v2", ...
            "both_probes_recorded_canonical_classifications_only", ...
            k,edges(k),edges(k+1),caseCount,completeCount, ...
            caseCount-completeCount,completeCount/caseCount,missingCount, ...
            'VariableNames',{'input','schema_version','analysis_scope','bin', ...
            'lower','upper','eligible_recorded_case_count_in_bin', ...
            'complete_count','observed_noncomplete_count', ...
            'complete_fraction_among_recorded','excluded_missing_case_count'});
        T=[T;row]; %#ok<AGROW>
    end
end

function T=missingness_bin_table(x,missing,inputName)
    edges=unique(utils.weighted_quantile(x,linspace(0,1,6)));
    T=table();
    for k=1:max(numel(edges)-1,0)
        take=bin_membership(x,edges,k);
        if ~any(take),continue;end
        caseCount=sum(take);
        missingCount=sum(missing(take));
        row=table(string(inputName), ...
            "real_extended_missingness_bins_v1", ...
            "all_expected_caseids_missingness_only", ...
            k,edges(k),edges(k+1),caseCount,caseCount-missingCount, ...
            missingCount,missingCount/caseCount, ...
            'VariableNames',{'input','schema_version','analysis_scope','bin', ...
            'lower','upper','expected_case_count_in_bin','recorded_case_count', ...
            'missing_case_count','missing_fraction_all_expected'});
        T=[T;row]; %#ok<AGROW>
    end
end

function take=bin_membership(x,edges,k)
    if k<numel(edges)-1
        take=x>=edges(k)&x<edges(k+1);
    else
        take=x>=edges(k)&x<=edges(k+1);
    end
end

function value=standardized_difference(a,b)
    if isempty(a)||isempty(b)
        value=NaN;
        return
    end
    pooled=sqrt(((numel(a)-1)*var(a)+(numel(b)-1)*var(b))/ ...
        max(numel(a)+numel(b)-2,1));
    delta=mean(a)-mean(b);
    if pooled==0
        if delta==0,value=0;else,value=sign(delta)*Inf;end
    else
        value=delta/pooled;
    end
end

function value=point_biserial(x,indicator)
    y=double(indicator);
    denominator=sqrt(sum((x-mean(x)).^2)*sum((y-mean(y)).^2));
    if denominator==0
        value=NaN;
    else
        value=sum((x-mean(x)).*(y-mean(y)))/denominator;
    end
end
