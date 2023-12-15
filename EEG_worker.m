% Script Name: EEG_worker.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------
function EEG_worker(EEG_processing_queue, EEG_save_queue)
% Description:
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
try
    board_shim.release_all_sessions();
catch
    fprintf("No session\n");
end

% ---------------------------------------------------------------------
% Init brainflow
% ---------------------------------------------------------------------
params = BrainFlowInputParams();
preset = int32(BrainFlowPresets.DEFAULT_PRESET);

% ---------------------------------------------------------------------
% Ganglion or Synthetic board
% ---------------------------------------------------------------------
% ---------------------------------------------------------------------
% Specify the serialport and mac address for brainflow
% ---------------------------------------------------------------------
params.serial_port = 'COM9';
% params.mac_address = 'F8:89:D2:68:8D:54';

% ---------------------------------------------------------------------
% Create the board_shim class
% ---------------------------------------------------------------------
board_shim = BoardShim(int32(BoardIds.GANGLION_BOARD), params);
% board_desc = board_shim.get_board_descr(int32(BoardIds.GANGLION_BOARD), preset);
% board_preset = board_shim.get_board_presets(int32(BoardIds.GANGLION_BOARD));
% pkgs = 200; % pkgs to detect wrap around


% ---------------------------------------------------------------------
% prepare BrainFlow’s streaming session, allocate required resources
% ---------------------------------------------------------------------
board_shim.prepare_session();

% ---------------------------------------------------------------------
% add streamer
% ---------------------------------------------------------------------
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HH_mm_ss'); % Format as 'YYYYMMDD_HHMMSS'
fileName = ['file://brainflow_eeg_rec_',char(currentDateTime),'.txt:w'];
board_shim.add_streamer(fileName, preset);

% ---------------------------------------------------------------------
% start streaming thread, store data in internal ringbuffer
% ---------------------------------------------------------------------
board_shim.start_stream(45000, '');
eegBuffer = []; % Buffer to store temporary values for data quality calculation

% ---------------------------------------------------------------------
% Package integrity
% ---------------------------------------------------------------------
outoforder = 0; % Tracks the samples out of order
samples = 0; % Total number of samples

label = 0;
slidingWindow = tic;
% ---------------------------------------------------------------------
% Main loop
% ---------------------------------------------------------------------
while true
    % ---------------------------------------------------------------------
    % Collect data
    % ---------------------------------------------------------------------
    dataInBuffer = board_shim.get_board_data_count(preset); % Check how many samples are in the buffer
    if dataInBuffer ~= 0
        data = board_shim.get_board_data(dataInBuffer, preset); % Take available packages and remove them from buffer
        send(EEG_main_queue, 'Data read from ganglion');
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
            samples = samples + 1;
    
            eegBuffer = [eegBuffer; channel1, channel2, channel3, channel4, packageid, timestamp];
    
            % ---------------------------------------------------------------------
            % Check so that the packages are in order
            % ---------------------------------------------------------------------
    
            % ---------------------------------------------------------------------
            % Increase samples, save the timestamp, and store values in temporary qualityBuffer
            % ---------------------------------------------------------------------
            if toc(slidingWindow)>=0.25
                send(EEG_main_queue, 'Sending data for processing and saving');
                send(EEG_processing_queue, eegBuffer);
                send(EEG_save_queue, eegBuffer);
                eegBuffer = [];
                slidingWindow = tic;
            end
        end
        
        if samples ~= size(data,2)
            outoforder = outoforder + 1;
        end
    end
end
end