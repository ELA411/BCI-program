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
function EEG_worker(EEG_processing_queue, EEG_save_queue, EEG_main_queue, session, debug)
EEG_worker_queue = parallel.pool.PollableDataQueue;
send(EEG_main_queue, EEG_worker_queue);
% ---------------------------------------------------------------------
% Init brainflow
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

% Wait for start command
send(EEG_main_queue, 'ready');
while true
    [trigger, flag] = poll(EEG_worker_queue);
    if flag
        if strcmp(trigger, 'start')
            send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')), ' EEG Worker, receieved start command']);
            break;
        end
    end
end
% ---------------------------------------------------------------------
% Main loop
% ---------------------------------------------------------------------
overlapSamples = round(0.025 * 200); % Assuming Fs is your sampling frequency

prevVoltage = []; % Initialize an array to store the overlapping data
firstIteration = true;
overSampling = false;
samples = 0;
threshold = 50;
runtime = 0;
totalSamples = 0;
packetLoss = 0;

while true
    % ---------------------------------------------------------------------
    % Collect data
    % ---------------------------------------------------------------------
    [trigger ,flag] = poll(EEG_worker_queue, 0);
    if flag
        if strcmp(trigger, 'stop')
            send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')), ' EEG Worker, receieved stop command']);
            break;
        end
    end
    if samples == 0
        runtime = tic;
    end
    dataInBuffer = board_shim.get_board_data_count(preset); % Check how many samples are in the buffer
    if dataInBuffer > 0
        
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
            % Assign the sampling time to the last place in the matrix for
            % response time calculation
            samplingtime = toc(runtime)*1000;
            
            eegBufferProcessing = [eegBufferProcessing; samplingtime,0,0,0];
            send(EEG_processing_queue, eegBufferProcessing);
            send(EEG_save_queue, eegBuffer);
            sampleRate = 1/mean(diff(eegBuffer(:,6)));

            packageIds = eegBuffer(:, 5); % Assuming 5th column contains package IDs
            for i = 4:2:length(packageIds) % Starting from the 4th element
                if i-2 >= 1 && i <= length(packageIds)
                    expectedNextId = mod(packageIds(i-2) - 100 + 1, 100) + 100; % Calculate expected next ID with wrap-around
                    if packageIds(i) ~= expectedNextId
                        packetLoss = packetLoss + 1;
                        send(EEG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EEG Worker, Lost sample: ', num2str(expectedNextId)]);
                    end
                else
                    send(EEG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EEG Worker, Index out of bounds at i: ', num2str(i)]);
                    break;
                end
            end

            if debug
                % send(EEG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EEG_Worker: Sending samples to processing: ', num2str(size(eegBufferProcessing, 1))]);
                % send(EEG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EEG Worker, sampleRate: ', num2str(sampleRate), ' PacketLoss: ', num2str(packetLoss), ' PacketLoss %: ', num2str((packetLoss/totalSamples)*100)]);
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
                threshold = 45; % Needs to be even since the packages are duplicates and it takes unecessary amount of time to implement a check for that
                firstIteration = false;
            end
        end
    end
end
send(EEG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EEG Worker, sampleRate: ', num2str(sampleRate), ' PacketLoss: ', num2str(packetLoss), ' PacketLoss %: ', num2str((packetLoss/totalSamples)*100)]);
board_shim.stop_stream();
board_shim.release_all_sessions();
end