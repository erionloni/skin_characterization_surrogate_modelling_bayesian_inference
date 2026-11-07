function [cases,summary,sources] = conditional_sd_ratio_tables(cfg)
%CONDITIONAL_SD_RATIO_TABLES The posterior SD of each condition against the reference: per matched case and over the cohort.
%   [CASES, SUMMARY, SOURCES] = plotting.conditional_sd_ratio_tables(CFG)
%   reads the saved results of the conditional inversion (the comparison, the
%   matched cohorts and summary, the status table and the draws of the
%   cells) and returns, for every condition besides the reference in every
%   scenario in which it ran (in the order of the settings' table, A.9, and
%   labelled from it), on the matched cohort of the condition and the
%   reference (the cases whose two cells have a posterior, certified or
%   healthy fallback):
%     CASES    one row per matched case and free parameter of the condition:
%              the posterior SD over the prior SD of the condition's cell and
%              of the reference cell, their ratio (the change relative to the
%              reference; 1 is no change), the replicate discrepancy of both
%              cells (the normalized Wasserstein distance between the two
%              replicates at the provider's level, the replicate-agreement
%              metric of the certification, inversion.posterior_reproducibility,
%              and the relative difference of the two replicates' posterior
%              SDs; NaN for a cell with one replicate at that level), the
%              status of both cells, whether both count in the
%              certified-only values (InCertifiedOnlyValues), and the
%              normalized recovery error of the posterior median of both;
%     SUMMARY  per scenario, condition and free parameter: the size of the
%              matched cohort and the median and quartiles of the SD ratio, of
%              the normalized recovery error of the posterior median of both
%              cells and of the larger replicate SD difference of the two
%              cells, each followed by its value over the cases whose two
%              cells count in the certified-only values (_certified_only).
%   SOURCES are the saved tables read.
%   Side effects: none. Computation: reads the draws of every matched cell
%   (seconds to a minute).

    root=study.source_folder(cfg,'conditional_inversion');
    sources={fullfile(root,'reports','conditional_inversion_comparison.csv'), ...
        fullfile(root,'reports','conditional_inversion_matched_cohorts.csv'), ...
        fullfile(root,'reports','conditional_inversion_matched_summary.csv'), ...
        fullfile(root,'cell_status.csv')};
    comparison=readtable(sources{1},'Delimiter',',','TextType','string', ...
        'VariableNamingRule','preserve');
    matched=utils.read_csv_table(sources{3},{'AnalysisID','Scenario','RequiredConditions', ...
        'IncludedCaseIDs','IncludedCaseIDs_certified_only','ExcludedCaseIDs', ...
        'ExcludedCaseIDs_certified_only'});
    status=utils.read_csv_table(sources{4},{'Scenario','Design','Condition','Status', ...
        'ProviderSampler','Reason'});
    detail=readtable(sources{2},'Delimiter',',','TextType','string', ...
        'VariableNamingRule','preserve');
    metrics=plotting.conditional_inversion_metrics(cfg,comparison,detail);
    conditions=metrics.conditions;
    reference=conditions([conditions.reference]);
    parameters=string(cfg.paramNames(:)).';
    rows={};references=containers.Map('KeyType','char','ValueType','any');
    for scenario=reshape(unique(comparison.Scenario,'stable'),1,[])
        for condition=conditions(~[conditions.reference])
            ran=comparison.Scenario==scenario&comparison.ConditionID==condition.id& ...
                logical(comparison.Scheduled);
            if ~any(ran),continue;end
            [included,certifiedOnly]=pair_cohort(matched,scenario,reference.savedCode, ...
                condition.savedCode);
            free=setdiff(1:numel(parameters),condition.fixedIndices);
            for caseID=reshape(included,1,[])
                record=struct('caseID',caseID,'scenario',char(scenario),'design','all_six', ...
                    'conditionCode',char(condition.savedCode),'conditionID',char(condition.id));
                [w,d]=replicate_discrepancy(cfg,record,false,free);
                key=sprintf('%s|%d',scenario,caseID);
                if ~isKey(references,key)
                    referenceRecord=struct('caseID',caseID,'scenario',char(scenario), ...
                        'design','all_six','conditionCode',char(reference.savedCode), ...
                        'conditionID',char(reference.id));
                    [rw,rd]=replicate_discrepancy(cfg,referenceRecord,true,1:numel(parameters));
                    references(key)=struct('w',rw,'d',rd);
                end
                R=references(key);
                for k=1:numel(free)
                    p=free(k);
                    x=value(comparison,scenario,caseID,condition.id,parameters(p),'NormalizedPosteriorSD');
                    a=value(comparison,scenario,caseID,reference.id,parameters(p),'NormalizedPosteriorSD');
                    rows{end+1}=table(scenario,condition.code,strjoin(string( ...
                        cfg.paramNames(condition.fixedIndices)),';'),caseID,parameters(p), ...
                        numel(included), ...
                        cell_status(status,caseID,scenario,condition.id), ...
                        cell_status(status,caseID,scenario,reference.id), ...
                        ismember(caseID,certifiedOnly),x,a,x/a,w(k),R.w(p),d(k),R.d(p), ...
                        value(comparison,scenario,caseID,condition.id,parameters(p), ...
                            'PosteriorMedianNormalizedRecoveryError'), ...
                        value(comparison,scenario,caseID,reference.id,parameters(p), ...
                            'PosteriorMedianNormalizedRecoveryError'), ...
                        'VariableNames',case_columns()); %#ok<AGROW>
                end
            end
        end
    end
    if isempty(rows)
        cases=cell2table(cell(0,numel(case_columns())),'VariableNames',case_columns());
    else
        cases=vertcat(rows{:});
    end
    summary=summarize(cases,false);
    summary=utils.add_certified_only(summary,summarize(cases,true), ...
        {'Scenario','Condition','FixedParameters','Parameter'});
end

function names=case_columns()
    names={'Scenario','Condition','FixedParameters','CaseID','Parameter','MatchedCaseCount', ...
        'Status','ReferenceStatus','InCertifiedOnlyValues','PosteriorSDOverPriorSD', ...
        'ReferencePosteriorSDOverPriorSD','SDRatioToReference','ReplicateWasserstein', ...
        'ReferenceReplicateWasserstein','ReplicateSDRelativeDifference', ...
        'ReferenceReplicateSDRelativeDifference','RecoveryError','ReferenceRecoveryError'};
end

function S=summarize(cases,certifiedOnly)
%SUMMARIZE Per scenario, condition and parameter: N, median and quartiles over the matched cases.
%   No matched case (e.g. a campaign whose new cells are all unavailable):
%   a table with the columns and no rows.
    keys=unique(cases(:,{'Scenario','Condition','FixedParameters','Parameter'}),'stable');
    names={'MatchedCaseCount','MedianSDRatioToReference','Q25SDRatioToReference', ...
        'Q75SDRatioToReference','MedianRecoveryError','Q25RecoveryError','Q75RecoveryError', ...
        'MedianReferenceRecoveryError','Q25ReferenceRecoveryError', ...
        'Q75ReferenceRecoveryError','MedianReplicateSDRelativeDifference'};
    parts=cell(height(keys),1);
    for i=1:height(keys)
        hit=cases.Scenario==keys.Scenario(i)&cases.Condition==keys.Condition(i)& ...
            cases.Parameter==keys.Parameter(i);
        if certifiedOnly,hit=hit&cases.InCertifiedOnlyValues;end
        C=cases(hit,:);
        ratio=quartiles(C.SDRatioToReference);
        error=quartiles(C.RecoveryError);
        referenceError=quartiles(C.ReferenceRecoveryError);
        spread=median(max(C.ReplicateSDRelativeDifference,C.ReferenceReplicateSDRelativeDifference), ...
            'omitnan');
        if isempty(C),spread=NaN;end
        parts{i}=[keys(i,:),table(height(C),ratio(2),ratio(1),ratio(3),error(2),error(1),error(3), ...
            referenceError(2),referenceError(1),referenceError(3),spread,'VariableNames',names)];
    end
    if isempty(parts)
        S=[keys,array2table(zeros(0,numel(names)),'VariableNames',names)];
    else
        S=vertcat(parts{:});
    end
end

function q=quartiles(values)
%QUARTILES The 25 %, 50 % and 75 % quantiles of the finite values (NaN when there are none).
    values=values(isfinite(values));
    if isempty(values),q=nan(1,3);return;end
    q=reshape(quantile(values,[0.25 0.50 0.75]),1,3);
end

function [included,certifiedOnly]=pair_cohort(matched,scenario,referenceCode,code)
%PAIR_COHORT The matched cases of a condition and the reference (combined and certified-only).
    required=[referenceCode code];
    hit=false(height(matched),1);
    for i=1:height(matched)
        hit(i)=matched.Scenario(i)==scenario&&isequal(sort(split(matched.RequiredConditions(i),"|")), ...
            sort(required(:)));
    end
    assert(nnz(hit)==1,'plotting:conditional_sd_ratio_tables:Cohort', ...
        'The saved matched summary must hold the cohort of %s and %s in %s once.', ...
        referenceCode,code,scenario);
    included=ids(matched.IncludedCaseIDs(hit));
    certifiedOnly=ids(matched.IncludedCaseIDs_certified_only(hit));
end

function v=ids(text)
    text=strtrim(string(text));
    if strlength(text)==0||text=="NaN",v=zeros(1,0);return;end
    v=reshape(double(split(text,";")),1,[]);
end

function v=value(comparison,scenario,caseID,conditionID,parameter,column)
    hit=comparison.Scenario==scenario&comparison.CaseID==caseID& ...
        comparison.ConditionID==conditionID&comparison.Parameter==parameter;
    assert(nnz(hit)==1,'plotting:conditional_sd_ratio_tables:Row', ...
        'The saved comparison must hold one row of case %d, %s, %s, %s.',caseID,scenario, ...
        conditionID,parameter);
    v=double(comparison.(column)(hit));
end

function s=cell_status(status,caseID,scenario,conditionID)
    hit=status.CaseID==caseID&status.Scenario==scenario&status.Condition==conditionID;
    assert(nnz(hit)==1,'plotting:conditional_sd_ratio_tables:Status', ...
        'The saved status table must list case %d, %s, %s once.',caseID,scenario,conditionID);
    s=status.Status(hit);
end

function [distance,sdDifference]=replicate_discrepancy(cfg,record,reference,free)
%REPLICATE_DISCREPANCY The certification's replicate metric of one cell, per free parameter.
%   The normalized Wasserstein distance between the two replicates of the
%   provider's level and the relative difference of their posterior SDs
%   (inversion.posterior_reproducibility); NaN when the cell has one
%   replicate at that level.
    distance=nan(1,numel(free));sdDifference=nan(1,numel(free));
    if reference
        [P,status]=recovery.load_posterior_provider(cfg,record);
    else
        [P,status]=recovery.load_conditional_provider(cfg,record);
    end
    assert(status.loaded,'plotting:conditional_sd_ratio_tables:Provider', ...
        'The matched cell %s of case %d (%s) has no saved posterior: %s', ...
        record.conditionCode,record.caseID,record.scenario,status.reason);
    provider=P.certification.provider;
    runs=cell(1,2);
    for r=1:2
        if reference
            [R,s]=recovery.load_posterior_provider(cfg,record,provider.sampler,r,provider.stepCount);
        else
            [R,s]=recovery.load_conditional_provider(cfg,record,provider.sampler,r,provider.stepCount);
        end
        if ~s.loaded,return;end
        if reference
            X=double(R.drawsPhysical(:,free));
        else
            assert(isequal(reshape(double(R.freeParameterIndices),1,[]),free), ...
                'plotting:conditional_sd_ratio_tables:Free', ...
                'The saved draws of %s, case %d, do not have the free parameters of the condition.', ...
                record.conditionCode,record.caseID);
            X=double(R.drawsFree);
        end
        runs{r}=reshape(X,size(X,1),size(X,2),1);
    end
    report=inversion.posterior_reproducibility(runs{1},runs{2}, ...
        double(cfg.paramBounds(free,:)),inversion.mcmc_diagnostic_thresholds(cfg));
    distance=reshape(report.normalizedWassersteinDistance,1,[]);
    sdDifference=reshape(abs(report.posteriorSD(1,:)-report.posteriorSD(2,:))./ ...
        mean(report.posteriorSD,1),1,[]);
end
