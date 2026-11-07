function report = run_generalized_study(varargin)
%RUN_GENERALIZED_STUDY Generalized study: 4 material + 3 protocol inputs -> 6 pressures.
%   run_generalized_study() renders the generalized-route figures and tables
%   from the shipped results, the protocol screening and the confirmation
%   included (Mode 'reproduce', the default).
%   run_generalized_study('Mode','rerun') recomputes the steps whose run
%   switch is true (study_settings.m, section 0.2; thesis: all, which needs
%   'ConfirmExpensive' and the reviewed COMSOL observations); 'Steps',{...}
%   names the steps of one call instead.
%   run_generalized_study(...,'Plan',true) only prints what would run.
%
%   Steps, in dependency order (switches s.run.generalized.<step>):
%     dataset                      939 cases -> 857 development / 82 external
%     surrogates                   (expensive) refit of the approved
%                                  Matern-3/2 surrogates (gamma 0.48225)
%     surrogate_assessment         predictions of the 82 held-out cases
%     default_protocol_comparison  surrogate at the default protocol vs fixed COMSOL
%     sensitivity                  Sobol sensitivity to material and protocol inputs
%     surrogate_audit              the 1,050-fit audit (shipped evidence; not rerun)
%   Protocol screening:
%     screen                       (expensive) local Fisher information of 730
%                                  protocols over 1,000 material states (about 1 h)
%     objective_supplement         full covariance for the six design objectives
%     rankings                     protocol rankings; primary objective
%                                  mean(lambda_max(Cq)) of the weak parameter pair
%   Confirmation (the design is that of the settings, B.7):
%     export_design                write the design and its COMSOL run list
%     import_observations          join the reviewed COMSOL observations to the
%                                  design by their values and accept them
%     prepare                      prepare one inverse cell per material and
%                                  protocol (thesis: 80)
%     run_cells                    (expensive, cluster) AIES inversion of the cells
%     compare                      paired comparisons with the shared reference
%                                  protocol (thesis: 60)
%     figures                      all generalized-route figures and tables
%
%   What the confirmation steps of a rerun read ('Mode','rerun'):
%     'ConfirmationObservationFiles'  import_observations: a folder with
%                                     reviewed_export.csv (one row per COMSOL
%                                     solve), source_provenance.json and
%                                     direct_data_acceptance.json
%     'ConfirmationCells'             run_cells: 'all' or task indices, e.g.
%                                     one cluster job per cell
%   The accepted observations and the campaign stay in the run folder;
%   prepare reads the run's observations, or else the accepted table of the
%   setting generalized.confirmation.observations.
%
%   Other options: see study_settings.m and study.resolve_settings.
%   Output: <output folder>/<run name>/, with run_record.json (the calls,
%   settings and completed steps).
%
%   Examples:
%     run_generalized_study('Mode','rerun','Steps',{'sensitivity'},'Plan',true)
%     run_generalized_study('Mode','rerun','Steps',{'screen','objective_supplement','rankings'}, ...
%         'Scale','example')
%
%   Side effects: changes the MATLAB path (src/; config/ and UQLab as the
%   steps need them); writes the run folder; rerun mode starts UQLab.
%   Computation: reproduce mode minutes; rerun costs per step ('Plan',true).

    addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));
    report = study.run('generalized', varargin{:});
end
