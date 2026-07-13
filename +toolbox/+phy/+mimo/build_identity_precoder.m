function precoder_matrix = build_identity_precoder(num_transmit_antennas, num_layers)
%BUILDIDENTITYPRECODER Build identity precoder matrix.

if num_transmit_antennas < num_layers
    error("toolbox:InvalidIdentityPrecoder", ...
        "Identity precoding requires num_transmit_antennas >= num_layers.");
end
precoder_matrix = eye(num_transmit_antennas, num_layers);
end
