% Script Name: EEG_save.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------
function EEG_save(EEG_main_queue)
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HH_mm_ss'); % Format as 'YYYYMMDD_HHMMSS'
fileName = ['eeg_rec_',char(currentDateTime),'.txt'];
fileID = fopen(fileName, "w");
EEG_save_queue = parallel.pool.PollableDataQueue; % Queue to save data
send(EEG_main_queue, EEG_save_queue); % Send the EMG queue back to main
% rawData = [];
% label = 0;
tic;
while true
    [rawData, msg_received] = poll(EEG_save_queue, 0);
    if msg_received
        channel1 = rawData(:,1);
        channel2 = rawData(:,2);
        channel3 = rawData(:,3);
        channel4 = rawData(:,4);
        % label = rawData(:,5);
        ID = rawData(:,5);
        timestamp = rawData(:,6);

        % fileID = fopen(fileName, "w");
        for i = 1:size(rawData, 1)
            if toc() <= 1
                label = 1;
            elseif toc()<=2
                label = 2;
            else
                label = 0;
                tic;
            end
            fprintf(fileID, "%f %f %f %f %f %f %f\n", channel1(i), channel2(i), channel3(i), channel4(i), label, ID(i), timestamp(i));
        end
        % fclose(fileID);
    end
end
end