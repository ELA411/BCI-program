delete(gcp('nocreate')); 
poolobj = parpool('Processes', 1); 

emg_queue = parallel.pool.PollableDataQueue;
EMG_sampling = parfeval(poolobj, @EMG_worker, 0, emg_queue);

starttime = tic;
dataRaw=[];
emgReadings = [];
while toc(starttime)<=10
    % Data supports vector, scalar, matrix, array, string, character vector
    [dataRaw, msg_received] = poll(emg_queue, 0);

    if msg_received
        fprintf("Message received after %d\n",toc(starttime));
        emgReadings = [emgReadings; dataRaw];
    end
end
if ~isempty(emgReadings)
    timeDiff = diff(emgReadings(:,3));
    sampleRate = 1/mean(timeDiff);
    fprintf("Sample Rate Timestamps: %d\n", int64(sampleRate));
else
    fprintf("No data received\n");
end
stop(d);
