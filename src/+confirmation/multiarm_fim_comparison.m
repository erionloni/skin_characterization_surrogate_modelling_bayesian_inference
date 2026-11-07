function [rows,aggregate]=multiarm_fim_comparison(cfg,provider,grid,weak,evaluator)
%MULTIARM_FIM_COMPARISON FIM-predicted and AIES-observed change of the weak-pair variance, per confirmation pair.
%   [ROWS, AGGREGATE] = confirmation.multiarm_fim_comparison(CFG, PROVIDER,
%   GRID, WEAK, EVALUATOR) evaluates, in one pass, the local information
%   of every protocol of the confirmation (GRID.protocols: the shared
%   reference and the selected ones) at every material of the comparisons
%   (GRID.pairs, confirmation.build_confirmation_grid) with EVALUATOR
%   (screening.evaluate_local_information: the full covariance of the
%   operational measurement-plus-emulator case, policy CFG.stage9bScreening,
%   over the pressures of the grid's observation design, GRID.designs(1):
%   d2_only the three D2 pressures)
%   and the model provider PROVIDER (screening.generalized_provider). For
%   each pair it compares the largest eigenvalue of the weak-pair
%   covariance that the FIM proxy predicts for the reference and the
%   selected protocol with the one observed in the certified AIES
%   posteriors (WEAK: one row per cell with MaterialCaseID, Protocol,
%   LambdaMax_Cq, ArtifactLoaded and CertificationMechanism).
%   ROWS: one row per pair: PairIndex, MaterialCaseID, FIMProxyValid, the
%   predicted and the observed largest eigenvalue of both protocols and
%   their changes, ObservedMinusPredictedDelta, ComparisonRole, and the six
%   objectives of both protocols (FIMDefault_<objective>,
%   FIMSelected_<objective>; screening.covariance_objectives).
%   AGGREGATE: per comparison role, the counts and the means over the pairs
%   with a valid FIM proxy and a certified AIES pair.
%   Side effects: none.
%   Computation: seconds to a minute (the local information at every truth
%   and protocol).
    P=grid.protocols;
    candidates=table(P.Protocol,P.ProtocolIndex,P.Log10AbsRate,P.Hold_s,P.Pause_s, ...
        true(height(P),1),'VariableNames',{'CandidateID','CandidateIndex','Log10AbsRate', ...
        'Hold_s','Pause_s','WithinConfiguredBounds'});
    pairs=grid.pairs;
    [~,keep]=unique(pairs.MaterialCaseID,'stable');p=pairs(keep,:);
    materials=table(string(p.MaterialCaseID),p.m3_f_RD,p.m3_e_RD,p.log10_k0_RD,p.Thickness_RD, ...
        'VariableNames',{'MaterialPointID','m3_f_RD','m3_e_RD','log10_k0_RD','Thickness_RD'});
    outputs=1:6;
    if isfield(grid,'designs')
        % The FIM proxy of the design the posteriors observe.
        outputs=inversion.design_registry(grid.designs(1).name).sourceOutputIndices;
    end
    [local,~]=evaluator(provider,candidates,materials,cfg.stage9bScreening, ...
        'RetainFullCovariance',true,'Outputs',outputs);
    v=find(strcmp(local.CovarianceCases,'operational_measurement_plus_emulator'));
    assert(isscalar(v)&&isfield(local,'FullCovariance'), ...
        'confirmation:multiarm_fim_comparison:Contract','Full four-material covariance is required.');
    objectives=screening.objective_registry();rows=table();
    certifiedCell=weak.ArtifactLoaded&startsWith(string(weak.CertificationMechanism),"CERTIFIED");
    for i=1:height(pairs)
        id=double(pairs.MaterialCaseID(i));
        m=find(materials.MaterialPointID==string(id));
        d=find(P.Protocol==string(pairs.DefaultProtocol(i)));
        s=find(P.Protocol==string(pairs.SelectedProtocol(i)));
        valid=all(local.Valid(m,[d s],v));pd=nan(1,6);ps=pd;
        if valid
            pd=screening.covariance_objectives(local.FullCovariance(:,:,m,d,v));
            ps=screening.covariance_objectives(local.FullCovariance(:,:,m,s,v));
        end
        dw=weak.MaterialCaseID==id&weak.Protocol==string(pairs.DefaultProtocol(i))&certifiedCell;
        sw=weak.MaterialCaseID==id&weak.Protocol==string(pairs.SelectedProtocol(i))&certifiedCell;
        certified=nnz(dw)==1&&nnz(sw)==1;od=NaN;os=NaN;
        if certified,od=weak.LambdaMax_Cq(dw);os=weak.LambdaMax_Cq(sw);end
        row=table(pairs.PairIndex(i),id,logical(valid),pd(1),ps(1), ...
            ps(1)-pd(1),certified,od,os,os-od,(os-od)-(ps(1)-pd(1)), ...
            string(pairs.ComparisonRole(i)), ...
            'VariableNames',{'PairIndex','MaterialCaseID','FIMProxyValid','FIMProxyDefaultLambdaMax', ...
            'FIMProxySelectedLambdaMax','FIMProxyPredictedDeltaLambdaMax','PairedAIESCertified', ...
            'AIESDefaultLambdaMax','AIESSelectedLambdaMax','AIESObservedDeltaLambdaMax', ...
            'ObservedMinusPredictedDelta','ComparisonRole'});
        for o=1:6
            row.(['FIMDefault_' char(objectives.ObjectiveID(o))])=pd(o);
            row.(['FIMSelected_' char(objectives.ObjectiveID(o))])=ps(o);
        end
        rows=[rows;row]; %#ok<AGROW>
    end
    aggregate=table();
    for role=reshape(unique(rows.ComparisonRole,'stable'),1,[])
        T=rows(rows.ComparisonRole==role,:);ok=T.FIMProxyValid&T.PairedAIESCertified;
        a=table(role,nnz(T.FIMProxyValid),nnz(T.PairedAIESCertified),nnz(ok), ...
            mean(T.FIMProxyDefaultLambdaMax(ok)),mean(T.FIMProxySelectedLambdaMax(ok)), ...
            mean(T.FIMProxyPredictedDeltaLambdaMax(ok)),mean(T.AIESDefaultLambdaMax(ok)), ...
            mean(T.AIESSelectedLambdaMax(ok)),mean(T.AIESObservedDeltaLambdaMax(ok)), ...
            mean(T.ObservedMinusPredictedDelta(ok)),strjoin(string(T.MaterialCaseID(ok)),';'), ...
            'VariableNames',{'ComparisonRole','FIMProxyValidCaseCount','AIESCertifiedPairCount', ...
            'CommonComparableCaseCount','MeanFIMProxyDefaultLambdaMax','MeanFIMProxySelectedLambdaMax', ...
            'MeanFIMProxyPredictedDeltaLambdaMax','MeanAIESDefaultLambdaMax','MeanAIESSelectedLambdaMax', ...
            'MeanAIESObservedDeltaLambdaMax','MeanObservedMinusPredictedDelta','CommonMaterialCaseIDs'});
        aggregate=[aggregate;a]; %#ok<AGROW>
    end
end
