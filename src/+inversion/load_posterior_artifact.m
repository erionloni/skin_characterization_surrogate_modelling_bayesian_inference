function [artifact,status] = load_posterior_artifact( ...
        cfg,cellRecord,sampler,replicateID,stepCount)
%LOAD_POSTERIOR_ARTIFACT Load one completed sampler request of an inversion cell.
%   [ARTIFACT,STATUS] = inversion.load_posterior_artifact(CFG,CELL,SAMPLER,
%   REPLICATEID,STEPCOUNT) reads the files that inversion.save_posterior_artifact
%   wrote for this request below the cell folder. ARTIFACT is the posterior
%   record (request, draws in model coordinates, truth, observation, summary,
%   health) with the retained sampler-state array (sampleArray), the
%   checkpoint's result state, the truth and observation records, the
%   metadata and the paths. A request is complete when all its files exist;
%   a complete request is reusable as a whole (never appended to a later
%   level).
%   STATUS.state is 'complete_reusable', 'missing' (a file is missing; the
%   reason names it) or 'invalid' (a file did not load); STATUS.valid is
%   true only for a complete request. The function does not throw.
%   Side effects: none.

    artifact=struct([]);
    status=base_status();
    try
        paths=inversion.posterior_artifact_paths( ...
            cfg,cellRecord,sampler,replicateID,stepCount);
        status.paths=paths;
        required={paths.checkpointPath,paths.posteriorPath, ...
            paths.truthPath,paths.observationPath,paths.metadataPath};
        missing=required(~cellfun(@isfile,required));
        if ~isempty(missing)
            status.state='missing';
            status.reason=sprintf('missing required artifact: %s',missing{1});
            return;
        end
        checkpointSaved=load(paths.checkpointPath,'checkpointArtifact');
        posteriorSaved=load(paths.posteriorPath,'posteriorArtifact');
        truthSaved=load(paths.truthPath,'truthArtifact');
        observationSaved=load(paths.observationPath,'observationArtifact');
        assert(isfield(checkpointSaved,'checkpointArtifact')&& ...
            isfield(posteriorSaved,'posteriorArtifact')&& ...
            isfield(truthSaved,'truthArtifact')&& ...
            isfield(observationSaved,'observationArtifact'), ...
            'inversion:load_posterior_artifact:Variables', ...
            'One or more MAT artifacts below %s lacks its variable.', ...
            paths.replicateRoot);
        checkpoint=checkpointSaved.checkpointArtifact;
        artifact=posteriorSaved.posteriorArtifact;
        artifact.sampleArray=checkpoint.retainedSampleArray;
        artifact.checkpointState=checkpoint.resultState;
        artifact.truthMetadata=truthSaved.truthArtifact;
        artifact.observationMetadata=observationSaved.observationArtifact;
        artifact.metadata=jsondecode(fileread(paths.metadataPath));
        artifact.paths=paths;
        status.state='complete_reusable';
        status.loaded=true;
        status.valid=true;
        status.resumable=true;
        status.resumeSemantics='reuse_complete_request_only';
        status.midChainResumeAvailable=false;
        status.reason='';
    catch exception
        artifact=struct([]);
        status.state='invalid';
        status.loaded=false;
        status.valid=false;
        status.resumable=false;
        status.reason=exception.message;
        status.errorIdentifier=exception.identifier;
    end
end

function status=base_status()
    status=struct('state','unresolved','loaded',false,'valid',false, ...
        'resumable',false,'resumeSemantics','none', ...
        'midChainResumeAvailable',false,'reason','', ...
        'errorIdentifier','','paths',struct([]));
end
