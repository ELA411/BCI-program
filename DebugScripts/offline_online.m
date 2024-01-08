offline_emg_data = load("Datasets/EMG/EMG_Pontus-Ch_1_longitude_Ch_2_transverse_2024-01-05_180125.txt"); % EMG data set (expected column format: channels, labels, package ID, timestamp. Each row is expected to be subsequent observations)
online_emg_data = load("Datasets/EMG/EMG_Pontus-Online-Run_2024-01-05_182541.txt");
% Find the length of online data
online_length = size(online_emg_data, 1);

% Trim the offline data to match the online data length
trimmed_offline_data = offline_emg_data(1:online_length, 1);

% Plot the data
figure
plot(online_emg_data(:,2), 'g') % Online data with green circles as markers
hold on
plot(trimmed_offline_data, 'r') % Offline data
legend("Online","Offline")
title("Pontus: RAW EMG")