function rankings=aggregate_objectives(candidates,local,policy)
%AGGREGATE_OBJECTIVES Rank the candidate protocols by each of the six objectives.
%   RANKINGS = screening.aggregate_objectives(CANDIDATES, LOCAL, POLICY)
%   averages, per protocol, covariance view and objective
%   (screening.objective_registry), the objective over the material points
%   at which every protocol is valid (the complete cohort; LOCAL: the full
%   covariances of screening.evaluate_local_information), ranks the
%   protocols (smaller is better) and records the paired per-material
%   comparisons with the leader and the score gaps. Tables sorted
%   separately are joined by CandidateID and view, never by position.
%   Side effects: none.
    registry=screening.objective_registry();n=height(candidates);
    assert(isequal(string(local.CandidateIDs(:)),string(candidates.CandidateID(:))), ...
        'screening:aggregate_objectives:CandidateAlignment','Candidate order mismatch.');
    assert(isfield(local,'MarginalVariances'), ...
        'screening:aggregate_objectives:MissingMarginals', ...
        'Historical weak-block summaries cannot supply stiffness/thickness.');
    d=find(candidates.IsDefault);assert(isscalar(d),'screening:aggregate_objectives:Default','One default required.');
    eligible=all(all(local.Valid,1),3);eligible=eligible(:);
    assert(eligible(d),'screening:aggregate_objectives:InvalidDefault','Default must be valid for every tissue/view.');
    tensors=cat(4,local.TargetProxyLambdaMax,local.MarginalVariances(:,:,:,3), ...
        local.MarginalVariances(:,:,:,2),local.MarginalVariances(:,:,:,1), ...
        local.MarginalVariances(:,:,:,4),sum(local.MarginalVariances(:,:,:,2:3),4));
    rankings=table();tol=policy.comparisonTolerance;
    for v=1:2
        for o=1:6
            T=candidates;T.CovarianceCase=repmat(string(local.CovarianceCases{v}),n,1);
            T.ObjectiveID=repmat(registry.ObjectiveID(o),n,1);
            T.Eligible=eligible;T.RequiredMaterialCount=repmat(size(local.Valid,1),n,1);
            T.FailedMaterialCount=sum(any(~local.Valid,3),1).';
            names={'MeanScore','Median','Q90','DefaultScore','RelativeImprovement', ...
                'FractionImproved','FractionNearEqual','FractionWorse', ...
                'FractionBothWeakImproved','FractionBothWeakNearEqual', ...
                'FractionBothWeakWorse','FractionWeakMixed','Rank','ScoreGapToLeader'};
            for k=1:numel(names),T.(names{k})=nan(n,1);end
            base=tensors(:,d,v,o);baseMean=mean(base);
            for c=1:n
                if ~eligible(c),continue;end
                x=tensors(:,c,v,o);t=tol*max(1,max(abs([x base]),[],2));
                T.MeanScore(c)=mean(x);T.Median(c)=median(x);T.Q90(c)=quantile(x,.9);
                T.DefaultScore(c)=baseMean;T.RelativeImprovement(c)=(baseMean-mean(x))/baseMean;
                T.FractionImproved(c)=mean(x<base-t);T.FractionNearEqual(c)=mean(abs(x-base)<=t);
                T.FractionWorse(c)=mean(x>base+t);
                a=[local.TargetVar_m3_e(:,c,v),local.TargetVar_log10_k0(:,c,v)];
                b=[local.TargetVar_m3_e(:,d,v),local.TargetVar_log10_k0(:,d,v)];
                wt=tol*max(1,max(abs(cat(3,a,b)),[],3));
                improve=all(a<b-wt,2);near=all(abs(a-b)<=wt,2);worse=all(a>b+wt,2);
                T.FractionBothWeakImproved(c)=mean(improve);T.FractionBothWeakNearEqual(c)=mean(near);
                T.FractionBothWeakWorse(c)=mean(worse);T.FractionWeakMixed(c)=mean(~improve&~near&~worse);
            end
            T=sortrows(T,{'MeanScore','CandidateID'});
            good=find(T.Eligible);T.Rank(good)=(1:numel(good)).';
            if ~isempty(good),T.ScoreGapToLeader(good)=T.MeanScore(good)-T.MeanScore(good(1));end
            rankings=[rankings;T]; %#ok<AGROW>
        end
    end
end
