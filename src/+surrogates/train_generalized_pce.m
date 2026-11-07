function result = train_generalized_pce(X, y, cfg, outputName, outputIndex, ...
        outputRoot, trainingContract)
%TRAIN_GENERALIZED_PCE Fit one generalized PCE output, choosing its degree by cross-validation.
%   RESULT = surrogates.train_generalized_pce(X, Y, CFG, OUTPUTNAME, OUTPUTINDEX,
%   OUTPUTROOT, TRAININGCONTRACT) fits sparse (BCS) PCE
%   candidates of one closing pressure on the development cases that observe
%   it (X n x 7 in model coordinates, Y n x 1 in mbar; cohort, split groups
%   and folds from TRAININGCONTRACT, surrogates.fit_generalized). Degrees 1-3 are
%   always compared by the same 5-fold cross-validation; degree 4, then 5,
%   then 6 are added only while no candidate meets the training-only
%   adequacy criterion (surrogates.generalized_pce_policy). The candidate with the
%   smallest mean CV NRMSE is selected. Held-out cases are not an input, so
%   they cannot influence the selection.
%   UQLab's sparse regression shuffles its internal cross-validation with
%   the global random stream, so every candidate fit depends on its seed. A
%   candidate of the approved PCE uses the recorded seeds of its full fit
%   and folds (config/seeds/surrogate_fit_seeds.csv); any other takes them
%   from the settings' seed rule (seeds.surrogate_fit).
%   Every candidate and the selection are checkpointed below
%   OUTPUTROOT/<output> (named by output, degree, q-norm and retry attempt)
%   with their requests (surrogates.generalized_fit_request); a later call
%   returns the checkpoints of the same requests. RESULT has fields record,
%   model, fitInfo and path.
%   Side effects: writes the checkpoints of the candidates and of the
%   selection; the random number generator's state is restored.
%   Computation: seconds to minutes per candidate, minutes per output.

    policy=surrogates.generalized_pce_policy(cfg);
    validate_training_contract(trainingContract,X,y,outputName,outputIndex);
    % PCE basis construction requires an active UQLab Input object. GP
    % training does not, so a fresh refit process can otherwise reach PCE
    % with no current input and fail every degree before fitting.
    parameterSpace=parameters.parameter_space(cfg);
    assert(parameterSpace.M==size(X,2) && ...
        isequal(parameterSpace.names,cfg.realExtended.learningInputNames), ...
        'surrogates:train_generalized_pce:InputContract', ...
        'Active UQLab input does not match the seven-input route contract.');
    folder=fullfile(outputRoot,matlab.lang.makeValidName(outputName));
    if ~isfolder(folder),mkdir(folder);end
    sharedFolds=surrogates.pce_shared_folds( ...
        size(X,1),outputName,outputIndex,policy.cvFolds,trainingContract);

    candidates=cell(0,1);
    for degree=policy.initialDegrees
        candidates{end+1,1}=fit_candidate(degree,policy.qNormCandidates, ...
            X,y,cfg,outputName,outputIndex,folder,policy, ...
            sharedFolds,trainingContract); %#ok<AGROW>
    end
    while ~any(cellfun(@(x) candidate_adequate(x,policy),candidates))
        nextDegree=policy.escalationDegrees(numel(candidates)- ...
            numel(policy.initialDegrees)+1);
        candidates{end+1,1}=fit_candidate(nextDegree, ...
            policy.qNormCandidates,X,y,cfg,outputName,outputIndex, ...
            folder,policy,sharedFolds,trainingContract); %#ok<AGROW>
        if nextDegree==policy.escalationDegrees(end),break;end
    end

    candidateTable=records_to_table(candidates,size(X,1));
    valid=find(candidateTable.ExecutionStatus=="completed" & ...
        isfinite(candidateTable.MeanCVNRMSE));
    selectionSettings=surrogates.generalized_pce_selection_settings( ...
        policy,candidateTable);
    selectionRequest=surrogates.generalized_fit_request(cfg,'pce_selection', ...
        outputName,selectionSettings,trainingContract);
    selectionPath=fullfile(folder, ...
        sprintf('pce_selected_o%02d_attempt%d.mat', ...
        outputIndex,policy.retryAttempt));
    if isfile(selectionPath)
        result=load_selection(selectionPath,selectionRequest);
        return;
    end
    lockCleanup=surrogates.checkpoint_lock(selectionPath); %#ok<NASGU>
    if isfile(selectionPath)
        result=load_selection(selectionPath,selectionRequest);
        return;
    end

    record=struct( ...
        'schemaVersion','real_extended_pce_selection_checkpoint_v3', ...
        'request',selectionRequest, ...
        'scientificVersion',cfg.realExtended.scientificVersion, ...
        'route','real_extended','family','pce','outputName',outputName, ...
        'outputIndex',outputIndex,'policy',policy, ...
        'trainingCount',trainingContract.trainingCount, ...
        'trainingCaseIDs',trainingContract.trainingCaseIDs, ...
        'trainingSplitGroupIdentities', ...
            {trainingContract.trainingSplitGroupIdentities}, ...
        'candidateTable',candidateTable,'executionStatus','failed', ...
        'selectedDegree',NaN, ...
        'selectedQNorm',NaN,'trainingAdequacyMet',false, ...
        'cv',struct(), ...
        'failureIdentifier','','failureMessage','', ...
        'completedUTC',utc_now());
    model=[];
    fitInfo=struct();
    if isempty(valid)
        record.failureIdentifier='surrogates:train_generalized_pce:AllCandidatesFailed';
        record.failureMessage='No PCE candidate completed successfully.';
    else
        [~,local]=min(candidateTable.MeanCVNRMSE(valid));
        selectedIndex=valid(local);
        selected=candidates{selectedIndex};
        model=selected.model;
        fitInfo=selected.fitInfo;
        record.cv=selected.record.cv;
        record.executionStatus='completed';
        record.selectedDegree=selected.record.degree;
        record.selectedQNorm=selected.record.qNorm;
        record.trainingAdequacyMet=candidate_adequate(selected,policy);
    end
    utils.atomic_save_struct(selectionPath,struct( ...
        'record',record,'model',model,'fitInfo',fitInfo),'-v7.3','NoReplace',true);
    result=load_selection(selectionPath,selectionRequest);
end

function result=fit_candidate(degree,qNorm,X,y,cfg,outputName,outputIndex, ...
        folder,policy,sharedFolds,trainingContract)
    settings=struct('schemaVersion','real_extended_pce_candidate_v2', ...
        'degree',degree,'qNorm',qNorm,'method',cfg.pce.method, ...
        'retryAttempt',policy.retryAttempt, ...
        'cvFolds',policy.cvFolds,'cvMetric',policy.cvMetric, ...
        'heldoutUsedForSelection',false);
    settings=recorded_seeds(settings,cfg,outputIndex,degree);
    request=surrogates.generalized_fit_request(cfg,'pce_candidate', ...
        outputName,settings,trainingContract);
    candidateFolder=fullfile(folder,'candidates',sprintf('degree_%d',degree));
    pathValue=fullfile(candidateFolder,sprintf( ...
        'pce_o%02d_d%d_q%s_attempt%d.mat',outputIndex,degree, ...
        strrep(sprintf('%.3g',qNorm),'.','p'),policy.retryAttempt));
    if isfile(pathValue)
        result=load_candidate(pathValue,request);
        return;
    end
    lockCleanup=surrogates.checkpoint_lock(pathValue); %#ok<NASGU>
    if isfile(pathValue)
        result=load_candidate(pathValue,request);
        return;
    end

    fullTerms=nchoosek(size(X,2)+degree,degree);
    truncatedTerms=hyperbolic_count(size(X,2),degree,qNorm);
    record=struct( ...
        'schemaVersion','real_extended_pce_candidate_checkpoint_v3', ...
        'request',request, ...
        'scientificVersion',cfg.realExtended.scientificVersion, ...
        'route','real_extended','family','pce','outputName',outputName, ...
        'outputIndex',outputIndex,'degree',degree,'qNorm',qNorm, ...
        'trainingCaseIDs',trainingContract.trainingCaseIDs, ...
        'trainingSplitGroupIdentities', ...
            {trainingContract.trainingSplitGroupIdentities}, ...
        'method',cfg.pce.method,'cvFolds',policy.cvFolds, ...
        'fullTotalDegreeBasisSize',fullTerms, ...
        'hyperbolicCandidateSize',truncatedTerms, ...
        'trainingRows',size(X,1), ...
        'trainingRowsPerCandidateTerm',size(X,1)/truncatedTerms, ...
        'heldoutUsedForSelection',false,'executionStatus','pending', ...
        'failureIdentifier','','failureMessage','', ...
        'fitRuntimeSeconds',NaN,'fitWarningID','', ...
        'fitWarningMessage','','observedCandidateSize',NaN, ...
        'activeTermCount',NaN,'LOOError',NaN,'cv',struct(), ...
        'completedUTC','');
    model=[];fitInfo=struct();
    try
        cfgCandidate=cfg;
        cfgCandidate.pce.degrees=degree;
        cfgCandidate.pce.q_norm=qNorm;
        cv=cross_validate(X,y,sharedFolds,cfgCandidate,settings,outputIndex,degree);
        state=rng;cleanup=onCleanup(@()rng(state));
        rng(candidate_seed(settings,cfg,outputIndex,degree,0),'twister');
        lastwarn('');
        started=tic;
        [model,fitInfo]=surrogates.train_pce(X,y,cfgCandidate);
        fitInfo.trainTime=toc(started);
        [warningMessage,warningID]=lastwarn;
        fitInfo.warningID=warningID;
        fitInfo.warningMessage=warningMessage;
        clear cleanup
        diagnostics=surrogates.pce_fit_diagnostics(model,{outputName},fitInfo);
        record.executionStatus='completed';
        record.fitRuntimeSeconds=fitInfo.trainTime;
        record.fitWarningID=warningID;
        record.fitWarningMessage=warningMessage;
        record.observedCandidateSize=diagnostics.CandidateBasisSize(1);
        record.activeTermCount=diagnostics.ActiveBasisSize(1);
        record.LOOError=diagnostics.LOOError(1);
        record.cv=cv;
        record.completedUTC=utc_now();
    catch ME
        record.executionStatus='failed';
        record.failureIdentifier=ME.identifier;
        record.failureMessage=ME.message;
        record.completedUTC=utc_now();
    end
    utils.atomic_save_struct(pathValue,struct( ...
        'record',record,'model',model,'fitInfo',fitInfo),'-v7.3','NoReplace',true);
    result=load_candidate(pathValue,request);
end

function validate_training_contract(contract,X,y,outputName,outputIndex)
    required={'outputName','outputIndex','trainingCount', ...
        'trainingCaseIDs','trainingSplitGroupIdentities','cvFoldAssignment'};
    assert(isstruct(contract)&&all(isfield(contract,required))&& ...
        double(contract.trainingCount)==size(X,1)&&size(X,1)==numel(y)&& ...
        numel(contract.trainingCaseIDs)==size(X,1)&& ...
        numel(contract.trainingSplitGroupIdentities)==size(X,1)&& ...
        numel(contract.cvFoldAssignment)==size(X,1)&& ...
        all(isfinite(X),'all')&&all(isfinite(y)), ...
        'surrogates:train_generalized_pce:TrainingContract', ...
        ['The training cohort of output %s must list every case of X and Y, ' ...
         'with its split group and fold; inputs and responses must be finite.'], ...
        outputName);
    assert(strcmp(char(string(contract.outputName)),outputName)&& ...
        double(contract.outputIndex)==outputIndex, ...
        'surrogates:train_generalized_pce:TrainingOutput', ...
        'The training cohort belongs to output %s, not to output %d (%s).', ...
        char(string(contract.outputName)),outputIndex,outputName);
    assert(isfield(contract,'trainingX')&&isfield(contract,'trainingY')&& ...
        isequal(double(contract.trainingX),double(X))&& ...
        isequal(reshape(double(contract.trainingY),[],1),reshape(double(y),[],1)), ...
        'surrogates:train_generalized_pce:TrainingData', ...
        'The training cohort of output %s describes other training data than the fit receives.', ...
        outputName);
end

function settings=recorded_seeds(settings,cfg,outputIndex,degree)
%RECORDED_SEEDS Add the thesis seeds of this candidate when they are recorded.
%   The full fit and the cross-validation folds of the approved PCE's
%   candidates (config/seeds/surrogate_fit_seeds.csv).
    key=struct('Route','generalized','Model','pce','Output',outputIndex, ...
        'Degree',degree,'Fold',0);
    fullFitSeed=seeds.recorded(cfg,'surrogateFits',key);
    if isnan(fullFitSeed),return;end
    foldSeeds=nan(1,settings.cvFolds);
    for f=1:settings.cvFolds
        key.Fold=f;foldSeeds(f)=seeds.recorded(cfg,'surrogateFits',key);
    end
    assert(all(isfinite(foldSeeds)), ...
        'surrogates:train_generalized_pce:RecordedSeeds', ...
        ['The seed table records the full fit of output %d, degree %d, ' ...
         'but not the seeds of all its %d folds.'],outputIndex,degree,settings.cvFolds);
    settings.fullFitSeed=fullFitSeed;
    settings.foldSeeds=foldSeeds;
end

function seed=candidate_seed(settings,cfg,outputIndex,degree,fold)
%CANDIDATE_SEED Seed of the full fit (FOLD 0) or of one CV fold of a candidate.
%   The recorded thesis seed, or else the seed of the settings' seed rule
%   (seeds.surrogate_fit).
    if fold==0&&isfield(settings,'fullFitSeed')
        seed=double(settings.fullFitSeed);
    elseif fold>0&&isfield(settings,'foldSeeds')
        seed=double(settings.foldSeeds(fold));
    else
        seed=seeds.surrogate_fit(cfg,'generalized','pce',outputIndex,degree,fold);
    end
end

function cv=cross_validate(X,y,folds,cfg,settings,outputIndex,degree)
    k=max(folds);prediction=nan(size(y));foldRMSE=nan(k,1);
    foldNRMSE=nan(k,1);foldR2=nan(k,1);foldRuntime=nan(k,1);
    foldActiveTermCount=nan(k,1);foldActiveBasisKeys=cell(k,1);
    scale=max(y)-min(y);
    for f=1:k
        train=folds~=f;validation=folds==f;
        state=rng;cleanup=onCleanup(@()rng(state));
        rng(candidate_seed(settings,cfg,outputIndex,degree,f),'twister');
        started=tic;
        foldModel=surrogates.train_pce(X(train,:),y(train),cfg);
        foldRuntime(f)=toc(started);
        foldActiveBasisKeys{f}=active_basis_keys(foldModel);
        foldActiveTermCount(f)=numel(foldActiveBasisKeys{f});
        prediction(validation)=uq_evalModel(foldModel,X(validation,:));
        clear foldModel cleanup
        residual=prediction(validation)-y(validation);
        foldRMSE(f)=sqrt(mean(residual.^2));
        foldNRMSE(f)=foldRMSE(f)/max(scale,eps);
        denominator=sum((y(validation)-mean(y(validation))).^2);
        foldR2(f)=1-sum(residual.^2)/max(denominator,eps);
    end
    residual=prediction-y;
    pairwiseJaccard=nan(nchoosek(k,2),1);cursor=0;
    for first=1:k-1
        for second=first+1:k
            cursor=cursor+1;
            a=foldActiveBasisKeys{first};b=foldActiveBasisKeys{second};
            pairwiseJaccard(cursor)=numel(intersect(a,b))/max(numel(union(a,b)),1);
        end
    end
    cv=struct('schemaVersion','real_extended_pce_cv_v1', ...
        'foldAssignment',folds,'prediction',prediction, ...
        'foldRMSE',foldRMSE,'foldNRMSE',foldNRMSE,'foldR2',foldR2, ...
        'foldRuntimeSeconds',foldRuntime, ...
        'foldActiveTermCount',foldActiveTermCount, ...
        'foldActiveBasisKeys',{foldActiveBasisKeys}, ...
        'activeTermCountCoefficientOfVariation', ...
            std(foldActiveTermCount)/max(mean(foldActiveTermCount),eps), ...
        'activeBasisPairwiseJaccard',pairwiseJaccard, ...
        'activeBasisJaccardMean',mean(pairwiseJaccard), ...
        'activeBasisJaccardMinimum',min(pairwiseJaccard), ...
        'RMSE',sqrt(mean(residual.^2)), ...
        'NRMSE',sqrt(mean(residual.^2))/max(scale,eps), ...
        'MAE',mean(abs(residual)), ...
        'R2',1-sum(residual.^2)/max(sum((y-mean(y)).^2),eps), ...
        'maxFoldNRMSE',max(foldNRMSE));
end

function keys=active_basis_keys(model)
    keys=strings(0,1);
    try
        indices=full(model.PCE(1).Basis.Indices);
        coefficients=model.PCE(1).Coefficients(:);
        threshold=1e-14*max(max(abs(coefficients)),1);
        active=abs(coefficients)>threshold;
        indices=indices(active,:);
        keys=strings(size(indices,1),1);
        for row=1:size(indices,1)
            keys(row)=strjoin(string(indices(row,:)),'_');
        end
    catch
    end
end

function tf=candidate_adequate(candidate,policy)
    tf=strcmp(candidate.record.executionStatus,'completed') && ...
        isfield(candidate.record,'cv') && ...
        candidate.record.cv.NRMSE<=policy.adequateMeanCVNRMSE && ...
        candidate.record.cv.maxFoldNRMSE<=policy.adequateMaxFoldNRMSE;
end

function tableOut=records_to_table(candidates,nTrain)
    n=numel(candidates);
    Degree=nan(n,1);QNorm=nan(n,1);FullTotalDegreeBasisSize=nan(n,1);
    HyperbolicCandidateSize=nan(n,1);ObservedCandidateSize=nan(n,1);
    TrainingRowsPerCandidateTerm=nan(n,1);ActiveTermCount=nan(n,1);
    ActiveCandidateRatio=nan(n,1);LOOError=nan(n,1);
    CVRMSE=nan(n,1);CVMAE=nan(n,1);MeanCVNRMSE=nan(n,1);
    MaxFoldNRMSE=nan(n,1);CVR2=nan(n,1);FitRuntimeSeconds=nan(n,1);
    TotalCVRuntimeSeconds=nan(n,1);
    FoldActiveTermCountCV=nan(n,1);ActiveBasisJaccardMean=nan(n,1);
    ActiveBasisJaccardMinimum=nan(n,1);
    ExecutionStatus=strings(n,1);WarningID=strings(n,1);
    FailureIdentifier=strings(n,1);
    for i=1:n
        r=candidates{i}.record;
        Degree(i)=r.degree;QNorm(i)=r.qNorm;
        FullTotalDegreeBasisSize(i)=r.fullTotalDegreeBasisSize;
        HyperbolicCandidateSize(i)=r.hyperbolicCandidateSize;
        ObservedCandidateSize(i)=r.observedCandidateSize;
        TrainingRowsPerCandidateTerm(i)=nTrain/r.hyperbolicCandidateSize;
        ActiveTermCount(i)=r.activeTermCount;
        ActiveCandidateRatio(i)=r.activeTermCount/r.hyperbolicCandidateSize;
        LOOError(i)=r.LOOError;FitRuntimeSeconds(i)=r.fitRuntimeSeconds;
        ExecutionStatus(i)=string(r.executionStatus);
        WarningID(i)=string(r.fitWarningID);
        FailureIdentifier(i)=string(r.failureIdentifier);
        if strcmp(r.executionStatus,'completed')
            CVRMSE(i)=r.cv.RMSE;
            CVMAE(i)=r.cv.MAE;
            MeanCVNRMSE(i)=r.cv.NRMSE;
            MaxFoldNRMSE(i)=r.cv.maxFoldNRMSE;
            CVR2(i)=r.cv.R2;
            TotalCVRuntimeSeconds(i)=sum(r.cv.foldRuntimeSeconds);
            FoldActiveTermCountCV(i)=r.cv.activeTermCountCoefficientOfVariation;
            ActiveBasisJaccardMean(i)=r.cv.activeBasisJaccardMean;
            ActiveBasisJaccardMinimum(i)=r.cv.activeBasisJaccardMinimum;
        end
    end
    tableOut=table(Degree,QNorm,FullTotalDegreeBasisSize, ...
        HyperbolicCandidateSize,ObservedCandidateSize, ...
        TrainingRowsPerCandidateTerm,ActiveTermCount,ActiveCandidateRatio, ...
        LOOError,CVRMSE,CVMAE,MeanCVNRMSE,MaxFoldNRMSE,CVR2, ...
        FitRuntimeSeconds,TotalCVRuntimeSeconds, ...
        FoldActiveTermCountCV,ActiveBasisJaccardMean, ...
        ActiveBasisJaccardMinimum, ...
        ExecutionStatus,WarningID,FailureIdentifier);
end

function count=hyperbolic_count(nInput,degree,qNorm)
    count=recurse(1,degree,0);
    function value=recurse(position,remaining,sumPower)
        value=0;
        if position==nInput
            for exponent=0:remaining
                normValue=(sumPower+exponent^qNorm)^(1/qNorm);
                if normValue<=degree+64*eps(max(degree,1))
                    value=value+1;
                end
            end
            return;
        end
        for exponent=0:remaining
            value=value+recurse(position+1,remaining-exponent, ...
                sumPower+exponent^qNorm);
        end
    end
end

function result=load_candidate(pathValue,request)
    loaded=load(pathValue,'record','model','fitInfo');
    assert(all(isfield(loaded,{'record','model','fitInfo'})) && ...
        isfield(loaded.record,'request') && ...
        isequaln(loaded.record.request,request) && ...
        any(strcmp(loaded.record.executionStatus,{'completed','failed'})), ...
        'surrogates:train_generalized_pce:InvalidCandidate', ...
        ['The PCE candidate checkpoint %s is incomplete or belongs to another ' ...
         'fit (data, folds or settings); delete it to refit the candidate.'],pathValue);
    result=struct('record',loaded.record,'model',loaded.model, ...
        'fitInfo',loaded.fitInfo,'path',pathValue);
end

function result=load_selection(pathValue,request)
    loaded=load(pathValue,'record','model','fitInfo');
    assert(all(isfield(loaded,{'record','model','fitInfo'})) && ...
        isfield(loaded.record,'request') && ...
        isequaln(loaded.record.request,request) && ...
        any(strcmp(loaded.record.executionStatus,{'completed','failed'})), ...
        'surrogates:train_generalized_pce:InvalidSelection', ...
        ['The PCE selection checkpoint %s is incomplete or belongs to another ' ...
         'fit (data, folds or settings); delete it to select again.'],pathValue);
    result=struct('record',loaded.record,'model',loaded.model, ...
        'fitInfo',loaded.fitInfo,'path',pathValue);
end

function value=utc_now()
    value=char(datetime('now','TimeZone','UTC', ...
        'Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
