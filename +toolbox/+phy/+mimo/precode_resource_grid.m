function tx_grid = precode_resource_grid(layer_grid, precoder)
%PRECODERESOURCEGRID Apply precoding to a layer resource grid.
%   TX_GRID = PRECODERESOURCEGRID(LAYER_GRID, PRECODER) maps the layer
%   resource grid LAYER_GRID (size [nsc, nsym, nlayers]) to the transmit
%   antenna grid TX_GRID (size [nsc, nsym, ntx]).
%
%   PRECODER may be:
%     - a wideband precoder matrix [ntx, nlayers], applied uniformly to every
%       subcarrier, or
%     - a per-subcarrier precoder array [ntx, nlayers, nsc] (constant across
%       symbols), applying a distinct precoder per subcarrier -- used by
%       closed-loop per-subband precoding.

if ndims(precoder) == 3
    tx_grid = precode_freq(layer_grid, precoder);
else
    tx_grid = precode_wideband(layer_grid, precoder);
end
end

function tx_grid = precode_wideband(layer_grid, precoder_matrix)
[num_subcarriers, num_symbols, num_layers] = size(layer_grid);
num_transmit_antennas = size(precoder_matrix, 1);

layer_grid_2d = reshape(layer_grid, [], num_layers);
tx_grid_2d = layer_grid_2d * transpose(precoder_matrix);
tx_grid = reshape(tx_grid_2d, num_subcarriers, num_symbols, num_transmit_antennas);
end

function tx_grid = precode_freq(layer_grid, p_freq)
[num_subcarriers, num_symbols, num_layers] = size(layer_grid);
num_transmit_antennas = size(p_freq, 1);

if size(p_freq, 2) ~= num_layers || size(p_freq, 3) ~= num_subcarriers
    error("toolbox:InvalidPrecoderFreq", ...
        "P_freq dimensions must be [ntx, nlayers, nsc] matching the layer grid.");
end

tx_grid = zeros(num_subcarriers, num_symbols, num_transmit_antennas, class(layer_grid));

for k = 1:num_subcarriers
    % Layer symbols on this subcarrier: [nlayers, nsym]; precoder: [ntx, nlayers].
    layer_symbols = reshape(layer_grid(k, :, :), num_symbols, num_layers).';
    tx_symbols = p_freq(:, :, k) * layer_symbols;      % [ntx, nsym]
    tx_grid(k, :, :) = reshape(tx_symbols.', 1, num_symbols, num_transmit_antennas);
end
end
