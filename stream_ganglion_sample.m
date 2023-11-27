% redirect logger from stderr to file, can be called any time
BoardShim.set_log_file('brainflow.log');
% enable BrainFlow logger with LEVEL_TRACE
BoardShim.enable_dev_board_logger();

% BoardShim class to communicate with a board 
% Create BoardShim object
params = BrainFlowInputParams();
% Change to this when using real hardware BoardIds.GANGLION_NATIVE_BOARD
board_shim = BoardShim(int32(BoardIds.SYNTHETIC_BOARD), params);
preset = int32(BrainFlowPresets.DEFAULT_PRESET);

% prepare BrainFlow’s streaming session, allocate required resources
board_shim.prepare_session();

% add streamer 
board_shim.add_streamer('file://data_default.csv:w', preset);

% start streaming thread, store data in internal ringbuffer 
board_shim.start_stream(45000, '');
pause(5);

% stop streaming thread, doesnt release other resources
board_shim.stop_stream();

% get latest datapoints, doesnt remove it from internal buffer
data = board_shim.get_current_board_data(10, preset);
disp(data);

% release session
board_shim.release_session();