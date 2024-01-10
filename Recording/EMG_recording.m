% Script Name: EMG_recording.m
% Author: Pontus Svensson
% Date: 2024-01-10
% Version: 1.0.0
% ---------------------------------------------------------------------
% Description: This script is the protocol used for recording EMG dataset
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
clear, clc;
name = 'Pontus';
setting = 'Ch_1_longitude_Ch_2_transverse';
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
printLabel = 0;
reps = 0;
ID = 0;
pause(4); % Make sure we get output first
start(d,"continuous");
while true
    [scanData, timeStamp] = read(d, seconds(0.001), "OutputFormat","Matrix");
    if toc(labelTime) >= 4
        if reps == 30
            disp(['REP: ', num2str(reps), ' Dataset completed']);
            break;
        end
        if label == 0
            disp(['REP: ', num2str(reps + 1),' REST']);
            printLabel = 0;
        elseif label == 1
            disp(['REP: ', num2str(reps + 1),' EXTENSION']);
            printLabel = 1;
        elseif label == 2
            disp(['REP: ', num2str(reps + 1),' REST']);
            printLabel = 0;
        else
            disp(['REP: ', num2str(reps + 1),' FLEXION']);
            printLabel = 2;
            reps = reps + 1;
        end
        label = mod(label + 1, 4); % Toggle label
        labelTime = tic; % Reset timer
    end
    for i = 1:size(scanData, 1)
        fprintf(fileID, "%f %f %f %f %f\n", scanData(i,1), scanData(i,2), printLabel, ID, timeStamp(i, 1));
        ID = mod(ID + 1, 1000);
    end
end
fclose(fileID);
stop(d);





