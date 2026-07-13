function precoder_matrix = build_hadamard_precoder(num_transmit_antennas, num_layers)
%BUILDHADAMARDPRECODER Build Hadamard-based open-loop precoder matrix.

if num_transmit_antennas < num_layers
    error("toolbox:InvalidHadamardPrecoder", ...
        "Hadamard precoding requires num_transmit_antennas >= num_layers.");
end
try
    base_matrix = hadamard(num_transmit_antennas);
catch err
    error("toolbox:InvalidHadamardPrecoder", ...
        "Hadamard precoding requires a supported Hadamard order; got %d Tx antennas. Original error: %s", ...
        num_transmit_antennas, err.message);
end
precoder_matrix = base_matrix(:, 1:num_layers) / sqrt(num_transmit_antennas);
end
