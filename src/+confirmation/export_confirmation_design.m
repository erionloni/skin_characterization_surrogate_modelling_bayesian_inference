function export_confirmation_design(design,root)
%EXPORT_CONFIRMATION_DESIGN The confirmation design and its COMSOL run list, for the simulations.
%   confirmation.export_confirmation_design(DESIGN, ROOT) writes the design
%   DESIGN (confirmation.confirmation_design) to the folder ROOT:
%     materials.csv     the materials: CaseID and truth values;
%     protocols.csv     the protocols: label, role, the objective it
%                       targets, signed rate, magnitude, log10 of the
%                       magnitude, hold and pause;
%     design_rows.csv   one row per material and protocol, in design order;
%     probe_solves.csv  the COMSOL run list: one D2 and one D6 solve per
%                       design row, with its RunID and COMSOL inputs.
%   Every double is written with 17 significant digits
%   (utils.atomic_write_exact_table): the COMSOL inputs are exact, and the
%   observations of a solve join the design by these values. It creates no
%   observations and no inverse cells.
%   Side effects: writes ROOT (refused when it holds a design already).
%   Computation: seconds.
    assert(~isfile(fullfile(root,'design_rows.csv')), ...
        'confirmation:export_confirmation_design:Exists', ...
        'A confirmation design exists in %s already; export into a new folder.',root);
    if ~isfolder(root),mkdir(root);end
    utils.atomic_write_exact_table(fullfile(root,'materials.csv'),design.materials);
    utils.atomic_write_exact_table(fullfile(root,'protocols.csv'),design.protocols);
    utils.atomic_write_exact_table(fullfile(root,'design_rows.csv'),design.rows);
    utils.atomic_write_exact_table(fullfile(root,'probe_solves.csv'),design.solves);
end
