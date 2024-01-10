% Script Name: EEG_processing.m
% Author: Pontus Svensson
% Date: 2024-01-10
% Version: 1.0.0
%
% Description:
% This script performs all signal processing for EEG signal. The process
% receives one window from the EEG_worker process. Filtering, feature
% extraction and prediction is made for each of the windows receieved.
%
% MIT License
% Copyright (c) 2024 Pontus Svensson
% 
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
% 
% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.
% 
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.
%

% ---------------------------------------------------------------------
function EEG_processing(EEG_main_queue, EEG_prediction_queue, W, eeg_classifier,debug)
% Create a pollable queue for processing
EEG_processing_queue = parallel.pool.PollableDataQueue;

% Send the handle to the other processes
send(EEG_main_queue, EEG_processing_queue);
eeg_fs = 200; % Ganglion board sampling rate
window_size = 0.25; % Window size 250 ms
overlap = 0.05; % Total overlap 50 ms
% ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
% Carl
[n_eeg, d_eeg, notchFilt_50_eeg, notchFilt_100_eeg] = eeg_real_time_processing_init(eeg_fs);
% ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
responseTimeBuffer = []; % Save the response times

send(EEG_main_queue, 'ready');
while true % Wait for start command
    [trigger, flag] = poll(EEG_processing_queue, 0.1);
    if flag
        if strcmp(trigger, 'start')
            send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')), ' EEG Processing, receieved start command']);
            break;
        end
    end
end

while true
    [eeg_data, dataReceived] = poll(EEG_processing_queue, 0); % Poll for data
    if dataReceived
        if strcmp(eeg_data, 'stop')
            send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')), ' EEG Processing, receieved stop command']);
            break;
        end
        samplingtime = eeg_data(end,1); % Sampling time is stored last in the matrix
        eeg_data(end,:) = [];
        tic;
        % ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        % Carl
        prediction = eeg_real_time_processing(eeg_data, eeg_fs, window_size, overlap, W, eeg_classifier, n_eeg, d_eeg, notchFilt_50_eeg, notchFilt_100_eeg);
        % ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        if debug
            send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')),' EEG Response time: ', num2str(toc()*1000+samplingtime), ' ms']);
        end
        responsetime = toc()*1000 + samplingtime; % Calculate the sampling-time + processing time
        responseTimeBuffer = [responseTimeBuffer; responsetime]; % Store the time in the buffer
        send(EEG_prediction_queue, prediction); % Send the prediction to the main queue
    end
end
averageResponseTime = mean(responseTimeBuffer); % Calculate average response time
stdResponseTime = std(responseTimeBuffer); % Calculate the standar deviation for the response time
send(EEG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EEG average Response Time: ', num2str(averageResponseTime),' ms']);
send(EEG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EEG standar deviation Response time: ', num2str(stdResponseTime),' ms']);
end