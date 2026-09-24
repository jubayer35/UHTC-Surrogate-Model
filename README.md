# Gaussian Process Surrogate for UHTC Thermal-Structural Response

A Gaussian Process (GP) regression surrogate that predicts **peak temperature** and **peak thermal stress** in a simplified 2D Ultra-High Temperature Ceramic (UHTC) leading edge from five material properties, trained on COMSOL Multiphysics simulations.

> **Status:** proof of concept. Constant material properties, simplified 2D geometry, 100 training simulations.

---

## Contents

- [Motivation](#motivation)
- [Repository structure](#repository-structure)
- [Simulation setup](#simulation-setup)
- [Surrogate modeling](#surrogate-modeling)
- [Results](#results)
- [Physics consistency check](#physics-consistency-check)
- [Limitations](#limitations)
- [How to run](#how-to-run)
- [Future work](#future-work)
- [License and contact](#license-and-contact)

---

## Motivation

UHTCs (e.g., ZrB₂, HfB₂, HfC, TaC) are candidate materials for hypersonic vehicle leading edges and other extreme thermal environments. Screening many candidate material-property combinations with finite element analysis (FEA) requires one simulation per combination. A surrogate model trained on a modest number of simulations can give near-instant predictions for new combinations, and a GP additionally provides a predictive uncertainty.

This project tests whether a GP can learn the mapping from five material properties to thermal-structural response, and whether the learned trends are consistent with classical thermal-shock theory.

---

## Repository structure

```
UHTC-Surrogate-Model/
├── UHTC-Surrogate-Model.mph      # COMSOL model (2D leading edge, coupled thermal-structural)
├── UHTC_ML_Training.csv          # Parametric-sweep results (100 cases)
├── ML_training.m                 # MATLAB script: data parsing, GP training, evaluation, plots
├── parity_plot.png               # Predicted vs. COMSOL (held-out test set)
├── response_surface.png          # Predicted peak stress vs. selected properties
├── thermal_shock_validation.png  # Predicted stress vs. thermal-shock parameter R
└── README.md
```

---

## Simulation setup

A coupled thermal-structural model of a simplified 2D leading edge was built in COMSOL Multiphysics using:

- Heat Transfer in Solids
- Solid Mechanics
- Thermal Expansion (multiphysics coupling)

A high heat flux is applied to the curved leading-edge tip, and the resulting temperature field drives thermal strains and stresses.

| Item | Value |
| --- | --- |
| COMSOL version | _TODO_ |
| Geometry (nose radius, wedge angle, thickness) | _TODO_ |
| Applied heat flux | _TODO_ |
| Simulation duration | _TODO_ |
| Initial / ambient temperature | _TODO_ |
| Other boundary conditions (radiation, constraints) | _TODO_ |
| Poisson's ratio | _TODO_ (held constant) |
| Stress measure extracted (von Mises / max principal) | _TODO_ |
| Where outputs are evaluated (domain max / probe point) | _TODO_ |
| Mesh convergence checked | _TODO_ |

### Parametric study

Five material properties were varied independently using **Latin hypercube sampling (LHS)**, giving **100 simulation cases**.

| Parameter | Symbol | Range (min – max) |
| --- | --- | --- |
| Thermal conductivity | $k$ | _TODO_ |
| Coefficient of thermal expansion | $\alpha$ | _TODO_ |
| Young's modulus | $E$ | _TODO_ |
| Heat capacity | $C_p$ | _TODO_ |
| Density | $\rho$ | _TODO_ |

For each case, temperature and thermal stress at the **final simulation time** were extracted as the target outputs.

---

## Surrogate modeling

Two GP regression models were trained in MATLAB with `fitrgp`:

| Model | Inputs | Output |
| --- | --- | --- |
| 1 | $k, \alpha, E, C_p, \rho$ | Peak temperature |
| 2 | $k, \alpha, E, C_p, \rho$ | Peak thermal stress |

- **Kernel:** squared exponential
- **Hyperparameters:** optimized automatically by `fitrgp`
- **Split:** 80 / 20 train / test (80 training cases, 20 held-out test cases)
- **Input/output preprocessing:** _TODO (e.g., standardization, log transform)_

---

## Results

Performance on the 20 held-out test cases:

| Output | Test RMSE | Target range | Relative RMSE (RMSE / range) |
| --- | --- | --- | --- |
| Peak temperature | 1.77 K | 334.02 – 383.74 K | 3.55 % |
| Peak thermal stress | 4.41 MPa | 126 – 315 MPa | 2.34 % |

Because the test set is small, these numbers carry noticeable sampling uncertainty. See [Limitations](#limitations).

### Parity plot

Predicted vs. COMSOL values for the held-out test cases; the diagonal is perfect agreement.

![Parity plot](parity_plot.png)

### Response surface

Predicted peak thermal stress as a function of selected material properties.

![Response surface](response_surface.png)

---

## Physics consistency check

As a sanity check, the surrogate's predicted stress is compared with the classical thermal-shock resistance parameter

$$R \propto \frac{k\,(1-\nu)}{E\,\alpha}$$

where $\nu$ is Poisson's ratio. Across the test cases, the Spearman rank correlation between predicted stress and $R$ is **$\rho = -0.92$**, consistent with the expected inverse relationship (higher $R$ → lower thermal stress).

![Thermal-shock validation](thermal_shock_validation.png)

**Interpretation notes**

- $\nu$ is held constant, so $R$ effectively reduces to $k/(E\alpha)$.
- $R$ does not include $\rho$ or $C_p$, which affect the transient response in the simulations. A correlation somewhat weaker than −1 is therefore expected.
- This check shows the trends are physically sensible. It does not replace validation against independent simulations or experiments.

---

## Limitations

- **Geometry:** simplified 2D leading edge only.
- **Material model:** constant, temperature-independent properties; the five properties are sampled independently, so some sampled combinations may not correspond to real materials.
- **Load case:** a single heating condition; no oxidation, ablation, or full radiation/aerothermal coupling.
- **Output definition:** outputs are taken at the final simulation time, which is assumed to be the peak state of the transient.
- **Dataset size:** 100 simulations; predictions outside the sampled property ranges should not be trusted.
- **Evaluation:** a single 80/20 split with 20 test points. Cross-validation and uncertainty calibration have not yet been done.
- **No baseline:** the GP has not yet been compared with simpler models (e.g., log-log linear regression or a quadratic response surface).

---

## How to run

### Requirements

- MATLAB _TODO version_ with the **Statistics and Machine Learning Toolbox** (`fitrgp`)
- COMSOL Multiphysics _TODO version_ (only needed to regenerate the data)

### 1. Train the surrogate (no COMSOL needed)

1. Clone the repository and place `ML_training.m` and `UHTC_ML_Training.csv` in the same folder.
2. Open `ML_training.m` in MATLAB and run it.
3. The script parses the final-time data, performs the 80/20 split, trains both GP models, reports test RMSE, and generates the three figures.

### 2. Regenerate the simulation data (optional)

1. Open `UHTC-Surrogate-Model.mph` in COMSOL Multiphysics.
2. Run the parametric sweep under the Study node.
3. Export the time-dependent results to CSV.

### Reproducibility

- Random seed for the train/test split: _TODO (e.g., `rng(1)`)_
- COMSOL runtime per case: _TODO_
- GP prediction time per case: _TODO_

---

## Future work

- Add baselines (log-log linear regression, quadratic response surface) to show what the GP contributes.
- Use ARD kernels and log-transformed inputs; use ARD length scales or Sobol indices to check sensitivities against the scaling $\sigma \propto E\alpha / k$.
- Replace the single split with repeated k-fold or leave-one-out cross-validation; report R², MAE, and calibration of the GP's predictive intervals.
- Validate on real UHTC compositions (e.g., ZrB₂, HfB₂, ZrC, HfC, TaC) run directly in COMSOL.
- Extract the maximum over time rather than the final-time value.
- Extend to 3D geometry, temperature-dependent properties, and DFT-derived material inputs.
- Use the GP's uncertainty for active learning or Bayesian optimization of material selection.

---

## License and contact

- License: _TODO (e.g., MIT)_
- Author: Jubayer Ahmed Muhin — [GitHub: jubayer35](https://github.com/jubayer35)
