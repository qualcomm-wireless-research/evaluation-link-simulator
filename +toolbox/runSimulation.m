function results = runSimulation(cfg)
%RUNSIMULATION Simulate DL PDSCH BLER and throughput for a given SNR and a config.

cfg = toolbox.defaultConfig(cfg);
tbs_match = struct('enabled', false);
if logical(cfg.shaping.enabled) && logical(cfg.shaping.matchUniformTbs)
    tbs_match = toolbox.ProbShaping.provider.match_ps_nu_to_uniform_tbs( ...
        cfg, ...
        'UniformMcsTable', cfg.shaping.uniformMcsTable, ...
        'PsMcsTable', cfg.shaping.mcsTable, ...
        'Levels', cfg.shaping.numShapedAmplitudeBitLevelsPerDimension, ...
        'ToleranceFraction', cfg.shaping.tbsMatchToleranceFraction, ...
        'MaxIterations', cfg.shaping.tbsMatchMaxIterations);
    tbs_match.enabled = true;
    cfg.shaping.useMcsTableNu = false;
    cfg.shaping.nu = tbs_match.nu;
end
[mcs_info, effective_shaping_nu] = toolbox.resolveMcsInfo(cfg);
cfg.shaping.nu = effective_shaping_nu;
toolbox.config.validate_config(cfg);
toolbox.config.require_5g_toolbox();

% Build static NR objects and resource allocations. These do not change across
% SNR points or transport blocks for a fixed-MCS sweep.
[carrier, pdsch] = toolbox.phy.pdsch.build_link_objects(cfg, mcs_info); % set up pdsch and dmrs parameters.
mimo_info = toolbox.phy.mimo.build_mimo_info(cfg, pdsch); % setup mimo parameters.
[pdsch_ind, pdsch_info] = nrPDSCHIndices(carrier, pdsch);
dmrs_ind = nrPDSCHDMRSIndices(carrier, pdsch);
dmrs_sym = nrPDSCHDMRS(carrier, pdsch);

num_tb_bits_cw = nrTBS( ...
    pdsch.Modulation, ...
    pdsch.NumLayers, ...
    numel(pdsch.PRBSet), ...
    pdsch_info.NREPerPRB, ...
    mcs_info.targetCodeRate, ...
    0);

ps_info = toolbox.ProbShaping.tbgen.init(cfg, carrier, pdsch, mcs_info, pdsch_info, num_tb_bits_cw);
num_tb_info_bits = ps_info.payloadTransportBlockLength;

% Preallocate empty grids and derive OFDM metadata once.
slot_duration_ms = toolbox.phy.channel.get_slot_duration_ms(cfg.carrier.subcarrierSpacingKHz);
zero_layer_grid = nrResourceGrid(carrier, pdsch.NumLayers);
zero_tx_grid = nrResourceGrid(carrier, mimo_info.numTransmitAntennas);
[~, ofdm_info] = nrOFDMModulate(carrier, zero_tx_grid);

% Select the propagation model (AWGN or TDL).
channel_model = "tdl";
if isfield(cfg.channel, 'model')
    channel_model = lower(string(cfg.channel.model));
elseif strcmpi(char(string(cfg.channel.delayProfile)), 'awgn')
    channel_model = "awgn";
end

if channel_model == "awgn"
    channel = [];
    path_filters = [];
    max_ch_delay = 0;
else
    channel = toolbox.phy.channel.create_tdl_channel(cfg, mimo_info.numTransmitAntennas, ofdm_info.SampleRate);
    channel_info = info(channel);
    path_filters = getPathFilters(channel);
    max_ch_delay = ceil(max(channel_info.PathDelays * channel.SampleRate)) ...
        + channel_info.ChannelFilterDelay;
end

% Both uniform NR and PS use nrDLSCH for transport-chain encoding. Create the
% encoder once before the SNR loop; PS only differs in the TB it feeds in.
% Encoding chain (CRC insertion, CB segmentation, encoding, rate matching, SBPM)
% are identical between PS and uniform QAM
dlsch_encoder = nrDLSCH;
dlsch_encoder.TargetCodeRate = mcs_info.targetCodeRate;

% Both uniform and PS paths end at the standard NR TB-CRC decoder. The PS differs only in the scrambling step, which is handled in ps_scramble.m
dlsch_decoder = nrDLSCHDecoder;
dlsch_decoder.TargetCodeRate = mcs_info.targetCodeRate;
dlsch_decoder.TransportBlockLength = num_tb_bits_cw;
dlsch_decoder.MaximumLDPCIterationCount = cfg.receiver.maxLdpcIterations;
dlsch_decoder.LDPCDecodingAlgorithm = cfg.receiver.LDPCDecodingAlgorithm;

% Initialize sphere decoder once before the SNR loop for efficiency.
if strcmpi(cfg.receiver.demapper, 'sphere')
    sphere_decoder_obj = toolbox.phy.receiver.initialize_sphere_decoder(...
        pdsch.Modulation, ...
        cfg.receiver.sphereAlgorithm, ...
        cfg.receiver.sphereRadius);
else
    sphere_decoder_obj = [];
end

% PS retransmissions fall back to the uniform table's modulation order (rate
% unchanged). Precompute the retransmission modulation/G/sphere decoder once
% here so the TB loop can swap them in/out like ps_info.enabled.
if cfg.simulation.maxNumTransmissions > 1
    if ps_info.enabled
        ps_retx_mcs_info = toolbox.getMcsInfo(cfg.pdsch.mcsIndex, cfg.shaping.uniformMcsTable);
        ps_retx_modulation = ps_retx_mcs_info.modulation;
        ps_retx_pdsch_info_G = numel(pdsch_ind) * toolbox.phy.pdsch.bits_per_symbol(ps_retx_modulation);
        if strcmpi(cfg.receiver.demapper, 'sphere')
            ps_retx_sphere_decoder_obj = toolbox.phy.receiver.initialize_sphere_decoder(...
                ps_retx_modulation, ...
                cfg.receiver.sphereAlgorithm, ...
                cfg.receiver.sphereRadius);
        else
            ps_retx_sphere_decoder_obj = [];
        end
        retx_mcs_table_name = ps_retx_mcs_info.table;
        retx_coded_bits = ps_retx_pdsch_info_G;
    else
        retx_mcs_table_name = mcs_info.table;
        retx_coded_bits = pdsch_info.G;
    end
end

snr_points = cfg.simulation.snrDb(:);
num_points = numel(snr_points);
snr_stats(num_points, 1) = struct( ...
    "snrDb", 0, ...
    "bler", 0, ...
    "throughputMbps", 0, ...
    "tbSizeBits", 0, ...
    "codedBits", 0, ...
    "meanTxSymbolEnergy", 0, ...
    "meanTxPowerScaling", 0, ...
    "meanNoiseVariance", 0);

for idx = 1:num_points
    % Use the configured seed per SNR point so different chain variants are
    % reproducible and comparable at the same SNR.
    rng(cfg.simulation.rngSeed);
    if ~isempty(channel)
        reset(channel);
    end

    snr_tic = tic;
    trans_blocks = 0;
    block_errors = 0;
    successful_blocks = 0;
    noise_variance_accum = 0;
    tx_symbol_energy_accum = 0;
    tx_power_scaling_accum = 0;

    for tb_idx = 1:cfg.simulation.numTransportBlocks
        reset(dlsch_decoder);


        % TX data path:
        % - Uniform: random TB -> nrDLSCH -> shared new_pdsch mapper.
        % - PS: prestructured PS TB -> nrDLSCH -> shared new_pdsch mapper.
        if ~ps_info.enabled
            tb = randi([0 1], num_tb_bits_cw, 1, 'int8');
        else
            % PS uses a prestructured TB so the shaped amplitude bits land at the
            % known per-CB positions inside nrDLSCH segmentation.
            tb = toolbox.ProbShaping.tbgen.build_tb_for_ps(ps_info);
        end

        setTransportBlock(dlsch_encoder, tb);

        % HARQ transmission
        ps_enabled_init = ps_info.enabled;   % For inital transmission
        pdsch_modulation_init = pdsch.Modulation;
        pdsch_info_G_init = pdsch_info.G;
        sphere_decoder_obj_init = sphere_decoder_obj;
        for trans_idx = 1:cfg.simulation.maxNumTransmissions

            % PS retransmissions: fall back to uniform QAM.
            if ps_info.enabled && trans_idx > 1
               ps_info.enabled = false;
               pdsch.Modulation = ps_retx_modulation;
               pdsch_info.G = ps_retx_pdsch_info_G;
               sphere_decoder_obj = ps_retx_sphere_decoder_obj;
            end

            cw = dlsch_encoder(pdsch.Modulation,pdsch.NumLayers, ...
                pdsch_info.G, cfg.pdsch.rv(trans_idx));

            tx_layer_grid = zero_layer_grid;
            [pdsch_symbols, pdsch_tx_info] = toolbox.phy.pdsch.new_pdsch( ...
                carrier, pdsch, cw, ps_info);
            tx_layer_grid(pdsch_ind) = pdsch_symbols;
            tx_symbol_energy_accum = tx_symbol_energy_accum + pdsch_tx_info.averageSymbolEnergy;
            tx_power_scaling_accum = tx_power_scaling_accum + pdsch_tx_info.psPowerScaling;
            if ps_info.enabled
                ps_info.psPowerScaling = pdsch_tx_info.psPowerScaling;
            end

            % Common grid/waveform path: precode layers to antennas and OFDM-modulate, then pass through AWGN or TDL plus AWGN.
            tx_layer_grid(dmrs_ind) = dmrs_sym;
            tx_grid = toolbox.phy.mimo.precode_resource_grid(tx_layer_grid, mimo_info.precoderMatrix);

            tx_waveform = nrOFDMModulate(carrier, tx_grid);
            tx_waveform = [tx_waveform; zeros(max_ch_delay, mimo_info.numTransmitAntennas)];

            if channel_model == "awgn"
                awgn_channel_matrix = ones( ...
                    mimo_info.numTransmitAntennas, cfg.channel.numReceiveAntennas);
                if mimo_info.numTransmitAntennas > 1
                    awgn_channel_matrix = zeros( ...
                        mimo_info.numTransmitAntennas, cfg.channel.numReceiveAntennas);
                    num_awgn_spatial_streams = min( ...
                        mimo_info.numTransmitAntennas, cfg.channel.numReceiveAntennas);
                    awgn_channel_matrix( ...
                        1:num_awgn_spatial_streams, 1:num_awgn_spatial_streams) = ...
                        eye(num_awgn_spatial_streams);
                end
                rx_waveform_noiseless = tx_waveform * awgn_channel_matrix;
                noise_waveform = toolbox.phy.channel.generate_awgn( ...
                    size(rx_waveform_noiseless), ...
                    snr_points(idx), ...
                    ofdm_info.Nfft, ...
                    cfg.channel.numReceiveAntennas);
                rx_waveform = rx_waveform_noiseless + noise_waveform;
                rx_grid = nrOFDMDemodulate(carrier, rx_waveform);
                noise_grid = nrOFDMDemodulate(carrier, noise_waveform);
                n_var = mean(abs(noise_grid(:)).^2);
                h_est_grid_raw = zeros( ...
                    size(rx_grid, 1), ...
                    size(rx_grid, 2), ...
                    cfg.channel.numReceiveAntennas, ...
                    mimo_info.numTransmitAntennas);
                for rx_idx = 1:cfg.channel.numReceiveAntennas
                    for tx_idx = 1:mimo_info.numTransmitAntennas
                        h_est_grid_raw(:, :, rx_idx, tx_idx) = ...
                            awgn_channel_matrix(tx_idx, rx_idx);
                    end
                end
                h_est_domain = "antenna";
            else
                [rx_waveform_noiseless, path_gains] = channel(tx_waveform);
                noise_waveform = toolbox.phy.channel.generate_awgn( ...
                    size(rx_waveform_noiseless), ...
                    snr_points(idx), ...
                    ofdm_info.Nfft, ...
                    cfg.channel.numReceiveAntennas);

                [rx_grid, h_est_grid_raw, n_var, h_est_domain] = toolbox.phy.channel.receive_grid( ...
                    carrier, ...
                    rx_waveform_noiseless, ...
                    noise_waveform, ...
                    path_gains, ...
                    path_filters, ...
                    cfg.receiver, ...
                    dmrs_ind, ...
                    dmrs_sym, ...
                    pdsch.DMRS.CDMLengths);
            end

            if h_est_domain == "antenna"
                h_est_grid = toolbox.phy.mimo.apply_precoder_to_channel_estimate( ...
                    h_est_grid_raw, mimo_info.precoderMatrix);
            else
                h_est_grid = h_est_grid_raw;
            end

            noise_variance_accum = noise_variance_accum + n_var;

            % Extract PDSCH REs and prepare receiver options used by both uniform
            % and PS demapping paths.
            [pdsch_rx, pdsch_hest] = nrExtractResources(pdsch_ind, rx_grid, h_est_grid);

            rx_cfg = cfg.receiver;
            rx_cfg.modulation = pdsch.Modulation;

            % Sphere detection works directly on the extracted MIMO symbols. Keep
            % the pre-initialized object and raw-grid context in the receiver config.
            if strcmpi(cfg.receiver.demapper, 'sphere')
                rx_cfg.sphereDecoderObj = sphere_decoder_obj;
                rx_cfg.rxGrid = rx_grid;
                rx_cfg.hEstGrid = h_est_grid;
                rx_cfg.pdschInd = pdsch_ind;
            end

            % RX data path:
            % - Uniform: equalize -> shared demod/descramble path.
            % - PS: demod preprocessing/equalize -> shared path.
            dlsch_llrs = toolbox.phy.pdsch.new_pdsch_decode( ...
                carrier, pdsch, pdsch_rx, pdsch_hest, n_var, rx_cfg, ps_info);

            % Both paths terminate at the standard NR TB-CRC decoder; only the
            % decoder-domain LLR source above differs between uniform and PS.
            [~, blk_err] = dlsch_decoder( ...
                dlsch_llrs, ...
                pdsch.Modulation, ...
                pdsch.NumLayers, ...
                cfg.pdsch.rv(trans_idx));

            trans_blocks = trans_blocks + 1;
            if ~any(blk_err)
                successful_blocks = successful_blocks + 1;
                break;  % Stop HARQ
            end
        end

        if any(blk_err)
            block_errors = block_errors + 1;
        end

        ps_info.enabled = ps_enabled_init;  % Reset for inital transmission
        pdsch.Modulation = pdsch_modulation_init;
        pdsch_info.G = pdsch_info_G_init;
        sphere_decoder_obj = sphere_decoder_obj_init;

    end

    % Aggregate BLER/throughput for this SNR point. Throughput uses the effective
    % payload size, which is smaller than num_tb_bits_cw when PS rate loss is present.
    elapsed_seconds = trans_blocks * slot_duration_ms * 1e-3;
    snr_stats(idx).snrDb = snr_points(idx);
    snr_stats(idx).bler = block_errors / cfg.simulation.numTransportBlocks;
    snr_stats(idx).throughputMbps = successful_blocks * num_tb_info_bits ...
        / elapsed_seconds / 1e6;
    snr_stats(idx).tbSizeBits = num_tb_info_bits;
    snr_stats(idx).codedBits = pdsch_info.G;
    snr_stats(idx).meanTxSymbolEnergy = ...
        tx_symbol_energy_accum / trans_blocks;
    snr_stats(idx).meanTxPowerScaling = ...
        tx_power_scaling_accum / trans_blocks;
    snr_stats(idx).meanNoiseVariance = ...
        noise_variance_accum / trans_blocks;

    if cfg.simulation.verbose
        fprintf('  SNR %5.1f dB  BLER %.3f (%d/%d)  throughput %6.2f Mbps  [%.1fs]\n', ...
            snr_points(idx), ...
            snr_stats(idx).bler, ...
            block_errors, ...
            cfg.simulation.numTransportBlocks, ...
            snr_stats(idx).throughputMbps, ...
            toc(snr_tic));
    end
end

% Convert the per-SNR struct array into a stable result table for plotting and
% sweep aggregation.
summary_table = struct2table(snr_stats);
summary_table.Properties.VariableNames = { ...
    'SNR_dB', ...
    'BLER', ...
    'Throughput_Mbps', ...
    'TBSize_bits', ...
    'CodedBits', ...
    'MeanTxSymbolEnergy', ...
    'MeanTxPowerScaling', ...
    'MeanNoiseVariance'};

if cfg.simulation.maxNumTransmissions > 1
    summary_table.MCS_Table_retx = repmat(string(retx_mcs_table_name), num_points, 1);
    summary_table.CodedBits_retx = repmat(retx_coded_bits, num_points, 1);
    summary_table = movevars(summary_table, "CodedBits_retx", "After", "CodedBits");
end

% Return both the user-facing metrics and enough metadata to audit the exact
% PHY chain, shaping plan, and resource allocation used for the sweep.
results = struct();
results.config = cfg;
results.carrier = carrier;
results.pdsch = pdsch;
results.mcsInfo = mcs_info;
results.pdschInfo = pdsch_info;
results.mimo = mimo_info;
results.transportBlockSize = num_tb_info_bits;
results.payloadTransportBlockSize = num_tb_info_bits;
results.chainTransportBlockSize = num_tb_bits_cw;
results.preLdpcBlockSize = ps_info.preLdpcBlockLength;
results.errorMeasurement = ps_info.measurementBasis;
results.tbsMatch = tbs_match;
results.slotDurationMs = slot_duration_ms;
results.ofdmInfo = ofdm_info;
results.shaping = ps_info;
results.perSnr = snr_stats;
results.summaryTable = summary_table;
end
