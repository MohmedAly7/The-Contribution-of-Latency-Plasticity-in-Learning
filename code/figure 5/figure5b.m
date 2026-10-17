if ~exist('USE_PRE_RUN_DATA', 'var')
    USE_PRE_RUN_DATA = 0;
end
if USE_PRE_RUN_DATA == 1
    data_source_dir = '../../data/figure 5/'; 
else
    data_source_dir = '../../results/figure 5/';
end

close all
clearvars -except USE_PRE_RUN_DATA data_source_dir
clc

%% ==================================================================
%% GENERAL NEURON PULSE SIMULATOR - Customizable Input Patterns
%% ==================================================================

%% 1. Define Neuron and Simulation Parameters
% --- Neuron membrane properties ---
C_m = 200e-12;      % Membrane Capacitance (F)
R_m = 100e6;        % Membrane Resistance (Ω)
V_rest = -70e-3;    % Resting Potential (V)
V_th = -55e-3;      % Spike Threshold (V)
V_reset = -75e-3;   % Reset Potential (V)
V_peak = 20e-3;     % Peak potential for spike visualization (V)
tau_m = R_m * C_m;  % Membrane time constant (s)

% --- Simulation time parameters ---
t_start = 0;
t_end = 0.02;        % Total simulation duration (s) - ADJUSTABLE
dt = 0.1e-4;        % Time step (s)
t = t_start:dt:t_end;
fprintf('=== NEURON SIMULATOR ===\n');
fprintf('Membrane time constant (τ_m) = %.1f ms\n\n', tau_m * 1000);

%% 2. DEFINE YOUR CUSTOM INPUT PATTERNS HERE
cases = {
    % --- PATTERN 1: Constant Regular Pulses ---
    struct('label', 'Regular pulses', ...
           'num_pulses', 6, ...
           'amplitudes', [150, 1550, 1550, 1550, 1550, 1550], ...      % pA
           'durations', [200, .2, .2, .2, .2, .2], ...                 % ms
           'start_times', [0, 15, 15.25, 15.50, 15.75, 16], ...        % ms
           'color', [0.8500, 0.3250, 0.0980], ...                      % Orange
           'line_style', '-'); 
    % --- PATTERN 2: Regular Pulses with an Extraneous Spike ---
    struct('label', 'Extraneous pulses', ...
           'num_pulses', 7, ...
           'amplitudes', [150, 1550, 1550, 1550, 1550, 1550, 1550], ... % pA
           'durations', [200, .2, .2, .2, .2, .2, .2], ...              % ms
           'start_times', [0, 7, 15, 15.25, 15.50, 15.75, 16], ...      % ms
           'color', [0, 0.4470, 0.7410], ...                            % Blue
           'line_style', ':');
};

%% 3. Validate and Convert Input Parameters
num_cases = length(cases);
I_vectors = zeros(num_cases, length(t));

fprintf('Input Pattern Validation:\n');
fprintf('%-25s | Pulses | Valid\n', 'Pattern Name');
fprintf('------------------------------------------------\n');

for k = 1:num_cases
    % Validate that all arrays have the same length
    n_pulses = cases{k}.num_pulses;
    is_valid = (length(cases{k}.amplitudes) == n_pulses) && ...
               (length(cases{k}.durations) == n_pulses) && ...
               (length(cases{k}.start_times) == n_pulses);
    
    if ~is_valid
        error('Pattern "%s": Array lengths must match num_pulses!', cases{k}.label);
    end
    fprintf('%-25s | %6d | ✓\n', cases{k}.label, n_pulses);
    
    % Build the current vector for this pattern
    for p = 1:n_pulses
        % Convert to SI units
        amp_SI = cases{k}.amplitudes(p) * 1e-12;      % pA to A
        dur_SI = cases{k}.durations(p) * 1e-3;        % ms to s
        start_SI = cases{k}.start_times(p) * 1e-3;    % ms to s
        
        % Calculate indices
        start_idx = round(start_SI / dt) + 1;
        pulse_steps = round(dur_SI / dt);
        end_idx = min(start_idx + pulse_steps - 1, length(t));
        
        % Check bounds
        if start_idx > 0 && start_idx <= length(t)
            I_vectors(k, start_idx:end_idx) = amp_SI;
        else
            warning('Pattern "%s", Pulse %d: Start time exceeds simulation window', ...
                    cases{k}.label, p);
        end
    end
end
fprintf('\n');

%% 4. Setup the Figure with TIGHT SPACING
fig = figure('Color', 'w', 'Position', [100, 100, 1000, 700]);
font_size = 12;
tiledlayout(2, 1, 'TileSpacing', 'tight', 'Padding', 'compact');
% --- Panel A: Membrane Potential with reduced margins ---
ax1 = nexttile;
hold(ax1, 'on');
ylabel({'Membrane', 'potential (mV)'}, 'FontSize', font_size);
grid on; box off;

% --- Panel B: Input Current with reduced margins ---
ax2 = nexttile;
hold(ax2, 'on');
xlabel('Time (ms)', 'FontSize', font_size);
ylabel('Current (nA)', 'FontSize', font_size);
grid on; box off;

% REDUCE THE SPACING BETWEEN SUBPLOTS
% Get current positions
pos1 = get(ax1, 'Position');
pos2 = get(ax2, 'Position');

% Adjust vertical spacing (reduce gap between plots)
vertical_gap = 0.05;  % Small gap between plots (adjust as needed: 0.02-0.08)
plot_height = (0.88 - vertical_gap) / 2;  % Total height divided by 2

% Set new positions with reduced gap
set(ax1, 'Position', [pos1(1), 0.88-plot_height, pos1(3), plot_height]);
set(ax2, 'Position', [pos2(1), 0.11, pos2(3), plot_height]);

%% 5. Simulate and Plot Each Pattern
dvdt_fun = @(v_val, I_val) ((V_rest - v_val)/R_m + I_val) / C_m;
voltage_handles = gobjects(num_cases, 1);
spike_counts = zeros(num_cases, 1);

fprintf('Simulation Results:\n');
fprintf('%-25s | Spikes | Peak V (mV)\n', 'Pattern Name');
fprintf('------------------------------------------------\n');

for k = 1:num_cases
    current_I_vec = I_vectors(k, :);
    v = zeros(size(t));
    v(1) = V_rest;
    max_voltage = V_rest;
    
    % --- Integrate membrane potential ---
    for i = 1:length(t)-1
        if v(i) >= V_th
            v(i) = V_peak;
            v(i+1) = V_reset;
            spike_counts(k) = spike_counts(k) + 1;
            continue;
        end
        v(i+1) = v(i) + dt * dvdt_fun(v(i), current_I_vec(i));
        max_voltage = max(max_voltage, v(i+1));
    end
    
    % --- Plot results ---
    case_color = cases{k}.color;
    case_line= cases{k}.line_style;
    label_str = sprintf('%s (%d spikes)', cases{k}.label, spike_counts(k));
    voltage_handles(k) = plot(ax1, t*1000, v*1000, 'Color', case_color, ...
                              'LineWidth', 2.5, 'DisplayName', label_str,'LineStyle',case_line);
    plot(ax2, t*1000, current_I_vec*1e9, 'Color', case_color, ...
        'LineWidth', 2.5, 'DisplayName', cases{k}.label,'LineStyle',case_line);
    
    fprintf('%-25s | %6d | %10.2f\n', cases{k}.label, spike_counts(k), max_voltage*1000);
end

%% 6. Finalize and Annotate Plots
% --- Add reference lines ---
yline(ax1, V_th * 1000, 'k--', 'Threshold', 'LineWidth', 1.5, ...
      'FontSize', 10, 'LabelVerticalAlignment', 'top');
yline(ax1, V_rest * 1000, 'k:', 'Rest', 'LineWidth', 1.5, ...
      'FontSize', 10, 'LabelVerticalAlignment', 'bottom');

% --- Add legends ---
legend(ax1, voltage_handles, 'Location', 'northwest', 'FontSize', 10, 'Box', 'off');
legend(ax2, 'Location', 'northwest', 'FontSize', 10, 'Box', 'off');

% --- Set axes properties ---
linkaxes([ax1, ax2], 'x');
xlim(ax1, [0 t_end*1000]);
ylim(ax1, [-80 30]);
set([ax1, ax2], 'FontSize', 11);

%% 7. Display Pattern Summary
fprintf('\n=== PATTERN SUMMARY ===\n');
for k = 1:num_cases
    fprintf('\nPattern %d: %s\n', k, cases{k}.label);
    fprintf('  Total Pulses: %d\n', cases{k}.num_pulses);
    fprintf('  Amplitudes (pA): %s\n', mat2str(cases{k}.amplitudes));
    fprintf('  Durations (ms): %s\n', mat2str(cases{k}.durations));
    fprintf('  Start Times (ms): %s\n', mat2str(cases{k}.start_times));
    fprintf('  Action Potentials: %d\n', spike_counts(k));
end

%% 8. Export for Publication (Optional)
output_dir = '../../results/figure 5/';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
exportgraphics(fig, fullfile(output_dir, 'Custom_Neuron_Simulation.pdf'), 'ContentType', 'image');