function result = posterior_marginal_density(draws,varargin)
%POSTERIOR_MARGINAL_DENSITY Deterministic one-dimensional posterior density.
%   RESULT = POSTERIOR_MARGINAL_DENSITY(DRAWS,'Bounds',[LO HI]) constructs a
%   fixed-grid histogram density and applies a deterministic Gaussian
%   smoothing kernel.  The marginal mode is the grid location at the highest
%   value of this same density.  It is a one-dimensional marginal mode, not a
%   joint-posterior MAP estimate.
%   Option (name-value): 'BinCount', the number of grid bins (default 128,
%   at least 16).
%   Side effects: none.

    parser=inputParser;
    addParameter(parser,'Bounds',[],@(x)isnumeric(x)&& ...
        (isempty(x)||(numel(x)==2&&all(isfinite(x)))));
    addParameter(parser,'BinCount',128,@(x)isnumeric(x)&&isscalar(x)&& ...
        isfinite(x)&&x>=16&&x==fix(x));
    parse(parser,varargin{:});
    values=double(draws(:));values=values(isfinite(values));
    assert(~isempty(values), ...
        'plotting:posterior_marginal_density:NoFiniteDraws', ...
        'A posterior marginal requires at least one finite draw.');

    bounds=reshape(double(parser.Results.Bounds),1,[]);
    if isempty(bounds)
        bounds=[min(values) max(values)];
        if bounds(1)==bounds(2)
            delta=max(1,abs(bounds(1)))*1e-6;
            bounds=bounds+[-delta delta];
        else
            padding=0.02*diff(bounds);
            bounds=bounds+[-padding padding];
        end
    end
    assert(bounds(2)>bounds(1)&& ...
        all(values>=bounds(1)-64*eps(max(1,abs(bounds(1)))))&& ...
        all(values<=bounds(2)+64*eps(max(1,abs(bounds(2))))), ...
        'plotting:posterior_marginal_density:Bounds', ...
        'Density bounds must contain every finite posterior draw.');

    binCount=double(parser.Results.BinCount);
    edges=linspace(bounds(1),bounds(2),binCount+1);
    centers=(edges(1:end-1)+edges(2:end))/2;
    binWidth=edges(2)-edges(1);
    counts=histcounts(values,edges);
    baseDensity=double(counts)/(numel(values)*binWidth);

    sampleSD=std(values,0);
    sampleIQR=diff(quantile(values,[0.25 0.75]));
    robustScale=min(sampleSD,sampleIQR/1.349);
    if ~(isfinite(robustScale)&&robustScale>0)
        robustScale=sampleSD;
    end
    if ~(isfinite(robustScale)&&robustScale>0)
        robustScale=binWidth;
    end
    bandwidth=0.9*robustScale*numel(values)^(-1/5);
    bandwidth=max(bandwidth,0.35*binWidth);
    sigmaBins=bandwidth/binWidth;
    radius=max(1,ceil(4*sigmaBins));
    offsets=-radius:radius;
    kernel=exp(-0.5*(offsets/sigmaBins).^2);
    kernel=kernel/sum(kernel);
    density=conv(baseDensity,kernel,'same');
    area=trapz(centers,density);
    if isfinite(area)&&area>0,density=density/area;end
    [~,modeIndex]=max(density);

    centralQuantiles=quantile(values,[0.025 0.25 0.75 0.975]);
    result=struct( ...
        'grid',reshape(centers,[],1), ...
        'density',reshape(density,[],1), ...
        'posteriorMean',mean(values), ...
        'posteriorMedian',median(values), ...
        'marginalMode',centers(modeIndex), ...
        'q025',centralQuantiles(1),'q25',centralQuantiles(2), ...
        'q75',centralQuantiles(3),'q975',centralQuantiles(4), ...
        'centralIntervalConvention','equal_tailed_matlab_quantile', ...
        'method','fixed_grid_gaussian_smoothed_histogram_v1', ...
        'binCount',binCount,'bandwidth',bandwidth, ...
        'bandwidthRule','0.9_min_sd_iqr_over_1.349_n_minus_one_fifth', ...
        'kernelTruncationStandardDeviations',4, ...
        'sampleCount',numel(values),'bounds',bounds, ...
        'modeTieBreak','first_grid_point_in_ascending_coordinate_order');
end
