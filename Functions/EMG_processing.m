% Script Name: EMG_processing.m
% Author: Pontus Svensson
% Date: 2023-12-14
% Version: 1.0.0
% License:
%
% Description:
% ---------------------------------------------------------------------
function EMG_processing(EMG_main_queue, EMG_classifier_queue)
EMG_processing_queue = parallel.pool.PollableDataQueue; % Queue for processing
send(EMG_main_queue, EMG_processing_queue);
% emg_data = [];
% numSamples = 0;
emg_fs = 1000;
%--------------------------------------------------------------------------------------------------------
% EMG

% 20–500Hz fourth-order Butterworth bandpass filter.
[n_emg,d_emg] = butter(4,[20 499]/(emg_fs/2),"bandpass");

% 4th order IIR notch filter with quality factor 30 and 1 dB passband ripple
fo = 4;     % Filter order.
cf = 50/(emg_fs/2); % Center frequency, value has to be between 0 and 1, where 1 is pi which is the Nyquist frequency which for our signal is Fs/2 = 500Hz.
qf = 30;   % Quality factor.
pbr = 1;   % Passband ripple, dB.
% 50 Hz
notchSpecs  = fdesign.notch('N,F0,Q,Ap',fo,cf * 1,qf,pbr);
notchFilt_50_emg = design(notchSpecs,'IIR','SystemObject',true);
% 100 Hz
notchSpecs  = fdesign.notch('N,F0,Q,Ap',fo,cf * 2,qf,pbr);
notchFilt_100_emg = design(notchSpecs,'IIR','SystemObject',true);
% 150 Hz
notchSpecs  = fdesign.notch('N,F0,Q,Ap',fo,cf * 3,qf,pbr);
notchFilt_150_emg = design(notchSpecs,'IIR','SystemObject',true);
debug_message = "Processing started";
while true
    [emg_data, dataReceived] = poll(EMG_processing_queue, 0);
    if dataReceived
        % send(EMG_main_queue, debug_message);
        tic; % Start timer
        % Processing...
        %--------------------------------------------------------------------------------------------------------
        % EMG Preprocessing
        % Removal of the 0Hz(the DC offset) and high frequency noise.
        % send(EMG_main_queue, 'Filtering');
        emg_data = filter(n_emg,d_emg,emg_data);
        
        % Removal of 50Hz noise and all of it's harmonics up to 150Hz. 
        % send(EMG_main_queue, 'Notch Filtering 50');
        emg_data = notchFilt_50_emg(emg_data);
        % send(EMG_main_queue, 'Notch Filtering 100');
        emg_data = notchFilt_100_emg(emg_data);
        % send(EMG_main_queue, 'Notch Filtering 150');

        emg_data = notchFilt_150_emg(emg_data);
       
        % EMG Feature Extraction
        % send(EMG_main_queue, 'Feature Extraction');
        f_mav = jfemg('mav', emg_data); % Mean absolut value returns for 2 channels
        f_wl = jfemg('wl', emg_data); % Waveform length
        f_zc = jfemg('zc', emg_data); % Zero crossing
        f_ssc = jfemg('ssc', emg_data); % Slope sign change
        opts.order = 1; % Defines output dimension
        f_ar = jfemg('ar', emg_data, opts); % Auto regressive
        
        emg_feature_extraction = [f_mav(1,1), f_wl, f_zc, f_ssc, f_ar];
        % Calculate sample rate
        % numSamples = size(emg_data, 1); % Assuming dataToProcess is organized with one sample per row
        % if numSamples > 0
        %     elapsedTime = toc; % Get elapsed time
        %     sampleRate = numSamples / elapsedTime;
        %     toSend = ['EMG_processing: samples after feature extraction ', num2str(numSamples),' Processing time: ', num2str(sampleRate)];
        %     send(EMG_main_queue, toSend); % Calculate processing time
        % end
        % Send to classifier
        % send(EMG_main_queue, 'Send processed data to classifier');
        send(EMG_main_queue, ['EMG Processing Time ', num2str(toc()*1000),' ms']);
        send(EMG_classifier_queue, emg_feature_extraction);
        % send(EMG_main_queue, debug_message);
        % emg_data = [];
    end
end
end