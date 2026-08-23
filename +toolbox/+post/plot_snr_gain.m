function gain_table = plot_snr_gain(summary_rows, output_dir, file_prefix, target_bler)
%PLOT_SNR_GAIN  PS-vs-uniform SNR gain at a target BLER, per MCS.
%   gain_table = PLOT_SNR_GAIN(summary_rows, output_dir, file_prefix)
%   computes, for each MCS and each PS chain in summary_rows, the SNR (dB) at
%   which the uniform and PS BLER curves cross the target BLER (default 10%) and
%   reports the gain
%       gain = SNR@target(uniform) - SNR@target(ps)
%   so a positive gain means PS reaches the target at lower SNR (a shaping gain).
%   Draws a bar chart of gain vs MCS, saves <file_prefix>_snr_gain.fig/.png,
%   writes <file_prefix>_snr_gain.csv, and returns the gain table.
%
%   Any chain whose label is not "uniform" is treated as a PS chain (e.g. "ps",
%   "ess", "ecc"); a gain series is produced for each PS chain present, so the
%   PS chain label does not have to be exactly "ps". MCS/chain points where
%   either chain is missing or never crosses the target yield NaN gain (skipped
%   on the plot) rather than an error. Requires a "uniform" chain plus at least
%   one PS chain in summary_rows to produce a gain.

if nargin < 4 || isempty(target_bler)
    target_bler = 0.10;
end

uniform_label = "uniform";
all_chains = unique(string(summary_rows.Chain), "stable");
ps_chains = all_chains(all_chains ~= uniform_label);

if isempty(ps_chains) || ~any(all_chains == uniform_label)
    warning("toolbox:NoPsVsUniformForGain", ...
        ["plot_snr_gain needs a 'uniform' chain and at least one PS chain; " ...
         "found chains [%s]. Skipping SNR-gain plot."], ...
        strjoin(cellstr(all_chains), ", "));
    gain_table = table('Size', [0 5], ...
        'VariableTypes', {'double', 'string', 'double', 'double', 'double'}, ...
        'VariableNames', {'MCS', 'PsChain', 'SNR_at_target_uniform_dB', ...
        'SNR_at_target_ps_dB', 'SNR_gain_dB'});
    return;
end

mcs_values = sort(unique(summary_rows.MCS));
num_mcs = numel(mcs_values);
num_ps = numel(ps_chains);

% Uniform crossing depends only on MCS; compute it once per MCS.
snr_uniform_by_mcs = nan(num_mcs, 1);
for k = 1:num_mcs
    snr_uniform_by_mcs(k) = crossingForChain( ...
        summary_rows, uniform_label, mcs_values(k), target_bler);
end

% Long-format table: one row per (MCS, PS chain). gain_mat is [num_mcs x num_ps]
% for the grouped bar chart.
mcs_col = zeros(num_mcs * num_ps, 1);
ps_col = strings(num_mcs * num_ps, 1);
snr_uniform_col = nan(num_mcs * num_ps, 1);
snr_ps_col = nan(num_mcs * num_ps, 1);
gain_col = nan(num_mcs * num_ps, 1);
gain_mat = nan(num_mcs, num_ps);

row = 0;
for p = 1:num_ps
    for k = 1:num_mcs
        row = row + 1;
        snr_ps = crossingForChain( ...
            summary_rows, ps_chains(p), mcs_values(k), target_bler);
        gain = snr_uniform_by_mcs(k) - snr_ps;

        mcs_col(row) = mcs_values(k);
        ps_col(row) = ps_chains(p);
        snr_uniform_col(row) = snr_uniform_by_mcs(k);
        snr_ps_col(row) = snr_ps;
        gain_col(row) = gain;
        gain_mat(k, p) = gain;
    end
end

gain_table = table(mcs_col, ps_col, snr_uniform_col, snr_ps_col, gain_col, ...
    'VariableNames', {'MCS', 'PsChain', 'SNR_at_target_uniform_dB', ...
    'SNR_at_target_ps_dB', 'SNR_gain_dB'});

% Grouped bar chart of gain vs MCS, one group of bars per MCS and one bar per
% PS chain. NaN gains leave a gap rather than a bar.
figure;
ax = axes; hold(ax, "on"); grid(ax, "on");
if any(isfinite(gain_mat(:)))
    bar(ax, mcs_values, gain_mat, 0.85);
    yline(ax, 0, "--", "HandleVisibility", "off");
    if num_ps > 1
        legend(ax, cellstr(ps_chains), "Location", "best");
    end
end
xlabel(ax, "MCS index");
ylabel(ax, sprintf("SNR gain at %.0f%% BLER (dB)", target_bler * 100));
title(ax, sprintf("PS vs uniform SNR gain at %.0f%% BLER", target_bler * 100));
if num_mcs > 0
    xticks(ax, mcs_values);
end

savefig(fullfile(output_dir, file_prefix + "_snr_gain.fig"));
saveas(gcf, fullfile(output_dir, file_prefix + "_snr_gain.png"));
writetable(gain_table, fullfile(output_dir, file_prefix + "_snr_gain.csv"));
end

function snr_db = crossingForChain(summary_rows, chain_name, mcs_index, target_bler)
% SNR at the target BLER for one chain/MCS, or NaN if that curve is absent.
mask = string(summary_rows.Chain) == chain_name & summary_rows.MCS == mcs_index;
rows = summary_rows(mask, :);
if isempty(rows)
    snr_db = NaN;
    return;
end
rows = sortrows(rows, "SNR_dB");
snr_db = toolbox.post.snr_at_bler(rows.SNR_dB, rows.BLER, target_bler);
end
