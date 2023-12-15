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
% Initialize DAQ
d = daq("ni");
d.Rate = 1000; % Set sampleRate
addinput(d, "myDAQ1", 0:1, "Voltage"); % Set channels to read from ai0, ai1
% addinput(d, "myDAQ1", 0, "Voltage"); % Set channels to read from ai0

% Really important to start in continuous mode
start(d,"continuous");
% voltage = [];
% voltage_save = [];
while true
        % Read data
        [scanData, timeStamp] = read(d, seconds(0.25), "OutputFormat","Matrix");
        voltage_save = [scanData(:,1), scanData(:,2), timeStamp]; % Used to save the samples
        voltage = [scanData(:,1), scanData(:,2)]; % We dont need the timestamps for processing
        % numberSamples = numberSamples + size(scanData,1);
        % debug_message = ['EMG data read: nr of samples: ',num2str(size(voltage,1))];
        % send(EMG_main_queue, debug_message);
        send(EMG_processing_queue, voltage);
        send(EMG_save_queue, voltage_save);
        % voltage = [];
        % voltage_save = [];
end
% stop(d);
end
