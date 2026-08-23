function params = scenario_simo_cdl_1x32_ul()
%SCENARIO_SIMO_CDL_1TX32RX CDL-A open-loop SIMO fixed-MCS sweep (1 Tx, 32 Rx, single layer).
%
%   PARAMS = SCENARIO_SIMO_CDL_1TX32RX() returns the scenario parameters consumed by
%   toolbox.loadScenario. Edit the values below to change the sweep.
%
%   Based on launcher_ran1_125_1tx32rx_CDLA.py: CDL-A, 4 GHz, 3 km/h,
%   1 TxRU (single isotropic element), 32 Rx, open-loop identity precoder,
%   FD channel filter, swapTransmitAndReceive=true (UL direction).

%% USER SETTINGS
chain_modes = ["uniform", "ps"];      % chains to sweep: "uniform", "ps", or both
mcs_list = 11;                        % fixed-MCS points to sweep
snr_db = -5:1:0;                     % SNR sweep grid in dB
num_transport_blocks = 200;           % transport blocks per SNR point (reduced for quick test)
rng_seed = 42;                        % RNG seed for repeatable runs

num_tx_antennas = 1;                  % transmit antennas
num_rx_antennas = 32;                 % receive antennas
num_pdsch_layers = 1;                 % PDSCH layers (rank 1)
prb_set = 0:1;                        % allocated PRBs (0:1 = 2 RB)
pdsch_symbol_allocation = [0 4];     % [start symbol, num symbols] within the slot

uniform_mcs_table = "qam256";         % MCS table for the uniform chain
ps_mcs_table = "ps_mcs_table2";       % MCS table for the PS chain
num_shaped_bit_level = 2;             % shaped amplitude bit levels per dimension
ps_tx_scaling = "lut";               % PS TX power scaling: "empirical" or "lut"
match_ps_tbs_to_uniform = true;       % match PS payload TBS to the uniform chain

cdl_delay_spread = 100e-9;            % CDL-A RMS delay spread in seconds
maximum_doppler_hz = 11;              % maximum Doppler shift in Hz (~3 km/h at 4 GHz)
open_loop_precoder = "identity";      % open-loop precoder
receiver_demapper = "mmse";    % detector: "mmse" or "sphere"
max_ldpc_iterations = 25;             % LDPC decoder iteration cap
ldpc_decoding_algorithm = "Layered belief propagation";
make_plots = true;                    % save overlay BLER/throughput figures
output_root = fullfile("results", "simo_cdl_1x32_ul");  % output directory root

%% SHARED CDL-A OPEN-LOOP CONFIG
base_cfg.simulation.snrDb = snr_db;
base_cfg.simulation.numTransportBlocks = num_transport_blocks;
base_cfg.simulation.rngSeed = rng_seed;

base_cfg.pdsch.numLayers = num_pdsch_layers;
base_cfg.pdsch.prbSet = prb_set;
base_cfg.pdsch.symbolAllocation = pdsch_symbol_allocation;
base_cfg.pdsch.rv = 0;

base_cfg.channel.model = "cdl";
base_cfg.channel.delayProfile = "CDL-A";
base_cfg.channel.delaySpread = cdl_delay_spread;
base_cfg.channel.maximumDopplerHz = maximum_doppler_hz;
base_cfg.channel.numReceiveAntennas = num_rx_antennas;
base_cfg.channel.normalizePathGains = true;
base_cfg.channel.normalizeOutputs = true;
base_cfg.channel.normalizeCDLChannel = true;
base_cfg.channel.filter = "fd";
base_cfg.channel.carrierFrequency = 4e9;
base_cfg.channel.utDirectionOfTravel = [65; 90];
base_cfg.channel.angleScaling = true;
base_cfg.channel.meanAngles = [0 0 0 0];
% Transmit array: 1 AE, single isotropic element, no analog combining
base_cfg.channel.transmitAntennaArray.size = [2 8 2 1 1];
base_cfg.channel.transmitAntennaArray.elementSpacing = [0.5 0.5 1 1];
base_cfg.channel.transmitAntennaArray.polarizationAngles = [-45 45];
base_cfg.channel.transmitAntennaArray.element = "38.901";
base_cfg.channel.transmitAntennaArray.polarizationModel = "Model-1";
base_cfg.channel.transmitArrayOrientation = [0; 0; 0];
base_cfg.channel.analogBF.arraySize = [1 1];
base_cfg.channel.analogBF.direction = [0 90];
% Receive array: 32 isotropic AEs
base_cfg.channel.receiveAntennaArray.size = [1 1 1 1 1];
base_cfg.channel.receiveAntennaArray.elementSpacing = [0.5 0.5 0.5 0.5];
base_cfg.channel.receiveAntennaArray.polarizationAngles = [0 90];
base_cfg.channel.receiveAntennaArray.element = "isotropic";
base_cfg.channel.receiveAntennaArray.polarizationModel = "Model-1";
base_cfg.channel.receiveArrayOrientation = [180; 0; 0];
base_cfg.channel.swapTransmitAndReceive = true;

base_cfg.receiver.channelEstimation = "perfect";
base_cfg.receiver.demapper = receiver_demapper;
base_cfg.receiver.maxLdpcIterations = max_ldpc_iterations;
base_cfg.receiver.ldpcDecodingAlgorithm = ldpc_decoding_algorithm;

base_cfg.mimo.numTransmitAntennas = num_tx_antennas;
base_cfg.mimo.precodingMode = "openloop";
base_cfg.mimo.openLoopPrecoder = open_loop_precoder;

%% SCENARIO METADATA
params = struct();
params.scenarioPrefix = "cdla_simo_1tx32rx";
params.scenarioTitle = "CDL-A open-loop SIMO 1x32 fixed-MCS sweep";
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
