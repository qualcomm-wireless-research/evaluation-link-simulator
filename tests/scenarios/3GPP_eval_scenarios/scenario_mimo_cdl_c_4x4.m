function params = scenario_mimo_cdl_c_4x4()
%SCENARIO_MIMO_CDL_C_4X4 CDL-C closed-loop DL MIMO fixed-MCS sweep (4x4), with explicit
%antenna arrays, analog beamforming, and angle/orientation randomization.
%
%   PARAMS = SCENARIO_MIMO_CDL_C_4X4() returns the scenario parameters consumed by
%   toolbox.loadScenario. Edit the values below to change the sweep.

%% USER SETTINGS
chain_modes = ["uniform", "ps"];      % chains to sweep: "uniform", "ps", or both
mcs_list = 24;                        % fixed-MCS points to sweep
snr_db = 30:1:40;                   % SNR sweep grid in dB
num_transport_blocks = 200;           % transport blocks per SNR point
warmup_slots = 10;                    % >= processing delay so CL precoder engaged
rng_seed = 0;                        % RNG seed for repeatable runs

num_tx_antennas = 4;                 % transmit antennas
num_rx_antennas = 4;                  % receive antennas
num_pdsch_layers = 4;                 % PDSCH layers
prb_set = 0:23;                       % allocated PRBs (0:23 = 24 RB)
pdsch_symbol_allocation = [0 12];     % [start symbol, num symbols] within the slot

uniform_mcs_table = "qam256";         % MCS table for the uniform chain
ps_mcs_table = "ps_mcs_table2";       % MCS table for the PS chain
num_shaped_bit_level = 2;             % shaped amplitude bit levels per dimension
ps_tx_scaling = "lut";          % PS TX power scaling: "empirical" or "lut"
match_ps_tbs_to_uniform = true;       % match PS payload TBS to the uniform chain

cdl_delay_spread = 300e-9;             % CDL RMS delay spread in seconds
maximum_doppler_hz = 11;              % maximum Doppler shift in Hz
precoding_mode = "closedloop";
open_loop_precoder = "identity";      % open-loop precoder
receiver_demapper = "fast_sphere";    % detector: "mmse", "sphere", or "fast_sphere"
fast_sphere_max_list = 128;           % Max candidate list size for soft LLR computation
fast_sphere_n_cand = 32;              % candidate list size per PAM level
max_ldpc_iterations = 25;             % LDPC decoder iteration cap
ldpc_decoding_algorithm = "Layered belief propagation";  % LDPC decoding algorithm
make_plots = true;                    % save overlay BLER/throughput figures
output_root = fullfile("results", "mimo_cdl_c_4x4");   % output directory root, relative to repo root

closed_loop_method = "svd";               % precoder computation: "svd"
closed_loop_subband_size = 4;             % PRBs per precoding RB group (1 = per-PRB)
closed_loop_periodicity_slots = 40;       % CSI report period P (slots)
closed_loop_processing_delay_slots = 8;   % feedback/processing delay D (slots)
closed_loop_warmup_precoder = "identity"; % fallback before first valid report
closed_loop_comb_size = 4;                % SRS frequency comb: sound every Nth SC (1 = all tones)
closed_loop_comb_offset = 0;              % first sounded SC within the comb
closed_loop_csi_symbol = 1;               % OFDM symbol index used as the CSI snapshot (1-based)

%% SHARED CDL-C CLOSED-LOOP CONFIG
% Base config shared by every chain/MCS combination in the sweep.
base_cfg.simulation.snrDb = snr_db;
base_cfg.simulation.numTransportBlocks = num_transport_blocks;
base_cfg.simulation.warmupSlots = warmup_slots;
base_cfg.simulation.rngSeed = rng_seed;

base_cfg.pdsch.numLayers = num_pdsch_layers;
base_cfg.pdsch.prbSet = prb_set;
base_cfg.pdsch.symbolAllocation = pdsch_symbol_allocation;
base_cfg.pdsch.rv = 0;

base_cfg.channel.model = "cdl";
base_cfg.channel.delayProfile = "CDL-C";
base_cfg.channel.delaySpread = cdl_delay_spread;
base_cfg.channel.maximumDopplerHz = maximum_doppler_hz;
base_cfg.channel.numReceiveAntennas = num_rx_antennas;
base_cfg.channel.normalizePathGains = true;
base_cfg.channel.normalizeOutputs = true;
base_cfg.channel.filter = "fd";
base_cfg.channel.carrierFrequency = 4e9; % Hz
base_cfg.channel.utDirectionOfTravel = [65; 90]; % [azimuth zenith] in degrees
base_cfg.channel.angleScaling = true;
base_cfg.channel.transmitAntennaArray.size = [1 2 2 1 1]; % [M N P Mg Ng]
base_cfg.channel.transmitAntennaArray.elementSpacing = [0.5 0.5 1 1]; % [dV dH dgV dgH] in lambda
base_cfg.channel.transmitAntennaArray.polarizationAngles = [-45 45]; % degrees
base_cfg.channel.transmitAntennaArray.element = "38.901";
base_cfg.channel.transmitAntennaArray.polarizationModel = "Model-1";
base_cfg.channel.transmitArrayOrientation = [0; 0; 0]; % [bearing downtilt slant] in degrees
base_cfg.channel.receiveAntennaArray.size = [1 2 2 1 1];
base_cfg.channel.receiveAntennaArray.elementSpacing = [0.5 0.5 0.5 0.5];
base_cfg.channel.receiveAntennaArray.polarizationAngles = [0 90];
base_cfg.channel.receiveAntennaArray.element = "isotropic";
base_cfg.channel.receiveAntennaArray.polarizationModel = "Model-1";
base_cfg.channel.receiveArrayOrientation = [180; 0; 0];
base_cfg.channel.normalizeCDLChannel = true;
base_cfg.channel.numTimeSamples = 1000;
base_cfg.channel.analogBF.arraySize = [1 1]; % [m n], i.e., [Mp Np] (# chains) = [M N] (# AEs) ./ [m n]
base_cfg.channel.analogBF.direction = [0 90]; % [azimuth zenith] in degrees
base_cfg.channel.swapTransmitAndReceive = false;

% Angle/orientation randomization
base_cfg.channel.randomizeUtDirectionOfTravel = true;
base_cfg.channel.randomUtDirectionOfTravel = [-180 180; 90 90]; % uniform random [azimuth zenith] lo/up in degrees
base_cfg.channel.randomizeMeanAngles = true;
base_cfg.channel.randomMeanAngles = [-60 60; -180 180; 99.3310 99.3310; 73.4974 73.4974]; % uniform random [AoD AoA ZoD ZoA] lo/up in degrees
base_cfg.channel.randomizeReceiveArrayOrientation = true;
base_cfg.channel.randomReceiveArrayOrientation = [-180 180; 0 0; 0 0];

% Note:
% Setting mean ZoD/ZoA to 99.3310/73.4974, i.e., CDL-C model mean ZoD/ZoA computed based on TR 38.901, as above is equivalent to
% disabling ZoD/ZoA angle translation (see TR 38.901 Section 7.7.5.1)

base_cfg.receiver.channelEstimation = "perfect";
base_cfg.receiver.demapper = receiver_demapper;
base_cfg.receiver.fastSphereMaxList = fast_sphere_max_list;
base_cfg.receiver.fastSphereNCand = fast_sphere_n_cand;
base_cfg.receiver.maxLdpcIterations = max_ldpc_iterations;
base_cfg.receiver.LDPCDecodingAlgorithm = ldpc_decoding_algorithm;

base_cfg.mimo.numTransmitAntennas = num_tx_antennas;
base_cfg.mimo.precodingMode = precoding_mode;
base_cfg.mimo.openLoopPrecoder = open_loop_precoder;
base_cfg.mimo.closedLoop.method = closed_loop_method;
base_cfg.mimo.closedLoop.subbandSize = closed_loop_subband_size;
base_cfg.mimo.closedLoop.periodicitySlots = closed_loop_periodicity_slots;
base_cfg.mimo.closedLoop.processingDelaySlots = closed_loop_processing_delay_slots;
base_cfg.mimo.closedLoop.warmupPrecoder = closed_loop_warmup_precoder;
base_cfg.mimo.closedLoop.combSize = closed_loop_comb_size;
base_cfg.mimo.closedLoop.combOffset = closed_loop_comb_offset;
base_cfg.mimo.closedLoop.csiSymbol = closed_loop_csi_symbol;

%% SCENARIO METADATA
params = struct();
params.scenarioPrefix = "cdlc_closedloop_4tx4rx";
params.scenarioTitle = "CDL-C closed-loop 4x4 fixed-MCS sweep";
params.outputRoot = output_root;
params.makePlots = make_plots;
params.plotSnrGain = true;

params.baseCfg = base_cfg;
params.chainModes = chain_modes;
params.mcsList = mcs_list;
params.chainOpts = struct( ...
    "uniformMcsTable", uniform_mcs_table, ...
    "psMcsTable", ps_mcs_table, ...
    "numShapedBitLevel", num_shaped_bit_level, ...
    "txScaling", ps_tx_scaling, ...
    "matchPsTbsToUniform", match_ps_tbs_to_uniform);
end
