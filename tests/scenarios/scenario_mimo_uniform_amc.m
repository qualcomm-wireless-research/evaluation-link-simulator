function params = scenario_mimo_uniform_amc()
%SCENARIO_MIMO_UNIFORM_AMC TDL-A open-loop 4x4 rank-4 BLER comparison of the
%three uniform-QAM MCS tables at a fixed MCS index.
%
%   PARAMS = SCENARIO_MIMO_UNIFORM_AMC() returns the scenario parameters
%   consumed by toolbox.loadScenario. One uniform-QAM simulation is emitted per
%   entry of UNIFORM_MCS_TABLES. The tables carry the same spectral efficiency
%   row-for-row, so every arm transmits the same payload and only the
%   modulation order / code rate split differs. At MCS 20:
%     qam256        256QAM  682.5/1024
%     qam1024      1024QAM  546/1024    ("NR+1")
%     qam_nrminus1   64QAM  910/1024    ("NR-1")

%% USER SETTINGS
uniform_mcs_tables = ["qam256", "qam1024", "qam_nrminus1"];  % uniform tables to compare
mcs_index = 20;                       % fixed MCS index shared by all tables
snr_db = 22:2:38;                     % SNR sweep grid in dB
num_transport_blocks = 200;           % transport blocks per SNR point
rng_seed = 1;                        % RNG seed for repeatable runs

num_tx_antennas = 4;                  % transmit antennas
num_rx_antennas = 4;                  % receive antennas
num_pdsch_layers = 4;                 % PDSCH layers
prb_set = 0:11;                        % allocated PRBs (0:1 = 2 RB)
pdsch_symbol_allocation = [0 4];      % [start symbol, num symbols] within the slot

tdl_delay_spread = 100e-9;            % TDL RMS delay spread in seconds
maximum_doppler_hz = 70;              % maximum Doppler shift in Hz
channel_filter = "fd";                % channel filter: "td" or "fd"
open_loop_precoder = "identity";      % open-loop precoder
receiver_demapper = "fast_sphere";    % detector: "mmse", "sphere", or "fast_sphere"
% The qam1024 arm runs 1024QAM on 4 layers; fastSphereNCand/MaxList may need
% raising for it to reach its full detection performance.
fast_sphere_max_list = 128;           % fast-sphere max candidate list size for soft LLR computation
fast_sphere_n_cand = 32;              % fast-sphere candidate list size per PAM level
llr_clip_limit = 30;                  % LLR clip magnitude (Inf disables)
max_ldpc_iterations = 25;             % LDPC decoder iteration cap
ldpc_decoding_algorithm = "Layered belief propagation";  % LDPC decoding algorithm
make_plots = true;                    % save overlay BLER/throughput figures
output_root = fullfile("results", "mimo");   % output directory root, relative to repo root

%% SHARED TDL-A OPEN-LOOP CONFIG
% Base config shared by every MCS-table arm in the sweep.
base_cfg.simulation.snrDb = snr_db;
base_cfg.simulation.numTransportBlocks = num_transport_blocks;
base_cfg.simulation.rngSeed = rng_seed;

base_cfg.pdsch.numLayers = num_pdsch_layers;
base_cfg.pdsch.prbSet = prb_set;
base_cfg.pdsch.symbolAllocation = pdsch_symbol_allocation;
base_cfg.pdsch.rv = 0;
base_cfg.pdsch.mcsIndex = mcs_index;

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
base_cfg.receiver.LDPCDecodingAlgorithm = ldpc_decoding_algorithm;
base_cfg.receiver.fastSphereMaxList = fast_sphere_max_list;
base_cfg.receiver.fastSphereNCand = fast_sphere_n_cand;
base_cfg.receiver.llrClipLimit = llr_clip_limit;

base_cfg.mimo.numTransmitAntennas = num_tx_antennas;
base_cfg.mimo.precodingMode = "openloop";
base_cfg.mimo.openLoopPrecoder = open_loop_precoder;

base_cfg.shaping.enabled = false;              % uniform QAM only, no PS
base_cfg.shaping.numShapedAmplitudeBitLevelsPerDimension = 0;

%% BUILD SWEEP VARIANTS: one uniform arm per MCS table
variants = struct('label', {}, 'cfgOverlay', {});
for table_name = uniform_mcs_tables
    cfg = base_cfg;
    cfg.pdsch.mcsTable = table_name;
    variants(end + 1) = struct('label', table_name, 'cfgOverlay', cfg); %#ok<AGROW>
end

%% SCENARIO METADATA
params = struct();
params.scenarioPrefix = "tdla_openloop_4tx4rx_uniform_tables_mcs" + string(mcs_index);
params.scenarioTitle = "TDL-A open-loop 4x4 rank 4, uniform MCS tables (MCS " + string(mcs_index) + ")";
params.outputRoot = output_root;
params.makePlots = make_plots;
params.plotSnrGain = false;                    % gain plot is PS-vs-uniform only

params.variants = variants;
end
