# Machine Learning Surrogate Modeling of UHTC Thermal-Structural Response

A Gaussian Process regression model for rapidly predicting peak temperature and thermal stress in Ultra-High Temperature Ceramic (UHTC) leading edges.

## Motivation
UHTCs are designed for extreme thermal environments, including hypersonic vehicle leading edges and advanced energy systems. However, evaluating their thermal and structural response using finite element simulations can be computationally expensive when many material combinations need to be tested. 

This project investigates whether a Gaussian Process (GP) surrogate model can learn the relationship between UHTC material properties and their thermal-structural response, providing near-instant predictions while retaining a connection to the underlying physics.

## Overview
A coupled thermal-structural model was developed in COMSOL for a simplified 2D UHTC leading edge. A parametric study was then performed by varying five material properties:
* Thermal conductivity ($k$)
* Coefficient of thermal expansion ($\alpha$)
* Young's modulus ($E$)
* Heat capacity ($C_p$)
* Density ($\rho$)

The resulting COMSOL simulations were used to train Gaussian Process regression models in MATLAB. The models predict two key quantities:
1. Peak temperature
2. Peak thermal stress

The surrogate can then be used to evaluate new material-property combinations without running the full COMSOL simulation.

## Methodology

### 1. COMSOL Model
A 2D leading-edge geometry was created in COMSOL using the following physics interfaces:
* Heat Transfer in Solids
* Solid Mechanics
* Thermal Expansion

A high heat flux was applied to the curved leading-edge tip to represent an extreme thermal loading condition. The thermal solution was coupled to the structural model so that temperature changes generated thermal strains and corresponding stresses.

### 2. Parametric Study
Five material properties were varied across the simulation set:

| Parameter | Symbol |
| :--- | :--- |
| Thermal conductivity | $k$ |
| Coefficient of thermal expansion | $\alpha$ |
| Young's modulus | $E$ |
| Heat capacity | $C_p$ |
| Density | $\rho$ |

A total of 100 COMSOL simulation cases were generated using a Latin hypercube sampling approach. For each case, the temperature and thermal stress at the final simulation time (representing the peak state of the heating transient) were extracted as target outputs.

### 3. Gaussian Process Surrogate
The simulation data were processed in MATLAB and used to train two Gaussian Process Regression models:
* Material properties → Peak temperature
* Material properties → Peak thermal stress

A Squared Exponential kernel was used. The dataset was divided into an 80/20 train/test split so performance could be rigorously evaluated on unseen cases.

## Results
The surrogate models were evaluated using the held-out test data. Hyperparameters were optimized via MATLAB's `fitrgp` automatic optimization.

| Output | Test RMSE | Target Range | Relative RMSE |
| :--- | :--- | :--- | :--- |
| Peak Temperature | 1.77 K | 334.02–383.74 K | 3.55% |
| Peak Thermal Stress | 4.41 MPa | 126–315 MPa | 2.34% |

### Prediction Accuracy
The parity plot compares the surrogate predictions with the corresponding COMSOL results for the held-out test cases. The diagonal line represents perfect agreement.

![Parity Plot](parity_plot.png)

### Response Surface
The response surface shows how the predicted peak thermal stress changes with selected material properties. It provides a visual representation of the relationships learned by the surrogate model.

![Response Surface](response_surface.png)

## Physics Validation
Machine learning accuracy alone does not guarantee that a model has learned physically meaningful relationships. To provide an additional check, the predicted stress trends are compared with the classical thermal-shock resistance parameter:

$$R \propto \frac{k(1-\nu)}{E\alpha}$$

where $k$ is thermal conductivity, $\nu$ is Poisson's ratio, $E$ is Young's modulus, and $\alpha$ is the coefficient of thermal expansion. 

The Spearman rank correlation between the surrogate's predicted stress and the thermal-shock parameter $R$ across the test cases was **$\rho = -0.92$**, indicating the model successfully captured the expected inverse relationship between stress and $R$. Rather than just memorizing numerical noise, the surrogate learned the foundational thermodynamics.

![Thermal Shock Validation](thermal_shock_validation.png)

## Limitations & Future Work
* **Geometry:** The current study relies on a simplified 2D leading-edge geometry.
* **Dataset Size:** The parametric sweep was limited to 100 runs due to computational time constraints. Predictions far outside the training bounds should be treated with caution.
* **Next Steps:** Future work will extend the surrogate to 3D geometries and incorporate Density Functional Theory (DFT) derived material inputs for multi-scale accuracy.

## Repository Structure
```text
UHTC-Surrogate-Model/
│
├── UHTC_Model.mph
├── ML_training.m
├── UHTC_ML_Training_Data.csv
│
├── parity_plot.png
├── response_surface.png
├── thermal_shock_validation.png
│
└── README.md
```

## How to Run

### Reproducing the Data (COMSOL)
1. Open `UHTC_Model.mph` in COMSOL Multiphysics.
2. Run the Parametric Sweep under the Study node to regenerate the thermal-structural simulations.
3. Export the time-dependent results to a CSV.

### Training the Surrogate (MATLAB)
1. Place `ML_training.m` and `UHTC_ML_Training_Data.csv` in the same directory.
2. Open `ML_training.m` in MATLAB and run the script.
3. The script will automatically parse the peak final-time data, execute the 80/20 split, train the GP models, and generate the three validation plots.

## Summary
This project demonstrates a functional workflow for replacing repeated, computationally expensive finite element evaluations with a lightweight machine learning surrogate. By learning directly from COMSOL simulations, the Gaussian Process models provide sub-millisecond predictions of peak temperature and thermal stress. The combination of high-fidelity FEM data, machine learning, and physics-based validation provides a practical, scalable framework for accelerating early-stage UHTC material design.