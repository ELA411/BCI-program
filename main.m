% Script Name: main.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description: This script handles the creation of the processes and
% receives the predicitions from the EEG process and EMG process, and then sends commands to the ROS interface.
% Make sure to start gazebo and turtlebot3 first
% ---------------------------------------------------------------------
clc, clear;

% Create the GUI
hFig = figure('Name', 'Control Panel', 'NumberTitle', 'off', 'CloseRequestFcn', @closeGUI);
hButton = uicontrol('Style', 'pushbutton', 'String', 'Stop', ...
    'Position', [20 20 100 40], 'Callback', @stopButtonCallback);

% Global variable to control the loop
global stopRequested;
stopRequested = false;

% Configure ROS2
setenv('ROS_DOMAIN_ID', '30')
node = ros2node("/matlab_nodec");
pub = ros2publisher(node, '/cmd_vel', 'geometry_msgs/Twist');
msg = ros2message(pub);

% Debug information
debug = false;

% Create a new file to store logs
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HHmmss');
fileName = ['Logs/',char(currentDateTime), '.txt'];
diary(fileName);

% Load variables from trained classifiers
load('..\processing\trained_classifiers\emg_classifier.mat');
load('..\processing\trained_classifiers\eeg_classifier.mat');
load('..\processing\saved_variables\W_matrix.mat');
% ---------------------------------------------------------------------
% Configure the name of the save file with useful information
name = 'Pontus';
setting = 'Test';
session = [name,'-', setting];
% ---------------------------------------------------------------------
% If no pool exists, create a new one
% DAQ toolbox and ganglion cannot run as a threads, ganglion board has no
% support to be used in LabView
poolobj = parpool('Processes', 8);
% ---------------------------------------------------------------------
% EMG_processing_queue, sends data to processing process
% EMG_save_queue sends data to writing process
% EMG_queue sends data to the main process (this script)
% EMG_command_queue sends data from classifier to this script
% ---------------------------------------------------------------------
EMG_main_queue = parallel.pool.PollableDataQueue; % Initial queue
EMG_prediction_queue = parallel.pool.PollableDataQueue; % Queue used to receive predictions from EMG classifier

% ---------------------------------------------------------------------
% EMG_processing dependencies: EMG_classifier_queue, EMG_main_queue
pEMG_processing = parfeval(poolobj, @EMG_processing, 0, EMG_main_queue, EMG_prediction_queue, emg_classifier, debug); % Process for EMG signal processing
% Make sure the process has started
while pEMG_processing.State ~= "running"
end
% Do not continue until the pollable queue created by the processing
% process has been returned, since it is needed as argument for the coming
% processes
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
% Information
disp([char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')),' pEMG_processing started']);
% ---------------------------------------------------------------------
% EMG_save dependencies: EMG_main_queue
pEMG_save = parfeval(poolobj, @EMG_save, 0, EMG_main_queue, session, debug); % Process to save data
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
pEMG_worker = parfeval(poolobj, @EMG_worker, 0, EMG_processing_queue, EMG_save_queue, EMG_main_queue, debug); % Process to read and send data for processing and saving
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
EEG_prediction_queue = parallel.pool.PollableDataQueue; % Queue used to receive predictions from EEG classifier
% ---------------------------------------------------------------------
% EEG_save dependencies: EEG_save_queue
pEEG_save = parfeval(poolobj, @EEG_save, 0, EEG_main_queue, session, debug);
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
pEEG_processing = parfeval(poolobj, @EEG_processing, 0, EEG_main_queue, EEG_prediction_queue, W, eeg_classifier, debug); % Process for EEG signal processing
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
pEEG_worker = parfeval(poolobj, @EEG_worker, 0, EEG_processing_queue, EEG_save_queue, EEG_main_queue, session,debug); % Sampling, brainflow already saves data
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
disp([char(datetime('now', 'Format', 'yyyy-MM-dd_HH:mm:ss:SSS')), 'All processes started']);

% ---------------------------------------------------------------------
% Start all processes at the same time
send(EEG_save_queue, 'start');
send(EEG_processing_queue, 'start');
send(EEG_worker_queue, 'start');

send(EMG_worker_queue, "start");
send(EMG_save_queue, "start");
send(EMG_processing_queue, "start");
% Initialize variables for collecting predictions
EEG_predictions = [];
EMG_predictions = [];
prediction_interval = 0.5; % Interval in seconds for collecting predictions
last_prediction_time = tic; % Start a timer
% Main processing loop
while ~stopRequested

    [EMG_debug, flag_EMG_debug] = poll(EMG_main_queue, 0);
    [EEG_debug, flag_EEG_debug] = poll(EEG_main_queue, 0);
    [EMG_prediction, flag_EMG_prediction] = poll(EMG_prediction_queue, 0);
    [EEG_prediction, flag_EEG_prediction] = poll(EEG_prediction_queue, 0);

    % if flag_EEG_debug && isa(EEG_debug, "double")
    %     eegBuffer = EEG_debug;
    % end
    if flag_EMG_debug && isa(EMG_debug, "char")
        disp(EMG_debug);
    end
    if flag_EEG_debug && isa(EEG_debug, "char")
        disp(EEG_debug);
    end

    if flag_EEG_prediction || flag_EMG_prediction
        if flag_EEG_prediction
            EEG_predictions(end + 1) = EEG_prediction;
        end
        if flag_EMG_prediction
            EMG_predictions(end + 1) = EMG_prediction;
        end
        % Check if the interval has passed
        if toc(last_prediction_time) >= prediction_interval
            % Determine the most frequent (mode) prediction
            mode_EEG_prediction = mode(EEG_predictions);
            mode_EMG_prediction = mode(EMG_predictions);


            if flag_EEG_prediction
                if mode_EEG_prediction == 0
                    disp('stop');
                    msg.linear.x = 0;
                    msg.linear.y = 0;
                    msg.linear.z = 0;
                else
                    disp('Drive forward');
                    msg.linear.x = 0.1;
                    msg.linear.y = 0;
                    msg.linear.z = 0;
                end
            end
            if flag_EMG_prediction
                if mode_EMG_prediction == 0
                    disp('Stop turning');
                    msg.angular.x = 0;
                    msg.angular.y = 0;
                    msg.angular.z = 0;
                elseif mode_EMG_prediction == 1
                    disp('Turn left');
                    msg.angular.x = 0.1; % turnleft
                    msg.angular.y = 0;
                    msg.angular.z = 0;
                else
                    disp('Turn right')
                    msg.angular.x = -0.1; % turnright
                    msg.angular.y = 0;
                    msg.angular.z = 0;
                end
            end

            send(pub, msg); % Send message to turtlebot with new velocity
            % Reset predictions
            EEG_predictions = [];
            EMG_predictions = [];
            last_prediction_time = tic; % Reset timer
        end
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