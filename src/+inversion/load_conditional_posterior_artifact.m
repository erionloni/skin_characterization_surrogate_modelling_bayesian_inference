function [artifact,status] = load_conditional_posterior_artifact( ...
        cfg,cellRecord,sampler,replicateID,stepCount)
%LOAD_CONDITIONAL_POSTERIOR_ARTIFACT Load one completed request of a conditional cell.
%   [ARTIFACT,STATUS] = inversion.load_conditional_posterior_artifact(CFG,CELL,
%   SAMPLER,REPLICATEID,STEPCOUNT) reads the files that
%   inversion.save_conditional_posterior_artifact wrote for this request.
%   ARTIFACT is the posterior record (request, condition, adapter, the draws
%   of the free parameters drawsFree, the four model coordinates with the
%   fixed ones at the truth drawsCanonicalCoordinates, roles, truth,
%   observation, summary, health) with the reduced sampler-state array
%   (sampleArray), the checkpoint's result state, the truth and observation
%   records, the metadata and the paths.
%   STATUS.state is 'complete_reusable', 'missing' (a file is missing) or
%   'invalid' (a file did not load); STATUS.valid is true only for a
%   complete request. The function does not throw.
%   Side effects: none.

    artifact=struct([]);status=base_status();
    try
        paths=inversion.conditional_posterior_artifact_paths( ...
            cfg,cellRecord,sampler,replicateID,stepCount);
        status.paths=paths;
        required={paths.checkpointPath,paths.posteriorPath,paths.truthPath, ...
            paths.observationPath,paths.metadataPath};
        missing=required(~cellfun(@isfile,required));
        if ~isempty(missing)
            status.state='missing';
            status.reason=sprintf('missing required artifact: %s',missing{1});
            return;
        end
        C=load(paths.checkpointPath,'checkpointArtifact');
        P=load(paths.posteriorPath,'posteriorArtifact');
        T=load(paths.truthPath,'truthArtifact');
        O=load(paths.observationPath,'observationArtifact');
        assert(isfield(C,'checkpointArtifact')&&isfield(P,'posteriorArtifact')&& ...
            isfield(T,'truthArtifact')&&isfield(O,'observationArtifact'), ...
            'inversion:load_conditional_posterior_artifact:Variables', ...
            'A conditional MAT artifact below %s lacks its variable.', ...
            paths.replicateRoot);
        checkpoint=C.checkpointArtifact;
        artifact=P.posteriorArtifact;
        artifact.sampleArray=double(checkpoint.retainedSampleArrayFree);
        artifact.checkpointState=checkpoint.resultState;
        artifact.truthMetadata=T.truthArtifact;
        artifact.observationMetadata=O.observationArtifact;
        artifact.metadata=jsondecode(fileread(paths.metadataPath));
        artifact.paths=paths;
        status.state='complete_reusable';status.loaded=true;status.valid=true;
        status.resumable=true;status.reason='';
        status.resumeSemantics='reuse_complete_request_only';
    catch exception
        artifact=struct([]);status.state='invalid';status.loaded=false;
        status.valid=false;status.resumable=false;status.reason=exception.message;
        status.errorIdentifier=exception.identifier;
    end
end

function status=base_status()
    status=struct('state','unresolved','loaded',false,'valid',false, ...
        'certified',false,'resumable',false,'resumeSemantics','none', ...
        'reason','','errorIdentifier','','paths',struct([]));
end
