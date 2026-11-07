# Generalized route: default-protocol comparison

The generalized surrogate evaluated at the default protocol and compared with the fixed-route COMSOL results. Both datasets come from the same COMSOL model (the author's statement): the fixed CSV does not carry its provenance (model, probe geometry, closing extraction, units, protocol), and the statement, not a comparison of fields, resolves these eight fields (settings B.5); the numbers are those of the thesis.

The fixed COMSOL values form vertical stripes in the panels against them: COMSOL registers the closing on a 1 s time grid, so at the default 0.4 kPa/s the closing pressures of cycle 1 lie on a 4 mbar grid (all of pcl1_D2_mbar, nearly all of pcl1_D6_mbar; data/README.md, section "The COMSOL model"). The grid belongs to the COMSOL reference, not to the surrogate.

## Contents

| Folder | Holds |
|---|---|
| `figures/` | 6 figures |
| `tables/` | 1 table (CSV) |
| `data/` | the saved results the figures, tables and later steps read (a rerun of the steps also writes further records): 7 files |

## Figures and tables

| File | Title | Shows | Scope | Command |
|---|---|---|---|---|
| [error_vs_support_distance.png](figures/error_vs_support_distance.png) | Default-protocol error versus generalized support distance \| COMPATIBLE_REFERENCE \| development-only cross-route reference | Generalized surrogate at the default protocol against the fixed-route COMSOL values | not posterior-based | `run_generalized_study('Steps',{'default_protocol_comparison'})` |
| [gp_vs_fixed_comsol.png](figures/gp_vs_fixed_comsol.png) | generalized GP at the configured default protocol \| COMPATIBLE_REFERENCE \| development-only cross-route reference | Generalized surrogate at the default protocol against the fixed-route COMSOL values | not posterior-based | `run_generalized_study('Steps',{'default_protocol_comparison'})` |
| [interval_coverage_by_output.png](figures/interval_coverage_by_output.png) | Default-protocol empirical interval inclusion \| COMPATIBLE_REFERENCE \| development-only cross-route reference | Generalized surrogate at the default protocol against the fixed-route COMSOL values | not posterior-based | `run_generalized_study('Steps',{'default_protocol_comparison'})` |
| [pce_vs_fixed_comsol.png](figures/pce_vs_fixed_comsol.png) | generalized PCE at the configured default protocol \| COMPATIBLE_REFERENCE \| development-only cross-route reference | Generalized surrogate at the default protocol against the fixed-route COMSOL values | not posterior-based | `run_generalized_study('Steps',{'default_protocol_comparison'})` |
| [per_output_residual_comparison.png](figures/per_output_residual_comparison.png) | Default-protocol residual magnitude by output \| COMPATIBLE_REFERENCE \| development-only cross-route reference | Generalized surrogate at the default protocol against the fixed-route COMSOL values | not posterior-based | `run_generalized_study('Steps',{'default_protocol_comparison'})` |
| [worst_case_provenance.png](figures/worst_case_provenance.png) | Worst-case provenance by surrogate family and output \| COMPATIBLE_REFERENCE \| development-only cross-route reference | Generalized surrogate at the default protocol against the fixed-route COMSOL values | not posterior-based | `run_generalized_study('Steps',{'default_protocol_comparison'})` |
| [default_protocol_gp_metrics.csv](tables/default_protocol_gp_metrics.csv) | Generalized GP at the default protocol against the fixed-route COMSOL values (recorded compatibility status: compatible reference) | Generalized surrogate at the default protocol against the fixed-route COMSOL values | not posterior-based | `run_generalized_study('Steps',{'default_protocol_comparison'})` |

Inside `data/`:

- files: `default_protocol_comparison_status.json`, `default_protocol_gp_metrics.csv`, `default_protocol_gp_metrics_raw_uqlab.csv`, `default_protocol_pce_metrics.csv`, `default_protocol_predictions.csv`, `default_protocol_support.csv`, `default_protocol_worst_cases.csv`

## Commands

```matlab
run_generalized_study('Steps',{'default_protocol_comparison'})                  % re-render figures/ and tables/ from data/
run_generalized_study('Mode','rerun','Steps',{'default_protocol_comparison'},'Plan',true)  % show what a recomputation costs
```
