%% =====================================================================
%  UHTC LEADING-EDGE SURROGATE MODEL
%  Gaussian Process regression on COMSOL thermal-structural simulations
%
%  Inputs  : k, alpha, E, Cp, rho  (5 material properties)
%  Outputs : peak temperature [K], peak von Mises stress [Pa]
%
%  Run from a clean workspace. Do not run section-by-section until the
%  whole script has passed once from cold.
%% =====================================================================

clear; clc; close all;

%% PART 0: LOAD DATA & VERIFY STRUCTURE

opts = detectImportOptions('UHTC_ML_Training.csv');
opts.CommentStyle = '%';
data = readtable('UHTC_ML_Training.csv', opts);

% --- Column map. VERIFY these against the printout below before trusting
%     any result. Nothing crashes if they are wrong; the plots simply lie.
COL_K     = 1;   % thermal conductivity      [W/m/K]
COL_ALPHA = 2;   % coefficient of thermal expansion [1/K]
COL_E     = 3;   % Young's modulus           [Pa]
COL_CP    = 4;   % specific heat capacity    [J/kg/K]
COL_RHO   = 5;   % density                   [kg/m^3]
COL_TIME  = 6;   % simulation time           [s]
COL_TEMP  = 7;   % peak temperature          [K]
COL_SIG   = 8;   % peak von Mises stress     [Pa]

fprintf('--- COLUMN MAP CHECK ---\n');
vn = data.Properties.VariableNames;
labels = {'k','alpha','E','Cp','rho','time','temperature','stress'};
for i = 1:min(8, numel(vn))
    fprintf('  Col %d -> %-28s (expected: %s)\n', i, vn{i}, labels{i});
end
fprintf('\n');

% --- Keep only the final time step of each transient (the peak state).
%     Tolerance rather than exact equality: COMSOL's exported time values
%     are floating point, so == can silently drop cases.
time_data = data{:, COL_TIME};
t_final   = max(time_data);
final_time_indices = abs(time_data - t_final) < 1e-9 * max(1, abs(t_final));

X_final        = data{final_time_indices, 1:5};
y_temp_final   = data{final_time_indices, COL_TEMP};
y_stress_final = data{final_time_indices, COL_SIG};

n_cases = size(X_final, 1);
fprintf('Loaded %d cases at final time step (t = %.4g s).\n', n_cases, t_final);
if n_cases ~= 100
    warning(['Expected 100 cases, found %d. Check the final-time filter ' ...
             'and the CSV export before trusting any downstream result.'], n_cases);
end

%% PART 1: DATA SPLITTING (80% Train, 20% Test)

rng(42);

cv = cvpartition(n_cases, 'HoldOut', 0.2);
idx_train = training(cv);
idx_test  = test(cv);

X_train = X_final(idx_train, :);
X_test  = X_final(idx_test, :);

y_stress_train = y_stress_final(idx_train);
y_stress_test  = y_stress_final(idx_test);

y_temp_train = y_temp_final(idx_train);
y_temp_test  = y_temp_final(idx_test);

% Normalization statistics from the TRAINING SET ONLY.
% Using the full dataset here would leak test information into the
% preprocessing and inflate the reported accuracy.
mu_train    = mean(X_train);
sigma_train = std(X_train);

X_train_norm = (X_train - mu_train) ./ sigma_train;
X_test_norm  = (X_test  - mu_train) ./ sigma_train;

fprintf('Split: %d training cases, %d held-out test cases.\n\n', ...
        sum(idx_train), sum(idx_test));

%% PART 2: TRAIN & EVALUATE SURROGATE MODELS

% 'Standardize' is false because the inputs are already standardized above
% using train-only statistics. Enabling it would standardize twice.

% --- STRESS MODEL ---
disp('Training GP Model for Peak Stress...');
gp_stress = fitrgp(X_train_norm, y_stress_train, ...
    'KernelFunction', 'squaredexponential', 'Standardize', false);

[y_stress_pred, y_stress_sd] = predict(gp_stress, X_test_norm);
rmse_stress     = sqrt(mean((y_stress_test - y_stress_pred).^2));
range_stress    = max(y_stress_test) - min(y_stress_test);
rel_rmse_stress = (rmse_stress / range_stress) * 100;

% --- TEMPERATURE MODEL ---
disp('Training GP Model for Peak Temperature...');
gp_temp = fitrgp(X_train_norm, y_temp_train, ...
    'KernelFunction', 'squaredexponential', 'Standardize', false);

[y_temp_pred, y_temp_sd] = predict(gp_temp, X_test_norm);
rmse_temp     = sqrt(mean((y_temp_test - y_temp_pred).^2));
range_temp    = max(y_temp_test) - min(y_temp_test);
rel_rmse_temp = (rmse_temp / range_temp) * 100;

fprintf('\n--- README TABLE METRICS (HELD-OUT TEST SET) ---\n');
fprintf('Peak Stress RMSE: %.2f MPa | Range: %.2f to %.2f MPa | Relative RMSE: %.2f%%\n', ...
    rmse_stress/1e6, min(y_stress_test)/1e6, max(y_stress_test)/1e6, rel_rmse_stress);
fprintf('Peak Temp   RMSE: %.2f K   | Range: %.2f to %.2f K   | Relative RMSE: %.2f%%\n', ...
    rmse_temp, min(y_temp_test), max(y_temp_test), rel_rmse_temp);

% --- FITTED HYPERPARAMETERS (know these before you present) ---
fprintf('\n--- FITTED GP HYPERPARAMETERS ---\n');
kp_s = gp_stress.KernelInformation.KernelParameters;
kp_t = gp_temp.KernelInformation.KernelParameters;
fprintf('Stress model: lengthscale = %.4f, signal sd = %.4g, noise sd = %.4g\n', ...
    kp_s(1), kp_s(2), gp_stress.Sigma);
fprintf('Temp   model: lengthscale = %.4f, signal sd = %.4g, noise sd = %.4g\n', ...
    kp_t(1), kp_t(2), gp_temp.Sigma);

% --- UNCERTAINTY CALIBRATION CHECK ---
% If the GP's error bars are honest, roughly 95% of test points should
% fall inside their own +/-2 sigma interval.
cov_stress = mean(abs(y_stress_test - y_stress_pred) <= 2*y_stress_sd) * 100;
cov_temp   = mean(abs(y_temp_test   - y_temp_pred)   <= 2*y_temp_sd)   * 100;

fprintf('\n--- UNCERTAINTY CALIBRATION (target ~95%%) ---\n');
fprintf('Stress: %.1f%% of test points within +/-2 sigma (%d of %d)\n', ...
    cov_stress, sum(abs(y_stress_test - y_stress_pred) <= 2*y_stress_sd), numel(y_stress_test));
fprintf('Temp:   %.1f%% of test points within +/-2 sigma (%d of %d)\n\n', ...
    cov_temp, sum(abs(y_temp_test - y_temp_pred) <= 2*y_temp_sd), numel(y_temp_test));

%% --- PARITY PLOT (HELD-OUT TEST SET) ---

figure('Position', [100 100 1000 450]);

% Peak stress
subplot(1,2,1);
errorbar(y_stress_test/1e6, y_stress_pred/1e6, 2*y_stress_sd/1e6, ...
         'o', 'MarkerFaceColor', [0.0 0.45 0.74], 'MarkerSize', 6, ...
         'LineStyle', 'none', 'Color', [0.5 0.5 0.5]);
hold on;
lims = [min(y_stress_test) max(y_stress_test)]/1e6;
pad  = 0.08*(lims(2)-lims(1));
lims = [lims(1)-pad, lims(2)+pad];
plot(lims, lims, 'r--', 'LineWidth', 1.5);
xlabel('COMSOL Peak Stress (MPa)', 'FontWeight', 'bold');
ylabel('GP Predicted Stress (MPa)', 'FontWeight', 'bold');
title(sprintf('Peak Stress: RMSE = %.2f MPa (%.2f%%)', ...
      rmse_stress/1e6, rel_rmse_stress));
xlim(lims); ylim(lims); axis square; grid on;
legend('Prediction \pm2\sigma', 'Perfect agreement', 'Location', 'northwest');

% Peak temperature
subplot(1,2,2);
errorbar(y_temp_test, y_temp_pred, 2*y_temp_sd, ...
         'o', 'MarkerFaceColor', [0.85 0.325 0.098], 'MarkerSize', 6, ...
         'LineStyle', 'none', 'Color', [0.5 0.5 0.5]);
hold on;
limsT = [min(y_temp_test) max(y_temp_test)];
padT  = 0.08*(limsT(2)-limsT(1));
limsT = [limsT(1)-padT, limsT(2)+padT];
plot(limsT, limsT, 'r--', 'LineWidth', 1.5);
xlabel('COMSOL Peak Temperature (K)', 'FontWeight', 'bold');
ylabel('GP Predicted Temperature (K)', 'FontWeight', 'bold');
title(sprintf('Peak Temperature: RMSE = %.2f K (%.2f%%)', ...
      rmse_temp, rel_rmse_temp));
xlim(limsT); ylim(limsT); axis square; grid on;
legend('Prediction \pm2\sigma', 'Perfect agreement', 'Location', 'northwest');

sgtitle(sprintf('Surrogate Accuracy on Held-Out Test Set (n = %d)', ...
        numel(y_stress_test)), 'FontWeight', 'bold');

exportgraphics(gcf, 'parity_plot.png', 'Resolution', 300);

%% PART 3: 3D RESPONSE SURFACE VISUALIZATION

% Sweep bounds taken from the data, not hardcoded, so the surface never
% extrapolates outside the region the GP was actually trained on.
k_range     = linspace(min(X_final(:,COL_K)),     max(X_final(:,COL_K)),     50);
alpha_range = linspace(min(X_final(:,COL_ALPHA)), max(X_final(:,COL_ALPHA)), 50);
[K_grid, Alpha_grid] = meshgrid(k_range, alpha_range);

% The remaining three properties are held at their training-set means.
% This is a 2D slice through a 5D input space - say so when presenting.
E_mean   = mu_train(COL_E);
Cp_mean  = mu_train(COL_CP);
rho_mean = mu_train(COL_RHO);

num_points = numel(K_grid);
X_surf = [K_grid(:), Alpha_grid(:), repmat(E_mean,   num_points, 1), ...
          repmat(Cp_mean,  num_points, 1), repmat(rho_mean, num_points, 1)];

X_surf_norm = (X_surf - mu_train) ./ sigma_train;
Z_stress    = predict(gp_stress, X_surf_norm);

Z_stress_grid = reshape(Z_stress, size(K_grid)) / 1e6;   % Pa -> MPa

figure('Position', [100 100 700 550]);
surf(K_grid, Alpha_grid, Z_stress_grid, 'EdgeColor', 'none');
colormap(parula);
cb = colorbar;
cb.Label.String = 'Predicted Peak Stress (MPa)';
xlabel('Thermal Conductivity (W/m\cdotK)', 'FontWeight', 'bold');
ylabel('CTE (1/K)', 'FontWeight', 'bold');
zlabel('Predicted Peak Stress (MPa)', 'FontWeight', 'bold');
title({'Response Surface: Stress vs. Conductivity & CTE', ...
       'E, C_p, \rho held at training-set means'});
view(-45, 30);
grid on;

exportgraphics(gcf, 'response_surface.png', 'Resolution', 300);

%% PART 4: PHYSICS VALIDATION - THERMAL SHOCK RESISTANCE

k_test     = X_test(:, COL_K);
alpha_test = X_test(:, COL_ALPHA);
E_test     = X_test(:, COL_E);

% Poisson's ratio was NOT a swept parameter, so (1-nu) is a constant
% multiplier and has no effect on a rank correlation. Kept for the
% classical form of the expression only.
nu = 0.15;

% Classical thermal shock resistance parameter
R_param = (k_test .* (1 - nu)) ./ (E_test .* alpha_test);

% Correlate against BOTH the COMSOL ground truth and the GP prediction.
% The first shows the physics trend exists in the data; the second shows
% the surrogate reproduces it. Only both together support the claim.
rho_truth = corr(R_param, y_stress_test, 'Type', 'Spearman');
rho_model = corr(R_param, y_stress_pred, 'Type', 'Spearman');

figure('Position', [100 100 700 550]);
scatter(R_param, y_stress_test/1e6, 70, 'filled', ...
        'MarkerFaceColor', [0.2 0.2 0.2], 'MarkerFaceAlpha', 0.85);
hold on;
scatter(R_param, y_stress_pred/1e6, 70, 'filled', ...
        'MarkerFaceColor', [0.85 0.325 0.098], 'MarkerFaceAlpha', 0.85);
xlabel('Thermal Shock Parameter, R \propto k(1-\nu)/(E\alpha)', 'FontWeight', 'bold');
ylabel('Peak Stress (MPa)', 'FontWeight', 'bold');
title({'Physics Validation: Stress vs. Thermal Shock Resistance', ...
       sprintf('Spearman \\rho: COMSOL = %.2f, GP = %.2f', rho_truth, rho_model)});
legend('COMSOL (ground truth)', 'GP prediction', 'Location', 'northeast');
grid on;

exportgraphics(gcf, 'thermal_shock_validation.png', 'Resolution', 300);

fprintf('--- PHYSICS VALIDATION (Spearman rank correlation with R) ---\n');
fprintf('COMSOL ground truth vs R: rho = %.2f\n', rho_truth);
fprintf('GP prediction       vs R: rho = %.2f\n', rho_model);
fprintf(['\nInterpretation: sigma ~ E*alpha*dT and dT ~ 1/k, so sigma ~ 1/R is\n' ...
         'close to implicit in the governing equations. A strong negative rho\n' ...
         'confirms the surrogate tracks the FEM faithfully. It is a consistency\n' ...
         'check, not evidence the model discovered new physics.\n\n']);

fprintf('Done. Regenerated: parity_plot.png, response_surface.png, thermal_shock_validation.png\n');