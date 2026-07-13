function tx_grid = precode_resource_grid(layer_grid, precoder_matrix)
%PRECODERESOURCEGRID Apply precoding to layer resource grid.

[num_subcarriers, num_symbols, num_layers] = size(layer_grid);
num_transmit_antennas = size(precoder_matrix, 1);

layer_grid_2d = reshape(layer_grid, [], num_layers);
tx_grid_2d = layer_grid_2d * transpose(precoder_matrix);
tx_grid = reshape(tx_grid_2d, num_subcarriers, num_symbols, num_transmit_antennas);
end
