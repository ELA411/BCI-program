% Script Name: EEG_classifier.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------
function EEG_classifier(EEG_main_queue, EEG_command_queue, eeg_classifier)
EEG_classifier_queue = parallel.pool.PollableDataQueue;
send(EEG_main_queue, EEG_classifier_queue);
while true
    [eeg_data, dataReceived] = poll(EEG_classifier_queue, 0);
    if dataReceived
        tic;
        %--------------------------------------------------------------------------------------------------------
        % EEG Classification
        eeg_label = predict(eeg_classifier.Trained{1}, eeg_data);
        %--------------------------------------------------------------------------------------------------------
        send(EEG_command_queue, ['EMG Prediction: ', num2str(emg_label), ' Time: ', num2str(toc()*1000),' ms' ]);
    end
end
end