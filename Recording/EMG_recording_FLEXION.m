clear, clc;
name = 'Pontus';
setting = 'FLEXION';
session = [name,'-', setting];
% Initialize DAQ
d = daq("ni");
d.Rate = 1000; % Set sampleRate
addinput(d, "myDAQ1", 0:1, "Voltage"); % Set channels to read from ai0, ai1
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HHmmss'); % Format as 'YYYYMMDD_HHMMSS'
fileName = ['../Datasets/EMG/EMG_',session,'_',char(currentDateTime),'.txt'];

fileID = fopen(fileName, "w");

% ---------------------------------------------------------------------
% Main loop
% ---------------------------------------------------------------------
labelTime = tic;
label = 0;
reps = 0;
ID = 0;
pause(4); % Make sure we get output first
start(d,"continuous");
runtime = tic;
while true
    [scanData, timeStamp] = read(d, seconds(0.001), "OutputFormat","Matrix");
    
    if toc(labelTime) >= 4
        if reps == 30
            disp(['REP: ', num2str(reps), ' Dataset completed']);
            break;
        end

        if label == 0
            disp(['REP: ', num2str(reps + 1),' REST', ' Label: ', num2str(label)]);
        else
            disp(['REP: ', num2str(reps + 1),' EXTENSION',' Label: ', num2str(2)]);
            reps = reps + 1;
        end
        label = ~label; % Toggle label
        labelTime = tic; % Reset timer
    end
    for i = 1:size(scanData,1)
        if ~label
            fprintf(fileID, "%f %f %f %f %f\n", scanData(i,1), scanData(i,2), 2, ID, timeStamp);
        else
            fprintf(fileID, "%f %f %f %f %f\n", scanData(i,1), scanData(i,2), label, ID, timeStamp);
        end
        ID = mod(ID + 1, 1000);
    end
end
disp(toc(runtime));
fclose(fileID);
stop(d);