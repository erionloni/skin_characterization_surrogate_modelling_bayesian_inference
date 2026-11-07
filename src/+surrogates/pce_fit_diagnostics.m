function diagnostics = pce_fit_diagnostics(model, outputNames, fitInfo)
%PCE_FIT_DIAGNOSTICS Extract auditable UQLab PCE fit/complexity evidence.
%   DIAGNOSTICS = PCE_FIT_DIAGNOSTICS(MODEL, OUTPUTNAMES, FITINFO) reads a
%   fitted multi-output UQLab PCE without modifying it.  Requested settings,
%   selected basis complexity, sparse active terms, LOO diagnostics, runtime
%   and captured warnings are returned one row per output.  Missing fields
%   remain NaN/empty rather than being silently invented.
%   Side effects: none.

    if nargin < 2 || isempty(outputNames)
        outputNames = default_output_names(model);
    end
    if nargin < 3 || isempty(fitInfo), fitInfo = struct(); end
    outputNames = string(outputNames(:));
    nOutput = numel(outputNames);

    requestedMethod = string(get_nested(model, {'Options','Method'}, ""));
    requestedDegrees = get_nested(model, {'Options','Degree'}, []);
    requestedDegreeText = string(mat2str(requestedDegrees));
    requestedQNorm = get_nested(model, ...
        {'Options','TruncOptions','qNorm'}, NaN);
    trainTime = get_numeric_scalar(fitInfo, 'trainTime', NaN);
    warningID = string(get_text(fitInfo, ...
        {'warningID','fitWarningID'}, ""));
    warningMessage = string(get_text(fitInfo, ...
        {'warningMessage','fitWarningMessage'}, ""));
    fitFailed = logical(get_numeric_scalar(fitInfo, 'fitFailed', false));
    failureIdentifier = string(get_text(fitInfo, ...
        {'failureIdentifier','errorIdentifier'}, ""));
    failureMessage = string(get_text(fitInfo, ...
        {'failureMessage','errorMessage'}, ""));

    selectedDegree = nan(nOutput,1);
    qNorm = nan(nOutput,1);
    candidateBasisSize = nan(nOutput,1);
    activeBasisSize = nan(nOutput,1);
    loo = nan(nOutput,1);
    modifiedLOO = nan(nOutput,1);
    normalizedEmpiricalError = nan(nOutput,1);
    degreeSearchLOO = strings(nOutput,1);
    degreeSearchNormalizedEmpiricalError = strings(nOutput,1);

    for j = 1:nOutput
        if has_member(model,'PCE') && numel(model.PCE) >= j
            one = model.PCE(j);
            selectedDegree(j) = get_nested(one, {'Basis','Degree'}, NaN);
            qNorm(j) = get_nested(one, {'Basis','qNorm'}, requestedQNorm);
            indices = get_nested(one, {'Basis','Indices'}, []);
            if isempty(indices)
                indices = get_nested(one, {'Basis','IndicesFull'}, []);
            end
            if ~isempty(indices), candidateBasisSize(j) = size(indices,1); end
            coefficients = get_nested(one, {'Coefficients'}, []);
            if ~isempty(coefficients)
                coefficients = coefficients(:);
                threshold = 1e-14 * max(max(abs(coefficients)),1);
                activeBasisSize(j) = nnz(abs(coefficients) > threshold);
            end
        end
        if has_member(model,'Error') && numel(model.Error) >= j
            errorRecord = model.Error(j);
            loo(j) = get_nested(errorRecord, {'LOO'}, NaN);
            modifiedLOO(j) = get_nested(errorRecord, {'ModifiedLOO'}, NaN);
            normalizedEmpiricalError(j) = ...
                get_nested(errorRecord, {'normEmpErr'}, NaN);
        end
        if has_member(model,'Internal') && ...
                isfield(model.Internal,'PCE') && numel(model.Internal.PCE) >= j
            internal = model.Internal.PCE(j);
            degreeSearchLOO(j) = string(mat2str( ...
                get_nested(internal, {'BCS','LOO'}, [])));
            degreeSearchNormalizedEmpiricalError(j) = string(mat2str( ...
                get_nested(internal, {'BCS','normEmpErr'}, [])));
        end
    end

    activeCandidateRatio = activeBasisSize ./ candidateBasisSize;
    diagnostics = table(outputNames, ...
        repmat(requestedMethod,nOutput,1), ...
        repmat(requestedDegreeText,nOutput,1), ...
        repmat(requestedQNorm,nOutput,1), selectedDegree, qNorm, ...
        candidateBasisSize, activeBasisSize, activeCandidateRatio, ...
        loo, modifiedLOO, normalizedEmpiricalError, degreeSearchLOO, ...
        degreeSearchNormalizedEmpiricalError, ...
        repmat(trainTime,nOutput,1), repmat(warningID,nOutput,1), ...
        repmat(warningMessage,nOutput,1), repmat(fitFailed,nOutput,1), ...
        repmat(failureIdentifier,nOutput,1), ...
        repmat(failureMessage,nOutput,1), ...
        'VariableNames', {'Output','SparseSolver','RequestedDegrees', ...
        'RequestedQNorm','SelectedDegree','QNorm','CandidateBasisSize', ...
        'ActiveBasisSize','ActiveCandidateRatio','LOOError', ...
        'ModifiedLOOError','NormalizedEmpiricalError','DegreeSearchLOO', ...
        'DegreeSearchNormalizedEmpiricalError','TrainingTimeSeconds', ...
        'FitWarningID','FitWarningMessage','FitFailed', ...
        'FailureIdentifier','FailureMessage'});
end

function names = default_output_names(model)
    if has_member(model,'PCE')
        n = numel(model.PCE);
    else
        n = 0;
    end
    names = arrayfun(@(i) sprintf('output_%d',i),1:n, ...
        'UniformOutput',false);
end

function value = get_nested(source, path, fallback)
    value = fallback;
    current = source;
    for i = 1:numel(path)
        name = path{i};
        if ~isstruct(current) && ~isobject(current), return; end
        if ~has_member(current,name), return; end
        current = current.(name);
    end
    if ~isempty(current), value = current; end
end

function tf = has_member(value,name)
    try
        tf = any(strcmp(fieldnames(value),name));
    catch
        tf = false;
    end
end

function value = get_numeric_scalar(source,name,fallback)
    value = fallback;
    if isstruct(source) && isfield(source,name)
        candidate = source.(name);
        if (isnumeric(candidate) || islogical(candidate)) && ...
                isscalar(candidate)
            value = candidate;
        end
    end
end

function value = get_text(source,names,fallback)
    value = fallback;
    if ~isstruct(source), return; end
    for i = 1:numel(names)
        if isfield(source,names{i})
            candidate = source.(names{i});
            if ischar(candidate) || (isstring(candidate) && isscalar(candidate))
                value = char(string(candidate));
                return;
            end
        end
    end
end
