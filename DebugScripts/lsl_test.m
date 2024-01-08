% Include LSL library
lib = lsl_loadlib();

% Look for a specific type of data stream on the network
% Replace 'EEG' with the type of your stream
result = {};
while isempty(result)
    result = lsl_resolve_byprop(lib, 'type', 'EEG'); 
    pause(1);
end

% Create a new inlet
inlet = lsl_inlet(result{1});

disp('Now receiving data...');
while true
    % Get data from the inlet
    [vec, ts] = inlet.pull_sample();
    
    % Process your data here
    % 'vec' is your data vector, 'ts' is the timestamp
    disp(['Timestamp: ', num2str(ts), ', Data: ', num2str(vec)]);
    
    % Pause for a short period to avoid overwhelming the console
    pause(0.1);
end
