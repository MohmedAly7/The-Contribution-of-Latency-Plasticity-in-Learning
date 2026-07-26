if ~exist('USE_PRE_RUN_DATA', 'var')
    USE_PRE_RUN_DATA = 0;
end
if USE_PRE_RUN_DATA == 1
    data_source_dir = '../../data/figure 7b/'; 
else
    data_source_dir = '../../results/figure 7b/';
end

% =========================================================================
%  FIGURE 7B — ISI LINE PLOT VIEWER (Active vs. Inactive Neurons)
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
static_location          = data_source_dir;                % folder containing the .neuron file
static_file              = 'figure7b.neuron';  % filename (with extension)
static_numberOfEventPage = -1000;             % negative value → ISI mode
static_numberOfhiddenpage = 50;               % context pages loaded around current page
static_pageNumber        = 10000;              % which page to display (clamped to max)

% =========================================================================
%  FILE SELECTION
% =========================================================================
location1 = data_source_dir;

if USE_STATIC
    location1 = static_location;
    file1     = static_file;
    fprintf('Static mode: using file "%s" in "%s"\n', file1, location1);
else
    [file1, location1] = uigetfile('*.neuron', 'Select a Neuron Data File', location1);
    if file1 == 0
        disp('No file selected. Exiting.');
        return;
    end
end

file = file1;
location = location1;

file_selected = true;
while file_selected
    fprintf('Selected File: %s\n\n', file);
    FileOffest = 4;
    fileid = fopen([location file], 'r');
    n = fread(fileid, 1, 'int32');

    active_color   = [0, 0.4470, 0.7410];
    inactive_color = [0.5, 0.5, 0.5];
    s1 = zeros(n, 3);
    for i = 1:n
        if i <= 25
            s1(i, :) = active_color;
        else
            s1(i, :) = inactive_color;
        end
    end

    fseek(fileid, 0, 'eof');
    totalNumBytes = ftell(fileid) - FileOffest;
    fclose(fileid);

    plotParams.fontSize      = 14;
    plotParams.titleFontSize = 16;
    plotParams.lineWidth     = 1.5;

    numberOfbytesPerEvent = 24;
    totalEventnumber      = totalNumBytes / numberOfbytesPerEvent;

    page_navigation = true;
    while page_navigation

        if USE_STATIC
            numberOfEventPage = static_numberOfEventPage;
        else
            numberOfEventPage = input('Enter number of events per page (-1 to change file): ');
        end

        if isempty(numberOfEventPage) || ~isnumeric(numberOfEventPage) || numberOfEventPage == -1
            file_selected = false;
            break;
        end

        if numberOfEventPage > 0
            fprintf('Please enter a negative number to enable ISI line plot.\n');
            if USE_STATIC
                break;
            end
            continue;
        end

        numberOfEventPage  = abs(numberOfEventPage);

        if USE_STATIC
            numberOfhiddenpage = static_numberOfhiddenpage;
        else
            numberOfhiddenpage = input('Enter number of hidden pages (context): ');
        end

        totalPageNumber    = floor(totalEventnumber / numberOfEventPage);

        if ~USE_STATIC
            fprintf('\n--- Navigation ---\n');
            fprintf('  -1: Go back (change events per page)\n');
            fprintf('  -4: Select a new file\n');
            fprintf('  -5: Close all figures & select a new file\n\n');
        end

        display_page = true;
        while display_page

            if USE_STATIC
                pageNumbertoDisplay = static_pageNumber;
                % Clamp to valid range
                if pageNumbertoDisplay > totalPageNumber
                    pageNumbertoDisplay = totalPageNumber;
                end
                fprintf('Static mode: displaying page %d of %d\n', pageNumbertoDisplay, totalPageNumber);
            else
                pageNumbertoDisplay = input(sprintf('Enter page number (Max: %d): ', totalPageNumber));
            end

            if isempty(pageNumbertoDisplay) || ~isnumeric(pageNumbertoDisplay)
                continue;
            end

            if pageNumbertoDisplay == -5
                close all;
                pageNumbertoDisplay = -4;
            end

            if pageNumbertoDisplay == -4
                display_page    = false;
                page_navigation = false;
                file_selected   = false;
                continue;
            end

            if pageNumbertoDisplay == -1
                display_page = false;
                continue;
            end

            if pageNumbertoDisplay < 1 || pageNumbertoDisplay > totalPageNumber
                fprintf('Invalid page number. Please try again.\n');
                if USE_STATIC
                    break;
                end
                continue;
            end

            % --- Data Loading ---
            fileid      = fopen([location file], 'r');
            eventnumber = (pageNumbertoDisplay - 1) * numberOfEventPage;
            before      = numberOfEventPage * numberOfhiddenpage;
            after       = numberOfEventPage * numberOfhiddenpage;

            if (eventnumber - before) < 0
                before = eventnumber;
            end
            if (eventnumber + numberOfEventPage + after) > totalEventnumber
                after = totalEventnumber - (eventnumber + numberOfEventPage);
            end

            byte = FileOffest + (eventnumber - before) * 24;
            fseek(fileid, byte, 'bof');

            numEventsToRead = numberOfEventPage + after + before;
            x = zeros(numEventsToRead, 4);
            for o = 1:numEventsToRead
                t = fread(fileid, 1, 'double');
                i = fread(fileid, 1, 'int32') + 1;
                j = fread(fileid, 1, 'int32') + 1;
                E = fread(fileid, 1, 'double');
                x(o, :) = [i, j, t, E];
            end
            fclose(fileid);

            TT      = x(1, 3);
            x(:,3)  = x(:,3) - TT;
            temp    = x(before + 1 : before + numberOfEventPage, :);

            % --- ISI Calculation ---
            fir  = x(x(:,1) == x(:,2), :);
            fir1 = temp(temp(:,1) == temp(:,2), :);

            C = cell(1, n); N = C; D = C; K = C;
            for i = 1:n
                C{i} = fir(fir(:,1) == i, 3);
                N{i} = fir1(fir1(:,1) == i, 3);
                if numel(C{i}) > 1
                    D{i} = diff(C{i});
                end
                if numel(N{i}) > 1
                    K{i} = diff(N{i});
                end
            end

            % --- ISI Line Plot ---
            H1  = figure('Name', sprintf('Firing period vs. Time (Line) - Page %d', pageNumbertoDisplay), ...
                         'WindowState', 'maximized', 'Visible', 'off');
            ax1 = axes(H1);
            hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');

            % Dummy handles for clean two-item legend
            h_active   = plot(ax1, NaN, NaN, 'Color', active_color,  'LineWidth', plotParams.lineWidth);
            h_inactive = plot(ax1, NaN, NaN, 'Color', inactive_color, 'LineWidth', plotParams.lineWidth);

            last_time_points = [];
            for p = 1:n
                if ~isempty(D{p})
                    time_points      = C{p}(1:end-1);
                    isi_values       = D{p};
                    last_time_points = time_points;

                    plot(ax1, time_points, isi_values, ...
                        'Color',     s1(p, :), ...
                        'LineWidth', plotParams.lineWidth);
                end
            end


            title(ax1,  sprintf('ISI Over Time — Page %d', pageNumbertoDisplay), ...
                  'FontSize', plotParams.titleFontSize);
            xlabel(ax1, 'Time (ms)', 'FontSize', plotParams.fontSize);
            ylabel(ax1, 'Firing period (ms)',  'FontSize', plotParams.fontSize);
            legend(ax1, [h_active, h_inactive], ...
                   {'Active Neurons (1-25)', 'Non-active Neurons (26-50)'}, ...
                   'Location', 'northeast', 'FontSize', 8,'Box','off');
            set(ax1, 'FontSize', plotParams.fontSize, 'TickDir', 'out');

            if ~isempty(last_time_points)
                xlim(ax1, [last_time_points(1), last_time_points(end)]);
            end

            % In static mode render once and exit.
            if USE_STATIC
                saveas(H1, fullfile('../../results/figure 7b/', 'figure7b_output.png'));
                break;
            end
        end

        % In static mode exit after one render.
        if USE_STATIC
            break;
        end
    end

    % Always exit the outer loop after one file.
    break;
end
if USE_STATIC
    exit;
end
