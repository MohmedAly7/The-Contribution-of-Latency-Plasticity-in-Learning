if ~exist('USE_PRE_RUN_DATA', 'var')
    USE_PRE_RUN_DATA = 0;
end
if USE_PRE_RUN_DATA == 1
    data_source_dir = '../../data/figure 4/'; 
else
    data_source_dir = '../../results/figure 4/';
end

% =========================================================================
%  NEURON DATA VIEWER — ISI Line Plot
%  Supports two input modes controlled by a single flag:
%    useStaticInput = true  → all parameters are taken from hardcoded values
%    useStaticInput = false → user is prompted at runtime (original behaviour)
% =========================================================================

% -------------------------------------------------------------------------
%  INPUT MODE FLAG  (flip this to switch between static and dynamic modes)
% -------------------------------------------------------------------------
useStaticInput = true;   % true = static (hardcoded) | false = dynamic (prompts)

% =========================================================================
%  STATIC PARAMETER BLOCK
%  These values are used only when useStaticInput = true.
%  Edit them freely; they are ignored when useStaticInput = false.
% =========================================================================
static_location          = data_source_dir;   % folder containing the .neuron file
static_file              = 'figure4a.neuron'; % filename (with extension)
static_numberOfEventPage = -200;          % negative value → show ISI mode
static_numberOfhiddenpage = 12;           % context pages loaded around current page

% =========================================================================
%  COLOR PALETTE  (used for plotting each neuron in a distinct colour)
% =========================================================================
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
%  PLOT STYLE PARAMETERS
% =========================================================================
plotParams.fontSize      = 14;   % axis tick / label font size
plotParams.titleFontSize = 16;   % figure title font size
plotParams.lineWidth     = 2;    % line width for all plots

% =========================================================================
%  FILE SELECTION
%  Static mode: uses the variables defined in the static block above.
%  Dynamic mode: opens a file-browser dialog for the user to choose.
% =========================================================================
if useStaticInput
    % --- Static: use hardcoded path and filename ---
    location1 = static_location;
    file1     = static_file;
    fprintf('Static mode: using file "%s" in "%s"\n', file1, location1);
else
    % --- Dynamic: prompt user with a file-browser dialog ---
    location1 = '';
    [file1, location1] = uigetfile('*.neuron', 'Select a Neuron Data File', location1);
    if isequal(file1, 0)
        disp('No file selected. Exiting.');
        return;
    end
end

% =========================================================================
%  READ FILE HEADER
%  The first 4 bytes store the number of neurons (n) as an int32.
%  If n > 0, 7 extra default MATLAB line colours are prepended to the palette.
% =========================================================================
FileOffset = 4;                               % byte offset past the header int32
fileid     = fopen([location1 file1], 'r');
n          = fread(fileid, 1, 'int32');        % number of neurons in the file

if n > 0
    % Prepend MATLAB's default 7-colour cycle so neuron indices stay consistent
    s1 = [lines(7); s1];
end

% Compute total number of events from file size
fseek(fileid, 0, 'eof');                       % jump to end of file
totalNumBytes = ftell(fileid) - FileOffset;    % exclude the 4-byte header
fclose(fileid);

numberOfBytesPerEvent = 24;                    % each event: double(8) + int32(4) + int32(4) + double(8)
totalEventNumber      = totalNumBytes / numberOfBytesPerEvent;

% =========================================================================
%  PAGE / DISPLAY PARAMETERS
%  A negative numberOfEventPage value activates ISI-display mode.
%  Static mode: uses hardcoded values; Dynamic mode: prompts the user.
% =========================================================================
if useStaticInput
    % --- Static: use hardcoded values ---
    numberOfEventPage  = static_numberOfEventPage;
    numberOfHiddenPage = static_numberOfhiddenpage;
else
    % --- Dynamic: prompt user at runtime ---
    numberOfEventPage  = input('Enter number of events per page (show ISI): ');
    numberOfHiddenPage = input('Enter number of hidden pages (context): ');
end

% Convert to absolute (the sign was just a mode flag, not a real negative size)
numberOfEventPage = abs(numberOfEventPage);

totalPageNumber     = floor(totalEventNumber / numberOfEventPage);
pageNumberToDisplay = 1;   % start on page 1

% =========================================================================
%  MAIN PAGE-NAVIGATION LOOP
%  Continues until the user enters 0 or an empty value.
% =========================================================================
while true

    % --- Exit conditions ---
    if isempty(pageNumberToDisplay) || pageNumberToDisplay == 0
        disp('Exiting.');
        break;
    end

    % --- Validate page number ---
    if pageNumberToDisplay < 1 || pageNumberToDisplay > totalPageNumber
        fprintf('Invalid page number. Please enter between 1 and %d.\n', totalPageNumber);
        % Re-prompt and continue
        pageNumberToDisplay = input(sprintf('Enter page number (1 to %d), 0 to exit: ', totalPageNumber));
        continue;
    end

    % =====================================================================
    %  COMPUTE CONTEXT WINDOW (hidden pages before and after current page)
    %  The context is loaded so ISI calculations have enough surrounding
    %  spikes for continuity at page boundaries.
    % =====================================================================
    eventnumber = (pageNumberToDisplay - 1) * numberOfEventPage;  % first event index of this page
    before      = numberOfEventPage * numberOfHiddenPage;          % events to load before page
    after       = numberOfEventPage * numberOfHiddenPage;          % events to load after page

    % Clamp 'before' so we don't seek before the start of the file
    if (eventnumber - before) < 0
        before = eventnumber;
    end
    % Clamp 'after' so we don't read past the end of the file
    if (eventnumber + numberOfEventPage + after) > totalEventNumber
        after = totalEventNumber - (eventnumber + numberOfEventPage);
    end

    % =====================================================================
    %  LOAD PAGE DATA WITH CONTEXT
    %  Each event record layout (24 bytes total):
    %    [double: timestamp | int32: neuron_i | int32: neuron_j | double: energy]
    % =====================================================================
    fileid         = fopen([location1 file1], 'r');
    byteOffset     = FileOffset + (eventnumber - before) * numberOfBytesPerEvent;
    fseek(fileid, byteOffset, 'bof');

    numEventsToRead = numberOfEventPage + before + after;
    x = zeros(numEventsToRead, 4);   % columns: [neuron_i, neuron_j, time, energy]

    for o = 1:numEventsToRead
        t = fread(fileid, 1, 'double');   % timestamp (s)
        i = fread(fileid, 1, 'int32') + 1; % neuron index i (1-based)
        j = fread(fileid, 1, 'int32') + 1; % neuron index j (1-based)
        E = fread(fileid, 1, 'double');   % event energy / amplitude
        x(o, :) = [i, j, t, E];
    end
    fclose(fileid);

    % Shift timestamps so the window starts at t = 0
    TT      = x(1, 3);
    x(:, 3) = x(:, 3) - TT;

    % Isolate the current page rows (strip the hidden context)
    temp = x(before + 1 : before + numberOfEventPage, :);

    % =====================================================================
    %  ISI (Inter-Spike Interval) CALCULATION
    %  Auto-spikes: events where i == j (a neuron fires on its own channel).
    %  ISI is the time difference between consecutive auto-spikes.
    % =====================================================================
    fir  = x(x(:,1) == x(:,2), :);          % auto-spikes in full window (with context)
    fir1 = temp(temp(:,1) == temp(:,2), :);  % auto-spikes in current page only

    % Pre-allocate cell arrays for each neuron
    C = cell(1, n);  % spike times — full window (used for smooth ISI across boundary)
    N = cell(1, n);  % spike times — current page only
    D = cell(1, n);  % ISI values  — full window
    K = cell(1, n);  % ISI values  — current page only

    for i = 1:n
        C{i} = fir(fir(:,1) == i, 3);           % all spike times for neuron i
        N{i} = fir1(fir1(:,1) == i, 3);         % page-only spike times for neuron i
        if numel(C{i}) > 1
            D{i} = diff(C{i});                   % ISI from full window
        end
        if numel(N{i}) > 1
            K{i} = diff(N{i});                   % ISI from current page
        end
    end

    % =====================================================================
    %  PLOT: ISI vs. Time (Line Plot)
    %  One line per neuron; x-axis = spike time, y-axis = ISI to next spike.
    % =====================================================================
    figure('Name', sprintf('Firing Period vs. Time (Line) - Page %d', pageNumberToDisplay), ...
           'WindowState', 'maximized');
    ax1 = axes();
    hold(ax1, 'on');
    grid(ax1, 'on');
    box(ax1, 'on');

    last_time_points = [];   % track the last neuron's time vector to set x-limits

    for p = 1:n
        if ~isempty(D{p})
            time_points      = C{p}(1:end-1);   % time of each spike (ISI is between spike p and p+1)
            isi_values       = D{p};             % corresponding ISI values
            last_time_points = time_points;

            plot(ax1, time_points, isi_values, ...
                'Color',       s1(p, :), ...
                'LineWidth',   plotParams.lineWidth, ...
                'DisplayName', ['Neuron ' num2str(p)]);
        end
    end

    % --- Axis labels and formatting ---
    xlabel(ax1, 'Time (ms)', 'FontSize', plotParams.fontSize);
    ylabel(ax1, 'Firing period (ms)',  'FontSize', plotParams.fontSize);
    legend(ax1, 'show', 'NumColumns', 2, 'Location', 'northeast', 'FontSize', 8, 'Box', 'off');
    set(ax1, 'FontSize', plotParams.fontSize, 'TickDir', 'out');

    % Set x-axis limits to match the plotted data range
    if ~isempty(last_time_points)
        xlim(ax1, [last_time_points(1), last_time_points(end)]);
    end

    if useStaticInput
        output_dir = '../../results/figure 4/';
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end
        saveas(gcf, fullfile(output_dir, sprintf('figure4a.png', pageNumberToDisplay)));
        break;
    end
    
    % --- Prompt for next page ---
    pageNumberToDisplay = input(sprintf('Enter page number (1 to %d), 0 to exit: ', totalPageNumber));

end % while true
