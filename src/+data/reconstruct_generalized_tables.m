function R = reconstruct_generalized_tables(T, cfg)
%RECONSTRUCT_GENERALIZED_TABLES The probe and case registries, QC and cohorts of the generalized dataset.
%   R = data.reconstruct_generalized_tables(T, CFG) turns the generalized
%   dataset table T (setting generalized.dataset.file, one row per designed
%   case with its requested inputs and the outcomes of its D2 and D6 runs;
%   data/README.md) into: the probe registry (one row per D2/D6 probe run,
%   with its availability and classification), the case registry (one row
%   per case), the paired classification, the quality control (strict cycle
%   monotonicity, kept as review evidence: finite six-output cases are
%   complete regardless), the exclusions, the cohort decision and its
%   evidence, the selected cases, the split and the final data contract
%   (data.generalized_data_contract), and the per-output support.
%   Side effects: none.

    T = sortrows(T, 'CaseID');
    S = probe_runs(T);
    nExpected = height(S);
    availability = S.available;
    classification = S.classification;
    classification(ismissing(classification) | strlength(strtrim(classification)) == 0) = ...
        "unavailable";
    productionComplete = S.production_complete;
    probe = S.probe;
    runID = S.RunID;
    caseID = S.CaseID;

    m3Source = S.m3_f_RD_source;
    m3Effective = S.m3_f_RD;
    m3e = S.m3_e_RD;
    k0 = S.k0_RD;
    logk0 = S.log10_k0_RD;
    thickness = S.Thickness_RD;
    signedRate = S.suction_rate_kPa_s;
    logRate = S.log10_abs_suction_rate;
    hold = S.hold_dur_s;
    pause = S.pause_dur_s;
    requested = [m3Effective,m3e,logk0,thickness,logRate,hold,pause];
    bounds = cfg.realExtended.authoritativePhysicalBounds;
    physical = [m3Effective,m3e,k0,thickness,signedRate,hold,pause];
    finiteInputs=all(isfinite(requested),2)&isfinite(k0)&isfinite(signedRate);
    k0TransformValid=finiteInputs&k0>0;
    k0TransformValid(k0TransformValid)=abs(log10(k0(k0TransformValid))- ...
        logk0(k0TransformValid))<=cfg.realExtended.transformTolerance;
    rateTransformValid=finiteInputs&signedRate<0;
    rateTransformValid(rateTransformValid)=abs(log10(abs( ...
        signedRate(rateTransformValid)))-logRate(rateTransformValid))<= ...
        cfg.realExtended.transformTolerance;
    insideBounds=finiteInputs;
    for inputIndex=1:size(physical,2)
        insideBounds=insideBounds&physical(:,inputIndex)>=bounds(inputIndex,1)& ...
            physical(:,inputIndex)<=bounds(inputIndex,2);
    end
    requestedInputValid=finiteInputs&k0TransformValid& ...
        rateTransformValid&insideBounds;

    canonicalStatus = repmat("canonical_unavailable",nExpected,1);
    canonicalStatus(availability) = "canonical_available";
    outcomeClass = classification;
    outcomeClass(~availability) = "truly_missing_or_unavailable";
    pressureValues=[S.pcl1_mbar,S.pcl2_mbar,S.pcl3_mbar];
    pressureAvailable=isfinite(pressureValues)&pressureValues>0;

    % The dataset holds the requested protocol, not the realized one.
    realization = "unavailable_from_selected_snapshot";
    probeRegistry = table(runID,caseID,probe,m3Source,m3Effective,m3e,k0,logk0, ...
        thickness,signedRate,logRate,hold,pause, ...
        nan(nExpected,1),nan(nExpected,1),nan(nExpected,1), ...
        availability,canonicalStatus,S.phase_reached,classification,outcomeClass, ...
        pressureValues(:,1),pressureValues(:,2),pressureValues(:,3), ...
        pressureAvailable(:,1),pressureAvailable(:,2),pressureAvailable(:,3), ...
        ~availability, ...
        classification=="nonlinear_failure",classification=="early_stop_phase5", ...
        productionComplete,requestedInputValid, ...
        repmat(realization,nExpected,1), ...
        'VariableNames', { ...
        'RunID','CaseID','probe','m3_f_RD_source','m3_f_RD','m3_e_RD','k0_RD', ...
        'log10_k0_RD','Thickness_RD','suction_rate_kPa_s', ...
        'log10_abs_suction_rate','hold_dur_s','pause_dur_s', ...
        'realized_suction_rate_kPa_s','realized_hold_dur_s','realized_pause_dur_s', ...
        'availability','canonical_status','phase_reached','classification', ...
        'outcome_class','pcl1_mbar','pcl2_mbar','pcl3_mbar', ...
        'pcl1_available','pcl2_available','pcl3_available', ...
        'missing_flag','failure_flag', ...
        'early_stop_flag','complete_phase9_flag','requested_input_valid', ...
        'protocol_realization_verification'});
    probeRegistry = sortrows(probeRegistry, {'CaseID','probe'});

    caseRegistry = build_case_registry(probeRegistry, T.pair_status);
    pairedClassified = caseRegistry(caseRegistry.D2_availability & ...
        caseRegistry.D6_availability,:);

    provisionalContract=data.generalized_data_contract(caseRegistry,cfg);
    caseRegistry=attach_split_roles( ...
        caseRegistry,provisionalContract.sourceRoleRegistry);
    check_complete_pairs(caseRegistry);
    completeAll=build_complete_table(caseRegistry,provisionalContract);
    assert(numel(provisionalContract.completeCaseIDs)==height(completeAll), ...
        'data:reconstruct_generalized_tables:FinalContractCompleteCount', ...
        'Final canonical complete cases differ from the consolidated table.');

    qc = cycle_drop_qc(completeAll, cfg);
    [decision, evidence] = cohort_decision(completeAll, qc, cfg);
    % Cycle monotonicity remains explicit QC/review evidence, but finite
    % six-output cases satisfy the final-data definition of complete.  Outcome
    % shape is therefore never used to create a fourth split role or to remove
    % complete cases after seeing their responses.
    finalContract=provisionalContract;
    split=finalContract.sourceRoleRegistry;
    caseRegistry=attach_split_roles(caseRegistry,split);
    % Every published complete/QC table carries the authoritative final role;
    % QC-flagged complete cases remain development or external test according
    % to the response-independent material-group split.
    completeAll=attach_final_complete_roles(completeAll,finalContract);
    monotonic=completeAll(qc.monotonic_both,:);
    exclusions=build_exclusions(completeAll,qc,caseRegistry,cfg);
    switch decision.decision
        case 'all_complete_primary'
            selected=completeAll;
        case 'monotonic_qc_primary'
            selected=monotonic;
        otherwise
            selected=completeAll([],:);
    end

    % Support is output-specific. Every finite scalar development observation
    % contributes to the corresponding output's reference cohort; unavailable
    % outputs are never imputed and invalid requested inputs remain explicit.
    support = support_table(caseRegistry, finalContract, cfg);
    caseRegistry = outerjoin(caseRegistry, ...
        support(:,{'CaseID','normalized_nearest_training_distance','support_class'}), ...
        'Keys','CaseID','MergeKeys',true,'Type','left');
    caseRegistry = sortrows(caseRegistry,'CaseID');

    countAudit = table( ...
        ["expected_probe_runids";"available_canonical_probe_outcomes"; ...
         "missing_probe_runids";"expected_caseids";"paired_classified_caseids"; ...
         "source_complete_phase9_pairs";"all_consolidated_complete_output_cases"; ...
         "final_scientific_complete_output_cases"; ...
         "monotonic_retained";"monotonic_excluded"; ...
         "selected_primary_cohort";"complete_development"; ...
         "partial_development";"all_development";"external_test_complete"; ...
         "unusable_no_output"], ...
        [height(probeRegistry);sum(probeRegistry.availability);sum(probeRegistry.missing_flag); ...
         height(caseRegistry);height(pairedClassified); ...
         sum(caseRegistry.complete_pair_flag);height(completeAll); ...
         finalContract.counts.completeCases; ...
         height(monotonic);height(exclusions);height(selected); ...
         finalContract.counts.completeDevelopmentCases; ...
         finalContract.counts.partialDevelopmentCases; ...
         finalContract.counts.developmentCases; ...
         finalContract.counts.externalTestCases; ...
         finalContract.counts.unusableCases], ...
        'VariableNames', {'operation','row_count'});

    R = struct();
    R.probeRegistry = probeRegistry;
    R.caseRegistry = caseRegistry;
    R.pairedClassified = pairedClassified;
    R.completeAll = completeAll;
    R.qc = qc;
    R.monotonic = monotonic;
    R.exclusions = exclusions;
    R.decision = decision;
    R.decisionEvidence = evidence;
    R.selected = selected;
    R.split = split;
    R.finalDataContract = finalContract;
    R.support = support;
    R.countAudit = countAudit;
end

function C = build_case_registry(P, pairStatus)
%BUILD_CASE_REGISTRY One row per case (CaseID order): its inputs and both runs' outcomes; PAIRSTATUS in CaseID order.
    D2 = sortrows(P(P.probe=="D2",:),'CaseID');
    D6 = sortrows(P(P.probe=="D6",:),'CaseID');
    n = height(D2);
    C = table(D2.CaseID,D2.RunID,D6.RunID,D2.m3_f_RD_source,D2.m3_f_RD, ...
        D2.m3_e_RD,D2.k0_RD,D2.log10_k0_RD,D2.Thickness_RD, ...
        D2.suction_rate_kPa_s,D2.log10_abs_suction_rate,D2.hold_dur_s,D2.pause_dur_s, ...
        D2.availability,D6.availability,D2.classification,D6.classification, ...
        D2.phase_reached,D6.phase_reached, ...
        D2.pcl1_mbar,D2.pcl2_mbar,D2.pcl3_mbar, ...
        D6.pcl1_mbar,D6.pcl2_mbar,D6.pcl3_mbar, ...
        D2.pcl1_available,D2.pcl2_available,D2.pcl3_available, ...
        D6.pcl1_available,D6.pcl2_available,D6.pcl3_available, ...
        'VariableNames', {'CaseID','D2_RunID','D6_RunID','m3_f_RD_source','m3_f_RD', ...
        'm3_e_RD','k0_RD','log10_k0_RD','Thickness_RD','suction_rate_kPa_s', ...
        'log10_abs_suction_rate','hold_dur_s','pause_dur_s','D2_availability', ...
        'D6_availability','D2_classification','D6_classification','D2_phase_reached', ...
        'D6_phase_reached','pcl1_D2_mbar','pcl2_D2_mbar','pcl3_D2_mbar', ...
        'pcl1_D6_mbar','pcl2_D6_mbar','pcl3_D6_mbar', ...
        'pcl1_D2_available','pcl2_D2_available','pcl3_D2_available', ...
        'pcl1_D6_available','pcl2_D6_available','pcl3_D6_available'});
    C.pair_status = string(pairStatus(:));
    C.complete_pair_flag = C.D2_classification=="solved_phase9" & ...
        C.D6_classification=="solved_phase9";
    C.any_missing_flag = ~C.D2_availability | ~C.D6_availability;
    C.any_failure_flag = C.D2_classification=="nonlinear_failure" | ...
        C.D6_classification=="nonlinear_failure";
    C.any_early_stop_flag = C.D2_classification=="early_stop_phase5" | ...
        C.D6_classification=="early_stop_phase5";
    C.requested_input_valid=D2.requested_input_valid&D6.requested_input_valid;
    invalid=~C.requested_input_valid;
    invalidNames={'m3_f_RD','m3_e_RD','k0_RD','log10_k0_RD', ...
        'Thickness_RD','suction_rate_kPa_s','log10_abs_suction_rate', ...
        'hold_dur_s','pause_dur_s'};
    for inputIndex=1:numel(invalidNames)
        C.(invalidNames{inputIndex})(invalid)=NaN;
    end
    C.analysis_outcome_class = classify_cases(C);
    C.protocol_realization_verification(:) = ...
        "unavailable_from_selected_snapshot";
    assert(height(C)==n,'data:reconstruct_generalized_tables:Height','Unexpected registry height.');
end

function C=attach_split_roles(C,split)
    [found,loc]=ismember(double(C.CaseID),double(split.CaseID));
    assert(all(found),'data:reconstruct_generalized_tables:SplitMissing','Split role missing.');
    C.future_train_test_role=string(split.split_role(loc));
    C.final_data_classification=string(split.Classification(loc));
    C.duplicate_group=string(split.DuplicateGroup(loc));
    C.split_group=string(split.SplitGroup(loc));
end

function T=attach_final_complete_roles(T,contract)
    manifest=contract.caseManifest;
    [eligible,eligibleLocation]=ismember( ...
        double(T.CaseID),double(manifest.CaseID));
    assert(all(eligible), ...
        'data:reconstruct_generalized_tables:FinalRoleBinding', ...
        'Every complete table row must have one development/test role.');
    T.future_train_test_role=strings(height(T),1);
    T.split_role=strings(height(T),1);
    T.final_data_classification=strings(height(T),1);
    T.duplicate_group=strings(height(T),1);
    T.split_group=strings(height(T),1);
    location=eligibleLocation;
    T.future_train_test_role=string(manifest.MethodologicalRole(location));
    T.split_role=T.future_train_test_role;
    T.final_data_classification=string(manifest.Classification(location));
    T.duplicate_group=string(manifest.DuplicateGroup(location));
    T.split_group=string(manifest.SplitGroup(location));
end

function label = classify_cases(C)
    n=height(C); label=repmat("other_recorded_incomplete_outcome",n,1);
    label(C.any_missing_flag)="truly_missing_or_unavailable";
    label(C.any_early_stop_flag & ~C.any_missing_flag)="recorded_phase5_early_stop";
    label(C.any_failure_flag & ~C.any_missing_flag)="recorded_nonlinear_failure";
    label(C.D2_classification=="solved_phase9" & ...
        C.D6_classification~="solved_phase9" & C.D6_availability)= ...
        "D2_complete_D6_noncomplete";
    label(C.D6_classification=="solved_phase9" & ...
        C.D2_classification~="solved_phase9" & C.D2_availability)= ...
        "D6_complete_D2_noncomplete";
    label(C.complete_pair_flag)="both_probes_complete_phase9";
end

function check_complete_pairs(C)
%CHECK_COMPLETE_PAIRS Both runs solved to phase 9: finite inputs and six finite positive pressures.
    T=C(C.complete_pair_flag,:);
    pressureNames = {'pcl1_D2_mbar','pcl2_D2_mbar','pcl3_D2_mbar', ...
        'pcl1_D6_mbar','pcl2_D6_mbar','pcl3_D6_mbar'};
    Y = T{:,pressureNames};
    X = T{: ,{'m3_f_RD','m3_e_RD','log10_k0_RD','Thickness_RD', ...
        'log10_abs_suction_rate','hold_dur_s','pause_dur_s'}};
    assert(all(isfinite(X),'all') && all(isfinite(Y),'all') && all(Y>0,'all'), ...
        'data:reconstruct_generalized_tables:Validity', ...
        'Complete-pair inputs/pressures must be finite and positive.');
end

function T=build_complete_table(C,contract)
%BUILD_COMPLETE_TABLE Materialize one row per consolidated scientific case.
%   Source aliases remain in the source registry. This table uses the merged
%   finite values owned by DATA.FINAL_DATA_CONTRACT and therefore never
%   expands one canonical material/protocol state back into duplicate rows.
    manifest=contract.caseManifest;
    canonical=manifest(manifest.Classification=="complete",:);
    assert(~isempty(canonical),'data:reconstruct_generalized_tables:Empty', ...
        'No complete consolidated generalized case is available.');
    representative=zeros(height(canonical),1);
    sourcePhase9=false(height(canonical),1);
    sourceIDs=strings(height(canonical),1);
    for index=1:height(canonical)
        canonicalID=double(canonical.CaseID(index));
        mapped=contract.sourceMap.SourceRow( ...
            double(contract.sourceMap.CaseID)==canonicalID);
        [present,locations]=ismember(double(mapped),double(C.CaseID));
        assert(all(present)&&~isempty(locations), ...
            'data:reconstruct_generalized_tables:SourceAliases', ...
            'Canonical CaseID %d has no source aliases.',canonicalID);
        preferred=find(double(C.CaseID(locations))==canonicalID,1);
        if isempty(preferred),preferred=1;end
        representative(index)=locations(preferred);
        sourcePhase9(index)=any(logical(C.complete_pair_flag(locations)));
        sourceIDs(index)=join(string(double(C.CaseID(locations)).'),';');
    end
    T=C(representative,:);
    inputNames={'m3_f_RD','m3_e_RD','log10_k0_RD','Thickness_RD', ...
        'log10_abs_suction_rate','hold_dur_s','pause_dur_s'};
    pressureNames={'pcl1_D2_mbar','pcl2_D2_mbar','pcl3_D2_mbar', ...
        'pcl1_D6_mbar','pcl2_D6_mbar','pcl3_D6_mbar'};
    T.CaseID=double(canonical.CaseID);
    T{:,inputNames}=double(canonical{:,inputNames});
    T.k0_RD=10.^T.log10_k0_RD;
    T.suction_rate_kPa_s=-10.^T.log10_abs_suction_rate;
    T{:,pressureNames}=double(canonical{:,pressureNames});
    T.D2_availability(:)=true;T.D6_availability(:)=true;
    availabilityNames={'pcl1_D2_available','pcl2_D2_available', ...
        'pcl3_D2_available','pcl1_D6_available','pcl2_D6_available', ...
        'pcl3_D6_available'};
    for outputIndex=1:numel(availabilityNames)
        T.(availabilityNames{outputIndex})(:)=true;
    end
    T.complete_pair_flag(:)=true;
    T.requested_input_valid(:)=true;
    T.future_train_test_role=string(canonical.MethodologicalRole);
    T.final_data_classification(:)="complete";
    T.duplicate_group=string(canonical.DuplicateGroup);
    T.split_group=string(canonical.SplitGroup);
    T.consolidated_source_case_ids=sourceIDs;
    T.consolidated_source_count=double(canonical.DuplicateSourceCount);
    T.source_complete_phase9_evidence=sourcePhase9;
    T.representative_source_case_id=double(C.CaseID(representative));
    T.complementary_merge_used=T.consolidated_source_count>1;
    T.source_provenance_semantics=repmat( ...
        "single_source_row",height(T),1);
    merged=T.complementary_merge_used;
    T.source_provenance_semantics(merged)= ...
        "consolidated_material_case_see_consolidated_source_case_ids";
    T.D2_RunID(merged)="consolidated_multiple_source_aliases";
    T.D6_RunID(merged)="consolidated_multiple_source_aliases";
    T.D2_classification(merged)="consolidated_output_evidence";
    T.D6_classification(merged)="consolidated_output_evidence";
    T.D2_phase_reached(merged)=NaN;T.D6_phase_reached(merged)=NaN;
    T.any_missing_flag(merged)=false;T.any_failure_flag(merged)=false;
    T.any_early_stop_flag(merged)=false;
    T.analysis_outcome_class(merged)= ...
        "consolidated_complete_output_evidence";
    T.pair_status(merged)="consolidated_complete_output_evidence";
    T.split_role=T.future_train_test_role;
    assert(numel(unique(T.CaseID))==height(T)&& ...
        all(isfinite(T{:,inputNames}),'all')&& ...
        all(isfinite(T{:,pressureNames}),'all')&& ...
        all(T{:,pressureNames}>0,'all'), ...
        'data:reconstruct_generalized_tables:CanonicalValidity', ...
        'Consolidated complete cases must be unique, finite and positive.');
end

function Q = cycle_drop_qc(T,cfg)
    Q=T(:,{'CaseID','D2_RunID','D6_RunID'});
    Q.drop12_D2_mbar=T.pcl1_D2_mbar-T.pcl2_D2_mbar;
    Q.drop23_D2_mbar=T.pcl2_D2_mbar-T.pcl3_D2_mbar;
    Q.drop13_D2_mbar=T.pcl1_D2_mbar-T.pcl3_D2_mbar;
    Q.drop12_D6_mbar=T.pcl1_D6_mbar-T.pcl2_D6_mbar;
    Q.drop23_D6_mbar=T.pcl2_D6_mbar-T.pcl3_D6_mbar;
    Q.drop13_D6_mbar=T.pcl1_D6_mbar-T.pcl3_D6_mbar;
    Q.rel_drop12_D2=Q.drop12_D2_mbar./T.pcl1_D2_mbar;
    Q.rel_drop23_D2=Q.drop23_D2_mbar./T.pcl2_D2_mbar;
    Q.rel_drop13_D2=Q.drop13_D2_mbar./T.pcl1_D2_mbar;
    Q.rel_drop12_D6=Q.drop12_D6_mbar./T.pcl1_D6_mbar;
    Q.rel_drop23_D6=Q.drop23_D6_mbar./T.pcl2_D6_mbar;
    Q.rel_drop13_D6=Q.drop13_D6_mbar./T.pcl1_D6_mbar;
    Q.min_cycle_drop_D2_mbar=min([Q.drop12_D2_mbar,Q.drop23_D2_mbar],[],2);
    Q.min_cycle_drop_D6_mbar=min([Q.drop12_D6_mbar,Q.drop23_D6_mbar],[],2);
    tol=cfg.realExtended.monotonicToleranceMbar;
    Q.monotonic_D2=Q.drop12_D2_mbar>tol & Q.drop23_D2_mbar>tol;
    Q.monotonic_D6=Q.drop12_D6_mbar>tol & Q.drop23_D6_mbar>tol;
    Q.monotonic_both=Q.monotonic_D2 & Q.monotonic_D6;
    Q.strict_monotonic_D2=Q.drop12_D2_mbar>0 & Q.drop23_D2_mbar>0;
    Q.strict_monotonic_D6=Q.drop12_D6_mbar>0 & Q.drop23_D6_mbar>0;
    Q.strict_monotonic_both=Q.strict_monotonic_D2 & Q.strict_monotonic_D6;
    Q.monotonic_rule_version(:)="strict_adjacent_cycle_drop_gt_zero_v1";
    Q.monotonic_tolerance_mbar(:)=tol;
    Q.relative_drop_denominator_rule(:)= ...
        "drop12/pcl1; drop23/pcl2; drop13/pcl1 within each probe";
    Q.exclusion_reason(:)="";
    Q.exclusion_reason(~Q.monotonic_D2 & Q.monotonic_D6)= ...
        "D2_adjacent_cycle_pressure_not_strictly_decreasing";
    Q.exclusion_reason(Q.monotonic_D2 & ~Q.monotonic_D6)= ...
        "D6_adjacent_cycle_pressure_not_strictly_decreasing";
    Q.exclusion_reason(~Q.monotonic_D2 & ~Q.monotonic_D6)= ...
        "both_probes_adjacent_cycle_pressure_not_strictly_decreasing";
end

function E = build_exclusions(T,Q,C,cfg)
    idx=~Q.monotonic_both;
    E=T(idx,:);
    q=Q(idx,:);
    dropNames=setdiff(q.Properties.VariableNames, ...
        {'CaseID','D2_RunID','D6_RunID','monotonic_D2','monotonic_D6', ...
        'monotonic_both','strict_monotonic_D2','strict_monotonic_D6', ...
        'strict_monotonic_both','monotonic_rule_version', ...
        'monotonic_tolerance_mbar','relative_drop_denominator_rule', ...
        'exclusion_reason'},'stable');
    E=[E q(:,dropNames)];
    E.violating_probes=repmat("",height(E),1);
    E.violating_probes(~q.monotonic_D2 & q.monotonic_D6)="D2";
    E.violating_probes(q.monotonic_D2 & ~q.monotonic_D6)="D6";
    E.violating_probes(~q.monotonic_D2 & ~q.monotonic_D6)="D2_and_D6";
    E.rounding_or_substantive=repmat("substantive",height(E),1);
    minDrop=min([q.min_cycle_drop_D2_mbar,q.min_cycle_drop_D6_mbar],[],2);
    E.rounding_or_substantive(abs(minDrop)<cfg.realExtended.roundingScaleMbar)= ...
        "rounding_scale";
    E.exclusion_reason=q.exclusion_reason;
    proto=[E.log10_abs_suction_rate,E.hold_dur_s,E.pause_dur_s];
    default=[log10(abs(cfg.realExtended.defaultProtocol.suction_rate_kPa_s)), ...
        cfg.realExtended.defaultProtocol.hold_dur_s, ...
        cfg.realExtended.defaultProtocol.pause_dur_s];
    pb=cfg.realExtended.learningBounds(5:7,:);
    E.distance_from_default_protocol=sqrt(sum(((proto-default)./ ...
        (pb(:,2)-pb(:,1)).').^2,2));
    [found,loc]=ismember(E.CaseID,C.CaseID);assert(all(found));
    E.D2_solver_classification=C.D2_classification(loc);
    E.D6_solver_classification=C.D6_classification(loc);
end

function [decision,evidence]=cohort_decision(T,Q,cfg)
    keep=Q.monotonic_both; excluded=~keep;
    nExcluded=sum(excluded);
    inputs={'m3_f_RD','m3_e_RD','log10_k0_RD','Thickness_RD', ...
        'log10_abs_suction_rate','hold_dur_s','pause_dur_s'};
    standardizedDifference=nan(numel(inputs),1);
    retainedMean=nan(numel(inputs),1); excludedMean=nan(numel(inputs),1);
    for i=1:numel(inputs)
        a=double(T{keep,inputs{i}}); b=double(T{excluded,inputs{i}});
        retainedMean(i)=mean(a);excludedMean(i)=mean(b);
        pooled=sqrt(((numel(a)-1)*var(a)+(numel(b)-1)*var(b))/ ...
            max(numel(a)+numel(b)-2,1));
        standardizedDifference(i)=(excludedMean(i)-retainedMean(i))/max(pooled,eps);
    end
    evidence=struct();
    evidence.input_names=inputs;
    evidence.retained_mean=retainedMean;
    evidence.excluded_mean=excludedMean;
    evidence.standardized_difference=standardizedDifference;
    evidence.exclusion_fraction=mean(excluded);
    evidence.monotonic_retained=sum(keep);
    evidence.monotonic_excluded=sum(excluded);
    evidence.excluded_case_ids=double(T.CaseID(excluded)).';
    rates=double(T.log10_abs_suction_rate);
    [~,fastOrder]=sort(rates,'descend');
    if nExcluded>0
        fastestIDs=double(T.CaseID(fastOrder(1:nExcluded)));
        evidence.excluded_are_exact_fastest_tail= ...
            isequal(sort(fastestIDs),sort(double(T.CaseID(excluded))));
    else
        evidence.excluded_are_exact_fastest_tail=false;
    end
    evidence.max_abs_protocol_smd=max(abs(standardizedDifference(5:7)));
    evidence.max_abs_material_smd=max(abs(standardizedDifference(1:4)));
    evidence.all_exclusions_complete_phase9= ...
        all(T.source_complete_phase9_evidence(excluded));
    evidence.all_excluded_pressures_positive=all(T{excluded, ...
        {'pcl1_D2_mbar','pcl2_D2_mbar','pcl3_D2_mbar', ...
        'pcl1_D6_mbar','pcl2_D6_mbar','pcl3_D6_mbar'}}>0,'all');
    evidence.simple_classifier_status=sprintf( ...
        "not_fit_only_%d_exclusions_effect_size_and_exact_fastest_tail_used", ...
        nExcluded);
    trigger=evidence.exclusion_fraction>cfg.realExtended.monotonicReviewFraction;
    materialAssociation=evidence.excluded_are_exact_fastest_tail || ...
        evidence.max_abs_protocol_smd>=cfg.realExtended.protocolAssociationSMD;
    if nExcluded==0
        reviewRecommendation='all_complete_primary';
        reviewRationale=['No consolidated complete-output case violates the recovered ' ...
            'monotonicity rule, so the all-complete and monotonic cohorts are identical.'];
    elseif evidence.all_exclusions_complete_phase9 && ...
            evidence.all_excluded_pressures_positive && materialAssociation
        reviewRecommendation='all_complete_primary';
        reviewRationale=sprintf(['All %d nonmonotonic rows have direct source-complete ' ...
            'phase-9 evidence and form the exact fastest successful-protocol tail. ' ...
            'Excluding them would remove the observed fast-rate boundary and ' ...
            'materially bias protocol-space coverage; no extraction defect is ' ...
            'present in the snapshot.'],nExcluded);
    elseif ~trigger && ~materialAssociation
        reviewRecommendation='monotonic_qc_primary';
        reviewRationale=['Strict monotonic flags are sparse and show no material ' ...
            'protocol association under the preregistered effect-size checks.'];
    else
        reviewRecommendation='ambiguous_requires_review';
        reviewRationale=['The monotonicity evidence does not uniquely support one ' ...
            'scientific interpretation and remains flagged for review.'];
    end
    choice='all_complete_primary';
    rationale=['The versioned final-data contract classifies every finite six-output ' ...
        'case as complete. Cycle monotonicity is retained as review evidence and ' ...
        'does not alter model eligibility or the development/external split.'];
    decision=struct( ...
        'schema_version','real_extended_primary_cohort_decision_v1', ...
        'snapshot_id',cfg.realExtended.snapshotID, ...
        'decision',choice, ...
        'rationale',rationale, ...
        'qc_review_recommendation',reviewRecommendation, ...
        'qc_review_rationale',reviewRationale, ...
        'qc_controls_model_eligibility',false, ...
        'all_complete_count',height(T), ...
        'monotonic_count',sum(keep), ...
        'excluded_count',sum(excluded), ...
        'exclusion_fraction',mean(excluded), ...
        'review_trigger_fraction',cfg.realExtended.monotonicReviewFraction, ...
        'review_trigger_active',trigger, ...
        'protocol_association_material',materialAssociation, ...
        'excluded_are_exact_fastest_tail',evidence.excluded_are_exact_fastest_tail, ...
        'requested_protocol_source','dataset_requested_inputs', ...
        'protocol_realization_verification', ...
        'unavailable_from_selected_snapshot', ...
        'posterior_certification','not_applicable', ...
        'claim_scope','selected_snapshot_dataset_and_feasibility_audit');
end

function support=support_table(C,contract,cfg)
    names={'m3_f_RD','m3_e_RD','log10_k0_RD','Thickness_RD', ...
        'log10_abs_suction_rate','hold_dur_s','pause_dur_s'};
    outputNames=cfg.realExtended.outputNames;
    bounds=cfg.realExtended.learningBounds;
    allX=double(C{:,names});
    validInput=logical(C.requested_input_valid)&all(isfinite(allX),2);
    span=(bounds(:,2)-bounds(:,1)).';
    allU=(allX-bounds(:,1).')./span;
    nCase=height(C);nOutput=numel(outputNames);
    distance=nan(nCase,nOutput);labels=strings(nCase,nOutput);
    wellThreshold=nan(1,nOutput);weakThreshold=nan(1,nOutput);
    trainingCount=zeros(1,nOutput);outputAvailable=false(nCase,nOutput);
    manifest=contract.caseManifest;
    [mapped,mapLocation]=ismember(double(C.CaseID), ...
        double(contract.sourceMap.SourceRow));
    canonicalCaseID=nan(nCase,1);
    canonicalCaseID(mapped)=double(contract.sourceMap.CaseID(mapLocation(mapped)));
    [usable,location]=ismember(canonicalCaseID,double(manifest.CaseID));
    development=string(manifest.MethodologicalRole)=="development";
    for outputIndex=1:nOutput
        observed=isfinite(double(contract.Y_all(:,outputIndex)));
        reference=development&observed;
        trainingX=double(contract.X_all(reference,:));
        trainingIDs=double(manifest.CaseID(reference));
        trainingCount(outputIndex)=size(trainingX,1);
        assert(trainingCount(outputIndex)>=2&&all(isfinite(trainingX),'all'), ...
            'data:reconstruct_generalized_tables:OutputSupportCohort', ...
            'Output %d has fewer than two valid development rows.',outputIndex);
        trainingU=(trainingX-bounds(:,1).')./span;
        for caseIndex=find(validInput).'
            one=sqrt(sum((trainingU-allU(caseIndex,:)).^2,2));
            if ismember(canonicalCaseID(caseIndex),trainingIDs)
                one(trainingIDs==canonicalCaseID(caseIndex))=inf;
            end
            distance(caseIndex,outputIndex)=min(one);
        end
        trainingDistance=nan(trainingCount(outputIndex),1);
        for trainingIndex=1:trainingCount(outputIndex)
            one=sqrt(sum((trainingU-trainingU(trainingIndex,:)).^2,2));
            one(trainingIndex)=inf;
            trainingDistance(trainingIndex)=min(one);
        end
        thresholds=utils.weighted_quantile(trainingDistance,[0.75 0.95]);
        assert(all(isfinite(thresholds))&&thresholds(1)>0&& ...
            thresholds(2)>=thresholds(1), ...
            'data:reconstruct_generalized_tables:OutputSupportThresholds', ...
            'Output %d support thresholds are invalid.',outputIndex);
        wellThreshold(outputIndex)=thresholds(1);
        weakThreshold(outputIndex)=thresholds(2);
        oneLabel=repmat("extrapolative",nCase,1);
        oneLabel(distance(:,outputIndex)<=thresholds(2))="weakly_supported";
        oneLabel(distance(:,outputIndex)<=thresholds(1))="well_supported";
        oneLabel(~validInput)="unavailable_invalid_input";
        present=usable;
        present(usable)=isfinite(double(contract.Y_all( ...
            location(usable),outputIndex)));
        outputAvailable(:,outputIndex)=present;
        missingOutput=validInput&~present;
        oneLabel(missingOutput&C.any_missing_flag)= ...
            "unresolved_due_to_missing_outcome";
        oneLabel(missingOutput&~C.any_missing_flag)= ...
            "inside_known_noncomplete_region";
        labels(:,outputIndex)=oneLabel;
    end
    aggregateDistance=max(distance,[],2,'omitnan');
    aggregateDistance(all(~isfinite(distance),2))=NaN;
    aggregateLabel=worst_support_label(labels);
    support=table(C.CaseID,aggregateDistance,aggregateLabel, ...
        C.complete_pair_flag,C.any_missing_flag,C.analysis_outcome_class, ...
        repmat(max(wellThreshold),nCase,1), ...
        repmat(max(weakThreshold),nCase,1), ...
        repmat("finite_output_specific_development_rows_no_imputation",nCase,1), ...
        'VariableNames',{'CaseID','normalized_nearest_training_distance', ...
        'support_class','complete_pair_flag','missing_flag','outcome_class', ...
        'well_supported_threshold','weakly_supported_threshold', ...
        'support_reference_scope'});
    support.requested_input_valid=validInput;
    for outputIndex=1:nOutput
        suffix=matlab.lang.makeValidName(outputNames{outputIndex});
        support.(['normalized_nearest_training_distance_' suffix])= ...
            distance(:,outputIndex);
        support.(['support_class_' suffix])=labels(:,outputIndex);
        support.(['output_available_' suffix])=outputAvailable(:,outputIndex);
        support.(['well_supported_threshold_' suffix])= ...
            repmat(wellThreshold(outputIndex),nCase,1);
        support.(['weakly_supported_threshold_' suffix])= ...
            repmat(weakThreshold(outputIndex),nCase,1);
        support.(['support_training_count_' suffix])= ...
            repmat(trainingCount(outputIndex),nCase,1);
    end
end

function label=worst_support_label(labels)
    order=["well_supported","weakly_supported","extrapolative", ...
        "inside_known_noncomplete_region", ...
        "unresolved_due_to_missing_outcome","unavailable_invalid_input"];
    score=zeros(size(labels));
    for index=1:numel(order),score(labels==order(index))=index;end
    [~,worst]=max(score,[],2);
    label=reshape(order(worst),[],1);
end

function S=probe_runs(T)
%PROBE_RUNS One row per D2/D6 run of every case, in CaseID order (D2 first):
%   the case's requested inputs (one set per case, the same for both runs),
%   the run's RunID (case00001_D2, ...), outcome and closing pressures.
    inputs={'m3_f_RD_source','m3_f_RD','m3_e_RD','k0_RD','log10_k0_RD', ...
        'Thickness_RD','suction_rate_kPa_s','log10_abs_suction_rate', ...
        'hold_dur_s','pause_dur_s'};
    n=height(T);caseID=double(T.CaseID);
    parts=cell(1,2);probes={'D2','D6'};
    for p=1:2
        probe=probes{p};
        one=table("case"+compose("%05d",caseID)+"_"+probe,caseID, ...
            repmat(string(probe),n,1),'VariableNames',{'RunID','CaseID','probe'});
        for k=1:numel(inputs),one.(inputs{k})=double(T.(inputs{k}));end
        one.available=logical_column(T.([probe '_available']));
        one.classification=string(T.([probe '_classification']));
        one.phase_reached=double(T.([probe '_phase_reached']));
        one.production_complete=logical_column(T.([probe '_production_complete']));
        for cycle=1:3
            one.(sprintf('pcl%d_mbar',cycle))=double(T.(sprintf('pcl%d_%s_mbar',cycle,probe)));
        end
        parts{p}=one;
    end
    S=[parts{1};parts{2}];
    S=S(reshape([1:n;n+1:2*n],[],1),:);
end

function value=logical_column(value)
    if islogical(value),return;end
    if isnumeric(value),value=value~=0;return;end
    text=lower(strtrim(string(value)));
    value=text=="true"|text=="1";
end
