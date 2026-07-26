close all
clear
clc
%% 1. Define Common Neuron and Simulation Parameters
% --- Neuron membrane properties ---
C_m = 1500e-12;      % Membrane Capacitance (F)
R_m = 100e6;        % Membrane Resistance (Ω)
V_rest = -70e-3;    % Resting Potential (V)
V_th = -55e-3;      % Spike Threshold (V)
V_reset = -70e-3;   % Reset Potential (V)
% --- Simulation time parameters ---
t_start = 0;
t_end = 100;
dt = 0.1e-4;
t = t_start:dt:t_end;
rng(14);

%% 2. Generate Input Current Vector
% --- Case 1: Poisson Pulse Train ---
target_avg_current = 280e-12; % A
pulse_amplitude = 2200e-12;   % A
pulse_duration = .2e-3;        % s
avg_rate = target_avg_current / (pulse_amplitude * pulse_duration);
fprintf('For Case 1, using a Poisson pulse train with an average rate of %.1f Hz.\n', avg_rate);
fprintf('Simulating for %.0f seconds to generate a robust ISI histogram...\n', t_end);
% Generate Poisson spike times
poisson_spike_times = [];
current_time = -log(rand()) / avg_rate;
while current_time < t_end
    poisson_spike_times = [poisson_spike_times; current_time];
    isi = -log(rand()) / avg_rate;
    current_time = current_time + isi;
end
% --- FASTER PULSE GENERATION BLOCK ---
I_case1_vec = zeros(size(t));
pulse_steps = round(pulse_duration / dt);
spike_start_indices = round(poisson_spike_times / dt) + 1;
for start_idx = spike_start_indices'
    end_idx = min(start_idx + pulse_steps - 1, length(t));
    I_case1_vec(start_idx:end_idx) = pulse_amplitude;
end

%% 3. Setup the Figure for Publication 📊
fig = figure('Color', 'w', 'Position', [100, 100, 700, 800]);

% Use tiledlayout for better control over spacing
tl = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Panel A: Membrane Potential ---
ax1 = nexttile;
hold(ax1, 'on');
title('A. Leaky Integrate-and-Fire Neuron Response (First Second)', 'FontSize', 18, 'FontWeight', 'bold');
ylim(ax1,[ V_reset*1000, (V_th+ 5e-3)*1000]);
ylabel('Potential (mV)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');  % Added unit
grid on; box off;

% --- Panel B: Input Current ---
ax2 = nexttile;
hold(ax2, 'on');
title('B. Total Input Current (First Second)', 'FontSize', 18, 'FontWeight', 'bold');
ylabel('Current (nA)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');  % Added unit
grid on; box off;

% --- Panel C: Inter-Spike Interval (ISI) Distribution ---
ax3 = nexttile;
hold(ax3, 'on');
title('C. Firing period  Distribution (from 100s simulation)', 'FontSize', 18, 'FontWeight', 'bold');
xlabel('Inter-Spike Interval (ms)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Probability Density', 'FontSize', 12, 'FontWeight', 'bold');
grid on; box off;

%% 4. Simulate the Neuron
current_I_vec = I_case1_vec;
v = zeros(size(t));
v(1) = V_rest;
spike_times = [];
dvdt_fun = @(v_val, I_val) ((V_rest - v_val)/R_m + I_val) / C_m;

% --- Simulation Loop ---
for i = 1:length(t)-1
    if v(i) >= V_th
        v(i+1) = V_reset;
        spike_times = [spike_times, t(i)];
        continue;
    end
    v(i+1) = v(i) + dt * dvdt_fun(v(i), current_I_vec(i));
end

%% 5. Plot the Results Professionally
plot_color = [0, 0.4470, 0.7410];

% --- Plot Panel A: Voltage ---
plot(ax1, t, v * 1000, 'Color', plot_color, 'LineWidth', 2);
plot(ax1, spike_times, ones(size(spike_times)) * V_th * 1000, '^', ...
    'MarkerFaceColor', plot_color, 'MarkerEdgeColor', 'none', ...
    'MarkerSize', 8, 'HandleVisibility', 'off');
h_thresh = yline(ax1, V_th*1000, 'k--', 'Threshold', 'LineWidth', 1.5);
h_reset = yline(ax1, V_reset*1000, 'k:', '', 'LineWidth', 1.5);

% --- Plot Panel B: Current ---
plot(ax2, t, current_I_vec * 1e9, 'Color', plot_color, 'LineWidth', 1);

% --- Plot Panel C: ISI Histogram ---
if length(spike_times) > 1
    isis_ms = diff(spike_times) * 1000;
    histogram(ax3, isis_ms, 20, 'Normalization', 'pdf', 'FaceColor', plot_color, 'EdgeColor', 'w');
end

% --- Final Aesthetics ---
linkaxes([ax1, ax2], 'x');
xlim(ax1, [0 1]);
set([ax1, ax2, ax3], 'FontSize', 14);

%% 6. Export the Figure for Publication
output_dir = '../../results/figure 1/';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
exportgraphics(fig, fullfile(output_dir, 'LIF_Neuron_Simulation_100s.svg'), 'ContentType', 'image');
exportgraphics(fig, fullfile(output_dir, 'LIF_Neuron_Simulation_100s.png'), 'Resolution', 300);
