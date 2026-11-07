# Surrogate Modelling and Bayesian Inference for Skin Characterization from Suction Experiments

[![ETH Zurich](https://img.shields.io/badge/ETH-Zurich-blue)](https://ethz.ch)
[![Empa](https://img.shields.io/badge/Empa-Collaboration-green)](https://www.empa.ch)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2024a%20%7C%20R2025b-orange)](https://www.mathworks.com/products/matlab.html)
[![UQLab](https://img.shields.io/badge/UQLab-2.3-blue)](https://www.uqlab.com)

MATLAB/UQLab code, data and results of the MSc thesis *Surrogate Modelling and Bayesian Inference for Skin
Characterization from Suction Experiments* (Erion Isljami, ETH Zurich and Empa, 2026). A suction device measures the
closing pressures of the skin over repeated suction cycles. The code learns fast surrogates of a high-fidelity COMSOL
model of the skin, identifies four mechanical parameters of the reticular dermis from the six closing pressures with
certified Bayesian inversion, and designs suction protocols that make the weakly identified parameters easier to
measure.

---

## Key Features

- **Two studies** — The *fixed route* maps four material parameters to six closing pressures at the default suction
  protocol (452 COMSOL cases). The *generalized route* adds three protocol inputs (939 cases).
- **Calibrated surrogates** — Matérn-3/2 Gaussian processes with one length scale per input, plus polynomial chaos
  expansions. The GP's uncertainty is calibrated against out-of-fold errors.
- **Sensitivity** — Sobol indices of every closing pressure and of the derived features.
- **Certified Bayesian inversion** — The affine-invariant ensemble sampler (AIES). A posterior counts only when two
  independently seeded ensembles agree. The full posterior draws of all 437 cells (277 canonical, 160 conditional) are shipped.
- **Experimental design** — A comparison of six observation designs by Fisher information, a screen of 730 suction
  protocols under six design objectives, and the design of a confirmation experiment.
- **One command reproduces the thesis** — `reproduce_thesis_results` redraws every figure and table from the shipped
  results, with no model fitting, no MCMC and no UQLab.

## Results at a Glance

| | Fixed route | Generalized route |
|---|---|---|
| GP accuracy on held-out COMSOL cases (R², six pressures) | 0.991 – 0.999 (61 cases) | 0.986 – 0.999 (82 cases) |
| GP error (RMSE) | 1.7 – 2.2 mbar | 1.9 – 2.9 mbar |

**Identifiability** (fixed route, 8 % measurement noise, all six pressures, 20 matched truths with certified and
healthy-fallback cells): the posterior standard deviation divided by the prior's, averaged over the truths (1 means
that the data taught nothing). In parentheses the same over the 19 truths whose cells are all certified.

| Thickness t<sub>RD</sub> | m<sub>3f,RD</sub> | m<sub>3e,RD</sub> | log<sub>10</sub>(k<sub>0,RD</sub>) |
|---|---|---|---|
| 0.24 (0.24) | 0.58 (0.60) | 0.76 (0.78) | 0.95 (0.96) |

The thickness is well identified. The dissipative-fibre coefficient and the permeability form a weakly identified
pair, and the permeability stays almost at its prior width.

**Protocol screening.** The best of 730 protocols (suction rate 2 kPa/s, hold 27.5 s, pause 15 s) reduces the primary
objective by about 5 % against the default protocol. The primary objective is the largest eigenvalue of the weak
pair's posterior covariance, averaged over 1,000 material states.

**Confirmation.** Full Bayesian inversions on direct COMSOL observations of the 20 truths under the default and three
focused protocols (the three pressures of the D2 probe) support the screen for the dissipation-focused protocol: it
narrows the posterior of m<sub>3e,RD</sub> for 15 of 17 materials (median SD ratio to the default 0.94). The screen's
best protocol (joint-focused) improves the primary objective for 10 of 18 materials (median ratio 0.99), within the
run-to-run variation of the sampler, and the permeability-focused protocol does not narrow
log<sub>10</sub>(k<sub>0,RD</sub>), which stays near its prior width under every protocol.

**GP mean, COMSOL data** (a fourth inversion scenario of the fixed route,
[thesis_results/fixed/09_gp_mean_inversion](thesis_results/fixed/09_gp_mean_inversion/README.md)): the COMSOL
pressures of the 20 truths with the GP mean as the forward model and only a numerical floor as variance. Its
posterior is practically a point, which the sampler cannot explore, so the analysis reports that point, the best fit
of the GP mean to the six pressures per truth, against the truth and the posterior means of the other scenarios.

## Project Structure

| Path | Purpose |
|------|---------|
| `reproduce_thesis_results.m` | Redraws every thesis figure and table from the shipped results |
| `run_fixed_study.m`, `run_generalized_study.m` | The two routes: render or recompute any of their steps |
| `run_all_studies.m` | Both routes end to end |
| `check_installation.m` | Checks that this computer can reproduce and rerun the results |
| `study_settings.m` | The one settings file of both routes; its values are the thesis values |
| `src/` | The MATLAB packages: surrogates, sensitivity, inversion, recovery, design study, screening, confirmation, plotting |
| `config/` | Frozen records the settings select: emulator calibrations, surrogate selection, seed tables |
| `data/` | The COMSOL datasets of both routes and the confirmation's observations |
| `thesis_results/` | Every result of the thesis, one folder per analysis: figures, tables, data and a README index |
| `docs/GUIDE.md` | The guide to the code |

## Usage

1. Install MATLAB (tested with R2024a and R2025b; at least R2021a), and put the repository in a short folder. On
   Windows, the folder path should have at most about 80 characters (for example `C:\work\skin-suction`): the files of
   the repository have paths of at most 120 characters, a run folder nests deeper, and MATLAB cannot read files beyond
   260.
2. In MATLAB, from this folder: `check_installation`
3. Reproduce every thesis figure and table: `reproduce_thesis_results`. This takes about 35–60 min and writes
   `runs/thesis_<time>/`, laid out like `thesis_results/`, with its `README.md` index.
4. To recompute, install [UQLab](https://www.uqlab.com) and set its folder in `study_settings.m`. A small example of a
   whole study takes 10–30 min: `run_fixed_study('Mode','rerun','Scale','example')`.

## Using the code for new work

- **Invert new or measured closing pressures** with the shipped GP: `inversion.gp_mean_best_fit` gives the best fit in
  a few minutes, `inversion.bayes_invert` the posterior (one AIES ensemble; two that agree make a certified posterior).
- **Other cases, scenarios and designs:** the inversion step runs any complete external case of the dataset, for all
  scenarios and designs or cell by cell.
- **New COMSOL data:** a dataset in the format of `data/fixed/` needs an emulator calibration estimated on it: the
  steps refuse a dataset whose cases differ from those the shipped calibration was estimated on (new values for the
  same cases are not detected and need their own calibration too), and this version does not write a calibration for
  a retrained GP.

The recipes, tested on the shipped GP, are in [docs/GUIDE.md, section 12](docs/GUIDE.md#12-using-the-code-for-new-work).

## Documentation

[docs/GUIDE.md](docs/GUIDE.md) is the guide to the code: installation, the settings file and how to change it, every
entry point and step, what each step computes, the outputs and the layout of `thesis_results/`, the data, reproducing
and rerunning, reproducibility, running heavy steps on a computing cluster, troubleshooting, using the code for new
work, a glossary and the thesis figure map. [thesis_results/README.md](thesis_results/README.md) indexes the results
and the cases; [data/README.md](data/README.md) describes the datasets.

## About This Project

This repository accompanies the MSc thesis **“Surrogate Modelling and Bayesian Inference for Skin Characterization
from Suction Experiments”** by Erion Isljami at ETH Zurich, carried out in collaboration with Empa.

## Citation

> Erion Isljami, *Surrogate Modelling and Bayesian Inference for Skin Characterization from Suction Experiments*,
> Master's Thesis, ETH Zurich, 2026.
> https://github.com/erionloni/skin_characterization_surrogate_modelling_bayesian_inference

## Advisors

- Prof. Dr. Tomaso Zambelli
- Prof. Dr. Edoardo Mazza
- Dr. Ehsan Hosseini
- Dr. Riccardo Alberini

## License

No software license is included. Contact the author regarding reuse.
