% Script Name: EMG_save.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------
function EMG_save(EMG_main_queue)
    currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HH_mm_ss');
    fileName = ['Datasets/EMG/emg_rec_', char(currentDateTime), '.txt'];
    fileID = fopen(fileName, "w");
    EMG_save_queue = parallel.pool.PollableDataQueue;
    send(EMG_main_queue, EMG_save_queue);
    pkdID = 0;
    tic;
    while true
        [rawData, msg_received] = poll(EMG_save_queue, 0);
        if msg_received
            send(EMG_main_queue, ['Saving ', num2str(size(rawData, 1)), ' samples']);
            for i = 1:size(rawData, 1)
                elapsed = toc();
                if elapsed <= 1
                    label = 1;
                elseif elapsed >= 4
                    label = 2;
                    tic;
                else
                    label = 0;
                end
                fprintf(fileID, "%f %f %f %f %f\n", rawData(i, 1), rawData(i, 2), label, pkdID, rawData(i, 3));
                pkdID = mod(pkdID + 1, 1000);
            end
        end
    end
    % fclose(fileID); % Uncomment if there's a condition to exit the loop
end
