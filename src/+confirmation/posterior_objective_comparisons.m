function evidence=posterior_objective_comparisons(grid,matrices,status,fim,tolerance)
%POSTERIOR_OBJECTIVE_COMPARISONS The six objectives of the certified posteriors, paired reference against selected.
%   EVIDENCE = confirmation.posterior_objective_comparisons(GRID, MATRICES,
%   STATUS, FIM, TOLERANCE) computes the six screening objectives
%   (screening.covariance_objectives) from the saved 4-by-4 posterior
%   covariance of every cell with a loaded provider (MATRICES: 16 rows per
%   cell, in prior-standard-deviation coordinates; STATUS: one row per
%   cell; both keyed by ConfirmationCellIndex), and compares, for every
%   planned comparison of GRID.comparisons, the selected protocol with the
%   shared reference on the same material: paired change, percent
%   reduction, improvement beyond TOLERANCE (relative, at least 1) and near
%   equality, next to the FIM proxy's values of the same pair (FIM,
%   confirmation.multiarm_fim_comparison). Posterior values come only from
%   saved covariances; none is invented for a missing cell.
%   EVIDENCE: cellMetrics (one row per cell and objective), pairedMetrics
%   (one row per comparison and objective), aggregate (per role, objective
%   and cohort: pairwise certified, common all-arms certified, pairwise all
%   available) and commonAllArmCohort (per material, whether every arm is
%   certified).
%   Side effects: none.
    registry=screening.objective_registry();cells=table();
    for i=1:height(status)
        id=status.ConfirmationCellIndex(i);hit=matrices.ConfirmationCellIndex==id;
        M=matrices(hit,:);values=nan(1,6);
        available=status.Certified(i);
        if ismember('ArtifactLoaded',status.Properties.VariableNames),available=status.ArtifactLoaded(i);end
        if available
            assert(height(M)==16&&all(M.ArtifactLoaded), ...
                'confirmation:posterior_objective_comparisons:Covariance','Incomplete covariance table.');
            C=nan(4);indices=sub2ind([4 4],M.RowIndex,M.ColumnIndex);
            assert(numel(unique(indices))==16,'confirmation:posterior_objective_comparisons:Entries','Duplicate covariance entries.');
            C(indices)=M.CovariancePriorSDCoordinates;
            values=screening.covariance_objectives(C);
        end
        T=table(repmat(id,6,1),repmat(status.MaterialCaseID(i),6,1), ...
            repmat(status.Protocol(i),6,1),registry.ObjectiveID,values.', ...
            repmat(status.Certified(i),6,1),'VariableNames', ...
            {'ConfirmationCellIndex','MaterialCaseID','Protocol','ObjectiveID','PosteriorValue','Certified'});
        T.Available=repmat(available,6,1);
        cells=[cells;T]; %#ok<AGROW>
    end
    comparisons=grid.comparisons;paired=table();common=table();
    materials=unique(comparisons.MaterialCaseID,'stable');
    for m=reshape(materials,1,[])
        take=comparisons.MaterialCaseID==m;
        ids=unique([comparisons.DefaultCellIndex(take);comparisons.SelectedCellIndex(take)]);
        [found,idx]=ismember(ids,status.ConfirmationCellIndex);
        allCertified=all(found)&&all(status.Certified(idx));
        common=[common;table(m,allCertified,numel(ids),'VariableNames', ...
            {'MaterialCaseID','AllArmsCertified','RequiredUniqueCellCount'})]; %#ok<AGROW>
    end
    for i=1:height(comparisons)
        p=comparisons(i,:);a=cells(cells.ConfirmationCellIndex==p.DefaultCellIndex,:);
        b=cells(cells.ConfirmationCellIndex==p.SelectedCellIndex,:);
        assert(height(a)==6&&height(b)==6&&isequal(a.ObjectiveID,b.ObjectiveID), ...
            'confirmation:posterior_objective_comparisons:Join','Comparison cells or objective order disagree.');
        certified=all(a.Certified)&all(b.Certified);
        eligible=all(a.Available)&all(b.Available);
        allArm=common.AllArmsCertified(common.MaterialCaseID==p.MaterialCaseID);
        f=fim(fim.PairIndex==p.PairIndex,:);assert(height(f)==1, ...
            'confirmation:posterior_objective_comparisons:FIMJoin','Missing same-tissue FIM record.');
        for o=1:6
            d=NaN;s=NaN;delta=NaN;percent=NaN;improved=false;near=false;
            if eligible
                d=a.PosteriorValue(o);s=b.PosteriorValue(o);delta=s-d;
                if d>0,percent=100*(d-s)/d;end
                t=tolerance*max(1,max(abs([d s])));improved=s<d-t;near=abs(s-d)<=t;
            end
            fd=f.(['FIMDefault_' char(registry.ObjectiveID(o))]);
            fs=f.(['FIMSelected_' char(registry.ObjectiveID(o))]);
            row=table(p.PairIndex,p.ComparisonRole,p.MaterialCaseID,p.Protocol,registry.ObjectiveID(o), ...
                d,s,delta,percent,certified,allArm,improved,near,fd,fs,fs-fd,logical(f.FIMProxyValid), ...
                'VariableNames',{'PairIndex','ComparisonRole','MaterialCaseID','Protocol','ObjectiveID', ...
                'DefaultPosterior','SelectedPosterior','SelectedMinusDefault','PercentReduction', ...
                'PairCertified','AllArmsCertified','Improved','NearEqual', ...
                'DefaultFIM','SelectedFIM','FIMSelectedMinusDefault','FIMValid'});
            row.PairAvailable=eligible;row.ContainsFallback=eligible&&~certified;
            paired=[paired;row]; %#ok<AGROW>
        end
    end
    aggregate=table();
    for role=reshape(unique(paired.ComparisonRole,'stable'),1,[])
        for o=reshape(registry.ObjectiveID,1,[])
            T=paired(paired.ComparisonRole==role&paired.ObjectiveID==o,:);
            for cohort=["pairwise_certified" "common_all_arms_certified" "pairwise_all_available"]
                keep=T.PairCertified;if cohort=="common_all_arms_certified",keep=keep&T.AllArmsCertified;end
                if cohort=="pairwise_all_available",keep=T.PairAvailable;end
                same=keep&T.FIMValid;
                row=table(role,o,cohort,height(T),nnz(keep),mean(T.DefaultPosterior(keep)), ...
                    mean(T.SelectedPosterior(keep)),mean(T.SelectedMinusDefault(keep)), ...
                    mean(T.PercentReduction(keep)),mean(T.Improved(keep)),nnz(same), ...
                    mean(T.FIMSelectedMinusDefault(same)),mean(T.SelectedMinusDefault(same)), ...
                    strjoin(string(T.MaterialCaseID(keep)),';'),'VariableNames', ...
                    {'ComparisonRole','ObjectiveID','Cohort','PlannedCount','IncludedCount','DefaultMean', ...
                    'SelectedMean','MeanPairedChange','MeanPairedPercentReduction','FractionImproved', ...
                    'CommonFIMPosteriorCount','SameTissueMeanFIMChange','SameTissueMeanPosteriorChange','IncludedMaterialCaseIDs'});
                aggregate=[aggregate;row]; %#ok<AGROW>
            end
        end
    end
    evidence=struct('cellMetrics',cells,'pairedMetrics',paired,'aggregate',aggregate,'commonAllArmCohort',common);
end
