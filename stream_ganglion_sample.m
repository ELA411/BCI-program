clc;clear;
global samples;
global s;
global expectedSamples;
global avgSampleTime;
global board_shim;
global fileName;
global timestamps;
% BoardShim class to communicate with a board
BoardShim.set_log_file('brainflow.log');
BoardShim.enable_dev_board_logger();
demo = 0;
% ---------------------------------------------------------------------
avgSampleTime = tic; % Variable to calculate average sample rate
outoforder = 0; % Tracks the samples out of order
timestamps = [];
samples = 0; % Total number of samples
lastPackageId = -1; % Used to check for packages wrap around
packageid = -1; % Current sample
wraps = 0; % Number of wrap arounds. Since having a infinite counter timestamp, the serial printer can't keep up
% ---------------------------------------------------------------------
params = BrainFlowInputParams();
preset = int32(BrainFlowPresets.DEFAULT_PRESET);

if demo == 1
    s = serialport("/dev/ttyACM0", 115200);
    % Create BoardShim object
    params.serial_port = '/dev/ttyACM0';
    params.mac_address = 'F8:89:D2:68:8D:54';
    % Change to this when using real hardware BoardIds.GANGLION_NATIVE_BOARD
    board_shim = BoardShim(int32(BoardIds.GANGLION_BOARD), params);
    sampling_rate = board_shim.get_sampling_rate(int32(BoardIds.GANGLION_BOARD), preset);
else
    board_shim = BoardShim(int32(BoardIds.SYNTHETIC_BOARD), params);
    sampling_rate = board_shim.get_sampling_rate(int32(BoardIds.SYNTHETIC_BOARD),preset);
end

% prepare BrainFlow’s streaming session, allocate required resources
board_shim.prepare_session();

% add streamer
currentDateTime = datestr(now, 'yyyy-mm-dd_HH:MM:SS'); % Format as 'YYYYMMDD_HHMMSS'
fileName = ['file://eeg_rec_',currentDateTime,'.txt:w'];
board_shim.add_streamer(fileName, preset);

% start streaming thread, store data in internal ringbuffer
board_shim.start_stream(45000, '');
% Create a figure for plotting
fig = figure;
set(fig, 'CloseRequestFcn', @closeFigure); % Function to close the serial port after closing the figure
subplot(4,1,1);
h1 = animatedline('Color', 'b');
h1_error = animatedline('Color', 'r', 'Marker', 'o'); % For out-of-order data
title('Channel 1');
xlabel('Time');
ylabel('Value');
ax1 = gca;
% ---------------------------------------------------------------------
subplot(4,1,2);
h2 = animatedline('Color', 'b');
h2_error = animatedline('Color', 'r', 'Marker', 'o'); % For out-of-order data
title('Channel 2');
xlabel('Time');
ylabel('Value');
ax2 = gca;
% ---------------------------------------------------------------------
subplot(4,1,3);
h3 = animatedline('Color', 'b');
h3_error = animatedline('Color', 'r', 'Marker', 'o'); % For out-of-order data
title('Channel 3');
xlabel('Time');
ylabel('Value');
ax3 = gca;
% ---------------------------------------------------------------------
subplot(4,1,4);
h4 = animatedline('Color', 'b');
h4_error = animatedline('Color', 'r', 'Marker', 'o'); % For out-of-order data
title('Channel 4');
xlabel('Time');
ylabel('Value');
ax4 = gca;

lastQualityCheck = tic;
sFE = signalTimeFeatureExtractor(SampleRate=1000, SNR = true, SINAD = true, THD = true);

eegQualityBuffer = [];
timeWindowInSeconds = 5;
timeWindow = timeWindowInSeconds / (24 * 3600); % MATLAB serial date number is in days
while true
    if demo == 1
        data = board_shim.get_current_board_data(200, preset); % The ganglion has a maximum of 200 Hz
        timestamps_row = data(17, :); 
        pkgs = 200; % pkgs to detect wrap around
    else
        dataInBuffer = board_shim.get_board_data_count(preset);
        data = board_shim.get_board_data(dataInBuffer, preset);
        timestamps_row = data(31, :);
        pkgs = 256;
    end

    for col = 1:size(data, 2)  % Plot first 4 channels
        packageid = data(1,col);
        timeNow = datenum(datetime('now')); % Used to print the serial value in real time
        
        if lastPackageId ~= -1 && mod(packageid - lastPackageId - 1, pkgs) ~= 0
            outoforder = outoforder + 1;
            addpoints(h1_error, timeNow, data(2,col));
            addpoints(h2_error, timeNow, data(3,col));
            addpoints(h3_error, timeNow, data(4,col));
            addpoints(h4_error, timeNow, data(5,col));
        else
            samples = samples + 1;
            timestamps = [timestamps; timestamps_row(col)]; % Save the ganglion board timestamps to calculate the sampling frequency
            eegQualityBuffer = [eegQualityBuffer; data(2, col), data(3, col), data(4, col), data(5,col)];
            addpoints(h1, timeNow, data(2,col));
            addpoints(h2, timeNow, data(3,col));
            addpoints(h3, timeNow, data(4,col));
            addpoints(h4, timeNow, data(5,col));
        end
        xlim(ax1, [timeNow - timeWindow, timeNow]); % Update the x-axis limits based on the latest time
        xlim(ax2, [timeNow - timeWindow, timeNow]);
        xlim(ax3, [timeNow - timeWindow, timeNow]);
        xlim(ax4, [timeNow - timeWindow, timeNow]);
        if toc(lastQualityCheck) >= 5
            eeg_quality = extract(sFE, eegQualityBuffer);
            % Log or display the results
            channel1 = eeg_quality(:,:,1);
            channel2 = eeg_quality(:,:,2);
            channel3 = eeg_quality(:,:,3);
            channel4 = eeg_quality(:,:,4);
            fprintf('============================================================================');
            fprintf('\nChannel1:\nSNR:\t %f\nSINAD:\t %f\nTHD:\t %f\n',channel1(:,1),channel1(:,2), channel1(:,3));
            fprintf('\nChannel2:\nSNR: %f\nSINAD: %f\nTHD: %f\n',channel2(:,1),channel2(:,2), channel2(:,3));
            fprintf('\nChannel3:\nSNR:\t %f\nSINAD:\t %f\nTHD:\t %f\n',channel3(:,1),channel3(:,2), channel3(:,3));
            fprintf('\nChannel4:\nSNR: %f\nSINAD: %f\nTHD: %f\n',channel4(:,1),channel4(:,2), channel4(:,3));
            fprintf('============================================================================\n');

            % Reset the buffer and timer
            eegQualityBuffer = [];
            lastQualityCheck = tic;
        end
        lastPackageId = packageid;
    end
    pause(0.001);
end

function closeFigure(src, ~)
    global samples;
    global s;
    global expectedSamples;
    global avgSampleTime;
    global fileName;
    global board_shim;
    global timestamps;
    % ---------------------------------------------------------------------
    if ~isempty(s) && isvalid(s) % I can't rerun the program without closing the serial port, just pressing stop does not close the port, which is the reason for this function
        delete(s);
    end

    % ---------------------------------------------------------------------
    totalElapsedTime = toc(avgSampleTime);
    averageSampleRate = samples / totalElapsedTime; % Matlab average sample rate

    % Calculate time differences and sampling frequency
    timeDiffs = diff(timestamps); % Time differences between consecutive samples
    avgTimeInterval = mean(timeDiffs); % Average time interval / Ganglion sample rate
    ganglionSampleRate = 1 / avgTimeInterval;
    
    expectedSamples = totalElapsedTime * ganglionSampleRate; % Expected number of samples 
    actualSamples = samples;
    lostSamples = expectedSamples - actualSamples; % Missing samples
    lossPercentage = (lostSamples / expectedSamples) * 100; % Percentage of lost samples
    % ---------------------------------------------------------------------
    % fprintf(fileID,['Runtime: ', num2str(totalElapsedTime),' seconds\n']);
    % fprintf(fileID,['Average Sample Rate: ', num2str(averageSampleRate), ' Hz\n']);
    % fprintf(fileID,['Expected Samples: ', num2str(expectedSamples),'\n']);
    % fprintf(fileID,['Actual Samples: ', num2str(actualSamples),'\n']);
    % fprintf(fileID,['Lost Samples: ', num2str(lostSamples)]);
    % fprintf(fileID,['\nData Loss Percentage: ', num2str(lossPercentage, '%.2f'), '%']);
    % ---------------------------------------------------------------------
    fprintf('\n============================================================================\n');
    disp(['Runtime: ', num2str(totalElapsedTime),' seconds']);
    disp(['Average Sample Rate GANGLION: ', num2str(ganglionSampleRate), ' Hz']);
    disp(['Average Sample Rate MATLAB: ', num2str(averageSampleRate), ' Hz']);
    disp(['Expected Samples: ', num2str(expectedSamples)]);
    disp(['Actual Samples: ', num2str(actualSamples)]);
    disp(['Lost Samples: ', num2str(lostSamples)]);
    disp(['Data Loss Percentage: ', num2str(lossPercentage, '%.2f'), '%']);
    fprintf('============================================================================\n');

    %disp(['Recording saved in: ',fileName]);
    % ---------------------------------------------------------------------
    board_shim.stop_stream(); % Stop streaming
    board_shim.release_session(); % Release session
    delete(src); % Figure
end
