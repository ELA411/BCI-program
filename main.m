% Script Name: main.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------
% Check if a parallel pool already exists
clc, clear;
load ..\processing\trained_classifiers\emg_classifier.mat
load ..\processing\trained_classifiers\eeg_classifier.mat

delete(gcp('nocreate')); 

% If no pool exists, create a new one
% DAQ toolbox and ganglion cannot run as a threads :)))) :DDDD
poolobj = parpool('Processes', 8); 

% EMG_processing_queue, sends data to processing process
% EMG_save_queue sends data to writing process
% EMG_queue sends data to the main process (this script)
% EMG_command_queue sends data from classifier to this script

EMG_main_queue = parallel.pool.PollableDataQueue; % Initial queue
EMG_command_queue = parallel.pool.PollableDataQueue; % Queue for command to ROS

qReceived = false;
qReceived1 = false;
qReceived2 = false;

% EMG_classifier dependencies: EMG_command_queue, EMG_main_queue
pEMG_classifier = parfeval(poolobj, @EMG_classifier, 0, EMG_main_queue, EMG_command_queue, emg_classifier); % Process for classification
while pEMG_classifier.State ~= "running"
end
while qReceived2 == false
    [EMG_classifier_queue, qReceived2] = poll(EMG_main_queue, 0); % EMG_processing_queue handle
end
disp('pEMG_classifier started');
% EMG_processing dependencies: EMG_classifier_queue, EMG_main_queue
pEMG_processing = parfeval(poolobj, @EMG_processing, 0, EMG_main_queue, EMG_classifier_queue); % Process for EMG signal processing
while pEMG_processing.State ~= "running"
end
while qReceived1 == false
    [EMG_processing_queue, qReceived1] = poll(EMG_main_queue, 0); % EMG_processing_queue handle
end
disp('pEMG_processing started');
% EMG_save dependencies: EMG_main_queue
pEMG_save = parfeval(poolobj, @EMG_save, 0, EMG_main_queue); % Process to save data
while pEMG_save.State ~= "running"
end
while qReceived == false 
    [EMG_save_queue, qReceived] = poll(EMG_main_queue,0 ); % EMG_save_queue handle
end
disp('pEMG_save started');
% EMG worker dependencies: EMG_processing_queue, EMG_save_queue
pEMG_worker = parfeval(poolobj, @EMG_worker, 0, EMG_processing_queue, EMG_save_queue, EMG_main_queue); % Process to read and send data for processing and saving
while pEMG_worker.State ~= "running"
end
disp('pEMG_worker started');
% EEG_queue --> EEG_processing_queue --> EEG_command_queue
% EEG
EEG_main_queue = parallel.pool.PollableDataQueue;
EEG_command_queue = parallel.pool.PollableDataQueue;

qReceived3 = false;
qReceived4 = false;
qReceived5 = false;

% EEG_save dependencies: EEG_save_queue
pEEG_save = parfeval(poolobj, @EEG_save, 0, EEG_main_queue);
while pEEG_save.State ~= "running"
end
while qReceived5 == false
    [EEG_save_queue, qReceived5] = poll(EEG_main_queue, 0);
end
disp('pEEG_save started');
% EEG_classifier dependencies: EEG_command_queue, EEG_main_queue
pEEG_classifier = parfeval(poolobj, @EEG_classifier, 0, EEG_main_queue, EEG_command_queue, eeg_classifier); % Process for classification
while pEEG_classifier.State ~= "running"
end
while qReceived3 == false
    [EEG_classifier_queue, qReceived3] = poll(EEG_main_queue, 0);
end
disp('pEEG_classifier started');
% EEG_processing dependencies: EEG_main_queue, EEG_classifier_queue
pEEG_processing = parfeval(poolobj, @EEG_processing, 0, EEG_main_queue, EEG_classifier_queue); % Process for EEG signal processing
while pEEG_processing.State ~= "running"
end
while qReceived4 == false
    [EEG_processing_queue, qReceived4] = poll(EEG_main_queue, 0);
end
disp('pEEG_processing started');
% EEG_sampling dependencies: EEG_main_queue, EEG_processing_queue,
% EEG_save_queue
pEEG_worker = parfeval(poolobj, @EEG_worker, 0, EEG_processing_queue, EEG_save_queue, EEG_main_queue); % Sampling, brainflow already saves data
while pEEG_worker.State ~= "running"
end
disp('pEEG_worker started');
fprintf("All processes started\n");
% ---------------------------------------------------------------------
% Receive input from the classifiers
while true    % Implement processing

    % Data supports vector, scalar, matrix, array, string, character vector
    % [EMG_command, msg_received_emg] = poll(EMG_command_queue, 0);
    [EEG_command, msg_received_eeg] = poll(EEG_command_queue, 0);
    % [message, msg_received_emg2] = poll(EMG_main_queue, 0);
    [message2, msg_received_eeg2] = poll(EEG_main_queue, 0);

    % General EMG debug
    % if msg_received_emg2
    %     disp(message);
    % end

    % % Classifier debug
    % if msg_received_emg
    %     disp(EMG_command);
    % end
    
    % General EEG Debug
    if msg_received_eeg2
        disp(message2);
    end
    
    % Classifier EEG debug
    if msg_received_eeg
        disp(EEG_command);
    end
end