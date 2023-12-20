function [alpha, beta] = Extract_psd(eeg_data)
    extracted_data = fft(eeg_data);
    alpha = extracted_data(:,9:1:12);
    beta = extracted_data(:, 12:30);
end