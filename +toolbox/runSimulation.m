function results = runSimulation(cfg)
%RUNSIMULATION Simulate DL PDSCH BLER and throughput for a given SNR and a config.

cfg = toolbox.defaultConfig(cfg);
mcs_info = toolbox.resolveMcsInfo(cfg);
[cfg, tbs_match] = toolbox.resolveShapingNu(cfg, mcs_info);
toolbox.config.validate_config(cfg);
cfg = toolbox.config.apply_rank_adaptation(cfg);
% Re-resolve MCS info and shaping after rank adaptation may have changed MCS
mcs_info = toolbox.resolveMcsInfo(cfg);
[cfg, tbs_match] = toolbox.resolveShapingNu(cfg, mcs_info);
toolbox.config.require_5g_toolbox();

% Build static NR objects and resource allocations. These do not change across
% SNR points or transport blocks for a fixed-MCS sweep.
[carrier, pdsch] = toolbox.phy.pdsch.build_link_objects(cfg, mcs_info); % set up pdsch and dmrs parameters.
mimo_info = toolbox.phy.mimo.build_mimo_info(cfg, pdsch); % setup mimo parameters.
[pdsch_ind, pdsch_info] = nrPDSCHIndices(carrier, pdsch);
dmrs_ind = nrPDSCHDMRSIndices(carrier, pdsch);
dmrs_sym = nrPDSCHDMRS(carrier, pdsch);

num_tb_bits_cw = nrTBS(pdsch.Modulation, pdsch.NumLayers,numel(pdsch.PRBSet), ...
    pdsch_info.NREPerPRB, mcs_info.targetCodeRate, 0);

ps_info = toolbox.ProbShaping.tbgen.init(cfg, carrier, pdsch, mcs_info, pdsch_info, num_tb_bits_cw);
num_tb_info_bits = ps_info.payloadTransportBlockLength; 

% Preallocate empty grids and derive OFDM metadata once.
zero_layer_grid = nrResourceGrid(carrier, pdsch.NumLayers);
amc_allocated_sc = toolbox.amc.allocated_subcarrier_indices( ...
    pdsch_ind, size(zero_layer_grid, 1));
zero_tx_grid = nrResourceGrid(carrier, mimo_info.numTransmitAntennas);
[~, ofdm_info] = nrOFDMModulate(carrier, zero_tx_grid);

% Select the propagation model (AWGN, TDL, or CDL).
channel_model = "tdl";
if isfield(cfg.channel, 'model')
    channel_model = lower(string(cfg.channel.model));
elseif strcmpi(char(string(cfg.channel.delayProfile)), 'awgn')
    channel_model = "awgn";
end

numReceiveAntennaElements = cfg.channel.numReceiveAntennas;

switch channel_model
    case "awgn"
        channel = [];
        path_filters = [];
        max_ch_delay = 0;
    case "tdl"
        channel = toolbox.phy.channel.create_tdl_channel(cfg, mimo_info.numTransmitAntennas, ofdm_info.SampleRate);
    case "cdl"
        channel = toolbox.phy.channel.create_cdl_channel(cfg, ofdm_info.SampleRate);
        analog_bf = toolbox.phy.channel.build_analog_bf(cfg);
        if cfg.channel.swapTransmitAndReceive
            numReceiveAntennaElements = prod(cfg.channel.transmitAntennaArray.size);
        end
        % Compute scaling factor to normalize antenna element/analog BF gain
        if cfg.channel.normalizeCDLChannel
            channel_clone = clone(channel);
            release(channel_clone);
            channel_clone.ChannelFiltering = false;
            channel_clone.SampleRate = channel_clone.MaximumDopplerShift / sqrt(9 / 16 / pi);
            channel_clone.NumTimeSamples = cfg.channel.numTimeSamples;
            path_gains = toolbox.phy.channel.apply_analog_bf(channel_clone(), analog_bf, 3 + cfg.channel.swapTransmitAndReceive, cfg);
            channel_power = mean(sum(abs(path_gains) .^ 2 , 2), 'all');
            scaling_factor = 1 / sqrt(channel_power * numReceiveAntennaElements);
        end
end

if channel_model ~= "awgn"
    channel_info = info(channel);
    path_filters = getPathFilters(channel);
    max_ch_delay = ceil(max(channel_info.PathDelays * channel.SampleRate))  + channel_info.ChannelFilterDelay;
end

% Both uniform NR and PS use nrDLSCH for transport-chain encoding. Create the encoder once before the SNR loop. 
% Encoding chain (CRC insertion, CB segmentation, encoding, rate matching, SBPM) are identical between PS and uniform QAM
dlsch_encoder = nrDLSCH;
dlsch_encoder.TargetCodeRate = mcs_info.targetCodeRate;

% Both uniform and PS paths end at the standard NR TB-CRC decoder. The PS differs only in the scrambling step, which is handled in ps_scramble.m
dlsch_decoder = nrDLSCHDecoder;
dlsch_decoder.TargetCodeRate = mcs_info.targetCodeRate;
dlsch_decoder.TransportBlockLength = num_tb_bits_cw; %%TBS seen by the decoder
dlsch_decoder.MaximumLDPCIterationCount = cfg.receiver.maxLdpcIterations;
dlsch_decoder.LDPCDecodingAlgorithm = cfg.receiver.LDPCDecodingAlgorithm;

% Initialize sphere decoder once before the SNR loop for efficiency.
if strcmpi(cfg.receiver.demapper, 'sphere')
    sphere_decoder_obj = toolbox.phy.receiver.initialize_sphere_decoder(...
        pdsch.Modulation,cfg.receiver.sphereAlgorithm, cfg.receiver.sphereRadius);
else
    sphere_decoder_obj = [];
end

% PS retx fall back to the uniform table's modulation order (rate
% unchanged). Precompute the retx modulation/G/sphere decoder once
% here so the TB loop can swap them in/out like ps_info.enabled.
if cfg.simulation.maxNumTransmissions > 1
    if ps_info.enabled
        ps_retx_mcs_info = toolbox.getMcsInfo(cfg.pdsch.mcsIndex, cfg.shaping.uniformMcsTable);
        ps_retx_modulation = ps_retx_mcs_info.modulation;
        ps_retx_pdsch_info_G = numel(pdsch_ind) * toolbox.phy.pdsch.bits_per_symbol(ps_retx_modulation);
        if strcmpi(cfg.receiver.demapper, 'sphere')
            ps_retx_sphere_decoder_obj = toolbox.phy.receiver.initialize_sphere_decoder(...
                ps_retx_modulation, cfg.receiver.sphereAlgorithm, cfg.receiver.sphereRadius);
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

% Initialize fast-sphere (MEX) decoder once before the SNR loop for efficiency.
if strcmpi(cfg.receiver.demapper, 'fast_sphere')
    fast_sphere_decoder_obj = toolbox.phy.receiver.initialize_fast_sphere_decoder(...
        pdsch.Modulation, cfg.pdsch.numLayers, cfg.receiver.fastSphereNCand, ...
        cfg.receiver.fastSphereMaxList, cfg.receiver.fastSphereUseQrAugmentation);
else
    fast_sphere_decoder_obj = [];
end

snr_points = cfg.simulation.snrDb(:);
num_snr_points = numel(snr_points);

% AMC regime setup.
% All setup lives in toolbox.amc.configure, which returns one immutable state
% struct. Enum values are already validated by validate_config above.
amc = toolbox.amc.configure(cfg, ps_info.enabled);
if amc.enabled
    warmup_blocks = max(amc.warmupBlocks, cfg.simulation.warmupSlots);
else
    warmup_blocks = cfg.simulation.warmupSlots;
end

% Per-SNR results rows. repmat (rather than assigning only the tail element)
% gives every element the scalar prototype's values, so struct2table sees
% uniform column types even on a non-AMC run where the Amc* columns stay at
% their ""/NaN prefill. Assigning just snr_stats(end) would leave elements
% 1..end-1 with [] for the non-numeric fields.
snr_stats = repmat(struct( ...
    "snrDb", 0, "bler", 0, "throughputMbps", 0, "tbSizeBits", 0, ...
    "codedBits", 0, "meanTxSymbolEnergy", 0, "meanTxPowerScaling", 0, ...
    "meanNoiseVariance", 0, "selectedRank", 0, "selectedMcs", 0, ...
    "selectedModulation", "", "effectiveCodeRate", 0, ...
    "amcSelector", "", "amcSelectedTable", "", "amcMeanLayerSnrDb", NaN, ...
    "amcSpreadDb", NaN, "shapingNu", NaN, "tbsMatchRelDiff", NaN), ...
    num_snr_points, 1);

% Per-SNR-point shaping diagnostics.
point_tbs_match = tbs_match;

% Per-point run metadata 
point_mcs_table  = strings(num_snr_points, 1);
point_chain_bits = zeros(num_snr_points, 1);

% Closed-loop precoding: the applied precoder is computed per slot from the
% genie channel estimate, reported back with a periodicity P and processing
% delay D. The report measured on report slot s is applied causally from slot
% s+1 onward; at slot n (0-indexed) we use the newest report slot no later than
% min(n-D, n-1).
is_closed_loop = isfield(mimo_info, 'closedLoop') && mimo_info.closedLoop.enabled;
if is_closed_loop
    cl_period = mimo_info.closedLoop.periodicitySlots;
    cl_delay = mimo_info.closedLoop.processingDelaySlots;
    % Options passed to build_subband_precoders each report slot. subbandSize is
    % in PRBs; NR uses 12 subcarriers per PRB.
    cl_opts = struct( ...
        'numLayers', pdsch.NumLayers, ...
        'subbandSize', mimo_info.closedLoop.subbandSize, ...
        'numScPerPrb', 12, ...
        'combSize', mimo_info.closedLoop.combSize, ...
        'combOffset', mimo_info.closedLoop.combOffset, ...
        'csiSymbol', mimo_info.closedLoop.csiSymbol);
end

%Link level simulation starts here.
for idx = 1:num_snr_points

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

    
    % Low-SNR early exit: set when the first nErrors measured transport blocks
    % all fail, meaning this SNR point is hopeless and BLER is taken as 1.
    low_snr_abort = false;
    n_errors_limit = cfg.simulation.nErrors;

    % Running count of every transmitted slot, including warmup slots. Closed-
    % loop CSI report/apply timing is kept relative to this so the precoder has
    % already converged by the time measurement starts; trans_blocks (above)
    % only counts slots that count toward BLER/throughput.
    total_slot_count = 0;

    % Live progress cadence: refresh the in-place status line every 10
    % transport blocks (and on the final block) rather than once per block, so
    % long runs show motion without flooding the console.
    progress_step = 10;

    % Closed-loop feedback buffer, reset per SNR point so each sweep point is
    % independent. cl_reports maps report slot index -> candidate P_freq;
    % cl_applied_freq is the precoder currently in force (empty until the first
    % report is available, when the wideband warm-up precoder is used instead).
    if is_closed_loop
        cl_reports = containers.Map('KeyType', 'double', 'ValueType', 'any');
        cl_applied_freq = [];
    end

    % AMC: every SNR point runs a full warmup followed by the measured blocks. The decision + object
    % rebuild happen once per point, at the first non-warmup block.
    warmup_blocks_this_snr = warmup_blocks;
    total_blocks = warmup_blocks_this_snr + cfg.simulation.numTransportBlocks;
    if amc.enabled
        amc_warmup  = toolbox.amc.warmup_accumulator.reset(amc);
        amc_decided = false;   % fires once per SNR at the first measured block
    end

    for tb_idx = 1:total_blocks
        is_warmup_block = amc.enabled && (tb_idx <= warmup_blocks_this_snr);

        % --- AMC decision + rebuild: fires once per SNR at the first measured block ---
        if amc.enabled && ~amc_decided && ~is_warmup_block
            [decision, amc_metrics, amc_sorted_snr_db] = ...
                toolbox.amc.decide(amc, amc_warmup, snr_points(idx));

            if cfg.simulation.verbose
                fprintf('  [AMC] SNR %5.1f dB  warmup avg per-layer SNR (dB): [%s]\n', ...
                    snr_points(idx), ...
                    strjoin(arrayfun(@(x) sprintf('%.1f', x), amc_sorted_snr_db(:).', ...
                        'UniformOutput', false), ', '));
            end

            if ps_info.enabled
                cfg.shaping.mcsTable = amc.origPsMcsTable;
            else
                cfg.pdsch.mcsTable = amc.origUniformMcsTable;
            end

            mcs_info_before = toolbox.resolveMcsInfo(cfg);

            switch decision.action
                case "tableSwitch"
                    if ps_info.enabled
                        cfg.shaping.mcsTable = char(decision.mcsTable);
                    else
                        cfg.pdsch.mcsTable = char(decision.mcsTable);
                    end
                otherwise
                    % "none": keep the restored baseline table.
            end
            
            mcs_info = toolbox.resolveMcsInfo(cfg);
            [cfg, point_tbs_match] = toolbox.resolveShapingNu(cfg, mcs_info);
            pdsch.Modulation = mcs_info.modulation;
            effective_code_rate = mcs_info.targetCodeRate;

            if cfg.simulation.verbose && decision.action == "tableSwitch"
                if ps_info.enabled
                    eff_nu = NaN;
                    if isfield(cfg.shaping, 'nu'); eff_nu = cfg.shaping.nu; end
                    fprintf('  [AMC-PS] %s  (from cr %.4f)  nu %.4f\n', ...
                        decision.reason, mcs_info_before.targetCodeRate, eff_nu);
                else
                    fprintf('  [AMC-UNI] %s  (from cr %.4f)\n', ...
                        decision.reason, mcs_info_before.targetCodeRate);
                end
            end

            % Rebuild every slot object with the final modulation and code rate.
            [pdsch_ind, pdsch_info] = nrPDSCHIndices(carrier, pdsch);
            dmrs_ind = nrPDSCHDMRSIndices(carrier, pdsch);
            dmrs_sym = nrPDSCHDMRS(carrier, pdsch);
            num_tb_bits_cw = nrTBS( ...
                pdsch.Modulation, pdsch.NumLayers, numel(pdsch.PRBSet), ...
                pdsch_info.NREPerPRB, effective_code_rate, 0);
            if ps_info.enabled
                ps_info = toolbox.ProbShaping.tbgen.init( ...
                    cfg, carrier, pdsch, mcs_info, pdsch_info, num_tb_bits_cw);
                num_tb_info_bits = ps_info.payloadTransportBlockLength;
            else
                num_tb_info_bits = num_tb_bits_cw;
            end
            zero_layer_grid  = nrResourceGrid(carrier, pdsch.NumLayers);
            dlsch_encoder.TargetCodeRate = effective_code_rate;
            dlsch_decoder.TargetCodeRate = effective_code_rate;
            dlsch_decoder.TransportBlockLength = num_tb_bits_cw;
            mimo_info = toolbox.phy.mimo.build_mimo_info(cfg, pdsch);

            if strcmpi(cfg.receiver.demapper, 'sphere')
                sphere_decoder_obj = toolbox.phy.receiver.initialize_sphere_decoder( ...
                    pdsch.Modulation, cfg.receiver.sphereAlgorithm, cfg.receiver.sphereRadius);
            elseif strcmpi(cfg.receiver.demapper, 'fast_sphere')
                fast_sphere_decoder_obj = ...
                    toolbox.phy.receiver.initialize_fast_sphere_decoder( ...
                        pdsch.Modulation, pdsch.NumLayers, ...
                        cfg.receiver.fastSphereNCand, cfg.receiver.fastSphereMaxList, cfg.receiver.fastSphereUseQrAugmentation);
            end

            if cfg.simulation.verbose
                if ps_info.enabled
                    fprintf('  [AMC] SNR %5.1f dB  mod %s->%s  cr %.4f  ps_table %s\n', ...
                        snr_points(idx), mcs_info_before.modulation, pdsch.Modulation, ...
                        effective_code_rate, char(string(cfg.shaping.mcsTable)));
                else
                    fprintf('  [AMC] SNR %5.1f dB  mod %s->%s  cr %.4f\n', ...
                        snr_points(idx), mcs_info_before.modulation, pdsch.Modulation, ...
                        effective_code_rate);
                end
            end

            amc_decided = true;
        end
        % --- end AMC decision + rebuild ---

        reset(dlsch_decoder);

        % Warmup slots run the full Tx/Rx chain (so the channel evolves and the
        % closed-loop precoder converges) but are excluded from BLER/throughput.
        is_measured = tb_idx > warmup_blocks_this_snr;

        % TX data path:
        if ~ps_info.enabled
            tb = randi([0 1], num_tb_bits_cw, 1, 'int8');
        else
            tb = toolbox.ProbShaping.tbgen.build_tb_for_ps(ps_info);
        end

        setTransportBlock(dlsch_encoder, tb);

        % HARQ transmission — save initial state for retransmission restore.
        % These are saved AFTER the AMC reinit so that retx-restore returns to
        % the (possibly AMC-adjusted) state, not the pre-reinit original.
        ps_enabled_init = ps_info.enabled;
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

            slot_n = total_slot_count;

            cw = dlsch_encoder(pdsch.Modulation,pdsch.NumLayers, pdsch_info.G, cfg.pdsch.rv(trans_idx));

            tx_layer_grid = zero_layer_grid;
            [pdsch_symbols, pdsch_tx_info] = toolbox.phy.pdsch.new_pdsch( ...
                carrier, pdsch, cw, ps_info);
            tx_layer_grid(pdsch_ind) = pdsch_symbols;
            if is_measured
                tx_symbol_energy_accum = tx_symbol_energy_accum + pdsch_tx_info.averageSymbolEnergy;
                tx_power_scaling_accum = tx_power_scaling_accum + pdsch_tx_info.psPowerScaling;
            end
            if ps_info.enabled
                ps_info.psPowerScaling = pdsch_tx_info.psPowerScaling;
            end

            % Common grid/waveform path: precode layers to antennas and OFDM-modulate, then pass through AWGN or TDL/CDL plus AWGN.
            tx_layer_grid(dmrs_ind) = dmrs_sym;
            if is_closed_loop
                % Newest report that could have arrived: reported no later than the
                % previous slot (causality) and after the processing delay.
                deadline = min(slot_n - cl_delay, slot_n - 1);
                if deadline >= 0
                    report_slot = floor(deadline / cl_period) * cl_period;
                    if isKey(cl_reports, report_slot)
                        cl_applied_freq = cl_reports(report_slot);
                    end
                end

                if isempty(cl_applied_freq)
                    % Warm-up: no valid CSI report yet, use the wideband fallback.
                    tx_grid = toolbox.phy.mimo.precode_resource_grid(tx_layer_grid, mimo_info.precoderMatrix);
                else
                    tx_grid = toolbox.phy.mimo.precode_resource_grid(tx_layer_grid, cl_applied_freq);
                end
            else
                tx_grid = toolbox.phy.mimo.precode_resource_grid(tx_layer_grid, mimo_info.precoderMatrix);
            end

            tx_waveform=[nrOFDMModulate(carrier, tx_grid); zeros(max_ch_delay, mimo_info.numTransmitAntennas)];

            if channel_model == "awgn"
                % channel.model = "awgn" is restricted to 1 tx/1 rx antenna and
                % 1 PDSCH layer (validate_config.m), so the "channel" is just
                % unit gain on a single antenna pair.
                noise_waveform = toolbox.phy.channel.generate_awgn( size(tx_waveform), snr_points(idx), ...
                    ofdm_info.Nfft, numReceiveAntennaElements);
                rx_waveform = tx_waveform + noise_waveform;
                rx_grid = nrOFDMDemodulate(carrier, rx_waveform);
                noise_grid = nrOFDMDemodulate(carrier, noise_waveform);
                n_var = mean(abs(noise_grid(:)).^2);
                h_est_grid_raw = ones(size(rx_grid, 1), size(rx_grid, 2), 1, 1);
                h_est_domain = "antenna";
            else
                if channel_model == "cdl"
                    if ~cfg.channel.swapTransmitAndReceive
                        tx_waveform = toolbox.phy.channel.apply_analog_bf(tx_waveform, analog_bf, 2, cfg);
                        [rx_waveform_noiseless, path_gains, sample_time] = channel(tx_waveform);
                    else
                        [rx_waveform_noiseless, path_gains, sample_time] = channel(tx_waveform);
                        rx_waveform_noiseless = toolbox.phy.channel.apply_analog_bf(rx_waveform_noiseless, analog_bf, 2, cfg);
                    end
                    path_gains = toolbox.phy.channel.apply_analog_bf(path_gains, analog_bf, 3 + cfg.channel.swapTransmitAndReceive, cfg);
                    % Normalize antenna element/analog BF gain
                    if cfg.channel.normalizeCDLChannel
                        rx_waveform_noiseless = rx_waveform_noiseless * scaling_factor;
                        path_gains = path_gains * scaling_factor;
                    end
                else
                    [rx_waveform_noiseless, path_gains, sample_time] = channel(tx_waveform);
                end

                [rx_grid, h_est_grid_raw, n_var, h_est_domain] = toolbox.phy.channel.receive_grid( ...
                    carrier, cfg.channel.filter, rx_waveform_noiseless, tx_grid, ...
                    path_gains, path_filters, cfg.receiver, ...
                    dmrs_ind, dmrs_sym, pdsch.DMRS.CDMLengths, sample_time, ...
                    snr_points(idx), ofdm_info.Nfft, numReceiveAntennaElements);
            end

            if h_est_domain == "antenna"
                if is_closed_loop && ~isempty(cl_applied_freq)
                    % Fold the frequency-selective precoder actually applied this
                    % slot into the channel estimate for equalization.
                    h_est_grid = toolbox.phy.mimo.apply_precoder_to_channel_estimate(h_est_grid_raw, cl_applied_freq);
                else
                    h_est_grid = toolbox.phy.mimo.apply_precoder_to_channel_estimate(h_est_grid_raw, mimo_info.precoderMatrix);
                end
            else
                h_est_grid = h_est_grid_raw;
            end

            % Closed-loop CSI report: on report slots, compute a fresh per-subband
            % SVD precoder candidate from this slot's genie estimate and buffer it.
            % It becomes eligible for application at future slots per the scheduler.
            if is_closed_loop && h_est_domain == "antenna"
                if mod(slot_n, cl_period) == 0
                    cl_reports(slot_n) = toolbox.phy.mimo.build_subband_precoders( ...
                        h_est_grid_raw, cl_opts);
                end
            end

            % AMC warmup: accumulate per-layer effective SNR (dB), sampled once per
            % PRG at its middle tone on the CSI snapshot symbol and reduced across
            % PRGs in amc.prgDomain. Only on the first HARQ attempt; h_est_grid is
            % [nsc,nsym,nrx,nlayers]. Measurement in toolbox.amc.measure_layer_snr.

            cl_precoder_converged = ~is_closed_loop || ~isempty(cl_applied_freq);
            if is_warmup_block && trans_idx == 1 && h_est_domain == "antenna" ...
                    && cl_precoder_converged
                layer_snr_db = toolbox.amc.measure_layer_snr( ...
                    h_est_grid, n_var, amc.geom, amc.prgDomain, amc_allocated_sc);
                amc_warmup = toolbox.amc.warmup_accumulator.add( ...
                    amc_warmup, layer_snr_db);
            end

            if is_measured
                noise_variance_accum = noise_variance_accum + n_var;
            end

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
            elseif strcmpi(cfg.receiver.demapper, 'fast_sphere')
                rx_cfg.fastSphereDecoderObj = fast_sphere_decoder_obj;
            end

            % RX data path:
            dlsch_llrs = toolbox.phy.pdsch.new_pdsch_decode( ...
                carrier, pdsch, pdsch_rx, pdsch_hest, n_var, rx_cfg, ps_info);

            [~, blk_err] = dlsch_decoder(dlsch_llrs, pdsch.Modulation, ...
                pdsch.NumLayers, cfg.pdsch.rv(trans_idx));

            total_slot_count = total_slot_count + 1;
            if is_measured
                trans_blocks = trans_blocks + 1;
            end
            if ~any(blk_err)
                if is_measured
                    successful_blocks = successful_blocks + 1;
                end
                break;  % Stop HARQ retx
            end
        end

        if is_measured && any(blk_err)
            block_errors = block_errors + 1;
        end

        ps_info.enabled = ps_enabled_init;  % Reset for inital transmission
        pdsch.Modulation = pdsch_modulation_init;
        pdsch_info.G = pdsch_info_G_init;
        sphere_decoder_obj = sphere_decoder_obj_init;

        % In-place live progress: refresh a single status line every
        % progress_step blocks (and on the final block) rather than once per
        % block.
        main_tb_idx = tb_idx - warmup_blocks_this_snr;
        if cfg.simulation.verbose && is_measured && ...
                (mod(main_tb_idx, progress_step) == 0 || main_tb_idx == cfg.simulation.numTransportBlocks)
            fprintf('\r  SNR %5.1f dB  block %3d/%-3d  running BLER %.3f  [%.1fs]', ...
                snr_points(idx), ...
                main_tb_idx, cfg.simulation.numTransportBlocks, ...
                block_errors / main_tb_idx, ...
                toc(snr_tic));
        end

        % Low-SNR early exit: if the first n_errors_limit measured transport
        % blocks have all failed, treat this SNR point as BLER = 1 and stop
        % simulating it. Saves the bulk of the runtime on MCS/SNR combinations
        % that never decode.
        if n_errors_limit > 0 && is_measured && ...
                trans_blocks >= n_errors_limit && block_errors == trans_blocks
            low_snr_abort = true;
            break;
        end
    end

    % Aggregate BLER/throughput for this SNR point. Throughput uses the effective
    % payload size, which is smaller than num_tb_bits_cw when PS rate loss is present.
    elapsed_seconds = trans_blocks * cfg.carrier.slotDurationMs * 1e-3;
    snr_stats(idx).snrDb = snr_points(idx);
    if low_snr_abort
        % Aborted early with every measured block in error: BLER is 1 by
        % construction, so normalize by the blocks actually run rather than by
        % the full (unreached) numTransportBlocks budget.
        snr_stats(idx).bler = 1;
    else
        snr_stats(idx).bler = block_errors / cfg.simulation.numTransportBlocks;
    end
    snr_stats(idx).throughputMbps = successful_blocks * num_tb_info_bits/elapsed_seconds/1e6;
    snr_stats(idx).tbSizeBits = num_tb_info_bits;
    snr_stats(idx).codedBits = pdsch_info.G;
    point_mcs_table(idx)  = string(mcs_info.table);
    point_chain_bits(idx) = num_tb_bits_cw;
    snr_stats(idx).meanTxSymbolEnergy = tx_symbol_energy_accum / trans_blocks;
    snr_stats(idx).meanTxPowerScaling = tx_power_scaling_accum / trans_blocks;
    snr_stats(idx).meanNoiseVariance  = noise_variance_accum   / trans_blocks;
    snr_stats(idx).selectedRank = cfg.pdsch.numLayers;
    snr_stats(idx).selectedMcs  = cfg.pdsch.mcsIndex;
    snr_stats(idx).selectedModulation = string(pdsch.Modulation);
    snr_stats(idx).effectiveCodeRate  = dlsch_encoder.TargetCodeRate;
    % Shaping nu actually used at THIS point. Under AMC the table -- and so nu --
    % is re-resolved per point, and a revert changes it back, so a single
    % sweep-level value would be wrong for most rows. NaN on the uniform path.
    if isfield(cfg, 'shaping') && isfield(cfg.shaping, 'enabled') && ...
            logical(cfg.shaping.enabled) && isfield(cfg.shaping, 'nu')
        snr_stats(idx).shapingNu = cfg.shaping.nu;
    end
    if isfield(point_tbs_match, 'enabled') && point_tbs_match.enabled
        snr_stats(idx).tbsMatchRelDiff = point_tbs_match.relativeDifference;
    end
    % AMC selection metrics captured at this point's decision. 
    if amc.enabled && amc_decided
        snr_stats(idx).amcSelector       = amc_metrics.selector;
        snr_stats(idx).amcSelectedTable  = amc_metrics.table;
        snr_stats(idx).amcMeanLayerSnrDb = amc_metrics.meanSnrDb;
        snr_stats(idx).amcSpreadDb       = amc_metrics.spreadDb;
    end

    if cfg.simulation.verbose
        % Overwrite the in-place progress line with the final aggregate for this
        % SNR point. Pad to clear any leftover characters from the longer live line.
        if low_snr_abort
            fprintf('\r  SNR %5.1f dB  BLER %.3f (%d/%d, early exit: first %d blocks all failed)  throughput %6.2f Mbps  [%.1fs]%-12s\n', ...
                snr_points(idx), snr_stats(idx).bler, block_errors, ...
                block_errors, n_errors_limit, snr_stats(idx).throughputMbps, ...
                toc(snr_tic), '');
        else
            fprintf('\r  SNR %5.1f dB  BLER %.3f (%d/%d)  throughput %6.2f Mbps  [%.1fs]%-12s\n', ...
                snr_points(idx), snr_stats(idx).bler, block_errors, ...
                cfg.simulation.numTransportBlocks,  snr_stats(idx).throughputMbps, ...
                toc(snr_tic), '');
        end
    end

    % Early-exit: if BLER is zero, all higher SNR points will also be zero.
    if snr_stats(idx).bler == 0 && idx < num_snr_points
        if cfg.simulation.verbose
            fprintf('  BLER=0 at SNR %.1f dB — projecting onto remaining %d point(s)\n', ...
                snr_points(idx), num_snr_points - idx);
        end
        for jdx = (idx+1):num_snr_points
            % Copy the full measured row first so the Selected*/EffectiveCodeRate
            % and Amc* columns are carried onto the skipped points, then restore the
            % release_v3 legacy-field projection exactly: throughput saturates at
            % one payload TB per slot and meanNoiseVariance is scaled by the SNR
            % delta rather than copied constant.
            snr_stats(jdx) = snr_stats(idx);
            snr_stats(jdx).snrDb          = snr_points(jdx);
            snr_stats(jdx).throughputMbps = num_tb_info_bits / ...
                (cfg.carrier.slotDurationMs * 1e-3) / 1e6;
            snr_stats(jdx).meanNoiseVariance = snr_stats(idx).meanNoiseVariance * ...
                10^(-(snr_points(jdx) - snr_points(idx)) / 10);
            % Skipped points were never run, so they inherit the projecting
            % point's table and chain size rather than staying at the ""/0
            % prefill.
            point_mcs_table(jdx)  = point_mcs_table(idx);
            point_chain_bits(jdx) = point_chain_bits(idx);
        end
        break;
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
    'MeanNoiseVariance', ...
    'SelectedRank', ...
    'SelectedMcs', ...
    'SelectedModulation', ...
    'EffectiveCodeRate', ...
    'AmcSelector', ...
    'AmcSelectedTable', ...
    'AmcMeanLayerSnrDb', ...
    'AmcSpreadDb', ...
    'ShapingNu', ...
    'TbsMatchRelDiff'};

if cfg.simulation.maxNumTransmissions > 1
    summary_table.MCS_Table_retx = repmat(string(retx_mcs_table_name), num_snr_points, 1);
    summary_table.CodedBits_retx = repmat(retx_coded_bits, num_snr_points, 1);
    summary_table = movevars(summary_table, "CodedBits_retx", "After", "CodedBits");
end

% Return both the user-facing metrics and enough metadata to audit the exact
% PHY chain, shaping plan, and resource allocation used for the sweep.
results = struct();
results.config = cfg;
results.carrier = carrier;
results.pdsch = pdsch;
results.mcsInfo = mcs_info;
% Per-point counterparts of mcsInfo.table / chainTransportBlockSize, one entry
% per SNR point. Use these for anything stamped onto summary rows.
results.pointMcsTable = point_mcs_table;
results.pointChainTransportBlockSize = point_chain_bits;
results.pdschInfo = pdsch_info;
results.mimo = mimo_info;
results.transportBlockSize = num_tb_info_bits;
results.payloadTransportBlockSize = num_tb_info_bits;
results.chainTransportBlockSize = num_tb_bits_cw;
results.preLdpcBlockSize = ps_info.preLdpcBlockLength;
results.errorMeasurement = ps_info.measurementBasis;
% Pre-sweep solve only. Under AMC each SNR point re-resolves nu; the per-point
% values are the ShapingNu / TbsMatchRelDiff columns of summaryTable.
results.tbsMatch = tbs_match;
results.slotDurationMs = cfg.carrier.slotDurationMs;
results.ofdmInfo = ofdm_info;
results.shaping = ps_info;
results.perSnr = snr_stats;
results.summaryTable = summary_table;
end
