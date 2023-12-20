% Script Name: EEG_worker.m
% Author: Pontus Svensson
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
slidingWindow = tic;
samples = 0;
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
    dataInBuffer = board_shim.get_board_data_count(preset); % Check how many samples are in the buffer
    if dataInBuffer > 0
        data = board_shim.get_board_data(1, preset); % Take available packages and remove them from buffer
        samples = samples + 1;
        packageid = data(1,col);
        channel1 = data(2,col);
        channel2 = data(3,col);
        channel3 = data(4,col);
        channel4 = data(5,col);
        timestamp = data(14,col);

        eegBuffer = [eegBuffer; channel1, channel2, channel3, channel4, packageid, timestamp];
        eegBufferProcessing = [eegBufferProcessing; channel1, channel2, channel3, channel4];

        if toc(slidingWindow)>=0.1
            % if samples >= 50
            send(EEG_processing_queue, eegBufferProcessing);
            send(EEG_save_queue, eegBuffer);
            if debug
                send(EEG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EEG_Worker: Sending samples to processing: ', num2str(size(eegBufferProcessing, 1))]);
            end
            eegBuffer = [];
            eegBufferProcessing = [];
            slidingWindow = tic;
            samples = 0;
        end
    end
end
board_shim.stop_stream();
board_shim.release_all_sessions();
end