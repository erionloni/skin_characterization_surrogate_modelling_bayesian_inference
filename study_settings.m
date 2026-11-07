function s = study_settings()
%STUDY_SETTINGS Every setting of both routes and all steps: the one file you edit.
%   S = STUDY_SETTINGS() returns the settings that every entry point reads
%   (run_fixed_study, run_generalized_study, run_all_studies,
%   reproduce_thesis_results, check_installation).
%
%   THIS FILE IS THE THESIS CONFIGURATION: every value below is the value
%   the thesis used. Change a value to compute new results; the run record
%   of every run (<run>/run_record.json) keeps the complete settings it
%   used. A single call can override a setting without editing this file,
%   for example run_fixed_study('Mode','rerun'), or with 'Settings' (a
%   complete settings struct, e.g. s = study_settings(); change a field;
%   run_fixed_study('Settings',s,...)).
%
%   Every setting is read from here; the code has no hidden defaults. A
%   missing setting stops a run ("setting <name> missing in section
%   <section> of the settings file"), and so does an unknown one (with the
%   closest valid name) or an invalid value. A few settings name what an
%   analysis is defined for (for example the two scenarios the posterior
%   eigen-analysis compares) and accept only that value; the message says
%   so. Large records (seed tables, calibrations, approved models, the
%   confirmation design) stay files in config/ and data/; this file selects
%   them.
%
%   Contents
%     0  General
%        0.1  Paths                           s.paths
%        0.2  What to run                     s.run (the run switches: s.run.fixed,
%                                             s.run.generalized)
%        0.3  Computation                     s.compute
%        0.4  Figures                         s.figures
%        0.5  Messages                        s.logging
%        0.6  Seeds                           s.seeds
%        0.7  Derived features                s.features
%     A  Fixed route (run_fixed_study)
%        A.1  Dataset and parameters          s.fixed.dataset, s.fixed.parameters
%        A.2  Measurement model               s.fixed.measurement
%        A.3  Surrogates                      s.fixed.surrogates
%        A.4  Surrogate audit                 s.fixed.surrogateAudit
%        A.5  Sensitivity                     s.fixed.sensitivity
%        A.6  Inversion                       s.fixed.inversion
%        A.7  Recovery                        s.fixed.recovery
%        A.8  Design study                    s.fixed.designStudy
%        A.9  Conditional inversion           s.fixed.conditionalInversion
%        A.10 Case outputs                    s.fixed.caseOutputs
%        A.11 Ratio-error curves              s.fixed.ratioErrorCurves
%        A.12 Parameter combinations          s.fixed.combinations
%        A.13 GP-mean inversion               s.fixed.gpMeanInversion
%     B  Generalized route (run_generalized_study)
%        B.1  Dataset and parameters          s.generalized.dataset, s.generalized.parameters
%        B.2  Measurement model               s.generalized.measurement
%        B.3  Surrogates                      s.generalized.surrogates
%        B.4  Sensitivity                     s.generalized.sensitivity
%        B.5  Default-protocol comparison     s.generalized.defaultProtocolComparison
%        B.6  Protocol screening              s.generalized.screening
%        B.7  Confirmation                    s.generalized.confirmation
%        B.8  Parameter combinations of the   s.generalized.combinations
%             confirmation
%
%   Selections (cases, scenarios, designs, ...) take a list or the word
%   'all'. Paths are relative to the repository folder unless absolute.
%   (Named study_settings rather than settings: MATLAB already has a
%   built-in function called settings, which a file of the same name would
%   hide.)
%   Side effects: none.

%% ======================================================================
%% 0  GENERAL
%% ======================================================================

%% 0.1 Paths --------------------------------------------------------------

% Folder of your UQLab installation (the folder that contains core/). Text;
% empty: the UQLAB_ROOT environment variable (read once, recorded in the run
% record). The thesis used UQLab 2.3.0. Needed for Mode 'rerun' only.
s.paths.uqlabRoot = '';

% Shipped thesis results, read by Mode 'reproduce' and by reruns for the
% inputs of steps that are not run. Folder. Thesis: 'thesis_results'.
s.paths.results = 'thesis_results';

% Where runs are written: <output>/<run name>/. Folder. Thesis: 'runs'.
s.paths.output = 'runs';

%% 0.2 What to run --------------------------------------------------------

% 'reproduce' draws figures and tables from the shipped results (no model
% fitting, no MCMC, no UQLab); 'rerun' recomputes the requested steps.
% Default: 'reproduce'.
s.run.mode = 'reproduce';

% Name of the run folder under s.paths.output. Text of letters, digits, '.',
% '_' and '-'; empty: automatic, <route>_<UTC time> (all_<UTC time> for
% run_all_studies). Default: ''.
s.run.name = '';

% true: print what would run, what would be reused, the estimated cost and
% whether the call would be refused, then stop without computing anything.
% Default: false.
s.run.plan = false;

% 'thesis': the steps at these settings. 'example' (with Mode 'rerun'): a
% small version of a study in about 10-30 minutes (one inversion cell with
% short MCMC chains; a GP refit limited to 5 optimizer iterations; a screen
% of 7 protocols x 15 material points), labelled as a demonstration in its
% READMEs; never thesis evidence.
s.run.scale = 'thesis';

% Steps that cost hours or need a computing cluster (MCMC campaigns, the
% surrogate audit, refits, the screen) run only when this is true. Their
% cost is printed first. Default: false.
s.run.confirmExpensive = false;

% Which steps, and which analyses inside a step, a call runs: true or false,
% per route. In reproduce mode they choose what is rendered, in rerun mode
% what is computed. A call's 'Steps' overrides the step switches for that
% call; the analysis switches still apply inside its steps. A switched-on
% step runs only when the results it needs exist (computed in the same call,
% in the run folder, or shipped where that is allowed: the plan says which);
% otherwise the call is refused before any computation, naming the switch to
% turn on. Switches choose analyses, never parts of the method: health
% checks, certification and provider selection always apply. Thesis: every
% switch true (the thesis's rerun is expensive; 'Plan',true shows it).
% Fixed route (run_fixed_study):
s.run.fixed.dataset = true;                % the 452 usable cases and their split; about 30 s
s.run.fixed.surrogates = true;             % the six GP and PCE surrogates: the shipped ones with modelSource 'use_shipped' (A.3), else a refit (about 1-2 min)
s.run.fixed.surrogate_assessment = true;   % the 61 external cases predicted (reads held-out outcomes); about 10 s; needs the surrogates
s.run.fixed.surrogate_audit = true;        % kernel, seed and cross-validation audit (development cases only); several hours; needs the surrogates
s.run.fixed.feature_accuracy = true;       % the catalog's features (0.7) from the surrogate means against COMSOL on the 61 external cases (reads held-out outcomes); seconds; needs the assessment
s.run.fixed.sensitivity = true;            % Sobol and ARD sensitivity of the six pressures; about 2 min; needs the surrogates
s.run.fixed.feature_sensitivity = true;    % Sobol indices of the derived features (catalog 0.7) on the sample of the ratio indices; about 1 min; needs the surrogates
s.run.fixed.inversion = true;              % 360 cells x 2 AIES ensembles; a computing cluster; needs the surrogates
s.run.fixed.conditional_inversion = true;  % the conditional inversions of A.9 (A-F: 160 cells, all shipped); a computing cluster; needs the canonical all_six cells (this run's or shipped)
s.run.fixed.recovery = true;               % the five analyses below, on this run's posteriors or the shipped draws
s.run.fixed.coverage_recovery = true;      %   truth inclusion, posterior width and recovery error per cell, and their summaries; minutes
s.run.fixed.eigen_analysis = true;         %   eigen-analysis of the posterior covariances; minutes
s.run.fixed.feature_reconstruction = true; %   the features reconstructed from the posteriors (the GP at every draw); up to about 1 h
s.run.fixed.error_budget = true;           %   the downstream error budget of the reconstruction; needs feature_reconstruction in the same call
s.run.fixed.second_mode_check = true;      %   the second walker group of one cell (A.7; thesis: case 215 gp_self_det all_six): fit, refinement, path, noise, COMSOL neighbours; a few minutes
s.run.fixed.design_study = true;           % Fisher information and posteriors of the six observation designs; about 20 min; needs posteriors (this run's or shipped)
s.run.fixed.ratio_error_curves = true;     % how well the posterior draws reproduce the cycle-to-cycle ratios (A.11); the GP at every draw of 21 cells, about 2 min; needs posteriors (this run's or shipped)
s.run.fixed.combinations = true;           % which parameter combinations the posteriors determine, and the compensation behind them (A.12); about a minute; needs posteriors (this run's or shipped)
s.run.fixed.gp_mean_inversion = true;      % the inversion in the scenario gp_mean_det (A.13: 20 cells x 2 AIES ensembles); a computing cluster; needs the surrogates
s.run.fixed.figures = true;                % (rerun) the figures and tables of this run's results
% Generalized route (run_generalized_study):
s.run.generalized.dataset = true;          % the 939 usable cases and their split; about 1 min
s.run.generalized.surrogates = true;       % the approved GP and PCE: the shipped ones with modelSource 'use_shipped' (B.3), else a refit (about 1.5 h)
s.run.generalized.surrogate_assessment = true; % the 82 external cases predicted (reads held-out outcomes); about 1 min
s.run.generalized.feature_accuracy = true; % the catalog's features (0.7) from the surrogate means against COMSOL on the 82 external cases (reads held-out outcomes); seconds; needs the assessment
s.run.generalized.default_protocol_comparison = true; % the generalized GP at the default protocol against the fixed route's COMSOL results; about 1 min
s.run.generalized.sensitivity = true;      % Sobol sensitivity to the four material and three protocol inputs; about 8 min
s.run.generalized.feature_sensitivity = true; % Sobol indices of the derived features (catalog 0.7) over the seven inputs; about 4 min
s.run.generalized.surrogate_audit = true;  % the 1,050-fit audit: shipped evidence (this version does not rerun it)
s.run.generalized.screen = true;           % local Fisher information of 730 protocols over 1,000 material states; about 1 h
s.run.generalized.objective_supplement = true; % full covariances for the six objectives; about 30 min; needs the screen
s.run.generalized.rankings = true;         % the six-objective rankings; seconds; needs the supplement
s.run.generalized.export_design = true;    % the confirmation design (B.7), its COMSOL run list and the screen's predictions; about 2 min
s.run.generalized.import_observations = true; % the reviewed COMSOL observations (a human decision: 'ConfirmationObservationFiles')
s.run.generalized.prepare = true;          % the confirmation's cells, seeds and task table; about a minute; needs the observations
s.run.generalized.run_cells = true;        % AIES of the confirmation cells; a computing cluster; needs prepare
s.run.generalized.compare = true;          % certification and the comparisons with the default protocol; minutes; needs run_cells
s.run.generalized.combinations = true;     % the weak-pair combinations of the confirmation's posteriors and how the focused protocols change them (B.8); about a minute; needs the confirmation's draws (this run's or shipped)
s.run.generalized.figures = true;          % (rerun) the figures and tables of this run's results

%% 0.3 Computation --------------------------------------------------------

% Parallel MATLAB workers for model predictions. Must be 0: parallel UQLab
% sessions have not been validated for this release. Thesis: 0.
s.compute.parallelWorkers = 0;

% Points per call of the generalized GP (predictions of the dataset,
% sensitivity, screening and confirmation). Positive integer. Thesis: 1024.
% Memory only; the predictions do not depend on it.
s.compute.gpPredictionBatchSize = 1024;

% GP evaluations per batch at posterior draws (the fixed feature
% reconstruction and the confirmation summaries). Positive integer.
% Thesis: 5000. Memory only.
s.compute.posteriorBatchSize = 5000;

% Protocols per saved block of the protocol screen and its supplement (a
% stopped screen resumes from the last block). Positive integer. Thesis: 5.
s.compute.screeningBlockSize = 5;

%% 0.4 Figures ------------------------------------------------------------

% File formats of every figure: any of 'png', 'pdf', 'svg'. Thesis: {'png'}.
s.figures.formats = {'png'};

% Resolution of raster figures in dots per inch. Thesis: 300.
s.figures.resolution = 300;

% Posterior corner plots: 'canonical' draws those of the case outputs
% (A.10; thesis: the 20 gp_only / all_six cells); 'all' draws every
% available inversion cell (277), each from every retained draw of its
% provider shipped in thesis_results/.
s.figures.cornerGallery = 'canonical';

% Which figures a renderer draws: 'publication' (the thesis figures),
% 'aggregate' (summaries only) or 'full' (every per-cell figure).
% Thesis: 'publication'.
s.figures.mode = 'publication';

% true: draw the comparisons of the six observation designs per cell.
% Thesis: true.
s.figures.crossDesignComparisons = true;

% The GP hyperparameter tables (02_surrogates, gp_hyperparameters) flag a
% length scale theta above this value as at the upper bound of its
% optimization (AtUpperBound_<input>): the fits keep UQLab's default bounds
% of theta, 1e-3 to 10 in its scaled input coordinates, and its optimizer
% stops just below 10. Thesis: 9.9.
s.figures.thetaAtUpperBound = 9.9;

%% 0.5 Messages -----------------------------------------------------------

% How much a run prints: 'quiet', 'info' or 'debug'. Default: 'info'.
s.logging.level = 'info';

%% 0.6 Seeds --------------------------------------------------------------
% Every seed of the thesis results is recorded in the tables below and
% looked up by its request (case, scenario, design, output, ...). A request
% the thesis did not make (a new case, condition, output, fold or setting)
% takes the seed of its family's rule: the base plus fixed multiples of the
% request's numbers. A rule seed equal to a recorded seed is refused.
% Changing a rule changes the seeds of new requests only; the recorded
% seeds stay those of the thesis.

% Master seed: the development/external splits of both routes and the fixed
% sensitivity. Positive integer. Thesis: 20260519. Another value gives
% other splits, so other datasets and models.
s.seeds.master = 20260519;

% The folder of the recorded seed tables, and the table of each family.
% Thesis: config/seeds with the four tables below.
s.seeds.folder = 'config/seeds';
s.seeds.tables.mcmc = 'mcmc_seeds.csv';                    % MCMC requests (1,760)
s.seeds.tables.surrogateFits = 'surrogate_fit_seeds.csv';  % surrogate fits (125)
s.seeds.tables.surrogateAudit = 'surrogate_audit_seeds.csv'; % the fixed audit (598)
s.seeds.tables.designStudy = 'design_study_seeds.csv';     % the design study (63)

% Rules for requests without a recorded seed: seed = base + the sum of each
% multiplier times the request's number (codes: CaseID; condition code 1, 2,
% 4, 8 added for m3_f, m3_e, log10_k0, thickness fixed; scenario, design,
% level and replicate by position). Positive integers; the multipliers must
% leave room for the largest number of each field (checked).
% MCMC of the fixed route (thesis rule):
%   1000000000 + 1000000 CaseID + 10000 condition + 1000 scenario
%   + 100 design + 10 level + replicate
s.seeds.rules.mcmc = struct('base', 1000000000, 'case', 1000000, 'condition', 10000, ...
    'scenario', 1000, 'design', 100, 'level', 10, 'replicate', 1);
% Surrogate fits (route 1 fixed, 2 generalized; model 1 GP, 2 PCE; fold 0 is
% the full fit): 300000000 + 10000000 route + 1000000 model + 10000 output
% + 100 degree + fold.
s.seeds.rules.surrogateFit = struct('base', 300000000, 'route', 10000000, ...
    'model', 1000000, 'output', 10000, 'degree', 100, 'fold', 1);
% The surrogate audit: 100000000 + 1000000 purpose + 10000 output
% + 100 repeat + index.
s.seeds.rules.surrogateAudit = struct('base', 100000000, 'purpose', 1000000, ...
    'output', 10000, 'repeat', 100, 'index', 1);
% The design study's rank bootstrap: 200000000 + 1000000 scenario; its ratio
% check: that seed + 1000 + CaseID.
s.seeds.rules.rankBootstrap = struct('base', 200000000, 'scenario', 1000000);
s.seeds.rules.ratioValidation = struct('offset', 1000, 'case', 1);
% The confirmation cells (no recorded seeds; design: its position among the
% inversion's designs, all_six 1, d2_only 2; protocol: its row in B.7):
% 2000000000 + 1000000 design + 1000 CaseID + 100 protocol + 10 level
% + replicate.
s.seeds.rules.confirmation = struct('base', 2000000000, 'design', 1000000, 'case', 1000, ...
    'protocol', 100, 'level', 10, 'replicate', 1);

%% 0.7 Derived features ---------------------------------------------------

% Features derived from the six closing pressures (ratios, levels, decline
% shapes), shared by the ratio-error curves (A.11) and both routes'
% feature analyses (features.definitions). The reference coefficient of
% variation: their errors are read in units of a relative error of this
% size (the yardstick of the ratio discrepancy d). It is a unit, not the
% noise model of the likelihood (A.2 and B.2 have their own). Thesis: 0.08.
s.features.referenceCV = 0.08;

% The feature catalog of the feature sensitivity (step feature_sensitivity of
% both routes) and the feature accuracy, one row per feature:
% {name, family, type, weights, unit, status, physical hypothesis}. The
% pressures p in the order of the outputs: cycles 1, 2, 3 of D2, then of D6.
%   type 'loglinear'  weights w (6 entries): log f = w * log(p), natural log
%                     (the feature is used as log f)
%   type 'raw'        weights {a} or {a, b} (6 entries each): f = a * p, or
%                     f = (a * p) / (b * p) (used as f, in mbar for a
%                     difference)
% family: F1_ratios, F2_differences, F3_levels or F4_decline_shape (the six
% pressures themselves are F0_raw_pressures); status: 'core' or
% 'exploratory'. A feature that a route's sensitivity step already computes
% keeps that step's definition there, the raw convention
% (features.inventory): the within-probe ratios of cycles 2 and 3 to cycle 1
% on both routes; on the generalized route also the cycle drops (the F2
% differences) and the relative drops (1 - r21, 1 - r32, 1 - r31). A row added
% here appears in every table and figure of the feature analyses. Thesis: the
% 26 features below.
s.features.catalog = { ...
    'r21_D2', 'F1_ratios', 'loglinear', [-1 1 0 0 0 0], '-', 'core', 'D2 decline from cycle 1 to 2: dissipation (m3e) against recovery (k0)'; ...
    'r31_D2', 'F1_ratios', 'loglinear', [-1 0 1 0 0 0], '-', 'core', 'D2 decline from cycle 1 to 3'; ...
    'r32_D2', 'F1_ratios', 'loglinear', [0 -1 1 0 0 0], '-', 'core', 'D2 decline from cycle 2 to 3: the later-cycle balance'; ...
    'r21_D6', 'F1_ratios', 'loglinear', [0 0 0 -1 1 0], '-', 'core', 'D6 decline from cycle 1 to 2: thickness and m3e'; ...
    'r31_D6', 'F1_ratios', 'loglinear', [0 0 0 -1 0 1], '-', 'core', 'D6 decline from cycle 1 to 3'; ...
    'r32_D6', 'F1_ratios', 'loglinear', [0 0 0 0 -1 1], '-', 'core', 'D6 decline from cycle 2 to 3'; ...
    'q1', 'F1_ratios', 'loglinear', [1 0 0 -1 0 0], '-', 'core', 'depth contrast of the level in cycle 1 (D2 over D6): thickness'; ...
    'q2', 'F1_ratios', 'loglinear', [0 1 0 0 -1 0], '-', 'core', 'depth contrast of the level in cycle 2'; ...
    'q3', 'F1_ratios', 'loglinear', [0 0 1 0 0 -1], '-', 'core', 'depth contrast of the level in cycle 3'; ...
    'R21', 'F1_ratios', 'loglinear', [-1 1 0 1 -1 0], '-', 'core', 'depth contrast of the decline from cycle 1 to 2 (the double ratio R)'; ...
    'R31', 'F1_ratios', 'loglinear', [-1 0 1 1 0 -1], '-', 'core', 'depth contrast of the decline from cycle 1 to 3'; ...
    'R32', 'F1_ratios', 'loglinear', [0 -1 1 0 1 -1], '-', 'core', 'depth contrast of the decline from cycle 2 to 3'; ...
    'd21_D2', 'F2_differences', 'raw', {[1 -1 0 0 0 0]}, 'mbar', 'core', 'absolute D2 decline from cycle 1 to 2: level and decline together'; ...
    'd32_D2', 'F2_differences', 'raw', {[0 1 -1 0 0 0]}, 'mbar', 'core', 'absolute later D2 decline'; ...
    'd31_D2', 'F2_differences', 'raw', {[1 0 -1 0 0 0]}, 'mbar', 'core', 'total D2 decline'; ...
    'd21_D6', 'F2_differences', 'raw', {[0 0 0 1 -1 0]}, 'mbar', 'core', 'absolute D6 decline from cycle 1 to 2'; ...
    'd32_D6', 'F2_differences', 'raw', {[0 0 0 0 1 -1]}, 'mbar', 'core', 'absolute later D6 decline'; ...
    'd31_D6', 'F2_differences', 'raw', {[0 0 0 1 0 -1]}, 'mbar', 'core', 'total D6 decline'; ...
    'G_D2', 'F3_levels', 'loglinear', [1 1 1 0 0 0] / 3, '-', 'core', 'shallow level (geometric mean of D2): m3f'; ...
    'G_D6', 'F3_levels', 'loglinear', [0 0 0 1 1 1] / 3, '-', 'core', 'deep level (geometric mean of D6): thickness'; ...
    'G_all', 'F3_levels', 'loglinear', [1 1 1 1 1 1] / 6, '-', 'core', 'overall stiffness level'; ...
    's_D2', 'F4_decline_shape', 'loglinear', [1 -2 1 0 0 0], '-', 'exploratory', 'second log-difference of D2: does the decline saturate?'; ...
    's_D6', 'F4_decline_shape', 'loglinear', [0 0 0 1 -2 1], '-', 'exploratory', 'second log-difference of D6'; ...
    's_diff', 'F4_decline_shape', 'loglinear', [1 -2 1 -1 2 -1], '-', 'exploratory', 'depth contrast of the progression (s_D2 - s_D6)'; ...
    'dropratio_D2', 'F4_decline_shape', 'raw', {[0 1 -1 0 0 0], [1 -1 0 0 0 0]}, '-', 'exploratory', 'linear progression of the D2 decline: (p2 - p3) / (p1 - p2)'; ...
    'dropratio_D6', 'F4_decline_shape', 'raw', {[0 0 0 0 1 -1], [0 0 0 1 -1 0]}, '-', 'exploratory', 'linear progression of the D6 decline'};

% A raw quotient of the catalog (a drop ratio) is UNSTABLE, reported but
% left out of the rankings, when its denominator changes sign over the Sobol
% sample or when a few samples carry its variance: the 0.1 % of the values
% farthest from the mean holding more than this share of the sum of squared
% deviations. The feature accuracy applies the rule to the external cases
% (there the 0.1 % is the one most extreme case). Thesis: 0.5.
s.features.unstableTailShare = 0.5;

% The feature accuracy (step feature_accuracy of both routes: the catalog's
% features from the surrogate means against the same features from the
% COMSOL pressures of the external cases): the case-bootstrap of RMSE and
% R^2 (resamples, seed); the outputs whose values lie on the time grid of
% the COMSOL closing in most cases (their rounding step is |rate| x the
% time step; pcl2_D2_mbar and pcl3_D2_mbar, on it in a minority of the
% cases, are not counted) and that time step (s): COMSOL registers a
% closing at its solver's steps, at most 1 s apart (data/README.md).
% Thesis: 2000, 20291530; pcl1_D2_mbar and pcl1_D6_mbar, 1.
s.features.accuracy.bootstrapResamples = 2000;
s.features.accuracy.bootstrapSeed = 20291530;
s.features.accuracy.griddedOutputs = {'pcl1_D2_mbar', 'pcl1_D6_mbar'};
s.features.accuracy.outputTimeStep = 1;

%% ======================================================================
%% A  FIXED ROUTE (run_fixed_study)
%% ======================================================================
% Four material parameters of the reticular dermis -> six closing pressures
% (three suction cycles at the probes D2 and D6) under the default protocol.

%% A.1 Dataset and parameters ---------------------------------------------

% The COMSOL dataset: one row per simulated material (CaseID, the four
% parameters, the six pressures and the split group; data/README.md). CSV
% file. Thesis: the 452 cases of the freeze of 2 September 2026 (the
% dataset of the frozen calibration of A.3; another dataset needs a
% matching calibration).
s.fixed.dataset.file = 'data/fixed/fixed_dataset.csv';

% The column of the split groups: cases with equal material inputs share a
% label, and the split keeps each group on one side. The surrogate audit
% orders its grouped folds by these labels. Thesis: 'MaterialGroup' (frozen
% labels G0001-G0452 that reproduce the thesis folds; data/README.md).
s.fixed.dataset.groupColumn = 'MaterialGroup';

% Columns of the parameters and of the six closing pressures (mbar) in the
% dataset, in model order. Thesis values below.
s.fixed.dataset.inputColumns = {'m3_f_RD', 'm3_e_RD', 'k0_RD', 'Thickness_RD'};
s.fixed.dataset.outputColumns = {'pcl1_D2_mbar', 'pcl2_D2_mbar', 'pcl3_D2_mbar', ...
    'pcl1_D6_mbar', 'pcl2_D6_mbar', 'pcl3_D6_mbar'};

% The input column learned on a log10 scale (the permeability k0). A column
% name, or '' for none. Thesis: 'k0_RD'.
s.fixed.dataset.logColumn = 'k0_RD';

% Development / external split of the complete cases: the fractions sum to
% 1. Thesis: 0.80 / 0.20 (391 development, 61 external cases; partial cases
% are always development). A larger external share leaves fewer training
% cases.
s.fixed.dataset.developmentFraction = 0.80;
s.fixed.dataset.externalFraction = 0.20;

% Cases the split keeps external when they are complete: the 20 inversion
% truths first, then the other 16 external cases of the earlier 178-case
% split, so that the thesis's external cohort contains them. CaseIDs.
s.fixed.dataset.preferredExternalCases = [131 113 230 232 42 93 172 12 119 220 206 48 96 ...
    215 83 146 166 246 249 116 13 45 52 88 102 105 123 126 138 152 167 180 194 229 237 242];

% The four parameters of the model (the learning coordinates), their units
% and bounds. The inverse problem's prior is uniform on these bounds; cases
% outside them are not used. Thesis: m3_f 50-300, m3_e 0-1000,
% log10(k0) -2.30103 to -1.30103 (k0 0.005-0.05 mm^4/(N s)), thickness
% 1.0-2.5 mm.
s.fixed.parameters.names = {'m3_f_RD', 'm3_e_RD', 'log10_k0_RD', 'Thickness_RD'};
s.fixed.parameters.units = {'-', '-', 'log10(mm^4/(N s))', 'mm'};
s.fixed.parameters.bounds = [50 300; 0 1000; -2.30103 -1.30103; 1.0 2.5];

%% A.2 Measurement model --------------------------------------------------

% Measurement noise of the scenario measurement_plus_gp: the standard
% deviation of output j is CV x |GP mean of output j| (mbar). Positive.
% Thesis: 0.08. A larger value widens the likelihood (wider posteriors); a
% smaller one sharpens it.
s.fixed.measurement.cv = 0.08;

% A numerical floor (mbar) whose square is added to the variance of every
% output in every scenario. Positive. Thesis: 1e-6.
s.fixed.measurement.minimumSigma = 1e-6;

%% A.3 Surrogates ---------------------------------------------------------

% Which surrogate models the later steps use:
%   'use_shipped'           the exact thesis models in thesis_results/ (no
%                           fitting; the step 'surrogates' is not run)
%   'refit_audit_selected'  the step 'surrogates' refits them with the
%                           configuration the development audit selected
%                           (the record below: kernel, trend, ARD,
%                           optimizer, nugget, seeds)
%   'refit_manual'          the step 'surrogates' refits them with the
%                           kernel, optimizer and nugget of s.fixed.surrogates.manual
% Thesis: 'use_shipped'.
s.fixed.surrogates.modelSource = 'use_shipped';

% The audit's selection record (read by 'use_shipped' and
% 'refit_audit_selected'). Thesis: the Matern-3/2 decision with the reviewed
% seed of output 6.
s.fixed.surrogates.auditSelection = 'config/fixed_surrogate_selection.json';

% The GP of 'refit_manual': kernel ('Matern-3_2', 'Matern-5_2',
% 'Gaussian', 'Exponential', 'Linear'), trend ('ordinary', 'linear',
% 'quadratic'), correlation ('Ellipsoidal': one length scale per input,
% ARD; 'Separable'), optimizer (UQLab: 'HGA', 'BFGS', 'LBFGS', 'GA',
% 'SADE', 'HSADE', 'CMAES', 'HCMAES') and nugget. Values here: those of the
% thesis models. The emulator calibration below was fitted for the thesis
% GP; another GP needs its own calibration (the run refuses a calibration
% made for another kernel, trend, correlation, optimizer or nugget). Every
% GP fit (the thesis GPs too) keeps UQLab's default bounds: the length
% scales theta between 1e-3 and 10 in UQLab's scaled input coordinates (9
% of the 24 thesis length scales end at 10, the tables flag them, 0.4), and
% the process variance sigma^2, optimized together with them, between
% (0.1 SD)^2 and (10 SD)^2 of the training outputs; the nugget is a known
% noise variance (UQLab Regression.SigmaNSQ), not estimated.
s.fixed.surrogates.manual.kernel = 'Matern-3_2';
s.fixed.surrogates.manual.trend = 'ordinary';
s.fixed.surrogates.manual.correlation = 'Ellipsoidal';
s.fixed.surrogates.manual.optimizer = 'HGA';
s.fixed.surrogates.manual.nugget = 1e-10;

% Advanced ('refit_manual' only): fixed correlation length scales instead
% of an optimization, one row per output (6) and one column per input (4),
% in UQLab's scaling of theta; the GP variance then follows from them.
% Only for a GP without a nugget (nugget 0): UQLab 2.3 fits a GP with a
% nugget (the thesis GP) as a GP regression, whose hyperparameters it
% always optimizes. Such a GP needs an emulator calibration of its own.
% [] optimizes them. Thesis: [].
s.fixed.surrogates.manual.fixedTheta = [];

% The PCE (the sensitivity's second surrogate): UQLab method, candidate
% degrees and q-norm of the hyperbolic truncation. Thesis: 'BCS', 1:6,
% 0.75.
s.fixed.surrogates.pce.method = 'BCS';
s.fixed.surrogates.pce.degrees = 1:6;
s.fixed.surrogates.pce.qNorm = 0.75;

% The emulator-error calibration: the GP's predictive variance, tempered
% and scaled per output (gamma 0.302, tau^2 per output), used by every
% likelihood with GP error. JSON record. Thesis: v3.
s.fixed.surrogates.emulatorCalibration = 'config/fixed_emulator_calibration.json';

%% A.4 Surrogate audit (step surrogate_audit, development cases only) -----

% Kernels compared by the repeated cross-validation, and those compared by
% the same-data seed-stability fits and the training-size convergence.
% Thesis: Matern-3/2, Matern-5/2 and Gaussian; Matern-3/2 and Matern-5/2.
s.fixed.surrogateAudit.kernels = {'Matern-3_2', 'Matern-5_2', 'Gaussian'};
s.fixed.surrogateAudit.sameDataKernels = {'Matern-3_2', 'Matern-5_2'};

% GP trend and correlation of every audit fit. Thesis: 'ordinary',
% 'Ellipsoidal' (anisotropic, one length scale per input).
s.fixed.surrogateAudit.trend = 'ordinary';
s.fixed.surrogateAudit.correlation = 'Ellipsoidal';

% Same-data refits per kernel, repeats and folds of the grouped
% cross-validation, and the probe points of the seed-stability check
% (a centred Latin hypercube on the bounds). Thesis: 5, 5, 5, 512.
s.fixed.surrogateAudit.sameDataReplicates = 5;
s.fixed.surrogateAudit.crossValidationRepeats = 5;
s.fixed.surrogateAudit.crossValidationFolds = 5;
s.fixed.surrogateAudit.probePointCount = 512;

% Training-size convergence: repeats, validation cases, candidate pool and
% training sizes. Thesis: 5, 22, 120, [20 40 60 80 100 120].
s.fixed.surrogateAudit.trainingConvergenceRepeats = 5;
s.fixed.surrogateAudit.trainingConvergenceValidationCount = 22;
s.fixed.surrogateAudit.trainingConvergencePoolCount = 120;
s.fixed.surrogateAudit.trainingConvergenceSizes = [20 40 60 80 100 120];

% The emulator-error calibration of the audit (it compares the variance
% models raw UQLab, constant, full and tempered local shape): folds, the
% gamma grid, bins of the local shape, CaseID cluster bootstrap replicates,
% residual-correlation bootstrap replicates and the largest residuals
% reported per output. Thesis values below.
s.fixed.surrogateAudit.calibrationFolds = 5;
s.fixed.surrogateAudit.gammaGrid = 0:0.025:1;
s.fixed.surrogateAudit.localShapeBinCount = 5;
s.fixed.surrogateAudit.clusterBootstrapReplicates = 500;
s.fixed.surrogateAudit.residualCorrelationBootstrapReplicates = 200;
s.fixed.surrogateAudit.residualTailCount = 10;

% Central interval levels of the coverage checks. Thesis: [0.50 0.80 0.90 0.95].
s.fixed.surrogateAudit.intervalLevels = [0.50 0.80 0.90 0.95];

% Numerical tolerances of the audit's comparisons (equal within this
% relative difference). Thesis: 1e-12 each.
s.fixed.surrogateAudit.comparisonTolerance = 1e-12;
s.fixed.surrogateAudit.relativeDenominatorTolerance = 1e-12;
s.fixed.surrogateAudit.rangeTolerance = 1e-12;
s.fixed.surrogateAudit.varianceFactorizationTolerance = 1e-12;

%% A.5 Sensitivity --------------------------------------------------------

% Sobol indices of the six pressures: Monte Carlo sample size, highest
% interaction order and the tolerance of the first/total-order consistency
% check. Thesis: 50000, 2, 0.02.
s.fixed.sensitivity.sobolSamples = 50000;
s.fixed.sensitivity.sobolOrder = 2;
s.fixed.sensitivity.consistencyTolerance = 0.02;

%% A.6 Inversion ----------------------------------------------------------

% Truths to invert: CaseIDs of complete external cases, in the order given,
% or 'all' (every complete external case, in the order of the split
% manifest; then pass the cases with 'Cases' in every call that names
% 'InversionCells', GUIDE section 3). Thesis: the 20 canonical truths below.
s.fixed.inversion.cases = [131 113 230 232 42 93 172 12 119 220 206 48 96 215 83 146 ...
    166 246 249 116];

% Likelihood scenarios, a list or 'all'. Keep all three in this order: a
% rerun of the inversion and of the steps that read its grid (recovery,
% design study, conditional inversion) refuses a subset
% (inversion.build_inversion_grid); to run some cells only, select them with
% 'InversionCells' (GUIDE section 3):
%   'measurement_plus_gp'  the held-out COMSOL pressures, with measurement
%                          noise (A.2) plus the calibrated GP error
%   'gp_only'              the same observations, the calibrated GP error only
%   'gp_self_det'          the GP mean at the truth as observations, with the
%                          floor of A.2 only (a self-consistency diagnostic)
% Thesis: all three.
s.fixed.inversion.scenarios = {'measurement_plus_gp', 'gp_only', 'gp_self_det'};

% Observation designs, a list or 'all': 'all_six', 'd2_only', 'd6_only',
% 'cycle_1_only', 'ratios_only', 'physics_guided_full_rank_six'. Keep all
% six in this order, as the scenarios above. Thesis: all six.
s.fixed.inversion.designs = {'all_six', 'd2_only', 'd6_only', 'cycle_1_only', ...
    'ratios_only', 'physics_guided_full_rank_six'};

% The design 'ratios_only' observes the pressure ratios output(numerator) /
% output(denominator); a denominator below the floor is refused. Thesis:
% 2/1, 3/1, 5/4, 6/4 (cycle 2 and 3 over cycle 1 at each probe), floor 1e-12.
s.fixed.inversion.ratioNumerators = [2 3 5 6];
s.fixed.inversion.ratioDenominators = [1 1 4 4];
s.fixed.inversion.ratioDenominatorFloor = 1e-12;

% AIES (affine-invariant ensemble sampler, UQLab): chain lengths of the
% levels (a cell escalates to the next level when its replicates do not
% certify), burn-in fraction, thinning, walkers, stretch scale a, start of
% the walkers and the independent replicate ensembles per cell. Thesis:
% [2000 5000], 0.5, 1, 40, 2, 'latin_hypercube', [1 2]. Longer chains cost
% proportionally more; certification needs exactly the two replicates
% [1 2].
s.fixed.inversion.mcmc.levels = [2000 5000];
s.fixed.inversion.mcmc.burnIn = 0.5;
s.fixed.inversion.mcmc.thinning = 1;
s.fixed.inversion.mcmc.walkers = 40;
s.fixed.inversion.mcmc.stretchScale = 2;
s.fixed.inversion.mcmc.initialization = 'latin_hypercube';
s.fixed.inversion.mcmc.replicates = [1 2];

% Certification of a cell (inversion.same_sampler_reliability): each of the
% two AIES ensembles must pass the structural health checks (every retained
% draw inside the prior bounds; no frozen walker: each moves in at least
% frozenMovementFraction of the steps and visits at least
% minimumUniqueStates states; no duplicated trajectory), and the two must
% agree for every parameter: the normalized Wasserstein distance and the
% 2.5 % and 97.5 % quantile differences within their fraction of the prior
% range. For AIES the ensemble-time R-hat, the bulk and tail ESS, the
% relative Monte Carlo SE of the SD and the median and correlation
% differences are warnings that never veto (thresholds below); R-hat, ESS,
% MCSE and the median difference gate only the independent chains of
% adaptive Metropolis, which this version does not run, and the correlation
% difference gates neither. Thesis values below. Stricter values of
% maxNormalizedWasserstein, maxQuantileRangeDifference and
% frozenMovementFraction certify fewer cells; the warning thresholds change
% only the warnings.
s.fixed.inversion.certification.maxRankSplitRhat = 1.05;
s.fixed.inversion.certification.minBulkESS = 400;
s.fixed.inversion.certification.minTailESS = 200;
s.fixed.inversion.certification.maxRelativeSdMCSE = 0.05;
s.fixed.inversion.certification.maxMedianRangeDifference = 0.03;
s.fixed.inversion.certification.maxQuantileRangeDifference = 0.05;
s.fixed.inversion.certification.maxNormalizedWasserstein = 0.05;
s.fixed.inversion.certification.correlationDifferenceWarning = 0.15;
s.fixed.inversion.certification.minIndependentReplicates = 2;
s.fixed.inversion.certification.frozenMovementFraction = 0.01;
s.fixed.inversion.certification.minimumUniqueStates = 2;
s.fixed.inversion.certification.duplicateSampleTolerance = 1e-12;
s.fixed.inversion.certification.maxDuplicateFraction = 0;

% The warning diagnostics of a replicate pair (ensemble-time R-hat, tail
% ESS) never gate certification. An undefined R-hat (NaN), an R-hat at or
% above degenerateRhat and a tail ESS of 0 are written as a health note in
% the pair diagnostics and the status table and are left out of the
% diagnostic figures (their count in the figure's title). Thesis: 1e6 (the
% thesis campaign's R-hats are at most 6.71, or about 4.4e14).
s.fixed.inversion.diagnostics.degenerateRhat = 1e6;

%% A.7 Recovery -----------------------------------------------------------

% Posterior covariance eigen-analysis (switch: s.run.fixed.eigen_analysis,
% 0.2): its scenarios and design (it compares the practical scenario
% measurement_plus_gp with the structural gp_only on all_six: the only values
% implemented), the relative eigenvalue gap below which two directions count
% as degenerate, and the numerical tolerances. Thesis: measurement_plus_gp
% and gp_only, all_six, 0.10, 1e-12, 1e-12, 1e-15.
s.fixed.recovery.eigendecomposition.scenarios = {'measurement_plus_gp', 'gp_only'};
s.fixed.recovery.eigendecomposition.design = 'all_six';
s.fixed.recovery.eigendecomposition.nearDegenerateGapThreshold = 0.10;
s.fixed.recovery.eigendecomposition.negativeEigenvalueTolerance = 1e-12;
s.fixed.recovery.eigendecomposition.symmetryTolerance = 1e-12;
s.fixed.recovery.eigendecomposition.divisionFloor = 1e-15;

% The weak pair whose joint posterior geometry the recovery reports (the
% two least identifiable parameters), and whose posteriors the figures of
% the conditional inversion show (A.9). Two names of A.1. Thesis: m3_e and
% log10(k0).
s.fixed.recovery.eigendecomposition.weakPair = {'m3_e_RD', 'log10_k0_RD'};

% Feature reconstruction (the pressures and features predicted from the
% posterior, per fitting design and evaluation space) and its error budget
% (switches: s.run.fixed.feature_reconstruction and error_budget, 0.2): its
% scenarios (measurement_plus_gp and gp_only, the only values implemented),
% the diagnostic spaces besides the six designs, and the tolerance below
% which a truth range counts as zero. Thesis: measurement_plus_gp and
% gp_only, the three below, 1e-12.
s.fixed.recovery.featureReconstruction.scenarios = {'measurement_plus_gp', 'gp_only'};
s.fixed.recovery.featureReconstruction.diagnosticSpaces = {'within_probe_drops', ...
    'cross_probe_ratios', 'cross_probe_differences'};
s.fixed.recovery.featureReconstruction.nearZeroRangeTolerance = 1e-12;

% Second-mode check (switch: s.run.fixed.second_mode_check, 0.2): one cell
% whose walkers split into groups, and whether its second group B is a second
% region of good fit or a place where walkers are stuck; descriptive, no
% MCMC, no status changes. The cell (case, scenario, design); two walkers
% are in one group when their median positions differ by at most
% groupDistance prior widths in every parameter; the points of the path from
% the truth to B; the neighbourhood (prior widths, every parameter) in which
% the draws of the case's cells in shareScenarios count as near B or near the
% truth; the eigendirections of directionScenario (the cell's design) that
% the direction truth -> B is compared with (and its weak-pair combinations,
% step combinations, A.12); the number of COMSOL cases with
% the closest pressures; the local optimizer (fmincon) of the refinement;
% and the class, fixed in advance: EXACT SECOND SOLUTION when the refinement
% from B ends at least exactDistance prior widths from the truth in some
% parameter with a log-likelihood within exactLogLikelihood of the truth's,
% else NEAR-EQUIVALENT SOLUTION when delta (measurement and calibrated
% emulator noise at the truth) at B is below nearDelta, else TRAP. Thesis:
% case 215 gp_self_det all_six, 0.05, 201, 0.05,
% measurement_plus_gp and gp_only, measurement_plus_gp, 10, sqp with the
% tolerances below, 0.05, 2, 2.
s.fixed.recovery.secondModeCheck.caseID = 215;
s.fixed.recovery.secondModeCheck.scenario = 'gp_self_det';
s.fixed.recovery.secondModeCheck.design = 'all_six';
s.fixed.recovery.secondModeCheck.groupDistance = 0.05;
s.fixed.recovery.secondModeCheck.pathPoints = 201;
s.fixed.recovery.secondModeCheck.neighbourhood = 0.05;
s.fixed.recovery.secondModeCheck.shareScenarios = {'measurement_plus_gp', 'gp_only'};
s.fixed.recovery.secondModeCheck.directionScenario = 'measurement_plus_gp';
s.fixed.recovery.secondModeCheck.comsolNeighbours = 10;
s.fixed.recovery.secondModeCheck.optimizer.algorithm = 'sqp';
s.fixed.recovery.secondModeCheck.optimizer.optimalityTolerance = 1e-10;
s.fixed.recovery.secondModeCheck.optimizer.stepTolerance = 1e-12;
s.fixed.recovery.secondModeCheck.optimizer.maxIterations = 500;
s.fixed.recovery.secondModeCheck.optimizer.maxFunctionEvaluations = 5000;
s.fixed.recovery.secondModeCheck.classification.exactDistance = 0.05;
s.fixed.recovery.secondModeCheck.classification.exactLogLikelihood = 2;
s.fixed.recovery.secondModeCheck.classification.nearDelta = 2;

% Sensitivity of the published aggregates of one scenario to cells whose
% walkers sit at the thickness bound (a table of the recovery, drawn with
% the analysis coverage_recovery): the cells' cases, removed from every
% compared design, their scenario (the aggregates of that scenario) and
% design. Thesis: the healthy fallbacks of cases 172, 220, 48, 166 and 246 in
% gp_only, physics_guided_full_rank_six (2 to 9 of 40 walkers of the healthy
% replicate at the lower thickness bound).
s.fixed.recovery.boundSensitivity.cases = [172 220 48 166 246];
s.fixed.recovery.boundSensitivity.scenario = 'gp_only';
s.fixed.recovery.boundSensitivity.design = 'physics_guided_full_rank_six';

%% A.8 Design study -------------------------------------------------------

% Bootstrap replicates of the design ranking and Monte Carlo draws of the
% ratio check. Thesis: 2000, 20000.
s.fixed.designStudy.bootstrapReplicates = 2000;
s.fixed.designStudy.ratioValidationDraws = 20000;

% The ratio check compares the delta-method covariance of the cycle ratios
% with their Monte Carlo covariance; it passes when their relative
% Frobenius difference is at most this tolerance. Thesis: 0.10.
s.fixed.designStudy.ratioValidationTolerance = 0.10;

% Finite-difference step of the Fisher-information metrics (unit-box
% coordinates) and the two steps of their step check. Thesis: 1e-3;
% 5e-4 and 2e-3.
s.fixed.designStudy.finiteDifferenceStep = 1e-3;
s.fixed.designStudy.finiteDifferenceCheckSteps = [5e-4 2e-3];

%% A.9 Conditional inversion (step conditional_inversion) -----------------

% Inversions with material parameters fixed at the case's synthetic truth.
% The sampler moves only the free parameters; the GP is evaluated on all
% four, the fixed ones at the truth. Prior (the free parameters' bounds),
% likelihood, sampler, health checks and certification are those of the
% canonical inversion (A.6), with the replicate agreement over the free
% parameters. Each condition is compared with the canonical all_six cell of
% the same case and scenario. Its figures show the weak pair of A.7
% (s.fixed.recovery.eigendecomposition.weakPair); its tables every free
% parameter.

% The conditions: rows {label, description, fixed parameters}. The fixed
% parameters are names of the four material parameters ('m3_f_RD',
% 'm3_e_RD', 'log10_k0_RD', 'Thickness_RD'); at least one stays free, and
% no two rows fix the same set. The code derives each condition's mask
% (1 = free, in this order of the parameters) and records it in the run
% record. Exactly one row fixes nothing: the canonical all_six cell, never
% run in this step. A condition is defined by its fixed parameters; the
% label only names it in tables and figures, so renaming a label changes no
% cell, seed or file. Thesis: A-D (the thesis campaign: are the weak
% parameters masked by the strong ones?) and E, F (do the two weak
% parameters m3_e and log10_k0 mask each other?).
s.fixed.conditionalInversion.conditions = { ...
    'A', 'All four parameters free', {}; ...
    'B', 'Thickness fixed at truth', {'Thickness_RD'}; ...
    'C', 'm3_f fixed at truth', {'m3_f_RD'}; ...
    'D', 'm3_f and Thickness fixed at truth', {'m3_f_RD', 'Thickness_RD'}; ...
    'E', 'm3_e fixed at truth', {'m3_e_RD'}; ...
    'F', 'log10_k0 fixed at truth', {'log10_k0_RD'}};
% A further condition is one more row, e.g.
%     'G', 'log10_k0 and Thickness fixed at truth', {'log10_k0_RD', 'Thickness_RD'}; ...
% and a row of s.fixed.conditionalInversion.cells that runs it.

% The campaign: rows {conditions, scenarios}; every condition of a row runs
% in every scenario of the row, in this order, for every case. Conditions
% are labels of the table above (not the row that fixes nothing) or 'all';
% scenarios are 'measurement_plus_gp' and 'gp_only' (the scenarios the
% conditional inversion is implemented for) or 'all' (both). Thesis: B, C
% and D in gp_only and D in measurement_plus_gp (the thesis campaign, 80
% cells), E and F in both scenarios, measurement_plus_gp first (80 cells).
s.fixed.conditionalInversion.cells = { ...
    {'B', 'C', 'D'}, {'gp_only'}; ...
    {'D'}, {'measurement_plus_gp'}; ...
    {'E', 'F'}, {'measurement_plus_gp', 'gp_only'}};

% The cases: 'all' (every case of the inversion, A.6) or a list of CaseIDs
% of the inversion (e.g. a pilot of the first five). Thesis: 'all', the 20
% canonical cases. Conditions need a synthetic truth, which every case of
% the inversion has.
s.fixed.conditionalInversion.cases = 'all';

% The observation design of the conditional cells. Thesis: all_six (the
% only design implemented).
s.fixed.conditionalInversion.design = 'all_six';

% A conditional cell runs when its canonical all_six cell (same case and
% scenario) has one of these statuses: 'certified', 'healthy fallback'.
% Otherwise the cell is not run and reported unavailable. Thesis: both
% (the thesis campaign holds the cells of every case, also of the three
% whose gp_only cell is a healthy fallback); {'certified'} runs only cells
% with a certified baseline.
s.fixed.conditionalInversion.baselineStatuses = {'certified', 'healthy fallback'};

% Cells that thesis_results/ holds already: true takes them from there
% (status, provider, draws and comparison rows; they are not run), false
% runs every cell. It applies when the canonical cells are the shipped ones
% (this call does not run the step inversion). Thesis: true, so that only
% the cells of new conditions run.
s.fixed.conditionalInversion.reuseShippedCells = true;

%% A.10 Case outputs ------------------------------------------------------

% The outputs of single cases, in thesis_results/fixed/cases/case_<CaseID>/
% with one folder per step (inversion, recovery, design_study,
% conditional_inversion). Each setting selects cases, or rows {cases,
% scenarios} or {cases, scenarios, designs}: cases a list of CaseIDs or
% 'all' (every case of the inversion, A.6), scenarios and designs a list or
% 'all'; {} or [] draws none. A cell is drawn if it has a posterior,
% certified or a healthy fallback (its title says which); a case that is
% not a case of the inversion is left out. Every draw of every cell ships,
% so any selection renders from the shipped results.

% The posterior of single cells (inversion): marginals with their
% statistics, credible intervals and corner plot (every retained draw in
% pairs), named <scenario>_<design>_<what>. Rows {cases, scenarios,
% designs}. Thesis: every case in the primary configuration,
% measurement_plus_gp and all_six; case 131 in measurement_plus_gp with
% every design; the all_six cells of cases 131 and 113 in gp_only and of
% 131 and 42 in gp_self_det.
s.fixed.caseOutputs.cells = { ...
    'all', {'measurement_plus_gp'}, {'all_six'}; ...
    131, {'measurement_plus_gp'}, 'all'; ...
    [131 113], {'gp_only'}, {'all_six'}; ...
    [131 42], {'gp_self_det'}, {'all_six'}};

% The sampler traces and the provider's diagnostic metrics of single cells
% (inversion), <scenario>_<design>_traces and _diagnostics. Rows {cases,
% scenarios, designs}. Thesis: case 131 in measurement_plus_gp with every
% design, and the all_six cells of cases 131 and 113 in gp_only and of 131
% and 42 in gp_self_det.
s.fixed.caseOutputs.samplerDiagnostics = { ...
    131, {'measurement_plus_gp'}, 'all'; ...
    [131 113], {'gp_only'}, {'all_six'}; ...
    [131 42], {'gp_self_det'}, {'all_six'}};

% Corner plots, with the cell's statistics, of further cells (inversion);
% s.figures.cornerGallery 'all' draws the corner plot of every cell
% instead. Rows {cases, scenarios, designs}. Thesis: every case in gp_only,
% all_six.
s.fixed.caseOutputs.corners = {'all', {'gp_only'}, {'all_six'}};

% The certification summary of single cells (inversion), a table
% <scenario>_<design>_certification: the cell's status, provider and
% reason, and per step level and parameter its replicate agreement and
% health diagnostics with their thresholds. Rows {cases, scenarios,
% designs}. Thesis: every case in measurement_plus_gp, all_six.
s.fixed.caseOutputs.certificationSummaries = {'all', {'measurement_plus_gp'}, {'all_six'}};

% The all_six marginals of the scenarios side by side (inversion),
% all_six_scenario_marginals. Cases. Thesis: 'all'.
s.fixed.caseOutputs.scenarioMarginals = 'all';

% The marginals of the designs overlaid, with their statistics (inversion),
% <scenario>_design_marginals; drawn when s.figures.crossDesignComparisons
% is true. Rows {cases, scenarios}. Thesis: case 131 in
% measurement_plus_gp.
s.fixed.caseOutputs.designMarginals = {131, {'measurement_plus_gp'}};

% The all_six posterior median with its 50 % and 95 % intervals and the
% truth, per scenario (recovery), posterior_intervals. Cases. Thesis:
% 'all'.
s.fixed.caseOutputs.posteriorIntervals = 'all';

% The posterior predictive check of single cells (recovery),
% <scenario>_<design>_predictive: the six closing pressures of the case
% (held-out COMSOL) against the median and central 95 % interval of the GP
% mean at the cell's posterior draws, as the recovery reconstructed them
% (scenarios measurement_plus_gp and gp_only). Rows {cases, scenarios,
% designs}. Thesis: every case in measurement_plus_gp, all_six.
s.fixed.caseOutputs.predictiveChecks = {'all', {'measurement_plus_gp'}, {'all_six'}};

% The 95 % ellipse of the all_six posterior of m3_e_RD and log10_k0_RD
% (design study), <scenario>_target_q_ellipse. Rows {cases, scenarios}.
% Thesis: case 131 in every scenario.
s.fixed.caseOutputs.targetEllipse = {131, 'all'};

% The conditional posteriors of the weak parameters next to the all_six
% posterior of the case, with their statistics (conditional inversion,
% A.9), selected_posteriors. Cases. Thesis: case 131.
s.fixed.caseOutputs.conditionalPosteriors = 131;

%% A.11 Ratio-error curves (step ratio_error_curves) ----------------------

% How well the parameter values inside a posterior reproduce the four
% cycle-to-cycle pressure ratios of the observation (descriptive; no MCMC,
% nothing beyond the six pressures: the ratios are functions of them).
% For every draw of each replicate (never pooled), the GP mean is compared
% with the observation the posterior used: the ratio discrepancy d (units
% of the reference CV, 0.7), the level discrepancy, the four signed ratio
% errors and the double ratio, summarized in quantile bins of each
% parameter. The cells: scenario and design, the cases with a posterior
% (certified or healthy fallback; a list or 'all'), and a supplement (cases,
% their scenario; [] for none). Bins: equal-count bins of replicate 1's
% draws per parameter; quantiles: the band and the centre of each bin.
% Thesis: measurement_plus_gp, all_six, all 20 cases; supplement case 113,
% gp_only; 20 bins; 0.10, 0.50, 0.90.
s.fixed.ratioErrorCurves.scenario = 'measurement_plus_gp';
s.fixed.ratioErrorCurves.design = 'all_six';
s.fixed.ratioErrorCurves.cases = 'all';
s.fixed.ratioErrorCurves.supplementCases = 113;
s.fixed.ratioErrorCurves.supplementScenario = 'gp_only';
s.fixed.ratioErrorCurves.bins = 20;
s.fixed.ratioErrorCurves.quantiles = [0.10 0.50 0.90];

%% A.12 Parameter combinations (step combinations) -----------------------

% Which combinations of the parameters the posteriors determine
% (descriptive; no MCMC): per cell and replicate (never pooled) the
% eigen-directions of the posterior covariance in prior-standardized
% coordinates (as the eigen-analysis, A.7), the best- and worst-determined
% combinations of the weak pair (A.7), also in log form (a power law), the
% marginal of each best combination against its prior, and the
% compensation predicted at the truth by the GP's whitened Jacobian (the
% design study's step, A.8). The cells: cases (a list or 'all': every case
% of the inversion, A.6) and scenarios, design all_six (the only value
% implemented). Thesis: 'all'; measurement_plus_gp and gp_only; all_six.
s.fixed.combinations.cases = 'all';
s.fixed.combinations.scenarios = {'measurement_plus_gp', 'gp_only'};
s.fixed.combinations.design = 'all_six';

% The prior sample: the prior distributions of the combinations and the
% prior mean and SD of the log coordinates. Size and seed. Thesis: 100000,
% 20291531.
s.fixed.combinations.priorSampleSize = 100000;
s.fixed.combinations.priorSampleSeed = 20291531;

% The log form takes the natural log of these weak-pair parameters (the
% other one enters as its model coordinate: log10 k0 is a logarithm
% already). A cell uses it when every draw of both replicates is positive
% and each replicate's quantile below lies at least the share of the prior
% range above the lower bound; otherwise the cell reports it as not
% applicable, with the reason. Thesis: m3_e_RD; 0.01, 0.05.
s.fixed.combinations.logForm.parameters = {'m3_e_RD'};
s.fixed.combinations.logForm.quantile = 0.01;
s.fixed.combinations.logForm.rangeShare = 0.05;

% "Identified combination" (a description, not a statistical test): the
% best weak-pair combination's SD ratio is at most this factor times the
% smaller of the two individual SD ratios. Thesis: 0.5.
s.fixed.combinations.labelFactor = 0.5;

%% A.13 GP-mean inversion (step gp_mean_inversion) -----------------------

% A fourth inversion scenario, gp_mean_det ("GP mean, COMSOL data"): the
% held-out COMSOL pressures of the truths (the observations of
% measurement_plus_gp and gp_only) inverted with the GP predictive mean as
% the forward model and the variance of gp_self_det, the floor of A.2 only
% (no GP predictive variance, no measurement noise). Prior, sampler, chain
% levels, replicates, health checks and certification are those of the
% canonical inversion (A.6); a cell that does not certify is a healthy
% fallback when one of its requests is healthy (the highest level first,
% replicate 1 first), otherwise unavailable. Seeds: the MCMC rule (0.6)
% with scenario number 4 (checked against every seed used before). Its
% figures and tables compare the posterior SD and the error per parameter
% with the all_six cells of the three canonical scenarios, read from the
% shipped results (nothing recomputed). With the floor as the only variance
% the posterior is practically a point, which AIES cannot sample; the
% scenario's answer is that point, the best fit below.

% The cases: 'all' (every case of the inversion, A.6) or a list of its
% CaseIDs. Thesis: 'all', the 20 canonical truths.
s.fixed.gpMeanInversion.cases = 'all';

% The observation design. Thesis: all_six (the only design implemented).
s.fixed.gpMeanInversion.design = 'all_six';

% The case whose posterior marginals in the four scenarios are drawn in one
% figure of the analysis. Thesis: 119.
s.fixed.gpMeanInversion.showcaseCase = 119;

% The best fit (the scenario's answer: with the floor as the only variance
% the posterior is practically a point, which AIES cannot sample). Per
% case theta* = argmin sum_i (y_i - mu_i(theta))^2: the six held-out
% COMSOL pressures against the GP mean, within the prior bounds, in model
% coordinates (inversion.gp_mean_best_fit; no sampler). lsqnonlin
% (trust-region-reflective) on the six residuals, the parameters scaled to
% [0, 1], the Jacobian by central differences of step jacobianStep (scaled),
% inside MultiStart from start points of a Latin hypercube (lhsdesign after
% rng(seed, 'twister')). starts: the number of start points; when fewer
% than minimumStartsAtBest of them reach the best minimum, the search runs
% again with the next number. Thesis: [200 1000], 5, seed 20291532;
% tolerances 1e-12 (function, step), 1e-10 (optimality), 400 iterations,
% 4,000 evaluations, step 1e-6; two local solutions are one minimum within
% 1e-4 (scaled) and 1e-6 (objective, relative); a component within 1e-6
% (scaled) of a bound is on it.
s.fixed.gpMeanInversion.bestFit.starts = [200 1000];
s.fixed.gpMeanInversion.bestFit.minimumStartsAtBest = 5;
s.fixed.gpMeanInversion.bestFit.seed = 20291532;
s.fixed.gpMeanInversion.bestFit.functionTolerance = 1e-12;
s.fixed.gpMeanInversion.bestFit.stepTolerance = 1e-12;
s.fixed.gpMeanInversion.bestFit.optimalityTolerance = 1e-10;
s.fixed.gpMeanInversion.bestFit.maxIterations = 400;
s.fixed.gpMeanInversion.bestFit.maxFunctionEvaluations = 4000;
s.fixed.gpMeanInversion.bestFit.jacobianStep = 1e-6;
s.fixed.gpMeanInversion.bestFit.distinctXTolerance = 1e-4;
s.fixed.gpMeanInversion.bestFit.distinctFunctionTolerance = 1e-6;
s.fixed.gpMeanInversion.bestFit.boundTolerance = 1e-6;

%% ======================================================================
%% B  GENERALIZED ROUTE (run_generalized_study)
%% ======================================================================
% Four material parameters and three protocol controls -> the six closing
% pressures; the protocol screening and the confirmation experiment.

%% B.1 Dataset and parameters ---------------------------------------------

% The COMSOL dataset: one row per designed case with its requested inputs,
% the outcomes of its D2 and D6 runs and its six pressures
% (data/README.md). CSV file. Thesis: the 1,000 designed cases of the
% snapshot of 20 September 2026 (939 usable).
s.generalized.dataset.file = 'data/generalized/generalized_dataset.csv';

% The snapshot the dataset was frozen as. The emulator calibration of B.3
% records the snapshot it was fitted on and must name this one. Thesis:
% '20260920T221107Z'.
s.generalized.dataset.snapshot = '20260920T221107Z';

% The six closing pressures (mbar), in model order. Thesis: these six.
s.generalized.dataset.outputColumns = {'pcl1_D2_mbar', 'pcl2_D2_mbar', 'pcl3_D2_mbar', ...
    'pcl1_D6_mbar', 'pcl2_D6_mbar', 'pcl3_D6_mbar'};

% Share of the complete cases kept external. Thesis: 0.2 (82 of 939 cases
% external).
s.generalized.dataset.externalFraction = 0.2;

% Quality checks of the dataset: tolerance of the coordinate
% transforms, the smallest drop between adjacent suction cycles (mbar; a
% smaller drop is not monotone), the rounding scale of the pressures (mbar),
% the share of non-monotone cases that triggers a review, and the
% standardized mean difference above which a protocol variable counts as
% associated with missingness. Thesis: 1e-12, 0, 0.01, 0.15, 0.5.
s.generalized.dataset.transformTolerance = 1e-12;
s.generalized.dataset.monotonicToleranceMbar = 0;
s.generalized.dataset.roundingScaleMbar = 0.01;
s.generalized.dataset.monotonicReviewFraction = 0.15;
s.generalized.dataset.protocolAssociationSMD = 0.5;

% The seven inputs (learning coordinates), their units, bounds (the prior
% and the design space) and the physical bounds of the dataset's inputs.
% Thesis: the four material parameters as in A.1 (log10(k0) from log10
% 0.005 to log10 0.05) and log10 |suction rate| log10 0.2 to log10 2
% kPa/s, hold 10-45 s, pause 5-25 s.
s.generalized.parameters.names = {'m3_f_RD', 'm3_e_RD', 'log10_k0_RD', 'Thickness_RD', ...
    'log10_abs_suction_rate', 'hold_dur_s', 'pause_dur_s'};
s.generalized.parameters.units = {'-', '-', 'log10(mm^4/(N s))', 'mm', 'log10(kPa/s)', ...
    's', 's'};
s.generalized.parameters.bounds = [50 300; 0 1000; log10(0.005) log10(0.05); 1.0 2.5; ...
    log10(0.2) log10(2.0); 10 45; 5 25];
s.generalized.parameters.physicalBounds = [50 300; 0 1000; 0.005 0.05; 1.0 2.5; ...
    -2.0 -0.2; 10 45; 5 25];

% The default suction protocol (the fixed route's): signed suction rate
% (kPa/s), hold and pause (s). Thesis: -0.4, 30, 12.
s.generalized.defaultProtocol.suctionRate = -0.4;
s.generalized.defaultProtocol.holdSeconds = 30;
s.generalized.defaultProtocol.pauseSeconds = 12;

%% B.2 Measurement model --------------------------------------------------

% As A.2, for the screening and the confirmation. Thesis: 0.08, 1e-6.
s.generalized.measurement.cv = 0.08;
s.generalized.measurement.minimumSigma = 1e-6;

%% B.3 Surrogates ---------------------------------------------------------

% The steps after the dataset use the approved package: the dataset, GP
% and PCE of thesis_results/generalized with the calibration below. Erion
% Isljami approved it on 21 September 2026 for local scientific use (not for
% production), the GP with the calibration of gamma 0.48225.
% Which models the step 'surrogates' fits, as A.3:
%   'use_shipped'           none: the approved package (no fitting)
%   'refit_audit_selected'  the step 'surrogates' refits them under the fit
%                           policy below (kernel, multi-start rule of
%                           outputs 1 and 3, seeds); the later steps keep
%                           the approved package, whose calibration belongs
%                           to the approved models
%   'refit_manual'          the step 'surrogates' refits them with the
%                           kernel, optimizer and nugget of s.generalized.surrogates.manual
% Thesis: 'use_shipped'.
s.generalized.surrogates.modelSource = 'use_shipped';

% The fit policy: the audit's selection (Matern-3/2, five declared starts
% for outputs 1 and 3). JSON record. Thesis: the approved policy.
s.generalized.surrogates.fitPolicy = 'config/generalized_gp_fit_policy.json';

% The emulator-error calibration of the approved GP (gamma 0.48225). JSON.
% Thesis: the approved calibration (candidate v3).
s.generalized.surrogates.emulatorCalibration = 'config/generalized_emulator_calibration.json';

% The GP of 'refit_manual', as A.3 (a manual refit fits every output once,
% without the multi-start rule of the fit policy; fixedTheta: 6 rows, 7
% columns; only with nugget 0; UQLab's default bounds of theta and sigma^2
% as in A.3: 13 of the 42 approved length scales end at 10). Thesis: the
% approved GP's values, [].
s.generalized.surrogates.manual.kernel = 'Matern-3_2';
s.generalized.surrogates.manual.trend = 'ordinary';
s.generalized.surrogates.manual.correlation = 'Ellipsoidal';
s.generalized.surrogates.manual.optimizer = 'HGA';
s.generalized.surrogates.manual.nugget = 1e-10;
s.generalized.surrogates.manual.fixedTheta = [];

% Cross-validation folds of every generalized GP refit. Thesis: 5.
s.generalized.surrogates.gpFolds = 5;

% The PCE of a refit: a staged degree search (the initial degrees; the
% escalation degrees when no initial degree is adequate), the q-norm, the
% UQLab method, cross-validation folds and the adequacy thresholds of the
% fold NRMSE (mean, maximum). Thesis: 1:3, 4:6, 0.75, 'BCS', 5, 0.15, 0.30.
s.generalized.surrogates.pce.initialDegrees = 1:3;
s.generalized.surrogates.pce.escalationDegrees = 4:6;
s.generalized.surrogates.pce.qNorm = 0.75;
s.generalized.surrogates.pce.method = 'BCS';
s.generalized.surrogates.pce.folds = 5;
s.generalized.surrogates.pce.adequateMeanNRMSE = 0.15;
s.generalized.surrogates.pce.adequateMaxFoldNRMSE = 0.30;

%% B.4 Sensitivity --------------------------------------------------------

% Sobol indices over the seven inputs: sample size and highest interaction
% order; the support audit's sample size and seed; the tolerance of the
% campaign bounds; the bootstrap of the fixed surrogate (on/off, base sample
% size, replicates, seed). Thesis: 40000 and 2; 50000 and 20291520; 1e-8;
% true, 5000, 100, 20291522.
s.generalized.sensitivity.sobolSamples = 40000;
s.generalized.sensitivity.sobolOrder = 2;
s.generalized.sensitivity.supportAuditSamples = 50000;
s.generalized.sensitivity.supportAuditSeed = 20291520;
s.generalized.sensitivity.campaignBoundsTolerance = 1e-8;
s.generalized.sensitivity.bootstrap.enabled = true;
s.generalized.sensitivity.bootstrap.baseSize = 5000;
s.generalized.sensitivity.bootstrap.replicates = 100;
s.generalized.sensitivity.bootstrap.seed = 20291522;

%% B.5 Default-protocol comparison ----------------------------------------

% The generalized surrogate at the default protocol against the fixed
% route's COMSOL results (the dataset of A.1): the step
% default_protocol_comparison, switched in 0.2
% (s.run.generalized.default_protocol_comparison). The fixed CSV does not
% carry the provenance of its COMSOL model (constitutive model, probe
% geometry, the closing-pressure extraction, units, default protocol and its
% phases): the source given here resolves these eight fields; '' leaves them
% unresolved (status COMPATIBILITY_UNRESOLVED). Thesis: 'author statement:
% same COMSOL model' (both datasets come from the same COMSOL model).
s.generalized.defaultProtocolComparison.provenanceSource = 'author statement: same COMSOL model';

%% B.6 Protocol screening (steps screen, objective_supplement, rankings) --

% The screen evaluates the six pressures (all_six). The two target
% parameters (the weak pair), the protocol grid (levels per protocol
% control, within the bounds of B.1), the material points (a seeded Latin
% hypercube) and its seed. Thesis: m3_e and log10(k0); 9 levels (729
% protocols, plus the default); 1000 points, seed 20260519.
s.generalized.screening.targetParameters = {'m3_e_RD', 'log10_k0_RD'};
s.generalized.screening.protocolLevels = 9;
s.generalized.screening.materialPoints = 1000;
s.generalized.screening.materialSeed = 20260519;

% The local Fisher information: finite-difference step (in the unit box)
% and the covariance cases (measurement only; measurement plus GP error;
% the screen compares both, in this order: the only values implemented).
% The rankings order the protocols by the primary metric, the mean largest
% eigenvalue of the target pair's posterior covariance proxy. Thesis values
% below.
s.generalized.screening.finiteDifferenceStep = 1e-3;
s.generalized.screening.covarianceCases = {'measurement_covariance', ...
    'operational_measurement_plus_emulator'};

% Numerical tolerances: duplicate protocols, equal scores, symmetric and
% positive semi-definite matrices. Thesis: 1e-12, 1e-12, 1e-10, 1e-10.
s.generalized.screening.candidateDuplicateTolerance = 1e-12;
s.generalized.screening.comparisonTolerance = 1e-12;
s.generalized.screening.symmetryTolerance = 1e-10;
s.generalized.screening.psdTolerance = 1e-10;

%% B.7 Confirmation (steps export_design ... compare) ----------------------

% The confirmation experiment simulates every material with every protocol
% in COMSOL (probes D2 and D6) and inverts each observation; each focused
% protocol is compared with the reference protocol (the first row below).
% The step export_design writes the design and its COMSOL run list; the
% observations join the design by the exact values of the materials and
% protocols. Changing a material or protocol defines a new experiment,
% which needs its own COMSOL simulations.

% The materials: CaseIDs of the fixed dataset (A.1), whose parameter values
% are the truths, in the order of the design, or 'all'. Thesis: the 20
% canonical inversion truths, in their order.
s.generalized.confirmation.materials = [131 113 230 232 42 93 172 12 119 220 206 48 96 ...
    215 83 146 166 246 249 116];

% The protocols, one row each: label (letters, digits and '_', at most 40;
% it names the cells), the screening objective the protocol targets (''
% for the reference), signed suction rate (kPa/s, negative), hold (s) and
% pause (s). The first row is the reference; each other row targets a
% different objective: 'joint_weak' (the weak pair m3_e and log10 k0),
% 'permeability' (log10 k0), 'dissipation' (m3_e). The GP reads a protocol
% as log10 of the rate's magnitude, hold and pause, within the bounds of
% B.1. Or 'from_screening': the default protocol (B.1) and the protocol
% ranked first for each objective of 'objectives' below among the eligible
% protocols of the screen (operational covariance), labelled
% <objective role>_focused. Thesis: the four protocols of the design
% approved on 21 September 2026, exact values (the default protocol and
% the three objective winners of the screen: grid protocols 369, 368 and
% 315).
s.generalized.confirmation.protocols = { ...
    'default',              '',             -0.4,                30,     12; ...
    'joint_focused',        'joint_weak',   -2,                  27.5,   15; ...
    'permeability_focused', 'permeability', -1.4997884186649117, 27.5,   15; ...
    'dissipation_focused',  'dissipation',  -2,                  40.625, 12.5};

% The objectives whose screening leaders 'from_screening' takes, in order.
% Thesis: joint_weak, permeability, dissipation (not used: the protocols
% above are given explicitly; 'from_screening' gives the same three).
s.generalized.confirmation.objectives = {'joint_weak', 'permeability', 'dissipation'};

% The accepted COMSOL observations of the design (one row per material and
% protocol; data/README.md), which the step prepare reads when the run did
% not import them itself. CSV file. Thesis:
% data/confirmation/confirmation_observations.csv (the observations
% accepted on 3 October 2026).
s.generalized.confirmation.observations = 'data/confirmation/confirmation_observations.csv';

% The inverse problem of every cell: likelihood scenario (measurement_plus_gp,
% the only value implemented), observation design and the target parameters
% of the comparisons. The design is that of every cell, comparison and
% aggregate: all_six (the six pressures) or d2_only (the three pressures of
% probe D2); a design row is accepted when the reviewer accepts its pressures
% of this design. Thesis: measurement_plus_gp, d2_only, m3_e and log10(k0)
% (d2_only: Erion's decision of 2 Oct 2026, before any confirmation posterior
% existed; under the three focused protocols the D6 probe mostly stops in the
% hold of cycle 2 or fails in COMSOL, and all_six would leave 6 of the 60
% comparisons).
s.generalized.confirmation.scenario = 'measurement_plus_gp';
s.generalized.confirmation.design = 'd2_only';
s.generalized.confirmation.targetParameters = {'m3_e_RD', 'log10_k0_RD'};

% A second observation design, descriptive only, inverted on the complete
% pairs alone: the materials and focused protocols whose focused and default
% rows both have every pressure of this design accepted (with the default
% cell of each such material). Its results describe those pairs, not the
% protocols. all_six or d2_only, different from the design above; '' for
% none. Thesis: all_six.
s.generalized.confirmation.completePairsDesign = 'all_six';

% Relative tolerance with which a material and protocol count as a training
% point of the generalized GP (the overlap columns of the comparisons, a
% description of the cohort), and the representative overlay pairs per
% figure. Thesis: 1e-12, 3.
s.generalized.confirmation.coordinateTolerance = 1e-12;
s.generalized.confirmation.overlayPairs = 3;

% The showcase material of the results (the marginals and the corner plot of
% its four protocols), by a rule fixed before the results exist, never by the
% most favourable outcome: 'first_all_certified' (the first material of the
% list above whose four cells are certified; no showcase when none is) or one
% MaterialCaseID. Thesis: 'first_all_certified'.
s.generalized.confirmation.showcase = 'first_all_certified';

% AIES and certification of the confirmation cells, as A.6. Thesis: the
% values of the fixed inversion.
s.generalized.confirmation.mcmc.levels = [2000 5000];
s.generalized.confirmation.mcmc.burnIn = 0.5;
s.generalized.confirmation.mcmc.thinning = 1;
s.generalized.confirmation.mcmc.walkers = 40;
s.generalized.confirmation.mcmc.stretchScale = 2;
s.generalized.confirmation.mcmc.initialization = 'latin_hypercube';
s.generalized.confirmation.mcmc.replicates = [1 2];
s.generalized.confirmation.certification.maxRankSplitRhat = 1.05;
s.generalized.confirmation.certification.minBulkESS = 400;
s.generalized.confirmation.certification.minTailESS = 200;
s.generalized.confirmation.certification.maxRelativeSdMCSE = 0.05;
s.generalized.confirmation.certification.maxMedianRangeDifference = 0.03;
s.generalized.confirmation.certification.maxQuantileRangeDifference = 0.05;
s.generalized.confirmation.certification.maxNormalizedWasserstein = 0.05;
s.generalized.confirmation.certification.correlationDifferenceWarning = 0.15;
s.generalized.confirmation.certification.minIndependentReplicates = 2;
s.generalized.confirmation.certification.frozenMovementFraction = 0.01;
s.generalized.confirmation.certification.minimumUniqueStates = 2;
s.generalized.confirmation.certification.duplicateSampleTolerance = 1e-12;
s.generalized.confirmation.certification.maxDuplicateFraction = 0;

%% B.8 Parameter combinations of the confirmation (step combinations) ----

% The parameter combinations of the fixed route (A.12) on the
% confirmation's posteriors (descriptive; no MCMC): per material, protocol,
% observation design and replicate (never pooled), in prior-standardized
% coordinates, the best- and worst-determined combinations of the weak pair
% (the confirmation's target parameters, B.7), also in log form (a power
% law), the marginal of each best combination against its prior, and their
% consensus per protocol; then, on the materials with a posterior under
% both, how each focused protocol rotates or sharpens the best combination
% of the weak pair against the default protocol, next to the difference
% between the two replicates of each cell. The eigen-analysis uses the
% thresholds of A.7. The designs: a list of the confirmation's designs or
% 'all' (the design and the complete pairs' design of B.7). Thesis: 'all'.
s.generalized.combinations.designs = 'all';

% The prior sample (size, seed), the log form and the label, as in A.12.
% Thesis: the values of A.12 (the same prior sample: the material
% parameters have the same bounds).
s.generalized.combinations.priorSampleSize = 100000;
s.generalized.combinations.priorSampleSeed = 20291531;
s.generalized.combinations.logForm.parameters = {'m3_e_RD'};
s.generalized.combinations.logForm.quantile = 0.01;
s.generalized.combinations.logForm.rangeShare = 0.05;
s.generalized.combinations.labelFactor = 0.5;
end
