function A = replicate_agreement(runs, bounds)
%REPLICATE_AGREEMENT How far the medians and 2.5%/97.5% quantiles of several posteriors differ.
%   A = inversion.replicate_agreement(RUNS, BOUNDS) summarizes each
%   posterior of RUNS (cell array of sample arrays, iteration-by-parameter-
%   by-walker, each flattened for its own summary; never pooled) by its
%   medians and 2.5%/97.5% quantiles, and returns them with, per parameter,
%   the largest difference between the posteriors in each of the three,
%   divided by the parameter's prior width (BOUNDS: parameter-by-2).
%   Side effects: none.
    r = numel(runs); m = size(runs{1}, 2);
    width = (bounds(:,2) - bounds(:,1)).';
    med = nan(r,m); qlo = med; qhi = med;
    for i = 1:r
        flat = reshape(permute(runs{i}, [1 3 2]), [], m);
        med(i,:) = median(flat,1);
        qlo(i,:) = quantile(flat,.025,1);
        qhi(i,:) = quantile(flat,.975,1);
    end
    A.medians = med; A.q025 = qlo; A.q975 = qhi;
    A.maxMedianRangeDifference = zeros(1,m);
    A.maxQ025RangeDifference = zeros(1,m);
    A.maxQ975RangeDifference = zeros(1,m);
    for j = 1:m
        A.maxMedianRangeDifference(j) = (max(med(:,j))-min(med(:,j))) / width(j);
        A.maxQ025RangeDifference(j) = (max(qlo(:,j))-min(qlo(:,j))) / width(j);
        A.maxQ975RangeDifference(j) = (max(qhi(:,j))-min(qhi(:,j))) / width(j);
    end
end
