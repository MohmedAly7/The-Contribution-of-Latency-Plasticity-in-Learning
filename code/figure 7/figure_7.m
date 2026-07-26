if ~exist('USE_PRE_RUN_DATA', 'var')
    USE_PRE_RUN_DATA = 0;
end
if USE_PRE_RUN_DATA == 1
    data_source_dir = '../../data/figure 7/'; 
else
    data_source_dir = '../../results/figure 7/';
end

% =========================================================================
%  FIGURE 7 — ISI LINE PLOT VIEWER
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
static_location          = data_source_dir; % folder containing the .neuron file
static_file              = 'figure7.neuron';  % filename (with extension)
static_numberOfEventPage = -1000;             % negative value → ISI mode
static_numberOfhiddenpage = 4;                % context pages loaded around current page
static_pageNumber        = 999;               % which page to display (clamped to max)

% =========================================================================
%  COLOR PALETTE  — one row per neuron; indices map via s1(g,:)
% =========================================================================
s1 = [
    
    0.000, 0.000, 0.000; % Black
    1.000, 0.000, 0.000; % Red
    0.000, 0.700, 0.000; % Green
   
    .9000, .9000, 0.000; % Yellow
    0.300, 0.500, 0.700; % Steel Blue
    0.700, 0.300, 0.700; % Magenta
    0.000, 0.700, 0.700; % Cyan
   0.8500, 0.3250, 0.0980 %orange
    0, 0.4470, 0.7410;  %blue
    0.700, 0.700, 0.700; % Gray
    0.700, 0.300, 0.300; % Dark Red
    0.500, 0.700, 0.300; % Light Green
    0.300, 0.700, 0.500; % Teal
    0.000, 0.000, 1.000; % Blue
    0.300, 0.300, 0.700; % Navy Blue
    0.700, 0.300, 0.000; % Brown
    0.500, 0.000, 0.500; % Purple
    0.500, 0.500, 0.000; % Olive---
    0.900, 0.500, 0.000; % Orange-
    0.700, 0.500, 0.700; % Lavender--
    0.500, 0.700, 0.700  % Turquoise-5-5
    ];

plotParams.fontSize      = 14;
plotParams.titleFontSize = 16;
plotParams.lineWidth     = 2;

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

% --- Read File Header ---
FileOffest = 4;
fileid = fopen([location1 file1], 'r');
n = fread(fileid, 1, 'int32');
if n > 0
    s1 = [lines(7); s1];
end
fseek(fileid, 0, 'eof');
totalNumBytes = ftell(fileid) - FileOffest;
fclose(fileid);

numberOfbytesPerEvent = 24;
totalEventnumber      = totalNumBytes / numberOfbytesPerEvent;

% --- Page Setup ---
if USE_STATIC
    numberOfEventPage = static_numberOfEventPage;
else
    numberOfEventPage = -input('Enter number of events per page (negative to show ISI): ');
end

numberOfEventPage  = abs(numberOfEventPage);

if USE_STATIC
    numberOfhiddenpage = static_numberOfhiddenpage;
else
    numberOfhiddenpage = input('Enter number of hidden pages (context): ');
end

totalPageNumber    = floor(totalEventnumber / numberOfEventPage);
pageNumbertoDisplay = 999;

% --- Page Navigation Loop ---
while true

    if USE_STATIC
        % Clamp to valid range
        if pageNumbertoDisplay > totalPageNumber
            pageNumbertoDisplay = totalPageNumber;
        end
        fprintf('Static mode: displaying page %d of %d\n', pageNumbertoDisplay, totalPageNumber);
    end

    if isempty(pageNumbertoDisplay) || pageNumbertoDisplay == 0
        disp('Exiting.');
        break;
    end

    if pageNumbertoDisplay < 1 || pageNumbertoDisplay > totalPageNumber
        fprintf('Invalid page number. Please enter between 1 and %d.\n', totalPageNumber);
        if USE_STATIC
            break;
        end
        continue;
    end

    % --- Compute before/after context (same logic as original) ---
    eventnumber = (pageNumbertoDisplay - 1) * numberOfEventPage;
    before      = numberOfEventPage * numberOfhiddenpage;
    after       = numberOfEventPage * numberOfhiddenpage;

    if (eventnumber - before) < 0
        before = eventnumber;
    end
    if (eventnumber + numberOfEventPage + after) > totalEventnumber
        after = totalEventnumber - (eventnumber + numberOfEventPage);
    end

    % --- Load Page Data with Context ---
    fileid         = fopen([location1 file1], 'r');
    byte           = FileOffest + (eventnumber - before) * numberOfbytesPerEvent;
    fseek(fileid, byte, 'bof');

    numEventsToRead = numberOfEventPage + before + after;
    x = zeros(numEventsToRead, 4);
    for o = 1:numEventsToRead
        t = fread(fileid, 1, 'double');
        i = fread(fileid, 1, 'int32') + 1;
        j = fread(fileid, 1, 'int32') + 1;
        E = fread(fileid, 1, 'double');
        x(o, :) = [i, j, t, E];
    end
    fclose(fileid);

    % Normalize time
    TT      = x(1, 3);
    x(:, 3) = x(:, 3) - TT;

    % Current page window (without hidden context)
    temp = x(before + 1 : before + numberOfEventPage, :);

    % --- ISI Calculation on full window (x) same as original ---
    fir  = x(x(:,1) == x(:,2), :);      % all events including context
    fir1 = temp(temp(:,1) == temp(:,2), :);  % current page only

    C = cell(1, n);  % spike times from full window
    N = cell(1, n);  % spike times from current page
    D = cell(1, n);  % ISI from full window
    K = cell(1, n);  % ISI from current page

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
    figure('Name', sprintf('Firing period vs. Time (Line) - Page %d', pageNumbertoDisplay), ...
           'WindowState', 'maximized');
    ax1 = axes();
    hold(ax1, 'on');
    grid(ax1, 'on');
    box(ax1, 'on');

    last_time_points = [];
    for p = 1:n
        if ~isempty(D{p})
            time_points      = C{p}(1:end-1);
            isi_values       = D{p};
            last_time_points = time_points;

            plot(ax1, time_points, isi_values, ...
                'Color',       s1(p, :), ...
                'LineWidth',   plotParams.lineWidth, ...
                'DisplayName', ['Neuron ' num2str(p)]);
        end
    end


    xlabel(ax1, 'Time (ms)', 'FontSize', plotParams.fontSize);
    ylabel(ax1, 'Firing period (ms)',  'FontSize', plotParams.fontSize);
    legend(ax1, 'show', 'NumColumns', 5, 'Location', 'northoutside', 'FontSize', 8,'Box','off');
    set(ax1, 'FontSize', plotParams.fontSize, 'TickDir', 'out');

    if ~isempty(last_time_points)
        xlim(ax1, [last_time_points(1), last_time_points(end)]);
    end

    % Save the figure to the results directory
    output_dir = '../../results/figure 7/';
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    saveas(gcf, fullfile(output_dir, sprintf('figure7_page%d.png', pageNumbertoDisplay)));

    % In static mode render once and exit.
    if USE_STATIC
        break;
    end

    pageNumbertoDisplay = input(sprintf('Enter page number (1 to %d), 0 to exit: ', totalPageNumber));
end