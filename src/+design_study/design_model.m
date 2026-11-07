function model = design_model(provider,caseIndex,design)
%DESIGN_MODEL The forward map and observation covariance of one case and design.
%   MODEL = design_study.design_model(PROVIDER, CASEINDEX, DESIGN) returns,
%   for the case CASEINDEX of the provider (design_study provider:
%   recovery.design_study_provider), MODEL.forward: unit-box parameters to
%   the design's observations (the selected pressures, the four cycle
%   ratios or the physics-guided full-rank coordinates), MODEL.covariance:
%   the design's local observation covariance, and the design and case ID.
%   Side effects: none.
    design = design_study.get_design(provider,design);
    rawForward = @(u) provider.forward_evaluator(caseIndex,u);
    switch design.type
        case 'raw'
            model.forward = @(u) select(rawForward(u),design.indices);
        case 'ratio'
            model.forward = @(u) ratio_value(rawForward(u), ...
                provider.transform_options.ratio_denominator_floor);
        case 'transformed_full_rank'
            model.forward = @(u) physics_guided_value(rawForward(u), ...
                provider.transform_options.physics_guided_denominator_floor);
        otherwise
            error('design_study:design_model:UnsupportedTransform', ...
                'Unsupported design transform "%s".',design.type);
    end
    model.covariance = provider.observation_covariance_provider( ...
        caseIndex,design);
    model.design = design;
    model.case_id = provider.case_ids{caseIndex};
end

function value = select(y,indices)
    y = y(:);
    value = y(indices);
end

function value = ratio_value(y,floorValue)
    value = design_study.ratio_transform(y,[],floorValue);
end

function value = physics_guided_value(y,floorValue)
    value=inversion.physics_guided_full_rank_values( ...
        reshape(y,1,6),floorValue).';
end
