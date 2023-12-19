% Script Name: EEG_processing.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% This script performs all signal processing for EEG signal
% ---------------------------------------------------------------------
function EEG_processing(EEG_main_queue, W, eeg_classifier)
% Create a pollable queue for processing
EEG_processing_queue = parallel.pool.PollableDataQueue;

% Send the handle to the other processes
send(EEG_main_queue, EEG_processing_queue);

eeg_fs = 200;
[n_eeg, d_eeg, notchFilt_50_eeg, notchFilt_100_eeg] = eeg_real_time_processing_init(eeg_fs);
counter = 0;
send(EEG_main_queue, 'ready');
while true
    [trigger, flag] = poll(EEG_processing_queue, 0.1);
    if flag
        if strcmp(trigger, 'start')
            send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')), ' EEG Processing, receieved start command']);
            break;
        end
    end
end

while true
    [eeg_data, dataReceived] = poll(EEG_processing_queue, 0);
    if dataReceived
        if strcmp(eeg_data, 'stop')
            send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')), ' EEG Processing, receieved stop command']);
            break;
        end
        % send(EEG_main_queue, ['EEG Processing started ', char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')), ' Predictions: ', num2str(counter)]);
        tic;
        prediction = eeg_real_time_processing(eeg_data, W, eeg_classifier, n_eeg, d_eeg, notchFilt_50_eeg, notchFilt_100_eeg);
        counter = counter + 1;
        % send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')),' EEG Processing: LOOPS: ', num2str(counter)]);
        % send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')),' EEG Processing: ', num2str(toc()*1000), ' ms']);
        send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')),' EEG Prediction: ', num2str(prediction)]);
    end
end
end