clear, clc;
d = daq("ni");
d.Rate = 1000;
ch = addinput(d,"myDAQ1",0:1,"Voltage");
start(d, "Continuous");
voltage = [];
starttime = tic();
runtime = tic();
overlapSamples = round(0.025 * 1000); % Replace Fs with your actual sampling rate
prevVoltage = []; % Initialize an array to store the overlapping data
firstIteration = true;
% Really important to start in continuous mode
while true
    % Read data
    if firstIteration
        [scanData, timeStamp] = read(d, seconds(0.25), "OutputFormat","Matrix");
        firstIteration = false;
    else
        [scanData, timeStamp] = read(d, seconds(0.225), "OutputFormat","Matrix");
    end

    % Append the previous overlap to the current data
    voltage = [prevVoltage; scanData(:,1), scanData(:,2), timeStamp]; % Append overlap
    voltage_save = [scanData(:,1), scanData(:,2), timeStamp]; % Combine with timestamps for saving

    % Store last 25 ms of data for the next overlap
    if size(scanData, 1) > overlapSamples
        prevVoltage = [scanData(end-overlapSamples+1:end, 1:2), timeStamp(end-overlapSamples+1:end)];
    else
        prevVoltage = [];
    end
end
endtime = toc(starttime);
fprintf("Sample rate: %d\n", int64(1/(endtime/size(voltage,1))));
stop(d);