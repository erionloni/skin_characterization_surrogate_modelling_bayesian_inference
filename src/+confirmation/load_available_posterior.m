function [artifact,status]=load_available_posterior(cfg,cellRecord)
%LOAD_AVAILABLE_POSTERIOR The provider of a finished cell: certified, or its healthy fallback.
%   [ARTIFACT, STATUS] = confirmation.load_available_posterior(CFG, CELLRECORD)
%   loads the certified posterior of the cell when there is one. Otherwise,
%   for a cell whose terminal decision is saved (it has run), the healthy
%   completed fallback: the highest configured level first, replicate 1
%   before replicate 2, the first request whose single-analysis health
%   passes. Its providerEvidence says which request it is and what the
%   replicate pair at that level showed. Never changes a certification,
%   pools draws or uses an interrupted request.
%   Side effects: none.
    [artifact,status]=inversion.load_certified_posterior(cfg,cellRecord);
    if status.loaded,return;end
    outcome=confirmation.confirmation_campaign_support('cell_outcome',cfg,cellRecord);
    assert(~outcome.missing,'confirmation:load_available_posterior:NotTerminal', ...
        ['Cell %s has not finished; the summary reads finished cells ' ...
         'only (run the step ''run_cells'').'],cellRecord.cellID);
    for steps=reshape(sort(double(cfg.mcmc.levels),'descend'),1,[])
        for replicate=[1 2]
            [one,loaded]=inversion.load_posterior_artifact(cfg,cellRecord,'AIES',replicate,steps);
            if ~loaded.valid,continue;end
            health=inversion.single_analysis_health(one.sampleArray,cfg.paramBounds,cfg,'AIES');
            if ~health.pass,continue;end
            artifact=one;
            verification='SAME_LEVEL_CONFIRMATION_UNAVAILABLE';
            verificationSource='not_available';
            pair=struct([]);
            if steps==outcome.decision.stepCount
                pair=outcome.decision.evidence.aiesPairReliability;
                verificationSource='saved_terminal_decision';
            else
                % The terminal decision describes only its own level. A
                % lower-level pair must be compared at that actual level,
                % never inferred from a failed/interrupted higher pair.
                [a,sa]=inversion.load_posterior_artifact(cfg,cellRecord,'AIES',1,steps);
                [b,sb]=inversion.load_posterior_artifact(cfg,cellRecord,'AIES',2,steps);
                if sa.valid&&sb.valid
                    pair=inversion.same_sampler_reliability({a.sampleArray,b.sampleArray}, ...
                        cfg.paramBounds,cfg,'AIES','Seeds',[a.request.seed b.request.seed], ...
                        'ReplicateIDs',[1 2],'HealthRecords',[a.health b.health]);
                    verificationSource='recomputed_same_level_existing_owner';
                end
            end
            if ~isempty(pair)&&isfield(pair,'structuralHealthPass')
                if ~pair.structuralHealthPass
                    verification='COMPLETE_PAIR_STRUCTURAL_HEALTH_FAILED';
                elseif pair.reliable
                    verification='PAIR_PASSED_NO_CERTIFICATION_PUBLISHED';
                else
                    verification='COMPLETE_PAIR_REPLICATE_AGREEMENT_FAILED';
                end
            end
            artifact.providerEvidence=struct('sampler','AIES','replicateID',replicate, ...
                'stepCount',steps,'certified',false,'kind','healthy_completed_fallback', ...
                'sameLevelVerificationStatus',verification,'sameLevelVerificationSource',verificationSource, ...
                'terminationReason',outcome.decision.reason);
            status=loaded;status.certified=false;status.state='non_certified_fallback';
            status.reason='Healthy completed request; same-level certification not passed. No pooling.';
            return
        end
    end
end
