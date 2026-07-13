function noise_waveform = generate_awgn(waveform_size, snr_db, nfft, num_receive_antennas)
%GENERATEAWGN Generate AWGN noise waveform with specified SNR.

snr_linear = 10^(snr_db / 10);
sigma = 1 / sqrt(2 * num_receive_antennas * double(nfft) * snr_linear);
noise_waveform = sigma * complex(randn(waveform_size), randn(waveform_size));
end
