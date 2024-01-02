% Script Name: EMG_save.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% This script receieves the data read from the NI myDAQ and writes it to
% file
% ---------------------------------------------------------------------
function EMG_save(EMG_main_queue, session, debug)

EMG_save_queue = parallel.pool.PollableDataQueue;
send(EMG_main_queue, EMG_save_queue);
send(EMG_main_queue, 'ready');
pkdID = 0;
label = 0; % Initialize label
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HHmmss');
fileName = ['Datasets/EMG/EMG_', session, '_',char(currentDateTime), '.txt'];
fileID = fopen(fileName, "w");
while true
    [trigger, flag] = poll(EMG_save_queue, 0.1);
    if flag
        if strcmp(trigger, 'start')
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Save, receieved start command']);
            break;
        end
    end
end

% send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Starting save']);
% labelTime = tic; % Start timer for label switching
while true
    [rawData, msg_received] = poll(EMG_save_queue, 0);

    if msg_received
        if strcmp(rawData, 'stop')
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG save, stop command received. Closing file']);
            break;
        end
        if debug
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG save, writing ', num2str(size(rawData, 1)),' samples to file']);
            % send(EMG_main_queue, ['Saving ', num2str(size(rawData, 1)), ' samples']);
        end
        for i = 1:size(rawData, 1)

            % if toc(labelTime) >= 1
            %     label = mod(label + 1, 3); % Cycle through 0, 1, 2
            %     labelTime = tic; % Reset timer
            %     ends

            fprintf(fileID, "%f %f %f %f\n", rawData(i, 1), rawData(i, 2), pkdID, rawData(i, 3));
            pkdID = mod(pkdID + 1, 1000);
        end

    end
end
fclose(fileID); % Uncomment if there's a condition to exit the loop
end


