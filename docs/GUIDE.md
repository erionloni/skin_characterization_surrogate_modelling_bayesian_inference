# Guide

The code of the thesis *Surrogate Modelling and Bayesian Inference for Skin Characterization from Suction
Experiments*: how to install it, reproduce the thesis results, change settings, rerun any part of the analysis and
use the code for new work. The science (the model, the methods and the interpretation) is in the thesis; this guide
describes the code that produced it.

1. [Installation](#1-installation)
2. [Quick start](#2-quick-start)
3. [The settings file](#3-the-settings-file)
4. [Entry points and steps](#4-entry-points-and-steps)
5. [What each step computes](#5-what-each-step-computes)
6. [Outputs and the layout of the thesis results](#6-outputs-and-the-layout-of-the-thesis-results)
7. [The data](#7-the-data)
8. [Reproducing and rerunning](#8-reproducing-and-rerunning)
9. [Reproducibility](#9-reproducibility)
10. [Running heavy steps on a computing cluster](#10-running-heavy-steps-on-a-computing-cluster)
11. [Troubleshooting](#11-troubleshooting)
12. [Using the code for new work](#12-using-the-code-for-new-work)

Appendices: [A. Glossary](#appendix-a-glossary), [B. Thesis figure map](#appendix-b-thesis-figure-map).

## 1. Installation

| To … | you need |
|---|---|
| reproduce the thesis figures and tables | MATLAB, nothing else |
| rerun any step | also [UQLab](https://www.uqlab.com) 2.3.0, and for fitting the surrogates the Optimization and Global Optimization Toolboxes (the best fit of the GP-mean inversion, [section 12](#12-using-the-code-for-new-work), also needs them and the Statistics and Machine Learning Toolbox) |

The code was tested with MATLAB R2024a (the computing cluster of the thesis runs) and R2025b (a workstation); it
needs at least R2021a.

1. Download or clone the repository into a short folder, at most about 80 characters long (for example
   `C:\work\skin-suction`). The files of the repository have paths of at most 120 characters, but the bookkeeping of
   a run folder nests deeper, and MATLAB cannot read a file whose path is longer than 260 characters on Windows.
2. Start MATLAB in the repository folder and run `check_installation`. It checks:
   - the MATLAB release and the functions the figures need;
   - the repository folders, the settings file, the configuration records, the datasets and the shipped results;
   - the toolboxes and UQLab, which only reruns need.

   It ends with an error if something that reproducing needs is missing.
3. For reruns, set the UQLab folder in `study_settings.m` (`s.paths.uqlabRoot`) or the environment variable
   `UQLAB_ROOT`. `check_installation('StartUQLab',true)` then also starts UQLab once.

## 2. Quick start

```matlab
check_installation                                   % is everything in place?
reproduce_thesis_results                             % every thesis figure and table (about 35-60 min)
run_fixed_study('Mode','rerun','Scale','example')    % a small rerun of the fixed study (10-30 min, needs UQLab)
```

`reproduce_thesis_results` writes `runs/thesis_<time>/`, laid out like `thesis_results/`, with a `README.md` that
indexes every figure and table. It fits no model, runs no MCMC and needs no UQLab.

## 3. The settings file

`study_settings.m` is the one file you edit, and it is the thesis configuration: every value in it is the value the
thesis used. It holds every choice of both routes, each with a comment (what it does, the allowed values, the thesis
value and what changing it means). Its table of contents:

| Section | Holds |
|---|---|
| 0 General | paths (`s.paths`), what to run (`s.run`: mode, run name, plan, scale, confirmation of expensive steps, and the run switches `s.run.fixed` and `s.run.generalized`: one per step and per analysis inside a step), computation and batch sizes (`s.compute`), figures (`s.figures`), messages (`s.logging`), seeds (`s.seeds`: the master seed, the tables of recorded seeds in `config/seeds/` and the rules for new requests), derived features (`s.features`: the reference CV, the yardstick of the ratio-error curves; the feature catalog of the feature sensitivity and the feature accuracy, and its stability limit; the bootstrap, the gridded outputs and the time step of their grid for the feature accuracy) |
| A Fixed route (`s.fixed`) | A.1 dataset and parameters with their prior bounds; A.2 measurement model; A.3 surrogates (`modelSource`); A.4 surrogate audit; A.5 sensitivity; A.6 inversion (cases, scenarios, observation designs, AIES settings, escalation, certification thresholds); A.7 recovery (eigen-analysis, feature reconstruction, second-mode check); A.8 design study; A.9 conditional inversion (the condition table, the campaign rows, cases, the accepted baseline statuses, the reuse of shipped cells); A.10 case outputs; A.11 ratio-error curves (the cells, the bins and the quantiles); A.12 parameter combinations (the cells, the prior sample, the log-form thresholds, the label factor); A.13 GP-mean inversion (the cases, the design, the showcase case, the best fit's search: starts, seed, tolerances) |
| B Generalized route (`s.generalized`) | B.1 dataset and parameters; B.2 measurement model; B.3 surrogates (`modelSource`, the approved package); B.4 sensitivity (sample size and order of its own); B.5 default-protocol comparison (the provenance source that resolves the fixed CSV's eight missing provenance fields; thesis: the author's statement that both datasets come from the same COMSOL model); B.6 protocol screening; B.7 confirmation (materials, protocols, observations); B.8 the parameter combinations of the confirmation (as A.12) |

- **Validated.** A run stops when a setting is missing ("setting <name> missing in section <section> of the
  settings file"), when a name is unknown (the message names the closest valid one) or when a value is invalid (the
  message says what the setting accepts). Nothing has a hidden default: the code reads every value from this file.
- **Selections** (cases, scenarios, designs, materials, protocols) take a list or `'all'`.
- **Run switches** (section 0.2): one true/false switch per step (`s.run.fixed.inversion`,
  `s.run.generalized.screen`, ...) and per analysis inside a step (the recovery's `coverage_recovery`,
  `eigen_analysis`, `feature_reconstruction`, `error_budget`, `second_mode_check`). In reproduce mode they choose
  what is rendered, in rerun mode what is computed; the thesis values are all true. `'Steps'` overrides the step
  switches for one call (the run record keeps it); the analysis switches still apply inside its steps. A
  switched-on step runs only when the results it needs exist: computed in the same call, present in the run folder,
  or shipped where that is allowed (the shipped models with `modelSource` `'use_shipped'`, the shipped posterior
  draws, the approved generalized package); otherwise the call is refused before any computation, naming the
  missing results and the switch to turn on. Nothing is switched on for you, and no switch changes the method:
  health checks, certification and provider selection always apply. `'Plan',true` prints the steps of a call,
  which switch or `'Steps'` chose them, the source of every prerequisite (this run, shipped or missing) and the
  steps that are switched off or left out, with why (a rerun leaves out the steps whose results can only be the
  shipped ones, and `'Scale','example'` the steps without an example).
- **Surrogates.** `modelSource` per route: `'use_shipped'` (the thesis setting: the exact thesis models, nothing is
  fitted and the step `surrogates` is refused), `'refit_audit_selected'` (refit with the configuration the audit
  selected, from its records) or `'refit_manual'` (kernel, trend, correlation, optimizer and nugget of the settings;
  optionally fixed length scales instead of an optimization, for a GP without a nugget, since UQLab 2.3 always
  optimizes a GP with a nugget). The emulator calibrations were fitted for the thesis GPs: a GP with another kernel,
  trend, correlation, optimizer or nugget needs a calibration of its own, and a run refuses it before computing
  anything.
- **Fixed by the code.** A few settings show what an analysis is defined for and accept only that value (for
  example the two scenarios the posterior eigen-analysis compares); the message says so.
- **Records.** Large records stay files in `config/` and the settings select them: the seed tables, the two
  emulator calibrations, the audit's selection of the fixed surrogates and the generalized GP fit policy. The
  generalized steps after the dataset use the approved package: the shipped dataset, GP and PCE of
  `thesis_results/generalized/` with the generalized calibration.
- **One call.** The name-value options of an entry point override settings for one call, for example
  `run_fixed_study('Mode','rerun')`; for any other setting pass a changed copy, `'Settings',s`. The run record
  (`run_record.json`) keeps the options and the complete settings of every call. `help study.resolve_settings` lists
  every name-value option.

### How to change settings

Change a copy of the settings and pass it to the entry point, or edit `study_settings.m` itself.

**Choose what runs (the run switches, section 0.2).** Rerun the fixed route without the surrogate audit, its plan
first:

```matlab
s = study_settings();
s.run.fixed.surrogate_audit = false;
run_fixed_study('Mode','rerun','Settings',s,'Plan',true)
```

Only the eigen-analysis of the recovery, on the shipped posterior draws (no inversion in the run):

```matlab
s = study_settings();
s.run.fixed.coverage_recovery = false;
s.run.fixed.feature_reconstruction = false;
s.run.fixed.error_budget = false;
run_fixed_study('Mode','rerun','Steps',{'recovery'},'Settings',s)
```

The inversion on the shipped models: with the thesis setting `modelSource` `'use_shipped'` nothing is fitted, and the
plan shows the surrogates as `shipped`:

```matlab
run_fixed_study('Mode','rerun','Steps',{'inversion'},'Plan',true)
```

A call whose prerequisites are missing is refused before anything is computed, with the switch to turn on. The
inversion after a refit setting, without the refit:

```matlab
s = study_settings();
s.fixed.surrogates.modelSource = 'refit_manual';
run_fixed_study('Mode','rerun','Steps',{'inversion'},'Settings',s,'Plan',true)
```

prints the plan and why the call would be refused:

```text
        Steps chosen by 'Steps' (for this call, instead of the run switches of the settings, 0.2)
        Step                         Action   Estimated cost                                Notes
        dataset                      shipped  about 30 s                                    from the shipped results
        surrogates                   missing  about 1-2 min
        inversion                    run      computing cluster: 360 cells x 2 ensembles (days of CPU time) expensive; reads held-out outcomes
The call would be refused: Cannot run inversion: it needs the results of surrogates, which are neither computed in this call nor present in run "<run>" nor shipped.
Switch them on (s.run.fixed.surrogates in study_settings.m, section 0.2) or add them to 'Steps', or produce them first, for example:
  run_fixed_study('Steps',{'surrogates'},'Mode','rerun','RunName','<run>')
```

With the thesis setting `'use_shipped'` the same call plans the shipped models instead. An analysis that is computed
from another one in the same call is refused when that one is switched off (the error budget needs the feature
reconstruction), and so is a step whose analyses are all switched off.

**Render the outputs of other cases.** The case outputs are settings (A.10, `s.fixed.caseOutputs`). Every cell of
case 42, for example, rendered from the shipped draws into the case folder of a new run folder:

```matlab
s = study_settings();
s.fixed.caseOutputs.cells = {42, 'all', 'all'};          % rows {cases, scenarios, designs}
run_fixed_study('Steps',{'inversion'},'Settings',s)
```

`{'all','all','all'}` renders every cell with a posterior (277 cells, about 3 MB each, mostly the corner plots);
`'CornerGallery','all'` draws only the corner plot of every cell.

**Run only the surrogate audit.** It reads the shipped surrogates when the run has none of its own:

```matlab
run_fixed_study('Mode','rerun','Steps',{'surrogate_audit'},'Plan',true)              % its cost first
run_fixed_study('Mode','rerun','Steps',{'surrogate_audit'},'ConfirmExpensive',true)  % several hours
```

**Refit the surrogates with your own configuration.**

```matlab
s = study_settings();
s.fixed.surrogates.modelSource = 'refit_manual';
s.fixed.surrogates.manual.kernel = 'Matern-5_2';
run_fixed_study('Mode','rerun','Steps',{'surrogates'},'Settings',s)
```

This call is refused before anything is computed: the emulator calibration (`s.fixed.surrogates.emulatorCalibration`)
was fitted for the Matérn-3/2 GP of the thesis, and a GP with another kernel needs a calibration fitted for it.
With the thesis values of `s.fixed.surrogates.manual` the refit runs.

**Invert other cases, or one scenario or design.** The inversion step runs a grid: its cases (the complete external
cases of the fixed dataset; `s.fixed.inversion.cases`, `'all'`, or `'Cases'` for one call) × the three scenarios ×
the six designs, always all of them and in this order: a rerun of the inversion, and of the recovery, the design
study and the conditional inversion, which read its grid, refuses another scenario or design selection in A.6
("Exactly the three canonical scenarios are required in canonical order.", `inversion.build_inversion_grid`), so
keep those selections `'all'`. To run part of the grid, write its task table once and run cells by index;
`'PartialCampaign',true` publishes the cells run so far (the others stay missing). With `'all'` or more than 20 cases
in the settings, pass the cases with `'Cases'` in every call that names `'InversionCells'`, so that the indices are
checked against the right grid:

```matlab
run_fixed_study('Mode','rerun','Steps',{'inversion'},'Cases',11,'InversionCells','prepare', ...
    'ConfirmExpensive',true,'RunName','case11')    % writes <run>/_run/inversion/cell_task_table.csv: 18 cells
run_fixed_study('Mode','rerun','Steps',{'inversion'},'Cases',11,'InversionCells',3, ...
    'PartialCampaign',true,'ConfirmExpensive',true,'RunName','case11')   % measurement_plus_gp, d6_only
```

For one case the cells are numbered scenario by scenario (`measurement_plus_gp`, `gp_only`, `gp_self_det`), and
within a scenario by design (`all_six`, `d2_only`, `d6_only`, `cycle_1_only`, `ratios_only`,
`physics_guided_full_rank_six`): cell 3 is `measurement_plus_gp` with `d6_only`. A cell runs two ensembles of 2,000
steps (about 50 minutes each on a workstation) and, if they do not certify, two of 5,000 steps. For a trial,
`'DemonstrationSteps',[200 250]` in both calls shortens the chains (not thesis evidence; a run folder never mixes
chain lengths). A whole grid realistically needs a computing cluster
([section 10](#10-running-heavy-steps-on-a-computing-cluster)).

**Add a condition to the conditional inversion.** A condition is a row of the condition table (A.9,
`s.fixed.conditionalInversion.conditions`): a label, a description and the parameters it fixes at the truth, by name.
The code derives the mask (1 = free) and records it in the run record. Thickness and log<sub>10</sub>(k<sub>0</sub>)
fixed together, run in `measurement_plus_gp` for every case:

```matlab
s = study_settings();
s.fixed.conditionalInversion.conditions(end+1,:) = {'G','log10_k0 and Thickness fixed at truth', ...
    {'log10_k0_RD','Thickness_RD'}};
s.fixed.conditionalInversion.cells(end+1,:) = {{'G'},{'measurement_plus_gp'}};
run_fixed_study('Mode','rerun','Steps',{'conditional_inversion'},'Settings',s, ...
    'ConfirmExpensive',true,'ConditionalCells','prepare')   % the cells, seeds and tasks; nothing is computed
```

The cells that the shipped results hold are taken from them (`reuseShippedCells`), so the task table lists only the
cells of the new condition. A new cell's seeds follow the settings' rule, with the
condition code of its fixed parameters (m<sub>3f</sub> 1, m<sub>3e</sub> 2, log<sub>10</sub>(k<sub>0</sub>) 4,
thickness 8), and are checked against every recorded seed. A parameter name with a typo, a label that is not in the
table, a condition that fixes every parameter or the same ones as another, and a cell listed twice are refused before
anything is computed, with what to change.

**Run a subset of the conditional inversion (a pilot).** E and F in `measurement_plus_gp` for the first five cases,
run again although the shipped results hold them:

```matlab
s = study_settings();
s.fixed.conditionalInversion.cases = [131 113 230 232 42];
s.fixed.conditionalInversion.cells = {{'E','F'},{'measurement_plus_gp'}};
s.fixed.conditionalInversion.reuseShippedCells = false;   % run them, do not take the shipped cells
run_fixed_study('Mode','rerun','Steps',{'conditional_inversion'},'Settings',s,'ConfirmExpensive',true)
```

## 4. Entry points and steps

| Entry point | What it does |
|---|---|
| `check_installation` | checks MATLAB, the repository, the settings, the data and the results; for reruns also UQLab and the toolboxes |
| `reproduce_thesis_results` | renders every thesis figure and table of both routes from `thesis_results/` |
| `run_fixed_study` | the fixed route: dataset, surrogates, sensitivity, inversion, recovery, design study, the conditional inversion, the ratio-error curves, the parameter combinations, the GP-mean inversion; the run switches (section 0.2) or `'Steps'` choose the steps |
| `run_generalized_study` | the generalized route: dataset, approved surrogates, assessment, default-protocol comparison, sensitivity, the protocol screening (screen, six design objectives, rankings) and the confirmation experiment (design export, observation import, inversion, comparison, the parameter combinations); the run switches or `'Steps'` choose the steps |
| `run_all_studies` | both routes end to end: in reproduce mode as `reproduce_thesis_results`; in rerun mode every switched-on step that later results build on, stopping before a step that needs a computing cluster, a human decision or `'ConfirmExpensive',true`, with the commands that continue (and those of the switched-on side analyses) |

Each entry point runs in reproduce mode by default and writes one run folder. `help <entry point>` lists its steps
and options. The costs below are rough guides for one workstation, taken from recorded runs.

### Fixed route

| Step | What it does | Needs | Cost of a rerun |
|---|---|---|---|
| `dataset` | Read the 452-case dataset, classify complete/partial cases and split 391 development / 61 external cases. | - | about 30 s |
| `surrogates` | Fit the six Gaussian-process and PCE surrogates on the development cases (`modelSource` `refit_audit_selected` or `refit_manual`; the thesis setting `use_shipped` uses the shipped models). | dataset | about 1-2 min |
| `surrogate_assessment` (reads held-out outcomes) | Predict the 61 held-out external cases with the surrogates. | surrogates | about 10 s |
| `surrogate_audit` (expensive) | Repeated kernel, seed and cross-validation audit of the surrogates on development cases only. | surrogates | several hours (hundreds of GP fits) |
| `feature_accuracy` (reads held-out outcomes) | How well the GP and PCE means reproduce every feature of the feature catalog (settings 0.7) on the 61 external cases, from the predictions that the assessment saved; a side analysis. | surrogate_assessment | seconds |
| `sensitivity` | Sobol and ARD sensitivity of the six closing pressures to the four material parameters. | surrogates | about 2 min |
| `feature_sensitivity` | Sobol indices of the derived features of the six pressures (the feature catalog of the settings, 0.7) on the sample of the ratio indices; a side analysis. | surrogates | about 1 min |
| `inversion` (expensive, reads held-out outcomes) | AIES Bayesian inversion: 20 truths × 3 scenarios × 6 designs = 360 cells, two ensembles per cell. | surrogates | computing cluster: 360 cells × 2 ensembles (days of CPU time) |
| `conditional_inversion` (expensive, reads held-out outcomes) | Inversions with material parameters fixed at the truth: the conditions and campaign of the settings (A.9; thesis A–D, 80 cells, and E, F, 80 cells). | inversion | computing cluster: 160 cells × 2 ensembles (A–F; a rerun takes the shipped ones) |
| `recovery` (reads held-out outcomes) | Coverage and recovery, posterior eigen-analysis, feature reconstruction and error budgets, and the second-mode check of one cell, on this run's inversion or on the shipped full posterior draws. | - | minutes to about 1 h (evaluates the GP at posterior draws) |
| `design_study` (reads held-out outcomes) | Fisher-information comparison of the six observation designs, on this run's inversion or on the shipped full posterior draws. | - | about 20 min |
| `ratio_error_curves` (reads held-out outcomes) | How well the draws of each posterior reproduce the observed cycle-to-cycle pressure ratios (the GP mean at every draw), on this run's inversion or on the shipped full posterior draws; a side analysis that no later step reads. | - | about 2 min |
| `combinations` (reads held-out outcomes) | Which combinations of the four parameters each posterior determines (per replicate), and the compensation the GP predicts at the truths, on this run's inversion or on the shipped full posterior draws; a side analysis. | - | about a minute |
| `gp_mean_inversion` (expensive, reads held-out outcomes) | A fourth scenario, `gp_mean_det` (settings A.13): the held-out COMSOL pressures with the GP mean as the forward model and the numerical floor only, 20 cells (AIES as for the inversion), and per case the best fit of the GP mean to the six pressures (no sampler); a side analysis. | surrogates | computing cluster: 20 cells × 2 ensembles (6-10 h per cell on one CPU, all escalated); the best fit about 1 h |
| `figures` | Render the fixed-route figures and tables from the saved results. | recovery, design_study | about 10 min |

### Generalized route

| Step | What it does | Needs | Cost of a rerun |
|---|---|---|---|
| `dataset` | Read the 939-case generalized dataset (4 material + 3 protocol inputs) and split 857 development / 82 external cases. | - | about 1-1.5 min |
| `surrogates` (expensive) | Refit the generalized surrogates (`modelSource` `refit_audit_selected`: the approved fit policy with the thesis seeds; `refit_manual`); the later steps keep the approved package (Matérn-3/2, γ = 0.48225). | dataset | about 1.5 h (outputs 1 and 3: five starts each; the others 1-4 min) |
| `surrogate_assessment` (reads held-out outcomes) | Predict the 82 held-out external cases with the approved surrogates. | surrogates | about 1 min |
| `feature_accuracy` (reads held-out outcomes) | How well the approved GP and the PCE reproduce every feature of the feature catalog on the 82 external cases, each at its own protocol, from the predictions that the assessment saved; a side analysis. | surrogate_assessment | seconds |
| `default_protocol_comparison` (reads held-out outcomes) | Compare the generalized surrogate at the default protocol with fixed-route COMSOL results. | surrogates | about 1 min |
| `sensitivity` | Sobol sensitivity of the six pressures to the four material and three protocol inputs. | surrogates | about 8 min |
| `feature_sensitivity` | Sobol indices of the derived features over the seven inputs, on the sample of the derived-feature indices; a side analysis. | surrogates | about 4 min |
| `surrogate_audit` (expensive, shipped as evidence; not rerun) | The 1,050-fit kernel, seed and cross-validation audit on development cases only. | dataset | many hours (1,050 GP fits) |
| `screen` (expensive) | Protocol screening: local Fisher information of 730 candidate protocols over 1,000 material states. | - | about 1 h |
| `objective_supplement` | Full four-parameter covariance for the six design objectives, both covariance views. | screen | about 30 min |
| `rankings` | Rank the 730 protocols under the six objectives (primary: mean largest weak-pair eigenvalue). | screen, objective_supplement | seconds |
| `export_design` | Write the confirmation design of the settings (thesis: 20 materials × 4 protocols), its COMSOL run list (160 D2/D6 probe solves) and the screen's proxy of its protocols in the confirmation's observation designs. | - | about two minutes |
| `import_observations` | Join the reviewed COMSOL observations to the design by their values and accept them. | - | seconds |
| `prepare` | Prepare one inverse cell per material and protocol (thesis: 80; four unknowns, protocol known), their seeds and task table. | import_observations | about a minute |
| `run_cells` (expensive) | AIES inversion of the prepared cells (any subset per call, e.g. one job per cell on a cluster). | prepare | computing cluster: 82 cells × 2 ensembles (about 850 core-hours) |
| `compare` | Certify the cells and compare each selected protocol with the shared reference (thesis: 60 paired comparisons). | run_cells | minutes |
| `combinations` | Which combinations of the weak pair each confirmation posterior determines (per replicate), and how each focused protocol rotates or sharpens the best one against the default protocol, on this run's confirmation or on the shipped draws. | - | about a minute |
| `figures` | Render the generalized-route figures and tables (screening and confirmation included) from the saved results. | dataset | minutes |

## 5. What each step computes

A short description of each step, with the settings the thesis used and the functions that implement it (in
brackets). The thesis gives the reasoning and the results.

**The forward problem.** A suction probe (D2 or D6) applies repeated suction cycles to the skin; the COMSOL model
predicts the six **closing pressures** (mbar, as magnitudes), cycles 1-3 of each probe, in this order:
`pcl1_D2_mbar`, `pcl2_D2_mbar`, `pcl3_D2_mbar`, `pcl1_D6_mbar`, `pcl2_D6_mbar`, `pcl3_D6_mbar`. The fixed route maps
the four material parameters θ to them at the default protocol, y = f(θ); the generalized route adds the three
protocol inputs φ as known controls, y = f(θ, φ). The inverse problem infers θ from measured closing pressures; the
protocol is always known.

| Parameter | Code name | Range (uniform prior) | Unit |
|---|---|---|---|
| elastic-fibre coefficient m<sub>3f,RD</sub> | `m3_f_RD` | 50 – 300 | – |
| dissipative-fibre coefficient m<sub>3e,RD</sub> | `m3_e_RD` | 0 – 1000 | – |
| permeability, log<sub>10</sub>(k<sub>0,RD</sub>) | `log10_k0_RD` | log<sub>10</sub>(0.005) – log<sub>10</sub>(0.05) | k<sub>0</sub> in mm⁴/(N·s) |
| reticular-dermis thickness t<sub>RD</sub> | `Thickness_RD` | 1.0 – 2.5 | mm |
| suction rate, log<sub>10</sub>(\|rate\|) (generalized) | `log10_abs_suction_rate` | log<sub>10</sub>(0.2) – log<sub>10</sub>(2.0) | rate in kPa/s (default 0.4) |
| hold duration (generalized) | `hold_dur_s` | 10 – 45 | s (default 30) |
| pause duration (generalized) | `pause_dur_s` | 5 – 25 | s (default 12) |

The surrogates, priors and posteriors work in these *model coordinates*, with the permeability as
log<sub>10</sub>(k<sub>0</sub>); the datasets store k<sub>0</sub> itself, and the code takes the logarithm once, when
it reads them.

**`dataset`** (`data.build_dataset`, `data.build_generalized_dataset`). Reads the dataset table, applies its quality
rules, classifies complete cases (all six pressures) and partial cases (some of them, used for training only), and
holds out complete cases by material group with a fixed seed, so no material appears on both sides: 391
development / 61 external cases on the fixed route, 857 / 82 on the generalized route. The 20 inversion truths are
external cases of the fixed route: 131, 113, 230, 232, 42, 93, 172, 12, 119, 220, 206, 48, 96, 215, 83, 146, 166,
246, 249, 116.

**`surrogates`** (`surrogates.train_gp`, `surrogates.train_pce`). One Gaussian process per closing pressure:
ordinary Kriging with a Matérn-3/2 kernel and one length scale per input, nugget 10⁻¹⁰, hyperparameters minimizing
the leave-one-out error with UQLab's hybrid genetic algorithm, trained on every development case that observes the
output (fixed: 355, 347, 346, 357, 341, 282 cases; generalized: 758, 758, 735, 721, 719, 385). The optimization
keeps UQLab's default bounds: length scales θ from 10⁻³ to 10 in UQLab's scaled input coordinates, the process
variance σ² (optimized with them) from (0.1 SD)² to (10 SD)² of the output's training values, and the nugget a fixed
noise variance. 9 of the 24 fixed and 13 of the 42 generalized length scales end at the upper bound 10; the
hyperparameter tables flag them (`AtUpperBound_<input>`, settings 0.4). The fit seeds are
recorded; for outputs 1 and 3 the approved generalized GP takes the best of five declared starts. Sparse polynomial
chaos expansions (Bayesian compressive sensing, degree chosen by cross-validation) serve for comparison and for the
analytic Sobol indices. The GP's predictive variance is rescaled to the observed out-of-fold errors,
v<sub>emu,j</sub> = τ<sub>j</sub>² · h<sub>j</sub><sup>γ</sup> with h<sub>j</sub> = v<sub>native,j</sub> / σ<sub>j</sub>²,
γ = 0.302 on the fixed route and 0.48225 on the generalized route; both calibrations are frozen records in `config/`.
σ² and with it v<sub>native</sub> are not identified in scale: refits of the fixed GP on the same data with other
seeds change σ² by factors of 4.5 to 1,494 while the D6 means move by less than 0.003 mbar. The calibration works on
h = v<sub>native</sub> / σ², which removes that scale; scores of the raw variance (a raw-variance cross-validation,
say) therefore do not rank kernels. Each γ is the mean of 500 case-cluster bootstrap estimates, each the best value
on a grid from 0 to 1 in steps of 0.025, so γ itself lies off the grid, while the bootstrap's 95 % interval (fixed
0.225–0.375, generalized 0.35–0.60) can only take grid values.

**`surrogate_assessment`, `surrogate_audit`.** The assessment predicts the held-out external cases: R², RMSE, NRMSE
and the coverage of the calibrated predictive intervals. The audit (development cases only) compares kernels,
seeds, training-set sizes and the variance model; its results are shipped as evidence. On the generalized route the
review of the bounded GP selection (outputs 1 and 3) compares, per declared start, the training analytic
leave-one-out MSE (UQLab's optimizer objective, mbar²) under the original optimizer budget of 20 iterations
(`OriginalLOOMSE`) and the approved budget of 100 (`NewLOOMSE`). The assessment's records hold no
cross-validation predictions of the approved GP (`prediction_unavailable`): the GP's cross-validation rows of
`training_cv_internal_heldout_metrics.csv` are empty (the PCE's are filled), and the cohort figure leaves them out.

**Support classes** (generalized route). Each external case gets, per output, its normalized distance to the
nearest development case that observes the output (the seven inputs scaled to [0, 1] by their bounds;
`NearestTrainingDistance7D`, in the default-protocol comparison `NearestGeneralizedTrainingDistance`) and a support
class: well supported up to the LOO-95 radius r<sub>95</sub>, the 95 % quantile of the development cases'
leave-one-out nearest distances; weakly supported up to 1.5 r<sub>95</sub>; extrapolative beyond (thesis,
`pcl3_D6_mbar`: 76 well and 6 weakly supported external cases). The dataset's case registry and the support audit
of the sensitivity's Sobol points cut at the 75 % and the 95 % quantiles instead (well supported, weakly supported,
extrapolative) and add two classes from the outcomes: inside a known non-complete region (the output is missing
although both probe runs exist: an early stop or a nonlinear failure; for a Sobol point, that of its nearest planned
case) and unresolved due to a missing outcome (a probe run is missing).

**`feature_accuracy`** (`features.external_predictions`, `features.feature_accuracy`; settings 0.7). Whether the
surrogates reproduce the derived features that `feature_sensitivity` analyses: on the external cases only, the six
pressures and every feature of the catalog computed from the GP mean and from the PCE mean, against the same feature
computed from the COMSOL pressures. The step reads the predictions that `surrogate_assessment` saved and fits or tunes
nothing. Log-linear features are compared in log (e = log f(mean) − log f(COMSOL), about the relative error),
differences in mbar. Per feature: the bias, RMSE and R² with 95 % case-bootstrap intervals (2,000 resamples, recorded
seed); the spread of the feature over the cases, the signal scale (ratios vary little between tissues, so read RMSE
next to R²); a descriptive noise scale, the SD of the feature under independent errors of the reference CV; the SD
that the 1 s time grid of the COMSOL closing (section 7) gives the gridded outputs (a 4 mbar step at the fixed
route's 0.4 kPa/s); the correlation of the six outputs' relative errors and the split of each feature's error variance into
variance and covariance terms (do the errors cancel in a ratio?); and an emulator check, the error over its SD under
the calibrated emulator variances taken as independent, as the likelihood does. A drop ratio that the rule of
`feature_sensitivity` finds UNSTABLE on the external cases is reported, not summarized. The generalized route adds
subsets by suction rate and by the training support of `pcl3_D6_mbar`; its spread includes the protocol effects, so R²
is not comparable between the routes. Outputs, in the surrogate analysis (`feature_accuracy_*`): the main figure (the
four within-probe ratios and R21, parity and errors), parity figures per family, an error strip of every feature, the
correlation and emulator-check figures, and the tables; the rankings of `feature_sensitivity` show each feature's R²
and NRMSE. It validates point predictions, not posteriors.

**`sensitivity`** (`sensitivity.sobol`, `sensitivity.ard`). First-order, total and second-order Sobol indices of
every closing pressure, from the GP mean by Monte Carlo (50,000 samples per matrix on the fixed route, 40,000 on the
generalized route; recorded seeds) and from the PCE analytically; the total indices of the pressure ratios; and the
ARD importance of each input (normalized inverse length scales). The generalized route adds material/protocol group
effects and interactions and checks that the Sobol samples stay inside the input region the training data cover.
The GP indices carry Monte Carlo error, visible in the shipped values: on the fixed route first-order indices above
their totals by up to 0.0025 and second-order indices from −0.004 to 0.008; on the generalized route five slightly
negative first-order indices (hold and pause at D6, down to −0.006), seven first-order indices above their totals
(by up to 0.005), and material × protocol second-order indices with an offset per output (mean about −0.004 at D2
and +0.008 at D6, every D6 pair at least +0.006): estimator error, not interaction. Indices of that size are zero
within their error. The tables keep the estimates as computed, negative values included; only the interaction gap,
max(S<sub>T</sub> − S<sub>1</sub>, 0), sets a negative difference to 0. Second-order indices are read per output,
never averaged over outputs, and a group sum of them (`material_protocol_second_order_sum`) adds the offsets of its
12 pairs. The PCE indices are analytic.

**`feature_sensitivity`** (`features.catalog`, `features.feature_sensitivity`; settings 0.7). The Sobol indices of
derived features of the six pressures, so that a parameter's influence can be read on more than the raw pressures:
the ratios within a probe and between the probes, including the double ratio R21 =
(p<sup>D2</sup><sub>cl,2</sub>/p<sup>D2</sup><sub>cl,1</sub>) / (p<sup>D6</sup><sub>cl,2</sub>/p<sup>D6</sup><sub>cl,1</sub>),
the differences between the cycles (mbar), the levels of each probe (geometric means) and the shape of the decline
(exploratory). The catalog in the settings defines each feature by a weight vector w of the six pressures (used as
log f = w · log p) or as a raw difference or quotient; a feature added there appears in every table and figure. Each
route uses its existing estimator, sample and seed: the fixed route the sample of its ratio indices (the raw sample is
drawn again first), the generalized route that of its derived-feature indices; a feature that the step `sensitivity`
already computes keeps its raw definition there, and its indices are the existing ones. Per feature and input: S1,
ST, ST − S1 and the effect size sqrt(ST × variance) in the feature's own units; a drop ratio whose denominator
changes sign over the sample, or whose variance a few samples carry, is UNSTABLE and not ranked. Outputs, in the
sensitivity analysis (`features_*`): a table and a heatmap per family, a ranking per input (the top 10; the features
of `physics_guided_full_rank_six` marked), the dominant input of every feature, an overview heatmap and the
registry. An index is a share of a feature's variation, not its size, and says nothing about whether a parameter can
be recovered from a measurement; every feature is a function of the same six pressures.

**`inversion`** (`inversion.gp_log_likelihood`, `inversion.bayes_invert`, `inversion.run_reliability_cell`). A
Gaussian likelihood with the GP mean as the model and a variance per output that depends on the **scenario**:

| Scenario | Observations | Variance of output j |
|---|---|---|
| `measurement_plus_gp` | held-out COMSOL pressures of the truth case | (0.08 · \|μ<sub>j</sub>\|)² + v<sub>emu,j</sub> + (10⁻⁶)² |
| `gp_only` | the same | v<sub>emu,j</sub> + (10⁻⁶)² |
| `gp_self_det` | the GP mean at the truth (a self-consistency diagnostic) | (10⁻⁶)² |

The **observation designs** use subsets or transforms of the six pressures: `all_six`, `d2_only`, `d6_only`,
`cycle_1_only`, `ratios_only` (p<sub>2</sub>/p<sub>1</sub> and p<sub>3</sub>/p<sub>1</sub> of each probe) and
`physics_guided_full_rank_six` (an invertible transform of all six pressures, the six coordinates `p3_D2`,
`p3_D2/p1_D2`, `p1_D2 - p2_D2`, `p1_D2/p3_D6`, `p3_D6/p1_D6` and `p2_D6/p1_D6`; listed with their ranges in
`fixed/05_recovery/data/feature_reconstruction/feature_registry.csv`); transformed designs carry the full
delta-method covariance. The prior is uniform. UQLab's affine-invariant ensemble sampler (AIES) runs 40 interacting
walkers (stretch parameter 2) from a Latin hypercube over the prior; the first half of each chain is discarded, with
no thinning. Every cell (truth × scenario × design) runs two independently seeded ensembles of 2,000 steps, and two
fresh ones of 5,000 steps if the pair does not **certify**; replicates and levels are never pooled. A pair certifies
when each ensemble passes the hard health checks (finite draws inside the prior, a finite log-likelihood trace, every
walker moving in at least 1 % of the steps and visiting at least two states, no duplicated trajectory) and, for
every parameter, the two ensembles' first Wasserstein distance and their 2.5 % and 97.5 % quantiles differ by at most
0.05 of the prior width. Replicate 1 of the certified level is the cell's posterior. R-hat, ESS, MCSE, median and
correlation differences are reported as warnings and never veto a certification. An undefined R-hat (NaN), a
degenerate one (at least 1e6, settings A.6; the thesis campaign's are at most 6.71 or about 4.4e14) and a tail ESS of 0
are a health note (`HealthNote`) in the pair diagnostics (`diagnostics/pair_reliability_diagnostics.csv`) and, per
cell, in `cell_status.csv`; the R-hat figures leave them out and give their number in the title. A cell that does
not certify but has a healthy completed request is a **healthy fallback**: its posterior is the first healthy
request, the highest level first and replicate 1 before replicate 2 (never pooled); a cell without a healthy request
is **unavailable**. The pair diagnostics hold one replicate pair per cell, the pair at the level that decided its
status (2,000 or 5,000 steps); the failed 2,000-step pairs of cells that went on to 5,000 steps are not in them. In
the thesis campaign 302 of the 360 canonical cells have a pair (230 certified, 23 healthy fallbacks whose pair did not
certify after 5,000 steps, 49 unavailable), and 79 of the 80 conditional cells of A–D; the other 24 canonical
healthy fallbacks have none, because their second replicate ran out of time (`TIMEOUT`), and their posterior is the
healthy replicate. The 80 cells of E and F (all certified) keep their certification record in their draw files.

| Campaign | Cells | Certified | Healthy fallbacks | Unavailable |
|---|---|---|---|---|
| canonical (20 truths × 3 scenarios × 6 designs) | 360 | 230 | 47 | 83 (all `gp_self_det`) |
| conditional (parameters fixed at the truth) | 160 | 158 | 2 | 0 |

**`conditional_inversion`** (`inversion.conditional_inversion_conditions`, `study.conditional_design`). The `all_six`
inversion repeated with parameters fixed at the truth, by the condition table and the campaign rows of the settings
(A.9). Condition A fixes nothing: it is the canonical cell itself (of the run's finalized inversion campaign, or the
shipped one). B fixes the thickness, C m<sub>3f,RD</sub>, D both (B–D in `gp_only`, D also in
`measurement_plus_gp`: the thesis campaign, 80 cells); E fixes m<sub>3e,RD</sub> and F log<sub>10</sub>(k<sub>0,RD</sub>)
(both scenarios, 80 cells): do the two weak parameters mask each other? The sampler moves the free parameters only, the
GP sees all four, and prior, likelihood, health checks and certification are the canonical ones, the replicate
agreement over the free parameters. A cell is its fixed parameters, case, scenario and replicate: renaming a label
changes no cell, seed or file. Its figures and tables show the conditions of its results, ordered and labelled as in
the condition table: per scenario in which at least two conditions besides A ran, the posterior spread, the recovery
error and the 50 % and 95 % truth inclusion of the weak pair (A.7) over the matched cohort of all of them; per
condition of `measurement_plus_gp`, its comparison with A; the table `conditional_sd_ratios`, per matched case,
condition and free parameter: the posterior SD over the prior SD under the condition and under A, their ratio (1 is
no change), and the replicate discrepancy of both cells (the normalized Wasserstein distance between the two
replicates, the certification's measure, and the relative difference of their posterior SDs), so that a change can be
read against the run-to-run variation; `conditional_sd_ratio_summary`, its median and quartiles per scenario,
condition and parameter over the matched cohort, with the certified-only values; and per case the conditional
posteriors (A.10). A parameter that a condition fixes has no posterior: the figures mark it "fixed at the truth".
A campaign's results carry its seed record (`data/seeds/seed_record.csv`): the seed of every request of its cells,
recorded in `config/seeds/mcmc_seeds.csv` (A–D) or given by the settings' rule (a new condition or case).

**`recovery`** (`recovery.*`). From the posterior of every cell with a selected provider (certified or healthy
fallback; every aggregate also over the certified cells alone): coverage (the truth inside the central 50 % and 95 %
intervals), contraction (posterior over prior standard deviation), recovery error (|posterior median − truth| over
the prior width), the posterior covariance eigen-analysis in prior-standardized coordinates (stiff and sloppy
directions; the two replicates' geometry compared), and the feature reconstruction (every posterior draw through the
GP to the observable features, compared with the surrogate error budget). The reconstruction normalizes the errors of
every feature (pressure, ratio, drop or difference) by its range over the 61 complete external cases of the fixed
dataset, computed from their COMSOL pressures (`FeatureScale` = maximum − minimum; one scale per feature, the same
for every design and scenario; no normalized error where the range is numerically zero); `feature_registry.csv`
lists each scale with its minimum, maximum and cases. The surrogate error budget is posterior-free: one table,
`error_budget/raw_output_summary.csv`. Comparisons between designs use matched
cohorts: the truths with a posterior for every compared design. The second-mode check (`recovery.second_mode_check`,
settings A.7; thesis: case 215, `gp_self_det`, `all_six`, whose walkers split into a group at the truth and a group
at a point B in both replicates) asks whether B is a second region of good fit or a place where walkers are stuck:
the walker groups with their log-likelihood, the fit at B and at the truth, a local refinement from both, the
negative log-likelihood on the line between them, the noise at which the six pressures would tell B from the truth,
the angles to the posterior's eigendirections and to its combinations of the weak pair (step `combinations`) and
the COMSOL cases with the closest pressures; its class follows a rule fixed in advance (settings A.7). Descriptive:
no sampling, no status changes. Output: a figure and a table in
the case folder (`cases/case_215/recovery/`). The table `gp_only_sensitivity_without_bound_cells` (settings A.7)
repeats every published `gp_only` aggregate that contains the `physics_guided_full_rank_six` healthy fallbacks of
cases 172, 220, 48, 166 and 246, whose healthy replicate has 2 to 9 of 40 walkers at the lower thickness bound: the
matched-design SD ratios and recovery errors, the design means and the design study's ranking, with the cells (the
published value) and without their cases (removed from every compared design), each with its N. It replaces no
published value.

**`design_study`** (`design_study.generate`, `design_study.score_fim`). Compares the six observation designs: the local
Fisher information F = Jᵀ Σ⁻¹ J at each truth (finite-difference Jacobian in the unit box), the approximate posterior
covariance (C<sub>0</sub>⁻¹ + F)⁻¹ with its D-utility, A-loss, target variances and information gain; and from the
posterior draws the information gained on the **weak pair** (m<sub>3e,RD</sub>, log<sub>10</sub>(k<sub>0,RD</sub>)),
½ [log det C<sub>0,qq</sub> − log det C<sub>post,qq</sub>] (nats), averaged over the matched cohort. `gp_self_det` has
no complete six-design cohort and so no full ranking. The ranking tables rank by that mean (`RankByQInformation`);
their other means (full information, D-utility, posterior SD, contraction, coverage) give their own orders.
`ConditionNumber` (`fim_metrics.csv`) is s<sub>1</sub>/s<sub>4</sub> of the whitened Jacobian, the square root of the
condition number of F, and infinite for a design with fewer than four outputs (`d2_only` and `d6_only` leave a
one-dimensional null space, `cycle_1_only` a two-dimensional one). The information scores from the posterior draws are
Monte Carlo estimates of covariance moments: of the 60 nested steps of Measurement + GP (cycle 1, D2 or D6 → all six;
`sequential_information.csv`) 9 gain negative weak-pair information (down to −0.118 nats) and 54 have a covariance
reduction with a negative eigenvalue (down to −0.022; GP only 28 of 60, down to −0.040): Monte Carlo and moment
error, not information lost by adding pressures.

**`ratio_error_curves`** (`features.ratio_errors`, `features.ratio_error_curves`; settings 0.7 and A.11). Inside the
existing posteriors, do some parameter values reproduce the cycle-to-cycle pressure ratios better than others? A
descriptive map of the posteriors: the ratios are functions of the same six pressures, so nothing is sampled and no
inference changes. For every retained draw of each replicate (never pooled), the GP mean μ of the production model
gives the log errors u = log μ − log y against the observation y the posterior used (natural logarithm, the six
pressures in the order above) and the four log-ratio errors e = A u, in the order D2 c2/c1, D2 c3/c1, D6 c2/c1, D6
c3/c1 (the rows of A: (−1, 1, 0, 0, 0, 0), (−1, 0, 1, 0, 0, 0), (0, 0, 0, −1, 1, 0), (0, 0, 0, −1, 0, 1)). The two
ratios of a probe share its cycle-1 pressure, so their errors are correlated; the **ratio discrepancy** weights them
for it: d = sqrt(eᵀ (c² A Aᵀ)⁻¹ e / 4) = sqrt([(a₁² − a₁b₁ + b₁²) + (a₂² − a₂b₂ + b₂²)] / (6c²)), with (a₁, b₁) the
two ratio errors of D2 and (a₂, b₂) those of D6. Its unit is a fixed **yardstick**, c = 0.08 (settings 0.7), the
same for every draw, case and scenario: d is about 1 when the ratios are off by about what independent 8 % errors of
the six pressures would give, and 0 when they are reproduced exactly. The yardstick is a unit, not the noise model of
the likelihood. The **level discrepancy** d<sub>level</sub> = sqrt(3 (ū<sub>D2</sub>² + ū<sub>D6</sub>²) / (2c²)),
with ū the mean of u over a probe's three cycles, measures the overall pressure level instead; the two split the
misfit into shape and level, 4d² + 2d<sub>level</sub>² = Σ u² / c². Per parameter, the draws of replicate 1 are cut
into 20 bins of equal count (replicate 2 on the same edges); per bin the 10, 50 and 90 % quantiles and the mean of d,
d<sub>level</sub>, the ratio errors in percent (100 e) and the double-ratio error 100 (e<sub>1</sub> − e<sub>3</sub>);
per cell and parameter η² = Σ<sub>b</sub> n<sub>b</sub> (mean<sub>b</sub> d − mean d)² / Σ<sub>s</sub> (d<sub>s</sub> −
mean d)², the share of the variance of d between the bins (replicate 1; descriptive). The cells: every case whose
`measurement_plus_gp`, `all_six` cell has a posterior (certified or healthy fallback), and case 113 in `gp_only`.
Reading the curves: a flat curve means that the ratios give the parameter no leverage within the posterior. A
structured curve, stable across bins and replicates, gives leverage only if ratio errors are more precise than
independent 8 % errors imply, an unmeasured property of the device. The observations are exact COMSOL outputs, so
structure near the truth can look more decisive than it would with real, noisy data. The curves show association
along plausible parameter combinations, not causation.

**`combinations`** (`recovery.parameter_combinations`; settings A.12). The weak parameters m<sub>3e,RD</sub> and
log<sub>10</sub>(k<sub>0,RD</sub>) are poorly determined one by one, but a measurement may determine a combination of
them (as x + y = 5 determines x + y, but neither x nor y). For each cell of the settings (thesis: the 20 cases in
`measurement_plus_gp` and `gp_only`, `all_six`) and each replicate on its own, in the prior-standardized coordinates
of the eigen-analysis, z = (parameter − prior mean) / prior SD, where a combination w'z of unit length has prior SD 1:
the eigen-directions of the posterior covariance of the four parameters, as formulas with their SD ratios (posterior
over prior SD; the tightest is the best-determined combination); the best- and worst-determined combinations of the
weak pair from its 2 × 2 block, next to the SD ratios of the two parameters alone; the same in log form, a power law
m<sub>3e</sub><sup>a</sup> k<sub>0</sub><sup>b</sup>, where every draw of m<sub>3e,RD</sub> is positive and its 1 %
quantile lies at least 5 % of the prior range above zero (settings; otherwise the reason is given); and the marginal of
each best combination from the projected draws, against its prior (a prior sample of the settings) and the truth.
"Identified combination" labels a best weak-pair combination whose SD ratio is at most half the smaller individual
SD ratio (settings): a description, not a statistical test. The compensation behind it, at each truth: the GP's
Jacobian in the same coordinates, whitened by the scenario's observation covariance (as the design study does), gives
the angle between the sensitivity vectors of the two weak parameters (near 180 degrees: a change of one is undone by
a change of the other), the collinearity index of Brun, Reichert and Künsch (2001) and the pair's least-informative
direction, compared with the worst-determined posterior direction. Across the cells of a scenario: the consensus
combination and each cell's angle to it. The best combination in standardized units depends on the prior ranges
(the log form does not depend on units); the truths are synthetic, under the thesis prior; and a combination that a
measurement determines well is necessary but not sufficient for a clinical descriptor, which needs clinical data.
Outputs, in the recovery analysis (`combinations_*`): the tables of the cells, the marginals and the cohort summary
(certified cells alone in the `_certified_only` columns), three cohort figures, and per cell the marginals and the
scatter of the weak pair in the case folder (`cases/case_<CaseID>/combinations/`).

**`gp_mean_inversion`** (`inversion.gp_mean_best_fit`, `study.write_gp_mean_results`; settings A.13). A fourth
scenario, `gp_mean_det` (GP mean, COMSOL data): per truth the six held-out COMSOL pressures (the observation vectors of
Measurement + GP and GP only) with the GP predictive mean as the forward model and the variance of the GP
self-consistency scenario, the numerical floor of A.2 only (1e-6 mbar). The 20 cells (`all_six`) ran with the
canonical sampler, escalation, health checks, certification and fallback rule, seeds by the MCMC rule with scenario
number 4. No posterior is available for this scenario: with a variance of 1e-12 mbar² the posterior is practically a
point, which the AIES ensembles cannot sample; every cell escalated and ended unresolved with frozen walker
trajectories, 19 without a healthy request (unavailable) and case 131 with one (a healthy fallback). Its answer is
that point, computed directly: per case θ* = argmin<sub>θ</sub> Σ<sub>i</sub> (y<sub>i</sub> − μ<sub>i</sub>(θ))²
within the prior bounds (model coordinates), the maximum of the likelihood and, under the uniform prior, of the
posterior; `lsqnonlin` (trust-region-reflective) on the six residuals with the parameters scaled to [0, 1], inside
`MultiStart` from 200 Latin-hypercube start points (1,000 when fewer than 5 reach the best minimum). The analysis
(`fixed/09_gp_mean_inversion`) compares θ* with the truth and with the posterior means of the three canonical
scenarios, read from the shipped results; θ* is where the GP mean fits the COMSOL pressures best, which need not be
the truth.

**`default_protocol_comparison`** (generalized). The generalized surrogate at the default protocol against the
fixed-route COMSOL results: metrics, residuals and coverage. The fixed CSV does not carry the provenance of its
COMSOL model (eight fields: model, probe geometry, swelling, closing extraction, units, protocol and its phases);
the source in settings B.5 resolves them (thesis: the author's statement that both datasets come from the same COMSOL
model, section 7), and the status record and every table carry the status `COMPATIBLE_REFERENCE`.

**`screen`, `objective_supplement`, `rankings`** (`screening.run_screening`). 730 candidate protocols (9 levels of
each protocol input, plus the default) evaluated at 1,000 material states of a Latin hypercube over the prior (seed
20260519): the local Fisher information F from the approved generalized GP (finite differences with step 10⁻³ in
the unit box, prior-standard-deviation coordinates) in two covariance views (measurement noise only; measurement
noise plus the calibrated emulator variance), and the covariance proxy C = (I + F)⁻¹. Six objectives are computed
from C: the largest eigenvalue of the weak pair's block C<sub>qq</sub> (the primary objective, averaged over the
1,000 states), the four standardized marginal variances and the trace of C<sub>qq</sub>. The rankings sort the
protocols by each objective; they do not select one. `AggregateWorstDirectionSDImprovement` is
1 − √(1 − `RelativePrimaryImprovement`), the primary objective's improvement over the default in SD units: a
transform of it, not a further criterion.

**`export_design` … `compare`** (the confirmation experiment). The confirmation tests the selected protocols with
new COMSOL simulations, not with the GP: the design of the settings (B.7; thesis: the 20 canonical truths × 4
protocols: the default, and one protocol each focused on the joint weak pair, on the permeability and on the
dissipative-fibre coefficient), 160 D2/D6 probe solves, 80 inverse cells in `measurement_plus_gp` with the
observation design of the settings (B.7 `design`; thesis `d2_only`, the three D2 pressures: under the three focused
protocols the D6 probe mostly stopped in the hold of cycle 2 or failed in COMSOL, which left 6 of the 60 comparisons
with all six pressures; Erion's decision of 2 October 2026, before any confirmation posterior existed), certified as
above (the protocol is known and enters the GP as log<sub>10</sub> of the rate's magnitude, hold and pause), and 60
paired comparisons of a selected protocol with the shared default posterior of the same material. A second design,
descriptive only, is inverted on the complete pairs alone (B.7 `completePairsDesign`; thesis `all_six`: the pairs
whose focused and default rows both have all six pressures, with the default cells of those materials); its tables
(`confirmation_complete_pairs_*`) and figures say "n pairs with all six pressures; descriptive, not representative
of the protocols". Every comparison uses the matched cohort: the materials whose two cells have a posterior (certified or healthy
fallback), with the certified-only value next to each aggregate. Its tables: the status of every cell
(`cell_status`); per matched material, focused protocol and parameter the posterior SD over the prior SD under both
protocols, their ratio and the replicate discrepancy of both cells (`confirmation_sd_ratios`, summarized per protocol
and target parameter in `confirmation_sd_ratio_summary`); per protocol and screening objective the fraction improved
and the ratio of the posterior objective to the default's (`confirmation_objective_summary`), and the agreement of
the FIM-predicted with the posterior change, same direction and rank correlation (`confirmation_fim_agreement`); the
recovery error per protocol over the materials with all four posteriors (`confirmation_recovery_error`). The FIM
predictions refer to the design the posteriors observe: per material, the local information of the design's
pressures; for the screen's own scale, `confirmation_design_predictions` gives the screen's six objectives of the
four protocols at the screen's 1,000 material points with all six pressures (the screen's values) and in the
confirmation's designs (written by `export_design`). `confirmation_comsol_outcomes` counts, per protocol and probe,
how the COMSOL solves ended (written by `import_observations`). The figures add the marginals and the corner plot of
one showcase material under the four protocols, chosen by a rule fixed in the settings before the results (B.7
`showcase`: the first material with four certified cells), and, in the case folders, the marginals of every pair
under the focused protocol and the default (`<design>_<protocol>_vs_default_marginals`; the complete pairs also
together, `complete_pairs_marginals`).

**`combinations`** (generalized; `confirmation.parameter_combinations`; settings B.8). The parameter combinations of
the fixed route (`combinations` above) on the confirmation's posteriors: per material, protocol, observation design
and replicate, the best- and worst-determined combinations of the weak pair with the SD ratios of the two parameters
alone, the log form where the draws allow it, the marginal of each best combination against its prior and the
truth, and per protocol the consensus of the materials; the shared parts are those of the fixed route
(`recovery.combination_support`). Then what a focused protocol changes: on the materials with a posterior
(certified or healthy fallback) under the focused protocol and under the default, per replicate, the rotation of
the best weak-pair combination from the default's (the angle between the two directions, 0 to 90 degrees) and the
ratio of their SD ratios (below 1: the focused protocol determines its best combination more sharply), next to the
angle between the two replicates of each cell, the run-to-run variation a protocol's rotation must exceed. It reads
the draws of this run's `compare`, or the shipped ones. Outputs, in the confirmation analysis (`combinations_*`):
the tables of the cells, the marginals, the consensus and the protocol comparison with its summary (pairs of
certified cells alone in the `_certified_only` columns); per design the SD ratios, the directions and the protocol
effect; and per material and design the marginals and the scatter of the weak pair under each protocol in the
generalized case folder (`generalized/cases/case_<CaseID>/combinations/`).

**`figures`.** Renders the figures and tables of the route from the saved results; no step computes anything while
drawing.

## 6. Outputs and the layout of the thesis results

`thesis_results/` holds the results of the thesis: one folder per analysis, in scientific order, and one folder per
case for the outputs of single cases. It is the output of `reproduce_thesis_results`, so a rerun of the code writes
exactly this layout and can be compared with it file by file. Start with
[`thesis_results/README.md`](../thesis_results/README.md): the index of the analyses and of the case folders, the
case overview (every canonical truth with the status of its cells and links to its case folders), how certified and
healthy-fallback cells are shown, the posterior draws and how the results were produced.

| Folder | Analysis | Main content |
|---|---|---|
| `fixed/01_dataset` | the fixed dataset | case counts, availability patterns, the 391/61 split, training support per output |
| `fixed/02_surrogates` | GP and PCE surrogates | the production models (`thesis_results/fixed/02_surrogates/data/models/`), external assessment, hyperparameters, emulator calibration, development audit; the accuracy of the derived features on the external cases (`feature_accuracy_*`) |
| `fixed/03_sensitivity` | Sobol and ARD sensitivity | indices of the pressures and ratios, GP and PCE; the derived features (`features_*`: families, rankings per parameter, registry) |
| `fixed/04_inversion` | the canonical inversion (360 cells) | the status table of the 360 cells, posterior draws of the 277 available cells, diagnostics, design comparisons |
| `fixed/05_recovery` | recovery | coverage, contraction, recovery error, posterior eigen-analysis, feature reconstruction, error budget, second-mode check; the parameter combinations the posteriors determine (`combinations_*`) |
| `fixed/06_design_study` | the six observation designs | Fisher-information and posterior comparisons, rankings |
| `fixed/07_conditional_inversion` | the conditional inversion (160 cells) | matched cohorts, posterior draws, comparisons with the canonical cells, posterior SD ratios to the canonical cells |
| `fixed/08_ratio_error_curves` | ratio-error curves (21 cells) | how well the posterior draws reproduce the cycle-to-cycle ratios: per draw the ratio discrepancy, the level discrepancy and the four ratio errors; bin summaries along each parameter, eta², the cells and their status |
| `fixed/09_gp_mean_inversion` | the GP-mean inversion (20 cells) | the status of its cells (no posterior; one healthy fallback), the best fit θ* of the GP mean to the COMSOL pressures per case with its local minima, θ* against the truth and against the posterior means of the three canonical scenarios |
| `generalized/01_dataset` | the generalized dataset | case registry, split, support of the protocol space |
| `generalized/02_surrogates` | the approved surrogates | the approved GP and PCE, assessment, hyperparameters, the 1,050-fit audit, the selection review; the accuracy of the derived features on the external cases (`feature_accuracy_*`) |
| `generalized/03_sensitivity` | sensitivity with protocol inputs | Sobol indices, material/protocol group effects; the derived features (`features_*`) |
| `generalized/04_default_protocol_comparison` | generalized GP against fixed-route COMSOL results | metrics, residuals, coverage |
| `generalized/05_protocol_screening` | the protocol screen | rankings of 730 protocols under six objectives |
| `generalized/06_confirmation` | the confirmation | its design (20 truths × 4 protocols), how the COMSOL solves ended, the status of its 89 cells, posterior draws of the 82 with an observation, the paired comparisons with the default (SD ratios, objectives, FIM agreement, recovery error), the complete pairs (descriptive) and the parameter combinations (`combinations_*`) |

Every analysis folder holds `figures/` (PNG), `tables/` (CSV at full precision), `data/` (the saved results the
figures, tables and later steps read; a rerun of the steps also writes further records) and a `README.md`: the
index of its figures and tables (title, what each shows, the cells it covers and their status, the command that
redraws it), its outputs of single cases, what `data/` holds, the full-size intermediates that are not shipped
(with the command that regenerates them) and its commands.

**Case folders.** The outputs of single cases lie in `<route>/cases/case_<CaseID>/<step>/figures/` and `tables/`,
one step folder per analysis that draws them (`inversion`, `recovery`, `combinations`, `design_study`,
`conditional_inversion`, `ratio_error_curves`, `gp_mean_inversion`); a case folder has no README. The cases, scenarios and designs they
cover are settings (A.10 "Case outputs"; the ratio-error curves: A.11; the parameter combinations: A.12; the
GP-mean inversion: its cells with a posterior, A.13); the full
draws of every cell ship, so any other selection renders from these results.

| Step folder | Per case | Thesis selection |
|---|---|---|
| `inversion` | per cell `<scenario>_<design>_marginals`, `_statistics` (CSV), `_intervals`, `_corner` | the 20 cases in `measurement_plus_gp`, `all_six`; case 131 in `measurement_plus_gp` with every design; the `all_six` cells of 131 and 113 in `gp_only` and of 131 and 42 in `gp_self_det` |
| `inversion` | per cell `<scenario>_<design>_traces`, `_diagnostics` (the sampler) | case 131 in `measurement_plus_gp` with every design; the `all_six` cells of 131 and 113 in `gp_only` and of 131 and 42 in `gp_self_det` |
| `inversion` | per cell `<scenario>_<design>_certification` (CSV): status, provider, replicate agreement and health diagnostics | the 20 cases in `measurement_plus_gp`, `all_six` |
| `inversion` | `<scenario>_<design>_corner` with `_statistics` | the 20 cases in `gp_only`, `all_six` |
| `inversion` | `all_six_scenario_marginals`; `<scenario>_design_marginals` with `_statistics` | the 20 cases; case 131 in `measurement_plus_gp` |
| `recovery` | `posterior_intervals` (the three scenarios, `all_six`) | the 20 cases |
| `recovery` | per cell `<scenario>_<design>_predictive`: the six closing pressures against the GP mean at the posterior draws | the 20 cases in `measurement_plus_gp`, `all_six` |
| `combinations` | per cell `<scenario>_<design>_combination_marginals` (the best combinations against their priors) and `_weak_pair_scatter` (the draws of the weak pair with the best and worst directions) | the 20 cases in `measurement_plus_gp` and `gp_only`, `all_six` |
| `combinations` (generalized) | per material and design `<design>_combination_marginals` (the best weak-pair combination under each protocol against its prior) and `_weak_pair_scatter` | every material of the confirmation with a posterior |
| `design_study` | `<scenario>_target_q_ellipse` | case 131 in every scenario |
| `conditional_inversion` | `selected_posteriors` with `_statistics` | case 131 |
| `ratio_error_curves` | per cell `<scenario>_<design>_ratio_discrepancy` (d), `_ratio_errors` (the four ratio errors), `_level_discrepancy`, `_double_ratio_error`: the posterior marginals above the curves | the 20 cases in `measurement_plus_gp`, `all_six`; case 113 in `gp_only`, `all_six` |
| `gp_mean_inversion` | `gp_mean_det_all_six_marginals` with `_statistics` | every GP-mean cell with a posterior (thesis: case 131, a healthy fallback) |
| `gp_mean_inversion` | `four_scenario_marginals` (the four scenarios, `all_six`) and `best_fit_pressures` (the six COMSOL pressures, the GP mean at the best fit and at the truth) | the showcase case of A.13 (thesis: 119) |

**Certified and healthy-fallback cells.** Results based on posteriors show every cell with a selected provider: the
certified cells (two independent ensembles that agree) and the healthy fallbacks (a healthy posterior that did not
certify), without markers. The index of each analysis names, for every figure and table, the cells it shows and
which of them are healthy fallbacks or unavailable; a figure of one case gives its status in the title;
`cell_status.csv` lists every cell. Aggregates count certified and fallback cells and state their number; summary
tables give next to each value its value over the certified cells alone (columns ending in `_certified_only`); a
comparison of two conditions of the conditional inversion counts a case there when both of its cells are certified.
Cells without a posterior (83 of the 360 canonical cells, all in the `gp_self_det` diagnostic scenario) stay
explicit, as unavailable: blank, grey in heatmaps, never drawn as zero.

**Posterior draws.** `fixed/04_inversion/data/draws/` (277 cells), `fixed/07_conditional_inversion/data/draws/`
(160 cells) and `fixed/09_gp_mean_inversion/data/draws/` (1 cell, a healthy fallback) hold, for every cell with a selected posterior, every retained draw of both replicates at full precision,
one file per cell, with an index (`index.csv`), the health record and request of each replicate, and the
certification record of a certified cell. Nine healthy fallbacks hold only the replicate that finished.

```matlab
S = load('thesis_results/fixed/04_inversion/data/draws/measurement_plus_gp/all_six/case_131.mat');
D = S.draws;                                        % one cell
k = [D.replicates.replicateID] == D.providerReplicateID;
theta = D.replicates(k).drawsPhysical;              % draws x 4: m3_f_RD, m3_e_RD, log10_k0_RD, Thickness_RD
```

The names ending in `Physical` (`drawsPhysical`, `TruthPhysical`, …) are the recorded names of the thesis runs; the
values are in model coordinates, with the permeability as log10(k0).

The canonical draw files and every draw file the current code writes (schema `shipped_posterior_draws_v3`) also
hold, for each replicate, `logLikelihood`: the log-likelihood of every retained draw, row by row with
`drawsPhysical` (`D.replicates(k).logLikelihood`, draws x 1). `logLikelihoodSource` names where the values come
from: `sampler`, the values the sampler computed for the retained states (its stored evaluations; the files the
current code writes), or `evaluated`, the cell's likelihood evaluated at every retained draw after the run (its
scenario, design and observation, the shipped GP with its calibrated emulator variance; no new sampling): the 277
files of `fixed/04_inversion/data/draws/`, whose runs' stored evaluations are not shipped. The two agree to about
1e-10 relative in `measurement_plus_gp` and `gp_only`. In the diagnostic scenario `gp_self_det` the variance is the
numerical floor alone (1e-6 mbar), so the rounding of the GP mean (about 1e-12 relative; it depends on the computer
and on how many points one evaluation takes) moves the log-likelihood by up to a few 1e-4 near its maximum (about
1e-6 relative). The prior is uniform and constant inside the bounds, so the log-posterior is `logLikelihood` plus a
constant. The conditional files of cells A–D (`fixed/07_conditional_inversion/data/draws/`) have schema
`shipped_posterior_draws_v2`, without the field; those of E and F, written by the current code, have it (`sampler`).

**Reading the data without MATLAB.** Every data file under `thesis_results/` is a CSV file or a MAT file of format
v7 (`scipy.io.loadmat` reads it) holding numbers, logicals, text and structs. Where a variable was a MATLAB table or
string array, the file stores it as plain values: a table as a struct with one field per column, a string array as a
cell array of text; the variable `plainMatEncoding` lists them, and `utils.load_plain_mat` loads such a file with the
tables and strings restored. The exception are the four surrogate model files
(`fixed/02_surrogates/data/models/{gp,pce}_surrogate.mat`,
`generalized/02_surrogates/data/surrogates/{gp,pce}/ensembles/{gp,pce}_ensemble.mat`): they hold the UQLab models the
code evaluates, which need MATLAB with UQLab. The surrogate audit's PIT histogram and Q-Q points are also CSV, per
route: `02_surrogates/data/audit/residual_distribution/pit_bins.csv` (per kernel, variance model, output and bin:
the edges, the count and the fraction) and `qq_points.csv` (per kernel, variance model and output, every rank: the
probability (rank - 0.5)/n, the normal quantile and the observed standardized residual).

**What thesis_results/ does not ship.** Full-size intermediates of the thesis runs that no figure, table or later
step reads (for example the GP evaluated at every posterior draw). The README of each analysis names them with the
command that regenerates them and its runtime.

**Results that do not exist.** In the diagnostic scenario `gp_self_det` no case has a posterior for all six
observation designs, so there is no six-design ranking and no matched-design comparison for it (its 83 unavailable
cells are listed in the status table). Two studies were never run: the inversion against the surrogate's training-set
size, and the robustness of the inversion to a perturbed likelihood or emulator variance.

**A run folder.** A run writes `runs/<run name>/`, in the same layout:

```
<run>/
  fixed/01_dataset/ … fixed/09_gp_mean_inversion/, fixed/cases/
  generalized/01_dataset/ … generalized/06_confirmation/
  README.md             the index of the run's analyses and case folders, and how they were produced
  run_record.json       every call and every completed step of the run
  _run/                 work folders: campaigns, checkpoints, logs
```

`run_record.json` records every call of an entry point on the run folder (its arguments, the complete settings, the
code version, the MATLAB and UQLab versions, the steps run and reused, the times and the status) and every completed
step, with its inputs and outputs. A rerun's own canonical inversion campaign selects certified providers only; its
conditional campaign and the confirmation also take the healthy fallbacks, by the rule of the thesis's cells
([section 5](#5-what-each-step-computes)).

## 7. The data

The input data are in `data/`, described in [data/README.md](../data/README.md) (columns, quality rules, counts and
provenance):

| File | Content |
|---|---|
| `data/fixed/fixed_dataset.csv` | fixed protocol, frozen 2 Sep 2026: 452 usable cases (306 complete, 146 partial) of 500 designed |
| `data/generalized/generalized_dataset.csv` | generalized protocol, frozen 20 Sep 2026: the 1,000 designed cases, 939 usable (412 complete, 527 partial) |
| `data/confirmation/confirmation_observations.csv` | the accepted COMSOL observations of the confirmation: 20 materials × 4 protocols, the QC-valid closing pressures of each (NaN where QC failed; the confirmation reads the three D2 pressures, design `d2_only`); accepted 3 Oct 2026: 73 of the 80 rows, 7 excluded |

The settings name them (`fixed.dataset.file`, `generalized.dataset.file`, `generalized.confirmation.observations`).

- **Conventions.** The tables store the physical k0 (0.005–0.05 mm⁴/(N·s)); the code works with log10(k0). The
  protocol controls (generalized only) are `suction_rate_kPa_s` (−2.0 to −0.2; negative means suction) with the
  learning coordinate `log10_abs_suction_rate`, `hold_dur_s` (10–45 s) and `pause_dur_s` (5–25 s); the default
  protocol is 0.4 kPa/s, 30 s, 12 s. A missing output is `NaN`; nothing is imputed.
- **Complete, partial, unusable.** A complete case has all six outputs, a partial case one to five (it trains only
  the outputs it has), an unusable case none. The fixed table holds the usable cases; the generalized table holds
  every designed case, and the step `dataset` sets the 61 unusable ones aside (their reason is in
  `exclusion_reason`).
- **Split groups.** The split keeps cases with equal material inputs on one side. The fixed table's column
  `MaterialGroup` holds the frozen labels that reproduce the thesis folds of the surrogate audit; the generalized
  route derives its groups from the four material inputs.
- **From data to analysis.** The step `dataset` writes the analysis dataset, shipped in
  `thesis_results/<route>/01_dataset/data/`, and reproduces it exactly from `data/`:

| | Fixed | Generalized |
|---|---|---|
| development (training and audit) | 391 = 245 complete + 146 partial | 857 = 330 complete + 527 partial |
| external (held-out assessment) | 61 complete, among them the 20 inversion truths | 82 complete |
| training cases per output | 355, 347, 346, 357, 341, 282 | 758, 758, 735, 721, 719, 385 |

- **Checks.** Before computing anything, `run_fixed_study` compares the fixed dataset with the one the frozen
  emulator calibration was fitted on and refuses a different one; the generalized emulator calibration names the
  snapshot it was fitted on, which must be the setting `generalized.dataset.snapshot`. The step `dataset` refuses a
  table without the columns it needs or with a repeated CaseID, and checks the requested inputs (bounds and the
  log<sub>10</sub> transforms).

### The COMSOL model and the suction protocol

Both datasets come from the same COMSOL model (statement of the author, 30 September 2026), and the confirmation's
COMSOL solves use it too; [data/README.md](../data/README.md) (section "The COMSOL model") has the details and the
evidence.

- **Probes.** D2 and D6 name the diameter of the probe opening, 2 mm and 6 mm (COMSOL `Radius_Shield_inn` 1 mm and
  3 mm); the closing elevation `Elevation_Probe` is 0.3 mm (D2) and 1.0 mm (D6).
- **Protocol.** Nine phases: ramp to closing 1; release at the same rate magnitude to near-zero pressure; pause
  (default 12 s); ramp to closing 2; hold at the constant pressure p<sub>cl,2</sub> (default 30 s); release; pause;
  ramp to closing 3; release. The default protocol is 0.4 kPa/s, hold 30 s and pause 12 s; the generalized route
  varies the rate, the hold and the pause.
- **Closing.** A vertical tube stands in the probe opening, its lower end at the closing elevation `Elevation_Probe`
  above the lower face of the probe wall. The model registers a closing when the mean height of the top of the
  buffer disc under the vertical tube (the disc's top surface within 0.3 mm of the axis) reaches `Elevation_Probe`
  (the device itself uses a pressure criterion), at the first time step of its solver at which this holds; the
  closing pressure is the prescribed pressure on the next saved output row. The solver's steps are at most 1 s, so
  the closing pressures lie on a 1 s time grid with the pressure step |r| × 1 s: 4 mbar at the default rate (rounding
  SD 1.15 mbar), 2 to 20 mbar over the generalized rates; a registered closing can lie up to one step after the true
  crossing.

## 8. Reproducing and rerunning

```matlab
reproduce_thesis_results                                        % every figure and table (about 35-60 min)
run_fixed_study                                                 % the fixed route only
run_fixed_study('Steps',{'sensitivity'})                        % one analysis
run_fixed_study('Steps',{'inversion'},'CornerGallery','all')    % a corner plot for every cell
```

Reproduce mode reads `thesis_results/<route>/<analysis>/data/`. It writes the figures, tables and READMEs of each
analysis, and the outputs of single cases, into a new run folder. A rendered PNG can differ from the shipped one in
some pixels (anti-aliasing) and still show the same content. A rendered table holds the same values; MATLAB's
`writetable` ends its lines with CRLF on Windows, as in the shipped tables, and with LF on Linux and macOS.

```matlab
run_fixed_study('Mode','rerun','Steps',{'dataset','surrogates'},'Plan',true)   % what would run
run_fixed_study('Mode','rerun','Steps',{'sensitivity'})                        % one step
run_fixed_study('Mode','rerun','Scale','example')                              % a small whole study
```

- **Steps and inputs.** A rerun computes the steps whose run switch is true (section 0.2 of the settings), or the
  steps named in `'Steps'`. A step reads its inputs from its own run folder when an earlier step of the run wrote
  them, and otherwise from the shipped results where that is allowed. So a single step can rerun without the steps
  before it: the sensitivity, for example, uses the shipped surrogates (with `modelSource` `'use_shipped'`; after a
  refit setting the later steps of the fixed route need the run's own models).
- **Refused before any computation.** A missing input stops the call, and the message names the input and the
  command that produces it.
- **Plan first.** `'Plan',true` prints what would run, what would be reused, the estimated cost and whether the
  call would be refused, and computes nothing.
- **Expensive steps** (MCMC, full refits, audits) need `'ConfirmExpensive',true` and print their cost first.
- **Held-out outcomes.** The steps that read the outcomes of the held-out external cases are marked in the plan
  ("reads held-out outcomes") and run only when the call selects them (their run switch or `'Steps'`); the surrogate
  audit never runs in the same call.
- **The small example.** `'Scale','example'` runs a whole study at reduced size, in 10–30 minutes: on the fixed route
  one inversion cell (case 131, `measurement_plus_gp`, `d6_only`) with 200/250-step chains, then the recovery, the
  design study and the figures; with `'Steps',{'conditional_inversion','figures'}` the conditional inversion of case
  131: E and F in `measurement_plus_gp` with the same chains, run again rather than taken from the shipped results
  (about 40 minutes); on the generalized route its steps, with a reduced GP
  optimization if the refit is requested and a protocol screen of 7 protocols × 15 material points if the screening
  is requested (the confirmation's steps after `export_design` have no example). An example run is labelled as a
  demonstration in its READMEs; its results are never thesis evidence.
- **Seeds.** A rerun uses the recorded seeds of the thesis (`config/seeds/`); a request the thesis did not make takes
  its seed from a simple rule ([section 9](#9-reproducibility)).

**The confirmation experiment.** Its design is set in section B.7 of the settings: the materials (CaseIDs of the
fixed dataset, whose values are the truths) and the protocols (label, targeted objective, signed rate, hold, pause;
or `'from_screening'`, the leaders of the screening rankings). The code covers every step except the simulations:

1. `run_generalized_study('Mode','rerun','Steps',{'export_design'})` writes the design and its COMSOL run list: one
   D2 and one D6 solve per material and protocol, with their inputs to 17 digits; and the screen's proxy of the
   protocols in the confirmation's observation designs (`design_predictions.csv`).
2. The simulations run elsewhere. Their reviewed outputs come back as a folder with `reviewed_export.csv` (one row
   per solve), `source_provenance.json` and the acceptance record `direct_data_acceptance.json`
   ([data/README.md](../data/README.md) describes the columns). The reviewer names in the acceptance the design rows
   accepted as missing (`excludedDesignRows`, each with its reason, e.g. a probe pair that failed).
3. `run_generalized_study('Mode','rerun','Steps',{'import_observations'},'ConfirmationObservationFiles',<folder>)`
   joins every solve to the design by its exact inputs and accepts a material and protocol when the pressures of
   the observation design (B.7 `design`; thesis `d2_only`: the three D2 pressures) are QC-valid. A row the reviewer
   excluded stays in the table, never imputed; its cells are unavailable. Any other row without those pressures
   stops the import, which lists those rows. It also counts how the solves ended in COMSOL, per protocol and probe
   (`comsol_outcomes.csv`).
4. Three calls invert one cell per material and protocol and compare each selected protocol with the shared
   reference: `'Steps',{'prepare'}`, then `{'run_cells'}` (expensive; for a cluster see
   [section 10](#10-running-heavy-steps-on-a-computing-cluster)), then `{'compare'}`. `prepare` reads this run's
   accepted observations, or else the table of the setting `generalized.confirmation.observations`. The seeds of the
   cells follow the rule of the settings (0.6) from the cell's design, the material's CaseID and the protocol's row.
   With a descriptive design of the complete pairs (B.7 `completePairsDesign`), `prepare` adds its cells after the
   80 cells of the design. Given to `prepare`,
   `'DemonstrationSteps'` (e.g. `[200 250]`) makes a demonstration campaign whose cells run chains of that length;
   every later call of the campaign keeps the chains it was prepared with.

The thesis campaign (82 cells: 73 in `d2_only`, 9 in `all_six`) ran on a computing cluster
([section 10](#10-running-heavy-steps-on-a-computing-cluster)); its results are in
`thesis_results/generalized/06_confirmation`, from which `reproduce_thesis_results` renders them.

## 9. Reproducibility

**The claim: scientific reproducibility.** A rerun reproduces the results of the thesis within the tolerances below,
on any computer, with any MATLAB and UQLab release, and even with new random seeds for the MCMC. The conclusions of
the thesis do not depend on which run produced them. For the Bayesian inversions this is exactly what the
certification tests, cell by cell: two independently seeded AIES ensembles must agree on every parameter (the first
Wasserstein distance between their marginals and the differences of their 2.5 % and 97.5 % quantiles at most 5 % of
the prior width). The results use the certified cells and the healthy fallbacks together, name the fallbacks, and
give every aggregate also over the certified cells alone (the certified-only values), so that each conclusion can be
checked on the certified cells. A new run with new seeds therefore gives different draws, but the same certified
posteriors within that tolerance.

We do **not** claim that the same seeds reproduce MCMC draws identically, nor that results are bitwise identical
across computers, operating systems or MATLAB/UQLab releases.

| Result | Reproduces | Evidence |
|---|---|---|
| Figures and tables (`reproduce_thesis_results`) | the same content: plotted data, text and table values | a render compared with `thesis_results/` differs in no plotted value or text of any figure and, on Windows, in no table byte; pixels can differ slightly between computers (anti-aliasing), and on Linux and macOS the table lines end with LF instead of the shipped CRLF |
| Datasets, splits, folds and masks | exactly | deterministic, recorded seeds |
| Predictions of the shipped surrogates | to numerical precision | about 1e-10 between MATLAB R2024a and R2025b |
| Fisher information, covariances and summaries computed from the shipped models and posterior draws | to numerical precision | recovery and design study rerun from the shipped draws: posterior summaries within 1.4e-13 relative; reconstruction and Fisher-information metrics within 2.7e-7 between R2024a and R2025b |
| Sensitivity (Sobol indices) with the recorded seeds | to numerical precision | the Monte Carlo sample uses the recorded seed |
| Protocol screening | to numerical precision | a subset of the screen against the shipped one: largest difference 1.4e-14 |
| Surrogate refits with the recorded seeds | exactly on the same release; closely across releases | the fixed refit on MATLAB R2025b equals the R2025b fits of the thesis period bit for bit, and the R2024a production fit to 2e-5 relative in the mean; generalized outputs 2 and 6 and the PCE refit bit for bit on the release of the approved fits (R2025b) |
| MCMC posteriors | within the certification tolerance | two independent ensembles per cell must agree (above) |

The fixed-route surrogates and inversions of the thesis ran on a computing cluster with MATLAB R2024a; the approved
generalized surrogates were fitted on a workstation with MATLAB R2025b. Both used UQLab 2.3.0. Every run record names
the MATLAB and UQLab versions it ran with.

**Seeds.** The seeds of the thesis are recorded in four tables of `config/seeds`: `mcmc_seeds.csv` (the 1,760
canonical and conditional MCMC requests), `surrogate_fit_seeds.csv`, `surrogate_audit_seeds.csv` and
`design_study_seeds.csv`. The code looks every seed up by the request (case, scenario, design, fixed parameters,
replicate and level for an MCMC request), so a rerun uses the thesis seeds; every cell can be run on its own and in
any order. A request that the thesis did not make (a new case, condition, output or fold) takes its seed from a
simple rule: a base seed plus fixed multiples of the request's numbers; a rule seed equal to a recorded seed is
refused. The recorded tables are never written: a conditional campaign ships its own seed record with its results,
naming for every request whether its seed is recorded or given by the rule. The master seed 20260519 seeds the
dataset splits, the fixed sensitivity and the screening's material design directly.

**Tolerances.**

- **Exact:** datasets, masks, splits, seeds, request definitions, the cells of each campaign, certification
  decisions, rankings and orderings.
- **Numerical precision** (relative 1e-12, or the measured cross-release differences above): predictions of saved
  models; Fisher information and covariances from saved models; summaries of saved posterior draws.
- **Refits:** on the same release, the saved hyperparameters; across releases, close but not exact.
- **Figures:** the same content (plotted data and text); pixels can differ (anti-aliasing).
- **Tables:** the same values; the line endings follow the platform (CRLF on Windows, as shipped; LF elsewhere).

**Figures and graphics hardware.** Without hardware-accelerated graphics, MATLAB draws fewer markers than a plot holds
("Displaying fewer markers to preserve interactivity"). The corner plots show every posterior draw, up to 100,000
markers, so when hardware graphics is missing they are written with a warning and a note in the index of their
analysis README, and a render of the shipped results refuses them. Render them on a computer with working graphics
hardware, with the display on.

**How the restructuring was checked.** The code was restructured from the version that produced the thesis, and that
work was checked privately: the old and new code were compared step by step, and the fixed route's example with real
MCMC drew identical samples on one computer with one release. This exact replay is a check of the restructuring only;
it is not part of the public claim above.

## 10. Running heavy steps on a computing cluster

The heavy computations of the thesis ran on a computing cluster: the canonical inversion (360 cells), the conditional
inversion (160 cells) and the confirmation (82 cells). Each cell runs two AIES ensembles of 40 walkers, of 2,000
steps each and, when the pair does not certify, again of 5,000 steps. On a workstation one 2,000-step ensemble takes
about 50 minutes.

The repository contains no scheduler code. It provides portable functions that any scheduler, or a plain loop over
MATLAB processes, can call:

| Step | Fixed inversion | Confirmation |
|---|---|---|
| 1. Prepare the campaign once: grid, seeds, task table | `run_fixed_study('Mode','rerun','Steps',{'inversion'},'ConfirmExpensive',true,'InversionCells','prepare')` | `run_generalized_study('Mode','rerun','Steps',{'prepare'})` |
| 2. Run any subset of cells, one call per job | the same call with `'InversionCells',[i j …]` (indices of `<run>/_run/inversion/cell_task_table.csv`) | `run_generalized_study('Mode','rerun','Steps',{'run_cells'},'ConfirmExpensive',true,'ConfirmationCells',[i j …])` |
| 3. Certify and write the results | the same call with `'InversionCells','all'` (it runs what is left, then finalizes) | `run_generalized_study('Mode','rerun','Steps',{'compare'})` |

Every call of a job uses the same run folder (`'RunName'`, and `'OutputFolder'` on shared storage).

- **Cells are independent.** Each cell's seeds follow from the cell itself, so the cells can run in any order, in
  separate processes, on one computer or on many.
- **Cells resume.** A cell that already has its outcome record is not run again. A cell that stopped reuses the
  requests it had finished.
- **No pooling.** Two replicates or two levels are never pooled; a cell is certified only when its two independently
  seeded ensembles agree ([section 5](#5-what-each-step-computes)).
- **One chain length per campaign.** A campaign prepared with `'DemonstrationSteps'` (or `'Scale','example'`) runs
  every cell with those chains; a call that asks for other lengths is refused.
- **Provenance.** Each finished cell records the MATLAB and UQLab versions it ran with; the run record and the README
  of the run name them, so cells run on another computer keep their provenance.

The conditional inversion (`'Steps',{'conditional_inversion'}`) runs its cells the same way, with
`'ConditionalCells'` (`'prepare'`; task indices of
`<run>/_run/inversion/conditional_inversion/orchestration/conditional_tasks.csv`; `'all'`), each cell costing about
as much as a canonical cell. It compares with the canonical
`all_six` cells of the run's finalized inversion campaign or, without one, with the shipped ones, and takes the cells
that the shipped results hold from them (`reuseShippedCells`), so that only new conditions run. `'PartialCampaign',true`
publishes the cells run so far (the others unavailable, "not run in this campaign"), as the example does.

## 11. Troubleshooting

| Message or symptom | Meaning and fix |
|---|---|
| an input is missing, and the message names a step | run that step first, or rerun without it so that the shipped results are read ([section 8](#8-reproducing-and-rerunning)) |
| a setting is missing, unknown or invalid | the message names the setting, its section of `study_settings.m` and what it accepts (or the closest valid name) |
| UQLab not found | set `s.paths.uqlabRoot` in `study_settings.m`, or the `UQLAB_ROOT` environment variable |
| held-out outcomes refused | name the step, for example `'Steps',{'surrogate_assessment'}`; it never runs implicitly |
| "Hardware-accelerated graphics is unavailable. Displaying fewer markers …" | MATLAB draws fewer markers than a plot holds. Figures with many markers (the corner plots) are written with a warning and a note in the index of their analysis README. Render again with working graphics hardware and the display on. |
| a figure differs from the shipped PNG in some pixels | anti-aliasing differs between computers; the plotted content is the same |
| errors about long paths on Windows | move the repository or the `OutputFolder` to a shorter path ([section 1](#1-installation)) |
| "… was written by step … of this run but is missing since" | a file of an earlier step was deleted; rerun that step in the same run folder |

## 12. Using the code for new work

The entry points reproduce and rerun the thesis. For new work, the functions they call can be used directly. Each
recipe below was run with the shipped results (MATLAB R2025b, UQLab 2.3.0, 6 Nov 2026), from the repository folder
and with the UQLab folder in `s.paths.uqlabRoot` of `study_settings.m` ([section 1](#1-installation); these recipes do
not read the environment variable `UQLAB_ROOT`). The best fit also needs the Optimization Toolbox (`lsqnonlin`), the
Global Optimization Toolbox (`MultiStart`) and the Statistics and Machine Learning Toolbox (`lhsdesign`).

### Invert new or measured closing pressures

The fixed-route GP describes the default protocol (0.4 kPa/s, hold 30 s, pause 12 s) with the probes D2 and D6, so
the pressures must come from that protocol: six closing pressures in mbar, in the order of the dataset's outputs
(`pcl1_D2_mbar`, `pcl2_D2_mbar`, `pcl3_D2_mbar`, `pcl1_D6_mbar`, `pcl2_D6_mbar`, `pcl3_D6_mbar`). The likelihood is
that of the thesis: the measurement error of A.2 (8 %) and the calibrated GP error.

```matlab
addpath('src');
s = study_settings();
% s.paths.uqlabRoot = getenv('UQLAB_ROOT');          % if the settings file does not name the UQLab folder
study.activate_environment(s);                       % UQLab
runRoot = fullfile(tempdir, 'my_inversion', 'real', 'runs', 'r1');   % a label: these calls write nothing
cfg = study.project_config(s, 'Route', 'real', 'RunRoot', runRoot, 'Stage', 4);
P = parameters.parameter_space(cfg);                 % the four parameters and their prior bounds
gp = getfield(load('thesis_results/fixed/02_surrogates/data/models/gp_surrogate.mat', 'gp'), 'gp');
data = readtable('data/fixed/fixed_dataset.csv');
y = data{data.CaseID == 119, cfg.outputNames}        % a test: the pressures of case 119; or your six values
```

**The best fit** (a few minutes; no uncertainty): the parameters at which the GP mean comes closest to the six
pressures in the prior box, the answer of the GP-mean inversion (settings A.13).

```matlab
fit = inversion.gp_mean_best_fit(gp, y, P.bounds, cfg.gpMeanInversion.bestFit);
fit.theta        % m3_f_RD, m3_e_RD, log10 of k0_RD, Thickness_RD (case 119: 96.3, 360.9, -1.864, 1.941)
fit.residual     % y minus the GP mean at the best fit, mbar
```

**The posterior** (one AIES ensemble of 40 walkers; 2,000 steps take about 50 minutes on a workstation). The scenario
(`measurement_plus_gp`, or `gp_only` with `'measurementCV'` 0) and the design (`all_six`, `d2_only`, `d6_only`,
`cycle_1_only`, `ratios_only`, `physics_guided_full_rank_six`) are those of [section 5](#5-what-each-step-computes):

```matlab
scenario = inversion.scenario_registry('measurement_plus_gp');
design = inversion.design_registry('all_six');
opts = struct('scenarioTag', scenario.tag, 'observationSource', scenario.observationSource, ...
    'uncertaintyMode', scenario.uncertaintyMode, 'measurementCV', cfg.meas_cv, ...
    'emulatorErrorCalibrationVersion', cfg.inversion.emulatorErrorCalibrationVersion, ...
    'outputs', design.sourceOutputIndices, 'observationTransform', design.observationTransform);
request = inversion.sampler_request_config(cfg, 'AIES', 2000);   % for a trial: request.mcmc.n_steps = 200;
rng(1, 'twister');                                   % the seed of this ensemble
R = inversion.bayes_invert(gp, y, P, request, opts);
[R.paramQ025; R.paramMedian; R.paramQ975]            % 2.5 %, 50 % and 97.5 % of each parameter
```

`R.postSample` holds the retained draws (the second half of the chain, every walker), `R.sampleArray` the same as
steps × parameters × walkers, and `R.logLikelihoodTrace` the sampler's log-likelihood of every step of the chain
(steps × walkers, the discarded first half included: the retained draws are its last
`size(R.sampleArray, 1)` rows). **Certified** as in the thesis: a second
ensemble with another seed, both healthy, and the two in agreement ([section 5](#5-what-each-step-computes));
otherwise two new ensembles of 5,000 steps (`inversion.sampler_request_config(cfg, 'AIES', 5000)`), never pooled:

```matlab
rng(2, 'twister');
R2 = inversion.bayes_invert(gp, y, P, request, opts);
agreement = inversion.posterior_reproducibility(R.sampleArray, R2.sampleArray, P.bounds, ...
    inversion.mcmc_diagnostic_thresholds(cfg));
certified = R.singleAnalysisHealth.pass && R2.singleAnalysisHealth.pass && ...
    agreement.hardDistributionAgreementPass
```

The posterior is then the draws of the first ensemble (`R`).

### Other cases, scenarios and designs

The inversion step runs any complete external case of the fixed dataset, as a whole grid of three scenarios and six
designs or cell by cell: [section 3](#3-the-settings-file), "Invert other cases, or one scenario or design". The
renders and the case outputs of other cases are settings too (section 3, "Render the outputs of other cases").

### New COMSOL data

A dataset in the format of `data/fixed/fixed_dataset.csv` ([data/README.md](../data/README.md): the columns, the units
and the split groups) is passed with `'FixedDataFile'` (or `s.fixed.dataset.file`). The likelihoods with GP error use
an emulator calibration estimated on the thesis split of the thesis dataset (`config/fixed_emulator_calibration.json`,
settings A.3), and the steps refuse, before computing anything, a dataset whose cases differ from those the
calibration was estimated on (its CaseIDs; at the inversion also the split and the outputs each development case
observes):

```text
The fixed dataset does not belong to the frozen emulator calibration.
  dataset:     ...\new_dataset.csv (451 cases)
  calibration: ...\config\fixed_emulator_calibration.json (estimated on 452 cases: 391 development + 61 external)
Use the 452-case dataset in data/fixed/ or a calibration estimated on your dataset.
```

The values are not compared: new pressures for the same 452 cases pass this check. A GP retrained on new COMSOL data,
for other cases or for the same ones, therefore needs its own emulator calibration (a record in the format of
`config/fixed_emulator_calibration.json`), which this version does not write.

## Appendix A. Glossary

The terms used in the code, the results and the thesis, and the older names that saved records still use.

### Problem and data

| Term | Meaning |
|---|---|
| Fixed route | The study at the default suction protocol: four material parameters → six closing pressures, `y = f(θ)`. Code and records call it `real`. |
| Generalized route | The study over suction protocols: four material parameters and three protocol inputs → six closing pressures, `y = f(θ, φ)`. The protocol inputs are known controls, not unknowns. Code and records call it `real_extended`. |
| Material parameters θ | The four reticular-dermis parameters: `m3_f_RD` (elastic-fibre coefficient, 50–300, dimensionless), `m3_e_RD` (dissipative-fibre coefficient, 0–1000, dimensionless), `log10_k0_RD` (log10 of the permeability k0, k0 in 0.005–0.05 mm⁴/(N·s)) and `Thickness_RD` (1.0–2.5 mm). Thesis symbols: m<sub>3f,RD</sub>, m<sub>3e,RD</sub>, log<sub>10</sub>(k<sub>0,RD</sub>), t<sub>RD</sub>. |
| Protocol inputs φ | `log10_abs_suction_rate` (rate 0.2–2.0 kPa/s, default 0.4), `hold_dur_s` (10–45 s, default 30), `pause_dur_s` (5–25 s, default 12). |
| Closing pressures | The six outputs, in this order: `pcl1_D2_mbar`, `pcl2_D2_mbar`, `pcl3_D2_mbar`, `pcl1_D6_mbar`, `pcl2_D6_mbar`, `pcl3_D6_mbar`: cycles 1–3 of the D2 and D6 probes, magnitudes in mbar. Thesis symbols p<sup>D2</sup><sub>cl,1</sub> … p<sup>D6</sup><sub>cl,3</sub>. |
| Model coordinates | The coordinates in which the surrogates, priors and posteriors work: the four parameters as listed above, with the permeability as log10(k0). Physical units are used only where a table or axis says so. |
| Complete / partial / unusable case | A COMSOL case with all six closing pressures, with some of them, or with none usable after quality control. Partial cases train the outputs they observe. |
| Development / external cases | The split of the complete cases by material group: development cases train and audit the surrogates; external (held-out) cases only assess them. |
| Duplicate group, split group | The group labels of the dataset tables. A duplicate group (`DuplicateGroup`, `V####`) holds the source rows with identical inputs, which become one case; a split group (`SplitGroup`, `G####`) holds the cases with identical material inputs, which the development/external split keeps on one side. `SplitRole` is a case's side in the split's own labels (`train`, and `validation` on the fixed route or `test` on the generalized route); `MethodologicalRole` names them development and external test. |
| Held-out outcome access | Reading the closing pressures of the external cases: the surrogate assessments, the generalized default-protocol comparison and, on the fixed route, the inversion (its observations) and the analyses of its posteriors (conditional inversion, recovery, design study, ratio-error curves), and the GP-mean inversion (its observations). The plan marks these steps; they run only when the call selects them (run switch or `'Steps'`), never in one call with the surrogate audit. |

### Surrogates

| Term | Meaning |
|---|---|
| Surrogate | A statistical model of the COMSOL map from inputs to the six closing pressures: a Gaussian process (GP; Matérn-3/2 kernel with one length scale per input) and a polynomial chaos expansion (PCE). |
| Emulator variance (calibrated) | The GP's uncertainty used in the likelihood: `v_emu = τ² · h^γ` per output, with `h = v_native / σ²_process`. The calibration (τ², γ) is a frozen record (fixed route γ = 0.302; generalized γ = 0.48225); loading it never refits it. |
| Approved package | The reviewed generalized surrogates: the dataset, GP and PCE of `thesis_results/generalized/` with the calibration and fit policy of `config/` (settings B.3), approved on 21 Sep 2026 for local scientific use. Every generalized step after the dataset uses it as it is; a refit is a side analysis. |
| Surrogate audit | The development audit of the surrogates (1,050 fits: kernels, seeds, training size, error model). Its results are shipped; it is not rerun. |

### Inversion

| Term | Meaning |
|---|---|
| Scenario | The observation-error model of the likelihood: `measurement_plus_gp` (8 % measurement CV plus the calibrated emulator variance), `gp_only` (emulator variance only), `gp_self_det` (a deterministic GP self-consistency check). |
| Observation design | The pressures an inversion uses: `all_six`, `d2_only`, `d6_only`, `cycle_1_only`, `ratios_only`, `physics_guided_full_rank_six`. |
| Cell | One inversion problem: a truth case × scenario × design (360 canonical cells: 20 truths × 3 scenarios × 6 designs). |
| Request, replicate, level | One AIES run of 40 interacting walkers is a request. Each cell runs two independently seeded requests (replicates 1 and 2) at 2,000 steps, and again at 5,000 steps if the pair does not certify. |
| Certification | The decision that a cell's posterior is reproducible: both replicates pass the health checks, and for every parameter the normalized Wasserstein distance between the two replicates and the differences of their 2.5 % and 97.5 % quantiles are at most 0.05 of the prior width. The results use certified cells and healthy fallbacks together, with the certified-only values alongside. |
| Provider | The posterior a cell contributes: replicate 1 of the certified level. The replicates are never pooled. |
| Healthy non-certified fallback | A cell whose requests are healthy but did not certify. It is shown with the certified cells and named in the index of every output and in `cell_status.csv`. |
| Unavailable cell | A cell without an admissible posterior. It stays an explicit row; it is never filled in. |
| Certified-only value | The value of an aggregate over the certified cells alone, next to the value over certified and fallback cells in every summary table (columns ending in `_certified_only`). |
| Matched cohort | The cases for which every compared design (or condition) has a posterior, so that comparisons use the same cases. |
| Conditional inversion | Inversions with material parameters fixed at the truth, by the condition table of the settings (A.9; the thesis B–F); the condition that fixes nothing (A) is the canonical inversion itself. |
| SD ratio to the reference | A free parameter's posterior SD under a condition over its posterior SD under A (all parameters free), for the same case and scenario; below 1 the condition narrows the posterior. |
| Replicate discrepancy | How much the two independently seeded replicates of one cell differ: the normalized Wasserstein distance of the certification, or the relative difference of their posterior SDs. |
| `logLikelihood` (draw files) | The log-likelihood of each retained draw, row by row with `drawsPhysical`: as the sampler computed it (`logLikelihoodSource` `sampler`), or the cell's likelihood evaluated at the draw after the run (`evaluated`: the shipped canonical files). The prior is uniform and constant inside the bounds, so the log-posterior is `logLikelihood` plus a constant. |

### Analyses and outputs

| Term | Meaning |
|---|---|
| Recovery | Coverage, contraction and recovery errors of the posteriors, their covariance eigen-analysis, the reconstruction of observed features and the downstream error budget, and the second-mode check of one cell. |
| Coverage (in names) | An inclusion rate: the fraction of case truths inside the posterior intervals, not a repeated-noise calibration. |
| Design study | The comparison of the six observation designs by Fisher information, posterior covariance and ranking. Thesis-era records call it Stage 9A. |
| Ratio discrepancy d | How far the cycle-to-cycle pressure ratios that one posterior draw predicts (the GP mean) are from the observed ones, weighted for the shared cycle-1 pressure of each probe, in units of the reference CV (settings 0.7, thesis 8 %): about 1 when they are off by about what independent errors of that size give. The level discrepancy measures the overall pressure level instead (section 5, `ratio_error_curves`). |
| Ratio-error curve | The bin medians of the ratio discrepancy (or of a ratio error) along one parameter within a posterior, below its marginal: descriptive, association and not causation. |
| Parameter combination, SD ratio | A weighted sum w'z of the prior-standardized parameters (prior SD 1 for unit length w); its SD ratio is its posterior SD, so 1 means the measurement leaves it at its prior width. "Identified combination": a best weak-pair combination with at most half the smaller SD ratio of its two parameters (settings A.12), a description, not a test (section 5, `combinations`). |
| Protocol screening | The local Fisher information of 730 candidate protocols over a common 1,000-point material Latin hypercube, with the approved generalized GP. It ranks protocols; it does not select or confirm one. Records call it Stage 9B-A. |
| Six objectives | The screening's objectives on the weak parameter pair (`m3_e_RD`, `log10_k0_RD`): the largest eigenvalue of the pair's covariance (primary: its mean over the materials), the four standardized marginal variances and the pair's trace. The covariance is `C = (I + F)⁻¹`; the pair's block is taken from C. |
| Protocol selection | The protocols the confirmation tests, set in the settings (B.7): given by their values (the thesis: the selection approved on 21 September 2026) or `'from_screening'`, the leader of each objective in the screening rankings. |
| Confirmation | The test of the selected protocols: 20 truths × 4 protocols (the default and three objective-focused ones), observations from new COMSOL runs, inversions in the `measurement_plus_gp` scenario with the `d2_only` design (`all_six` on the complete pairs only, descriptively), and 60 paired comparisons against one shared default posterior per material. Records call it Stage 9B-B. |
| Shared default | The one default-protocol cell of a material, against which all three focused protocols are compared. |
| Case folder | `thesis_results/<route>/cases/case_<CaseID>/`: the outputs of one case, one folder per step that draws them; which cases, scenarios and designs are drawn is set in the settings (A.10). |
| Per-case output | A figure or table of one case (one cell, or several cells of the case), named without the case, e.g. `measurement_plus_gp_all_six_corner.png`; the analysis README lists it in its section "Per-case outputs". |

### Running the code

| Term | Meaning |
|---|---|
| Reproduce mode | The default: render every figure and table from the saved results in `thesis_results/`; no fitting, no MCMC, no UQLab. |
| Rerun mode | Recompute the requested steps (`'Mode','rerun'`). Expensive steps also need `'ConfirmExpensive',true`. |
| Plan | `'Plan',true` prints what would run, what would be reused, the estimated cost and whether the call would be refused, and computes nothing. |
| Example scale | `'Scale','example'`: a small, labelled run of a route for trying the code. It is never a result. |
| Run folder | `runs/<run name>/`: the outputs of one call, laid out like `thesis_results/`, with bookkeeping in `_run/`. |
| Placed intermediates | Full-size intermediate outputs of the thesis runs that `thesis_results/` does not ship. Each analysis README names the command that regenerates them. |

### Names in saved records

File and folder names say what a file holds, and the columns of the shipped tables have readable names. Inside the
records, names of the pre-publication code remain where they belong to a record's format: schema versions
(`routeR_emulator_error_calibration_v3`, `real_extended_dataset_resolver_v4`, `stage9_rank_bootstrap_v1_tie_aware`),
status values (`STAGE3_COMPLETE`), setting names and the field names inside MAT files (listed below). They mean:

| Recorded name | Meaning |
|---|---|
| `S01` … `S07`, `stage01` … `stage07` | The steps of the pre-publication code: dataset, surrogates, sensitivity, inversion, recovery, design study, figures. |
| `Stage 9A`, `stage9` | The design study. |
| `Stage 9B`, `stage9b` (`9B-A`, `9B-B`) | The protocol screening (A) and the confirmation (B). |
| `routeR`, Route-R | The name of the pre-publication pipeline, kept in schema versions such as `routeR_emulator_error_calibration_v3`. |
| `real`, `real_extended` | The fixed and the generalized route. |
| `production` (in run names; `ProductionModel`; `production_tempered_local_diagonal_emulator_variance`) | What produced or entered the thesis results: the production runs of a campaign, the variance model that the likelihood uses (`ProductionModel`), and the calibrated emulator variance itself. |
| `qualification` (`…_qualification_20260920T221107Z`) | The generalized route's qualification run on the dataset frozen on 20 Sep 2026. Its GP was a Matérn-5/2 baseline, which was not approved (the approved GP is Matérn-3/2); its PCE is the approved PCE. Its tables are not shipped (no figure, table or step reads them). |
| `…Physical` (`drawsPhysical`, `TruthPhysical`, `CI025Physical`, …) | Values in model coordinates, with the permeability as log10(k0), not in physical units. |
| `+pipeline`, `+stage9`, `+analysis`, `+stage9b`, `+inverse`, `+diagnostics`, `+extended` | Packages of the pre-publication code, now `+study`, `+design_study`, `+recovery`, `+screening` and `+confirmation`, `+inversion`, `+inversion`, and `+data`/`+surrogates`/`+sensitivity`. |
| gamma, beta, h_dermis; "descriptor" for a parameter | Retired names of the material parameters in older records. In current records gamma is only the exponent of the emulator calibration. |

Field names inside MAT files keep their names; these hold readable labels, not identities:

| Field | Meaning |
|---|---|
| `developmentMaterialGroupIdentities`, `trainingMaterialGroupIdentities` (`dataset.mat`, its `outputTrainingEvidence`) | The duplicate-group labels `V####` of the development and training cases; the tables call them `DuplicateGroup` (`duplicate_group`). |
| `developmentSplitGroupIdentities`, `trainingSplitGroupIdentities` (`dataset.mat`; the `records` of the generalized ensembles) | The split-group labels `G####`; the tables call them `SplitGroup` (`split_group`). |

## Appendix B. Thesis figure map

Where each figure and table of the thesis comes from. The IDs F1–F17 follow the thesis figure plan. Paths are
relative to `thesis_results/`; the README of each analysis folder lists every figure and table with its meaning,
scope and command. The last column is the command that redraws a group from the shipped results.

| ID | Content | Files | Command |
|---|---|---|---|
| F1 | COMSOL model of the skin (layers, D2/D6 probes) | not produced by this code | – |
| F2 | suction protocol and closing-pressure events | not produced by this code | – |
| F3 | analysis workflow | not produced by this code; see [section 4](#4-entry-points-and-steps) | – |
| F4 | dataset: output availability, training support, 391/61 split | `fixed/01_dataset/figures/dataset_availability_patterns.png`, `dataset_output_distributions.png`, `dataset_mean_cycle_pressures*.png`; tables `fixed/01_dataset/tables/dataset_counts`, `development_cases_per_output` | `run_fixed_study('Steps',{'dataset'})` |
| F5 | fixed GP/PCE validation, held out and cross-validated | `fixed/02_surrogates/figures/predicted_vs_comsol_gp.png`, `predicted_vs_comsol_pce.png`, `gp_pce_comparison.png`, `gp_predictive_coverage.png`, `audit_cv_*.png` | `run_fixed_study('Steps',{'surrogates'})` |
| F6 | kernel/seed stability and the calibrated emulator uncertainty | `fixed/02_surrogates/figures/audit_same_data_gp_*_seed_stability.png`, `audit_variance_model_*.png`, `audit_variance_scale_gamma_bootstrap_intervals.png`, `audit_standardized_residual_qq_pit.png`; table `emulator_variance_calibration` | `run_fixed_study('Steps',{'surrogates'})` |
| F7 | generalized surrogate at the default protocol, and the protocol-variable sensitivity | `generalized/04_default_protocol_comparison/figures/gp_vs_fixed_comsol.png`, `per_output_residual_comparison.png`, …; `generalized/03_sensitivity/figures/gp_protocol_variable_sensitivity.png`, `gp_material_protocol_*.png` | `run_generalized_study('Steps',{'default_protocol_comparison','sensitivity'})` |
| F8 | Sobol sensitivity of the pressures and of the derived features | `fixed/03_sensitivity/figures/gp_total_sobol.png`, `gp_second_order_sobol.png`, `ratio_sobol_*_total.png`, `ard_importance.png` (PCE versions alongside) | `run_fixed_study('Steps',{'sensitivity'})` |
| F9 | replicate agreement and certification | `fixed/04_inversion/figures/certification_overview.png`; per cell `fixed/cases/case_<CaseID>/inversion/tables/<scenario>_<design>_certification.csv` and the figures `<scenario>_<design>_diagnostics.png`, `<scenario>_<design>_traces.png`; table `fixed/04_inversion/tables/certification_counts` | `run_fixed_study('Steps',{'inversion'})` |
| F10 | recovery, coverage, contraction and representative corner plots | `fixed/05_recovery/figures/design_coverage*.png`, `design_contraction.png`, `design_recovery_error.png`, `fixed/cases/case_<CaseID>/recovery/figures/posterior_intervals.png`; corner plots `fixed/cases/case_<CaseID>/inversion/figures/<scenario>_all_six_corner.png` | `run_fixed_study('Steps',{'recovery','inversion'})` |
| F11 | conditional inversion and posterior eigendirections | `fixed/07_conditional_inversion/figures/*.png`; `fixed/05_recovery/figures/geometry_*.png` | `run_fixed_study('Steps',{'conditional_inversion','recovery'})` |
| F12 | feature reconstruction and error budget | `fixed/05_recovery/figures/reconstruction_*.png`, `error_budget_*.png`; per case `fixed/cases/case_<CaseID>/recovery/figures/measurement_plus_gp_all_six_predictive.png` | `run_fixed_study('Steps',{'recovery'})` |
| F13 | the six observation designs, matched comparison | `fixed/06_design_study/figures/<scenario>_design_ranking.png`, `<scenario>_target_q_information.png`, `<scenario>_fim_vs_posterior.png`, …; tables `fixed/06_design_study/tables/<scenario>_design_ranking` | `run_fixed_study('Steps',{'design_study'})` |
| F14 | protocol screening: rankings, score surfaces | `generalized/05_protocol_screening/figures/*.png`; tables `top10_protocols`, `six_objective_leaders` | `run_generalized_study('Steps',{'screen'})` |
| F15 | confirmation: paired default/selected posteriors | `generalized/06_confirmation/figures/paired_default_selected_*.png` (and `paired_common_*.png`: the materials whose four cells are certified), `showcase_marginals.png`, `showcase_corner.png`, `representative_posterior_overlays_*.png`; per pair `generalized/cases/case_<CaseID>/confirmation/figures/d2_only_<protocol>_vs_default_marginals.png` | `run_generalized_study('Steps',{'compare'})` |
| F16 | Fisher-predicted against observed paired improvement | `generalized/06_confirmation/figures/fim_proxy_vs_aies_lambda_change_*.png`; table `confirmation_fim_agreement` | as F15 |
| F17 | severity/power workflow | outlook, not produced by this code | – |

| Thesis table | File(s) |
|---|---|
| parameters, ranges, priors | [section 5](#5-what-each-step-computes); `study_settings.m` (A.1, B.1) |
| dataset cleaning and split | `fixed/01_dataset/tables/*`, `generalized/01_dataset/tables/*`; [section 7](#7-the-data) |
| surrogate validation and emulator calibration | `fixed/02_surrogates/tables/external_assessment_metrics`, `emulator_variance_calibration`, `gp_training_vs_external_metrics`, `gp_hyperparameters` (and the same for `generalized/02_surrogates`) |
| MCMC health, reproducibility and warnings | `fixed/04_inversion/tables/certification_counts`, `ensemble_bulk_ess_correction`; `fixed/04_inversion/data/diagnostics/`; per cell the certification summaries in the case folders |
| the six designs; design-study results | `fixed/06_design_study/tables/<scenario>_design_ranking` |
| conditional, feature and eigendirection results | `fixed/07_conditional_inversion/tables/conditional_matched_cohorts`, `conditional_sd_ratios`, `conditional_sd_ratio_summary`; `fixed/05_recovery/tables/*` |
| screening candidates and scores; protocol selection | `generalized/05_protocol_screening/tables/top10_protocols`, `six_objective_leaders`; the confirmation protocols in `study_settings.m` (B.7) |
| confirmation design | `generalized/06_confirmation/tables/confirmation_design` |
| confirmation results | `generalized/06_confirmation/tables/cell_status`, `confirmation_sd_ratio_summary`, `confirmation_objective_summary`, `confirmation_fim_agreement`, `confirmation_recovery_error`, `confirmation_comsol_outcomes`; the complete pairs `confirmation_complete_pairs_*` |
