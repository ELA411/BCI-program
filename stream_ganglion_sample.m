clc;clear;
% BoardShim class to communicate with a board
BoardShim.set_log_file('brainflow.log');
BoardShim.enable_dev_board_logger();
s = serialport("/dev/ttyACM0", 115200);
k = readline(s);
% Create BoardShim object
params = BrainFlowInputParams();
params.serial_port = '/dev/ttyACM0';
params.mac_address = 'F8:89:D2:68:8D:54';
% Change to this when using real hardware BoardIds.GANGLION_NATIVE_BOARD
board_shim = BoardShim(int32(BoardIds.GANGLION_BOARD), params);
preset = int32(BrainFlowPresets.DEFAULT_PRESET);
% Time stamp channel
% board_shim.get_timestamp_channel(int32(BoardIds.SYNTHETIC_BOARD), preset);
% prepare BrainFlow’s streaming session, allocate required resources
board_shim.prepare_session();

% add streamer
board_shim.add_streamer('file://data_default.csv:w', preset);

% start streaming thread, store data in internal ringbuffer
board_shim.start_stream(45000, '');

% Create a figure for plotting
figure;
hold on;

% Continuously acquire and plot data
figure; % Create a new figure for plotting
try
    while true
        %pause(0.01);

        % Get the latest datapoints (4x10 matrix)
        data = board_shim.get_current_board_data(100, preset);

        % Clear the current figure
        clf;

        % Plot first 4 channels
        for i = 1:4 % Iterate through each channel
            subplot(4, 1, i); % Create a subplot for each channel
            plot(data(i, :)); % Plot the data of the current channel
            title(['Channel ' num2str(i)]); % Add a title to each subplot
        end

        drawnow; % Update the plots

    end
catch ME
    disp('Error or interruption occurred. Stopping data acquisition...');
end

% After exiting the loop
board_shim.stop_stream(); % Stop streaming
board_shim.release_session(); % Release session
close; % Close the figure
