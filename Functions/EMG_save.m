% Script Name: EMG_save.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------
function EMG_save(EMG_main_queue)
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HH_mm_ss'); % Format as 'YYYYMMDD_HHMMSS'
fileName = ['Datasets\EMG\emg_rec_',char(currentDateTime),'.txt'];
fileID = fopen(fileName, "w");
EMG_save_queue = parallel.pool.PollableDataQueue; % Queue to save data
send(EMG_main_queue, EMG_save_queue); % Send the EMG queue back to main
% rawData = [];
% label = 0;
tic;
while true
    [rawData, msg_received] = poll(EMG_save_queue, 0);
    if msg_received
        send(EMG_main_queue, ['Saving ',num2str(size(rawData,1)),' samples']);
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
            fprintf(fileID, "%f %f %f %f\n", rawData(i, 1), rawData(i, 2), label, rawData(i, 3));
        end
        % fclose(fileID);
    end
end
end