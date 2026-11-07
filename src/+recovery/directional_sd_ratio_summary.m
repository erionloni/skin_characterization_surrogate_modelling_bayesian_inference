function S=directional_sd_ratio_summary(directions)
%DIRECTIONAL_SD_RATIO_SUMMARY The median and quartiles of the directional posterior SD ratios.
%   S = recovery.directional_sd_ratio_summary(DIRECTIONS) takes the
%   eigendirections of the cells (posterior_eigendirections.csv of the
%   eigen-analysis, recovery.summarize_posterior_eigendecomposition: one row
%   per cell and direction) and returns one row per scenario, design and
%   direction (DirectionRank, DirectionLabel): the number of cases with a
%   valid eigensystem and a finite ratio (CaseCount) and the median, the 25 %
%   and the 75 % quantile of DirectionalPosteriorSDRatio over them (MATLAB
%   quantile), each followed by its value over the certified cells alone
%   (_certified_only: CertificationMechanism
%   CERTIFIED_AIES_REPLICATE_AGREEMENT; utils.add_certified_only).
%   Side effects: none.

    keys={'Scenario','Design','DirectionRank','DirectionLabel'};
    valid=logical(directions.EigensystemValid)&isfinite(double(directions.DirectionalPosteriorSDRatio));
    T=directions(valid,:);
    groups=unique(T(:,keys),'stable');
    certified=T.CertificationMechanism=="CERTIFIED_AIES_REPLICATE_AGREEMENT";
    S=utils.add_certified_only(summarize(T,groups),summarize(T(certified,:),groups),keys);
end

function S=summarize(T,groups)
%SUMMARIZE CaseCount, median and quartiles of the directional SD ratio per group (NaN for none).
    n=height(groups);
    count=zeros(n,1);q25=nan(n,1);med=nan(n,1);q75=nan(n,1);
    for g=1:n
        hit=T.Scenario==groups.Scenario(g)&T.Design==groups.Design(g)& ...
            T.DirectionRank==groups.DirectionRank(g);
        x=double(T.DirectionalPosteriorSDRatio(hit));
        count(g)=numel(x);
        if isempty(x),continue;end
        q=quantile(x,[0.25 0.5 0.75]);
        q25(g)=q(1);med(g)=q(2);q75(g)=q(3);
    end
    S=[groups,table(count,med,q25,q75,'VariableNames',{'CaseCount', ...
        'MedianDirectionalPosteriorSDRatio','Q25DirectionalPosteriorSDRatio', ...
        'Q75DirectionalPosteriorSDRatio'})];
end
