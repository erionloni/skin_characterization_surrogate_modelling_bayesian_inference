function scales = reconstruction_feature_scales( ...
        truthRawPressures,caseIDs,varargin)
%RECONSTRUCTION_FEATURE_SCALES Complete external-test-cohort feature ranges.
%   SCALES uses the realized complete external-test cohort. Each unique
%   scalar feature receives one truth-range scale shared by all fitting
%   designs and scenarios.  Numerically near-zero ranges remain explicit and
%   do not receive an artificial denominator floor.
%   SCALES = recovery.reconstruction_feature_scales(TRUTHRAWPRESSURES,
%   CASEIDS, ...) returns one row per scalar feature: its scale, whether a
%   normalized metric is available and why not, and the cases it is based
%   on.
%   Options (name-value): 'DenominatorFloor' (1e-12), 'ExpectedCaseCount'
%   (checked when given) and 'NearZeroAbsoluteTolerance' and
%   'NearZeroRelativeTolerance' (1e-12 each: a scale below them is treated as
%   zero, so no normalized metric is reported).
%   Side effects: none.

    parser=inputParser;
    parser.FunctionName='recovery.reconstruction_feature_scales';
    addParameter(parser,'DenominatorFloor',1e-12,@positive_scalar);
    addParameter(parser,'ExpectedCaseCount',[], ...
        @(x)isempty(x)||positive_integer(x));
    addParameter(parser,'NearZeroAbsoluteTolerance',1e-12,@nonnegative_scalar);
    addParameter(parser,'NearZeroRelativeTolerance',1e-12,@nonnegative_scalar);
    parse(parser,varargin{:});
    expectedCount=parser.Results.ExpectedCaseCount;
    if isempty(expectedCount),expectedCount=size(truthRawPressures,1);end
    expectedCount=double(expectedCount);
    assert(isnumeric(truthRawPressures)&&isreal(truthRawPressures)&& ...
        isequal(size(truthRawPressures),[expectedCount 6])&& ...
        all(isfinite(truthRawPressures),'all'), ...
        'recovery:reconstruction_feature_scales:TruthShape', ...
        'Truth pressures must be a finite expected-case-count-by-6 matrix.');
    caseIDs=reshape(double(caseIDs),[],1);
    assert(numel(caseIDs)==expectedCount&&all(isfinite(caseIDs))&& ...
        numel(unique(caseIDs))==expectedCount, ...
        'recovery:reconstruction_feature_scales:CaseIDs', ...
        'The normalization cohort requires unique finite CaseIDs.');

    registry=recovery.reconstruction_feature_registry();
    flat=registry.scalarFeatures;
    uniqueIDs=unique(flat.FeatureID,'stable');n=numel(uniqueIDs);
    [truthMinimum,truthMaximum,featureScale,nearZeroThreshold]= ...
        deal(nan(n,1));
    [scalarFeature,featureFamily,units,formula,evaluationSpaces, ...
        normalizationUnavailableReason]=deal(strings(n,1));
    normalizedMetricAvailable=false(n,1);
    featureValues=cell(n,1);

    for s=1:numel(registry.spaces)
        space=registry.spaces(s);
        values=recovery.reconstruction_feature_values( ...
            truthRawPressures,space.id,'DenominatorFloor', ...
            parser.Results.DenominatorFloor);
        for j=1:space.featureCount
            featureID=string(space.featureIDs{j});
            index=find(uniqueIDs==featureID);
            assert(isscalar(index), ...
                'recovery:reconstruction_feature_scales:FeatureBinding', ...
                'Feature %s must occur once among the scaled features.',featureID);
            if isempty(featureValues{index})
                featureValues{index}=values(:,j);
            else
                difference=max(abs(featureValues{index}-values(:,j)));
                tolerance=10*eps(max(1,max(abs(featureValues{index}))));
                assert(difference<=tolerance, ...
                    'recovery:reconstruction_feature_scales:DuplicateFormula', ...
                    ['Feature %s appears in multiple spaces with inconsistent ' ...
                     'truth values.'],featureID);
            end
        end
    end

    for i=1:n
        rows=flat.FeatureID==uniqueIDs(i);
        assert(~isempty(featureValues{i})&&any(rows), ...
            'recovery:reconstruction_feature_scales:MissingFeature', ...
            'Feature %s has no values to scale.',uniqueIDs(i));
        values=featureValues{i};truthMinimum(i)=min(values);
        truthMaximum(i)=max(values);
        featureScale(i)=truthMaximum(i)-truthMinimum(i);
        reference=max(1,max(abs(values)));
        nearZeroThreshold(i)= ...
            double(parser.Results.NearZeroAbsoluteTolerance)+ ...
            double(parser.Results.NearZeroRelativeTolerance)*reference;
        normalizedMetricAvailable(i)=featureScale(i)>nearZeroThreshold(i);
        if ~normalizedMetricAvailable(i)
            normalizationUnavailableReason(i)= ...
                "truth_range_numerically_near_zero";
        end
        first=find(rows,1);
        scalarFeature(i)=flat.ScalarFeature(first);
        featureFamily(i)=flat.FeatureFamily(first);
        units(i)=flat.Units(first);formula(i)=flat.Formula(first);
        evaluationSpaces(i)=strjoin(unique(flat.EvaluationSpace(rows), ...
            'stable'),';');
    end

    validationCaseCount=repmat(expectedCount,n,1);
    validationCaseIDs=repmat(strjoin(string(caseIDs.'),','),n,1);
    scales=table(uniqueIDs,scalarFeature,featureFamily,units,formula, ...
        evaluationSpaces,truthMinimum,truthMaximum,featureScale, ...
        normalizedMetricAvailable,normalizationUnavailableReason, ...
        nearZeroThreshold,validationCaseCount,validationCaseIDs, ...
        'VariableNames',{'FeatureID','ScalarFeature','FeatureFamily', ...
        'Units','Formula','EvaluationSpaces','TruthMinimum','TruthMaximum', ...
        'FeatureScale','NormalizedMetricAvailable', ...
        'NormalizationUnavailableReason','NearZeroThreshold', ...
        'ValidationCaseCount','ValidationCaseIDs'});
end

function tf=positive_scalar(value)
    tf=isnumeric(value)&&isreal(value)&&isscalar(value)&& ...
        isfinite(value)&&value>0;
end

function tf=nonnegative_scalar(value)
    tf=isnumeric(value)&&isreal(value)&&isscalar(value)&& ...
        isfinite(value)&&value>=0;
end

function tf=positive_integer(value)
    tf=positive_scalar(value)&&value==round(value);
end
