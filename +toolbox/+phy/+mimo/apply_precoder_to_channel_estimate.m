function h_eff_grid = apply_precoder_to_channel_estimate(h_grid, precoder_matrix)
%APPLYPRECODERTOCHANNELESTIMATE Apply precoder to antenna-domain channel estimate.

num_subcarriers = size(h_grid, 1);
num_symbols = size(h_grid, 2);
num_receive_antennas = size(h_grid, 3);
num_transmit_antennas = size(h_grid, 4);
num_layers = size(precoder_matrix, 2);

if num_transmit_antennas ~= size(precoder_matrix, 1)
    error("toolbox:InvalidPrecoder", ...
        "Precoder dimension does not match the channel estimate dimensions.");
end

h_eff_grid = zeros( ...
    num_subcarriers, ...
    num_symbols, ...
    num_receive_antennas, ...
    num_layers, ...
    class(h_grid));

for rx_idx = 1:num_receive_antennas
    h_slice = reshape(h_grid(:, :, rx_idx, :), [], num_transmit_antennas);
    h_eff_slice = h_slice * precoder_matrix;
    h_eff_grid(:, :, rx_idx, :) = reshape( ...
        h_eff_slice, num_subcarriers, num_symbols, 1, num_layers);
end
end
