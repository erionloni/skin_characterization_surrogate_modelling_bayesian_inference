function result=fit_gp_candidates(X,y,cfg,policy,context,root)
%FIT_GP_CANDIDATES Fit a GP from each declared start and select one (multi-start selection).
%   RESULT = surrogates.fit_gp_candidates(X, Y, CFG, POLICY, CONTEXT, ROOT)
%   fits one Kriging model per declared start POLICY.seeds (HGA with at most
%   POLICY.maxIter iterations, kernel POLICY.kernel, nugget CFG.gp.nugget)
%   on the training data X (n x d) and Y (n x 1) only, and selects the
%   candidate with the smallest re-evaluated analytic leave-one-out MSE
%   (POLICY.selectionRule 'minimum_reevaluated_analytic_loo_mse_ordered_seed_tie_v1';
%   exact ties go to the earlier start; surrogates.select_gp_candidate). A
%   candidate whose objective cannot be re-evaluated
%   (surrogates.gp_optimizer_evidence) or whose predictions at its training
%   data are not finite is not eligible. The same function fits the full
%   development data and the training data of each cross-validation fold;
%   CONTEXT says which (its role, 'full_development' or 'development_CV'
%   with the fold) and is part of the request.
%   Every candidate is checkpointed in ROOT/<role>, for example
%   ROOT/development_CV_fold_2, with the request (data, policy, context,
%   nugget, optimizer); a later call reuses the checkpoints only for the same
%   request.
%   RESULT has fields status, records (one per start), candidatePaths,
%   completedCandidates, selectedIndex and model (the selected fit).
%   Computation: one HGA Kriging fit per start (minutes each at 100 iterations).
%   Side effects: writes the candidates' checkpoints below the checkpoint
%   folder; the random number generator's state is restored.

    validateattributes(X,{'numeric'},{'2d','real','finite','nonempty'});
    validateattributes(y,{'numeric'},{'column','real','finite','numel',size(X,1)});
    required={'kernel','seeds','maxIter','selectionRule'};
    rule='minimum_reevaluated_analytic_loo_mse_ordered_seed_tie_v1';
    assert(isstruct(policy)&&isscalar(policy)&&all(isfield(policy,required))&& ...
        strcmp(policy.selectionRule,rule)&&isstruct(context)&&isscalar(context), ...
        'surrogates:fit_gp_candidates:Policy', ...
        ['The multi-start policy needs a kernel, the declared starts, an ' ...
         'iteration limit and the selection rule %s.'],rule);
    seeds=double(policy.seeds(:).');
    assert(~isempty(seeds)&&all(isfinite(seeds))&&all(seeds==fix(seeds))&& ...
        all(seeds>0&seeds<2^32)&&numel(unique(seeds))==numel(seeds), ...
        'surrogates:fit_gp_candidates:Seeds', ...
        'The declared starts must be distinct integers from 1 to 2^32-1.');
    validateattributes(policy.maxIter,{'numeric'}, ...
        {'scalar','integer','positive','finite','real'});
    assert(strcmpi(cfg.gp.optim_method,'HGA'),'surrogates:fit_gp_candidates:HGA', ...
        'The multi-start selection is defined for the HGA optimizer, not for %s.', ...
        cfg.gp.optim_method);
    request=struct('schemaVersion','scalar_gp_multistart_request_v2', ...
        'X',double(X),'y',double(y),'policy',policy,'context',context, ...
        'nugget',cfg.gp.nugget,'optimizer',cfg.gp.optim_method);
    name=folder_name(context);
    folder=fullfile(root,name);
    if ~isfolder(folder),mkdir(folder);end
    requestPath=fullfile(folder,'request.mat');
    if isfile(requestPath)
        saved=load(requestPath,'request');
        assert(isfield(saved,'request')&&isequaln(saved.request,request), ...
            'surrogates:fit_gp_candidates:CheckpointRequest', ...
            ['The candidate fits in %s belong to another request (data, policy or ' ...
             'settings); delete the folder to refit.'],folder);
    else
        utils.atomic_save_struct(requestPath,struct('request',request), ...
            '-v7.3','NoReplace',true);
    end
    records=cell(1,numel(seeds));paths=cell(size(records));
    % Capture and restore caller state without seed-dependent side effects.
    originalState=rng;
    cleanup=onCleanup(@()rng(originalState));
    for k=1:numel(seeds)
        path=fullfile(folder,sprintf('candidate_%02d_seed_%u.mat',k,seeds(k)));
        paths{k}=path;
        if isfile(path)
            loaded=load(path,'record');record=loaded.record;
            assert(record.seed==seeds(k)&&record.seedOrder==k, ...
                'surrogates:fit_gp_candidates:CheckpointSeed', ...
                'The candidate checkpoint %s belongs to another start; delete it to refit.', ...
                path);
            records{k}=record;continue
        end
        fprintf('[GP candidates] %s candidate %d/%d seed=%u N=%d MaxIter=%d\n', ...
            name,k,numel(seeds),seeds(k),numel(y),policy.maxIter);
        record=struct('schemaVersion','scalar_gp_candidate_v2', ...
            'seedOrder',k,'seed',seeds(k), ...
            'policy',policy,'context',context,'trainingCount',numel(y), ...
            'executionStatus','failed','eligible',false,'objective',NaN, ...
            'optimizerEvidence',struct(),'fitInfo',struct(),'errorIdentifier','', ...
            'errorMessage','','console','','runtimeSeconds',NaN);
        % model and info are assigned inside evalc; declared here so that
        % MATLAB treats them as variables (info is also a built-in function).
        model=[];info=struct();timer=tic;
        try
            rng(seeds(k),'twister');
            opts=struct('kernel',policy.kernel,'nugget',cfg.gp.nugget, ...
                'optimMethod',cfg.gp.optim_method,'optimMaxIter',policy.maxIter); %#ok<NASGU> evalc
            record.console=evalc('[model,info]=surrogates.train_gp(X,y,cfg,opts);');
            evidence=surrogates.gp_optimizer_evidence(model);
            [mu,v]=surrogates.evaluate(model,X,'gp');
            assert(all(isfinite(mu))&&all(isfinite(v))&&all(v>=0), ...
                'surrogates:fit_gp_candidates:FiniteModel', ...
                'The candidate predicts non-finite values or a negative variance at its training data.');
            assert(isequal(model.ExpDesign.X,X)&&isequal(model.ExpDesign.Y,y), ...
                'surrogates:fit_gp_candidates:TrainingOrder', ...
                'The fitted candidate does not hold the training data in the given order.');
            record.optimizerEvidence=evidence;record.fitInfo=info;
            record.objective=evidence.reevaluatedObjective;
            record.eligible=true;record.executionStatus='completed';
        catch ME
            record.errorIdentifier=ME.identifier;record.errorMessage=getReport(ME,'extended','hyperlinks','off');
        end
        record.runtimeSeconds=toc(timer);
        utils.atomic_save_struct(path,struct('model',model,'record',record), ...
            '-v7.3','NoReplace',true);
        records{k}=record;
        if ~isempty(model),uq_removeModel(model);end
        clear model
    end
    R=[records{:}];index=surrogates.select_gp_candidate([R.objective],[R.eligible]);
    loaded=load(paths{index},'model');
    result=struct('status','complete', ...
        'records',{records},'candidatePaths',{paths},'completedCandidates',numel(records), ...
        'selectedIndex',index,'model',loaded.model);
    summary=rmfield(result,'model');
    summaryPath=fullfile(folder,'selection.json');
    if ~isfile(summaryPath),utils.atomic_write_json(summaryPath,summary);end
end

function name=folder_name(context)
%FOLDER_NAME The candidates' folder: the fit's role, and its fold for a cross-validation fit.
    assert(isfield(context,'role'), ...
        'surrogates:fit_gp_candidates:Context', ...
        'The context of a multi-start fit names its role.');
    name=char(string(context.role));
    if isfield(context,'fold')
        name=sprintf('%s_fold_%d',name,double(context.fold));
    end
end
