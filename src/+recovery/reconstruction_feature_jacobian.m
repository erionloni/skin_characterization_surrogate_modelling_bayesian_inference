function [jacobian,metadata] = reconstruction_feature_jacobian( ...
        rawPressure,evaluationSpace,varargin)
%RECONSTRUCTION_FEATURE_JACOBIAN Analytic Jacobian of one response space.
%   J = recovery.reconstruction_feature_jacobian(Y,SPACE) returns the
%   feature-by-pressure Jacobian at one finite 1-by-6 pressure vector in the
%   canonical order [p1_D2 p2_D2 p3_D2 p1_D6 p2_D6 p3_D6]. The definition
%   follows recovery.reconstruction_feature_registry exactly and is intended
%   for deterministic delta-method covariance propagation.
%   METADATA records the evaluation space, the evaluation point and the
%   denominator floor.
%   Option (name-value): 'DenominatorFloor' (default 1e-12), the smallest
%   admissible denominator of a ratio feature.
%   Side effects: none.

    parser=inputParser;
    parser.FunctionName='recovery.reconstruction_feature_jacobian';
    addParameter(parser,'DenominatorFloor',1e-12,@valid_floor);
    parse(parser,varargin{:});
    denominatorFloor=double(parser.Results.DenominatorFloor);
    y=reshape(double(rawPressure),1,[]);
    assert(isnumeric(rawPressure)&&isreal(rawPressure)&&numel(y)==6&& ...
        all(isfinite(y)), ...
        'recovery:reconstruction_feature_jacobian:RawPressureShape', ...
        'Raw pressure must be one finite real six-element vector.');

    % Calling the canonical transform first applies its identical denominator
    % policy and also verifies that this evaluation point is usable.
    [~,valueMetadata]=recovery.reconstruction_feature_values( ...
        y,evaluationSpace,'DenominatorFloor',denominatorFloor);
    space=char(string(evaluationSpace));
    jacobian=zeros(valueMetadata.featureCount,6);
    switch space
        case 'all_six'
            jacobian=eye(6);
        case 'd2_only'
            jacobian(:,1:3)=eye(3);
        case 'd6_only'
            jacobian(:,4:6)=eye(3);
        case 'cycle_1_only'
            jacobian(1,1)=1;jacobian(2,4)=1;
        case 'ratios_only'
            jacobian(1,[1 2])=[-y(2)/y(1)^2 1/y(1)];
            jacobian(2,[1 3])=[-y(3)/y(1)^2 1/y(1)];
            jacobian(3,[4 5])=[-y(5)/y(4)^2 1/y(4)];
            jacobian(4,[4 6])=[-y(6)/y(4)^2 1/y(4)];
        case 'physics_guided_full_rank_six'
            jacobian(1,3)=1;
            jacobian(2,[1 3])=[-y(3)/y(1)^2 1/y(1)];
            jacobian(3,[1 2])=[1 -1];
            jacobian(4,[1 6])=[1/y(6) -y(1)/y(6)^2];
            jacobian(5,[4 6])=[-y(6)/y(4)^2 1/y(4)];
            jacobian(6,[4 5])=[-y(5)/y(4)^2 1/y(4)];
        case 'within_probe_drops'
            jacobian(1,[1 2])=[1 -1];
            jacobian(2,[1 3])=[1 -1];
            jacobian(3,[2 3])=[1 -1];
            jacobian(4,[4 5])=[1 -1];
            jacobian(5,[4 6])=[1 -1];
            jacobian(6,[5 6])=[1 -1];
        case 'cross_probe_ratios'
            cursor=0;
            for i=1:3
                for k=4:6
                    cursor=cursor+1;
                    jacobian(cursor,i)=1/y(k);
                    jacobian(cursor,k)=-y(i)/y(k)^2;
                end
            end
        case 'cross_probe_differences'
            cursor=0;
            for i=1:3
                for k=4:6
                    cursor=cursor+1;
                    jacobian(cursor,i)=1;
                    jacobian(cursor,k)=-1;
                end
            end
        otherwise
            error('recovery:reconstruction_feature_jacobian:UnsupportedSpace', ...
                'Unsupported reconstruction evaluation space "%s".',space);
    end
    assert(isequal(size(jacobian),[valueMetadata.featureCount 6])&& ...
        all(isfinite(jacobian),'all'), ...
        'recovery:reconstruction_feature_jacobian:InvalidJacobian', ...
        'The analytic feature Jacobian is nonfinite or has invalid dimensions.');
    metadata=struct( ...
        'schemaVersion','reconstruction_feature_jacobian_v1', ...
        'evaluationSpace',space, ...
        'featureCount',valueMetadata.featureCount, ...
        'rawOutputCount',6, ...
        'featureIDs',{valueMetadata.featureIDs}, ...
        'rawOutputOrder',{{'p1_D2','p2_D2','p3_D2', ...
            'p1_D6','p2_D6','p3_D6'}}, ...
        'method','analytic_delta_method_jacobian', ...
        'evaluationPoint','saved_GP_mean_at_truth', ...
        'denominatorFloor',denominatorFloor);
end

function tf=valid_floor(value)
    tf=isnumeric(value)&&isreal(value)&&isscalar(value)&& ...
        isfinite(value)&&value>0;
end
