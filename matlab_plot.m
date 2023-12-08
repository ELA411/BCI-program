% Script Name: matlab_plot.m
% Author: Pontus Svensson
% Date: 2023-12-01
% Version: 1.0.0
% License:
%
% Description:
% This script reads the serial input and provides a real-time plot of
% values.
% NOTE: The packages are almost never out of order, but instead the lost
% samples probably depends on the serieal read not being able to parse
% correctly.
% ---------------------------------------------------------------------
%
% ---------------------------------------------------------------------
clc,clear, close all;
% ---------------------------------------------------------------------
% Globals is needed because of the end function, it can't reach them
% otherwise
global expectedSamples;
global outoforder;
global s;
global samples;
global avgSampleTime;
global fileID;
global fileName;
global timestamps;
global wraps;
global packageid;
% ---------------------------------------------------------------------
try
    s = serialport("/dev/ttyACM0", 115200); % Serial port
catch
    fprintf("Port open alread\n");
    delete(s)
    s = serialport("/dev/ttyACM0", 115200); % Serial port
end
    % ---------------------------------------------------------------------
currentDateTime = datestr(now, 'yyyy-mm-dd_HH:MM:SS'); % Add new name for each run automatically
fileName = ['emg_rec_',currentDateTime,'.txt'];
fileID = fopen(fileName, "w");
% ---------------------------------------------------------------------
label = 0;
badSplit = 0;
emgDataBuffer = [];
timestamps = [];
lastComputationTime = tic; % Timer for 5-second interval
% ---------------------------------------------------------------------
avgSampleTime = tic; % Variable to calculate average sample rate
outoforder = 0; % Tracks the samples out of order
samples = 0; % Total number of samples
lastPackageId = -1; % Used to check for packages wrap around
packageid = -1; % Current sample
% ---------------------------------------------------------------------
fig = figure;
% ---------------------------------------------------------------------
set(fig, 'CloseRequestFcn', @closeFigure); % Function to close the serial port after closing the figure
subplot(1,1,1);
% plot();

h1 = animatedline('Color', 'g');
h2 = animatedline('Color','r');
h3 = animatedline('Color','b');
h1_error = animatedline('Color', 'r', 'Marker', 'o'); % For out-of-order data
title('Channel 1');
xlabel('Time');
ylabel('Value');
ax1 = gca;
% ---------------------------------------------------------------------
% subplot(2,1,2);
% h2 = animatedline('Color', 'b');
% h2_error = animatedline('Color', 'r', 'Marker', 'o'); % For out-of-order data
% title('Channel 2');
% xlabel('Time');
% ylabel('Value');
% ax2 = gca;
sFE = signalTimeFeatureExtractor(SampleRate=1000, SNR = true, SINAD = true, THD = true);
% ---------------------------------------------------------------------
% Define the time window in days (10 seconds in this case)
timeWindowinSeconds = 10;
timeWindow = timeWindowinSeconds / (24 * 3600); % MATLABs serial date number is in days
% ---------------------------------------------------------------------
% Read and plot the data continuously
while ishandle(fig)
    data = readline(s); % Read one line of data
    % ---------------------------------------------------------------------
    splitData = strsplit(data, ' '); % Split the data by spaces and parse the first four values
    % ---------------------------------------------------------------------
    if length(splitData) >= 4 % If the split was successful or, the package is not corrupt
        adc1 = str2double(splitData{1}); % Channel 1
        %adc2 = str2double(splitData{2}); % Channel 2
        label = str2double(splitData{2}); % Label
        packageid = str2double(splitData{3}); % id
        timestamp = str2double(splitData{4}); % timestamp
        % ---------------------------------------------------------------------
        if ~isnan(adc1) && ~isnan(packageid) && ~isnan(label) && ~isnan(timestamp)
            timeNow = datenum(datetime('now')); % Used to print the serial value in real time
            % emgDataBuffer = [emgDataBuffer; adc1, ]; % Store values for SNR; SINAD, and THD calculation
            timestamps = [timestamps; timestamp ]; % Store the timestamps to calculate the actual sample rate
            % ---------------------------------------------------------------------
            % Compute some signal quality metrics every 5 seconds
            % if toc(lastComputationTime) >= 5
            %     emg_quality = extract(sFE, emgDataBuffer);
            % 
            %     % Log or display the results
            %     channel1 = emg_quality(:,:,1);
            %     channel2 = emg_quality(:,:,2);
            %     fprintf('\nChannel1:\nSNR:\t %f\nSINAD:\t %f\nTHD:\t %f\n',channel1(:,1),channel1(:,2), channel1(:,3));
            %     fprintf('\nChannel2:\nSNR: %f\nSINAD: %f\nTHD: %f\n',channel2(:,1),channel2(:,2), channel2(:,3));
            % 
            %     % Reset the buffer and timer
            %     emgDataBuffer = [];
            %     lastComputationTime = tic;
            % end
            % ---------------------------------------------------------------------
            % The id of each package wraps around at 1000
            if lastPackageId ~= -1 && mod(packageid - lastPackageId - 1, 1000) ~= 0
                outoforder = outoforder + 1; % Is the samples out of order
                addpoints(h1_error, timeNow, adc1); % Marke the package with a red circle in the plot
                % addpoints(h2_error, timeNow, adc2);
            else
                if label == 1
                    addpoints(h1, timeNow, adc1); % Green
                elseif label == 2
                    addpoints(h2, timeNow, adc1); % Red
                else
                    addpoints(h3, timeNow, adc1); % Blue
                end
                % addpoints(h2, timeNow, adc2);
                fprintf(fileID,'%d %d %d %d\n',int32(adc1), int32(label), int32(packageid), int64(timestamp));
                samples = samples + 1; % Regular sample
            end
            % ---------------------------------------------------------------------
            xlim(ax1, [timeNow - timeWindow, timeNow]); % Update the x-axis limits based on the latest time
            % xlim(ax2, [timeNow - timeWindow, timeNow]);
            % ---------------------------------------------------------------------
            lastPackageId = packageid; % Update the lastPackage
        end
    else
        badSplit = badSplit + 1;
    end
end
% ---------------------------------------------------------------------
function closeFigure(src, ~)
    % Global variables are used since attaching each variable to the
    % figure introduces too much overhead, causing bad performance
    global samples;
    global s;
    global expectedSamples;
    global avgSampleTime;
    global fileID;
    global fileName;
    global timestamps;
    % ---------------------------------------------------------------------
    if ~isempty(s) && isvalid(s) % I can't rerun the program without closing the serial port, just pressing stop does not close the port, which is the reason for this function
        delete(s);
    end

    % ---------------------------------------------------------------------
    totalElapsedTime = toc(avgSampleTime); % Time from starting the script to now
    averageSampleRate = samples / totalElapsedTime; % Matlab receive time

    % Calculate time differences and sampling frequency
    timeDiffs = diff(timestamps); % Time differences between consecutive samples
    avgTimeInterval = mean(timeDiffs); % Average time interval

    expectedSamples = totalElapsedTime * avgTimeInterval; % Calculate the expected number of samples from PICO sample rate
    actualSamples = samples; % Packages not out of order
    lostSamples = expectedSamples - actualSamples;
    lossPercentage = (lostSamples / expectedSamples) * 100; % Percentage of lost samples
    % ---------------------------------------------------------------------
    % Write to file
    % fprintf(fileID,['Runtime: ', num2str(totalElapsedTime),' seconds\n']);
    % fprintf(fileID,['Average Sample Rate: ', num2str(averageSampleRate), ' Hz\n']);
    % fprintf(fileID,['Expected Samples: ', num2str(expectedSamples),'\n']);
    % fprintf(fileID,['Actual Samples: ', num2str(actualSamples),'\n']);
    % fprintf(fileID,['Lost Samples: ', num2str(lostSamples)]);
    % fprintf(fileID,['\nData Loss Percentage: ', num2str(lossPercentage, '%.2f'), '%']);
    % ---------------------------------------------------------------------
    % Write to console
    disp(['Runtime: ', num2str(totalElapsedTime),' seconds']);
    disp(['Average Sample Rate PICO: ', num2str(avgTimeInterval), ' Hz']);
    disp(['Average Sample Rate MATLAB: ', num2str(averageSampleRate), ' Hz']);
    disp(['Expected Samples: ', num2str(expectedSamples)]);
    disp(['Actual Samples: ', num2str(actualSamples)]);
    disp(['Lost Samples: ', num2str(lostSamples)]);
    disp(['Data Loss Percentage: ', num2str(lossPercentage, '%.2f'), '%']);
    disp(['Recording saved in: ',fileName]);
    % ---------------------------------------------------------------------
    if ~isempty(fileID) && fileID ~= -1
        fclose(fileID); % Close file
    end
    delete(src); % Delete the figure and end the program
end

