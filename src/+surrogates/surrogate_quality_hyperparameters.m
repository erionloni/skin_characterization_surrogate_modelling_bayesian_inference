function T=surrogate_quality_hyperparameters(model,inputNames,outputNames,context)
%SURROGATE_QUALITY_HYPERPARAMETERS Long factual UQLab GP fit metadata.
%   T = surrogates.surrogate_quality_hyperparameters(MODEL, INPUTNAMES,
%   OUTPUTNAMES, CONTEXT) tabulates the fitted UQLab Kriging MODEL (inputs
%   INPUTNAMES, outputs OUTPUTNAMES) with the fit CONTEXT (campaign, repeat,
%   fold, kernel, optimizer, nugget, seed, request key, time, status).
%   One row is returned per output/input. Theta is the authoritative raw
%   UQLab value in UQLab's normalized input coordinates. The normalized
%   inverse-theta importance is descriptive and sums to one within output.
%   Optional process/trend/optimizer quantities remain explicitly missing
%   when the fitted object does not expose them.
%   Side effects: none.

    arguments
        model
        inputNames
        outputNames
        context (1,1) struct
    end
    inputNames=reshape(string(inputNames),[],1);
    outputNames=reshape(string(outputNames),[],1);
    nInput=numel(inputNames);nOutput=numel(outputNames);
    required={'Campaign','Repeat','Fold','Kernel','Optimizer','Nugget', ...
        'SeedBasis','FitSeed','FitRequest','TrainTime_s','FitStatus'};
    assert(all(isfield(context,required)), ...
        'surrogates:surrogate_quality_hyperparameters:Context', ...
        'The fit context lacks the field(s) %s.',strjoin(required(~isfield(context,required)),', '));

    n=nInput*nOutput;
    Campaign=repmat(string(context.Campaign),n,1);
    Repeat=repmat(double(context.Repeat),n,1);
    Fold=repmat(double(context.Fold),n,1);
    Kernel=repmat(string(context.Kernel),n,1);
    Optimizer=repmat(string(context.Optimizer),n,1);
    Nugget=repmat(double(context.Nugget),n,1);
    SeedBasis=repmat(string(context.SeedBasis),n,1);
    FitSeed=repmat(double(context.FitSeed),n,1);
    FitRequest=repmat(string(context.FitRequest),n,1);
    TrainTime_s=repmat(double(context.TrainTime_s),n,1);
    FitStatus=repmat(string(context.FitStatus),n,1);
    OutputIndex=zeros(n,1);Output=strings(n,1);
    InputIndex=zeros(n,1);Input=strings(n,1);
    Theta=nan(n,1);NormalizedInverseThetaImportance=nan(n,1);
    ARDCoordinateSystem=repmat("UQLab_normalized_dimensionless_input",n,1);
    ProcessVariance=nan(n,1);ProcessVarianceAvailable=false(n,1);
    ProcessVarianceSource=strings(n,1);ProcessVarianceMissingReason=strings(n,1);
    TrendCoefficients=strings(n,1);TrendCoefficientCount=zeros(n,1);
    TrendCoefficientsAvailable=false(n,1);TrendCoefficientsSource=strings(n,1);
    TrendCoefficientsMissingReason=strings(n,1);
    OptimizerObjective=nan(n,1);OptimizerObjectiveAvailable=false(n,1);
    OptimizerObjectiveSource=strings(n,1);OptimizerObjectiveMissingReason=strings(n,1);
    OptimizerEvaluationCount=nan(n,1);OptimizerIterationCount=nan(n,1);
    OptimizerExitFlag=nan(n,1);OptimizerTerminationAvailable=false(n,1);
    OptimizerExitFlagGA=nan(n,1);OptimizerExitFlagBFGS=nan(n,1);
    OptimizerTerminationState=strings(n,1);
    OptimizerTerminationSource=strings(n,1);OptimizerTerminationMissingReason=strings(n,1);

    row=0;
    for outputIndex=1:nOutput
        component=kriging_component(model,outputIndex,nOutput);
        theta=read_numeric(component,{'theta'});
        if numel(theta)~=nInput,theta=nan(1,nInput);else,theta=theta(:).';end
        inverse=1./theta;
        if all(isfinite(inverse))&&all(inverse>0)
            importance=inverse/sum(inverse);
        else
            importance=nan(1,nInput);
        end
        [process,processSource]=first_numeric(component, ...
            {{'sigmaSQ'},{'sigma2'},{'ProcessVariance'}});
        [trend,trendSource]=first_numeric(component, ...
            {{'beta'},{'Beta'},{'trendCoefficients'}});
        internal=internal_component(model,outputIndex);
        if isempty(process)
            [process,processSource]=first_numeric(internal, ...
                {{'GP','sigmaSQ'},{'GP','Regression','sigmaSQ'}});
        end
        if isempty(trend)
            [trend,trendSource]=first_numeric(internal, ...
                {{'GP','Trend','beta'},{'Trend','beta'}});
        end
        [objective,objectiveSource]=first_numeric(internal, ...
            {{'Optim','ObjFun'},{'Optim','Objective'},{'Optim','fval'}});
        [evaluationCount,evaluationSource]=first_numeric(internal, ...
            {{'Optim','nEval'},{'Optim','FunctionCount'}});
        [iterationCount,iterationSource]=first_numeric(internal, ...
            {{'Optim','nIter'},{'Optim','IterationCount'}});
        [exitFlag,exitSource]=first_value(internal, ...
            {{'Optim','ExitFlag'},{'Optim','exitflag'}});
        terminationSources=[string(evaluationSource);string(iterationSource); ...
            string(exitSource)];
        terminationSources=terminationSources(strlength(terminationSources)>0);

        for inputIndex=1:nInput
            row=row+1;OutputIndex(row)=outputIndex;Output(row)=outputNames(outputIndex);
            InputIndex(row)=inputIndex;Input(row)=inputNames(inputIndex);
            Theta(row)=theta(inputIndex);
            NormalizedInverseThetaImportance(row)=importance(inputIndex);
            if ~isempty(process)&&isscalar(process)&&isfinite(process)
                ProcessVariance(row)=double(process);
                ProcessVarianceAvailable(row)=true;
                ProcessVarianceSource(row)=string(processSource);
            else
                ProcessVarianceMissingReason(row)= ...
                    "not_exposed_as_finite_scalar_by_fitted_model";
            end
            if ~isempty(trend)&&all(isfinite(trend))
                TrendCoefficients(row)=string(mat2str(double(trend(:).'),17));
                TrendCoefficientCount(row)=numel(trend);
                TrendCoefficientsAvailable(row)=true;
                TrendCoefficientsSource(row)=string(trendSource);
            else
                TrendCoefficientsMissingReason(row)= ...
                    "not_exposed_as_finite_vector_by_fitted_model";
            end
            if ~isempty(objective)&&isscalar(objective)&&isfinite(objective)
                OptimizerObjective(row)=double(objective);
                OptimizerObjectiveAvailable(row)=true;
                OptimizerObjectiveSource(row)=string(objectiveSource);
            else
                OptimizerObjectiveMissingReason(row)= ...
                    "not_exposed_as_finite_scalar_by_fitted_model";
            end
            if ~isempty(evaluationCount)&&isscalar(evaluationCount)
                OptimizerEvaluationCount(row)=double(evaluationCount);
            end
            if ~isempty(iterationCount)&&isscalar(iterationCount)
                OptimizerIterationCount(row)=double(iterationCount);
            end
            if isnumeric(exitFlag)&&isscalar(exitFlag)
                OptimizerExitFlag(row)=double(exitFlag);
                OptimizerTerminationState(row)=string(num2str( ...
                    double(exitFlag),17));
            elseif isstruct(exitFlag)&&isscalar(exitFlag)
                OptimizerTerminationState(row)=string(jsonencode(exitFlag));
                ga=read_numeric(exitFlag,{'GA'});
                bfgs=read_numeric(exitFlag,{'BFGS'});
                if isscalar(ga),OptimizerExitFlagGA(row)=ga;end
                if isscalar(bfgs),OptimizerExitFlagBFGS(row)=bfgs;end
            end
            if any(isfinite([OptimizerEvaluationCount(row) ...
                    OptimizerIterationCount(row) OptimizerExitFlag(row) ...
                    OptimizerExitFlagGA(row) OptimizerExitFlagBFGS(row)]))|| ...
                    strlength(OptimizerTerminationState(row))>0
                OptimizerTerminationAvailable(row)=true;
                OptimizerTerminationSource(row)=strjoin(terminationSources,';');
            else
                OptimizerTerminationMissingReason(row)= ...
                    "optimizer_termination_fields_not_exposed";
            end
        end
    end

    T=table(Campaign,Repeat,Fold,Kernel,Optimizer,Nugget,SeedBasis,FitSeed, ...
        FitRequest,OutputIndex,Output,InputIndex,Input,Theta, ...
        NormalizedInverseThetaImportance,ARDCoordinateSystem, ...
        ProcessVariance,ProcessVarianceAvailable,ProcessVarianceSource, ...
        ProcessVarianceMissingReason,TrendCoefficients,TrendCoefficientCount, ...
        TrendCoefficientsAvailable,TrendCoefficientsSource, ...
        TrendCoefficientsMissingReason,OptimizerObjective, ...
        OptimizerObjectiveAvailable,OptimizerObjectiveSource, ...
        OptimizerObjectiveMissingReason,OptimizerEvaluationCount, ...
        OptimizerIterationCount,OptimizerExitFlag,OptimizerExitFlagGA, ...
        OptimizerExitFlagBFGS,OptimizerTerminationState, ...
        OptimizerTerminationAvailable,OptimizerTerminationSource, ...
        OptimizerTerminationMissingReason,TrainTime_s,FitStatus);
end

function component=kriging_component(model,index,nOutput)
    component=[];
    if isstruct(model)&&isfield(model,'models')
        if numel(model.models)~=nOutput||isempty(model.models{index}),return;end
        child=model.models{index};
        value=read_value(child,{'Kriging'});
    else
        value=read_value(model,{'Kriging'});
    end
    if isempty(value),return;end
    try
        if isstruct(model)&&isfield(model,'models'),component=value(1); ...
        else,component=value(index);end
    catch
        component=[];
    end
end

function component=internal_component(model,index)
    component=[];internal=read_value(model,{'Internal','Kriging'});
    if isempty(internal),return;end
    try
        component=internal(index);
    catch
        component=[];
    end
end

function [value,source]=first_numeric(root,paths)
    value=[];source='';
    for i=1:numel(paths)
        candidate=read_numeric(root,paths{i});
        if ~isempty(candidate)
            value=candidate;source=strjoin(string(paths{i}),'.');return
        end
    end
end

function [value,source]=first_value(root,paths)
    value=[];source='';
    for i=1:numel(paths)
        candidate=read_value(root,paths{i});
        if ~isempty(candidate)
            value=candidate;source=strjoin(string(paths{i}),'.');return
        end
    end
end

function value=read_numeric(root,path)
    value=read_value(root,path);
    if isempty(value)||~isnumeric(value),value=[];else,value=double(value);end
end

function value=read_value(root,path)
    value=root;
    try
        for i=1:numel(path)
            name=path{i};
            if isstruct(value)
                if ~isfield(value,name),value=[];return;end
                value=value.(name);
            else
                names=fieldnames(value);
                if ~any(strcmp(names,name)),value=[];return;end
                value=value.(name);
            end
        end
    catch
        value=[];
    end
end
