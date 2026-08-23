function [rx_grid, h_est_grid, n_var, h_est_domain] = receive_grid( ...
    carrier, channel_filter, rx_waveform_noiseless, tx_grid, ...
    path_gains, path_filters, receiver_cfg, ...
    dmrs_ind, dmrs_sym, dmrs_cdm_lengths, sample_time, ...
    snr_db, nfft, num_receive_antennas)
%RECEIVEGRID Demodulate received waveform and perform channel estimation.

timing_offset = nrPerfectTimingEstimate(path_gains, path_filters);
timing_offset = min(timing_offset, size(rx_waveform_noiseless, 1) - 1);

switch channel_filter
    case 'td'
        noise_waveform = toolbox.phy.channel.generate_awgn( ...
            size(rx_waveform_noiseless), snr_db, nfft, num_receive_antennas);

        rx_waveform = rx_waveform_noiseless + noise_waveform;
        rx_waveform = rx_waveform((1 + timing_offset):end, :);
        noise_waveform = noise_waveform((1 + timing_offset):end, :);

        rx_grid = nrOFDMDemodulate(carrier, rx_waveform);
        noise_grid = nrOFDMDemodulate(carrier, noise_waveform);
        n_var = mean(abs(noise_grid(:)).^2);
    case 'fd'
        h_grid = nrPerfectChannelEstimate( ...
            carrier, path_gains, path_filters, timing_offset, sample_time);
        rx_grid_noiseless = sum(h_grid .* permute(tx_grid, [1, 2, 4, 3]), 4);
        noise_grid = toolbox.phy.channel.generate_awgn( ...
            size(rx_grid_noiseless), snr_db, 1, num_receive_antennas);
        rx_grid = rx_grid_noiseless + noise_grid;
        n_var = mean(abs(noise_grid(:)).^2);
end

switch lower(char(receiver_cfg.channelEstimation))
    case 'perfect'
        h_est_grid = nrPerfectChannelEstimate( ...
            carrier, path_gains, path_filters, timing_offset, sample_time);
        h_est_domain = "antenna";
    otherwise
        error("toolbox:UnsupportedChannelEstimation", ...
            "Unsupported channel estimation mode '%s'.", ...
            receiver_cfg.channelEstimation);
end

end
