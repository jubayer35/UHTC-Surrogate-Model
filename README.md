# UHTC-Surrogate-Model

A Gaussian Process regression model for rapidly predicting peak temperature and thermal stress in Ultra-High Temperature Ceramic (UHTC) leading edges. 

This repository contains a machine learning workflow that replaces computationally expensive finite element models (FEM) with a surrogate model capable of sub-millisecond predictions. The model is trained on a 100-case parametric sweep generated via COMSOL Multiphysics, capturing the coupled thermo-structural response of a 2D leading edge under hypersonic heat flux conditions (reaching up to ~4300 K).

## Repository Contents

* **`ML_training.m`**: The main MATLAB executable script. Handles data parsing, 80/20 train/test splitting, Gaussian Process training, uncertainty calibration, and plotting.
* **`UHTC_ML_Training.csv`**: The dataset containing 100 COMSOL simulation results. Inputs include thermal conductivity ($k$), coefficient of thermal expansion ($\alpha$), Young's modulus ($E$), heat capacity ($C_p$), and density ($\rho$). Outputs are peak temperature and peak von Mises stress.
* **`parity_plot.png`**: Visualizes the model's predictive accuracy and $\pm2\sigma$ uncertainty bounds on the held-out test set.
* **`response_surface.png`**: A 3D surface plot demonstrating the interaction between thermal conductivity, CTE, and resulting peak stress.
* **`thermal_shock_validation.png`**: Evaluates the model's alignment with fundamental thermoelastic physics by correlating predictions against the classical thermal shock resistance parameter ($R$).

## Performance Metrics (Held-Out Test Set)

* **Peak Stress RMSE:** 169.32 MPa (2.28% relative error)
* **Peak Temperature RMSE:** 77.00 K (3.29% relative error)
* **Uncertainty Calibration:** 95.0% of stress test points and 90.0% of temperature test points fall within the predicted $\pm2\sigma$ bounds.
* **Physics Validation:** The surrogate predictions exhibit a strong negative Spearman rank correlation ($\rho = -0.93$) with the thermal shock resistance parameter, identical to the COMSOL ground truth. This confirms the model implicitly learned the governing relationships of thermoelasticity rather than just memorizing data.

## Requirements

* **MATLAB** (R2021a or newer recommended)
* **Statistics and Machine Learning Toolbox** (required for `fitrgp`)

## Usage

1. Clone this repository or download the files to a local directory.
2. Open MATLAB and navigate to the directory containing the files.
3. Ensure the workspace is clear.
4. Run `ML_training.m`. The script will automatically load the CSV data, train the models, and output the three evaluation figures.