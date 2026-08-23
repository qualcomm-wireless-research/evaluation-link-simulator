function params = scenario_awgn()
%SCENARIO_AWGN AWGN fixed-MCS sweep: uniform vs ESS vs ECC shaped PS chains.
%
%   PARAMS = SCENARIO_AWGN() returns the scenario parameters consumed by
%   toolbox.loadScenario. Edit the values below to change the sweep.

%% USER SETTINGS
% Three-way comparison: uniform QAM vs ESS-shaped vs ECC-shaped PS chains.
chain_modes = ["uniform", "ess", "ecc"];   % chains to sweep
mcs_list = 20;                         % fixed-MCS points to sweep
snr_db = 16:0.25:19;                     % SNR sweep grid in dB
num_transport_blocks = 1000;           % transport blocks per SNR point
rng_seed = 42;

num_tx_antennas = 1;                  % transmit antennas
num_rx_antennas = 1;                  % receive antennas
num_pdsch_layers = 1;                 % PDSCH layers
prb_set = 0:7;                        % allocated PRBs (0:7 = 8 RB)
pdsch_symbol_allocation = [0 9];      % [start symbol, num symbols] within the slot

uniform_mcs_table = "qam256";         % MCS table for the uniform chain
ps_mcs_table = "ps_mcs_table1";       % MCS table shared by the ESS and ECC PS chains
num_shaped_bit_level = 2;             % shaped amplitude bit levels per dimension
match_ps_tbs_to_uniform = true;       % match PS payload TBS to the uniform chain

ess_tx_scaling = "lut";               % ESS TX power scaling: "empirical" or "lut"
ess_n_max = 128;                      % ESS DP table size cap
ess_n_mantissa = 8;                   % ESS energy-table mantissa bits

% ECC's txScaling must stay "empirical" -- validate_config.m rejects
% mode='ecc' with txScaling='lut' (LUT scaling is an ESS-only optimization).
ecc_n_max = 1024;                     % ECC polar shaper max DM block length
ecc_list_size = 1;                    % ECC SCL decoder list size

receiver_demapper = "mmse";           % detector: "mmse" or "sphere"
max_ldpc_iterations = 25;             % LDPC decoder iteration cap
ldpc_decoding_algorithm = "Layered belief propagation";  % LDPC decoding algorithm
make_plots = true;                    % save overlay BLER/throughput figures
output_root = fullfile("results", "awgn");   % output directory root, relative to repo root

%% SHARED AWGN CONFIG
% Base config shared by every chain/MCS combination in the sweep.
base_cfg.simulation.snrDb = snr_db;
base_cfg.simulation.numTransportBlocks = num_transport_blocks;
base_cfg.simulation.rngSeed = rng_seed;

base_cfg.pdsch.numLayers = num_pdsch_layers;
base_cfg.pdsch.prbSet = prb_set;
base_cfg.pdsch.symbolAllocation = pdsch_symbol_allocation;
base_cfg.pdsch.rv = 0;

base_cfg.channel.model = "awgn";
base_cfg.channel.delayProfile = "AWGN";
base_cfg.channel.maximumDopplerHz = 0;
base_cfg.channel.numReceiveAntennas = num_rx_antennas;

base_cfg.receiver.channelEstimation = "perfect";
base_cfg.receiver.demapper = receiver_demapper;
base_cfg.receiver.maxLdpcIterations = max_ldpc_iterations;
base_cfg.receiver.LDPCDecodingAlgorithm = ldpc_decoding_algorithm;

base_cfg.shaping.ess.nMax = ess_n_max;
base_cfg.shaping.ess.nMantissa = ess_n_mantissa;
base_cfg.shaping.ecc.nMax = ecc_n_max;
base_cfg.shaping.ecc.listSize = ecc_list_size;

base_cfg.mimo.numTransmitAntennas = num_tx_antennas;
if num_tx_antennas == num_pdsch_layers
    base_cfg.mimo.precodingMode = "none";
else
    base_cfg.mimo.precodingMode = "openloop";
end
base_cfg.mimo.openLoopPrecoder = "identity";

%% SCENARIO METADATA
params = struct();
params.scenarioPrefix = "awgn";
params.scenarioTitle = "AWGN uniform vs ESS vs ECC comparison";
params.outputRoot = output_root;
params.makePlots = make_plots;
params.plotSnrGain = false;

params.baseCfg = base_cfg;
params.chainModes = chain_modes;
params.mcsList = mcs_list;
params.chainOpts = struct( ...
    "uniformMcsTable", uniform_mcs_table, ...
    "psMcsTable", ps_mcs_table, ...
    "numShapedBitLevel", num_shaped_bit_level, ...
    "txScaling", ess_tx_scaling, ...
    "matchPsTbsToUniform", match_ps_tbs_to_uniform);
end
