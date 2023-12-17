clear, clc;
name = 'Pontus';
setting = 'COMBINED';
session = [name,'-', setting];
% Initialize DAQ
d = daq("ni");
d.Rate = 1000; % Set sampleRate
addinput(d, "myDAQ1", 0:1, "Voltage"); % Set channels to read from ai0, ai1
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HHmmss'); % Format as 'YYYYMMDD_HHMMSS'
fileNameEMG = ['../Datasets/EMG/EMG_',session,'_',char(currentDateTime),'.txt'];

fileIDEMG = fopen(fileNameEMG, "w");
% ---------------------------------------------------------------------
% Init brainflow
% ---------------------------------------------------------------------
params = BrainFlowInputParams();
preset = int32(BrainFlowPresets.DEFAULT_PRESET);

% ---------------------------------------------------------------------
% Specify the serialport and mac address for brainflow
% ---------------------------------------------------------------------
params.serial_port = 'COM9';

% ---------------------------------------------------------------------
% Create the board_shim class
% ---------------------------------------------------------------------
board_shim = BoardShim(int32(BoardIds.GANGLION_BOARD), params);

% ---------------------------------------------------------------------
% prepare BrainFlow’s streaming session, allocate required resources
% ---------------------------------------------------------------------
board_shim.prepare_session();

% ---------------------------------------------------------------------
% add streamer
% ---------------------------------------------------------------------
currentDateTime = datetime('now','Format', 'yyyy-MM-dd_HHmmss'); % Format as 'YYYYMMDD_HHMMSS'
fileName = ['file://../Datasets/Brainflow/Brainflow_',session,'_EEG_',char(currentDateTime),'.txt:w'];
fileNameEEG = ['../Datasets/EEG/EEG_',session,'_',char(currentDateTime),'.txt'];

fileIDEEG = fopen(fileNameEEG, "w");
board_shim.add_streamer(fileName, preset);
eegBuffer = []; % Buffer to store temporary values for data quality calculation
eegBufferProcessing = [];
col = 1;

board_shim.start_stream(10000, '');
% ---------------------------------------------------------------------
% Main loop
% ---------------------------------------------------------------------
labelTime = tic;
runtime = tic;
label = 0;
EmgPrintLabel = 0;
EegPrintLabel = 0;
reps = 0;
ID = 0;
pause(4); % Make sure we get output first
start(d,"continuous");
while true
    [scanData, timeStamp] = read(d, seconds(0.001), "OutputFormat","Matrix");

    dataInBuffer = board_shim.get_board_data_count(preset); % Check how many samples are in the buffer

    if toc(labelTime) >= 4
        if reps == 30
            disp(['REP: ', num2str(reps), ' Dataset completed']);
            break;
        end

        if label == 0
            fprintf("\n");
            disp(['REP: ', num2str(reps + 1),' REST', ' Label: ', num2str(label)]);
            EmgPrintLabel = 0;
            EegPrintLabel = 0;

        elseif label == 1
            fprintf("\n");
            disp(['REP: ', num2str(reps + 1),' EXTENSION',' Label: ', num2str(label)]);
            EmgPrintLabel = 1;
            EegPrintLabel = 0;

        elseif label == 2
            fprintf("\n");
            disp(['REP: ', num2str(reps + 1),' REST', ' Label: ', num2str(0)]);
            EmgPrintLabel = 0;
            EegPrintLabel = 0;

        elseif label == 3
            fprintf("\n");
            disp(['REP: ', num2str(reps + 1),' FLEXION',' Label: ', num2str(2)]);
            EmgPrintLabel = 2;
            EegPrintLabel = 0;
        elseif label == 4
            fprintf("\n");
            disp(['REP: ', num2str(reps + 1),' REST', ' Label: ', num2str(0)]);
            EegPrintLabel = 0;
            EmgPrintLabel = 0;
        else
            fprintf("\n");
            disp(['REP: ', num2str(reps + 1),' MI CLOSE',' Label: ', num2str(1)]);
            EegPrintLabel = 1;
            reps = reps + 1;
        end
        label = mod(label + 1, 6); % Toggle label
        labelTime = tic; % Reset timer
    end

    if dataInBuffer > 0
        data = board_shim.get_board_data(1, preset); % Take available packages and remove them from buffer

        pkgID = data(1,col);
        channel1 = data(2,col);
        channel2 = data(3,col);
        channel3 = data(4,col);
        channel4 = data(5,col);
        timestamp = data(14,col);

        fprintf(fileIDEEG, "%f %f %f %f %f %f %f\n", channel1, channel2, channel3, channel4, EegPrintLabel, pkgID, timestamp);
    end

    for i = 1:size(scanData,1)
        fprintf(fileIDEMG, "%f %f %f %f %f\n", scanData(i,1), scanData(i,2), EmgPrintLabel, ID, timeStamp);
        ID = mod(ID + 1, 1000);
    end
end
disp(toc(runtime));
fclose(fileIDEEG);
fclose(fileIDEMG);
board_shim.stop_stream();
board_shim.release_all_sessions();
stop(d);
