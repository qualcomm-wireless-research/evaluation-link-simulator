function params = scenario_awgn_harq()
%SCENARIO_AWGN_HARQ AWGN fixed-MCS sweep with IR-HARQ retransmissions.
%
%   PARAMS = SCENARIO_AWGN_HARQ() returns the scenario parameters consumed by
%   toolbox.loadScenario. Edit the values below to change the sweep.

%% USER SETTINGS
chain_modes = ["uniform", "ps"];      % chains to sweep: "uniform", "ps", or both
mcs_list = 20;                         % fixed-MCS points to sweep
snr_db = 8.5:0.25:11.5;                % SNR sweep grid in dB
num_transport_blocks = 1000;           % transport blocks per SNR point
rng_seed = 42;                        % RNG seed for repeatable runs

max_num_transmissions = 2;            % HARQ transmissions, per TB (1 = no transmission)
rv_sequence = [0 2 3 1];              % RV sequence indexed by transmission attempt

num_tx_antennas = 1;                  % transmit antennas
num_rx_antennas = 1;                  % receive antennas
num_pdsch_layers = 1;                 % PDSCH layers
prb_set = 0:7;                        % allocated PRBs (0:7 = 8 RB)
pdsch_symbol_allocation = [0 9];      % [start symbol, num symbols] within the slot

uniform_mcs_table = "qam256";         % MCS table for the uniform chain
ps_mcs_table = "ps_mcs_table1";       % MCS table for the PS chain
num_shaped_bit_level = 2;             % shaped amplitude bit levels per dimension
ps_tx_scaling = "lut";                % PS TX power scaling: "empirical" or "lut"
match_ps_tbs_to_uniform = true;       % match PS payload TBS to the uniform chain

receiver_demapper = "mmse";           % detector: "mmse" or "sphere"
max_ldpc_iterations = 25;             % LDPC decoder iteration cap
ldpc_decoding_algorithm = "Layered belief propagation";  % LDPC decoding algorithm
make_plots = true;                    % save overlay BLER/throughput figures
output_root = fullfile("results", "awgn_harq");   % output directory root, relative to repo root

%% SHARED AWGN CONFIG
% Base config shared by every chain/MCS combination in the sweep.
base_cfg.simulation.snrDb = snr_db;
base_cfg.simulation.numTransportBlocks = num_transport_blocks;
base_cfg.simulation.rngSeed = rng_seed;
base_cfg.simulation.maxNumTransmissions = max_num_transmissions;

base_cfg.pdsch.numLayers = num_pdsch_layers;
base_cfg.pdsch.prbSet = prb_set;
base_cfg.pdsch.symbolAllocation = pdsch_symbol_allocation;
base_cfg.pdsch.rv = rv_sequence;

base_cfg.channel.model = "awgn";
base_cfg.channel.delayProfile = "AWGN";
base_cfg.channel.maximumDopplerHz = 0;
base_cfg.channel.numReceiveAntennas = num_rx_antennas;

base_cfg.receiver.channelEstimation = "perfect";
base_cfg.receiver.demapper = receiver_demapper;
base_cfg.receiver.maxLdpcIterations = max_ldpc_iterations;
base_cfg.receiver.LDPCDecodingAlgorithm = ldpc_decoding_algorithm;

base_cfg.shaping.ess.nMax = 128;      % ESS DP table size cap
base_cfg.shaping.ess.nMantissa = 8;   % ESS energy-table mantissa bits
base_cfg.shaping.txScaling = ps_tx_scaling;

base_cfg.mimo.numTransmitAntennas = num_tx_antennas;
if num_tx_antennas == num_pdsch_layers
    base_cfg.mimo.precodingMode = "none";
else
    base_cfg.mimo.precodingMode = "openloop";
end
base_cfg.mimo.openLoopPrecoder = "identity";

%% SCENARIO METADATA
params = struct();
params.scenarioPrefix = "awgn_harq";
params.scenarioTitle = sprintf("AWGN fixed-MCS sweep (max #trans = %d)", max_num_transmissions);
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
    "txScaling", ps_tx_scaling, ...
    "matchPsTbsToUniform", match_ps_tbs_to_uniform);
end
