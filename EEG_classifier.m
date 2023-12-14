function EEG_classifier(EEG_main_queue, EEG_command_queue)
EEG_classifier_queue = parallel.pool.PollableDataQueue;
send(EEG_main_queue, EEG_classifier_queue);
dataToClassify = [];    
    while true
        [dataToClassify, dataReceived] = poll(EEG_classifier_queue, 0);
        if dataReceived
            % Classify ......
            
            % command = 0; % Just for debugging
            send(EEG_command_queue, dataToClassify);
        end
    end
end