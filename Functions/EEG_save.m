% Script Name: EEG_save.m
% Author: Pontus Svensson
% Date: 2024-01-10
% Version: 1.0.0
% ---------------------------------------------------------------------
% Description:
% This script saves the data received from the ganglion. The process
% receives a buffer containing the timestamps, packageids and samples from
% the 4 EEG channels and writes them to file.
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
% ---------------------------------------------------------------------
function EEG_save(EEG_main_queue, session, debug)
% Create a file to write to, sessin is defined in main.m
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HHmmss');
fileName = ['Datasets/EEG/EEG_',session,'_',char(currentDateTime),'.txt'];
fileID = fopen(fileName, "w");

% Create a pollable queue for the EEG_save process, this is needed because
% the pollable queue has to created by the process which it should be
% polled in. See documentation in parallel toolbox for more information.
EEG_save_queue = parallel.pool.PollableDataQueue;
send(EEG_main_queue, EEG_save_queue);

send(EEG_main_queue, 'ready')
while true % Wait for start command
    [trigger, flag] = poll(EEG_save_queue, 0.1);
    if flag
        if strcmp(trigger, 'start')
            send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')), ' EEG Save, receieved start command']);
            break;
        end
    end
end

while true
    [rawData, msg_received] = poll(EEG_save_queue, 0); % Poll for data

    if msg_received
        if debug
            send(EEG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EEG save, writing ', num2str(size(rawData, 1)),' samples to file']);
        end
        if strcmp(rawData, 'stop')
            send(EEG_main_queue, [char(datetime('now','Format','yyyy-MM-dd_HH:mm:ss:SSS')), ' EEG Save, receieved stop command. Closing file']);
            break;
        end
        % Extract the data received
        channel1 = rawData(:,1);
        channel2 = rawData(:,2);
        channel3 = rawData(:,3);
        channel4 = rawData(:,4);
        ID = rawData(:,5);
        timestamp = rawData(:,6);

        for i = 1:size(rawData, 1) % Write the data to file
            fprintf(fileID, "%f %f %f %f %f %f\n", channel1(i), channel2(i), channel3(i), channel4(i), ID(i), timestamp(i));
        end
    end
end
fclose(fileID);
end

