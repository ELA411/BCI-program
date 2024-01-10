% Script Name: EMG_save.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% ---------------------------------------------------------------------
% Description:
% This script receieves the data read from the NI myDAQ and writes it to
% file.
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
function EMG_save(EMG_main_queue, session, debug)
% Queue for checking after data
EMG_save_queue = parallel.pool.PollableDataQueue;
send(EMG_main_queue, EMG_save_queue);
send(EMG_main_queue, 'ready');
pkdID = 0; % myDAQ does not provide package ID so we have to assign them ourselves

% File
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HHmmss');
fileName = ['Datasets/EMG/EMG_', session, '_',char(currentDateTime), '.txt'];
fileID = fopen(fileName, "w");

% Wait for start command from main
while true
    [trigger, flag] = poll(EMG_save_queue, 0.1);
    if flag
        if strcmp(trigger, 'start')
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG Save, receieved start command']);
            break;
        end
    end
end
% Main loop
while true
    [rawData, msg_received] = poll(EMG_save_queue, 0);

    if msg_received
        if strcmp(rawData, 'stop')
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG save, stop command received. Closing file']);
            break;
        end
        if debug
            send(EMG_main_queue, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' EMG save, writing ', num2str(size(rawData, 1)),' samples to file']);
        end
        % Save the received values to the file
        for i = 1:size(rawData, 1)
            fprintf(fileID, "%f %f %f %f\n", rawData(i, 1), rawData(i, 2), pkdID, rawData(i, 3));
            pkdID = mod(pkdID + 1, 1000);
        end
    end
end
fclose(fileID);
end


