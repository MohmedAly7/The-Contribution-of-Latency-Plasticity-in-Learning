if ~exist('USE_PRE_RUN_DATA', 'var')
    USE_PRE_RUN_DATA = 0;
end
if USE_PRE_RUN_DATA == 1
    data_source_dir = '../../data/figure 3/'; 
else
    data_source_dir = '../../results/figure 3/';
end
clearvars -except USE_PRE_RUN_DATA data_source_dir

location1 = '';

USE_STATIC = true;   % ← toggle here

%% --- ASK HOW MANY PLOTS ---
if USE_STATIC
    % static parameters block
    num_plots = 3;
    ...
else
    % interactive input block
    num_plots = input('How many plots do you want to create? ');
    ...
end

% Store parameters and data for each plot
plot_params = cell(num_plots, 1);
plot_events = cell(num_plots, 1);
plot_n_neurons = zeros(num_plots, 1);


if USE_STATIC
plot_params{1}.file          = [data_source_dir, 'circle_figure3a.neuron'];
plot_params{1}.neuron         = 2;
plot_params{1}.neuron_dynamic = 1;
plot_params{1}.offset         = 1;
plot_params{1}.n_plot         = 11;
plot_params{1}.intensity      = 1;

plot_params{2}.file          = [data_source_dir, 'circle_figure3b.neuron'];
plot_params{2}.neuron         = 2;
plot_params{2}.neuron_dynamic = 1;
plot_params{2}.offset         = 2;
plot_params{2}.n_plot         = 19;
plot_params{2}.intensity      = 1;


plot_params{3}.file          = [data_source_dir, 'circle_figure3c.neuron'];
plot_params{3}.neuron         = 2;
plot_params{3}.neuron_dynamic = 1;
plot_params{3}.offset         = 1;
plot_params{3}.n_plot         = 1000;
plot_params{3}.intensity      = .3;
end

%% --- COLLECT FILE + PARAMETERS FOR EACH PLOT ---
for i = 1:num_plots
    fprintf('\n--- Parameters for Plot %d ---\n', i);

    % File selection per plot
    if USE_STATIC
       file_path =  plot_params{i}.file ; 
    else
    [file1, location1] = uigetfile('*.neuron', sprintf('Select file for Plot %d', i), location1);
     file_path= fullfile(location1, file1);
     if file1 == 0
        disp('No file selected. Exiting.');
        return;
    end
    end

    

    % --- FILE READING ---
    fileid = fopen(file_path, 'r');
    if fileid == -1
        error('File could not be opened: %s', file_path);
    end
    n_neurons = fread(fileid, 1, 'int32');
    file_data_bytes = fread(fileid, inf, '*uint8');
    fclose(fileid);

    % --- DATA PARSING ---
    event_record_size_bytes = 4 + n_neurons * 8;
    num_events = floor(numel(file_data_bytes) / event_record_size_bytes);

    if num_events == 0
        warning('Plot %d: No complete events found in file.', i);
        events = [];
    else
        file_data_bytes = file_data_bytes(1:(num_events * event_record_size_bytes));
        data_matrix_bytes = reshape(file_data_bytes, event_record_size_bytes, num_events);

        indices_bytes = data_matrix_bytes(1:4, :);
        indices = typecast(indices_bytes(:), 'int32') + 1;

        event_data_bytes = data_matrix_bytes(5:end, :);
        event_data = typecast(event_data_bytes(:), 'double');
        event_data_matrix = reshape(event_data, n_neurons, num_events);

        events = cell(1, n_neurons);
        for l = 1:n_neurons
            mask = (indices == l);
            events{l} = event_data_matrix(:, mask);
        end
    end

    plot_events{i}   = events;
    plot_n_neurons(i) = n_neurons;
    if ~USE_STATIC
    % Collect plot parameters
    plot_params{i}.neuron         = input('Enter the number of the constant neuron: ');
    plot_params{i}.neuron_dynamic = input('Enter the number of the slipping neuron: ');
    plot_params{i}.offset         = input('Enter the start event number: ');
    plot_params{i}.n_plot         = input('Enter the number of events to plot: ');
    plot_params{i}.intensity         = input('Enter the intensity value: ');
    end
end

%% --- CREATE FIGURE WITH SUBPLOTS ---
drawArrow = @(x,y,str,t) arrow([x(1) y(1)],[x(2) y(2)],'Length',10,'color',str, ...
    'edgealpha',t,'Facealpha',t,'width',2,'Length',15);

num_cols = num_plots;   % all plots in one row
num_rows = 1;

% Extra top margin fraction to fit letter labels
label_margin =.02;

fig = figure('Position', [100, 100, 400*num_cols, 400*num_rows]);
set(gcf, 'Color', 'w');

%% --- PLOT EACH SUBPLOT ---
h_static_legend   = [];
h_dynamic_legend  = [];
neuron_static     = [];
neuron_dynamic_num = [];

for plot_idx = 1:num_plots
    row = ceil(plot_idx / num_cols);
    col = mod(plot_idx - 1, num_cols) + 1;

    % Shrink each cell slightly to leave room for the letter label at top
    cell_w = 1 / num_cols;
    cell_h = 1 / num_rows;
    inner_h = cell_h * (1 - label_margin);      % same reduced height
    left   = (col - 1) * cell_w;
    bottom = 1 - row * cell_h;                  % ← was: + cell_h * label_margin


    ax = subplot('Position', [left, bottom, cell_w, inner_h]);
    hold on;
    axis tight;

    % Retrieve data and parameters for this plot
    events   = plot_events{plot_idx};
    neuron         = plot_params{plot_idx}.neuron;
    neuron_dynamic = plot_params{plot_idx}.neuron_dynamic;
    offset         = plot_params{plot_idx}.offset;
    n_plot         = plot_params{plot_idx}.n_plot;
    intencity      = plot_params{plot_idx}.intensity;

    % Circle
    centers = [0, 0];
    radii   = 3;
    viscircles(centers, radii, 'LineWidth', 1, 'color', 'k');

    % Colors
    if neuron == 2
        dynamic_arrow_color = [0.8500, 0.3250, 0.0980];
        blue = [0, 0.4470, 0.7410];
    else
        dynamic_arrow_color = [0, 0.4470, 0.7410];
        blue = [0.8500, 0.3250, 0.0980];
    end

    % Static arrow
    h_static = drawArrow([radii, radii + 0.85], [0, 0], dynamic_arrow_color, 1);
    if plot_idx == 1
        h_static_legend = h_static;
        neuron_static   = neuron;
    end

    % Dynamic arrows
    if ~isempty(events) && ~isempty(events{neuron})
        event_indices = offset + (1:n_plot);
        if max(event_indices) <= size(events{neuron}, 2)
            dyn_neuron_data   = events{neuron}(neuron_dynamic, event_indices);
            const_neuron_data = events{neuron}(neuron, event_indices);
            valid_mask        = dyn_neuron_data >= 0;

            if any(valid_mask)
                angles     = 2 * dyn_neuron_data(valid_mask) ./ const_neuron_data(valid_mask);
                cos_angles = cospi(angles);
                sin_angles = sinpi(angles);
                x_end   = radii * cos_angles;
                y_end   = radii * sin_angles;
                x_start = (radii - 0.7) * cos_angles;
                y_start = (radii - 0.7) * sin_angles;

                for i = 1:numel(x_end)
                    h_dyn = drawArrow([x_start(i), x_end(i)], [y_start(i), y_end(i)], blue, intencity);
                    if plot_idx == 1 && i == 1
                        h_dynamic_legend  = h_dyn;
                        neuron_dynamic_num = neuron_dynamic;
                    end
                end
            end
        else
            warning('Plot %d: Requested event range exceeds available events.', plot_idx);
        end
    end

    % T arc + arrowhead
    theta = linspace(.5*pi, (1/6)*pi, 100);
    r = 2;
    x = r * cos(theta);
    y = r * sin(theta);
    plot(x, y, 'color', 'K', 'LineWidth', 2)
    arrow_length = 0.4;
    arrow_angle  = 20 * pi/180;
    dx = x(end) - x(end-1);  dy = y(end) - y(end-1);
    angle = atan2(dy, dx);
    x_arrow = [x(end), x(end)-arrow_length*cos(angle-arrow_angle), x(end)-arrow_length*cos(angle+arrow_angle)];
    y_arrow = [y(end), y(end)-arrow_length*sin(angle-arrow_angle), y(end)-arrow_length*sin(angle+arrow_angle)];
    patch(x_arrow, y_arrow, 'k', 'EdgeColor', 'k')
    text(x(1), y(1)-.3, 't', 'Color', 'k', 'FontSize', 18, 'FontWeight', 'bold', ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

    % K arc + arrowhead
    if neuron == 2
        theta = linspace(1.5*pi, 2*pi-(1/6)*pi, 100);
    else
        theta = linspace(2*pi-(1/6)*pi, 1.5*pi, 100);
    end
    x = r * cos(theta);  y = r * sin(theta);
    plot(x, y, 'color', blue, 'LineWidth', 2)
    dx = x(end)-x(end-1);  dy = y(end)-y(end-1);
    angle = atan2(dy, dx);
    x_arrow = [x(end), x(end)-arrow_length*cos(angle-arrow_angle), x(end)-arrow_length*cos(angle+arrow_angle)];
    y_arrow = [y(end), y(end)-arrow_length*sin(angle-arrow_angle), y(end)-arrow_length*sin(angle+arrow_angle)];
    patch(x_arrow, y_arrow, blue, 'EdgeColor', blue)
    if neuron == 2
        text(x(1),   y(1)+.3,   'k', 'color', blue, 'FontSize', 14, 'FontWeight', 'bold', ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    else
        text(x(end), y(end)+.3, 'k', 'color', blue, 'FontSize', 14, 'FontWeight', 'bold', ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    end

    % Format
    axis equal; axis off;
    camroll(90);
    % --- PER-PLOT LEGEND ---
    h1 = plot(NaN, NaN, 'Color', dynamic_arrow_color, 'LineWidth', 3);
    h2 = plot(NaN, NaN, 'Color', blue,                'LineWidth', 3);
    
    % Create the legend without the automatic 'Location' property
    lgd = legend([h1, h2], {sprintf('n%d', neuron), sprintf('n%d', neuron_dynamic)}, ...
        'Orientation', 'horizontal', 'FontSize', 14, 'Box', 'off');
        
    % Manually force the legend to the absolute visual Northwest (top-left) of the subplot
    lgd.Units = 'normalized';
    
    % Adjust these specific offsets if you need to nudge the legend slightly
    lgd_x = left + 0.02;               % 2% from the left edge of the cell
    lgd_y = bottom + inner_h - 0.1;   % 6% from the top edge of the axes
    
    lgd.Position = [lgd_x, lgd_y, 0.15, 0.05]; 

% --- LETTER LABEL (a, b, c, …) top-left of each subplot, publication style ---
    letter = char('a' + plot_idx - 1);          % 'a', 'b', 'c', …

    % Top-left in normalised figure coords: just outside the axes top-left corner
    label_x = left + 0.003;                     % slight inset from cell left edge
    label_y = 1 - (row - 1) * cell_h - 0.055;  % near the top of the cell

    annotation('textbox', [label_x, label_y, 0.06, 0.05], ...
        'String', letter, ...
        'FontSize', 18, 'FontWeight', 'bold', ...
        'FontName',  'Helvetica', ...           % clean sans-serif, common in journals
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment',   'middle', ...
        'EdgeColor',           'none', ...
        'BackgroundColor',     'none');
end

results_dir = '../../results/figure 3';
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

exportgraphics(fig, fullfile(results_dir, 'figure3.eps'), 'ContentType', 'image');
exportgraphics(fig, fullfile(results_dir, 'figure3.png'), 'Resolution', 300);


