function params = scenario_mimo()
%SCENARIO_MIMO TDL-A open-loop MIMO fixed-MCS sweep (2x2).
%
%   PARAMS = SCENARIO_MIMO() returns the scenario parameters consumed by
%   toolbox.loadScenario. Edit the values below to change the sweep.

%% USER SETTINGS
chain_modes = ["uniform", "ps"];      % chains to sweep: "uniform", "ps", or both
mcs_list = 11;                        % fixed-MCS points to sweep
snr_db = 10:1:22;                    % SNR sweep grid in dB
num_transport_blocks = 200;           % transport blocks per SNR point
rng_seed = 42;                        % RNG seed for repeatable runs

num_tx_antennas = 2;                  % transmit antennas
num_rx_antennas = 2;                  % receive antennas
num_pdsch_layers = 2;                 % PDSCH layers
prb_set = 0:1;                        % allocated PRBs (0:1 = 2 RB)
pdsch_symbol_allocation = [0 4];      % [start symbol, num symbols] within the slot

uniform_mcs_table = "qam256";         % MCS table for the uniform chain
ps_mcs_table = "ps_mcs_table1";       % MCS table for the PS chain
num_shaped_bit_level = 2;             % shaped amplitude bit levels per dimension
ps_tx_scaling = "lut";          % PS TX power scaling: "empirical" or "lut"
match_ps_tbs_to_uniform = true;       % match PS payload TBS to the uniform chain

tdl_delay_spread = 100e-9;            % TDL RMS delay spread in seconds
maximum_doppler_hz = 70;              % maximum Doppler shift in Hz
channel_filter = "fd";                % channel filter: "td" or "fd"
open_loop_precoder = "identity";      % open-loop precoder
receiver_demapper = "fast_sphere";    % detector: "mmse", "sphere", or "fast_sphere"
fast_sphere_max_list = 128;           % fast-sphere max candidate list size for soft LLR computation
fast_sphere_n_cand = 32;              % fast-sphere candidate list size per PAM level
llr_clip_limit = 30;                  % LLR clip magnitude (Inf disables)
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
base_cfg.channel.filter = channel_filter;
base_cfg.channel.delayProfile = "TDL-A"; % TDL-A/B/C/D/E, NTN-TDL-A/B/C/D/E
base_cfg.channel.delaySpread = tdl_delay_spread;
base_cfg.channel.maximumDopplerHz = maximum_doppler_hz;
base_cfg.channel.numReceiveAntennas = num_rx_antennas;
base_cfg.channel.normalizePathGains = true;
base_cfg.channel.normalizeOutputs = true;

base_cfg.receiver.channelEstimation = "perfect";
base_cfg.receiver.demapper = receiver_demapper;
base_cfg.receiver.maxLdpcIterations = max_ldpc_iterations;
base_cfg.receiver.fastSphereMaxList = fast_sphere_max_list;
base_cfg.receiver.fastSphereNCand = fast_sphere_n_cand;
base_cfg.receiver.llrClipLimit = llr_clip_limit;

base_cfg.mimo.numTransmitAntennas = num_tx_antennas;
base_cfg.mimo.precodingMode = "openloop";
base_cfg.mimo.openLoopPrecoder = open_loop_precoder;

%% SCENARIO METADATA
params = struct();
params.scenarioPrefix = "tdla_openloop_2tx2rx";
params.scenarioTitle = "TDL-A open-loop 2x2 fixed-MCS sweep";
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
