function mimo_info = build_mimo_info(cfg, pdsch)
%BUILDMIMOINFO Build MIMO configuration and precoder matrix.

num_layers = pdsch.NumLayers;
num_transmit_antennas = cfg.mimo.numTransmitAntennas;
precoding_mode = lower(char(string(cfg.mimo.precodingMode)));

switch precoding_mode
    case 'none'
        precoder_matrix = eye(num_transmit_antennas, num_layers);

    case 'openloop'
        open_loop_precoder = lower(char(string(cfg.mimo.openLoopPrecoder)));
        switch open_loop_precoder
            case 'dft'
                precoder_matrix = toolbox.phy.mimo.build_dft_precoder(num_transmit_antennas, num_layers);
            case 'identity'
                precoder_matrix = toolbox.phy.mimo.build_identity_precoder(num_transmit_antennas, num_layers);
            case 'hadamard'
                precoder_matrix = toolbox.phy.mimo.build_hadamard_precoder(num_transmit_antennas, num_layers);
            otherwise
                error("toolbox:UnsupportedOpenLoopPrecoder", ...
                    "Unsupported open-loop precoder '%s'.", cfg.mimo.openLoopPrecoder);
        end

    otherwise
        error("toolbox:UnsupportedPrecodingMode", ...
            "Unsupported mimo.precodingMode '%s'.", cfg.mimo.precodingMode);
end

precoder_matrix = precoder_matrix / norm(precoder_matrix, 'fro');

mimo_info = struct();
mimo_info.precodingMode = string(precoding_mode);
mimo_info.numLayers = num_layers;
mimo_info.numTransmitAntennas = num_transmit_antennas;
mimo_info.openLoopPrecoder = string(cfg.mimo.openLoopPrecoder);
mimo_info.precoderMatrix = precoder_matrix;
end
