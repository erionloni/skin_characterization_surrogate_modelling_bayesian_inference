# Fixed route: dataset and split

The 452 usable cases (306 complete, 146 partial), their classification, the 391 development / 61 external split and the per-output training support.

## Contents

| Folder | Holds |
|---|---|
| `figures/` | 4 figures |
| `tables/` | 6 tables (CSV) |
| `data/` | the saved results the figures, tables and later steps read (a rerun of the steps also writes further records): 5 files |

## Figures and tables

| File | Title | Shows | Scope | Command |
|---|---|---|---|---|
| [dataset_availability_patterns.png](figures/dataset_availability_patterns.png) | Output availability patterns (1 observed, 0 missing; missing is not zero pressure) | Which outputs are observed, per availability pattern | not posterior-based | `run_fixed_study('Steps',{'dataset'})` |
| [dataset_mean_cycle_pressures.png](figures/dataset_mean_cycle_pressures.png) | Mean closing pressure by probe and cycle (each bar over the cases where that pressure is observed) | Mean pressure per probe and cycle, each over its own observed cases | not posterior-based | `run_fixed_study('Steps',{'dataset'})` |
| [dataset_mean_cycle_pressures_complete_cases.png](figures/dataset_mean_cycle_pressures_complete_cases.png) | Mean closing pressure by probe and cycle (matched cohort: the 306 complete cases) | Mean pressure per probe and cycle over the 306 complete cases (the table also: SD and range) | not posterior-based | `run_fixed_study('Steps',{'dataset'})` |
| [dataset_output_distributions.png](figures/dataset_output_distributions.png) | Fixed dataset (452 cases): closing-pressure distributions | Histogram of each closing pressure over its observed cases | not posterior-based | `run_fixed_study('Steps',{'dataset'})` |
| [dataset_availability_patterns.csv](tables/dataset_availability_patterns.csv) | Number of cases per output availability pattern | Which outputs are observed, per availability pattern | not posterior-based | `run_fixed_study('Steps',{'dataset'})` |
| [dataset_counts.csv](tables/dataset_counts.csv) | Fixed route: usable cases, completeness and development/external split | Usable, complete, partial, development and external case counts | not posterior-based | `run_fixed_study('Steps',{'dataset'})` |
| [dataset_mean_cycle_pressures.csv](tables/dataset_mean_cycle_pressures.csv) | Observed count, mean, SD and range of each closing pressure | Mean pressure per probe and cycle, each over its own observed cases | not posterior-based | `run_fixed_study('Steps',{'dataset'})` |
| [dataset_mean_cycle_pressures_complete_cases.csv](tables/dataset_mean_cycle_pressures_complete_cases.csv) | Mean, SD and range of each closing pressure over the 306 complete cases | Mean pressure per probe and cycle over the 306 complete cases (the table also: SD and range) | not posterior-based | `run_fixed_study('Steps',{'dataset'})` |
| [dataset_output_distributions.csv](tables/dataset_output_distributions.csv) | Histogram counts of each closing pressure (15 equal-width bins over its observed values) | Histogram of each closing pressure over its observed cases | not posterior-based | `run_fixed_study('Steps',{'dataset'})` |
| [development_cases_per_output.csv](tables/development_cases_per_output.csv) | Fixed route: development cases available for training each output | Development cases available for training each output | not posterior-based | `run_fixed_study('Steps',{'dataset'})` |

Inside `data/`:

- files: `dataset.mat`, `development_external_role_manifest.csv`, `output_availability_patterns.csv`, `per_output_development_support.csv`, `split_manifest.csv`

## Commands

```matlab
run_fixed_study('Steps',{'dataset'})                  % re-render figures/ and tables/ from data/
run_fixed_study('Mode','rerun','Steps',{'dataset'},'Plan',true)  % show what a recomputation costs
```
