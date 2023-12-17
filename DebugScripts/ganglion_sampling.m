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
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HHmmss'); % Format as 'YYYYMMDD_HHMMSS'
fileName = ['file://Datasets/Brainflow/Brainflow_',session,'_EEG_',char(currentDateTime),'.txt:w'];
board_shim.add_streamer(fileName, preset);

% ---------------------------------------------------------------------
% start streaming thread, store data in internal ringbuffer
% ---------------------------------------------------------------------
bufferSize = 10000;
board_shim.start_stream(bufferSize, '');
eegBuffer = []; % Buffer to store temporary values for data quality calculation
eegBufferProcessing = [];
% ---------------------------------------------------------------------
% Package integrity
% ---------------------------------------------------------------------
outoforder = 0; % Tracks the samples out of order
samples = 0; % Total number of samples
oldData = zeros(15,25);
% ---------------------------------------------------------------------
% Main loop
sameData = 0;
% ---------------------------------------------------------------------
slidingWindow = tic;
while true
    % ---------------------------------------------------------------------
    % Collect data
    % ---------------------------------------------------------------------
    dataInBuffer = board_shim.get_board_data_count(preset); % Check how many samples are in the buffer
    if dataInBuffer > 0
        samples = samples + 1;
        data = board_shim.get_board_data(1, preset);
        % send(EEG_main_queue, ['Samples in buffer: ', dataInBuffer]);
        % send(EEG_main_queue, "Data read from ganglion");
        % ---------------------------------------------------------------------
        % Iterate through all the packages received
        % ---------------------------------------------------------------------
        % for col = 1:size(data,2)
        packageid = data(1,1);
        channel1 = data(2,1);
        channel2 = data(3,1);
        channel3 = data(4,1);
        channel4 = data(5,1);
        timestamp = data(14,1);

        eegBuffer = [eegBuffer; channel1, channel2, channel3, channel4, packageid, timestamp];
        eegBufferProcessing = [eegBufferProcessing; channel1, channel2, channel3, channel4];

        % ---------------------------------------------------------------------
        % Check so that the packages are in order
        % ---------------------------------------------------------------------

        % ---------------------------------------------------------------------
        % Increase samples, save the timestamp, and store values in temporary qualityBuffer
        % ---------------------------------------------------------------------
        if toc(slidingWindow)>=0.25
            % send(EEG_processing_queue, eegBufferProcessing);
            % send(EEG_save_queue, eegBuffer);
            % send(EEG_main_queue, ['Number of samples for 250 ms ', size(eegBufferProcessing, 1)]);
            disp(size(eegBufferProcessing, 1));
            eegBuffer = [];
            eegBufferProcessing = [];
            slidingWindow = tic;
        end
        % end

    end
end