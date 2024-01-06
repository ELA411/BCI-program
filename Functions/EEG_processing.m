% Script Name: EEG_processing.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% This script performs all signal processing for EEG signal
% ---------------------------------------------------------------------
function EEG_processing(EEG_main_queue, EEG_prediction_queue, W, eeg_classifier,debug)
% Create a pollable queue for processing
EEG_processing_queue = parallel.pool.PollableDataQueue;

% Send the handle to the other processes
send(EEG_main_queue, EEG_processing_queue);
eeg_fs = 200;
window_size = 0.25;
overlap = 0.05;
% ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
% Carl
[n_eeg, d_eeg, notchFilt_50_eeg, notchFilt_100_eeg] = eeg_real_time_processing_init(eeg_fs);
% ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
responseTimeBuffer = [];

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
        samplingtime = eeg_data(end,1);
        eeg_data(end,:) = [];
        tic;
        % ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        % Carl
        prediction = eeg_real_time_processing(eeg_data, eeg_fs, window_size, overlap, W, eeg_classifier, n_eeg, d_eeg, notchFilt_50_eeg, notchFilt_100_eeg);
        % ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        if debug
            send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')),' EEG Response time: ', num2str(toc()*1000+samplingtime), ' ms']);
        end
        responsetime = toc()*1000 + samplingtime;
        responseTimeBuffer = [responseTimeBuffer; responsetime];
        send(EEG_prediction_queue, prediction);
    end
end
averageResponseTime = mean(responseTimeBuffer);
stdResponseTime = std(responseTimeBuffer);
send(EEG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EEG average Response Time: ', num2str(averageResponseTime),' ms']);
send(EEG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EEG standar deviation Response time: ', num2str(stdResponseTime),' ms']);
end