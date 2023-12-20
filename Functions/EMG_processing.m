% Script Name: EMG_processing.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% This script performs all signal processing for EMG
% Courtesy: Carl Larsson
% ---------------------------------------------------------------------
function EMG_processing(EMG_main_queue, EMG_prediction_queue, emg_classifier, debug)
EMG_processing_queue = parallel.pool.PollableDataQueue; % Queue for processing
send(EMG_main_queue, EMG_processing_queue);
emg_fs = 1000;
[n_emg, d_emg, notchFilt_50_emg, notchFilt_100_emg, notchFilt_150_emg] = emg_real_time_processing_init(emg_fs);
send(EMG_main_queue, 'ready');

while true
    [trigger, flag] = poll(EMG_processing_queue, 0.1);
    if flag
        if strcmp(trigger, 'start')
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Processing, receieved start command']);
            break;
        end
    end
end
% send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Starting processing']);
while true
    [emg_data, dataReceived] = poll(EMG_processing_queue, 0);
    if dataReceived
        if strcmp(emg_data, 'stop')
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Processing, receieved stop command']);
            break;
        end

        % send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Processing, receieved: ', num2str(size(emg_data, 1)),' samples']);
        tic; % Start timer
        prediction = emg_real_time_processing(emg_data, emg_classifier, n_emg, d_emg, notchFilt_50_emg, notchFilt_100_emg, notchFilt_150_emg);
        if debug
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Processing Time: ', num2str(toc()*1000),' ms']);
        end
        send(EMG_prediction_queue, prediction);
        send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Prediction: ', num2str(prediction)]);
    end
end
end