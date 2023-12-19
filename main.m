% Script Name: main.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------

% Create the GUI
hFig = figure('Name', 'Control Panel', 'NumberTitle', 'off', 'CloseRequestFcn', @closeGUI);
hButton = uicontrol('Style', 'pushbutton', 'String', 'Stop', ...
    'Position', [20 20 100 40], 'Callback', @stopButtonCallback);

% Global variable to control the loop
global stopRequested;
stopRequested = false;
clc;
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HHmmss');
fileName = ['Logs/',char(currentDateTime), '.txt'];
diary(fileName);
load('..\processing\trained_classifiers\emg_classifier.mat');
load('..\processing\trained_classifiers\eeg_classifier.mat');
load('..\processing\saved_variables\W_matrix.mat');
% ---------------------------------------------------------------------
name = 'Pontus';
setting = 'Test_grove_connected_to_ch1_ch2_electrode_loose';
session = [name,'-', setting];
% ---------------------------------------------------------------------
% If no pool exists, create a new one
% DAQ toolbox and ganglion cannot run as a threads :)))) :DDDD
poolobj = parpool('Processes', 8);
% ---------------------------------------------------------------------
% EMG_processing_queue, sends data to processing process
% EMG_save_queue sends data to writing process
% EMG_queue sends data to the main process (this script)
% EMG_command_queue sends data from classifier to this script
% ---------------------------------------------------------------------
EMG_main_queue = parallel.pool.PollableDataQueue; % Initial queue
EEG_debug_queue = parallel.pool.PollableDataQueue; % Initial queue

% ---------------------------------------------------------------------
% EMG_processing dependencies: EMG_classifier_queue, EMG_main_queue
pEMG_processing = parfeval(poolobj, @EMG_processing, 0, EMG_main_queue, emg_classifier); % Process for EMG signal processing
while pEMG_processing.State ~= "running"
end
while true
    [trigger, flag] = poll(EMG_main_queue, 0.1);
    if flag && isa(trigger, 'parallel.pool.PollableDataQueue')
        EMG_processing_queue = trigger;
    elseif flag && isa(trigger, "char")
        if strcmp(trigger, 'ready')
            break;
        end
    end
end
disp([char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' pEMG_processing started']);
% ---------------------------------------------------------------------
% EMG_save dependencies: EMG_main_queue
pEMG_save = parfeval(poolobj, @EMG_save, 0, EMG_main_queue, session); % Process to save data
while pEMG_save.State ~= "running"
end
while true
    [trigger, flag] = poll(EMG_main_queue, 0.1);
    if flag && isa(trigger, 'parallel.pool.PollableDataQueue')
        EMG_save_queue = trigger;
    elseif flag && isa(trigger, "char")
        if strcmp(trigger, 'ready')
            break;
        end
    end
end
disp([char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' pEMG_save started']);
% ---------------------------------------------------------------------
% EMG worker dependencies: EMG_processing_queue, EMG_save_queue
pEMG_worker = parfeval(poolobj, @EMG_worker, 0, EMG_processing_queue, EMG_save_queue, EMG_main_queue); % Process to read and send data for processing and saving
while pEMG_worker.State ~= "running"
end
while true
    [trigger, flag] = poll(EMG_main_queue, 0.1);
    if flag && isa(trigger, 'parallel.pool.PollableDataQueue')
        EMG_worker_queue = trigger;
    elseif flag && isa(trigger, "char")
        if strcmp(trigger, 'ready')
            break;
        end
    end
end
disp([char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')), ' pEMG_worker started']);
% ---------------------------------------------------------------------
% EEG_queue --> EEG_processing_queue --> EEG_command_queue
% EEG
EEG_main_queue = parallel.pool.PollableDataQueue;
% ---------------------------------------------------------------------
% EEG_save dependencies: EEG_save_queue
pEEG_save = parfeval(poolobj, @EEG_save, 0, EEG_main_queue, session);
while pEEG_save.State ~= "running"
end
while true
    [trigger, flag] = poll(EEG_main_queue, 0.1);
    if flag && isa(trigger, 'parallel.pool.PollableDataQueue')
        EEG_save_queue = trigger;
    elseif flag && isa(trigger, "char")
        if strcmp(trigger, 'ready')
            break;
        end
    end
end
disp([char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')), ' pEEG_save started']);
% ---------------------------------------------------------------------
% EEG_processing dependencies: EEG_main_queue, EEG_classifier_queue
pEEG_processing = parfeval(poolobj, @EEG_processing, 0, EEG_main_queue, EEG_debug_queue, W, eeg_classifier); % Process for EEG signal processing
while pEEG_processing.State ~= "running"
end
while true
    [trigger, flag] = poll(EEG_main_queue, 0.1);
    if flag && isa(trigger, 'parallel.pool.PollableDataQueue')
        EEG_processing_queue = trigger;
    elseif flag && isa(trigger, "char")
        if strcmp(trigger, 'ready')
            break;
        end
    end
end
disp([char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')), ' pEEG_processing started']);
% ---------------------------------------------------------------------
% EEG_sampling dependencies: EEG_main_queue, EEG_processing_queue,
% EEG_save_queue
pEEG_worker = parfeval(poolobj, @EEG_worker, 0, EEG_processing_queue, EEG_save_queue, EEG_main_queue, session); % Sampling, brainflow already saves data
while pEEG_worker.State ~= "running"
end
while true
    [trigger, flag] = poll(EEG_main_queue, 0.1);
    if flag && isa(trigger, 'parallel.pool.PollableDataQueue')
        EEG_worker_queue = trigger;
    elseif flag && isa(trigger, "char")
        if strcmp(trigger, 'ready')
            break;
        end
    end
end
disp([char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')), ' pEEG_worker started']);
% ---------------------------------------------------------------------
disp("All processes started");

% ---------------------------------------------------------------------
% Start all processes at the same time
send(EEG_save_queue, 'start');
send(EEG_processing_queue, 'start');
send(EEG_worker_queue, 'start');

send(EMG_worker_queue, "start");
send(EMG_save_queue, "start");
send(EMG_processing_queue, "start");
% Main processing loop
while ~stopRequested

    [EMG_debug, msg_received_emg2] = poll(EMG_main_queue, 0);
    [EEG_debug, msg_received_eeg2] = poll(EEG_main_queue, 0);
    [EEG_debug2, flag] = poll(EEG_debug_queue, 0);
    if flag 
        IC = EEG_debug2;
    end
    if msg_received_emg2 && isa(EMG_debug, "char")
        disp(EMG_debug);
    end
    if msg_received_eeg2 && isa(EEG_debug, "char")
        disp(EEG_debug);
    end
    pause(0.05); % Pause to reduce CPU usage and make the GUI responsive
end

% Perform cleanup
disp('Cleaning up resources...');
send(EEG_save_queue, 'stop');
send(EEG_processing_queue, 'stop');
send(EEG_worker_queue, 'stop');

send(EMG_save_queue, 'stop');
send(EMG_processing_queue, 'stop');
send(EMG_worker_queue, 'stop');
pause(1);
while EMG_main_queue.QueueLength ~= 0
    [trigger, flag] = poll(EMG_main_queue, 0);
    if flag
        disp(trigger);
    end
end
while EEG_main_queue.QueueLength ~= 0
    [trigger, flag] = poll(EEG_main_queue, 0);
    if flag
        disp(trigger);
    end
end
      
pause(5);
delete(gcp('nocreate'));

disp('Cleanup done.');
diary off;
% Close the figure
delete(hFig);


function stopButtonCallback(hObject, eventdata)
global stopRequested;
stopRequested = true;
end

function closeGUI(hObject, eventdata)
global stopRequested;
if ~stopRequested
    % If the process is still running, confirm before closing
    choice = questdlg('The process is still running. Do you want to stop and exit?', ...
        'Confirm Exit', 'Yes', 'No', 'No');
    if strcmp(choice, 'Yes')
        stopRequested = true;
    end
else
    % If the process has already been stopped, close the GUI
    delete(hObject);
end
end