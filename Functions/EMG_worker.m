% Script Name: EMG_worker.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------
function EMG_worker(EMG_processing_queue, EMG_save_queue, EMG_main_queue)
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
% Really important to start in continuous mode
start(d,"continuous");
while true
    % send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Starting inloop']);
    [trigger, flag] = poll(EMG_worker_queue, 0);
    if flag
        if strcmp(trigger, 'stop')
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Worker, received stop command']);
            break;
        end
    end
    % send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Sampling, sampling 250 ms']);
    % Read data
    [scanData, timeStamp] = read(d, seconds(0.25), "OutputFormat","Matrix");
    voltage_save = [scanData(:,1), scanData(:,2), timeStamp]; % Used to save the samples
    voltage = [scanData(:,1), scanData(:,2)]; % We dont need the timestamps for processing

    send(EMG_processing_queue, voltage);
    send(EMG_save_queue, voltage_save);
end
stop(d);
end
