delete(gcp('nocreate')); 
poolobj = parpool('Processes', 1); 
eeg_queue = parallel.pool.PollableDataQueue;
EEG_sampling = parfeval(poolobj, @EEG_worker, 0, eeg_queue);

starttime = tic;
dataRaw=[];
eegReadings = [];
while toc(starttime)<=10
    % Data supports vector, scalar, matrix, array, string, character vector
    [dataRaw, msg_received] = poll(eeg_queue, 0);

    if msg_received
        fprintf("Message received after %d\n",toc(starttime));
        eegReadings = [eegReadings; dataRaw];
    end
end
if ~isempty(eegReadings)
    timeDiff = diff(eegReadings(:,7));
    sampleRate = 1/mean(timeDiff);
    fprintf("Sample Rate Timestamps: %d\n", int64(sampleRate));
else
    fprintf("No data received\n");
end