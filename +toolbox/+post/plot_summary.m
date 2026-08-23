function plot_summary(summary_rows, output_dir, file_prefix, target_bler)
%PLOT_SUMMARY  Per-MCS BLER and throughput vs SNR, in separate figures.
%   PLOT_SUMMARY(summary_rows, output_dir, file_prefix) draws two figures, each
%   a 1-by-numMCS tiled row with one column per MCS and the chains present in
%   summary_rows (e.g. uniform and PS) overlaid within each cell:
%     * a BLER figure (log y), with the target-BLER reference line (default 10%)
%       and each curve's crossing marked, saved as <file_prefix>_bler.fig/.png;
%     * a throughput figure (linear y), saved as <file_prefix>_throughput.fig/.png.
%   Each subplot keeps a fixed 6:5 aspect box and a single shared legend is
%   placed below the tiles so it never overlaps the data.
%
%   summary_rows must contain columns Chain, MCS, SNR_dB, BLER, Throughput_Mbps.

if nargin < 4 || isempty(target_bler)
    target_bler = 0.10;
end

mcs_values = sort(unique(summary_rows.MCS)).';
chain_modes = unique(summary_rows.Chain).';
num_mcs = numel(mcs_values);
num_chains = numel(chain_modes);

% Keep a consistent color per chain across every subplot so the shared legend
% (one entry per chain) reads the same in each cell.
chain_colors = lines(num_chains);

% ---- BLER figure: one column per MCS ----
[fig, layout] = newRowFigure(num_mcs, "BLER vs. SNR");
bler_axes = gobjects(1, num_mcs);
legend_lines = gobjects(1, num_chains);

for col = 1:num_mcs
    mcs_index = mcs_values(col);
    ax = nexttile(col);
    styleAxes(ax); set(ax, "YScale", "log");
    bler_axes(col) = ax;

    for c = 1:num_chains
        rows = selectRows(summary_rows, chain_modes(c), mcs_index);
        if isempty(rows)
            continue;
        end
        line_h = semilogy(ax, rows.SNR_dB, rows.BLER, "-o", ...
            "Color", chain_colors(c, :), ...
            "MarkerFaceColor", chain_colors(c, :), ...
            "MarkerSize", 5, "LineWidth", 1.6, ...
            "DisplayName", upper(char(chain_modes(c))));
        % Capture one handle per chain for the shared legend.
        if ~isgraphics(legend_lines(c))
            legend_lines(c) = line_h;
        end

        % Mark the target-BLER crossing in the chain's color.
        snr_op = toolbox.post.snr_at_bler(rows.SNR_dB, rows.BLER, target_bler);
        if ~isnan(snr_op)
            plot(ax, snr_op, target_bler, "p", ...
                "MarkerSize", 11, ...
                "MarkerFaceColor", chain_colors(c, :), ...
                "MarkerEdgeColor", "k", ...
                "HandleVisibility", "off");
        end
    end

    yline(ax, target_bler, "--", sprintf("%.0f%% BLER", target_bler * 100), ...
        "Color", [0.4 0.4 0.4], "HandleVisibility", "off");
    title(ax, sprintf("MCS %d", mcs_index));
    xlabel(ax, "SNR (dB)");
    if mod(col - 1, layout.GridSize(2)) == 0
        ylabel(ax, "BLER");
    end
    ylim(ax, [1e-2 1]);
end

linkYLimits(bler_axes);
sharedLegend(layout, bler_axes, legend_lines);

savefig(fig, fullfile(output_dir, file_prefix + "_bler.fig"));
saveas(fig, fullfile(output_dir, file_prefix + "_bler.png"));

% ---- Throughput figure: one column per MCS ----
[fig_tp, layout_tp] = newRowFigure(num_mcs, "Throughput vs. SNR");
throughput_axes = gobjects(1, num_mcs);
legend_lines_tp = gobjects(1, num_chains);

for col = 1:num_mcs
    mcs_index = mcs_values(col);
    ax = nexttile(col);
    styleAxes(ax);
    throughput_axes(col) = ax;

    for c = 1:num_chains
        rows = selectRows(summary_rows, chain_modes(c), mcs_index);
        if isempty(rows)
            continue;
        end
        line_h = plot(ax, rows.SNR_dB, rows.Throughput_Mbps, "-o", ...
            "Color", chain_colors(c, :), ...
            "MarkerFaceColor", chain_colors(c, :), ...
            "MarkerSize", 5, "LineWidth", 1.6, ...
            "DisplayName", upper(char(chain_modes(c))));
        if ~isgraphics(legend_lines_tp(c))
            legend_lines_tp(c) = line_h;
        end
    end

    title(ax, sprintf("MCS %d", mcs_index));
    xlabel(ax, "SNR (dB)");
    if mod(col - 1, layout_tp.GridSize(2)) == 0
        ylabel(ax, "Throughput (Mbps)");
    end
end

linkYLimits(throughput_axes);
sharedLegend(layout_tp, throughput_axes, legend_lines_tp);

savefig(fig_tp, fullfile(output_dir, file_prefix + "_throughput.fig"));
saveas(fig_tp, fullfile(output_dir, file_prefix + "_throughput.png"));
end

function [fig, layout] = newRowFigure(num_mcs, title_text)
% Create a tiled figure for num_mcs subplots, wrapping into a grid capped at
% MAX_COLS columns so a wide MCS sweep stacks into multiple rows instead of one
% cramped strip. Each cell is sized so it reads at ~6:5.
max_cols = 6;
cols = max(min(num_mcs, max_cols), 1);
rows = max(ceil(num_mcs / cols), 1);
per_col_px = 320;           % width budget per subplot column
per_row_px = 360;           % height budget per subplot row (room for legend)
fig = figure("Color", "w", "Units", "pixels", ...
    "Position", [80, 80, cols * per_col_px + 120, rows * per_row_px + 40]);
layout = tiledlayout(rows, cols, "TileSpacing", "compact", "Padding", "compact");
title(layout, title_text, "FontWeight", "bold", "FontSize", 13);
end

function styleAxes(ax)
% Common per-subplot styling: hold, grid, font, and a fixed 6:5 aspect box.
hold(ax, "on");
grid(ax, "on");
set(ax, "FontSize", 10, "GridAlpha", 0.15, "Box", "on");
pbaspect(ax, [6 5 1]);      % lock each subplot to a 6:5 box
end

function sharedLegend(layout, axes_row, legend_lines)
% One horizontal legend for the whole figure, docked below the tiles.
valid = isgraphics(legend_lines);
anchor = axes_row(find(isgraphics(axes_row), 1));
if ~any(valid) || isempty(anchor)
    return;
end
lgd = legend(anchor, legend_lines(valid), "Orientation", "horizontal");
lgd.Layout.Tile = "south";
end

function rows = selectRows(summary_rows, chain_mode, mcs_index)
% Return the SNR-sorted rows for one chain/MCS combination (possibly empty).
mask = summary_rows.Chain == chain_mode & summary_rows.MCS == mcs_index;
rows = summary_rows(mask, :);
if ~isempty(rows)
    rows = sortrows(rows, "SNR_dB");
end
end

function linkYLimits(axes_row)
% Give every axis in a row the same y-limits (max span) so columns compare
% directly. No-op for a single axis.
axes_row = axes_row(isgraphics(axes_row));
if numel(axes_row) < 2
    return;
end
lims = cell2mat(get(axes_row, "YLim"));   % N-by-2: [lo hi] per axis
common = [min(lims(:, 1)), max(lims(:, 2))];
set(axes_row, "YLim", common);
end
