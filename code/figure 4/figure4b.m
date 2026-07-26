if ~exist('USE_PRE_RUN_DATA', 'var')
    USE_PRE_RUN_DATA = 0;
end
if USE_PRE_RUN_DATA == 1
    data_source_dir = '../../data/figure 4/'; 
else
    data_source_dir = '../../results/figure 4/';
end
clearvars -except USE_PRE_RUN_DATA data_source_dir

location1 = '';  % initialise file-browser starting folder (empty = last used / default)

USE_STATIC = true;   % ← toggle here: true = hardcoded params | false = runtime prompts

%% =========================================================================
%  STEP 1 — DETERMINE HOW MANY SUBPLOTS TO CREATE
%  In static mode the count is fixed; in dynamic mode the user is prompted.
% =========================================================================
if USE_STATIC
    num_plots = 2;           % hardcoded number of plots
else
    num_plots = input('How many plots do you want to create? ');
end

% Pre-allocate storage: one cell/array entry per plot
plot_params    = cell(num_plots, 1);   % struct with file path + display parameters
plot_events    = cell(num_plots, 1);   % parsed spike-event data per plot
plot_n_neurons = zeros(num_plots, 1);  % number of neurons found in each file

%% =========================================================================
%  STEP 2 — STATIC PARAMETER BLOCK
%  Only used when USE_STATIC = true.
%  Each plot_params{i} must define:
%    .file          – path to the .neuron file
%    .neuron         – index of the "constant" (reference) neuron
%    .neuron_dynamic – index of the "slipping" (dynamic) neuron
%    .offset         – first event index to display (1-based)
%    .n_plot         – number of consecutive events to display
%    .intensity      – arrow transparency (0 = invisible, 1 = opaque)
% =========================================================================
if USE_STATIC
    % --- Plot 1 parameters ---
    plot_params{1}.file          = [data_source_dir 'figure4b.neuron'];
    plot_params{1}.neuron         = 2;      % constant neuron index
    plot_params{1}.neuron_dynamic = 1;      % dynamic neuron index
    plot_params{1}.offset         = 1;      % start at event #1
    plot_params{1}.n_plot         = 1000;   % show 1000 events
    plot_params{1}.intensity      = 0.1;    % low opacity → many arrows overlap cleanly

    % --- Plot 2 parameters ---
    plot_params{2}.file          = [data_source_dir 'figure4b.neuron'];
    plot_params{2}.neuron         = 1;
    plot_params{2}.neuron_dynamic = 2;
    plot_params{2}.offset         = 1;
    plot_params{2}.n_plot         = 1000;
    plot_params{2}.intensity      = 0.1;
end

%% =========================================================================
%  STEP 3 — LOAD AND PARSE EACH FILE
%  For every plot: select (or use static) file → read binary header + data
%  → parse events into a per-neuron cell array.
% =========================================================================
for i = 1:num_plots
    fprintf('\n--- Parameters for Plot %d ---\n', i);

    % ------------------------------------------------------------------
    %  3a. File selection
    % ------------------------------------------------------------------
    if USE_STATIC
        file_path = plot_params{i}.file;          % use hardcoded path directly
    else
        % Open a file-browser; remember the last folder for the next iteration
        [file1, location1] = uigetfile('*.neuron', ...
                                        sprintf('Select file for Plot %d', i), ...
                                        location1);
        if isequal(file1, 0)
            disp('No file selected. Exiting.');
            return;
        end
        file_path = fullfile(location1, file1);   % assemble full OS-safe path
    end

    % ------------------------------------------------------------------
    %  3b. Open file and read header
    %  File layout:
    %    [int32: n_neurons] [repeating event records …]
    %  Each event record:
    %    [int32: neuron_index | double×n_neurons: channel amplitudes]
    % ------------------------------------------------------------------
    fileid = fopen(file_path, 'r');
    if fileid == -1
        error('File could not be opened: %s', file_path);
    end
    n_neurons      = fread(fileid, 1, 'int32');    % number of neurons in this recording
    file_data_bytes = fread(fileid, inf, '*uint8'); % read remaining bytes as raw uint8
    fclose(fileid);

    % ------------------------------------------------------------------
    %  3c. Parse the binary event stream
    %  Record size = 4 bytes (index) + n_neurons × 8 bytes (doubles)
    % ------------------------------------------------------------------
    event_record_size_bytes = 4 + n_neurons * 8;
    num_events = floor(numel(file_data_bytes) / event_record_size_bytes);

    if num_events == 0
        warning('Plot %d: No complete events found in file.', i);
        events = [];
    else
        % Trim any trailing partial record
        file_data_bytes = file_data_bytes(1:(num_events * event_record_size_bytes));

        % Reshape into a matrix: each column = one event record (bytes)
        data_matrix_bytes = reshape(file_data_bytes, event_record_size_bytes, num_events);

        % --- Extract neuron indices (first 4 bytes of each record) ---
        indices_bytes = data_matrix_bytes(1:4, :);
        indices = typecast(indices_bytes(:), 'int32') + 1;  % convert to 1-based MATLAB index

        % --- Extract amplitude data (remaining bytes, n_neurons doubles per event) ---
        event_data_bytes  = data_matrix_bytes(5:end, :);
        event_data        = typecast(event_data_bytes(:), 'double');
        event_data_matrix = reshape(event_data, n_neurons, num_events);
        % event_data_matrix is [n_neurons × num_events]:
        %   row k = amplitudes recorded on channel k across all events

        % --- Split events into per-neuron cells using the firing index ---
        events = cell(1, n_neurons);
        for l = 1:n_neurons
            mask      = (indices == l);          % events where neuron l fired
            events{l} = event_data_matrix(:, mask);
            % events{l} is [n_neurons × spike_count_of_l]:
            %   each column = the full amplitude snapshot when neuron l fired
        end
    end

    % Store results for this plot
    plot_events{i}    = events;
    plot_n_neurons(i)  = n_neurons;

    % ------------------------------------------------------------------
    %  3d. Collect remaining display parameters (dynamic mode only)
    % ------------------------------------------------------------------
    if ~USE_STATIC
        plot_params{i}.neuron         = input('Enter the number of the constant neuron: ');
        plot_params{i}.neuron_dynamic = input('Enter the number of the slipping neuron: ');
        plot_params{i}.offset         = input('Enter the start event number: ');
        plot_params{i}.n_plot         = input('Enter the number of events to plot: ');
        plot_params{i}.intensity      = input('Enter the intensity value: ');
    end
end

%% =========================================================================
%  STEP 4 — FIGURE AND SUBPLOT LAYOUT
% =========================================================================

% Helper: draw a filled arrow between two points with given colour + transparency
% Signature: drawArrow(x_vec, y_vec, colour_str, alpha)
drawArrow = @(x, y, str, t) arrow([x(1) y(1)], [x(2) y(2)], ...
    'Length', 10, 'color', str, ...
    'edgealpha', t, 'Facealpha', t, 'width', 2, 'Length', 15);

num_cols = num_plots;   % lay out all plots in a single horizontal row
num_rows = 1;

% Extra fractional height reserved at the bottom of each cell for the letter label
label_margin = 0.06;

figure('Position', [100, 100, 400*num_cols, 400*num_rows]);
set(gcf, 'Color', 'w');   % white figure background

%% =========================================================================
%  STEP 5 — DRAW EACH SUBPLOT
% =========================================================================

% Handles and neuron indices collected from the first plot for the shared legend
h_static_legend    = [];
h_dynamic_legend   = [];
neuron_static      = [];
neuron_dynamic_num = [];

for plot_idx = 1:num_plots

    % ------------------------------------------------------------------
    %  5a. Compute manual subplot position
    %  We use 'subplot(Position,…)' for pixel-accurate control so we can
    %  reserve space at the bottom of each cell for the letter label.
    % ------------------------------------------------------------------
    row = ceil(plot_idx / num_cols);
    col = mod(plot_idx - 1, num_cols) + 1;

    cell_w  = 1 / num_cols;                          % fractional cell width
    cell_h  = 1 / num_rows;                          % fractional cell height
    inner_h = cell_h * (1 - label_margin);           % axes height (shrunk to leave label room)
    left    = (col - 1) * cell_w;                    % left edge of this cell
    bottom  = 1 - row * cell_h + cell_h * label_margin; % bottom edge (shifted up inside cell)

    ax = subplot('Position', [left, bottom, cell_w, inner_h]);
    hold on;
    axis tight;

    % ------------------------------------------------------------------
    %  5b. Retrieve this plot's data and parameters
    % ------------------------------------------------------------------
    events         = plot_events{plot_idx};
    neuron         = plot_params{plot_idx}.neuron;        % constant (reference) neuron
    neuron_dynamic = plot_params{plot_idx}.neuron_dynamic; % dynamic (slipping) neuron
    offset         = plot_params{plot_idx}.offset;        % first event index
    n_plot         = plot_params{plot_idx}.n_plot;        % number of events to show
    intencity      = plot_params{plot_idx}.intensity;     % arrow transparency

    % ------------------------------------------------------------------
    %  5c. Draw the reference circle (represents the oscillation cycle)
    % ------------------------------------------------------------------
    centers = [0, 0];
    radii   = 3;
    viscircles(centers, radii, 'LineWidth', 1, 'color', 'k');

    % ------------------------------------------------------------------
    %  5d. Assign colours based on which neuron is "constant"
    %  Neuron 2 constant → orange static arrow, blue dynamic arrows (and vice-versa)
    % ------------------------------------------------------------------
    if neuron == 2
        dynamic_arrow_color = [0.8500, 0.3250, 0.0980];  % orange — constant neuron
        blue                = [0.0000, 0.4470, 0.7410];  % blue   — dynamic neuron
    else
        dynamic_arrow_color = [0.0000, 0.4470, 0.7410];  % blue   — constant neuron
        blue                = [0.8500, 0.3250, 0.0980];  % orange — dynamic neuron
    end

    % ------------------------------------------------------------------
    %  5e. Static (reference) arrow — fixed position pointing outward at 3 o'clock
    % ------------------------------------------------------------------
    h_static = drawArrow([radii, radii + 0.85], [0, 0], dynamic_arrow_color, 1);
    if plot_idx == 1
        % Save handle + neuron index for the shared legend (first plot only)
        h_static_legend = h_static;
        neuron_static   = neuron;
    end

    % ------------------------------------------------------------------
    %  5f. Dynamic arrows — one arrow per selected event
    %  Arrow angle encodes the phase of the dynamic neuron relative to
    %  the constant neuron: angle = 2π × (t_dynamic / T_constant)
    % ------------------------------------------------------------------
    if ~isempty(events) && ~isempty(events{neuron})
        event_indices = offset + (1:n_plot);   % absolute event indices to display

        if max(event_indices) <= size(events{neuron}, 2)
            % Read amplitudes of both neurons for the selected events
            dyn_neuron_data   = events{neuron}(neuron_dynamic, event_indices);
            const_neuron_data = events{neuron}(neuron,         event_indices);

            % Discard events where the dynamic neuron amplitude is negative
            valid_mask = dyn_neuron_data >= 0;

            if any(valid_mask)
                % Compute normalised phase angle (in half-turns, for cospi/sinpi)
                angles = 2 * dyn_neuron_data(valid_mask) ./ const_neuron_data(valid_mask);

                % Convert phase to Cartesian coordinates on the circle
                cos_angles = cospi(angles);
                sin_angles = sinpi(angles);
                x_end   = radii         * cos_angles;   % arrow tip on the circle
                y_end   = radii         * sin_angles;
                x_start = (radii - 0.7) * cos_angles;   % arrow tail slightly inside
                y_start = (radii - 0.7) * sin_angles;

                % Draw one semi-transparent arrow per valid event
                for i = 1:numel(x_end)
                    h_dyn = drawArrow([x_start(i), x_end(i)], ...
                                      [y_start(i), y_end(i)], ...
                                      blue, intencity);
                    % Save the first dynamic arrow handle for the shared legend
                    if plot_idx == 1 && i == 1
                        h_dynamic_legend   = h_dyn;
                        neuron_dynamic_num  = neuron_dynamic;
                    end
                end
            end
        else
            warning('Plot %d: Requested event range exceeds available events.', plot_idx);
        end
    end

    % ------------------------------------------------------------------
    %  5g. Draw the "T" arc with arrowhead (constant-neuron period marker)
    %  Arc runs from 90° down to 30° (π/2 → π/6) — marks the reference phase.
    % ------------------------------------------------------------------
    theta = linspace(0.5*pi, (1/6)*pi, 100);
    r     = 2;                          % arc drawn on inner radius
    x     = r * cos(theta);
    y     = r * sin(theta);
    plot(x, y, 'color', 'k', 'LineWidth', 2)

    % Arrowhead at the end of the arc using a small filled triangle
    arrow_length = 0.4;
    arrow_angle  = 20 * pi/180;
    dx    = x(end) - x(end-1);   dy    = y(end) - y(end-1);
    angle = atan2(dy, dx);        % tangent direction at arc tip
    x_arrow = [x(end), x(end)-arrow_length*cos(angle-arrow_angle), ...
                        x(end)-arrow_length*cos(angle+arrow_angle)];
    y_arrow = [y(end), y(end)-arrow_length*sin(angle-arrow_angle), ...
                        y(end)-arrow_length*sin(angle+arrow_angle)];
    patch(x_arrow, y_arrow, 'k', 'EdgeColor', 'k')

    % Label "T" at the start of the arc (arc start = 90°)
    text(x(1), y(1)-0.3, 'T', ...
         'Color', 'k', 'FontSize', 18, 'FontWeight', 'bold', ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

    % ------------------------------------------------------------------
    %  5h. Draw the "K" arc with arrowhead (dynamic-neuron phase marker)
    %  Arc direction depends on which neuron is constant, so the two arcs
    %  mirror each other for the swapped configuration.
    % ------------------------------------------------------------------
    if neuron == 2
        % Arc runs clockwise from 270° to ~330°
        theta = linspace(1.5*pi, 2*pi-(1/6)*pi, 100);
    else
        % Arc runs counter-clockwise: same angular range but reversed
        theta = linspace(2*pi-(1/6)*pi, 1.5*pi, 100);
    end
    x = r * cos(theta);   y = r * sin(theta);
    plot(x, y, 'color', blue, 'LineWidth', 2)

    % Arrowhead at the arc tip
    dx    = x(end) - x(end-1);   dy    = y(end) - y(end-1);
    angle = atan2(dy, dx);
    x_arrow = [x(end), x(end)-arrow_length*cos(angle-arrow_angle), ...
                        x(end)-arrow_length*cos(angle+arrow_angle)];
    y_arrow = [y(end), y(end)-arrow_length*sin(angle-arrow_angle), ...
                        y(end)-arrow_length*sin(angle+arrow_angle)];
    patch(x_arrow, y_arrow, blue, 'EdgeColor', blue)

    % Label "K" — position differs slightly between the two configurations
    if neuron == 2
        text(x(1),   y(1)+0.3, 'K', ...
             'color', blue, 'FontSize', 18, 'FontWeight', 'bold', ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    else
        text(x(end), y(end)+0.3, 'K', ...
             'color', blue, 'FontSize', 18, 'FontWeight', 'bold', ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    end

    % ------------------------------------------------------------------
    %  5i. Axis formatting
    % ------------------------------------------------------------------
    axis equal;    % equal data-unit scaling so circle stays circular
    axis off;      % hide axes frame, ticks, and labels
    camroll(90);   % rotate the view 90° so "up" on the circle = 12 o'clock

    % ------------------------------------------------------------------
    %  5j. Letter label below each subplot  (a), (b), (c), …
    %  Placed using a figure-level annotation so it sits below the axes
    %  in the reserved label_margin space.
    % ------------------------------------------------------------------
    letter  = '(' + string(char('a' + plot_idx - 1)) + ')';  % char('a')=97
    label_x = left + cell_w / 2;           % horizontally centred in the cell
    label_y = 1 - row * cell_h + 0.01;     % just above the very bottom edge of the cell
    annotation('textbox', [label_x - 0.05, label_y, 0.10, 0.04], ...
        'String', letter, ...
        'FontSize', 14, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'EdgeColor', 'none', 'BackgroundColor', 'none');
end

%% =========================================================================
%  STEP 6 — SHARED LEGEND
%  A single legend is drawn beneath all subplots showing which colour
%  corresponds to the constant (static) neuron and which to the dynamic one.
%  Arrow edge colours are used so the legend lines match the arrow colours.
% =========================================================================
if ~isempty(h_static_legend) && ~isempty(h_dynamic_legend)
    % Create an invisible axes just for the legend (centred at the bottom)
    legend_ax = axes('Position', [0.4, 0.02, 0.2, 0.05], 'Visible', 'off');
    hold on;

    % Proxy lines — invisible NaN plots that carry the colour for the legend
    h1 = plot(NaN, NaN, 'Color', get(h_static_legend,  'EdgeColor'), 'LineWidth', 3);
    h2 = plot(NaN, NaN, 'Color', get(h_dynamic_legend, 'EdgeColor'), 'LineWidth', 3);

    legend([h1, h2], ...
           {sprintf('n%d', neuron_static), sprintf('n%d', neuron_dynamic_num)}, ...
           'Orientation', 'horizontal', 'FontSize', 12, 'Box', 'off');
    legend_ax.Visible = 'off';   % keep axes invisible; only the legend shows
end

if USE_STATIC
    saveas(gcf, '../../results/figure 4/figure4b.png');
end
