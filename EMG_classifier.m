function EMG_classifier(EMG_main_queue, EMG_command_queue)

EMG_classifier_queue = parallel.pool.PollableDataQueue; % Queue for processing
send(EMG_main_queue, EMG_classifier_queue);
dataToClassify = [];    
    while true
        [dataToClassify, dataReceived] = poll(EMG_classifier_queue, 0);
        if dataReceived
            % Classify ......
            
            % command = 1; % Just for debugging
            send(EMG_command_queue, dataToClassify);
        end
    end
end