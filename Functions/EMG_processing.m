% Script Name: EMG_processing.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
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
% Description:
% This script performs all signal processing for EMG
% ---------------------------------------------------------------------
function EMG_processing(EMG_main_queue, EMG_prediction_queue, emg_classifier, debug)
EMG_processing_queue = parallel.pool.PollableDataQueue; % Queue for processing
send(EMG_main_queue, EMG_processing_queue);
emg_fs = 1000; % Sample rate
% ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
% Carl
[n_emg, d_emg, notchFilt_50_emg, notchFilt_100_emg, notchFilt_150_emg] = emg_real_time_processing_init(emg_fs);
% ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
send(EMG_main_queue, 'ready');
responseTimeBuffer = [];
% Wait for start command 
while true
    [trigger, flag] = poll(EMG_processing_queue, 0.1);
    if flag
        if strcmp(trigger, 'start')
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Processing, receieved start command']);
            break;
        end
    end
end

while true
    % Check for data windows
    [emg_data, dataReceived] = poll(EMG_processing_queue, 0);
    if dataReceived
        if debug
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Processing, data received: ', num2str(size(emg_data, 1))]);
        end
        if strcmp(emg_data, 'stop')
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Processing, receieved stop command']);
            break;
        end
        % The last row contains the sampling time
        samplingtime = emg_data(end,1); % save sampling time
        emg_data(end,:) = []; % Remove last row
        tic; % Start timer
        % ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        % Carl
        prediction = emg_real_time_processing(emg_data, emg_classifier, n_emg, d_emg, notchFilt_50_emg, notchFilt_100_emg, notchFilt_150_emg);
        % ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        if debug
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Processing Time: ', num2str(toc()*1000),' ms']);
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Prediction: ', num2str(prediction)]);
        end
        responsetime = toc()*1000 + samplingtime; % Calculate processing time + sampling time
        responseTimeBuffer = [responseTimeBuffer; responsetime]; % Store the response times in an array
        send(EMG_prediction_queue, prediction); % Send the prediction to the main queue
    end
end
averageResponseTime = mean(responseTimeBuffer); % Calculate response time
stdResponseTime = std(responseTimeBuffer); % standard deviation of response time
% Send to main for printing
send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG average Response Time: ', num2str(averageResponseTime),' ms']);
send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG standar deviation Response time: ', num2str(stdResponseTime),' ms']);
end