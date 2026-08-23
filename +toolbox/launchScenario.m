function run_result = launchScenario(scenario)
%LAUNCHSCENARIO Run every variant of a scenario and aggregate results.
%
%   RUN_RESULT = LAUNCHSCENARIO(SCENARIO) runs toolbox.runSimulation for every
%   entry in SCENARIO.variants (as produced by toolbox.loadScenario), collects
%   per-SNR summary rows annotated with run metadata, writes
%   <prefix>_summary.csv and <prefix>_workspace.mat to a timestamped output
%   directory, and returns a struct with fields:
%     summaryRows    - concatenated, annotated per-SNR summary table
%     allResults     - struct of every variant's full toolbox.runSimulation output
%     outputDir      - timestamped output directory that was written to
%     scenarioPrefix, scenarioTitle, makePlots, plotSnrGain
%                    - carried through from SCENARIO for toolbox.post.plot_scenario

output_dir = fullfile(scenario.outputRoot, ...
    scenario.scenarioPrefix + "_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")));
if ~isfolder(output_dir)
    mkdir(output_dir);
end

summary_rows = table();
all_results = struct();

for v_idx = 1:numel(scenario.variants)
    label = string(scenario.variants(v_idx).label);
    cfg = scenario.variants(v_idx).cfg;

    snr_db = cfg.simulation.snrDb;
    fprintf("Running %s, MCS %d, SNR [%g..%g] dB\n", ...
        char(label), cfg.pdsch.mcsIndex, min(snr_db), max(snr_db));
    results = toolbox.runSimulation(cfg);

    rows = annotateSummary(results, cfg, label);

    if isempty(summary_rows)
        summary_rows = rows;
    else
        summary_rows = [summary_rows; rows]; %#ok<AGROW>
    end

    result_name = matlab.lang.makeValidName(sprintf("%s_mcs%d", char(label), cfg.pdsch.mcsIndex));
    all_results.(result_name) = results;
end

writetable(summary_rows, fullfile(output_dir, scenario.scenarioPrefix + "_summary.csv"));
workspace_vars = struct( ...
    "summaryRows", summary_rows, ...
    "allResults", all_results);
save(fullfile(output_dir, scenario.scenarioPrefix + "_workspace.mat"), "-struct", "workspace_vars");

run_result = struct();
run_result.summaryRows = summary_rows;
run_result.allResults = all_results;
run_result.outputDir = output_dir;
run_result.scenarioPrefix = scenario.scenarioPrefix;
run_result.scenarioTitle = scenario.scenarioTitle;
run_result.makePlots = scenario.makePlots;
run_result.plotSnrGain = scenario.plotSnrGain;
end

function rows = annotateSummary(results, cfg, label)
% Annotate one variant's per-SNR summary rows with run metadata, then move
% the new columns ahead of SNR_dB. defaultConfig guarantees every field
% referenced here exists on cfg, regardless of scenario type.
rows = results.summaryTable;
num_rows = height(rows);

rows.Chain = repmat(label, num_rows, 1);
rows.MCS = repmat(cfg.pdsch.mcsIndex, num_rows, 1);
% Per-point, not repmat'd: under AMC the active table, chain TB size and shaping
% nu are re-resolved at every SNR point, so a sweep-level scalar would label
% every row with the last point's (or, for nu, the pre-sweep) value.
rows.MCS_Table = results.pointMcsTable;
rows.PayloadBits = rows.TBSize_bits;
rows.ChainTBSBits = results.pointChainTransportBlockSize;
rows.MatchUniformTbs = repmat(logical(cfg.shaping.matchUniformTbs), num_rows, 1);
rows.PsTxScaling = repmat(string(cfg.shaping.txScaling), num_rows, 1);
rows.MatchedNu = rows.ShapingNu;
rows.MaxNumTransmissions = repmat(cfg.simulation.maxNumTransmissions, num_rows, 1);
rows.PrecodingMode = repmat(string(cfg.mimo.precodingMode), num_rows, 1);
rows.NumTx = repmat(cfg.mimo.numTransmitAntennas, num_rows, 1);
rows.NumRx = repmat(cfg.channel.numReceiveAntennas, num_rows, 1);
rows.NumLayers = repmat(cfg.pdsch.numLayers, num_rows, 1);
rows.DelayProfile = repmat(string(cfg.channel.delayProfile), num_rows, 1);
rows.DelaySpread_ns = repmat(getDelaySpreadNs(cfg), num_rows, 1);
rows.Doppler_Hz = repmat(cfg.channel.maximumDopplerHz, num_rows, 1);
rows.Precoder = repmat(string(cfg.mimo.openLoopPrecoder), num_rows, 1);

move_vars = ["Chain" "MaxNumTransmissions" "MCS" "MCS_Table"];
if isfield(rows, "MCS_Table_retx")
    move_vars = [move_vars "MCS_Table_retx"];
end
move_vars = [move_vars "PayloadBits" "ChainTBSBits" ...
    "MatchUniformTbs" "PsTxScaling" "MatchedNu" ...
    "PrecodingMode" "NumTx" "NumRx" "NumLayers" ...
    "DelayProfile" "DelaySpread_ns" "Doppler_Hz" "Precoder" ...
    "MeanTxSymbolEnergy" "MeanTxPowerScaling" "MeanNoiseVariance"];
rows = movevars(rows, move_vars, "Before", "SNR_dB");
end

function delay_spread_ns = getDelaySpreadNs(cfg)
% channel.delaySpread is only meaningful (and only ever set) for TDL/CDL;
% AWGN configs never populate it, so fall back to NaN rather than erroring.
delay_spread_ns = NaN;
if isfield(cfg.channel, "delaySpread")
    delay_spread_ns = cfg.channel.delaySpread * 1e9;
end
end
