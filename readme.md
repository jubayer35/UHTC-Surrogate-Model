# Surrogate Modeling of UHTC Leading-Edge Thermo-Structural Response

This repository contains a machine learning workflow designed to predict the thermal and structural behavior of Ultra-High Temperature Ceramics (UHTCs) under hypersonic heat fluxes. 

## Project Overview
Evaluating UHTC leading edges under extreme aerodynamic heating (>1700 K) typically requires computationally expensive finite element modeling (FEM) to resolve the coupled thermoelastic physics. To accelerate material screening, this project replaces the FEM solver with a Gaussian Process (GP) regression surrogate model developed in MATLAB. 

The model was trained on a 100-case parametric sweep generated in COMSOL Multiphysics. By taking five fundamental material properties as inputs (thermal conductivity, CTE, Young's modulus, heat capacity, and density), the surrogate predicts peak temperatures and von Mises stresses in milliseconds.

## Performance & Results

### 1. Predictive Accuracy
The GP model was evaluated on a strictly held-out 20% test set to ensure generalized accuracy. It achieved:
* **Peak Stress RMSE:** 169.32 MPa (2.28% relative error)
* **Peak Temperature RMSE:** 77.00 K (3.29% relative error)

The parity plot demonstrates that the predictions track closely with the COMSOL ground truth, with approximately 95% of test points falling accurately within the model's own $\pm2\sigma$ uncertainty bounds.

![Parity Plot](parity_plot.png)

### 2. Parametric Behavior
Using an Automatic Relevance Determination (ARD) kernel allows the model to capture the relative importance of different material properties. The resulting response surface reflects expected thermoelastic behavior, identifying the combination of high thermal expansion and low thermal conductivity as the primary driver of peak stress.

![Response Surface](response_surface.png)

### 3. Physics Validation
To confirm the model learned the underlying physics rather than just interpolating data points, the predictions were tested against the classical thermal shock resistance parameter ($R \propto \frac{k(1-\nu)}{E\alpha}$). Both the FEM data and the surrogate model exhibit an identical, strong negative Spearman rank correlation ($\rho = -0.93$), demonstrating that the surrogate successfully respects the governing thermoelastic equations.

![Thermal Shock Validation](thermal_shock_validation.png)

## Repository Structure
* `UHTC_ML_Training.csv`: The 100-case dataset generated from COMSOL Multiphysics.
* `ML_training.m`: The primary MATLAB script handling data splitting, GP training, and visualization.
* `UHTC-Surrogate-Model.mph`: The base COMSOL physics setup (data cleared to maintain repository size limits).

## Usage
1. Clone this repository.
2. Ensure `UHTC_ML_Training.csv` and `ML_training.m` are in your active MATLAB directory.
3. Run `ML_training.m` from a clean workspace to train the models and generate the evaluation plots. Required toolboxes: Statistics and Machine Learning Toolbox.
