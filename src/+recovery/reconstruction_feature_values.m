function [values,metadata] = reconstruction_feature_values( ...
        rawPressures,evaluationSpace,varargin)
%RECONSTRUCTION_FEATURE_VALUES Transform raw pressures sample by sample.
%   VALUES = recovery.reconstruction_feature_values(Y,SPACE) accepts one
%   finite N-by-6 matrix in canonical pressure order.  Nonlinear transforms
%   are applied to every row before any posterior summary is calculated.
%   [VALUES, METADATA] = ... returns the N-by-F feature values and the
%   transform's record.
%   Option (name-value): 'DenominatorFloor' (default 1e-12), the smallest
%   admissible denominator of a ratio feature.
%   Side effects: none.

    parser=inputParser;
    parser.FunctionName='recovery.reconstruction_feature_values';
    addParameter(parser,'DenominatorFloor',1e-12,@valid_floor);
    parse(parser,varargin{:});
    floorValue=double(parser.Results.DenominatorFloor);
    assert(isnumeric(rawPressures)&&isreal(rawPressures)&& ...
        ismatrix(rawPressures)&&size(rawPressures,2)==6&& ...
        ~isempty(rawPressures)&&all(isfinite(rawPressures),'all'), ...
        'recovery:reconstruction_feature_values:RawPressureShape', ...
        'Raw pressures must be one nonempty finite real N-by-6 matrix.');

    % The registry is immutable within one MATLAB session. Rebuilding it for
    % every case/space would dominate this otherwise cheap sample-wise
    % transform, especially for explicit missing-cell rows.
    persistent cachedRegistry
    if isempty(cachedRegistry)
        cachedRegistry=recovery.reconstruction_feature_registry();
    end
    registry=cachedRegistry;
    spaceName=char(string(evaluationSpace));
    hit=find(strcmp({registry.spaces.id},spaceName));
    assert(isscalar(hit), ...
        'recovery:reconstruction_feature_values:UnknownSpace', ...
        'Unknown reconstruction evaluation space "%s".',spaceName);
    space=registry.spaces(hit);

    switch spaceName
        case {'all_six','d2_only','d6_only','cycle_1_only'}
            design=inversion.design_registry(spaceName);
            values=rawPressures(:,design.outputIndices);
        case 'ratios_only'
            values=design_study.ratio_values(rawPressures,floorValue);
        case 'physics_guided_full_rank_six'
            values=inversion.physics_guided_full_rank_values( ...
                rawPressures,floorValue);
        case 'within_probe_drops'
            values=[rawPressures(:,1)-rawPressures(:,2), ...
                rawPressures(:,1)-rawPressures(:,3), ...
                rawPressures(:,2)-rawPressures(:,3), ...
                rawPressures(:,4)-rawPressures(:,5), ...
                rawPressures(:,4)-rawPressures(:,6), ...
                rawPressures(:,5)-rawPressures(:,6)];
        case 'cross_probe_ratios'
            denominators=rawPressures(:,4:6);
            assert(all(abs(denominators)>floorValue,'all'), ...
                'recovery:reconstruction_feature_values:UnsafeDenominator', ...
                ['Every D6 denominator for cross-probe ratios must have ' ...
                 'absolute magnitude above the configured floor.']);
            values=zeros(size(rawPressures,1),9);cursor=0;
            for i=1:3
                for j=1:3
                    cursor=cursor+1;
                    values(:,cursor)=rawPressures(:,i)./rawPressures(:,j+3);
                end
            end
        case 'cross_probe_differences'
            values=zeros(size(rawPressures,1),9);cursor=0;
            for i=1:3
                for j=1:3
                    cursor=cursor+1;
                    values(:,cursor)=rawPressures(:,i)-rawPressures(:,j+3);
                end
            end
        otherwise
            error('recovery:reconstruction_feature_values:UnsupportedSpace', ...
                'Unsupported reconstruction evaluation space "%s".',spaceName);
    end
    assert(isequal(size(values),[size(rawPressures,1) space.featureCount])&& ...
        all(isfinite(values),'all'), ...
        'recovery:reconstruction_feature_values:TransformedShape', ...
        'The feature transform produced invalid or nonfinite values.');
    metadata=struct( ...
        'schemaVersion','posterior_feature_values_v1', ...
        'evaluationSpace',space.id, ...
        'evaluationClass',space.evaluationClass, ...
        'featureIDs',{space.featureIDs}, ...
        'featureCount',space.featureCount, ...
        'sampleCount',size(rawPressures,1), ...
        'denominatorFloor',floorValue, ...
        'sampleWiseTransformApplied',true);
end

function tf=valid_floor(value)
    tf=isnumeric(value)&&isreal(value)&&isscalar(value)&& ...
        isfinite(value)&&value>0;
end
