% Script Name: EEG_processing.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------
function EEG_processing(EEG_main_queue, EEG_classifier_queue)
% Create a pollable queue for processing
EEG_processing_queue = parallel.pool.PollableDataQueue;

% Send the handle to the other processes
send(EEG_main_queue, EEG_processing_queue);
dataToProcess = [];
while true
    [dataToProcess, dataReceived] = poll(EEG_processing_queue, 0);
    if dataReceived
        % Processing...
        
        % Send to classifier
        send(EEG_classifier_queue, dataToProcess);
        dataToProcess = [];
    end
end
end