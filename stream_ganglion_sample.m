% Script Name: stream_ganglion_sample.m
% Author: Pontus Svensson
% Date: 2023-12-03
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------
clc;clear;
global samples;
global outoforder;
global s;
global expectedSamples;
global avgSampleTime;
global board_shim;
global fileName;
global timestamps;
global board_shim;
global fileID;
% ---------------------------------------------------------------------
demo = 1;

% ---------------------------------------------------------------------
% Signal quality
% ---------------------------------------------------------------------
sFE = signalTimeFeatureExtractor(SampleRate=200, SNR = true, SINAD = true, THD = true);
eegQualityBuffer = []; % Buffer to store temporary values for data quality calculation
lastQualityCheck = tic; % Timer for computing sFE every 5 seconds

% ---------------------------------------------------------------------
% Plotting
% ---------------------------------------------------------------------
timeWindowInSeconds = 10;
timeWindow = timeWindowInSeconds / (24 * 3600); % MATLAB serial date number is in days

% ---------------------------------------------------------------------
% Sampling
% ---------------------------------------------------------------------
avgSampleTime = tic; % Variable to calculate average sample rate
timestamps = []; % Buffer to store all the timestamps in order to calculate the true sample rate

% ---------------------------------------------------------------------
% Package integrity
% ---------------------------------------------------------------------
outoforder = 0; % Tracks the samples out of order
samples = 0; % Total number of samples
lastPackageId = -1; % Used to check for packages wrap around, and if package is in order
packageid = -1; % Current sample

% ---------------------------------------------------------------------
% Brainflow
% ---------------------------------------------------------------------
BoardShim.set_log_file('brainflow.log');
BoardShim.enable_dev_board_logger();

% ---------------------------------------------------------------------
% Init brainflow
% ---------------------------------------------------------------------
params = BrainFlowInputParams();
preset = int32(BrainFlowPresets.DEFAULT_PRESET);

% ---------------------------------------------------------------------
% Ganglion or Synthetic board
% ---------------------------------------------------------------------
if demo == 1
    % ---------------------------------------------------------------------
    % Specify the serialport and mac address for brainflow
    % ---------------------------------------------------------------------
    params.serial_port = '/dev/ttyACM1';
    params.mac_address = 'F8:89:D2:68:8D:54';

    % ---------------------------------------------------------------------
    % Create the board_shim class
    % ---------------------------------------------------------------------
    board_shim = BoardShim(int32(BoardIds.GANGLION_BOARD), params);
    board_desc = board_shim.get_board_descr(int32(BoardIds.GANGLION_BOARD), preset);
    board_preset = board_shim.get_board_presets(int32(BoardIds.GANGLION_BOARD));
else
    % ---------------------------------------------------------------------
    % If Dummy data is used
    % ---------------------------------------------------------------------
    board_shim = BoardShim(int32(BoardIds.SYNTHETIC_BOARD), params);
end

% ---------------------------------------------------------------------
% prepare BrainFlow’s streaming session, allocate required resources
% ---------------------------------------------------------------------
board_shim.prepare_session();

% ---------------------------------------------------------------------
% add streamer
% ---------------------------------------------------------------------
currentDateTime = datetime('now','Format', 'yyyy-mm-dd_HH:MM:SS'); % Format as 'YYYYMMDD_HHMMSS'
fileName = ['file://eeg_rec_',char(currentDateTime),'.txt:w'];
fileName2 = ['1eeg_rec_',char(currentDateTime),'.txt'];
board_shim.add_streamer(fileName, preset);
fileID = fopen(fileName2, "w");

% ---------------------------------------------------------------------
% start streaming thread, store data in internal ringbuffer
% ---------------------------------------------------------------------
board_shim.start_stream(45000, '');

% ---------------------------------------------------------------------
% Create a figure for plotting, and attach the figure handle to the close function
% ---------------------------------------------------------------------
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
save_data = [];
previousSample = -1;
label_timer = tic;
label_check = false;
label=0;
% ---------------------------------------------------------------------
% Main loop
% ---------------------------------------------------------------------
while true
    if toc(label_timer) >= 1
        if label_check == false
            label = 0;
        else
            label = 1;
        end
        label_check = ~label;
        label_timer = tic;
    end
    % ---------------------------------------------------------------------
    % Collect data
    % ---------------------------------------------------------------------
    dataInBuffer = board_shim.get_board_data_count(preset); % Check how many samples are in the buffer
    if dataInBuffer ~= 0
        data = board_shim.get_board_data(dataInBuffer, preset); % Take available packages and remove them from buffer
    end
    timestamps_row = data(14,:);
    pkgs = 200; % pkgs to detect wrap around


    % ---------------------------------------------------------------------
    % Iterate through all the packages received
    % ---------------------------------------------------------------------
    for col = 1:size(data,2)
        packageid = data(1,col);
        timeNow = datenum(datetime('now')); % Used to print the serial value in real time
        if col == 1
          previousSample = -1;
        end
        % ---------------------------------------------------------------------
        % Check so that the packages are in order
        % ---------------------------------------------------------------------
        if previousSample ~= -1 && ~(timestamps_row(:, col) >= timestamps_row(:, previousSample))
              outoforder = outoforder + 1;

              % ---------------------------------------------------------------------
              % Error plot
              % ---------------------------------------------------------------------
              addpoints(h1_error, timeNow, data(2,col));
              addpoints(h2_error, timeNow, data(3,col));
              addpoints(h3_error, timeNow, data(4,col));
              addpoints(h4_error, timeNow, data(5,col));
        else
            % ---------------------------------------------------------------------
            % Increase samples, save the timestamp, and store values in temporary qualityBuffer
            % ---------------------------------------------------------------------
            samples = samples + 1;
            % timestamps = [timestamps; timestamps_row(col)]; % Save the ganglion board timestamps to calculate the sampling frequency
            % eegQualityBuffer = [eegQualityBuffer; data(2, col), data(3, col), data(4, col), data(5,col)];
            fprintf(fileID,"%d %d %d %d %d %d %d\n",int32(data(2,col)),int32(data(3,col)),int32(data(4,col)),int32(data(5,col)), int32(label), int32(packageid), int32(data(14,col)));
            % ---------------------------------------------------------------------
            % EEG plot of the four channels
            % ---------------------------------------------------------------------
            addpoints(h1, timeNow, data(2,col));
            addpoints(h2, timeNow, data(3,col));
            addpoints(h3, timeNow, data(4,col));
            addpoints(h4, timeNow, data(5,col));
        end
        previousSample = col;
     end
    % ---------------------------------------------------------------------
    % Move the plot window
    % ---------------------------------------------------------------------
    xlim(ax1, [timeNow - timeWindow, timeNow]); % Update the x-axis limits based on the latest time
    xlim(ax2, [timeNow - timeWindow, timeNow]);
    xlim(ax3, [timeNow - timeWindow, timeNow]);
    xlim(ax4, [timeNow - timeWindow, timeNow]);

    % ---------------------------------------------------------------------
    % Calculate SNR, SINAD, and THD
    % ---------------------------------------------------------------------
    % if toc(lastQualityCheck) >= 5
    %     eeg_quality = extract(sFE, eegQualityBuffer);
    %     % ---------------------------------------------------------------------
    %     channel1 = eeg_quality(:,:,1);
    %     channel2 = eeg_quality(:,:,2);
    %     channel3 = eeg_quality(:,:,3);
    %     channel4 = eeg_quality(:,:,4);
    %     % ---------------------------------------------------------------------
    %     fprintf('============================================================================');
    %     fprintf('\nChannel1:\nSNR:\t %f\nSINAD:\t %f\nTHD:\t %f\n',channel1(:,1),channel1(:,2), channel1(:,3));
    %     fprintf('\nChannel2:\nSNR:\t %f\nSINAD:\t %f\nTHD:\t %f\n',channel2(:,1),channel2(:,2), channel2(:,3));
    %     fprintf('\nChannel3:\nSNR:\t %f\nSINAD:\t %f\nTHD:\t %f\n',channel3(:,1),channel3(:,2), channel3(:,3));
    %     fprintf('\nChannel4:\nSNR:\t %f\nSINAD:\t %f\nTHD:\t %f\n',channel4(:,1),channel4(:,2), channel4(:,3));
    %     fprintf('============================================================================\n');
    %
    %     % ---------------------------------------------------------------------
    %     % Reset the buffer and timer
    %     % ---------------------------------------------------------------------
    %     eegQualityBuffer = [];
    %     lastQualityCheck = tic;
    % endk
    % ---------------------------------------------------------------------
    % Update the lastPackageId
    % ---------------------------------------------------------------------
    pause(0.01); % Give matlab a chance to plot the values
end
% ---------------------------------------------------------------------


% ---------------------------------------------------------------------
% Function that runs when the figure is closed
% ---------------------------------------------------------------------
function closeFigure(src, ~)
% ---------------------------------------------------------------------
% Global variables declared since matlab gets way too slow if the are attached to the figure
% ---------------------------------------------------------------------
global samples;
global s;
global expectedSamples;
global avgSampleTime;
global fileName;
global board_shim;
global timestamps;
global outoforder;
global fileID;
% ---------------------------------------------------------------------
% Delete the serial port
% ---------------------------------------------------------------------
if ~isempty(s) && isvalid(s) % I can't rerun the program without closing the serial port, just pressing stop does not close the port, which is the reason for this function
    delete(s);
end

% ---------------------------------------------------------------------
% Calculate the runtime for the program
% % ---------------------------------------------------------------------
% totalElapsedTime = toc(avgSampleTime);
% averageSampleRate = samples / totalElapsedTime; % Matlab average sample rate
% 
% % ---------------------------------------------------------------------
% % Calculate time differences and sampling frequency
% % ---------------------------------------------------------------------
% timeDiffs = diff(timestamps); % Time differences between consecutive samples
% avgTimeInterval = mean(timeDiffs); % Average time interval / Ganglion sample rate
% ganglionSampleRate = 1 / avgTimeInterval;
% 
% % ---------------------------------------------------------------------
% % Calculate, #LostSamples, #LostSamples percentage, and expectedSamples
% % ---------------------------------------------------------------------
% expectedSamples = totalElapsedTime * ganglionSampleRate; % Expected number of samples
% actualSamples = samples;
% lostSamples = outoforder; % Missing samples
% lossPercentage = (lostSamples / expectedSamples) * 100; % Percentage of lost samples
% 
% % ---------------------------------------------------------------------
% % Add metrics to log file
% % ---------------------------------------------------------------------
% % fprintf(fileID,['Runtime: ', num2str(totalElapsedTime),' seconds\n']);
% % fprintf(fileID,['Average Sample Rate: ', num2str(averageSampleRate), ' Hz\n']);
% % fprintf(fileID,['Expected Samples: ', num2str(expectedSamples),'\n']);
% % fprintf(fileID,['Actual Samples: ', num2str(actualSamples),'\n']);
% % fprintf(fileID,['Lost Samples: ', num2str(lostSamples)]);
% % fprintf(fileID,['\nData Loss Percentage: ', num2str(lossPercentage, '%.2f'), '%']);
% 
% % ---------------------------------------------------------------------
% % Print metrics to console
% % ---------------------------------------------------------------------
% fprintf('\n============================================================================\n');
% disp(['Runtime: ', num2str(totalElapsedTime),' seconds']);
% disp(['Average Sample Rate GANGLION: ', num2str(ganglionSampleRate), ' Hz']);
% disp(['Average Sample Rate MATLAB: ', num2str(averageSampleRate), ' Hz']);
% disp(['Expected Samples: ', num2str(expectedSamples)]);
% disp(['Actual Samples: ', num2str(actualSamples)]);
% disp(['Lost Samples: ', num2str(lostSamples)]);
% disp(['Data Loss Percentage: ', num2str(lossPercentage, '%.2f'), '%']);
% %disp(['Recording saved in: ',fileName]);
% fprintf('============================================================================\n');

% ---------------------------------------------------------------------
% Release the brainflow session
% ---------------------------------------------------------------------
board_shim.stop_stream(); % Stop streaming
board_shim.release_session(); % Release session
if ~isempty(fileID) && fileID ~= -1
    fclose(fileID); % Close file
end
% ---------------------------------------------------------------------
% Delete the figure handle and end the program
% ---------------------------------------------------------------------
delete(src); % Figure
end
