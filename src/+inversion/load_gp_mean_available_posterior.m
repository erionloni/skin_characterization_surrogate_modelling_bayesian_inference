function [artifact,status] = load_gp_mean_available_posterior(cfg,cellRecord)
%LOAD_GP_MEAN_AVAILABLE_POSTERIOR The provider of a finished GP-mean cell: certified, or its healthy fallback.
%   [ARTIFACT, STATUS] = inversion.load_gp_mean_available_posterior(CFG, CELL)
%   loads, from the GP-mean campaign of the run (inversion.gp_mean_campaign_config),
%   the certified posterior of the cell when there is one
%   (inversion.load_certified_posterior). Otherwise, for a cell whose
%   terminal decision is saved (it has run), the healthy completed fallback
%   by the rule of the thesis's cells (as
%   inversion.load_conditional_available_posterior and
%   confirmation.load_available_posterior): the highest configured level
%   first, replicate 1 before replicate 2, the first complete request whose
%   single-analysis health passes (inversion.single_analysis_health of its
%   retained states within the prior bounds). Its ARTIFACT carries
%   certification (certified false, mechanism
%   NONCERTIFIED_HEALTHY_COMPLETED_REQUEST, the provider) and
%   providerEvidence (sampler, replicate, level, and the reason the cell did
%   not certify); a cell without such a request has no provider
%   (unavailable). STATUS.state is the certified loader's state,
%   'non_certified_fallback' or 'not_run'; STATUS.reason says why a cell that
%   has run is not certified, and when no request is healthy. Never pools
%   draws, changes a certification or uses an interrupted request.
%   Side effects: none.

    campaignCfg=inversion.gp_mean_campaign_config(cfg);
    [artifact,status]=inversion.load_certified_posterior(campaignCfg,cellRecord);
    if status.loaded,return;end
    outcome=inversion.grid_campaign_support('cell_outcome',campaignCfg,cellRecord);
    if outcome.missing
        status.state='not_run';
        status.reason='not run in this campaign';
        return
    end
    reason=char(string(outcome.decision.reason));
    for steps=reshape(sort(double(cfg.mcmc.levels),'descend'),1,[])
        for replicate=[1 2]
            [one,loaded]=inversion.load_posterior_artifact(campaignCfg,cellRecord,'AIES', ...
                replicate,steps);
            if ~loaded.valid,continue;end
            health=inversion.single_analysis_health(one.sampleArray,double(cfg.paramBounds),cfg,'AIES');
            if ~health.pass,continue;end
            provider=struct('sampler','AIES','replicateID',replicate,'stepCount',steps, ...
                'samplesPooled',false);
            artifact=one;
            % As inversion.load_certified_posterior gives them.
            artifact.truth=one.truthMetadata.truth;
            artifact.observation=one.observationMetadata.observation;
            artifact.certification=struct('certified',false, ...
                'certificationMechanism','NONCERTIFIED_HEALTHY_COMPLETED_REQUEST', ...
                'provider',provider,'state','non_certified_fallback');
            artifact.certificationPath='';
            artifact.providerEvidence=struct('sampler','AIES','replicateID',replicate, ...
                'stepCount',steps,'certified',false,'kind','healthy_completed_fallback', ...
                'terminationReason',reason);
            status=loaded;status.state='non_certified_fallback';status.loaded=true;
            status.valid=true;status.certified=false;status.reason=reason;
            return
        end
    end
    status.reason=sprintf('%s; no healthy completed request',reason);
end
