clear; close all; clc;

% Anchor to repo root (parent of tests/) so toolbox.* resolves and results/
% lands at the repo root regardless of the current working directory.
repo_root = fileparts(fileparts(mfilename('fullpath')));
addpath(repo_root);

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
output_root = fullfile(repo_root, "results", "awgn_harq");   % output directory root

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

%% RUN
% Sweep every chain x MCS combination and collect per-SNR summary rows.
scenario_prefix = "awgn_harq";                       % output file stem
scenario_title = "AWGN fixed-MCS sweep";        % figure title

output_dir = fullfile(output_root, scenario_prefix + "_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")));
if ~isfolder(output_dir)
    mkdir(output_dir);
end

summary_rows = table();
all_results = struct();

for chain_mode = string(chain_modes)
    for mcs_index = mcs_list(:).'
        cfg = toolbox.defaultConfig(base_cfg);
        cfg.pdsch.mcsIndex = mcs_index;
        cfg = configureChain(cfg, chain_mode, uniform_mcs_table, ps_mcs_table, ...
            num_shaped_bit_level, ps_tx_scaling, match_ps_tbs_to_uniform);

        fprintf("Running %s, MCS %d, max #trans %d, AWGN SNR [%g..%g] dB\n", ...
            char(chain_mode), mcs_index, cfg.simulation.maxNumTransmissions, ...
            min(snr_db), max(snr_db));
        results = toolbox.runSimulation(cfg);

        % Annotate each per-SNR row with run metadata, then reorder columns.
        rows = results.summaryTable;
        num_rows = height(rows);
        rows.Chain = repmat(chain_mode, num_rows, 1);
        rows.MCS = repmat(mcs_index, num_rows, 1);
        rows.MCS_Table = repmat(string(results.mcsInfo.table), num_rows, 1);
        rows.PayloadBits = repmat(results.payloadTransportBlockSize, num_rows, 1);
        rows.ChainTBSBits = repmat(results.chainTransportBlockSize, num_rows, 1);
        rows.MatchUniformTbs = repmat(logical(cfg.shaping.matchUniformTbs), num_rows, 1);
        rows.PsTxScaling = repmat(string(cfg.shaping.txScaling), num_rows, 1);
        rows.MatchedNu = repmat(getMatchedNu(results), num_rows, 1);
        rows.MaxNumTransmissions = repmat(cfg.simulation.maxNumTransmissions, num_rows, 1);
        move_vars = ["Chain" "MaxNumTransmissions" "MCS" "MCS_Table"];
        if cfg.simulation.maxNumTransmissions > 1
            move_vars = [move_vars "MCS_Table_retx"];
        end
        move_vars = [move_vars "PayloadBits" "ChainTBSBits" ...
            "MatchUniformTbs" "PsTxScaling" "MatchedNu" ...
            "MeanTxSymbolEnergy" "MeanTxPowerScaling"];
        rows = movevars(rows, move_vars, "Before", "SNR_dB");

        if isempty(summary_rows)
            summary_rows = rows;
        else
            summary_rows = [summary_rows; rows]; %#ok<AGROW>
        end

        result_name = matlab.lang.makeValidName(sprintf("%s_mcs%d", char(chain_mode), mcs_index));
        all_results.(result_name) = results;
    end
end

% Persist summary table, full workspace, and optional figures.
writetable(summary_rows, fullfile(output_dir, scenario_prefix + "_summary.csv"));
workspace_vars = struct( ...
    "summaryRows", summary_rows, ...
    "allResults", all_results, ...
    "baseCfg", base_cfg);
save(fullfile(output_dir, scenario_prefix + "_workspace.mat"), "-struct", "workspace_vars");

if make_plots
    plotSummary(summary_rows, output_dir, num_transport_blocks, scenario_prefix, ...
        scenario_title, max_num_transmissions);
end

disp(summary_rows);
fprintf("Saved AWGN sweep outputs to %s\n", output_dir);

%% LOCAL FUNCTIONS
function nu = getMatchedNu(results)
% Return the matched PS nu when TBS matching is active, else NaN.
nu = NaN;
if isfield(results, "tbsMatch") && isfield(results.tbsMatch, "enabled") ...
        && logical(results.tbsMatch.enabled) && isfield(results.tbsMatch, "nu")
    nu = results.tbsMatch.nu;
elseif isfield(results, "config") && isfield(results.config, "shaping") ...
        && isfield(results.config.shaping, "nu")
    nu = results.config.shaping.nu;
end
end

function cfg = configureChain(cfg, chain_mode, uniform_mcs_table, ps_mcs_table, ...
    num_shaped_bit_level, ps_tx_scaling, match_ps_tbs_to_uniform)
% Apply chain-specific MCS table and shaping settings.
switch lower(string(chain_mode))
    case "uniform"
        cfg.pdsch.mcsTable = uniform_mcs_table;
        cfg.shaping.enabled = false;
        cfg.shaping.numShapedAmplitudeBitLevelsPerDimension = 0;
    case "ps"
        cfg.pdsch.mcsTable = ps_mcs_table;
        cfg.shaping.enabled = true;
        cfg.shaping.mcsTable = ps_mcs_table;
        cfg.shaping.numShapedAmplitudeBitLevelsPerDimension = num_shaped_bit_level;
        cfg.shaping.txScaling = ps_tx_scaling;
        cfg.shaping.matchUniformTbs = logical(match_ps_tbs_to_uniform);
        cfg.shaping.uniformMcsTable = uniform_mcs_table;
    otherwise
        error("test_awgn_harq:UnknownChain", "Unsupported chain mode: %s", char(chain_mode));
end
end

function plotSummary(summary_rows, output_dir, num_transport_blocks, file_prefix, ...
    title_text, max_num_transmissions)
% Overlay BLER (log y) and throughput (linear y) across chains and MCS points.
layout = tiledlayout(2, 1, "TileSpacing", "compact");
title(layout, sprintf("%s (max #trans = %d)", title_text, max_num_transmissions));

ax_bler = nexttile; hold(ax_bler, "on"); grid(ax_bler, "on"); set(ax_bler, "YScale", "log");
ax_throughput = nexttile; hold(ax_throughput, "on"); grid(ax_throughput, "on");

for chain_mode = unique(summary_rows.Chain).'
    for mcs_index = unique(summary_rows.MCS).'
        mask = summary_rows.Chain == chain_mode & summary_rows.MCS == mcs_index;
        rows = summary_rows(mask, :);
        if isempty(rows)
            continue;
        end
        label = sprintf("%s MCS %d", upper(char(chain_mode)), mcs_index);
        semilogy(ax_bler, rows.SNR_dB, rows.BLER, "-o", "DisplayName", label);
        plot(ax_throughput, rows.SNR_dB, rows.Throughput_Mbps, "-o", "DisplayName", label);
    end
end

xlabel(ax_bler, "SNR (dB)"); ylabel(ax_bler, "BLER"); ylim(ax_bler, [1e-2 1]);
xlabel(ax_throughput, "SNR (dB)"); ylabel(ax_throughput, "Throughput (Mbps)");
legend(ax_bler, "Location", "best"); legend(ax_throughput, "Location", "best");
savefig(fullfile(output_dir, file_prefix + "_summary.fig"));
saveas(gcf, fullfile(output_dir, file_prefix + "_summary.png"));
end
