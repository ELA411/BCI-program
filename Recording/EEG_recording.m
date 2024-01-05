
name = 'Pontus';
setting = 'Left_side_cluster_50_reps';
session = [name,'-', setting];
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
fileName = ['file://../Datasets/Brainflow/Brainflow_',session,'_EEG_',char(currentDateTime),'.txt:w'];
fileName2 = ['../Datasets/EEG/EEG_',session,'_',char(currentDateTime),'.txt'];

fileID = fopen(fileName2, "w");
board_shim.add_streamer(fileName, preset);
eegBuffer = []; % Buffer to store temporary values for data quality calculation
eegBufferProcessing = [];
col = 1;

board_shim.start_stream(10000, '');
% ---------------------------------------------------------------------
% Main loop
% ---------------------------------------------------------------------
labelTime = tic;
label = 0;
reps = 0;
% label_flag = true;
while true
    % ---------------------------------------------------------------------
    % Collect data
    % ---------------------------------------------------------------------
    dataInBuffer = board_shim.get_board_data_count(preset); % Check how many samples are in the buffer
    if dataInBuffer > 0
        data = board_shim.get_board_data(1, preset); % Take available packages and remove them from buffer

        ID = data(1,col);
        channel1 = data(2,col);
        channel2 = data(3,col);
        channel3 = data(4,col);
        channel4 = data(5,col);
        timestamp = data(14,col);
        % if label_flag
        if toc(labelTime) >= 4
            if reps == 50
                disp(['REP: ', num2str(reps), ' Dataset completed']);
                % disp([char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss')),' REP: ', num2str(reps), ' Dataset completed']);
                break;
            end

            if label == 1
                disp(['REP: ', num2str(reps + 1),' CLOSE']);
                % disp([char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss')),' REP: ', num2str(reps + 1),' CLOSE']);
            end
            if label == 0
                disp(['REP: ', num2str(reps + 1),' REST']);
                % disp([char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss')),' REP: ', num2str(reps + 1),' REST']);
                reps = reps + 1;
            end
            label = ~label; % Toggle label
            % label_flag = false;
            labelTime = tic; % Reset timer

        end

        fprintf(fileID, "%f %f %f %f %f %f %f\n", channel1, channel2, channel3, channel4, label, ID, timestamp);
    end
end
fclose(fileID);
board_shim.stop_stream();
board_shim.release_all_sessions();