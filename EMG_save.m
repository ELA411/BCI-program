function EMG_save(EMG_main_queue)
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HH_mm_ss'); % Format as 'YYYYMMDD_HHMMSS'
fileName = ['emg_rec_',char(currentDateTime),'.txt'];
fileID = fopen(fileName, "w");
EMG_save_queue = parallel.pool.PollableDataQueue; % Queue to save data
send(EMG_main_queue, EMG_save_queue); % Send the EMG queue back to main
rawData = [];
while true
    [rawData, msg_received] = poll(EMG_save_queue, 0);
    if msg_received
        % send(EMG_main_queue, rawData);
        for i = size(rawData, 1)
            fprintf(fileID, "%f %f %f\n", rawData(i, 1), rawData(i, 2), rawData(i, 3));
        end
    end
end
fclose(fileID);
end