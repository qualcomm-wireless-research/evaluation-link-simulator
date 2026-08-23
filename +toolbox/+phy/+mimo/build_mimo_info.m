function mimo_info = build_mimo_info(cfg, pdsch)
%BUILDMIMOINFO Build MIMO configuration and precoder matrix.

num_layers = pdsch.NumLayers;
num_transmit_antennas = cfg.mimo.numTransmitAntennas;
precoding_mode = lower(char(string(cfg.mimo.precodingMode)));

closed_loop = struct('enabled', false);

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

    case 'closedloop'
        % The applied precoder is computed per slot inside the SNR/TB loop from
        % genie CSI. Here we only build the wideband warm-up fallback used
        % before the first valid CSI report arrives, and record the closed-loop
        % parameters for the loop scheduler.
        cl = cfg.mimo.closedLoop;
        warmup_precoder = lower(char(string(cl.warmupPrecoder)));
        switch warmup_precoder
            case 'dft'
                precoder_matrix = toolbox.phy.mimo.build_dft_precoder(num_transmit_antennas, num_layers);
            case 'identity'
                precoder_matrix = toolbox.phy.mimo.build_identity_precoder(num_transmit_antennas, num_layers);
            case 'hadamard'
                precoder_matrix = toolbox.phy.mimo.build_hadamard_precoder(num_transmit_antennas, num_layers);
            otherwise
                error("toolbox:UnsupportedWarmupPrecoder", ...
                    "Unsupported closed-loop warmup precoder '%s'.", cl.warmupPrecoder);
        end

        closed_loop = struct( ...
            'enabled', true, ...
            'method', string(lower(char(string(cl.method)))), ...
            'subbandSize', cl.subbandSize, ...
            'periodicitySlots', cl.periodicitySlots, ...
            'processingDelaySlots', cl.processingDelaySlots, ...
            'warmupPrecoder', string(warmup_precoder), ...
            'combSize', cl.combSize, ...
            'combOffset', cl.combOffset, ...
            'csiSymbol', cl.csiSymbol);

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
mimo_info.closedLoop = closed_loop;
end
