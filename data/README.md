# Data

The input data of the thesis: the two COMSOL datasets and the accepted COMSOL observations of the confirmation
experiment. The settings file names them (`fixed.dataset.file`, `generalized.dataset.file`,
`generalized.confirmation.observations`); `check_installation` checks that the datasets are present. The step
`dataset` of each route reads its table, applies the quality rules below and builds the analysis dataset with its
development/external split.

| File | What it is | Rows | Used by |
|---|---|---|---|
| `fixed/fixed_dataset.csv` | Fixed-protocol dataset: 4 material parameters → 6 closing pressures under the default suction protocol | 452 usable cases (of 500 designed) | `run_fixed_study` |
| `generalized/generalized_dataset.csv` | Generalized dataset: 4 material parameters and 3 protocol controls → 6 closing pressures; one row per designed case | 1,000 designed cases (939 usable) | `run_generalized_study` |
| `confirmation/confirmation_observations.csv` | Accepted COMSOL observations of the confirmation design: 6 closing pressures per material and protocol | 80 design rows: 73 accepted, 7 excluded by the reviewer (accepted 3 October 2026) | `run_generalized_study` (step `prepare`) |

## Common conventions

**Material parameters** (reticular dermis, RD):

| Column | Meaning | Unit | Range |
|---|---|---|---|
| `m3_f_RD` | elastic-fibre coefficient | dimensionless | 50–300 |
| `m3_e_RD` | dissipative-fibre coefficient | dimensionless | 0–1000 |
| `k0_RD` | permeability k0 (physical value) | mm⁴/(N·s) | 0.005–0.05 |
| `Thickness_RD` | reticular-dermis thickness | mm | 1.0–2.5 |

The tables store the **physical** k0. The surrogates and the inversion work with log10(k0); the code applies that
transform once when it reads the data (the generalized table also carries `log10_k0_RD`, which the code checks
against `k0_RD`).

**Outputs**, in this canonical order:

| Column | Meaning | Unit |
|---|---|---|
| `pcl1_D2_mbar`, `pcl2_D2_mbar`, `pcl3_D2_mbar` | closing pressure of suction cycles 1–3, probe D2 | mbar (magnitude) |
| `pcl1_D6_mbar`, `pcl2_D6_mbar`, `pcl3_D6_mbar` | closing pressure of suction cycles 1–3, probe D6 | mbar (magnitude) |

A missing output is `NaN`. Nothing is imputed, averaged or chosen by retry preference. A *complete* case has all six
outputs; a *partial* case has one to five and is used for training only (development); a case with none is
*unusable*.

## The COMSOL model

Both datasets were produced with the same COMSOL model (statement of the author, 30 September 2026), and the COMSOL
solves of the confirmation use it too. Each case is solved once per probe. A solve takes the four material
parameters, the protocol controls (suction rate, hold and pause), the probe geometry and three swelling stretches of
the reticular dermis (`lambda_01_RD` to `lambda_03_RD`), which the COMSOL workflow derives for each material before
the solve; everything else is defined by the model itself and is the same in every solve.

**Probes.** D2 and D6 name the diameter of the probe opening, 2 mm and 6 mm (COMSOL `Radius_Shield_inn` 1 mm and
3 mm). The closing elevation `Elevation_Probe` is 0.3 mm (D2) and 1.0 mm (D6).

**Protocol.** The model prescribes the suction pressure in nine phases:

| Phase | Prescribed suction pressure | Until |
|---|---|---|
| 1 | ramp at the suction rate | closing 1 (p<sub>cl,1</sub>) |
| 2 | release at the same rate magnitude | near-zero pressure |
| 3 | pause | the pause duration has passed (default 12 s) |
| 4 | ramp | closing 2 (p<sub>cl,2</sub>) |
| 5 | hold at the constant pressure p<sub>cl,2</sub> | the hold duration has passed (default 30 s) |
| 6 | release | near-zero pressure |
| 7 | pause | the pause duration has passed |
| 8 | ramp | closing 3 (p<sub>cl,3</sub>) |
| 9 | release | zero pressure; the solve ends |

The default protocol is 0.4 kPa/s, hold 30 s and pause 12 s; the generalized dataset varies the rate, the hold and
the pause.

**Closing.** A vertical tube stands in the probe opening, its lower end at the closing elevation `Elevation_Probe`
above the lower face of the probe wall. The model registers a closing when the mean height of the top of the buffer
disc under the vertical tube (the disc's top surface within 0.3 mm of the axis) reaches `Elevation_Probe` (the device
itself uses a pressure criterion). It checks the criterion at the time steps of its solver and switches to the
next phase at the first step at which the criterion holds. The closing pressure is the magnitude of the prescribed
pressure on the first saved output row of phases 2, 5 and 9, in mbar (the extraction rule of the separate COMSOL
workflow, the same for both datasets and the confirmation). Nothing is interpolated.

**Output resolution.** After its start-up the solver takes steps of at most 1 s, and the outputs are saved every
0.25 s. A registered closing can therefore lie up to one solver step (at most 1 s) after the true crossing of the
elevation, which raises the closing pressure by up to |r| × 1 s (r: the suction rate). In cycles 1 and 3 the release
has begun when the next output is saved, which lowers the value by less than |r| × 0.25 s; in cycle 2 the hold keeps
the pressure of the switch. So the closing pressures lie on a 1 s time grid with the pressure step |r| × 1 s: 4 mbar
at the default 0.4 kPa/s (uniform rounding SD 4 mbar / √12 = 1.15 mbar) and 2 to 20 mbar over the generalized rates.
The grid is visible where the solver's steps are regular, mostly in cycle 1:

- fixed dataset (0.4 kPa/s, step 4 mbar): all 416 values of `pcl1_D2_mbar` equal 2.1072016 mbar plus a multiple of
  4 mbar; 413 of the 418 values of `pcl1_D6_mbar` lie on the same time grid with seven offsets, 59 of the 408 values
  of `pcl2_D2_mbar` and 5 of the 407 of `pcl3_D2_mbar` as well; the D6 pressures of cycles 2 and 3 share no offset;
- generalized dataset (step |r| × 1 s): the implied closing time p / (10 |r|) (the time the ramp needs from zero to
  p; p in mbar, r in kPa/s) lies on an offset of the 1 s grid that at least two cases share for 96.5 % of
  `pcl1_D2_mbar` (811 of 840; 479 at the fixed dataset's 0.5268004 s) and 82.2 % of `pcl1_D6_mbar` (660 of 803);
  in cycles 2 and 3 for 26.7 % and 18.2 % of the D2 values, and at D6 only for pairs of cases.

Reference: the extraction rule above and the COMSOL records of the confirmation's solves, checked on 3 October 2026.
In all 138 solves with a saved probe table every phase switch falls on a solver step, and the registered closing lies
0.002 to 0.998 s after the crossing. Solving 20 cases of the fixed dataset again at the default protocol reproduced 36
of their 37 cycle-1 pressures exactly and the remaining one 4 mbar (one solver step) higher.

## Fixed-protocol dataset (`fixed/fixed_dataset.csv`)

Frozen on 2 September 2026 from two COMSOL productions of the fixed-protocol design (500 designed material cases;
249 historical and 237 new cases observed), with the COMSOL model above (the generalized dataset's model). One row
per usable case: `CaseID`, the four material parameters, the six
closing pressures and `MaterialGroup`.

Quality rules of the freeze: a closing pressure is kept when its COMSOL status is `ok`, its value is finite and the
material inputs of the solver summary match the design, so a failed or incomplete simulation can still contribute
its valid earlier cycles. Conflicting duplicate evidence is never averaged (this freeze has none). The 48 designed
cases without any valid pressure are not in the file.

| Quantity | Value |
|---|---|
| Designed cases | 500 (486 with any COMSOL output) |
| Usable | 452 = 306 complete + 146 partial |
| Valid values per output (D2 c1, c2, c3, D6 c1, c2, c3) | 416, 408, 407, 418, 402, 343 |
| Development / external split (step `dataset`) | 391 (245 complete + 146 partial) / 61 complete, including the 20 canonical inversion truths |
| Per-output development counts | 355, 347, 346, 357, 341, 282 |

`MaterialGroup` is the split group of the case: cases with identical material inputs must share a label, and the
split keeps a group on one side. Every case of this dataset is its own group. The labels `G0001`–`G0452` are frozen:
they number the groups in the order in which the thesis code sorted them (by a hash of the material vector, which the
publication code no longer computes), and the surrogate audit assigns its grouped cross-validation folds in the order
of the labels, so the thesis folds are reproduced exactly. A new dataset may use any labels (setting
`fixed.dataset.groupColumn`).

## Generalized dataset (`generalized/generalized_dataset.csv`)

Frozen on 20 September 2026 as snapshot `20260920T221107Z` (setting `generalized.dataset.snapshot`; the approved
emulator calibration records it). CaseIDs 1–500 come from the historical campaign and 501–1000 from the additional
campaign (`source_campaign`); each case was simulated with both probes, D2 and D6, with the COMSOL model above (the
fixed dataset's model). One row per designed case:

| Column | Meaning |
|---|---|
| `CaseID`, `source_campaign` | case number; `historical` (1–500) or `new` (501–1000) |
| `m3_f_RD_source` | m3_f as designed |
| `m3_f_RD` | m3_f as the COMSOL model used it (10 significant digits); the learning input |
| `m3_e_RD`, `k0_RD`, `log10_k0_RD`, `Thickness_RD` | the other material inputs |
| `suction_rate_kPa_s`, `log10_abs_suction_rate`, `hold_dur_s`, `pause_dur_s` | the protocol controls (below) |
| `D2_available`, `D6_available` | the run has a canonical output with a valid summary |
| `D2_classification`, `D6_classification` | solver outcome: `solved_phase9` (whole protocol), `early_stop_phase5`, `nonlinear_failure`, `unavailable` |
| `D2_phase_reached`, `D6_phase_reached` | last phase of the loading protocol the run reached (9: all of it) |
| `D2_production_complete`, `D6_production_complete` | the run completed the protocol |
| the six closing pressures | as above (`NaN`: missing) |
| `pair_status` | outcome of the two runs: `both_phase9_complete`, `both_recorded_noncomplete`, `D2_recorded_D6_missing`, `D6_recorded_D2_missing`, `both_missing` |
| `exclusion_reason` | why a case has no pressure: `no_valid_closing_pressure_output` or `conflicting_duplicate_output_evidence`; empty for a usable case |

**Protocol controls**:

| Column | Meaning | Unit | Range |
|---|---|---|---|
| `suction_rate_kPa_s` | signed suction rate (negative = suction) | kPa/s | −2.0 to −0.2 |
| `log10_abs_suction_rate` | learning coordinate log10(abs(rate)) | — | — |
| `hold_dur_s` | hold duration | s | 10–45 |
| `pause_dur_s` | pause duration | s | 5–25 |

The default protocol is rate 0.4 kPa/s, hold 30 s, pause 12 s.

Quality rules of the snapshot: the two productions were reconciled pressure by pressure with the accepted event
extractor; validated early-cycle pressures recovered from a failed attempt are kept, without labelling the attempt a
successful simulation (31 runs have pressures but no canonical output). A case whose duplicate evidence disagrees is
excluded in full (22 cases; strict policy, no tolerance and no averaging); 39 cases have no valid pressure. The
step `dataset` checks the requested inputs (bounds, the log10 transforms) and reports strict cycle monotonicity as
review evidence without excluding any case.

| Quantity | Value |
|---|---|
| Designed cases | 1,000; 2,000 D2/D6 runs, 1,933 with a canonical output |
| Usable | 939 = 412 complete + 527 partial |
| Excluded | 61 = 39 without a valid pressure + 22 with conflicting duplicate evidence |
| Development / external split (step `dataset`) | 857 (330 complete + 527 partial) / 82 complete |
| Per-output development counts | 758, 758, 735, 721, 719, 385 |

The split groups of the generalized route are the four material inputs, so that every protocol variant of a
material stays on one side of the split; the code derives them (every material of this dataset is its own group).

## Confirmation observations (`confirmation/confirmation_observations.csv`)

The confirmation experiment simulates every material of the design with every protocol, directly in COMSOL (probes
D2 and D6), and inverts each observation. The design is defined in the settings (section B.7): the materials are
CaseIDs of the fixed dataset, whose parameter values are the truths (thesis: the 20 canonical inversion truths 131,
113, 230, 232, 42, 93, 172, 12, 119, 220, 206, 48, 96, 215, 83, 146, 166, 246, 249, 116), and the protocols are
given by label, the screening objective they target, signed suction rate, hold and pause (thesis: `default` −0.4 kPa/s,
30 s, 12 s; `joint_focused` −2, 27.5, 15; `permeability_focused` −1.4997884186649117, 27.5, 15;
`dissipation_focused` −2, 40.625, 12.5). The step `export_design` writes the design and its COMSOL run list (80
material × protocol rows, 160 D2/D6 solves); the thesis campaign was started on 22 September 2026 with exactly these
inputs.

The file holds one row per material and protocol, in design order: `MaterialCaseID`, `Protocol`, the COMSOL inputs
`m3_f_RD`, `m3_e_RD`, `k0_RD`, `Thickness_RD`, `SignedRate_kPa_s`, `Hold_s`, `Pause_s` (17 significant digits), the
six closing pressures (mbar, as above; the QC-valid values, `NaN` where QC failed), `SolveStatus_D2` and `SolveStatus_D6` (the COMSOL outcome of each solve) and
`COMSOLModel`, then `Accepted` (1, or 0 for a design row the reviewer excluded) and `ExclusionReason` (the
reviewer's reason). The values are direct COMSOL simulations from the separate COMSOL workflow; nothing is
interpolated, predicted by a surrogate or imputed: an excluded row keeps its QC-valid pressures and `NaN` for the
others, and its cells are unavailable (they never run). The closing pressures are extracted exactly like those of
the datasets (section "The COMSOL model"), so their pressure step is |r| × 1 s: 4 mbar for `default`, 15.0 mbar for
`permeability_focused` and 20 mbar for `joint_focused` and `dissipation_focused`.

The step `import_observations` writes it from a reviewed COMSOL export (`reviewed_export.csv`, one row per solve:
the COMSOL inputs, `Probe`, the probe's three closing pressures `pcl1_mbar` to `pcl3_mbar`, their QC flags
`QCValid_pcl1` to `QCValid_pcl3` with a reason `QCReason_pcl1` to `QCReason_pcl3` for a pressure that fails QC, and
`SolveStatus`), the COMSOL provenance (`source_provenance.json`: `comsol_model`, `geometry`, `swelling`,
`protocol_definition`, `closing_pressure_extraction`) and the reviewer's acceptance (`direct_data_acceptance.json`:
`decision` `ACCEPT_DIRECT_OBSERVATIONS`, `reviewedBy`, `reviewedUTC`, and optionally `excludedDesignRows`: the
design rows the reviewer accepts as missing, each with `MaterialCaseID`, `Protocol` and `reason`, e.g. a probe pair
that failed). Quality rules: every solve of the design is present once and joins its design row by exactly equal
inputs and probe (no ID); a QC-valid pressure is finite and positive; a design row is accepted only with the
pressures of the confirmation's observation design QC-valid (settings B.7 `design`; thesis `d2_only`, the three D2
pressures, chosen on 2 October 2026 before any confirmation posterior existed because the D6 probe mostly failed
under the focused protocols, below), unless the reviewer excludes it. A row that lacks those pressures and is not
excluded stops the import, which lists those rows; its QC table (`observation_qc.csv`) stays in the run folder for
the review. The accepted table is then copied here. The rows with all six pressures QC-valid also enter the
descriptive inversion of the complete pairs (B.7 `completePairsDesign`, thesis `all_six`). Thesis: accepted on 3
October 2026 by the author, 73 of the 80 design rows; the 7 rows whose D2 probe failed (a nonlinear failure, no
D2 pressure) are excluded with that reason (`ExclusionReason`), and 23 accepted rows have all six pressures.

The import also counts how the solves ended in COMSOL, per protocol and probe (`comsol_outcomes.csv`, published as
`thesis_results/generalized/06_confirmation/tables/confirmation_comsol_outcomes.csv`): completed (the three cycles;
`solved_phase9`), early stop with the phase it stopped in (`early_stop_phase5`), nonlinear failure (COMSOL's
nonlinear solver did not converge; no pressures) and not run. An early stop in phase 5 is the stop of COMSOL's
time-dependent solver during the hold of cycle 2 on a stop condition of the model (each solve's COMSOL log: "Stop
condition fulfilled ... (Stop expression 2)"; a completed solve stops at the end of the protocol, stop expression
1). The campaign's extractor accepts such a solve with the closing pressures of cycles 1 and 2 (phases 2 and 5
reached) and none of cycle 3 (`accepted_protocol_early_stop`). All 41 early stops of the thesis campaign are D6
solves under a focused protocol. In the 36 read on 2 October 2026 (before the last five design rows ran), the skin
displacement at the stop was 1.019 to 1.022 times the probe's elevation (D6: 1.0 mm), and the stop came 0.25 to 34 s
before the planned end of the hold.
The stop expression and its threshold are defined in the COMSOL model, not in the solves' records.

## Provenance

The freeze manifests, provenance bundles, generation scripts, production run lists, failed-attempt inventories,
QC tables and checksum lists of both freezes are kept in the author's private evidence archive, as are the design
package of the confirmation approved on 21 September 2026 (its protocol selection, cohort approval, observation
contract and evidence), whose materials, protocol values and row order the settings reproduce exactly. The tables here hold
the recorded values unchanged: `fixed_dataset.csv` is the model-ready table of the fixed freeze with the frozen
`MaterialGroup` column added; `generalized_dataset.csv` combines the probe and case status tables of the generalized
snapshot, one row per designed case (the step `dataset` derives the 939 usable cases from it).
