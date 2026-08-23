function params = scenario_simo()
%SCENARIO_SIMO TDL-A SIMO fixed-MCS sweep (1 Tx, many Rx, single layer).
%
%   PARAMS = SCENARIO_SIMO() returns the scenario parameters consumed by
%   toolbox.loadScenario. Edit the values below to change the sweep.

%% USER SETTINGS
chain_modes = ["uniform", "ps"];      % chains to sweep: "uniform", "ps", or both
mcs_list = 20;                        % fixed-MCS points to sweep
snr_db = 0:1:6;                    % SNR sweep grid in dB
num_transport_blocks = 200;           % transport blocks per SNR point
rng_seed = 42;                        % RNG seed for repeatable runs

num_tx_antennas = 1;                  % transmit antennas
num_rx_antennas = 32;                  % receive antennas
num_pdsch_layers = 1;                 % PDSCH layers
prb_set = 0:7;                        % allocated PRBs (0:7 = 8 RB)
pdsch_symbol_allocation = [0 9];      % [start symbol, num symbols] within the slot

uniform_mcs_table = "qam256";         % MCS table for the uniform chain
ps_mcs_table = "ps_mcs_table1";       % MCS table for the PS chain
num_shaped_bit_level = 2;             % shaped amplitude bit levels per dimension
ps_tx_scaling = "lut";          % PS TX power scaling: "empirical" or "lut"
match_ps_tbs_to_uniform = true;       % match PS payload TBS to the uniform chain

tdl_delay_spread = 100e-9;            % TDL RMS delay spread in seconds
maximum_doppler_hz = 11;              % maximum Doppler shift in Hz
open_loop_precoder = "identity";      % open-loop precoder
receiver_demapper = "mmse";         % detector: "mmse" or "sphere"
max_ldpc_iterations = 25;             % LDPC decoder iteration cap
ldpc_decoding_algorithm = "Layered belief propagation";  % LDPC decoding algorithm
make_plots = true;                    % save overlay BLER/throughput figures
output_root = fullfile("results", "mimo");   % output directory root, relative to repo root

%% SHARED TDL-A OPEN-LOOP CONFIG
% Base config shared by every chain/MCS combination in the sweep.
base_cfg.simulation.snrDb = snr_db;
base_cfg.simulation.numTransportBlocks = num_transport_blocks;
base_cfg.simulation.rngSeed = rng_seed;

base_cfg.pdsch.numLayers = num_pdsch_layers;
base_cfg.pdsch.prbSet = prb_set;
base_cfg.pdsch.symbolAllocation = pdsch_symbol_allocation;
base_cfg.pdsch.rv = 0;

base_cfg.channel.model = "tdl";
base_cfg.channel.delayProfile = "TDL-A"; % TDL-A/B/C/D/E, NTN-TDL-A/B/C/D/E
base_cfg.channel.delaySpread = tdl_delay_spread;
base_cfg.channel.maximumDopplerHz = maximum_doppler_hz;
base_cfg.channel.numReceiveAntennas = num_rx_antennas;
base_cfg.channel.normalizePathGains = true;
base_cfg.channel.normalizeOutputs = true;

base_cfg.receiver.channelEstimation = "perfect";
base_cfg.receiver.demapper = receiver_demapper;
base_cfg.receiver.maxLdpcIterations = max_ldpc_iterations;

base_cfg.mimo.numTransmitAntennas = num_tx_antennas;
base_cfg.mimo.precodingMode = "openloop";
base_cfg.mimo.openLoopPrecoder = open_loop_precoder;

%% SCENARIO METADATA
params = struct();
params.scenarioPrefix = "tdla_simo_1tx32rx";
params.scenarioTitle = "TDL-A 1x32 fixed-MCS sweep";
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
