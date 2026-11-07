function receipt=run_objective_supplement(provider,candidates,materials,parentRoot,outputRoot)
%RUN_OBJECTIVE_SUPPLEMENT The six-objective supplement of a finished protocol screen.
%   RECEIPT = screening.run_objective_supplement(PROVIDER, CANDIDATES,
%   MATERIALS, PARENTROOT, OUTPUTROOT) evaluates, for the protocols
%   CANDIDATES and the material points MATERIALS of the screen PARENTROOT
%   (its saved design, in its order), the full 4x4 posterior covariance
%   proxy and the marginal variances in both covariance views
%   (screening.evaluate_local_information with 'RetainFullCovariance'), ranks
%   the protocols by the six objectives (screening.aggregate_objectives) and
%   writes to OUTPUTROOT: full_covariance_supplement.mat,
%   six_objective_rankings.csv, objective_registry.csv and receipt.json.
%   The screen must record the same inputs (screening.screen_inputs: the
%   model provider's content, the protocols, material points and policy).
%   Blocks of five protocols are checkpointed with the inputs (inputs.mat);
%   an interrupted supplement continues from its checkpoints only for the
%   same inputs. The parent screen is only read.
%   Side effects: writes the files above and the checkpoints below
%   OUTPUTROOT.
%   Computation: about 30 minutes.
    parent=jsondecode(fileread(fullfile(parentRoot,'status','screening_status.json')));
    assert(strcmp(parent.status,'complete'), ...
        'screening:run_objective_supplement:Parent', ...
        'The screen %s is not complete.',parentRoot);
    policy=provider.cfg.stage9bScreening;
    inputs=screening.screen_inputs(provider,candidates,materials,policy);
    original=load(fullfile(parentRoot,'local_information','local_information.mat'));
    original=original.localInformation;
    assert(isfield(original,'Inputs')&&isequaln(original.Inputs,inputs), ...
        'screening:run_objective_supplement:ScreenInputs', ...
        ['The screen %s was computed from other inputs (model provider, protocols, ' ...
         'material points in their order, or policy), or does not record them; the ' ...
         'supplement extends only a screen of its own inputs.'],parentRoot);
    assert(strictly_disjoint(parentRoot,outputRoot), ...
        'screening:run_objective_supplement:Output', ...
        'The supplement is written outside its screen (%s).',parentRoot);
    % The checkpoints of another supplement are not reused.
    if ~isfolder(outputRoot),mkdir(outputRoot);end
    cp=fullfile(outputRoot,'checkpoints');if ~isfolder(cp),mkdir(cp);end
    inputsPath=fullfile(outputRoot,'inputs.mat');
    if isfile(inputsPath)
        previous=load(inputsPath,'inputs');
        assert(isfield(previous,'inputs')&&isequaln(previous.inputs,inputs), ...
            'screening:run_objective_supplement:ResumeInputs', ...
            ['%s holds another supplement (model provider, protocols, material points ' ...
             'or policy); continue a supplement only with its own inputs, or write into ' ...
             'a new folder.'],outputRoot);
    else
        utils.atomic_save_struct(inputsPath,struct('inputs',inputs),'-v7.3','NoReplace',true);
    end
    localInformation=original;localInformation.SchemaVersion='stage9b_local_information_supplement_v3';
    localInformation.FullCovariance=nan(4,4,height(materials),height(candidates),2);
    localInformation.MarginalVariances=nan(height(materials),height(candidates),2,4);
    executed=0;reused=0;clock=tic;
    for first=1:5:height(candidates)
        take=first:min(first+4,height(candidates));path=fullfile(cp,sprintf('block_%04d.mat',first));
        if isfile(path)
            B=load(path);assert(isequal(B.take,take), ...
                'screening:run_objective_supplement:Checkpoint', ...
                'The checkpoint %s belongs to another supplement; remove it.',path);
            reused=reused+numel(take);
        else
            [block,execution]=screening.evaluate_local_information(provider,candidates(take,:),materials,policy, ...
                'RetainFullCovariance',true);
            B=struct('take',take,'block',block,'execution',execution);
            utils.atomic_save_struct(path,B,'-v7.3','NoReplace',true);executed=executed+numel(take);
        end
        localInformation.FullCovariance(:,:,:,take,:)=B.block.FullCovariance;
        localInformation.MarginalVariances(:,take,:,:)=B.block.MarginalVariances;
        progress=struct('status','RUNNING','candidatesCompleted',take(end), ...
            'candidateCount',height(candidates),'elapsedSeconds',toc(clock));
        utils.atomic_write_json(fullfile(outputRoot,'progress.json'),progress,'AllowReplace',true);
        fprintf('SUPPLEMENT %d/%d elapsed %.1fs\n',take(end),height(candidates),toc(clock));
    end
    localInformation.CovarianceParameterOrder=provider.materialParameterNames;
    localInformation.CovarianceCoordinates='prior_SD_standardized_material';
    arraysPath=fullfile(outputRoot,'full_covariance_supplement.mat');
    if ~isfile(arraysPath)
        utils.atomic_save_struct(arraysPath,struct('localInformation',localInformation), ...
            '-v7.3','NoReplace',true);
    end
    rankings=screening.aggregate_objectives(candidates,localInformation,policy);
    writetable(rankings,fullfile(outputRoot,'six_objective_rankings.csv'));
    writetable(screening.objective_registry(),fullfile(outputRoot,'objective_registry.csv'));
    receipt=struct('schemaVersion','stage9b_objective_supplement_receipt_v2','status','complete', ...
        'executedCandidatesThisInvocation',executed,'reusedCandidates',reused, ...
        'materialCount',height(materials),'covarianceViews',2,'objectiveCount',6, ...
        'elapsedSecondsThisInvocation',toc(clock),'environment',utils.environment_line(), ...
        'refits',0,'MCMC',0,'COMSOL',0);
    utils.atomic_write_json(fullfile(outputRoot,'receipt.json'),receipt,'AllowReplace',true);
    progress.status='COMPLETE';utils.atomic_write_json(fullfile(outputRoot,'progress.json'),progress,'AllowReplace',true);
end

function tf=strictly_disjoint(left,right)
%STRICTLY_DISJOINT True when neither folder contains the other.
    left=utils.absolute_path(left);right=utils.absolute_path(right);
    if ispc,left=lower(left);right=lower(right);end
    tf=~strcmp(left,right)&&~startsWith(left,[right filesep])&& ...
        ~startsWith(right,[left filesep]);
end
