function design = get_design(provider,design)
%GET_DESIGN A design of the provider, by name or record.
%   DESIGN = design_study.get_design(PROVIDER, DESIGN) returns the design
%   of PROVIDER.designs named DESIGN, or, for a design record DESIGN, the
%   provider's design of the same name.
%   Side effects: none.
    if ischar(design) || (isstring(design) && isscalar(design))
        name = char(string(design));
    else
        assert(isstruct(design) && isscalar(design) && isfield(design,'name'), ...
            'design_study:get_design:InvalidDesign', ...
            'Design must be a provider design name or scalar design struct.');
        name = design.name;
    end
    hit = find(strcmp({provider.designs.name},name),1);
    assert(~isempty(hit),'design_study:get_design:UnknownDesign', ...
        'Unknown observation design "%s".',name);
    design = provider.designs(hit);
end
