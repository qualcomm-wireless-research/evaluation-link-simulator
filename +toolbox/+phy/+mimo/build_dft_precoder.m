function precoder_matrix = build_dft_precoder(num_transmit_antennas, num_layers)
%BUILDDFTPRECODER Build DFT-based open-loop precoder matrix.

antenna_indices = (0:(num_transmit_antennas - 1)).';
layer_indices = 0:(num_layers - 1);
precoder_matrix = exp( ...
    -1j * 2 * pi * antenna_indices * layer_indices / num_transmit_antennas) ...
    / sqrt(num_transmit_antennas);
end
