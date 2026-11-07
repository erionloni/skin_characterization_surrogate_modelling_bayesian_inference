function result = train_generalized_gp(X, y, cfg, outputName, outputIndex, ...
        outputRoot, trainingContract)
%TRAIN_GENERALIZED_GP Fit one generalized GP output, after its 5-fold cross-validation.
%   RESULT = surrogates.train_generalized_gp(X, Y, CFG, OUTPUTNAME, OUTPUTINDEX,
%   OUTPUTROOT, TRAININGCONTRACT) fits the Kriging model of
%   one closing pressure (OUTPUTINDEX 1-6) on the development cases that
%   observe it: X (n x 7 inputs in model coordinates), Y (n x 1, mbar), with
%   the cohort, split groups and fold assignment of TRAININGCONTRACT
%   (surrogates.fit_generalized). The settings are surrogates.generalized_gp_policy's:
%   outputs 1 and 3 select the best of the declared starts
%   (surrogates.fit_gp_candidates); the others are single fits seeded with
%   the recorded thesis seed. The cross-validation refits the model on each
%   fold's training cases (development only).
%   The fit is checkpointed in OUTPUTROOT/<output>/gp_o<output>_attempt<n>.mat
%   with its request (surrogates.generalized_fit_request); a later call
%   returns the checkpoint of the same request. RESULT has fields record,
%   model, fitInfo and path; a fit that fails is recorded as failed, not
%   retried.
%   Side effects: writes the checkpoint (for a multi-start output also the
%   candidates' checkpoints, surrogates.fit_gp_candidates) and, while it
%   fits, a lock file (surrogates.checkpoint_lock); the random number
%   generator's state is restored.
%   Computation: 1-4 min per single-fit output, about 30 min for a
%   multi-start output at the thesis settings.

    settings = surrogates.generalized_gp_policy(cfg,outputIndex);
    validate_training_contract(trainingContract,X,y,outputName,outputIndex);
    request = surrogates.generalized_fit_request(cfg,'gp',outputName,settings,trainingContract);
    folder = fullfile(outputRoot,matlab.lang.makeValidName(outputName));
    checkpointPath = fullfile(folder, ...
        sprintf('gp_o%02d_attempt%d.mat',outputIndex,settings.retryAttempt));
    if isfile(checkpointPath)
        result = load_checkpoint(checkpointPath,request);
        return;
    end

    lockCleanup = surrogates.checkpoint_lock(checkpointPath); %#ok<NASGU>
    if isfile(checkpointPath)
        result = load_checkpoint(checkpointPath,request);
        return;
    end
    record = base_record(request,outputName,outputIndex, ...
        settings,run_relative(checkpointPath,cfg.paths.runRoot), ...
        cfg.realExtended.scientificVersion,trainingContract);
    model = [];
    fitInfo = struct();
    try
        folds = contract_folds(trainingContract,settings.cvFolds);
        cv = cross_validate(X,y,folds,cfg,settings,folder,outputIndex);
        state = rng;
        rngCleanup = onCleanup(@()rng(state));
        rng(full_fit_seed(settings,cfg,outputIndex),'twister');
        lastwarn('');
        started = tic;
        if isfield(settings,'numericalSelection')
            selected=surrogates.fit_gp_candidates(X,y,cfg, ...
                settings.numericalSelection,struct('output',outputIndex, ...
                'role','full_development'),fullfile(folder,'candidate_fits'));
            model=selected.model;fitInfo=struct( ...
                'selectedIndex',selected.selectedIndex, ...
                'selectedSeed',selected.records{selected.selectedIndex}.seed, ...
                'candidatePaths',{selected.candidatePaths});
            fitInfo.optimizerEvidence=selected.records{selected.selectedIndex}.optimizerEvidence;
            cv.fullFitSelection=fitInfo;
        else
            [model,fitInfo] = surrogates.train_gp(X,y,cfg,budget_options(settings));
        end
        fitInfo.trainTime = toc(started);
        [warningMessage,warningID] = lastwarn;
        fitInfo.warningID = warningID;
        fitInfo.warningMessage = warningMessage;
        clear rngCleanup
        theta = extract_theta(model,size(X,2));
        record.executionStatus = 'completed';
        record.fitRuntimeSeconds = fitInfo.trainTime;
        record.fitWarningID = warningID;
        record.fitWarningMessage = warningMessage;
        record.optimizerStatus = ...
            'completed_no_explicit_uqlab_optimizer_status_field';
        if isfield(settings,'numericalSelection')
            record.optimizerStatus='termination_recorded_in_cv_fullFitSelection_optimizerEvidence';
        end
        record.theta = theta;
        record.cv = cv;
        record.completedUTC = utc_now();
    catch ME
        record.executionStatus = 'failed';
        record.failureIdentifier = ME.identifier;
        record.failureMessage = ME.message;
        record.completedUTC = utc_now();
    end
    utils.atomic_save_struct(checkpointPath,struct( ...
        'record',record,'model',model,'fitInfo',fitInfo),'-v7.3','NoReplace',true);
    result = load_checkpoint(checkpointPath,request);
end

function cv = cross_validate(X,y,folds,cfg,settings,folder,outputIndex)
    k=max(folds); prediction=nan(size(y)); foldRMSE=nan(k,1);
    foldNRMSE=nan(k,1); foldR2=nan(k,1); foldRuntime=nan(k,1);
    scale=max(y)-min(y);
    selectedSeeds=nan(k,1);
    for f=1:k
        train=folds~=f;validation=folds==f;
        state=rng;cleanup=onCleanup(@()rng(state));
        % The approved single-fit outputs were fitted without this
        % cross-validation, so no thesis seed exists for its folds; the
        % seed follows from the seed rule of the settings.
        rng(seeds.surrogate_fit(cfg,'generalized','gp',outputIndex,[],f),'twister');
        started=tic;
        if isfield(settings,'numericalSelection')
            selected=surrogates.fit_gp_candidates(X(train,:),y(train),cfg, ...
                settings.numericalSelection,struct('output',outputIndex, ...
                'role','development_CV','fold',f,'trainingRows',find(train)), ...
                fullfile(folder,'candidate_fits'));
            foldModel=selected.model;
            selectedSeeds(f)=selected.records{selected.selectedIndex}.seed;
        else
            foldModel=surrogates.train_gp(X(train,:),y(train),cfg,budget_options(settings));
        end
        foldRuntime(f)=toc(started);
        prediction(validation)=uq_evalModel(foldModel,X(validation,:));
        clear foldModel cleanup
        residual=prediction(validation)-y(validation);
        foldRMSE(f)=sqrt(mean(residual.^2));
        foldNRMSE(f)=foldRMSE(f)/max(scale,eps);
        denominator=sum((y(validation)-mean(y(validation))).^2);
        foldR2(f)=1-sum(residual.^2)/max(denominator,eps);
    end
    residual=prediction-y;
    cv=struct('schemaVersion','real_extended_gp_cv_v1', ...
        'foldAssignment',folds,'prediction',prediction, ...
        'foldRMSE',foldRMSE,'foldNRMSE',foldNRMSE,'foldR2',foldR2, ...
        'foldRuntimeSeconds',foldRuntime, ...
        'RMSE',sqrt(mean(residual.^2)), ...
        'NRMSE',sqrt(mean(residual.^2))/max(scale,eps), ...
        'MAE',mean(abs(residual)), ...
        'R2',1-sum(residual.^2)/max(sum((y-mean(y)).^2),eps));
    if isfield(settings,'numericalSelection')
        cv.foldSelectedSeeds=selectedSeeds;
    end
end

function seed=full_fit_seed(settings,cfg,outputIndex)
%FULL_FIT_SEED Seed of the full fit: the recorded thesis seed when the policy carries one.
%   Otherwise the seed of the settings' seed rule (seeds.surrogate_fit).
    if isfield(settings,'fullFitSeed')
        seed=double(settings.fullFitSeed);
    else
        seed=seeds.surrogate_fit(cfg,'generalized','gp',outputIndex,[],0);
    end
end

function options=budget_options(settings)
%BUDGET_OPTIONS HGA iteration limit of a demonstration budget, and the fixed length scales of
%   a manual refit; none at the thesis settings.
    options=struct();
    if isfield(settings,'demonstrationIterations')
        options.optimMaxIter=settings.demonstrationIterations;
    end
    if isfield(settings,'fixedTheta')
        options.fixedTheta=settings.fixedTheta;
    end
end

function theta=extract_theta(model,nInput)
    theta=nan(1,nInput);
    try
        value=model.Kriging(1).theta(:).';
        if numel(value)==nInput,theta=value;end
    catch
    end
end

function record=base_record(request,outputName,outputIndex, ...
        settings,checkpointPath,scientificVersion,trainingContract)
    record=struct( ...
        'schemaVersion','real_extended_gp_output_checkpoint_v3', ...
        'request',request, ...
        'scientificVersion',scientificVersion, ...
        'route','real_extended','family','gp','outputName',outputName, ...
        'outputIndex',outputIndex,'settings',settings, ...
        'trainingCount',trainingContract.trainingCount, ...
        'trainingCaseIDs',trainingContract.trainingCaseIDs, ...
        'trainingSplitGroupIdentities', ...
            {trainingContract.trainingSplitGroupIdentities}, ...
        'checkpointPath',checkpointPath,'executionStatus','pending', ...
        'failureIdentifier','','failureMessage','', ...
        'fitRuntimeSeconds',NaN,'fitWarningID','', ...
        'fitWarningMessage','','optimizerStatus','not_run', ...
        'theta',[],'cv',struct(),'completedUTC','');
end

function folds=contract_folds(contract,k)
    folds=double(contract.cvFoldAssignment(:));
    groups=string(contract.trainingSplitGroupIdentities(:));
    assert(numel(folds)==numel(groups)&&all(isfinite(folds))&& ...
        all(folds==fix(folds))&&all(folds>=1&folds<=k)&& ...
        isequal(unique(folds).',(1:k)), ...
        'surrogates:train_generalized_gp:CVFoldAssignment', ...
        ['The output''s cases must take their folds from the one global ' ...
         'assignment and cover all %d folds.'],k);
    [uniqueGroups,~,groupIndex]=unique(groups,'stable');
    for i=1:numel(uniqueGroups)
        assert(isscalar(unique(folds(groupIndex==i))), ...
            'surrogates:train_generalized_gp:CVGroupLeakage', ...
            'One material split group occurs in more than one CV fold.');
    end
end

function validate_training_contract(contract,X,y,outputName,outputIndex)
    required={'outputName','outputIndex','trainingCount','trainingCaseIDs', ...
        'trainingSplitGroupIdentities','cvFoldAssignment'};
    assert(isstruct(contract)&&all(isfield(contract,required))&& ...
        double(contract.trainingCount)==size(X,1)&&size(X,1)==numel(y)&& ...
        numel(contract.trainingCaseIDs)==size(X,1)&& ...
        numel(contract.trainingSplitGroupIdentities)==size(X,1)&& ...
        numel(contract.cvFoldAssignment)==size(X,1)&& ...
        all(isfinite(X),'all')&&all(isfinite(y)), ...
        'surrogates:train_generalized_gp:TrainingContract', ...
        ['The training cohort of output %s must list every case of X and Y, ' ...
         'with its split group and fold; inputs and responses must be finite.'], ...
        outputName);
    assert(strcmp(char(string(contract.outputName)),outputName)&& ...
        double(contract.outputIndex)==outputIndex, ...
        'surrogates:train_generalized_gp:TrainingOutput', ...
        'The training cohort belongs to output %s, not to output %d (%s).', ...
        char(string(contract.outputName)),outputIndex,outputName);
    assert(isfield(contract,'trainingX')&&isfield(contract,'trainingY')&& ...
        isequal(double(contract.trainingX),double(X))&& ...
        isequal(reshape(double(contract.trainingY),[],1),reshape(double(y),[],1)), ...
        'surrogates:train_generalized_gp:TrainingData', ...
        'The training cohort of output %s describes other training data than the fit receives.', ...
        outputName);
end

function result=load_checkpoint(pathValue,request)
    loaded=load(pathValue,'record','model','fitInfo');
    assert(all(isfield(loaded,{'record','model','fitInfo'})) && ...
        isstruct(loaded.record) && isfield(loaded.record,'request') && ...
        isequaln(loaded.record.request,request) && ...
        any(strcmp(loaded.record.executionStatus,{'completed','failed'})), ...
        'surrogates:train_generalized_gp:InvalidCheckpoint', ...
        ['The GP checkpoint %s is incomplete or belongs to another fit (data, ' ...
         'folds or settings); delete it to refit the output.'],pathValue);
    result=struct('record',loaded.record,'model',loaded.model, ...
        'fitInfo',loaded.fitInfo,'path',pathValue);
end

function value=run_relative(pathValue,runRoot)
    pathValue=utils.absolute_path(pathValue);
    runRoot=utils.absolute_path(runRoot);
    prefix=[runRoot filesep];
    if ispc
        contained=startsWith(lower(pathValue),lower(prefix));
    else
        contained=startsWith(pathValue,prefix);
    end
    assert(contained,'surrogates:train_generalized_gp:CheckpointOutsideRun', ...
        'The GP checkpoint %s lies outside the run folder %s.',pathValue,runRoot);
    value=strrep(pathValue(numel(prefix)+1:end),'\','/');
end

function value=utc_now()
    value=char(datetime('now','TimeZone','UTC', ...
        'Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
