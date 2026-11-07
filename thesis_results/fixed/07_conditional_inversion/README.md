# Fixed route: conditional inversion

Inversions with parameters fixed at the truth (160 cells: 158 certified, 2 healthy fallbacks) compared with the canonical inversions.

The availability report data/reports/conditional_inversion_availability.csv covers the conditions A-D (160 rows, 40 per condition, among them the not scheduled cells of B and C in measurement_plus_gp). The 80 cells of E and F (m3e_fixed and log10k0_fixed, gp_only and measurement_plus_gp, all certified) are in tables/cell_status.csv, which holds the status of every scheduled cell of A-F (200 rows: A, D, E and F in both scenarios, B and C in gp_only); the not scheduled cells are only in the availability report.

Posterior-based results show every cell with a selected provider together: the certified cells (two independent AIES ensembles that agree) and the healthy fallbacks (a healthy provider that was not certified). Unavailable cells have no posterior and stay blank. The index names, for each output, the cells it shows and which of them are healthy fallbacks or unavailable; a figure of one case gives its status in the title. Summary tables give next to each value its value over the certified cells alone (columns ending in `_certified_only`).

The status of every cell: [`cell_status.csv`](tables/cell_status.csv).

## Contents

| Folder | Holds |
|---|---|
| `figures/` | 11 figures |
| `tables/` | 4 tables (CSV) |
| `data/` | the saved results the figures, tables and later steps read (a rerun of the steps also writes further records): 167 files |
| `../cases/` | 1 figure and 1 table (CSV) of single cases, in the case folders (section Per-case outputs) |

## Figures and tables

| File | Title | Shows | Scope | Command |
|---|---|---|---|---|
| [gp_only_coverage50.png](figures/gp_only_coverage50.png) | gp_only: 50% truth inclusion under oracle conditions A--F (exact matched N = 20) | Conditional inversion (parameters fixed at the truth) against the canonical inversion. Healthy fallback: gp_only, all_six, baseline: 131, 48, 249; gp_only, all_six, m3f_and_thickness_fixed: 48; gp_only, all_six, m3f_fixed: 48. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [gp_only_coverage95.png](figures/gp_only_coverage95.png) | gp_only: 95% truth inclusion under oracle conditions A--F (exact matched N = 20) | Conditional inversion (parameters fixed at the truth) against the canonical inversion. Healthy fallback: gp_only, all_six, baseline: 131, 48, 249; gp_only, all_six, m3f_and_thickness_fixed: 48; gp_only, all_six, m3f_fixed: 48. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [gp_only_median_recovery_error.png](figures/gp_only_median_recovery_error.png) | gp_only: truth recovery under oracle conditions A--F (exact matched N = 20) | Conditional inversion (parameters fixed at the truth) against the canonical inversion. Healthy fallback: gp_only, all_six, baseline: 131, 48, 249; gp_only, all_six, m3f_and_thickness_fixed: 48; gp_only, all_six, m3f_fixed: 48. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [gp_only_normalized_posterior_sd.png](figures/gp_only_normalized_posterior_sd.png) | gp_only: posterior spread under oracle conditions A--F (exact matched N = 20) | Conditional inversion (parameters fixed at the truth) against the canonical inversion. Healthy fallback: gp_only, all_six, baseline: 131, 48, 249; gp_only, all_six, m3f_and_thickness_fixed: 48; gp_only, all_six, m3f_fixed: 48. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [measurement_plus_gp_A_vs_D.png](figures/measurement_plus_gp_A_vs_D.png) | measurement_plus_gp: all-free A versus m3_f-and-Thickness-fixed D (exact matched N = 20) | Conditional inversion (parameters fixed at the truth) against the canonical inversion | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [measurement_plus_gp_A_vs_E.png](figures/measurement_plus_gp_A_vs_E.png) | measurement_plus_gp: all-free A versus m3_e-fixed E (exact matched N = 20) | Conditional inversion (parameters fixed at the truth) against the canonical inversion | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [measurement_plus_gp_A_vs_F.png](figures/measurement_plus_gp_A_vs_F.png) | measurement_plus_gp: all-free A versus log10_k0-fixed F (exact matched N = 20) | Conditional inversion (parameters fixed at the truth) against the canonical inversion | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [measurement_plus_gp_coverage50.png](figures/measurement_plus_gp_coverage50.png) | measurement_plus_gp: 50% truth inclusion under oracle conditions A, D, E, F (exact matched N = 20) | Conditional inversion (parameters fixed at the truth) against the canonical inversion | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [measurement_plus_gp_coverage95.png](figures/measurement_plus_gp_coverage95.png) | measurement_plus_gp: 95% truth inclusion under oracle conditions A, D, E, F (exact matched N = 20) | Conditional inversion (parameters fixed at the truth) against the canonical inversion | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [measurement_plus_gp_median_recovery_error.png](figures/measurement_plus_gp_median_recovery_error.png) | measurement_plus_gp: truth recovery under oracle conditions A, D, E, F (exact matched N = 20) | Conditional inversion (parameters fixed at the truth) against the canonical inversion | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [measurement_plus_gp_normalized_posterior_sd.png](figures/measurement_plus_gp_normalized_posterior_sd.png) | measurement_plus_gp: posterior spread under oracle conditions A, D, E, F (exact matched N = 20) | Conditional inversion (parameters fixed at the truth) against the canonical inversion | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [cell_status.csv](tables/cell_status.csv) | Status of every scheduled conditional cell and of its canonical reference (condition baseline): certified, healthy fallback or unavailable, with the provider, whether it counts in the certified-only values and why it is not certified | Conditional inversion (parameters fixed at the truth) against the canonical inversion. Healthy fallback: gp_only, all_six, baseline: 131, 48, 249; gp_only, all_six, m3f_and_thickness_fixed: 48; gp_only, all_six, m3f_fixed: 48. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [conditional_matched_cohorts.csv](tables/conditional_matched_cohorts.csv) | Conditional inversion: matched case cohorts of the condition comparisons, cases with a posterior (certified or healthy fallback) for every condition, and the same over the certified cells alone | Conditional inversion (parameters fixed at the truth) against the canonical inversion. Healthy fallback: gp_only, all_six, baseline: 131, 48, 249; gp_only, all_six, m3f_and_thickness_fixed: 48; gp_only, all_six, m3f_fixed: 48. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [conditional_sd_ratio_summary.csv](tables/conditional_sd_ratio_summary.csv) | Conditional inversion: per scenario, condition and free parameter, the median and quartiles over the matched cases of the SD ratio to the reference and of the recovery errors, and the median replicate SD difference, each followed by its value over the certified cells alone | Conditional inversion (parameters fixed at the truth) against the canonical inversion. Healthy fallback: gp_only, all_six, baseline: 131, 48, 249; gp_only, all_six, m3f_and_thickness_fixed: 48; gp_only, all_six, m3f_fixed: 48. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |
| [conditional_sd_ratios.csv](tables/conditional_sd_ratios.csv) | Conditional inversion: per matched case, condition and free parameter, the posterior SD over the prior SD of the condition's cell and of the reference (all parameters free), their ratio, the replicate discrepancy of both cells (normalized Wasserstein distance and relative SD difference of the two replicates) and their recovery errors | Conditional inversion (parameters fixed at the truth) against the canonical inversion. Healthy fallback: gp_only, all_six, baseline: 131, 48, 249; gp_only, all_six, m3f_and_thickness_fixed: 48; gp_only, all_six, m3f_fixed: 48. | 20 cases: certified and healthy fallback | `run_fixed_study('Steps',{'conditional_inversion'})` |

## Per-case outputs

The outputs of single cases lie in the case folders of the route, `../cases/case_<CaseID>/<step>/figures/` and `tables/`, for the cases of the settings (section A.10 of `study_settings.m`). One row per output: what it shows and its cases, each linked to its file; the title of each figure names its case and the status of its cells.

| Output | Shows | Cases | Command |
|---|---|---|---|
| `selected_posteriors.png` | Conditional posteriors of the weak parameters, per condition, next to the all-six posterior | [131](../cases/case_131/conditional_inversion/figures/selected_posteriors.png) | `run_fixed_study('Steps',{'conditional_inversion'})` |
| `selected_posteriors_statistics.csv` | Posterior marginal statistics of the conditional posteriors of the case | [131](../cases/case_131/conditional_inversion/tables/selected_posteriors_statistics.csv) | `run_fixed_study('Steps',{'conditional_inversion'})` |

Inside `data/`:

- `draws/` (161 files): every retained draw of both replicates of the provider's level, at full precision, for each certified cell and healthy fallback: one file per cell, with index.csv
- `reports/` (4 files)
- `seeds/` (1 file): the campaign's seed record (seed_record.csv): the seed of every request of its cells, recorded (the frozen record config/seeds/mcmc_seeds.csv) or by the seed rule of the settings
- files: `cell_status.csv`

## Commands

```matlab
run_fixed_study('Steps',{'conditional_inversion'})                  % re-render figures/ and tables/ from data/
run_fixed_study('Mode','rerun','Steps',{'conditional_inversion'},'Plan',true)  % show what a recomputation costs
```
