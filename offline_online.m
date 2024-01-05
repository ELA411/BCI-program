offline_emg_data = load("Datasets/EEG/EEG_Carl-Run_2024-01-05_131720.txt"); % EMG data set (expected column format: channels, labels, package ID, timestamp. Each row is expected to be subsequent observations)
online_emg_data = load("Datasets/Brainflow/Brainflow_Carl-Run_EEG_2024-01-05_131724.txt");
figure
plot(offline_emg_data(:,1), 'r--')
hold on
plot(online_emg_data(:,2), 'g')