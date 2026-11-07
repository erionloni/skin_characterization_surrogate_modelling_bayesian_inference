function [artifact,status]=load_conditional_available_posterior(cfg,cellRecord)
%LOAD_CONDITIONAL_AVAILABLE_POSTERIOR The provider of a finished conditional cell: certified, or its healthy fallback.
%   [ARTIFACT,STATUS] = inversion.load_conditional_available_posterior(CFG,CELL)
%   loads the certified posterior of the conditional cell
%   (inversion.load_conditional_certified_posterior) when there is one.
%   Otherwise, for a cell that has run (its outcome record exists), the
%   healthy completed fallback, by the rule of the thesis's cells: the
%   highest configured level
%   first, replicate 1 before replicate 2, the first complete request whose
%   single-analysis health passes (inversion.single_analysis_health of its
%   retained states in the free coordinates, within the free bounds). Its
%   ARTIFACT carries certification (certified false, mechanism
%   NONCERTIFIED_HEALTHY_COMPLETED_REQUEST, the provider), an empty
%   certificationPath and providerEvidence (sampler, replicate, level); a
%   cell without such a request has no provider. STATUS.state is
%   'certified_loaded', 'non_certified_fallback' or the certified loader's
%   state; for a cell that has run and is not certified, STATUS.reason is
%   the reason of its outcome record (why it did not certify), and says
%   when no request is healthy. Never pools draws, changes a certification
%   or uses an interrupted request.
%   Side effects: none.

    [artifact,status]=inversion.load_conditional_certified_posterior(cfg,cellRecord);
    if status.loaded,return;end
    outcomePath=inversion.conditional_campaign_contract('cell_outcome_path',cfg,cellRecord);
    if ~isfile(outcomePath),return;end
    outcome=jsondecode(fileread(outcomePath));
    for steps=reshape(sort(double(cfg.mcmc.levels),'descend'),1,[])
        for replicate=[1 2]
            [one,loaded]=inversion.load_conditional_posterior_artifact(cfg,cellRecord, ...
                'AIES',replicate,steps);
            if ~loaded.valid,continue;end
            health=inversion.single_analysis_health(one.sampleArray,double(one.freeBounds),cfg,'AIES');
            if ~health.pass,continue;end
            provider=struct('sampler','AIES','replicateID',replicate,'stepCount',steps, ...
                'samplesPooled',false);
            artifact=one;
            artifact.truth=one.truthMetadata.truth;
            artifact.observation=one.observationMetadata.observation;
            artifact.certification=struct('certified',false, ...
                'certificationMechanism','NONCERTIFIED_HEALTHY_COMPLETED_REQUEST', ...
                'provider',provider,'state','non_certified_fallback');
            artifact.certificationPath='';
            artifact.providerEvidence=struct('sampler','AIES','replicateID',replicate, ...
                'stepCount',steps,'certified',false,'kind','healthy_completed_fallback', ...
                'terminationReason',char(string(outcome.reason)));
            status=loaded;status.state='non_certified_fallback';status.loaded=true;
            status.valid=true;status.certified=false;
            status.reason=char(string(outcome.reason));
            return
        end
    end
    status.reason=sprintf('%s; no healthy completed request',char(string(outcome.reason)));
end
