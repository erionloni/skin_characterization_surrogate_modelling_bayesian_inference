function value = design_semantics(name)
%DESIGN_SEMANTICS The mathematical meaning of each design of the design study.
%   These labels distinguish output subsetting/transformation from the
%   full-rank representation parity check. They deliberately do not encode
%   physical deployability, acquisition burden, or protocol duration.
%
%   VALUE = design_study.design_semantics(NAME) returns, for the design NAME,
%   its role, comparison class, reference design (all_six) and information
%   claim.
%   Side effects: none.

    name=char(string(name));
    switch name
        case 'all_six'
            role='raw_full_reference';
            comparison='reference';
            claim=['Raw six-pressure reference. This is the comparison ' ...
                'baseline, not a claim of physical protocol optimality.'];
        case {'d2_only','d6_only','cycle_1_only'}
            role='raw_output_subset_experiment';
            comparison='information_subsetting';
            claim=['Reduced mathematical subset of the six available ' ...
                'pressure outputs.'];
        case 'ratios_only'
            role='reduced_transformed_output_experiment';
            comparison='information_subsetting_and_transformation';
            claim=['Four-dimensional ratio transform of the six available ' ...
                'pressure outputs; it is not new measurement information.'];
        case 'physics_guided_full_rank_six'
            role='full_rank_representation_parity';
            comparison='representation_parity_with_all_six';
            claim=['Invertible six-dimensional representation of the same ' ...
                'six pressures. It creates no new experimental information.'];
        otherwise
            error('design_study:design_semantics:UnknownDesign', ...
                'Unknown active design "%s".',name);
    end
    value=struct('design',name,'role',role, ...
        'comparison_class',comparison,'reference_design','all_six', ...
        'information_claim',claim);
end
