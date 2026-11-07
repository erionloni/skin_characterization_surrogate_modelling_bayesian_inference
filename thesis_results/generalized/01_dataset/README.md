# Generalized route: dataset and split

The 939 usable cases (412 complete, 527 partial) over four material and three protocol inputs, the 857 development / 82 external split, protocol-space support and the feasibility audit.

## Contents

| Folder | Holds |
|---|---|
| `figures/` | 3 figures |
| `tables/` | 2 tables (CSV) |
| `data/` | the saved results the figures, tables and later steps read (a rerun of the steps also writes further records): 9 files |

## Figures and tables

| File | Title | Shows | Scope | Command |
|---|---|---|---|---|
| [case_completeness_status.png](figures/case_completeness_status.png) | Generalized campaign pair-status inventory | Campaign cases by pair status | not posterior-based | `run_generalized_study('Steps',{'dataset'})` |
| [input_distributions.png](figures/input_distributions.png) | Generalized complete-case input distributions | Development and held-out distributions of the seven inputs (from data/processed/selected_cases.csv) | not posterior-based | `run_generalized_study('Steps',{'dataset'})` |
| [protocol_space_support.png](figures/protocol_space_support.png) | Protocol-space support; colour = pause duration [s] | Coverage of the protocol space by the cases | not posterior-based | `run_generalized_study('Steps',{'dataset'})` |
| [dataset_counts.csv](tables/dataset_counts.csv) | Generalized route: cases by split role and by campaign pair status | Generalized dataset: cases, split and training evidence | not posterior-based | `run_generalized_study('Steps',{'dataset'})` |
| [development_cases_per_output.csv](tables/development_cases_per_output.csv) | Generalized route: training evidence per output | Generalized dataset: cases, split and training evidence | not posterior-based | `run_generalized_study('Steps',{'dataset'})` |

Inside `data/`:

- `metadata/` (2 files)
- `processed/` (1 file)
- `registries/` (1 file)
- `splits/` (1 file)
- files: `complete_case_scientific_table.csv`, `dataset.mat`, `output_availability_patterns.csv`, `output_training_evidence.csv`

## Commands

```matlab
run_generalized_study('Steps',{'dataset'})                  % re-render figures/ and tables/ from data/
run_generalized_study('Mode','rerun','Steps',{'dataset'},'Plan',true)  % show what a recomputation costs
```
