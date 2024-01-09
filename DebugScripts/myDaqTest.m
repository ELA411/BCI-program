clear, clc;
d = daq("ni");
d.Rate = 1000;
ch = addinput(d,"myDAQ1",0:1,"Voltage");
start(d, "Continuous");
voltage = [];
starttime = tic();
runtime = tic();
voltage_save = [];
scanData = [];
timeStamp = [];
overlapSamples = round(0.025 * 1000); 
prevVoltage = []; % Initialize an array to store the overlapping data
firstIteration = true;
while toc(runtime) <= 10
    % Read data
    if firstIteration
        while(size(scanData,1)) <= 250
            % Read 1 sample every 1 ms, number of samples could also be
            % specified here, but to stay consistent when collecting a
            % dataset for training 1 ms is used.
            [data, time] = read(d, seconds(0.25), "OutputFormat","Matrix");
            scanData = [scanData; data];
            timeStamp = [timeStamp; time];
        end
        firstIteration = false;
    else
        % For any other windows we should only collect 225 since we are
        % saving the last 25 samples from previous window, 25 + 225 = 250
        while(size(scanData,1)) <= 225
            [data, time] = read(d, seconds(0.225), "OutputFormat","Matrix");
            scanData = [scanData; data];
            timeStamp = [timeStamp; time];
        end
    end

    % Append the previous overlap to the current data
    voltage = [voltage; prevVoltage; scanData(:,1), scanData(:,2), timeStamp]; % Append overlap
    voltage_save = [voltage_save; scanData(:,1), scanData(:,2), timeStamp]; % Combine with timestamps for saving

    % Store last 25 ms of data for the next overlap
    if size(scanData, 1) > overlapSamples
        prevVoltage = [scanData(end-overlapSamples+1:end, 1:2), timeStamp(end-overlapSamples+1:end)];
    else
        prevVoltage = [];
    end
    scanData = [];
    timeStamp = [];
end
endtime = toc(starttime);
fprintf("Sample rate: %f\n", (1/(endtime/size(voltage,1))));
stop(d);