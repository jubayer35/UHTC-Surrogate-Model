opts = detectImportOptions('UHTC_ML_Training.csv');
opts.CommentStyle = '%';
data = readtable('UHTC_ML_Training.csv', opts);

X = data{:, 1:5}; 

y_temp = data{:, 7};
y_stress = data{:, 8};

X_norm = normalize(X);

time_data = data{:, 6};

final_time_indices = (time_data == max(time_data));

X_final = data{final_time_indices, 1:5};
y_stress_final = data{final_time_indices, 8};

X_norm = normalize(X_final);

disp('Retraining GP Model on final peak stresses...');
gp_stress = fitrgp(X_norm, y_stress_final, ...
    'KernelFunction', 'squaredexponential', ...
    'Standardize', true);

y_pred = predict(gp_stress, X_norm);
rmse = sqrt(mean((y_stress_final - y_pred).^2));
fprintf('Corrected RMSE: %.2e Pa\n', rmse);


figure;
scatter(y_stress_final, y_pred, 'filled');
hold on;
plot([min(y_stress_final) max(y_stress_final)], [min(y_stress_final) max(y_stress_final)], 'r--', 'LineWidth', 1.5);
xlabel('COMSOL Actual Stress (Pa)');
ylabel('GP Predicted Stress (Pa)');
title('Corrected Surrogate Accuracy: Peak Stress');
grid on;

%% PART 1: DATA SPLITTING (80% Train, 20% Test)
rng(42); 

% Create the 80/20 partition
cv = cvpartition(size(X_final, 1), 'HoldOut', 0.2);
idx_train = training(cv);
idx_test = test(cv);

X_train = X_final(idx_train, :);
X_test  = X_final(idx_test, :);

y_stress_train = y_stress_final(idx_train);
y_stress_test  = y_stress_final(idx_test);

y_temp_train = y_temp_final(idx_train);
y_temp_test  = y_temp_final(idx_test);

mu_train = mean(X_train);
sigma_train = std(X_train);

X_train_norm = (X_train - mu_train) ./ sigma_train;
X_test_norm  = (X_test - mu_train) ./ sigma_train;

%% PART 2: TRAIN & EVALUATE SURROGATE MODELS
% --- STRESS MODEL ---
disp('Training GP Model for Peak Stress...');
gp_stress = fitrgp(X_train_norm, y_stress_train, ...
    'KernelFunction', 'squaredexponential', 'Standardize', true);

y_stress_pred = predict(gp_stress, X_test_norm);
rmse_stress = sqrt(mean((y_stress_test - y_stress_pred).^2));
range_stress = max(y_stress_test) - min(y_stress_test);
rel_rmse_stress = (rmse_stress / range_stress) * 100;

% --- TEMPERATURE MODEL ---
disp('Training GP Model for Peak Temperature...');
gp_temp = fitrgp(X_train_norm, y_temp_train, ...
    'KernelFunction', 'squaredexponential', 'Standardize', true);

y_temp_pred = predict(gp_temp, X_test_norm);
rmse_temp = sqrt(mean((y_temp_test - y_temp_pred).^2));
range_temp = max(y_temp_test) - min(y_temp_test);
rel_rmse_temp = (rmse_temp / range_temp) * 100;

fprintf('\n--- README TABLE METRICS (HELD-OUT TEST SET) ---\n');
fprintf('Peak Stress RMSE: %.2e Pa | Range: %.2e to %.2e Pa | Relative RMSE: %.2f%%\n', ...
    rmse_stress, min(y_stress_test), max(y_stress_test), rel_rmse_stress);
fprintf('Peak Temp RMSE:   %.2f K     | Range: %.2f to %.2f K     | Relative RMSE: %.2f%%\n\n', ...
    rmse_temp, min(y_temp_test), max(y_temp_test), rel_rmse_temp);

% PART 3: 3D RESPONSE SURFACE VISUALIZATION

k_range = linspace(5.0, 25.0, 50);
alpha_range = linspace(6.0e-6, 9.5e-6, 50);
[K_grid, Alpha_grid] = meshgrid(k_range, alpha_range);

E_mean = mu(3);
Cp_mean = mu(4);
rho_mean = mu(5);

num_points = numel(K_grid);
X_surf = [K_grid(:), Alpha_grid(:), repmat(E_mean, num_points, 1), ...
          repmat(Cp_mean, num_points, 1), repmat(rho_mean, num_points, 1)];

X_surf_norm = (X_surf - mu) ./ sigma;
Z_stress = predict(gp_stress, X_surf_norm);

Z_stress_grid = reshape(Z_stress, size(K_grid));

figure;
surf(K_grid, Alpha_grid, Z_stress_grid, 'EdgeColor', 'none');
colormap jet; 
colorbar;
xlabel('Thermal Conductivity (W/m*K)', 'FontWeight', 'bold');
ylabel('CTE (1/K)', 'FontWeight', 'bold');
zlabel('Predicted Peak Stress (Pa)', 'FontWeight', 'bold');
title('Response Surface: Stress vs. Conductivity & CTE');
view(-45, 30); 

k_test = X_test(:, 1);
alpha_test = X_test(:, 2);
E_test = X_test(:, 3);

% Assuming constant Poisson's ratio=0.15
nu = 0.15; 

% Calculate the classical Thermal Shock Resistance Parameter (R)
R_param = (k_test .* (1 - nu)) ./ (E_test .* alpha_test);

%Validation Scatter Plot
figure;
scatter(R_param, y_stress_pred, 50, 'filled', 'MarkerFaceColor', [0.85 0.325 0.098]);
xlabel('Thermal Shock Parameter, R \propto k(1-\nu)/(E\alpha)', 'FontWeight', 'bold');
ylabel('GP Predicted Peak Stress (Pa)', 'FontWeight', 'bold');
title('Physics Validation: Stress vs. Thermal Shock Resistance');
grid on;

% the Spearman rank correlation coefficient
rho_spearman = corr(R_param, y_stress_pred, 'Type', 'Spearman');
fprintf('\nPhysics Validation: Spearman Correlation (rho) = %.2f\n', rho_spearman);

