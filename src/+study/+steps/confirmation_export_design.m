function confirmation_export_design(cfg, ~)
%CONFIRMATION_EXPORT_DESIGN Step 'export_design': the confirmation design for the COMSOL simulations.
%   study.steps.confirmation_export_design(CFG, STEPSINCALL) builds the
%   design of the settings (B.7: the materials, CaseIDs of the fixed
%   dataset whose values are the truths, and the protocols;
%   confirmation.confirmation_design) and writes it to
%   <run>/generalized/06_confirmation/data/design (CFG.native.designRoot):
%     materials.csv, protocols.csv, design_rows.csv  the design
%     probe_solves.csv   the COMSOL run list: one D2 and one D6 solve per
%                        design row, with its inputs as exact doubles
%                        (confirmation.export_confirmation_design)
%     design_predictions.csv  the protocol screen's proxy of the design's
%                        protocols at the screen's material points, with all
%                        six pressures and in the confirmation's observation
%                        designs (B.7 design and completePairsDesign; the six
%                        objectives, confirmation.design_predictions)
%   The thesis settings give the design of the thesis's COMSOL campaign (20
%   materials x 4 protocols, 160 solves).
%   CFG comes from study.native_config.
%   Computation: about two minutes (the approved GP at the screen's material
%   points; no COMSOL, no sampler).
%   Side effects: writes the outputs above below the run folder.

    design = confirmation.confirmation_design(cfg);
    confirmation.export_confirmation_design(design, cfg.native.designRoot);
    utils.atomic_write_table(fullfile(cfg.native.designRoot, 'design_predictions.csv'), ...
        confirmation.design_predictions(cfg, study.screening_provider(cfg), design));
end
