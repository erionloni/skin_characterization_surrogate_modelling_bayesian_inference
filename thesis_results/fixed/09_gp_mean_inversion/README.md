# Fixed route: GP-mean inversion

A fourth inversion scenario, gp_mean_det (GP mean, COMSOL data): the held-out COMSOL pressures of the truths (all six outputs) with the GP mean as the forward model and the numerical floor only. Its AIES campaign gives no posterior; its answer is the best fit of the GP mean to the six pressures per case, against the truth and the posterior means of the three canonical scenarios.

The scenario (settings A.13): per truth the six held-out COMSOL pressures, the observation vectors of Measurement + GP and GP only, with the GP predictive mean as the forward model and the variance of the GP self-consistency scenario: the numerical floor of settings A.2 only (1e-6 mbar), no GP predictive variance and no measurement noise. Prior, AIES sampler (40 walkers, 2,000 steps, 5,000 on escalation, two independent ensembles per cell), health checks and certification are those of the canonical inversion; a cell that does not certify is a healthy fallback when one of its requests is healthy (the highest level first, replicate 1 first), otherwise unavailable. The seeds follow the MCMC seed rule of the settings with scenario number 4 (`data/seeds/seed_record.csv`), checked against every seed used before.

No posterior is available for this scenario. With the floor as the only variance (1e-12 mbar^2, far below the squared residuals the GP mean leaves at any point) the posterior is practically a point, which the AIES ensembles cannot sample: in the thesis campaign every cell escalated to 5,000 steps and ended unresolved with frozen walker trajectories. No request of 19 of the 20 cells passed the health check (unavailable); of case 131, replicate 1 at 5,000 steps did (a healthy fallback). The status table, the draws and the posterior tables and figures show the campaign as it ran.

The scenario's answer is that point, computed directly (`data/best_fit`, no sampler): per case theta* = argmin over theta of sum_i (y_i - mu_i(theta))^2, the six COMSOL pressures y against the GP mean mu within the prior bounds (model coordinates), the maximum of the likelihood and, under the uniform prior, of the posterior. The search: lsqnonlin (trust-region-reflective) with the parameters scaled to [0, 1], inside MultiStart from the start points of a Latin hypercube; starts, seed and tolerances in settings A.13. theta* is where the GP mean fits the COMSOL pressures best, not necessarily the truth. `tables/best_fit_*` and the best-fit figures compare it with the truth and with the posterior means of the three canonical scenarios.

The comparisons (`tables/comparison*.csv`, `tables/best_fit_comparison.csv`, the cohort and error figures) read the canonical cells from the shipped results (`fixed/05_recovery/data/tables/posterior_parameter_cells.csv`, `fixed/04_inversion/data/cell_status.csv`): nothing of them is recomputed. Error: the estimate minus the truth; normalized SD and error: over the prior SD and the prior width (model coordinates, log10 of the permeability).

Posterior-based results show every cell with a selected provider together: the certified cells (two independent AIES ensembles that agree) and the healthy fallbacks (a healthy provider that was not certified). Unavailable cells have no posterior and stay blank. The index names, for each output, the cells it shows and which of them are healthy fallbacks or unavailable; a figure of one case gives its status in the title. Summary tables give next to each value its value over the certified cells alone (columns ending in `_certified_only`).

The status of every cell: [`cell_status.csv`](tables/cell_status.csv).

## Contents

| Folder | Holds |
|---|---|
| `figures/` | 3 figures |
| `tables/` | 6 tables (CSV) |
| `data/` | the saved results the figures, tables and later steps read (a rerun of the steps also writes further records): 9 files |
| `../cases/` | 3 figures and 1 table (CSV) of single cases, in the case folders (section Per-case outputs) |

## Figures and tables

| File | Title | Shows | Scope | Command |
|---|---|---|---|---|
| [best_fit_against_truth.png](figures/best_fit_against_truth.png) | All six outputs, 20 cases: best fit of the GP mean to the COMSOL pressures against the truth (axes: the prior range) | Per parameter, every case: the best fit against the truth, on the prior range | not posterior-based | `run_fixed_study('Steps',{'gp_mean_inversion'})` |
| [best_fit_error_comparison.png](figures/best_fit_error_comparison.png) | All six outputs, 20 cases: error of the best fit of the GP mean to the COMSOL pressures and of the posterior means in the three scenarios | Per parameter, every case: the absolute error over the prior width of the best fit and of the posterior means of the three canonical scenarios (log scale). Healthy fallback: gp_only, all_six: 131, 48, 249; gp_self_det, all_six: 131, 113, 172, 206, 246, 249, 116. Unavailable: gp_self_det, all_six: 230, 232, 48, 96, 83. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'gp_mean_inversion'})` |
| [cohort_sd_and_error.png](figures/cohort_sd_and_error.png) | All six outputs, 20 cases: normalized posterior SD and error of the posterior mean in four scenarios | Per parameter, every case in four scenarios: normalized posterior SD and absolute error of the posterior mean (log scale). Healthy fallback: gp_mean_det, all_six: 131; gp_only, all_six: 131, 48, 249; gp_self_det, all_six: 131, 113, 172, 206, 246, 249, 116. Unavailable: gp_mean_det, all_six: 113, 230, 232, 42, 93, 172, 12, 119, 220, 206, 48, 96, 215, 83, 146, 166, 246, 249, 116; gp_self_det, all_six: 230, 232, 48, 96, 83. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'gp_mean_inversion'})` |
| [best_fit_comparison.csv](tables/best_fit_comparison.csv) | Error of the best fit and of the posterior means of the three canonical scenarios | Per case and parameter: the error of the best fit next to the errors of the posterior means of Measurement + GP, GP only and GP self-consistency (as shipped). Healthy fallback: gp_only, all_six: 131, 48, 249; gp_self_det, all_six: 131, 113, 172, 206, 246, 249, 116. Unavailable: gp_self_det, all_six: 230, 232, 48, 96, 83. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'gp_mean_inversion'})` |
| [best_fit_vs_truth.csv](tables/best_fit_vs_truth.csv) | Best fit of the GP mean to the COMSOL pressures against the truth | Per case and parameter: the best fit of the GP mean to the six COMSOL pressures (theta*) against the truth, its error, whether it lies on a prior bound, the sum of squared residuals at theta* and at the truth, the distinct local minima and the starts that reached the best | not posterior-based | `run_fixed_study('Steps',{'gp_mean_inversion'})` |
| [cell_status.csv](tables/cell_status.csv) | Status of the GP-mean cells | Per GP-mean cell: certified, healthy fallback or unavailable, the provider, the reason, the chain levels run and whether it escalated. Healthy fallback: gp_mean_det, all_six: 131. Unavailable: gp_mean_det, all_six: 113, 230, 232, 42, 93, 172, 12, 119, 220, 206, 48, 96, 215, 83, 146, 166, 246, 249, 116. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'gp_mean_inversion'})` |
| [comparison.csv](tables/comparison.csv) | Posterior SD and error per case and parameter in the four scenarios | Per case and parameter: posterior SD and error of the posterior mean in the four scenarios side by side (the canonical cells as shipped). Healthy fallback: gp_mean_det, all_six: 131; gp_only, all_six: 131, 48, 249; gp_self_det, all_six: 131, 113, 172, 206, 246, 249, 116. Unavailable: gp_mean_det, all_six: 113, 230, 232, 42, 93, 172, 12, 119, 220, 206, 48, 96, 215, 83, 146, 166, 246, 249, 116; gp_self_det, all_six: 230, 232, 48, 96, 83. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'gp_mean_inversion'})` |
| [comparison_summary.csv](tables/comparison_summary.csv) | Posterior SD, error and truth inclusion per scenario and parameter over the cases | Per scenario and parameter over the cases: median normalized posterior SD and error, how often the 95% interval contains the truth; certified cells alone in the _certified_only columns. Healthy fallback: gp_mean_det, all_six: 131; gp_only, all_six: 131, 48, 249; gp_self_det, all_six: 131, 113, 172, 206, 246, 249, 116. Unavailable: gp_mean_det, all_six: 113, 230, 232, 42, 93, 172, 12, 119, 220, 206, 48, 96, 215, 83, 146, 166, 246, 249, 116; gp_self_det, all_six: 230, 232, 48, 96, 83. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'gp_mean_inversion'})` |
| [posterior_summary.csv](tables/posterior_summary.csv) | Posterior summary per case and parameter (GP mean, COMSOL data) | Per case and parameter (GP mean, COMSOL data): posterior mean and SD, 95% interval, truth, error of the posterior mean, truth inside the interval. Healthy fallback: gp_mean_det, all_six: 131. Unavailable: gp_mean_det, all_six: 113, 230, 232, 42, 93, 172, 12, 119, 220, 206, 48, 96, 215, 83, 146, 166, 246, 249, 116. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'gp_mean_inversion'})` |

## Per-case outputs

The outputs of single cases lie in the case folders of the route, `../cases/case_<CaseID>/<step>/figures/` and `tables/`, for the cases of the settings (section A.13 of `study_settings.m`). One row per output: what it shows and its cases, each linked to its file; the title of each figure names its case and the status of its cells.

| Output | Shows | Cases | Command |
|---|---|---|---|
| `best_fit_pressures.png` | The six COMSOL pressures, the GP mean at the best fit and at the truth, and the residuals | [119](../cases/case_119/gp_mean_inversion/figures/best_fit_pressures.png) | `run_fixed_study('Steps',{'gp_mean_inversion'})` |
| `four_scenario_marginals.png` | Posterior marginals of the case in the four scenarios (all six outputs) | [119](../cases/case_119/gp_mean_inversion/figures/four_scenario_marginals.png) | `run_fixed_study('Steps',{'gp_mean_inversion'})` |
| `gp_mean_det_all_six_marginals.png` | Posterior marginals of the four parameters in the scenario GP mean, COMSOL data (all six outputs) | [131](../cases/case_131/gp_mean_inversion/figures/gp_mean_det_all_six_marginals.png) (healthy fallback) | `run_fixed_study('Steps',{'gp_mean_inversion'})` |
| `gp_mean_det_all_six_statistics.csv` | Posterior marginal statistics of the case in the scenario GP mean, COMSOL data | [131](../cases/case_131/gp_mean_inversion/tables/gp_mean_det_all_six_statistics.csv) (healthy fallback) | `run_fixed_study('Steps',{'gp_mean_inversion'})` |

Inside `data/`:

- `best_fit/` (3 files): the best fit of every case, theta* = argmin of the sum of squared residuals between the six COMSOL pressures and the GP mean within the prior bounds (settings A.13; no sampler): best_fit.csv (per case and parameter theta*, the truth, the error, the prior bounds, the objective at theta* and at the truth, the search), residuals.csv (per case and output the pressure, the GP mean at theta* and at the truth, the residuals) and local_minima.csv (per case every distinct minimum the starts reached)
- `draws/` (2 files): every retained draw of both replicates of the provider's level, at full precision, for each certified cell and healthy fallback: one file per cell, with index.csv
- `seeds/` (1 file): the campaign's seed record (seed_record.csv): the seed of every request of its cells, by the MCMC seed rule of the settings with scenario number 4
- files: `cell_status.csv`, `comparison.csv`, `posterior_parameter_cells.csv`

## Commands

```matlab
run_fixed_study('Steps',{'gp_mean_inversion'})                  % re-render figures/ and tables/ from data/
run_fixed_study('Mode','rerun','Steps',{'gp_mean_inversion'},'Plan',true)  % show what a recomputation costs
```
