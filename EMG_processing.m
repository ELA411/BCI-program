function EMG_processing(EMG_main_queue, EMG_classifier_queue)
EMG_processing_queue = parallel.pool.PollableDataQueue; % Queue for processing
send(EMG_main_queue, EMG_processing_queue);
dataToProcess = [];
numSamples = 0;
while true
    [dataToProcess, dataReceived] = poll(EMG_processing_queue, 0);
    if dataReceived
        tic; % Start timer
        % Processing...

        % Calculate sample rate
        numSamples = size(dataToProcess, 1); % Assuming dataToProcess is organized with one sample per row
        if numSamples > 0
            elapsedTime = toc; % Get elapsed time
            sampleRate = numSamples / elapsedTime;
            toSend = [numSamples, sampleRate];
            % send(EMG_main_queue, toSend); Calculate processing time
        end
        % send(EMG_main_queue, sampleRate);
        % Send to classifier
        send(EMG_classifier_queue, dataToProcess);
        % send(EMG_main_queue, dataToProcess);
        dataToProcess = [];
        dataReceived = false;
    end
end
end