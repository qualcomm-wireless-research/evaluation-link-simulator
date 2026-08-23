function params = scenario_mimo_cdl_2x4_ul()
%SCENARIO_MIMO_CDL_2X4_UL CDL-A open-loop UL MIMO fixed-MCS sweep (2 Tx, 4 Rx, 2 layers).
%
%   PARAMS = SCENARIO_MIMO_CDL_2X4_UL() returns the scenario parameters consumed by
%   toolbox.loadScenario. Edit the values below to change the sweep.
%
%     - CDL-A, 4 GHz, 3 km/h (Doppler ~11 Hz), 100 ns RMS delay spread
%     - 2 Tx, 4 Rx
%     - 2 PDSCH layers, open-loop identity precoder, MMSE demapper

%% USER SETTINGS
chain_modes = ["uniform", "ps"];      % chains to sweep: "uniform", "ps", or both
mcs_list = 19;                        % fixed-MCS points to sweep
snr_db = 19:1:26;                     % SNR sweep grid in dB
num_transport_blocks = 200;           % transport blocks per SNR point
rng_seed = 0;                        % RNG seed for repeatable runs

num_tx_antennas = 2;                  % transmit antennas
num_rx_antennas = 4;                  % receive antennas
num_pdsch_layers = 2;                 % PDSCH layers
prb_set = 0:1;                        % allocated PRBs (0:1 = 2 RB)
pdsch_symbol_allocation = [0 4];      % [start symbol, num symbols] within the slot

uniform_mcs_table = "qam256";         % MCS table for the uniform chain
ps_mcs_table = "ps_mcs_table2";       % MCS table for the PS chain
num_shaped_bit_level = 2;             % shaped amplitude bit levels per dimension
ps_tx_scaling = "lut";                % PS TX power scaling: "empirical" or "lut"
match_ps_tbs_to_uniform = true;       % match PS payload TBS to the uniform chain

cdl_delay_spread = 100e-9;            % CDL-A RMS delay spread in seconds (100 ns)
maximum_doppler_hz = 11;              % maximum Doppler shift in Hz (~3 km/h at 4 GHz)
open_loop_precoder = "identity";      % open-loop precoder
receiver_demapper = "mmse";           % detector: "mmse" or "sphere"
max_ldpc_iterations = 25;             % LDPC decoder iteration cap
ldpc_decoding_algorithm = "Layered belief propagation";
make_plots = true;                    % save overlay BLER/throughput figures
output_root = fullfile("results", "mimo_cdl_2x4_ul");  % output directory root

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
% Transmit array: 
base_cfg.channel.transmitAntennaArray.size = [1 2 2 1 1];          % [M N P Mg Ng]: 1 row, 2 col, 2 pol
base_cfg.channel.transmitAntennaArray.elementSpacing = [0.5 0.5 1 1];
base_cfg.channel.transmitAntennaArray.polarizationAngles = [-45 45];
base_cfg.channel.transmitAntennaArray.element = "38.901";
base_cfg.channel.transmitAntennaArray.polarizationModel = "Model-1";
base_cfg.channel.transmitArrayOrientation = [0; 0; 0];
base_cfg.channel.analogBF.arraySize = [1 1];                        
base_cfg.channel.analogBF.direction = [0 90];
% Receive array: 
base_cfg.channel.receiveAntennaArray.size = [1 1 2 1 1];
base_cfg.channel.receiveAntennaArray.elementSpacing = [0.5 0.5 0.5 0.5];
base_cfg.channel.receiveAntennaArray.polarizationAngles = [0 90];
base_cfg.channel.receiveAntennaArray.element = "isotropic";
base_cfg.channel.receiveAntennaArray.polarizationModel = "Model-1";
base_cfg.channel.receiveArrayOrientation = [180; 0; 0];
base_cfg.channel.swapTransmitAndReceive = true;                     % UL direction

base_cfg.receiver.channelEstimation = "perfect";
base_cfg.receiver.demapper = receiver_demapper;
base_cfg.receiver.maxLdpcIterations = max_ldpc_iterations;
base_cfg.receiver.ldpcDecodingAlgorithm = ldpc_decoding_algorithm;

base_cfg.mimo.numTransmitAntennas = num_tx_antennas;
base_cfg.mimo.precodingMode = "openloop";
base_cfg.mimo.openLoopPrecoder = open_loop_precoder;

%% SCENARIO METADATA
params = struct();
params.scenarioPrefix = "cdla_mimo_2tx4rx_ul";
params.scenarioTitle = "CDL-A open-loop UL MIMO 2x4 2-layer fixed-MCS sweep";
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
