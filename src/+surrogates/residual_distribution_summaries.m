function [pitBins,qqPoints]=residual_distribution_summaries(qq,pit,edges)
%RESIDUAL_DISTRIBUTION_SUMMARIES The PIT histogram and the Q-Q points of the audit's standardized residuals.
%   [PITBINS, QQPOINTS] = surrogates.residual_distribution_summaries(QQ, PIT,
%   EDGES) takes the surrogate audit's per-row tables of the cross-fitted
%   standardized residuals (surrogates.surrogate_quality_calibration: qqData
%   and pitData, one row per case, repeat, output, kernel and candidate
%   variance model) and the audit's PIT bin edges EDGES, and returns
%     PITBINS   one row per kernel, candidate, output and PIT bin, every bin
%               of EDGES (an empty one with count 0): Kernel, Candidate,
%               OutputIndex, PITBin, BinLower, BinUpper (the first bin
%               includes its lower edge, every bin its upper edge),
%               PITBinCount (the rows in the bin), RowCount (the rows of the
%               output) and PITBinFraction (their ratio);
%     QQPOINTS  one row per kernel, candidate, output and rank of the
%               sorted residuals: Kernel, Candidate, OutputIndex, Rank,
%               Probability ((Rank - 0.5)/n for the n rows of the output),
%               TheoreticalNormalQuantile (its standard normal quantile) and
%               ObservedStandardizedResidual (the residual of that rank).
%   The counts of the bins that hold rows are checked against the per-row
%   tables' counts, the ranks against 1 to n; the quantiles are the per-row
%   tables' values.
%   Side effects: none.

    edges=reshape(double(edges),[],1);
    binCount=numel(edges)-1;
    groups=unique(pit(:,{'Kernel','Candidate','OutputIndex'}),'stable');
    parts=cell(height(groups),1);
    for g=1:height(groups)
        one=pit(pit.Kernel==groups.Kernel(g)&pit.Candidate==groups.Candidate(g)& ...
            pit.OutputIndex==groups.OutputIndex(g),:);
        bins=(1:binCount).';
        counts=accumarray(double(one.PITBin),1,[binCount 1]);
        rows=height(one);
        fraction=counts/rows;
        present=unique(one(:,{'PITBin','PITBinCount'}),'rows');
        assert(height(present)==nnz(counts)&& ...
            isequal(double(present.PITBinCount),counts(present.PITBin)), ...
            'surrogates:residual_distribution_summaries:Bins', ...
            'The PIT bins of %s, %s, output %d disagree with the per-row counts.', ...
            groups.Kernel(g),groups.Candidate(g),groups.OutputIndex(g));
        parts{g}=table(repmat(groups.Kernel(g),binCount,1),repmat(groups.Candidate(g),binCount,1), ...
            repmat(groups.OutputIndex(g),binCount,1),bins,edges(1:end-1),edges(2:end), ...
            counts,repmat(rows,binCount,1),fraction, ...
            'VariableNames',{'Kernel','Candidate','OutputIndex','PITBin','BinLower', ...
            'BinUpper','PITBinCount','RowCount','PITBinFraction'});
    end
    pitBins=vertcat(parts{:});

    groups=unique(qq(:,{'Kernel','Candidate','OutputIndex'}),'stable');
    parts=cell(height(groups),1);
    for g=1:height(groups)
        one=qq(qq.Kernel==groups.Kernel(g)&qq.Candidate==groups.Candidate(g)& ...
            qq.OutputIndex==groups.OutputIndex(g),:);
        n=height(one);
        one=sortrows(one,'Rank');
        rank=double(one.Rank);
        probability=(rank-.5)/n;
        assert(isequal(rank,(1:n).'), ...
            'surrogates:residual_distribution_summaries:Ranks', ...
            'The Q-Q rows of %s, %s, output %d are not the ranks 1 to n.', ...
            groups.Kernel(g),groups.Candidate(g),groups.OutputIndex(g));
        parts{g}=table(one.Kernel,one.Candidate,one.OutputIndex,rank,probability, ...
            one.TheoreticalNormalQuantile,one.ObservedStandardizedResidual, ...
            'VariableNames',{'Kernel','Candidate','OutputIndex','Rank','Probability', ...
            'TheoreticalNormalQuantile','ObservedStandardizedResidual'});
    end
    qqPoints=vertcat(parts{:});
end
