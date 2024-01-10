% Script Name: EMG_worker.m
% Author: Pontus Svensson, Viktor Eriksson
% Date: 2023-12-14
% Version: 1.0.0
% ---------------------------------------------------------------------
% Description:
% This script samples the analog input of the NI myDAQ and saves the data
% for real-time processing and offline analysis.
% ---------------------------------------------------------------------
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
function EMG_worker(EMG_processing_queue, EMG_save_queue, EMG_main_queue, debug)
% ---------------------------------------------------------------------
EMG_worker_queue = parallel.pool.PollableDataQueue;
send(EMG_main_queue, EMG_worker_queue);
% Initialize DAQ
d = daq("ni");
d.Rate = 1000; % Set sampleRate
addinput(d, "myDAQ1", 0:1, "Voltage"); % Set channels to read from ai0, ai1
send(EMG_main_queue, 'ready');
while true
    [trigger, flag] = poll(EMG_worker_queue, 0.1);
    if flag
        if strcmp(trigger, 'start')
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Worker start command receieved']);
            break;
        end
    end
end
% Initiate some variables
overlapSamples = round(0.025 * 1000); % number of samples to store for each window
prevVoltage = []; % Array to store overlap samples
scanData = []; % Array to store samples values
timeStamp = []; % Store the timestamps
firstIteration = true; 
packetLoss = 0; 
samples = 0;
tolerance = 0.0015; % tolerance between consecutive samples

% If the sampling is not set to conitnuous mode, it always has to restart
% taking an undefined amount of time increasing the response time.
start(d,"continuous");
while true
    % poll the worker queue for data
    [trigger, flag] = poll(EMG_worker_queue, 0);
    if flag
        if strcmp(trigger, 'stop')
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Worker, received stop command']);
            break;
        end
    end

    if debug
        send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Worker, scans available for reading: ', num2str(d.NumScansAvailable)]);
    end
    % For the first iteration we sample 250 samples since it does not
    % contain overlap from previous samples
    if firstIteration
        starttime = tic;
        while(size(scanData,1)) <= 250
            % Read 1 sample every 1 ms, number of samples could also be
            % specified here, but to stay consistent when collecting a
            % dataset for training 1 ms is used.
            [data, time] = read(d, seconds(0.001), "OutputFormat","Matrix");
            scanData = [scanData; data];
            timeStamp = [timeStamp; time];
            samples = samples + size(scanData,1);
        end
        firstIteration = false;
        if debug
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Worker, scans read: ', num2str(d.NumScansAcquired)]);
        end
    else
        % For any other windows we should only collect 225 since we are
        % saving the last 25 samples from previous window, 25 + 225 = 250
        starttime = tic; % Time to collect the samples
        while(size(scanData,1)) <= 225
            [data, time] = read(d, seconds(0.001), "OutputFormat","Matrix");
            scanData = [scanData; data];
            timeStamp = [timeStamp; time];
            samples = samples + size(scanData,1);
        end
        if debug
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Worker, scans read: ', num2str(d.NumScansAcquired)]);
        end
    end
    % Append the previous overlap to the current data
    voltage = [prevVoltage; scanData(:,1), scanData(:,2)]; % Append overlap
    voltage_save = [scanData(:,1), scanData(:,2), timeStamp]; % Combine with timestamps for saving, we dont include overlap since it will include duplicates
    
    % The DAQ continuosly saves samples, and matlab is not fast enough to
    % reliably collect all of them, leaving behind 0 - 75 samples,
    % therefore we read the last samples remaining in the buffer, to only use the
    % latest samples for each window. Depending on what processes are running on the laptop the time
    % for sampling and processing differs a lot.
    if d.NumScansAvailable > 0
        [save_rest , times]= read(d, d.NumScansAvailable, "OutputFormat","Matrix");
        voltage_save = [voltage_save; save_rest(:,1), save_rest(:,2), times];
    end
    
    % Calculate the samplerate
    sampleRate = 1/mean(diff(timeStamp));
    
    % Calculate packetloss by comparing consecutive samples timedifference,
    % if the timedifference is greater than 1.5 ms it is assumed to be a
    % lost sample. We add some redundacy to take matlab processing times
    % into account
    for i = 2:size(voltage_save,1) % Start at the second sample
        if (voltage_save(i,3) - voltage_save(i-1,3)) > tolerance
            packetLoss = packetLoss + 1;
        end
    end

    if debug
        send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Worker, sampleRate: ', num2str(sampleRate)]);
    end

    % Save the time it took to collect the samples in the last row of the
    % array, this is the only way to "reliably" send the sampling time to
    % the processing worker in order to get the response time
    voltage = [voltage; toc(starttime)*1000, 0];
    send(EMG_processing_queue, voltage);
    send(EMG_save_queue, voltage_save);

    if debug
        send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Worker, sampling time: ', num2str(toc)]);
    end

    % Store last 25 ms of data for the next overlap
    if size(scanData, 1) > overlapSamples % Make sure we have collected enough samples
        prevVoltage = scanData(end-overlapSamples+1:end, 1:2); % Save the last 25 samples for each channel
    else
        prevVoltage = [];
    end
    % Reset the windows
    timeStamp = [];
    scanData = [];

end
% Display some useful information after ending the program
send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Worker, sampleRate: ', num2str(sampleRate), ' PacketLoss: ', num2str(packetLoss), ' PacketLoss %: ', num2str((packetLoss/samples)*100)]);
stop(d);
end
