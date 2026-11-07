function result = finite_difference_jacobian(forwardFunction, u, step, varargin)
%FINITE_DIFFERENCE_JACOBIAN Bound-aware Jacobian and covariance-whitened SVD.
%   RESULT = design_study.finite_difference_jacobian(FUN,U,STEP) evaluates FUN in
%   normalized [0,1] parameter coordinates and uses identity output weight.
%
%   RESULT = design_study.finite_difference_jacobian(...,SIGMA) or
%   RESULT = design_study.finite_difference_jacobian(...,'OutputCovariance',SIGMA)
%   uses the Cholesky-whitened Jacobian L\J, where L*L'=SIGMA. SIGMA must
%   be finite, symmetric, and positive definite; no jitter is added.
%
%   Optional name/value inputs:
%     RankRelativeTolerance - numerical-rank threshold (default 1e-3)
%     SymmetryTolerance     - relative covariance check (default 1e-10)
%     PrimaryStepOnly       - opt-in vectorized primary-step calculation
%                             for an N-by-M unit-box matrix (default false)
%     CenterValues          - optional N-by-K forward values used only with
%                             PrimaryStepOnly (default empty)
%   Side effects: none.

    if nargin < 3 || isempty(step), step = 1e-3; end
    options = parse_options(varargin{:});
    validate_inputs(forwardFunction,u,step,options);

    if options.PrimaryStepOnly
        result = primary_step_only_jacobian( ...
            forwardFunction,u,step,options.CenterValues);
        return;
    end

    u = u(:).';
    steps = [step/2 step 2*step];
    rawMatrices = cell(1,3);
    for i=1:3
        rawMatrices{i} = one_jacobian(forwardFunction,u,steps(i));
    end
    nOutput = size(rawMatrices{2},1);
    [whitenedMatrices,covariance,lowerFactor,method] = whiten( ...
        rawMatrices,options.OutputCovariance,nOutput, ...
        options.SymmetryTolerance);
    raw = rawMatrices{2};
    weighted = whitenedMatrices{2};
    nParameter = size(raw,2);
    [leftVectors,singularMatrix,rightVectors] = svd(weighted);
    diagonalValues = diag(singularMatrix);
    singularValues = zeros(nParameter,1);
    singularValues(1:numel(diagonalValues)) = diagonalValues;

    if isempty(singularValues) || singularValues(1)==0
        numericalRank = 0;
    else
        numericalRank = sum(singularValues/singularValues(1) >= ...
            options.RankRelativeTolerance);
    end
    if numericalRank < nParameter
        conditionNumber = Inf;
    else
        conditionNumber = singularValues(1)/max(singularValues(end), ...
            eps(singularValues(1)));
    end
    if isempty(singularValues) || singularValues(1)==0 || ...
            singularValues(end)==0
        continuousConditionNumber = Inf;
    else
        continuousConditionNumber = singularValues(1)/singularValues(end);
    end

    rawStepDifference = relative_step_difference(rawMatrices);
    weightedStepDifference = relative_step_difference(whitenedMatrices);
    result = struct( ...
        'matrix',raw, ...
        'rawMatrix',raw, ...
        'whitenedMatrix',weighted, ...
        'svdMatrix',weighted, ...
        'steps',steps, ...
        'stepMatrices',{rawMatrices}, ...
        'rawStepMatrices',{rawMatrices}, ...
        'whitenedStepMatrices',{whitenedMatrices}, ...
        'U',leftVectors, ...
        'singularValues',singularValues, ...
        'V',rightVectors, ...
        'conditionNumber',conditionNumber, ...
        'continuousConditionNumber',continuousConditionNumber, ...
        'relativeStepDifference',weightedStepDifference, ...
        'relativeStepDifferenceRaw',rawStepDifference, ...
        'relativeStepDifferenceWhitened',weightedStepDifference, ...
        'numericalRank',numericalRank, ...
        'nParameters',nParameter, ...
        'nOutputs',nOutput, ...
        'rankRelativeTolerance',options.RankRelativeTolerance, ...
        'parameterCoordinates',u, ...
        'parameterCoordinateSystem','normalized_unit_box', ...
        'outputCovariance',covariance, ...
        'outputWhiteningFactor',lowerFactor, ...
        'outputWhiteningMethod',method, ...
        'whiteningApplied',~isempty(options.OutputCovariance), ...
        'fisherInformation',weighted.'*weighted, ...
        'rawGramMatrix',raw.'*raw);
end

function options = parse_options(varargin)
    options = struct('OutputCovariance',[], ...
        'RankRelativeTolerance',1e-3,'SymmetryTolerance',1e-10, ...
        'PrimaryStepOnly',false,'CenterValues',[]);
    if isempty(varargin), return; end
    first = varargin{1};
    if isnumeric(first) && ~ischar(first) && ...
            ~(isstring(first)&&isscalar(first))
        options.OutputCovariance = first;
        varargin(1) = [];
    elseif isstruct(first)
        names = fieldnames(first);
        for i=1:numel(names)
            options = set_option(options,names{i},first.(names{i}));
        end
        varargin(1) = [];
    end
    if mod(numel(varargin),2)~=0
        error('design_study:finite_difference_jacobian:InvalidOptions', ...
            'Optional inputs must be a covariance, a struct, or name/value pairs.');
    end
    for i=1:2:numel(varargin)
        options = set_option(options,varargin{i},varargin{i+1});
    end
end

function options = set_option(options,name,value)
    if ~(ischar(name)||(isstring(name)&&isscalar(name)))
        error('design_study:finite_difference_jacobian:InvalidOptionName', ...
            'Option names must be text scalars.');
    end
    switch lower(char(name))
        case {'outputcovariance','likelihoodcovariance'}
            options.OutputCovariance = value;
        case 'rankrelativetolerance'
            options.RankRelativeTolerance = value;
        case 'symmetrytolerance'
            options.SymmetryTolerance = value;
        case 'primarysteponly'
            options.PrimaryStepOnly = value;
        case {'centervalues','suppliedcentervalues'}
            options.CenterValues = value;
        otherwise
            error('design_study:finite_difference_jacobian:UnknownOption', ...
                'Unknown option "%s".',char(name));
    end
end

function validate_inputs(forwardFunction,u,step,options)
    if ~isa(forwardFunction,'function_handle')
        error('design_study:finite_difference_jacobian:InvalidFunction', ...
            'forwardFunction must be a function handle.');
    end
    if ~islogical(options.PrimaryStepOnly)||~isscalar(options.PrimaryStepOnly)
        error('design_study:finite_difference_jacobian:InvalidPrimaryStepOnly', ...
            'PrimaryStepOnly must be a logical scalar.');
    end
    if options.PrimaryStepOnly
        validCoordinate=isnumeric(u)&&ismatrix(u)&&~isempty(u)&& ...
            all(isfinite(u),'all')&&all(u>=0&u<=1,'all');
    else
        validCoordinate=isnumeric(u)&&isvector(u)&&~isempty(u)&& ...
            all(isfinite(u(:)))&&all(u(:)>=0)&&all(u(:)<=1);
    end
    if ~validCoordinate
        error('design_study:finite_difference_jacobian:InvalidCoordinate', ...
            ['u must be a finite normalized vector in [0,1], or an N-by-M ' ...
             'matrix when PrimaryStepOnly is true.']);
    end
    if ~isscalar(step)||~isfinite(step)||step<=0||step>0.25
        error('design_study:finite_difference_jacobian:InvalidStep', ...
            ['step must be finite and in (0,0.25] so the doubled-step ' ...
             'audit remains feasible throughout [0,1].']);
    end
    if ~isscalar(options.RankRelativeTolerance)|| ...
            ~isfinite(options.RankRelativeTolerance)|| ...
            options.RankRelativeTolerance<=0||options.RankRelativeTolerance>=1
        error('design_study:finite_difference_jacobian:InvalidRankTolerance', ...
            'RankRelativeTolerance must lie in (0,1).');
    end
    if ~isscalar(options.SymmetryTolerance)|| ...
            ~isfinite(options.SymmetryTolerance)||options.SymmetryTolerance<0
        error('design_study:finite_difference_jacobian:InvalidSymmetryTolerance', ...
            'SymmetryTolerance must be a nonnegative finite scalar.');
    end
    if options.PrimaryStepOnly
        if ~isempty(options.OutputCovariance)
            error('design_study:finite_difference_jacobian:PrimaryStepCovariance', ...
                ['PrimaryStepOnly returns the raw Jacobian for later reuse ' ...
                 'with point-specific covariance cases. OutputCovariance ' ...
                 'must therefore be empty.']);
        end
        if ~isempty(options.CenterValues)&&(~isnumeric(options.CenterValues)|| ...
                ~ismatrix(options.CenterValues)|| ...
                any(~isfinite(options.CenterValues),'all'))
            error('design_study:finite_difference_jacobian:InvalidCenterValues', ...
                'CenterValues must be empty or a finite numeric matrix.');
        end
    elseif ~isempty(options.CenterValues)
        error('design_study:finite_difference_jacobian:UnusedCenterValues', ...
            'CenterValues may be supplied only when PrimaryStepOnly is true.');
    end
end

function result = primary_step_only_jacobian(fun,u,h,suppliedCenter)
%PRIMARY_STEP_ONLY_JACOBIAN Vectorized form of the established primary stencil.
%   Perturbation rows are ordered as lower/upper N-row blocks for parameter
%   1, then lower/upper blocks for parameter 2, and so on. Invalid one-sided
%   directions repeat the center coordinate, keeping the evaluation contract
%   at exactly 2*M perturbation rows per point without changing the derivative.

    u=double(u);
    if isvector(u)&&size(u,1)>1&&size(u,2)==1
        % In batched mode an N-by-1 input means N one-parameter points.
        u=reshape(u,[],1);
    end
    nPoint=size(u,1);nParameter=size(u,2);
    centerSupplied=~isempty(suppliedCenter);
    if centerSupplied
        center=batch_output(suppliedCenter,nPoint,'supplied center');
        centerRowsEvaluated=0;centerForwardCallCount=0;
    else
        center=batch_output(fun(u),nPoint,'center');
        centerRowsEvaluated=nPoint;centerForwardCallCount=1;
    end
    nOutput=size(center,2);

    perturbationCoordinates=zeros(2*nParameter*nPoint,nParameter);
    stencilCodes=strings(nPoint,nParameter);
    stencilNumericCodes=zeros(nPoint,nParameter);
    blockLabels=strings(2*nParameter,1);
    for parameterIndex=1:nParameter
        lowerRows=(2*parameterIndex-2)*nPoint+(1:nPoint);
        upperRows=(2*parameterIndex-1)*nPoint+(1:nPoint);
        lower=u;upper=u;
        central=u(:,parameterIndex)-h>=0&u(:,parameterIndex)+h<=1;
        forward=~central&u(:,parameterIndex)+h<=1;
        backward=~central&~forward;
        lower(central|backward,parameterIndex)= ...
            u(central|backward,parameterIndex)-h;
        upper(central|forward,parameterIndex)= ...
            u(central|forward,parameterIndex)+h;
        perturbationCoordinates(lowerRows,:)=lower;
        perturbationCoordinates(upperRows,:)=upper;
        stencilCodes(central,parameterIndex)="central";
        stencilCodes(forward,parameterIndex)="forward";
        stencilCodes(backward,parameterIndex)="backward";
        stencilNumericCodes(forward,parameterIndex)=1;
        stencilNumericCodes(backward,parameterIndex)=-1;
        blockLabels(2*parameterIndex-1)= ...
            "parameter_"+parameterIndex+"_lower";
        blockLabels(2*parameterIndex)= ...
            "parameter_"+parameterIndex+"_upper";
    end
    assert(all(perturbationCoordinates>=0&perturbationCoordinates<=1,'all'), ...
        'design_study:finite_difference_jacobian:PrimaryStepBounds', ...
        'The boundary-safe perturbation coordinates left the unit box.');

    perturbed=batch_output(fun(perturbationCoordinates), ...
        2*nParameter*nPoint,'perturbation');
    assert(size(perturbed,2)==nOutput, ...
        'design_study:finite_difference_jacobian:InvalidForwardOutput', ...
        'Center and perturbation output dimensions differ.');
    matrixByPoint=zeros(nOutput,nParameter,nPoint);
    for parameterIndex=1:nParameter
        lowerRows=(2*parameterIndex-2)*nPoint+(1:nPoint);
        upperRows=(2*parameterIndex-1)*nPoint+(1:nPoint);
        lower=perturbed(lowerRows,:);upper=perturbed(upperRows,:);
        derivative=zeros(nPoint,nOutput);
        central=stencilNumericCodes(:,parameterIndex)==0;
        forward=stencilNumericCodes(:,parameterIndex)==1;
        backward=stencilNumericCodes(:,parameterIndex)==-1;
        derivative(central,:)=(upper(central,:)-lower(central,:))/(2*h);
        derivative(forward,:)=(upper(forward,:)-center(forward,:))/h;
        derivative(backward,:)=(center(backward,:)-lower(backward,:))/h;
        matrixByPoint(:,parameterIndex,:)=permute(derivative,[2 3 1]);
    end

    if nPoint==1
        scalarMatrix=matrixByPoint(:,:,1);
    else
        scalarMatrix=[];
    end
    perturbationRowsEvaluated=2*nParameter*nPoint;
    result=struct( ...
        'matrix',scalarMatrix, ...
        'rawMatrix',scalarMatrix, ...
        'matrixByPoint',matrixByPoint, ...
        'rawMatrixByPoint',matrixByPoint, ...
        'steps',h, ...
        'stepMatrices',{{matrixByPoint}}, ...
        'rawStepMatrices',{{matrixByPoint}}, ...
        'parameterCoordinates',u, ...
        'parameterCoordinateSystem','normalized_unit_box', ...
        'primaryStepOnly',true, ...
        'centerValues',center, ...
        'centerValuesSupplied',centerSupplied, ...
        'stencilCodeByPoint',stencilCodes, ...
        'centralOrOneSidedByPoint',stencilCodes, ...
        'stencilNumericCodeByPoint',stencilNumericCodes, ...
        'stencilNumericCodeDefinition',struct( ...
            'central',0,'forward',1,'backward',-1), ...
        'perturbationBlockOrder',blockLabels, ...
        'nPoints',nPoint, ...
        'nParameters',nParameter, ...
        'nOutputs',nOutput, ...
        'centerRowsEvaluated',centerRowsEvaluated, ...
        'perturbationRowsEvaluated',perturbationRowsEvaluated, ...
        'perturbationRowsPerPoint',2*nParameter, ...
        'totalForwardRowsEvaluated', ...
            centerRowsEvaluated+perturbationRowsEvaluated, ...
        'totalForwardRowsPerPoint',2*nParameter+double(~centerSupplied), ...
        'centerForwardCallCount',centerForwardCallCount, ...
        'perturbationForwardCallCount',1, ...
        'totalForwardCallCount',centerForwardCallCount+1, ...
        'boundaryHandlingPolicy', ...
            'central_else_forward_else_backward_unit_box_v1');
end

function value=batch_output(value,nExpectedRows,label)
    if nExpectedRows==1&&isnumeric(value)&&isvector(value)&&~isempty(value)
        value=reshape(value,1,[]);
    end
    if ~isnumeric(value)||~ismatrix(value)||isempty(value)|| ...
            size(value,1)~=nExpectedRows||any(~isfinite(value),'all')
        error('design_study:finite_difference_jacobian:InvalidForwardOutput', ...
            'The %s output must be a finite %d-row numeric matrix.', ...
            label,nExpectedRows);
    end
    value=double(value);
end

function [weighted,covariance,lowerFactor,method] = ...
        whiten(raw,covariance,nOutput,symmetryTolerance)
    if isempty(covariance)
        covariance = eye(nOutput);
        lowerFactor = eye(nOutput);
        weighted = raw;
        method = 'identity';
        return;
    end
    if ~isnumeric(covariance)||~ismatrix(covariance)|| ...
            ~isequal(size(covariance),[nOutput nOutput])|| ...
            any(~isfinite(covariance(:)))
        error('design_study:finite_difference_jacobian:InvalidCovariance', ...
            'OutputCovariance must be a finite %d-by-%d matrix.',nOutput,nOutput);
    end
    scale = max(norm(covariance,'fro'),eps);
    symmetryError = norm(covariance-covariance.','fro')/scale;
    if symmetryError>symmetryTolerance
        error('design_study:finite_difference_jacobian:NonSymmetricCovariance', ...
            'OutputCovariance relative symmetry error %.3g exceeds %.3g.', ...
            symmetryError,symmetryTolerance);
    end
    covariance = (covariance+covariance.')/2;
    [lowerFactor,cholFlag] = chol(covariance,'lower');
    if cholFlag~=0
        error('design_study:finite_difference_jacobian:NonPositiveDefiniteCovariance', ...
            ['OutputCovariance must be positive definite. No numerical ' ...
             'jitter is added.']);
    end
    weighted = cell(size(raw));
    for i=1:numel(raw), weighted{i}=lowerFactor\raw{i}; end
    method = 'lower_cholesky_left_solve';
end

function difference = relative_step_difference(matrices)
    central = matrices{2};
    difference = [norm(matrices{1}-central,'fro'), ...
        norm(matrices{3}-central,'fro')]/max(norm(central,'fro'),eps);
end

function matrix = one_jacobian(fun,u,h)
    center = column(fun(u));
    validate_output(center,numel(center));
    matrix = zeros(numel(center),numel(u));
    for j=1:numel(u)
        if u(j)-h>=0 && u(j)+h<=1
            lower=u; upper=u; lower(j)=lower(j)-h; upper(j)=upper(j)+h;
            forward=column(fun(upper)); backward=column(fun(lower));
            validate_output(forward,numel(center));
            validate_output(backward,numel(center));
            matrix(:,j)=(forward-backward)/(2*h);
        elseif u(j)+h<=1
            upper=u; upper(j)=upper(j)+h; forward=column(fun(upper));
            validate_output(forward,numel(center));
            matrix(:,j)=(forward-center)/h;
        else
            lower=u; lower(j)=lower(j)-h; backward=column(fun(lower));
            validate_output(backward,numel(center));
            matrix(:,j)=(center-backward)/h;
        end
    end
end

function validate_output(value,nExpected)
    if isempty(value)||numel(value)~=nExpected||any(~isfinite(value))
        error('design_study:finite_difference_jacobian:InvalidForwardOutput', ...
            'The forward function output size and finiteness must be stable.');
    end
end

function value = column(value)
    value=value(:);
end
