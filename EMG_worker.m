function EMG_worker(EMG_processing_queue, EMG_save_queue, EMG_main_queue)
% ---------------------------------------------------------------------
% Initialize DAQ
d = daq("ni");
d.Rate = 1000; % Set sampleRate
addinput(d, "myDAQ1", 0:1, "Voltage"); % Set channels to read from ai0, ai1
% Really important to start in continuous mode
start(d,"continuous");
voltage = [];
numberSamples = 0;
while true
        % Read data
        [scanData, timeStamp] = read(d, seconds(0.25), "OutputFormat","Matrix");
        voltage = [voltage; scanData(:,1), scanData(:,2), timeStamp];
        % numberSamples = numberSamples + size(scanData,1);
        % send(EMG_main_queue, numberSamples);
        send(EMG_processing_queue, voltage);
        send(EMG_save_queue, voltage);
        voltage = [];
end
stop(d);
end
