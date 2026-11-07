# Protocol screening

Local Fisher information of 730 candidate protocols over 1,000 material states, the six design objectives (primary: mean largest eigenvalue of the weak-pair covariance) and the rankings.

AggregateWorstDirectionSDImprovement = 1 - sqrt(1 - RelativePrimaryImprovement): the improvement of the primary objective over the default protocol in SD units (the objective is a variance), a transform of RelativePrimaryImprovement and not a further criterion; the default-relative figure draws both.

## Contents

| Folder | Holds |
|---|---|
| `figures/` | 12 figures |
| `tables/` | 2 tables (CSV) |
| `data/` | the saved results the figures, tables and later steps read (a rerun of the steps also writes further records): 15 files |

## Figures and tables

| File | Title | Shows | Scope | Command |
|---|---|---|---|---|
| [default_relative_improvement.png](figures/default_relative_improvement.png) | Operational default-relative screening metrics | Screening of 730 protocols over 1,000 material states | not posterior-based | `run_generalized_study('Steps',{'screen'})` |
| [default_vs_operational_rank1_candidate.png](figures/default_vs_operational_rank1_candidate.png) | Default versus the best-ranked candidate in the investigated grid | Screening of 730 protocols over 1,000 material states | not posterior-based | `run_generalized_study('Steps',{'screen'})` |
| [mean_target_variance_log10k0_heatmaps.png](figures/mean_target_variance_log10k0_heatmaps.png) | Operational mean target variance: log10_k0_RD by protocol grid slice | Screening of 730 protocols over 1,000 material states | not posterior-based | `run_generalized_study('Steps',{'screen'})` |
| [mean_target_variance_m3e_heatmaps.png](figures/mean_target_variance_m3e_heatmaps.png) | Operational mean target variance: m3_e_RD by protocol grid slice | Screening of 730 protocols over 1,000 material states | not posterior-based | `run_generalized_study('Steps',{'screen'})` |
| [measurement_primary_score_all_candidates.png](figures/measurement_primary_score_all_candidates.png) | Measurement covariance ranking across eligible investigated candidates | Screening of 730 protocols over 1,000 material states | not posterior-based | `run_generalized_study('Steps',{'screen'})` |
| [measurement_vs_operational_rank.png](figures/measurement_vs_operational_rank.png) | Measurement versus operational factual rankings | Screening of 730 protocols over 1,000 material states | not posterior-based | `run_generalized_study('Steps',{'screen'})` |
| [operational_primary_score_all_candidates.png](figures/operational_primary_score_all_candidates.png) | Operational covariance ranking across eligible investigated candidates | Screening of 730 protocols over 1,000 material states | not posterior-based | `run_generalized_study('Steps',{'screen'})` |
| [operational_protocol_space_heatmaps.png](figures/operational_protocol_space_heatmaps.png) | Operational mean target proxy λ_max by protocol grid slice | Screening of 730 protocols over 1,000 material states | not posterior-based | `run_generalized_study('Steps',{'screen'})` |
| [proposed_protocol_cross_objective_changes.png](figures/proposed_protocol_cross_objective_changes.png) | Selected protocols: default-relative reduction of each objective's mean score [%] | The three selected protocols: change of every objective against the default | not posterior-based | `run_generalized_study('Steps',{'screen'})` |
| [six_objective_operational_rankings.png](figures/six_objective_operational_rankings.png) | Six design objectives: operational covariance ranking of the 730 protocols | Six design objectives over the 730 candidate protocols | not posterior-based | `run_generalized_study('Steps',{'screen'})` |
| [top10_protocol_summary.png](figures/top10_protocol_summary.png) | Protocol coordinates of the operational top-ranked grid candidates | Screening of 730 protocols over 1,000 material states | not posterior-based | `run_generalized_study('Steps',{'screen'})` |
| [top10_supporting_metrics.png](figures/top10_supporting_metrics.png) | Supporting metrics for the operational top-ranked grid candidates | Screening of 730 protocols over 1,000 material states | not posterior-based | `run_generalized_study('Steps',{'screen'})` |
| [six_objective_leaders.csv](tables/six_objective_leaders.csv) | Best protocol for each of the six objectives and covariance views | Six design objectives over the 730 candidate protocols | not posterior-based | `run_generalized_study('Steps',{'screen'})` |
| [top10_protocols.csv](tables/top10_protocols.csv) | Ten best protocols by the primary objective, per covariance view | Ten best protocols by the primary objective, per covariance view | not posterior-based | `run_generalized_study('Steps',{'screen'})` |

Inside `data/`:

- `screen/` (10 files)
- `six_objective/` (5 files)

## Full-size intermediates not shipped

A run of this analysis also writes the intermediate outputs below into its `data/` folder. thesis_results/ does not ship them because of their size; the command regenerates them at full size in the run folder (runtime on one workstation).

| File in `data/` | Holds | Regenerate with | Runtime |
|---|---|---|---|
| `screen/local_information/local_information.mat` | the local Fisher information of 730 protocols at 1,000 material points | `run_generalized_study('Mode','rerun','Steps',{'screen'},'ConfirmExpensive',true)` | about 1 h |
| `six_objective/full_covariance_supplement.mat` | the full posterior covariances of the six-objective supplement | `run_generalized_study('Mode','rerun','Steps',{'screen','objective_supplement'},'ConfirmExpensive',true)` | about 1 h + about 30 min (32 min recorded) |
| `six_objective/checkpoints/block_<first protocol>.mat` (146 files) | the supplement's checkpoints, five protocols each | `run_generalized_study('Mode','rerun','Steps',{'screen','objective_supplement'},'ConfirmExpensive',true)` | about 1 h + about 30 min (32 min recorded) |

## Commands

```matlab
run_generalized_study('Steps',{'screen','objective_supplement','rankings'})                  % re-render figures/ and tables/ from data/
run_generalized_study('Mode','rerun','Steps',{'screen','objective_supplement','rankings'},'Plan',true)  % show what a recomputation costs
```
