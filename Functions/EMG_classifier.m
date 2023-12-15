% Script Name: EMG_classifier.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------
function EMG_classifier(EMG_main_queue, EMG_command_queue, emg_classifier)

EMG_classifier_queue = parallel.pool.PollableDataQueue; % Queue for processing
send(EMG_main_queue, EMG_classifier_queue);
debug_message = 'EMG_classifier started';
% emg_data = [];    
    while true
        [emg_data, dataReceived] = poll(EMG_classifier_queue, 0);
        if dataReceived
            tic;
            % send(EMG_main_queue, debug_message);
            % Classify ......
            emg_label = predict(emg_classifier.Trained{1}, emg_data);

            % command = 1; % Just for debugging
            send(EMG_command_queue, ['EMG Prediction: ', num2str(emg_label), ' Time: ', num2str(toc()*1000),' ms' ]);
        end
    end
end