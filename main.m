% Script Name: stream_ganglion_sample.m
% Author: Pontus Svensson
% Date: 2023-12-03
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
try
    board_shim.release_all_sessions();
catch
    fprintf("No session\n");
end
clc, clear;

% ---------------------------------------------------------------------
% Brainflow
% ---------------------------------------------------------------------
% BoardShim.set_log_file('brainflow.log');
% BoardShim.enable_dev_board_logger();
demo = 1;

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
    % params.mac_address = 'F8:89:D2:68:8D:54';

    % ---------------------------------------------------------------------
    % Create the board_shim class
    % ---------------------------------------------------------------------
    board_shim = BoardShim(int32(BoardIds.GANGLION_BOARD), params);
    board_desc = board_shim.get_board_descr(int32(BoardIds.GANGLION_BOARD), preset);
    board_preset = board_shim.get_board_presets(int32(BoardIds.GANGLION_BOARD));
    pkgs = 200; % pkgs to detect wrap around
else
    % ---------------------------------------------------------------------
    % If Dummy data is used
    % ---------------------------------------------------------------------
    board_shim = BoardShim(int32(BoardIds.SYNTHETIC_BOARD), params);
    pkgs = 256; % Synthetic board max pkgs
end

% ---------------------------------------------------------------------
% prepare BrainFlow’s streaming session, allocate required resources
% ---------------------------------------------------------------------
board_shim.prepare_session();

% ---------------------------------------------------------------------
% add streamer
% ---------------------------------------------------------------------
currentDateTime = datestr(now, 'yyyy-mm-dd_HH:MM:SS'); % Format as 'YYYYMMDD_HHMMSS'
fileName = ['file://eeg_rec_',currentDateTime,'.txt:w'];
board_shim.add_streamer(fileName, preset);

% ---------------------------------------------------------------------
% start streaming thread, store data in internal ringbuffer
% ---------------------------------------------------------------------
board_shim.start_stream(45000, '');
delete(gcp('nocreate'))
poolobj = parpool('Threads',4);

% Create a queue to send values for processing
emg_queue = parallel.pool.PollableDataQueue;
eeg_queue = parallel.pool.PollableDataQueue;

EMG_worker = parfeval(poolobj,@emg_sampling, 0, emg_queue);
EEG_worker = parfeval(poolobj,@eeg_sampling, 0, eeg_queue, board_shim);

starttime = tic;
starttime_eeg = tic;
dataRaw=[];
dataRawEEG = [];
% ---------------------------------------------------------------------
while true    % Implement processing
    % Data supports vector, scalar, matrix, array, string, character vector
    [dataRaw, msg_received] = poll(emg_queue, 0);
    [dataRawEEG, msg_received_eeg] = poll(eeg_queue, 0);
    if msg_received_eeg
        fprintf("EEG_ Received: %d \n", toc(starttime_eeg));
    end
    if msg_received

        fprintf("Message received after %d, starting processing\n",toc(starttime));
    else
        fprintf("timeout receiving message at %.3g seconds\n", toc(starttime));
    end
    starttime = tic;
    starttime_eeg = tic;
end

% ---------------------------------------------------------------------

function eeg_sampling(eeg_queue, board_shim)
eegBuffer = []; % Buffer to store temporary values for data quality calculation
eegBufferOffline = []; % Buffer to store temporary values for data quality calculation

% ---------------------------------------------------------------------
% Package integrity
% ---------------------------------------------------------------------
outoforder = 0; % Tracks the samples out of order
samples = 0; % Total number of samples
lastPackageId = -1; % Used to check for packages wrap around, and if package is in order
packageid = -1; % Current sample


label = 0;
previousSample = -1;
slidingWindow = tic;
% ---------------------------------------------------------------------
% Main loop
% ---------------------------------------------------------------------
while true
    if demo == 1
        % ---------------------------------------------------------------------
        % Collect data
        % ---------------------------------------------------------------------
        dataInBuffer = board_shim.get_board_data_count(preset); % Check how many samples are in the buffer
        if dataInBuffer ~= 0
            data = board_shim.get_board_data(dataInBuffer, preset); % Take available packages and remove them from buffer
        end
        timestamps_row = data(14, :);
    else
        % ---------------------------------------------------------------------
        % Collect data
        % ---------------------------------------------------------------------
        dataInBuffer = board_shim.get_board_data_count(preset); % Check available samples in buffer
        if dataInBuffer ~=0
            data = board_shim.get_board_data(dataInBuffer, preset);
        end
        timestamps_row = data(31, :);
    end

    % ---------------------------------------------------------------------
    % Iterate through all the packages received
    % ---------------------------------------------------------------------
    for col = 1:size(data,2)
        packageid = data(1,col);
        channel1 = data(2,col);
        channel2 = data(3,col);
        channel3 = data(4,col);
        channel4 = data(5,col);
        timestamp = data(14,col);

        eegBuffer = [eegBuffer; channel1, channel2, channel3, channel4, label, packageid, timestamp];
        eegBufferOffline = [eegBufferOffline; channel1, channel2, channel3, channel4, label, packageid, timestamp];

        if col == 1
            previousSample = -1;
        end
        % ---------------------------------------------------------------------
        % Check so that the packages are in order
        % ---------------------------------------------------------------------
        if previousSample ~= -1 && ~(timestamps_row(:, col) >= timestamps_row(:, previousSample))
            outoforder = outoforder + 1;
        else
            % ---------------------------------------------------------------------
            % Increase samples, save the timestamp, and store values in temporary qualityBuffer
            % ---------------------------------------------------------------------
            samples = samples + 1;
            if toc(slidingWindow)>=0.10
                send(eeg_queue, eegBuffer);
                eegBuffer = [];
                slidingWindow = tic;
            end
        end
        previousSample = col;
    end
    pause(0.01); % Give matlab a chance to plot the values
end
end

% ---------------------------------------------------------------------

function process_eeg_data()
end
% ---------------------------------------------------------------------

function emg_sampling(emg_queue)
% ---------------------------------------------------------------------
s = [];
try
    if isempty(s)
        s = serialport("/dev/ttyACM0", 115200); % Serial port
    else
        delete(s);
        s = serialport("/dev/ttyACM0", 115200); % Serial port
    end
catch e
    fprintf("Error initializing serial port: %s\n", e.message);
    return; % Exit the function if an error occurs
end
% ---------------------------------------------------------------------
% currentDateTime = datestr(now, 'yyyy-mm-dd_HH:MM:SS'); % Add new name for each run automatically
% fileName = ['emg_rec_',currentDateTime,'.txt'];
% fileID = fopen(fileName, "w");
% ---------------------------------------------------------------------
emgDataBuffer = [];
emgDataBufferOffline = [];
% ---------------------------------------------------------------------
outoforder = 0; % Tracks the samples out of order
samples = 0; % Total number of samples
lastPackageId = -1; % Used to check for packages wrap around
packageid = -1; % Current sample
lastComputationTime = tic; % Timer for 5-second interval
% Read and plot the data continuously
while true
    data = readline(s); % Read one line of data
    % ---------------------------------------------------------------------
    splitData = strsplit(data, ' '); % Split the data by spaces and parse the first four values
    % ---------------------------------------------------------------------
    if length(splitData) >= 5 % If the split was successful or, the package is not corrupt
        adc1 = str2double(splitData{1}); % Channel 1
        adc2 = str2double(splitData{2}); % Channel 2
        label = str2double(splitData{3}); % Label
        packageid = str2double(splitData{4}); % id
        timestamp = str2double(splitData{5}); % timestamp
        % ---------------------------------------------------------------------
        if ~isnan(adc1) && ~isnan(adc2) && ~isnan(packageid) && ~isnan(label) && ~isnan(timestamp)
            emgDataBuffer = [emgDataBuffer; adc1, adc2, label, packageid, timestamp];
            emgDataBufferOffline = [emgDataBufferOffline; adc1, adc2, label, packageid, timestamp];

            % The id of each package wraps around at 1000
            if lastPackageId ~= -1 && mod(packageid - lastPackageId - 1, 1000) ~= 0
                outoforder = outoforder + 1; % Is the samples out of order
            else
                samples = samples + 1; % Regular sample
                if toc(lastComputationTime) >= 0.25
                    send(emg_queue, emgDataBuffer);
                    emgDataBuffer = [];
                    lastComputationTime = tic;
                end

            end
            lastPackageId = packageid; % Update the lastPackage
        end
    else
        outoforder = outoforder + 1; % Is the samples out of order
    end
end
end
