% Create udpport object for specified local port
u = udpport("LocalPort", 12345);

% Set up the figure for plotting
figure;
hold on;

% Initialize a buffer for incoming data
buffer = "";

% Define the sampling rate (samples per second) - replace with your actual rate
samplingRate = 200; % Example value

% Calculate buffer size for a 5-second window
bufferSize = 5 * samplingRate;

% Initialize a buffer for EEG data
% Assuming 4 channels; adjust if different
eegBuffer = cell(1, 4); 

try
    while true
        % Read data from udpport
        if u.NumBytesAvailable > 0
            data = read(u, u.NumBytesAvailable, 'string');
            buffer = buffer + data;

            % Split buffer into lines (individual JSON messages)
            while contains(buffer, newline)
                [jsonMessage, buffer] = strtok(buffer, newline);

                try
                    % Parse JSON data
                    jsonData = jsondecode(jsonMessage);

                    % Check if the type of data is timeSeriesRaw
                    if isfield(jsonData, 'type') && strcmp(jsonData.type, 'timeSeriesRaw')
                        % Extract data array
                        newEegData = jsonData.data;

                        % Append new data to the eegBuffer
                        for i = 1:size(newEegData, 1)
                            eegBuffer{i} = [eegBuffer{i}, newEegData(i, :)];
                            if length(eegBuffer{i}) > bufferSize
                                eegBuffer{i} = eegBuffer{i}(end-bufferSize+1:end);
                            end
                        end

                        % Plotting
                        clf; % Clear current figure
                        for i = 1:length(eegBuffer)
                            subplot(length(eegBuffer), 1, i);
                            plot(linspace(0, 5, length(eegBuffer{i})), eegBuffer{i});
                            title(['Channel ', num2str(i)]);
                            xlabel('Time (s)');
                            xlim([0 5]); % 5-second window
                        end
                        drawnow; % Update the plot
                    end
                catch
                    % If JSON decoding fails, do nothing and wait for more data
                end
            end
        end
    end
catch ME
    % Display error message
    disp(getReport(ME, 'extended'));
end
