if ~exist('USE_PRE_RUN_DATA', 'var')
    USE_PRE_RUN_DATA = 0;
end
if USE_PRE_RUN_DATA == 1
    data_source_dir = '../../data/figure 5/'; 
else
    data_source_dir = '../../results/figure 5/';
end

% =========================================================================
%  FIGURE 5a — SPIKE RASTER PLOT VIEWER
%  Supports two input modes controlled by a single flag:
%    USE_STATIC = true  → all parameters are taken from hardcoded values
%    USE_STATIC = false → user is prompted at runtime (original behaviour)
% =========================================================================

% -------------------------------------------------------------------------
%  INPUT MODE FLAG  (flip this to switch between static and dynamic modes)
% -------------------------------------------------------------------------
USE_STATIC = true;   % true = static (hardcoded) | false = dynamic (prompts)

% =========================================================================
%  STATIC PARAMETER BLOCK
%  These values are used only when USE_STATIC = true.
%  Edit them freely; they are ignored when USE_STATIC = false.
% =========================================================================
static_location          = data_source_dir;               % folder containing the .neuron file
static_file              = 'figure5a.neuron'; % filename (with extension)
static_neurons_to_display = [1];             % neuron indices to plot ([] = all)
static_showInputs        = true;             % true = show inputs from other neurons
static_numberOfEventPage = -1000;            % negative value → Firing period annotation mode
static_numberOfhiddenpage = 0;              % context pages loaded around current page
static_pageNumber        = 1;               % which page to display

% =========================================================================
%  COLOR PALETTE  — one row per neuron; indices map via s1(g,:)
% =========================================================================
location1 = '';   % starting folder for the file browser (empty = last used)

s1 = [
    0.000, 0.000, 0.000; % 1  Black
    1.000, 0.000, 0.000; % 2  Red
    0.000, 0.700, 0.000; % 3  Green
    0.900, 0.900, 0.000; % 4  Yellow
    0.300, 0.500, 0.700; % 5  Steel Blue
    0.700, 0.300, 0.700; % 6  Magenta
    0.000, 0.700, 0.700; % 7  Cyan
    0.850, 0.325, 0.098; % 8  Orange
    0.000, 0.447, 0.741; % 9  Blue
    0.700, 0.700, 0.700; % 10 Gray
    0.700, 0.300, 0.300; % 11 Dark Red
    0.500, 0.700, 0.300; % 12 Light Green
    0.300, 0.700, 0.500; % 13 Teal
    0.000, 0.000, 1.000; % 14 Pure Blue
    0.300, 0.300, 0.700; % 15 Navy Blue
    0.700, 0.300, 0.000; % 16 Brown
    0.500, 0.000, 0.500; % 17 Purple
    0.500, 0.500, 0.000; % 18 Olive
    0.900, 0.500, 0.000; % 19 Orange (alt)
    0.700, 0.500, 0.700; % 20 Lavender
    0.500, 0.700, 0.700; % 21 Turquoise
];

% =========================================================================
%  OUTER LOOP — file selection
%  In static mode runs once with the hardcoded file.
%  In dynamic mode repeats so the user can open multiple files.
% =========================================================================
while true

    % -----------------------------------------------------------------
    %  FILE SELECTION
    % -----------------------------------------------------------------
    if USE_STATIC
        % --- Static: use hardcoded path and filename ---
        location1 = static_location;
        file1     = static_file;
        fprintf('Static mode: using file "%s" in "%s"\n', file1, location1);
    else
        % --- Dynamic: open a file-browser dialog ---
        [file1, location1] = uigetfile('*.neuron', 'Select a Neuron Data File', location1);
        if isequal(file1, 0)
            disp('No file selected. Exiting.');
            break;
        end
    end

    file     = file1;
    location = location1;

    % =====================================================================
    %  DISPLAY-OPTIONS LOOP
    %  Runs once per file (or again if the user requests option changes
    %  mid-session via page code −2).
    % =====================================================================
    file_selected = true;
    while file_selected
        fprintf('Selected File: %s\n\n', file);

        % -----------------------------------------------------------------
        %  Read file header to get neuron count and total byte size.
        %  File layout: [int32: n_neurons] [event records…]
        % -----------------------------------------------------------------
        FileOffset    = 4;
        fileid        = fopen([location file], 'r');
        n             = fread(fileid, 1, 'int32');   % number of neurons

        % Prepend MATLAB default colours if the file contains neurons;
        % fall back to a single black colour for degenerate/empty files.
        if n > 0
            s1 = [lines(7); s1];
        else
            s1 = [0 0 0];
        end

        fseek(fileid, 0, 'eof');
        totalNumBytes = ftell(fileid) - FileOffset;   % bytes after header
        fclose(fileid);

        % -----------------------------------------------------------------
        %  DISPLAY OPTIONS — which neurons to show and whether to include
        %  synaptic input traces from other neurons.
        % -----------------------------------------------------------------
        plotOptions = struct();
        fprintf('This file contains %d neurons.\n', n);

        % --- 1. Neuron selection ---
        if USE_STATIC
            % --- Static: use hardcoded neuron list ---
            userInput = static_neurons_to_display;
        else
            % --- Dynamic: prompt user ---
            userInput = input('Enter neuron indices to display (e.g., [1 3 5], or Enter for all): ');
        end

        if isempty(userInput)
            plotOptions.neurons_to_display = 1:n;           % default: all neurons
        else
            % Keep only indices that are valid (1 … n)
            plotOptions.neurons_to_display = userInput(userInput >= 1 & userInput <= n);
            if isempty(plotOptions.neurons_to_display)
                fprintf('No valid neurons selected. Defaulting to all neurons.\n');
                plotOptions.neurons_to_display = 1:n;
            end
        end
        fprintf('Displaying neurons: %s\n', mat2str(plotOptions.neurons_to_display));

        % --- 2. Show/hide synaptic inputs from other neurons ---
        if USE_STATIC
            % --- Static: use hardcoded flag ---
            plotOptions.showInputs = static_showInputs;
            fprintf('Static mode: showInputs = %d\n', plotOptions.showInputs);
        else
            % --- Dynamic: prompt user ---
            userInput = input('Show inputs from other neurons? (y/n) [y]: ', 's');
            if isempty(userInput) || lower(userInput(1)) == 'y'
                plotOptions.showInputs = true;
                disp('Inputs from other neurons will be shown.');
            else
                plotOptions.showInputs = false;
                disp('Inputs from other neurons will be hidden.');
            end
        end
        fprintf('\n');

        % -----------------------------------------------------------------
        %  PLOT STYLE PARAMETERS
        % -----------------------------------------------------------------
        plotParams.fontSize      = 14;
        plotParams.titleFontSize = 16;
        plotParams.lineWidth     = 1.5;
        plotParams.markerSize    = 8;

        % =================================================================
        %  PAGE-SIZE LOOP
        %  The user chooses how many events fit on one page.
        %  Special codes: −1 = change file | −2 = change display options
        % =================================================================
        page_navigation = true;
        while page_navigation

            % --- Events per page ---
            if USE_STATIC
                % --- Static: use hardcoded value ---
                numberOfEventPage = static_numberOfEventPage;
            else
                % --- Dynamic: prompt user ---
                % Negative value activates ISI annotation mode.
                % −1 = go back to file selection | −2 = change display options
                numberOfEventPage = input('Enter number of events per page (-1 to change file, -2 to change display options): ');
            end

            % Code −2: return to display-options prompt
            if numberOfEventPage == -2
                page_navigation = false;
                continue;
            end

            % Code −1 or empty: return to file selection
            if isempty(numberOfEventPage) || ~isnumeric(numberOfEventPage) || numberOfEventPage == -1
                file_selected = false;
                break;
            end

            % A negative page size activates firig period annotation mode
            show_isi_plots = false;
            if numberOfEventPage < 0
                show_isi_plots    = true;
                numberOfEventPage = abs(numberOfEventPage);
            end

            % --- Hidden context pages ---
            if USE_STATIC
                numberOfhiddenpage = static_numberOfhiddenpage;
            else
                if show_isi_plots
                    numberOfhiddenpage = input('Enter number of hidden pages (context): ');
                else
                    numberOfhiddenpage = 0;
                end
            end

            % Compute total pages from file size
            numberOfBytesPerEvent = 24;   % double(8) + int32(4) + int32(4) + double(8)
            totalEventNumber      = totalNumBytes / numberOfBytesPerEvent;
            totalPageNumber       = floor(totalEventNumber / numberOfEventPage);

            % Navigation hint (dynamic mode only — static users don't need it)
            if ~USE_STATIC
                fprintf('\n--- Navigation ---\n');
                fprintf('  -1: Go back (change events per page)\n');
                fprintf('  -2: Change neuron display options\n');
                fprintf('  -4: Select a new file\n');
                fprintf('  -5: Close all figures & select a new file\n\n');
            end

            % =============================================================
            %  PAGE DISPLAY LOOP
            %  The user picks a page number; special codes navigate menus.
            % =============================================================
            display_page = true;
            while display_page

                % --- Page number ---
                if USE_STATIC
                    % --- Static: use hardcoded page number ---
                    pageNumbertoDisplay = static_pageNumber;
                else
                    % --- Dynamic: prompt user ---
                    pageNumbertoDisplay = input(sprintf('Enter page number (Max: %d): ', totalPageNumber));
                end

                if isempty(pageNumbertoDisplay) || ~isnumeric(pageNumbertoDisplay)
                    continue;
                end

                % Code −5: close all figures then fall through to −4
                if pageNumbertoDisplay == -5
                    close all;
                    pageNumbertoDisplay = -4;
                end

                % Code −4: select a new file (exit all inner loops)
                if pageNumbertoDisplay == -4
                    display_page    = false;
                    page_navigation = false;
                    file_selected   = false;
                    continue;
                end

                % Code −2: return to display-options prompt
                if pageNumbertoDisplay == -2
                    display_page    = false;
                    page_navigation = false;
                    continue;
                end

                % Code −1: return to page-size prompt
                if pageNumbertoDisplay == -1
                    display_page = false;
                    continue;
                end

                % Validate page number
                if pageNumbertoDisplay < 1 || pageNumbertoDisplay > totalPageNumber
                    fprintf('Invalid page number. Please enter between 1 and %d.\n', totalPageNumber);
                    continue;
                end

                % ---------------------------------------------------------
                %  LOAD EVENT DATA FOR THE REQUESTED PAGE (+ CONTEXT)
                %  Context pages (numberOfhiddenpage) are loaded before and
                %  after the current window so ISI calculations at page
                %  boundaries remain accurate.
                % ---------------------------------------------------------
                fileid = fopen([location file], 'r');

                eventnumber = (pageNumbertoDisplay - 1) * numberOfEventPage;
                before      = numberOfEventPage * numberOfhiddenpage;
                after       = numberOfEventPage * numberOfhiddenpage;

                % Clamp context so we don't read outside the file
                if (eventnumber - before) < 0
                    before = eventnumber;
                end
                if (eventnumber + numberOfEventPage + after) > totalEventNumber
                    after = totalEventNumber - (eventnumber + numberOfEventPage);
                end

                % Seek to the first byte of the context window and read events
                byte = FileOffset + (eventnumber - before) * numberOfBytesPerEvent;
                fseek(fileid, byte, 'bof');

                numEventsToRead = numberOfEventPage + after + before;
                x = zeros(numEventsToRead, 4);   % columns: [i, j, time, amplitude]
                for o = 1:numEventsToRead
                    t = fread(fileid, 1, 'double');    % absolute timestamp
                    i = fread(fileid, 1, 'int32') + 1; % pre-synaptic neuron (1-based)
                    j = fread(fileid, 1, 'int32') + 1; % post-synaptic neuron (1-based)
                    E = fread(fileid, 1, 'double');    % event amplitude / energy
                    x(o, :) = [i, j, t, E];
                end
                fclose(fileid);

                % Shift timestamps so the window starts at t = 0
                TT      = x(1, 3);
                x(:, 3) = x(:, 3) - TT;

                % Isolate the current page rows (strip hidden context)
                temp = x(before + 1 : before + numberOfEventPage, :);

                % ---------------------------------------------------------
                %  Auto-spikes (i == j) are self-firing events.
                %  C/D use the full context window for accurate cross-boundary ISI;
                %  N/K use only the current page for display annotations.
                % ---------------------------------------------------------
                fir  = x(x(:,1) == x(:,2), :);          % auto-spikes in full window
                fir1 = temp(temp(:,1) == temp(:,2), :);  % auto-spikes on current page

                C = cell(1, n); N = C; K = C; D = C;

                for i = 1:n
                    C{i} = fir(fir(:,1) == i, 3);        % spike times — full window
                    N{i} = fir1(fir1(:,1) == i, 3);      % spike times — current page
                end
                for i = 1:length(C)
                    if numel(C{i}) > 1
                        D{i} = diff(C{i});   % ISI series — full window
                    end
                    if numel(N{i}) > 1
                        K{i} = diff(N{i});   % ISI series — current page
                    end
                end

                % ---------------------------------------------------------
                %  FIGURE: SPIKE RASTER PLOT
                %  One tiled subplot per selected neuron, x-axes linked.
                % ---------------------------------------------------------
                figure('Name', 'Spike Raster Plot', 'WindowState', 'maximized');

                num_subplots = length(plotOptions.neurons_to_display);
                if num_subplots == 0
                    continue;   % nothing to plot
                end

                % Create a tiled layout — one row per selected neuron
                tl           = tiledlayout(num_subplots, 1, 'TileSpacing', 'none', 'Padding', 'compact');
                axesHandles  = gobjects(num_subplots, 1);  % store axes for later linking
                legendHandles = gobjects(n, 1);            % one handle per source neuron

                % --- Draw one subplot per selected neuron ---
                for subplot_idx = 1:num_subplots
                    p  = plotOptions.neurons_to_display(subplot_idx);  % actual neuron index
                    ax = nexttile;
                    axesHandles(subplot_idx) = ax;

                    hold(ax, 'on');
                    grid(ax, 'on');
                    box(ax, 'on');

                    % y-axis label: neuron index
                    ylabel(ax, ['n ' num2str(p)], 'FontSize', plotParams.fontSize - 10);

                    % Gather all events that arrived at neuron p
                    events_for_neuron_p = temp(temp(:,2) == p, :);

                    if plotOptions.showInputs
                        % ---- SHOW INPUTS MODE ----
                        % Plot each source neuron g → p in its own colour.
                        for g = 1:n
                            idx = events_for_neuron_p(:,1) == g;   % events from g to p
                            if any(idx)
                                h = stem(ax, ...
                                    events_for_neuron_p(idx, 3), ...   % time
                                    events_for_neuron_p(idx, 4), ...   % amplitude
                                    'Color',           s1(g, :), ...
                                    'MarkerFaceColor', s1(g, :), ...
                                    'LineWidth',       plotParams.lineWidth, ...
                                    'MarkerSize',      plotParams.markerSize);
                                % Keep the first handle per source neuron for the legend
                                if ~isgraphics(legendHandles(g))
                                    legendHandles(g) = h;
                                end
                            end
                        end

                    else
                        % ---- SELF-FIRING ONLY MODE ----
                        % Plot only the neuron's own spikes (source == self, amplitude > 0).
                        idx        = events_for_neuron_p(:,1) == p;
                        firing_idx = idx & (events_for_neuron_p(:,4) > 0);
                        if any(firing_idx)
                            stem(ax, ...
                                events_for_neuron_p(firing_idx, 3), ...
                                events_for_neuron_p(firing_idx, 4), ...
                                'Color',           s1(p, :), ...
                                'MarkerFaceColor', s1(p, :), ...
                                'LineWidth',       plotParams.lineWidth, ...
                                'MarkerSize',      plotParams.markerSize);
                        end
                    end

                    % ---- ISI ANNOTATION (ISI mode only) ----
                    % Print each ISI value as text centred between consecutive
                    % spikes at a fixed y position of 0.75.
                    if show_isi_plots && ~isempty(K{p})
                        SS = (N{p}(1:end-1) + N{p}(2:end)) / 2;   % midpoint between spikes
                        text(ax, SS, ones(size(SS)) * 0.75, string(round(K{p}, 2)), ...
                            'Clipping',            'on', ...
                            'HorizontalAlignment', 'center', ...
                            'FontSize',            plotParams.fontSize);
                    end

                    set(ax, 'FontSize', plotParams.fontSize - 2);
                end   % end subplot loop

                % ---------------------------------------------------------
                %  AXIS FORMATTING — link x-axes; set shared x/y limits.
                % ---------------------------------------------------------
                if ~isempty(axesHandles) && all(isgraphics(axesHandles))
                    linkaxes(axesHandles, 'x');
                    xlim(axesHandles, [temp(1,3), temp(end,3)]);

                    % y-limits: span the amplitude range with a 15 % buffer
                    min_E    = min(temp(:,4));
                    max_E    = max(temp(:,4));
                    y_buffer = (max_E - min_E) * 0.15;
                    ylim(axesHandles, [min_E - y_buffer, max_E + y_buffer]);

                    % Hide x-tick labels on all but the bottom subplot
                    set(axesHandles(1:end-1), 'xticklabel', []);
                end

                xlabel(tl, 'Time (ms)', 'FontSize', plotParams.fontSize);

                % ---------------------------------------------------------
                %  LEGEND — only shown in "show inputs" mode because
                %  self-firing-only mode has one colour per subplot already.
                % ---------------------------------------------------------
                if plotOptions.showInputs
                    valid_idx = isgraphics(legendHandles);
                    if any(valid_idx)
                        legend_labels = arrayfun(@(x) ['Neuron ' num2str(x)], ...
                                                  find(valid_idx), 'UniformOutput', false);
                        legend(legendHandles(valid_idx), legend_labels, 'Location', 'northoutside','NumColumns',5,'Box','off');
                    end
                end

                % In static mode render once and exit all loops cleanly.
                % In dynamic mode the while loops keep running for navigation.
                if USE_STATIC
                    output_dir = '../../results/figure 5/';
                    if ~exist(output_dir, 'dir')
                        mkdir(output_dir);
                    end
                    saveas(gcf, fullfile(output_dir, sprintf('figure5a_page%d.png', pageNumbertoDisplay)));
                    break;
                end

            end   % display_page loop

            if USE_STATIC, break; end
        end   % page_navigation loop

        if USE_STATIC, break; end
    end   % file_selected loop

    break;   % always exit the outer loop after one file (static or dynamic)
end   % outer while true