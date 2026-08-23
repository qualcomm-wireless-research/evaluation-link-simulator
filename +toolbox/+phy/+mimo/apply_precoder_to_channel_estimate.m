function h_eff_grid = apply_precoder_to_channel_estimate(h_grid, precoder)
%APPLYPRECODERTOCHANNELESTIMATE Fold a precoder into an antenna-domain channel estimate.
%   H_EFF_GRID = APPLYPRECODERTOCHANNELESTIMATE(H_GRID, PRECODER) applies
%   PRECODER to the antenna-domain channel estimate H_GRID (size
%   [nsc, nsym, nrx, ntx]) and returns the effective layer-domain channel
%   H_EFF_GRID (size [nsc, nsym, nrx, nlayers]), used by the receiver to
%   equalize against the effective (precoded) channel.
%
%   PRECODER may be:
%     - a wideband precoder matrix [ntx, nlayers], applied uniformly to every
%       subcarrier, or
%     - a per-subcarrier precoder array [ntx, nlayers, nsc] (constant across
%       symbols) -- used by closed-loop per-subband precoding.

if ndims(precoder) == 3
    h_eff_grid = apply_precoder_freq(h_grid, precoder);
else
    h_eff_grid = apply_precoder_wideband(h_grid, precoder);
end
end

function h_eff_grid = apply_precoder_wideband(h_grid, precoder_matrix)
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

function h_eff_grid = apply_precoder_freq(h_grid, p_freq)
num_subcarriers = size(h_grid, 1);
num_symbols = size(h_grid, 2);
num_receive_antennas = size(h_grid, 3);
num_transmit_antennas = size(h_grid, 4);
num_layers = size(p_freq, 2);

if size(p_freq, 1) ~= num_transmit_antennas || size(p_freq, 3) ~= num_subcarriers
    error("toolbox:InvalidPrecoderFreq", ...
        "P_freq dimensions must be [ntx, nlayers, nsc] matching the channel estimate.");
end

h_eff_grid = zeros( ...
    num_subcarriers, ...
    num_symbols, ...
    num_receive_antennas, ...
    num_layers, ...
    class(h_grid));

for k = 1:num_subcarriers
    precoder = p_freq(:, :, k);                        % [ntx, nlayers]
    for rx_idx = 1:num_receive_antennas
        % Channel for this subcarrier/rx across symbols: [nsym, ntx].
        h_slice = reshape(h_grid(k, :, rx_idx, :), num_symbols, num_transmit_antennas);
        h_eff_slice = h_slice * precoder;              % [nsym, nlayers]
        h_eff_grid(k, :, rx_idx, :) = reshape(h_eff_slice, 1, num_symbols, 1, num_layers);
    end
end
end
