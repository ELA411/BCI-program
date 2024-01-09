% Script Name: EMG_features_online_vs_offline.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% 
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
offline = load("Datasets/EMG/EMG_Pontus-Ch_1_longitude_Ch_2_transverse_2024-01-05_180125.txt");
online = load("Datasets/EMG/EMG_Pontus-Online-Run_2024-01-05_182541.txt");
raw_emg_data = {offline, online};

emg_fs = 1000; % Replace with your actual sampling frequency

% Process both datasets
emg_features_offline = process_emg(raw_emg_data{1}, emg_fs);
emg_features_online = process_emg(raw_emg_data{2}, emg_fs);

% Plotting features
% Channel 1
figure;
subplot(2,1,1);
plot(emg_features_offline(:, 1:5));
title('Offline Dataset - Channel 1 Features');
legend('MAV', 'WL', 'ZC', 'SSC', 'AR');

subplot(2,1,2);
plot(emg_features_online(:, 1:5));
title('Online Dataset - Channel 1 Features');
legend('MAV', 'WL', 'ZC', 'SSC', 'AR');

% Channel 2
figure;
subplot(2,1,1);
plot(emg_features_offline(:, 6:10));
title('Offline Dataset - Channel 2 Features');
legend('MAV', 'WL', 'ZC', 'SSC', 'AR');

subplot(2,1,2);
plot(emg_features_online(:, 6:10));
title('Online Dataset - Channel 2 Features');
legend('MAV', 'WL', 'ZC', 'SSC', 'AR');

% Plotting raw data comparison
figure;
subplot(2,1,1);
plot(raw_emg_data{1}(:, 1), 'b'); hold on;
plot(raw_emg_data{2}(:, 1), 'r');
title('Raw EMG Data - Channel 1');
legend('Offline', 'Online');
hold off;

subplot(2,1,2);
plot(raw_emg_data{1}(:, 2), 'b'); hold on;
plot(raw_emg_data{2}(:, 2), 'r');
title('Raw EMG Data - Channel 2');
legend('Offline', 'Online');
hold off;
% Function for processing, windowing, and feature extraction
function emg_features = process_emg(raw_emg, fs)
    % Filter design
    [n, d] = butter(4, [20 499]/(fs/2), 'bandpass');
    filtered_emg_data = filter(n, d, raw_emg(:, 1:2));

    % Notch filter for powerline noise removal
    fo = 4; % Filter order
    cf = 50/(fs/2); % Center frequency
    qf = 30; % Quality factor
    pbr = 1; % Passband ripple in dB
    for harmonic = 1:3
        notchSpecs = fdesign.notch('N,F0,Q,Ap', fo, cf * harmonic, qf, pbr);
        notchFilt = design(notchSpecs, 'IIR', 'SystemObject', true);
        filtered_emg_data = notchFilt(filtered_emg_data);
    end

    % Windowing parameters
    window_size = 0.250; % window size in seconds
    overlap = 0.025; % overlap in seconds

    % Windowing and feature extraction
    [emg_1, ~] = buffer(filtered_emg_data(:,1), window_size * fs, (overlap) * fs, 'nodelay');
    [emg_2, ~] = buffer(filtered_emg_data(:,2), window_size * fs, (overlap) * fs, 'nodelay');
    [~, col_size] = size(emg_1);
    emg_1_features = zeros(col_size, 5); % Preallocate for channel 1
    emg_2_features = zeros(col_size, 5); % Preallocate for channel 2

    for window = 1:col_size
        % Extract features for Channel 1
        f_mav_1 = jfemg('mav', emg_1(:,window));
        f_wl_1 = jfemg('wl', emg_1(:,window));
        f_zc_1 = jfemg('zc', emg_1(:,window));
        f_ssc_1 = jfemg('ssc', emg_1(:,window));
        opts.order = 1;
        f_ar_1 = jfemg('ar', emg_1(:,window), opts);
        emg_1_features(window,:) = [f_mav_1, f_wl_1, f_zc_1, f_ssc_1, f_ar_1];

        % Extract features for Channel 2
        f_mav_2 = jfemg('mav', emg_2(:,window));
        f_wl_2 = jfemg('wl', emg_2(:,window));
        f_zc_2 = jfemg('zc', emg_2(:,window));
        f_ssc_2 = jfemg('ssc', emg_2(:,window));
        f_ar_2 = jfemg('ar', emg_2(:,window), opts);
        emg_2_features(window,:) = [f_mav_2, f_wl_2, f_zc_2, f_ssc_2, f_ar_2];
    end
    emg_features = [emg_1_features, emg_2_features];
end