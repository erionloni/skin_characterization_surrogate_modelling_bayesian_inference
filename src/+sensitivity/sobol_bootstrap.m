function result = sobol_bootstrap(forwardFunction,nInputs,nBase,nReplicates,seed)
%SOBOL_BOOTSTRAP Fixed-evaluation bootstrap for first/total/second Sobol indices.
%   This quantifies Monte Carlo estimator uncertainty conditional on the
%   supplied forward/surrogate evaluator. It does not claim surrogate-refit
%   uncertainty.
%   RESULT = sensitivity.sobol_bootstrap(FORWARDFUNCTION, NINPUTS, NBASE,
%   NREPLICATES, SEED) draws, with the seed SEED, two base samples of NBASE
%   points in the unit cube (FORWARDFUNCTION maps them to the outputs),
%   evaluates them and their single- and pairwise-mixed matrices once, then
%   resamples the rows NREPLICATES times and returns the bootstrap
%   distributions, intervals and rank probabilities of the first-, total-
%   and second-order indices, with the failure rate per output.
%   Side effects: none (the random number generator's state is restored).

    assert(isa(forwardFunction,'function_handle')&&isscalar(nInputs)&& ...
        nInputs==fix(nInputs)&&nInputs>=1&& ...
        nBase>=100&&nReplicates>=1, ...
        'sensitivity:sobol_bootstrap:Configuration', ...
        'Provide a vectorized evaluator, a positive input dimension, and valid sample sizes.');
    previous=rng;cleanup=onCleanup(@() rng(previous));rng(seed,'twister');
    A=rand(nBase,nInputs);B=rand(nBase,nInputs);
    YA=forwardFunction(A);YB=forwardFunction(B);
    assert(isnumeric(YA)&&isequal(size(YA),size(YB))&& ...
        size(YA,1)==nBase&&all(isfinite(YA(:)))&&all(isfinite(YB(:))), ...
        'sensitivity:sobol_bootstrap:ForwardOutput', ...
        'The evaluator must return a finite nBase-by-nOutput matrix.');
    nOutputs=size(YA,2);
    pairs=nchoosek(1:nInputs,2);
    YSingle=cell(1,nInputs);
    for i=1:nInputs
        mixed=A;mixed(:,i)=B(:,i);YSingle{i}=forwardFunction(mixed);
    end
    YPair=cell(size(pairs,1),1);
    for p=1:size(pairs,1)
        mixed=A;mixed(:,pairs(p,:))=B(:,pairs(p,:));
        YPair{p}=forwardFunction(mixed);
    end
    first=zeros(nReplicates,nOutputs,nInputs);
    total=zeros(nReplicates,nOutputs,nInputs);
    second=zeros(nReplicates,nOutputs,size(pairs,1));
    failed=false(nReplicates,nOutputs);
    for b=1:nReplicates
        index=randi(nBase,nBase,1);
        variance=var([YA(index,:);YB(index,:)],1,1);
        failed(b,:)=~isfinite(variance)|variance<=eps;
        variance=max(variance,eps);
        for i=1:nInputs
            first(b,:,i)=mean(YB(index,:).* ...
                (YSingle{i}(index,:)-YA(index,:)),1)./variance;
            total(b,:,i)=0.5*mean((YA(index,:)- ...
                YSingle{i}(index,:)).^2,1)./variance;
        end
        for p=1:size(pairs,1)
            joint=mean(YB(index,:).* ...
                (YPair{p}(index,:)-YA(index,:)),1)./variance;
            second(b,:,p)=joint-first(b,:,pairs(p,1))- ...
                first(b,:,pairs(p,2));
        end
    end
    medianFirst=reshape(median(first,1),nOutputs,nInputs);
    medianTotal=reshape(median(total,1),nOutputs,nInputs);
    medianSecond=reshape(median(second,1),nOutputs,size(pairs,1));
    ciFirst=bootstrap_interval(first);
    ciTotal=bootstrap_interval(total);
    ciSecond=bootstrap_interval(second);
    [probabilityFirstOrderRankFirst,probabilityFirstOrderRankLast]= ...
        rank_probabilities(first,nOutputs,nInputs,nReplicates);
    [probabilityTotalOrderRankFirst,probabilityTotalOrderRankLast]= ...
        rank_probabilities(total,nOutputs,nInputs,nReplicates);
    result=struct( ...
        'schema_version','routeR_sobol_bootstrap_v2', ...
        'uncertainty_scope','conditional_monte_carlo_estimator_only', ...
        'n_base',nBase,'n_replicates',nReplicates,'seed',seed, ...
        'first_replicates',first,'total_replicates',total, ...
        'second_replicates',second,'second_order_pairs',pairs, ...
        'median_first',medianFirst,'median_total',medianTotal, ...
        'median_second',medianSecond, ...
        'ci95_first',ciFirst,'ci95_total',ciTotal, ...
        'ci95_second',ciSecond, ...
        'probability_first_order_rank_first', ...
            probabilityFirstOrderRankFirst, ...
        'probability_first_order_rank_last', ...
            probabilityFirstOrderRankLast, ...
        'probability_total_order_rank_first', ...
            probabilityTotalOrderRankFirst, ...
        'probability_total_order_rank_last', ...
            probabilityTotalOrderRankLast, ...
        'probability_rank_first',probabilityFirstOrderRankFirst, ...
        'probability_rank_last',probabilityFirstOrderRankLast, ...
        'bootstrap_failure_rate',mean(failed,1));
end

function [probabilityFirst,probabilityLast]= ...
        rank_probabilities(values,nOutputs,nInputs,nReplicates)
    probabilityFirst=zeros(nOutputs,nInputs);
    probabilityLast=zeros(nOutputs,nInputs);
    for out=1:nOutputs
        for b=1:nReplicates
            [~,highest]=max(values(b,out,:));
            [~,lowest]=min(values(b,out,:));
            probabilityFirst(out,highest)=probabilityFirst(out,highest)+1;
            probabilityLast(out,lowest)=probabilityLast(out,lowest)+1;
        end
    end
    probabilityFirst=probabilityFirst/nReplicates;
    probabilityLast=probabilityLast/nReplicates;
end

function interval=bootstrap_interval(values)
    [~,nOutputs,nInputs]=size(values);
    interval=zeros(nOutputs,nInputs,2);
    for o=1:nOutputs
        for i=1:nInputs
            interval(o,i,:)=utils.weighted_quantile( ...
                values(:,o,i),[0.025 0.975]);
        end
    end
end
