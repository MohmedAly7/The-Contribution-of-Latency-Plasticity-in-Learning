close all
clear
clc

%% 1. Define Neuron and Simulation Parameters
% --- Neuron membrane properties ---
C_m = 200e-12;      % Membrane Capacitance (F)
R_m = 100e6;        % Membrane Resistance (Ω)
V_rest = -70e-3;    % Resting Potential (V)
V_th = -55e-3;      % Spike Threshold (V)
V_reset = -75e-3;   % Reset Potential (V)
V_peak = 20e-3;       % Peak potential for spike visualization (V)
tau_m = R_m * C_m;  % Membrane time constant (s)

% --- Simulation time parameters (extended for both stimuli) ---
t_start = 0;
t_end = 0.15;        % 200 ms simulation window
dt = 0.1e-3;
t = t_start:dt:t_end;
fprintf('Membrane time constant (τ_m) is %.0f ms.\n', tau_m * 1000);

%% 2. Generate a Single, Combined Input Current Vector
% --- Pulse parameters ---
num_pulses = 5;
pulse_amplitude = 850e-12; % (850 pA)
pulse_duration = 1e-3;     % (1 ms)
pulse_steps = round(pulse_duration / dt);

% --- Define stimulus patterns ---
scattered_input = struct('label', 'Scattered', 'start', 20e-3, 'ipi', 15e-3, 'color', [0.8500, 0.3250, 0.0980]); % Red
clustered_input = struct('label', 'Clustered', 'start', 120e-3, 'ipi', 3e-3, 'color', [0, 0.4470, 0.7410]); % Blue
stimuli = {scattered_input, clustered_input};

% --- Create a single input current vector for the whole simulation ---
I_in = zeros(size(t));

% --- Populate the current vector with both scattered and clustered pulses ---
for i = 1:length(stimuli)
    stim = stimuli{i};
    pulse_times = stim.start + (0:num_pulses-1) * stim.ipi;
    pulse_start_indices = round(pulse_times / dt) + 1;
    for start_idx = pulse_start_indices
        end_idx = min(start_idx + pulse_steps - 1, length(t));
        I_in(start_idx:end_idx) = pulse_amplitude;
    end
end

%% 3. Setup the Figure 
fig = figure('Color', 'w', 'Position', [100, 100, 800, 600]);
font_size = 12;
tiledlayout(2, 1, 'TileSpacing', 'tight', 'Padding', 'compact');
% --- Panel A: Membrane Potential ---
ax1 = nexttile;
hold(ax1, 'on');
title('A. Membrane Potential Response to Sequential Stimuli', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Potential (mV)', 'FontSize', font_size, 'FontWeight', 'bold');
grid on; box off;

% --- Panel B: Input Current ---
ax2 = nexttile;
hold(ax2, 'on');
title('B. Combined Input Current Stimulus', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Time (ms)', 'FontSize', font_size, 'FontWeight', 'bold');
ylabel('Current (pA)', 'FontSize', font_size, 'FontWeight', 'bold');
grid on; box off;

%% 4. Simulate and Plot
% --- Leaky Integrate-and-Fire (LIF) neuron model equation ---
dvdt_fun = @(v_val, I_val) ((V_rest - v_val)/R_m + I_val) / C_m;

% --- Initialize voltage vector ---
v = zeros(size(t));
v(1) = V_rest;

% --- Single Simulation Loop for the entire duration ---
for i = 1:length(t)-1
    % If threshold is reached, fire a spike for visualization
    if v(i) >= V_th
        v(i) = V_peak;    % Set to peak value
        v(i+1) = V_reset; % Set next point to reset potential
        continue;         % Skip the integration step
    end
    
    % Use Euler's method to integrate the membrane potential
    v(i+1) = v(i) + dt * dvdt_fun(v(i), I_in(i));
end

% --- Plotting the simulation result with colored segments ---
% Plot the base traces in black
plot(ax1, t*1000, v*1000, 'k', 'LineWidth', 2); 
plot(ax2, t*1000, I_in*1e12, 'k', 'LineWidth', 2); 

% Overlay colored segments for the specific stimulus periods
for i = 1:length(stimuli)
    stim = stimuli{i};
    start_time = stim.start;
    end_time = stim.start + (num_pulses-1)*stim.ipi + pulse_duration;
    
    start_idx = find(t >= start_time, 1, 'first');
    end_idx = find(t >= end_time, 1, 'first');
    
    % Ensure indices are within bounds
    if isempty(start_idx) || isempty(end_idx), continue; end
    
    % Plot colored segment on top of the black trace
    plot(ax1, t(start_idx-2:end_idx)*1000, v(start_idx-2:end_idx)*1000, 'Color', stim.color, 'LineWidth', 2);
    plot(ax2, t(start_idx-2:end_idx)*1000, I_in(start_idx-2:end_idx)*1e12, 'Color', stim.color, 'LineWidth', 2);
end


%% 5. Finalize and Annotate Plots
% --- Add shaded regions to highlight stimulus periods ---
y_limits_ax1 = [-80 30];
y_limits_ax2 = ylim(ax2);

for i = 1:length(stimuli)
    stim = stimuli{i};
    start_patch = stim.start * 1000;
    end_patch = (stim.start + (num_pulses-1)*stim.ipi + pulse_duration) * 1000;
    
    % Shade region on the potential plot
    patch(ax1, [start_patch, end_patch, end_patch, start_patch], ...
          [y_limits_ax1(1), y_limits_ax1(1), y_limits_ax1(2), y_limits_ax1(2)], ...
          stim.color, 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
          
    % Shade region on the current plot
    patch(ax2, [start_patch, end_patch, end_patch, start_patch], ...
          [y_limits_ax2(1), y_limits_ax2(1), y_limits_ax2(2), y_limits_ax2(2)], ...
          stim.color, 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
          
    % Add text labels
    text(ax1, start_patch + 5, y_limits_ax1(2) - 10, stim.label, 'Color', stim.color, ...
         'FontSize', 12, 'FontWeight', 'bold');
end

% --- Add clean Threshold and Rest lines using yline ---
yline(ax1, V_th * 1000, 'k--', 'Threshold', 'LineWidth', 1.5, 'FontSize', 11, 'LabelVerticalAlignment', 'top');
yline(ax1, V_rest * 1000, 'k:', 'Rest', 'LineWidth', 1.5, 'FontSize', 11, 'LabelVerticalAlignment', 'top');

% --- Finalize axes ---
linkaxes([ax1, ax2], 'x');
xlim(ax1, [0 t_end*1000]);
ylim(ax1, y_limits_ax1);
set([ax1, ax2], 'FontSize', 11, 'FontWeight', 'bold');

%% 6. Save Figure
results_dir = '../../results/figure 2';
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end
saveas(fig, fullfile(results_dir, 'figure2.png'));
exportgraphics(fig, fullfile(results_dir, 'figure2.pdf'), 'ContentType', 'image');
