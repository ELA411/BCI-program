clc;clear, close all;
% BoardShim class to communicate with a board
BoardShim.set_log_file('brainflow.log');
BoardShim.enable_dev_board_logger();
s = serialport("/dev/ttyACM1", 115200);

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
try
    while true
        %pause(0.01);

        % Get the latest datapoints (4x10 matrix)
        eeg_data = board_shim.get_current_board_data(200, preset);

        % Clear the current figure
        clf;

        for j = 1:100
            emg_data = readline(s);
            splitNew =split(emg_data,' ');   
            emg_channel1 = str2double(splitNew(1,:));
            emg_channel2 = str2double(splitNew(2,:));
            timestamp = str2double(splitNew(3,:));
            emg_data_print(1,j) = emg_channel1;
            emg_data_print(2,j) = emg_channel2;
            emg_data_print(3,j) = timestamp;            
        end


        % Plot first 4 channels
        for i = 1:6 % Iterate through each channel
    
            subplot(6, 1, i); % Create a subplot for each channel
            if i < 5
                plot(eeg_data(i, :)); % Plot the data of the current channel
            elseif i == 5
                plot(emg_data_print(1,:));
            elseif i == 6
                plot(emg_data_print(2,:));
            end
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
