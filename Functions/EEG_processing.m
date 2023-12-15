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

%--------------------------------------------------------------------------------------------------------
% EEG

eeg_fs = 200;
% 4th order Butterworth highpass filter 0.1hz cut off frequency.
[n_eeg,d_eeg] = butter(4,(0.1)/(eeg_fs/2),"high");

% 4th order IIR notch filter with quality factor 30 and 1 dB passband ripple
fo = 4;     % Filter order.
cf = 50/(eeg_fs/2); % Center frequency, value has to be between 0 and 1, where 1 is pi which is the Nyquist frequency which for our signal is Fs/2 = 500Hz.
qf = 30;   % Quality factor.
pbr = 1;   % Passband ripple, dB.
% 50 Hz
notchSpecs  = fdesign.notch('N,F0,Q,Ap',fo,cf * 1,qf,pbr);
notchFilt_50_eeg = design(notchSpecs,'IIR','SystemObject',true);
% 100 Hz
notchSpecs  = fdesign.notch('N,F0,Q,Ap',fo,cf * 2,qf,pbr);
notchFilt_100_eeg = design(notchSpecs,'IIR','SystemObject',true);

while true
    [eeg_data, dataReceived] = poll(EEG_processing_queue, 0);
    if dataReceived
        send(EEG_main_queue, 'Starting Processing');
        tic;
        % Processing...
        % EEG Preprocessing
        % Remove baseline wandering and DC offset
        eeg_data = filter(n_eeg,d_eeg,eeg_data);
        
        % Removal of 50Hz noise and all of it's harmonics up to 100Hz.
        eeg_data = notchFilt_50_eeg(eeg_data);
        eeg_data = notchFilt_100_eeg(eeg_data);
        
        % Remove artifacts from EEG using wavelet enhanced ICA, W-ICA
        % add 'verbose', 'off' in fastica
        send(EEG_main_queue, eeg_data);
        [wIC,A,~,~] = wICA(transpose(eeg_data));
        % Artifacts
        artifacts = transpose(A*wIC);
        % Subtract artifacts from original signal to get "artifact free" signal
        eeg_data = eeg_data - artifacts;
        
        % CSP filter data
        eeg_data = transpose(W'*transpose(eeg_data));
        %--------------------------------------------------------------------------------------------------------
        %--------------------------------------------------------------------------------------------------------
        % EEG Feature Extraction
        eeg_data = log(var(eeg_data)); % Log variance
        %--------------------------------------------------------------------------------------------------------

        % Send to classifier
        send(EEG_main_queue, ['Processing time: ', num2str(toc()*1000), ' ms']);
        send(EEG_classifier_queue, eeg_data);
    end
end
end