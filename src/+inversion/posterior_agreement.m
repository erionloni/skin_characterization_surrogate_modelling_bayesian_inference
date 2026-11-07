function agreement = posterior_agreement(left,right,bounds,cfg)
%POSTERIOR_AGREEMENT Sampler-agnostic median/tail agreement test.
%   LEFT and RIGHT may have different numbers and types of sampler states.
%   Each is flattened only for its own posterior summary; samples are never
%   pooled across analyses or samplers.
%   AGREEMENT = inversion.posterior_agreement(LEFT, RIGHT, BOUNDS, CFG)
%   compares the medians and the 2.5%/97.5% quantiles of the two posteriors
%   per parameter, relative to the prior widths (BOUNDS), with the
%   configured tolerances, and returns whether the medians and tails agree
%   and the reasons.
%   Side effects: none.

    validate_run(left,bounds,'left');
    validate_run(right,bounds,'right');
    thresholds=inversion.mcmc_diagnostic_thresholds(cfg);
    raw=inversion.replicate_agreement({left,right},bounds);
    medianPass=all(isfinite(raw.maxMedianRangeDifference))&& ...
        all(raw.maxMedianRangeDifference<= ...
            thresholds.maxMedianRangeDifference);
    lowerPass=all(isfinite(raw.maxQ025RangeDifference))&& ...
        all(raw.maxQ025RangeDifference<= ...
            thresholds.maxQuantileRangeDifference);
    upperPass=all(isfinite(raw.maxQ975RangeDifference))&& ...
        all(raw.maxQ975RangeDifference<= ...
            thresholds.maxQuantileRangeDifference);
    reasons={};
    if ~medianPass
        reasons{end+1}='posterior medians disagree';
    end
    if ~(lowerPass&&upperPass)
        reasons{end+1}='posterior tail quantiles disagree';
    end
    agreement=raw;
    agreement.schemaVersion='direct_mcmc_posterior_agreement_v1';
    agreement.maxMedianThreshold=thresholds.maxMedianRangeDifference;
    agreement.maxTailQuantileThreshold= ...
        thresholds.maxQuantileRangeDifference;
    agreement.medianAgreement=medianPass;
    agreement.tailAgreement=lowerPass&&upperPass;
    agreement.agrees=medianPass&&lowerPass&&upperPass;
    agreement.samplesPooled=false;
    agreement.reasons=unique(reasons,'stable');
end

function validate_run(run,bounds,label)
    assert(isnumeric(run)&&size(run,1)>=1&&size(run,2)==size(bounds,1)&& ...
        size(run,3)>=1&&all(isfinite(run),'all'), ...
        'inversion:posterior_agreement:Samples', ...
        'The %s posterior must be a finite iteration x parameter x state array.',label);
    assert(isnumeric(bounds)&&size(bounds,2)==2&&all(isfinite(bounds),'all')&& ...
        all(bounds(:,2)>bounds(:,1)), ...
        'inversion:posterior_agreement:Bounds','Invalid parameter bounds.');
end
