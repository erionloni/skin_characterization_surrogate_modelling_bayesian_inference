function processVariance=gp_process_variance(model,outputCount)
%GP_PROCESS_VARIANCE Read UQLab's fitted scalar-output Kriging variances.
%   Values are read from Internal.Kriging(j).GP.sigmaSQ in physical mbar^2.
%   PROCESSVARIANCE = surrogates.gp_process_variance(MODEL, OUTPUTCOUNT)
%   returns one variance per output (1-by-OUTPUTCOUNT).
%   Side effects: none.

    validateattributes(outputCount,{'numeric'}, ...
        {'scalar','integer','positive'});
    processVariance=nan(1,outputCount);
    if isstruct(model)&&isfield(model,'models')
        assert(numel(model.models)==outputCount, ...
            'surrogates:gp_process_variance:EnsembleSize','Check failed: surrogates:gp_process_variance:EnsembleSize.');
        for j=1:outputCount
            processVariance(j)=read_one(model.models{j},1);
        end
    else
        for j=1:outputCount
            processVariance(j)=read_one(model,j);
        end
    end
    assert(all(isfinite(processVariance))&&all(processVariance>0), ...
        'surrogates:gp_process_variance:NonPositive', ...
        ['Every fitted output must expose a finite positive process variance ' ...
         'at Internal.Kriging(output).GP.sigmaSQ.']);
end

function value=read_one(model,index)
    internal=member(model,'Internal');
    kriging=member(internal,'Kriging');
    try
        component=kriging(index);
    catch
        error('surrogates:gp_process_variance:KrigingOutput', ...
            'The fitted model does not expose Kriging output %d.',index);
    end
    gp=member(component,'GP');
    value=double(member(gp,'sigmaSQ'));
    assert(isscalar(value), ...
        'surrogates:gp_process_variance:ProcessVarianceShape','Check failed: surrogates:gp_process_variance:ProcessVarianceShape.');
end

function value=member(source,name)
    try
        if isstruct(source)
            assert(isfield(source,name));
        else
            assert(isprop(source,name)||any(strcmp(fieldnames(source),name)));
        end
        value=source.(name);
    catch
        error('surrogates:gp_process_variance:MissingField', ...
            'The fitted UQLab model is missing %s.',name);
    end
end
