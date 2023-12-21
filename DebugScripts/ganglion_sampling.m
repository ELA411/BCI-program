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
fileName = 'file://Brainflow_EEG_.txt:w';
board_shim.add_streamer(fileName, preset);

% ---------------------------------------------------------------------
% start streaming thread, store data in internal ringbuffer
% ---------------------------------------------------------------------
bufferSize = 10000;
board_shim.start_stream(bufferSize, '');
eegBuffer = []; % Buffer to store temporary values for data quality calculation
eegBufferProcessing = [];
overlapSamples = round(0.025 * 200);
% ---------------------------------------------------------------------
% Package integrity
% ---------------------------------------------------------------------
outoforder = 0; % Tracks the samples out of order
samples = 0; % Total number of samples
oldData = zeros(15,25);
% ---------------------------------------------------------------------
% Main loop
sameData = 0;
prevVoltage = [];
col = 1;
firstIteration = true;
threshold = 50;
overSampling = false;
% ---------------------------------------------------------------------
slidingWindow = tic;
while true
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

        % eegBuffer = [eegBuffer; channel1, channel2, channel3, channel4, packageid, timestamp];
        if overSampling
            eegBufferProcessing = [prevVoltage; eegBufferProcessing; channel1, channel2, channel3, channel4, timestamp];
            overSampling = false;
        else
            eegBufferProcessing = [eegBufferProcessing; channel1, channel2, channel3, channel4, timestamp];
        end

        if samples >= threshold
            % Retain the last 25 ms of data in eegBufferProcessing for overlap
            if size(eegBufferProcessing, 1) > overlapSamples
                prevVoltage = eegBufferProcessing(end-overlapSamples+1:end, :);
                overSampling = true;
            else
                prevVoltage = [];
            end
            % eegBuffer = [];
            eegBufferProcessing = [];
            % slidingWindow = tic;
            samples = 0;
            if firstIteration
                threshold = 45;
                firstIteration = false;
            end
        end
    end
end