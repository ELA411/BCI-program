% Script Name: EEG_worker.m
% Author: Pontus Svensson, Viktor Eriksson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% This script performs all signal acquisition from the ganglion board using
% brainflow api
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Init brainflow
try
    board_shim.release_session;
catch
    fprintf("No session\n");
end
clear;
% ---------------------------------------------------------------------
params = BrainFlowInputParams();
preset = int32(BrainFlowPresets.DEFAULT_PRESET);

% ---------------------------------------------------------------------
% Specify the serialport and mac address for brainflow
% ---------------------------------------------------------------------
params.serial_port = 'COM9';

% ---------------------------------------------------------------------
% Create the board_shim class
% ---------------------------------------------------------------------
board_shim = BoardShim(int32(BoardIds.GANGLION_BOARD), params);

% ---------------------------------------------------------------------
% prepare BrainFlow’s streaming session, allocate required resources
% ---------------------------------------------------------------------
board_shim.prepare_session();
name = 'Debugging';
setting = 'Run';
session = [name,'-', setting];
% ---------------------------------------------------------------------
% add streamer
% ---------------------------------------------------------------------
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HHmmss'); % Format as 'YYYYMMDD_HHMMSS'
fileName = ['file://Datasets/Brainflow/Brainflow_',session,'_EEG_',char(currentDateTime),'.txt:w'];
board_shim.add_streamer(fileName, preset);
eegBuffer = []; % Buffer to store temporary values for data quality calculation
eegBufferProcessing = [];
col = 1;

board_shim.start_stream(10000, '');

% ---------------------------------------------------------------------
% Main loop
% ---------------------------------------------------------------------
overlapSamples = round(0.025 * 200); 
prevVoltage = []; % Initialize an array to store the overlapping data
firstIteration = true;
overSampling = false;
samples = 0;
threshold = 50;
totalSamples = 0;
packetLoss = 0;

while true

    dataInBuffer = board_shim.get_board_data_count(preset); % Check how many samples are in the buffer
    % runtime = toc;
    if dataInBuffer > 0
        fprintf("Running\n");
        data = board_shim.get_board_data(1, preset); % Take latest available packages and remove them from buffer
        samples = samples + 1;
        totalSamples = totalSamples + 1;
        packageid = data(1,col);
        channel1 = data(2,col);
        channel2 = data(3,col);
        channel3 = data(4,col);
        channel4 = data(5,col);
        timestamp = data(14,col);

        eegBuffer = [eegBuffer; channel1, channel2, channel3, channel4, packageid, timestamp];

        if overSampling
            eegBufferProcessing = [prevVoltage; eegBufferProcessing; channel1, channel2, channel3, channel4];
            overSampling = false;
        else
            eegBufferProcessing = [eegBufferProcessing; channel1, channel2, channel3, channel4];
        end

        if samples >= threshold
            sampleRate = 1/mean(diff(eegBuffer(:,6)));
            packageIds = eegBuffer(:, 5); % Assuming 5th column contains package IDs
            for i = 4:2:length(packageIds) % Starting from the 4th element and checking every second element
                expectedNextId = mod(packageIds(i-2) - 100 + 1, 100) + 100; % Calculate the expected next ID with wrap-around
                if packageIds(i) ~= expectedNextId
                    fprintf("Package ID %d missing\n", expectedNextId);
                end
            end

            % Retain the last 25 ms of data in eegBufferProcessing for 50 ms total overlap
            if size(eegBufferProcessing, 1) > overlapSamples
                prevVoltage = eegBufferProcessing(end-overlapSamples+1:end, :);
                overSampling = true;
            else
                prevVoltage = [];
            end
            eegBuffer = [];
            eegBufferProcessing = [];
            samples = 0;

            if firstIteration
                threshold = 44;
                firstIteration = false;
            end
        end

    end
end
board_shim.stop_stream();
board_shim.release_all_sessions();
