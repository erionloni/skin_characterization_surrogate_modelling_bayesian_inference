function result = fit_fixed(cfg)
%FIT_FIXED Fit the fixed route's canonical GP and PCE surrogates (six outputs).
%   RESULT = surrogates.fit_fixed(CFG) fits, on the development cases of the
%   dataset CFG.files.dataset, one GP and one PCE per closing pressure. Each
%   scalar model uses every finite development observation of its output
%   (surrogates.output_training_contract); the external cases are never
%   given to a fit. Each fit has its recorded seed (seeds.surrogate_fit,
%   config/seeds/surrogate_fit_seeds.csv; output 6 of the GP has the
%   reviewed seed 221754153). It writes the models and fit
%   metadata (CFG.files.gp, CFG.files.pce), the output training contract
%   (CFG.files.outputTrainingContract) and the training cohort table
%   (CFG.files.outputTrainingCohorts). RESULT names the model files.
%   The body of the pre-publication script
%   (s02_train_surrogates), moved unchanged.
%   Computation: about 1-2 minutes (UQLab).
%   Side effects: writes the files above; the random number generator's
%   state is restored afterwards.

    ensure_dirs({fileparts(cfg.files.gp),cfg.paths.surrogateAssessment});
    assert(strcmp(cfg.dataMode,'real'),'surrogates:fit_fixed:Route', ...
        'surrogates.fit_fixed fits the fixed route''s surrogates.');
    dataSet=stage2_dataset(cfg);
    training=surrogates.output_training_contract(dataSet,cfg);

    %% The canonical models: one GP and one PCE per output
    [gp,gpInfo]=fit_output_ensemble('gp',training,cfg);
    [pce,pceInfo]=fit_output_ensemble('pce',training,cfg);
    trainingMode='output_specific_scalar_ensembles';
    gpInfo.outputTrainingCounts=reshape([training.records.count],1,[]);
    pceInfo.outputTrainingCounts=reshape([training.records.count],1,[]);
    gpInfo.trainingMode=trainingMode;pceInfo.trainingMode=trainingMode;
    gpInfo=attach_gp_metadata(gp,gpInfo,cfg);
    pceInfo=attach_pce_metadata(pceInfo,cfg);
    utils.atomic_save_struct(cfg.files.gp,struct('gp',gp,'gpInfo',gpInfo));
    utils.atomic_save_struct(cfg.files.pce,struct('pce',pce,'pceInfo',pceInfo));
    publish_training_contract(training,dataSet,gpInfo,pceInfo,cfg);
    result=struct('route','real','canonical_gp',cfg.files.gp, ...
        'canonical_pce',cfg.files.pce);
    fprintf(['[surrogates] canonical GP/PCE trained with output counts [%s]; ' ...
        'external-test evidence was not supplied to either fit.\n'], ...
        strjoin(string([training.records.count]),','));
end

function publish_training_contract(training,dataSet,gpInfo,pceInfo,cfg)
%PUBLISH_TRAINING_CONTRACT Write the training cohorts of the six outputs.
%   The emulator-error calibration lists, per output, the development cases
%   it was fitted on; these are the cases of the table's TrainingCaseIDs.
    root=fileparts(cfg.files.outputTrainingContract);
    if ~isfolder(root),mkdir(root);end
    public=training;
    public.records=rmfield(public.records,{'X','Y','mask'});
    public.developmentCaseCount=numel(training.developmentCaseIDs);
    public.externalTestCaseIDs=reshape(double(dataSet.validationCaseIDs),1,[]);
    utils.atomic_save_struct(cfg.files.outputTrainingContract, ...
        struct('outputTrainingContract',public));
    n=numel(training.records);OutputIndex=(1:n).';
    Output=string(training.outputOrder(:));
    ValidDevelopmentCount=reshape([training.records.count],[],1);
    MissingDevelopmentCount=reshape( ...
        [training.records.missingDevelopmentCount],[],1);
    CompleteContributorCount=reshape( ...
        [training.records.completeContributorCount],[],1);
    PartialContributorCount=reshape( ...
        [training.records.partialContributorCount],[],1);
    TrainingCaseIDs=strings(n,1);
    GPFitSeed=double(gpInfo.childSeeds(:));
    PCEFitSeed=double(pceInfo.childSeeds(:));
    for j=1:n
        TrainingCaseIDs(j)=strjoin(string(training.records(j).caseIDs.'),';');
    end
    T=table(OutputIndex,Output,ValidDevelopmentCount, ...
        CompleteContributorCount,PartialContributorCount, ...
        MissingDevelopmentCount,TrainingCaseIDs,GPFitSeed,PCEFitSeed);
    utils.atomic_write_table(cfg.files.outputTrainingCohorts,T);
end

function info=attach_gp_metadata(gp,info,cfg)
%ATTACH_GP_METADATA The fitted process variances, ARD scales and input/output order.
    P=struct('outputNames',{cfg.outputNames},'M',numel(cfg.paramNames), ...
        'names',{cfg.paramNames});
    ard=sensitivity.ard(gp,P);
    info.processVarianceMbar2=surrogates.gp_process_variance(gp,6);
    info.ardThetaUQLabNormalizedCoordinates=double(ard.theta);
    info.ardNormalizedInverseThetaImportance=double(ard.importance);
    info.inputOrder=cfg.paramNames;
    info.outputOrder=cfg.outputNames;
end

function info=attach_pce_metadata(info,cfg)
%ATTACH_PCE_METADATA The input and output order of the PCE fit.
    info.inputOrder=cfg.paramNames;
    info.outputOrder=cfg.outputNames;
end

function [ensemble,info]=fit_output_ensemble(family,training,cfg)
    models=cell(1,6);childInfo=cell(1,6);childSeeds=zeros(1,6);
    total=tic;
    for j=1:6
        one=training.records(j);
        [seed,source]=seeds.surrogate_fit(cfg,'fixed',family,j,[],0);
        childSeeds(j)=seed;
        state=rng;cleanup=onCleanup(@()rng(state));
        rng(seed,'twister');
        if strcmp(family,'gp')
            options=struct();
            if ~isempty(cfg.gp.fixedTheta)
                % refit_manual with fixed length scales (settings A.3).
                options.fixedTheta=cfg.gp.fixedTheta(j,:);
            end
            [models{j},childInfo{j}]=surrogates.train_gp(one.X,one.Y,cfg,options);
        else
            [models{j},childInfo{j}]=surrogates.train_pce(one.X,one.Y,cfg);
        end
        childInfo{j}.randomNumberStream=struct('seed',seed,'source',source, ...
            'rngAlgorithm','twister');
        clear cleanup
    end
    ensemble=struct( ...
        'schemaVersion','routeR_fixed_output_ensemble_v1', ...
        'family',family,'models',{models}, ...
        'inputNames',{training.inputOrder},'outputNames',{training.outputOrder});
    optimMethod=cfg.gp.optim_method;
    if strcmp(family,'gp')&&~isempty(cfg.gp.fixedTheta)
        optimMethod='none';   % the fixed length scales of the settings, not optimized
    end
    info=struct('trainTime',toc(total),'children',{childInfo}, ...
        'childSeeds',childSeeds,'kernel',cfg.gp.kernel,'nugget',cfg.gp.nugget, ...
        'optimMethod',optimMethod,'trend',cfg.gp.trend, ...
        'correlationType',cfg.gp.correlation,'LOO',nan(6,1), ...
        'randomNumberStream',struct('rngAlgorithm','twister', ...
            'seedTable',cfg.seeds.tables.surrogateFits,'fitSeeds',childSeeds));
    if strcmp(family,'pce')
        info.kernel='not_applicable';
        info.nugget=NaN;
        info.optimMethod='not_applicable';
        for j=1:6
            if isfield(childInfo{j},'LOO'),info.LOO(j)=childInfo{j}.LOO(1);end
        end
    end
end

function dataSet=stage2_dataset(cfg)
    fields={'X_train','Y_train','inputNames','outputNames','inputBounds', ...
        'trainCaseIDs','trainSourceRows','validationCaseIDs', ...
        'developmentOutputAvailability','outputTrainingEvidence','counts', ...
        'dataProvenance'};
    dataSet=utils.load_plain_mat(cfg.files.dataset,fields{:});
    required={'X_train','Y_train','inputNames','outputNames','trainCaseIDs', ...
        'trainSourceRows','validationCaseIDs'};
    assert(all(isfield(dataSet,required))&& ...
        size(dataSet.X_train,2)==4&&size(dataSet.Y_train,2)==6&& ...
        size(dataSet.X_train,1)==size(dataSet.Y_train,1)&& ...
        numel(dataSet.trainCaseIDs)==size(dataSet.X_train,1)&& ...
        ~isempty(dataSet.validationCaseIDs)&& ...
        all(isfinite(dataSet.X_train),'all')&&~any(isinf(dataSet.Y_train),'all')&& ...
        isempty(intersect(double(dataSet.trainCaseIDs), ...
            double(dataSet.validationCaseIDs))), ...
        'surrogates:fit_fixed:DevelopmentDataset', ...
        ['The dataset %s is not a fixed-route dataset: it needs four finite ' ...
         'inputs and six outputs per development case, and development and ' ...
         'external cases that do not overlap. Rerun the step ''dataset''.'], ...
        cfg.files.dataset);
end

function ensure_dirs(paths)
    for i=1:numel(paths),if ~isfolder(paths{i}),mkdir(paths{i});end,end
end
