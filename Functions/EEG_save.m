% Script Name: EEG_save.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------
function EEG_save(EEG_main_queue, session)
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HHmmss');
fileName = ['Datasets/EEG/EEG_',session,'_',char(currentDateTime),'.txt'];
fileID = fopen(fileName, "w");
EEG_save_queue = parallel.pool.PollableDataQueue;
send(EEG_main_queue, EEG_save_queue);
% Wait for command to start
start = false;
label = 0; % Initialize label

send(EEG_main_queue, 'ready')
while true
    [trigger, flag] = poll(EEG_save_queue, 0.1);
    if flag
        if strcmp(trigger, 'start')
            send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')), ' EEG Save, receieved start command']);
            break;
        end
    end
end
labelTime = tic; % Start timer for label switching
while true % Add a condition to break this loop if necessary
    [rawData, msg_received] = poll(EEG_save_queue, 0);
    % Check class of message
    if msg_received
        if strcmp(rawData, 'stop')
            send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')), ' EEG Save, receieved stop command. Closing file']);
            break;
        end
        channel1 = rawData(:,1);
        channel2 = rawData(:,2);
        channel3 = rawData(:,3);
        channel4 = rawData(:,4);
        ID = rawData(:,5);
        timestamp = rawData(:,6);

        for i = 1:size(rawData, 1)
            if toc(labelTime) >= 1
                label = ~label; % Toggle label
                labelTime = tic; % Reset timer
            end

            fprintf(fileID, "%f %f %f %f %f %f %f\n", channel1(i), channel2(i), channel3(i), channel4(i), label, ID(i), timestamp(i));
        end
    end
end
fclose(fileID); % Uncomment if there's a condition to exit the loop
end

