% Script Name: EMG_worker.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% This script samples the analog input of the NI myDAQ and saves the data
% for real-time processing and offline analysis
% ---------------------------------------------------------------------
function EMG_worker(EMG_processing_queue, EMG_save_queue, EMG_main_queue, debug)
% ---------------------------------------------------------------------
EMG_worker_queue = parallel.pool.PollableDataQueue;
send(EMG_main_queue, EMG_worker_queue);
% Initialize DAQ
d = daq("ni");
d.Rate = 1000; % Set sampleRate
addinput(d, "myDAQ1", 0:1, "Voltage"); % Set channels to read from ai0, ai1
% addinput(d, "myDAQ1", 0, "Voltage"); % Set channels to read from ai0
send(EMG_main_queue, 'ready');

send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Worker checking for start']);
while true
    [trigger, flag] = poll(EMG_worker_queue, 0.1);
    if flag
        if strcmp(trigger, 'start')
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Worker start command receieved']);
            break;
        end
    end
end
overlapSamples = round(0.025 * 1000); % Replace Fs with your actual sampling rate
prevVoltage = []; % Initialize an array to store the overlapping data

% Really important to start in continuous mode
start(d,"continuous");
while true
    if debug
        send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Starting inloop']);
    end
    [trigger, flag] = poll(EMG_worker_queue, 0);
    if flag
        if strcmp(trigger, 'stop')
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Worker, received stop command']);
            break;
        end
    end
    if debug
        send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Sampling, sampling 250 ms']);
    end
        % Read data
    [scanData, timeStamp] = read(d, seconds(0.25), "OutputFormat","Matrix");

    % Append the previous overlap to the current data
    voltage = [prevVoltage; scanData(:,1), scanData(:,2)]; % Append overlap
    voltage_save = [voltage, timeStamp]; % Combine with timestamps for saving

    % Send data for processing and saving
    send(EMG_processing_queue, voltage);
    send(EMG_save_queue, voltage_save);

    % Store last 50 ms of data for the next overlap
    if size(scanData, 1) > overlapSamples
        prevVoltage = scanData(end-overlapSamples+1:end, 1:2);
    else
        prevVoltage = [];
    end
end
stop(d);
end
