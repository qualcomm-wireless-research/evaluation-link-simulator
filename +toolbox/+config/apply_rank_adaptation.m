function cfg = apply_rank_adaptation(cfg)
%APPLY_RANK_ADAPTATION Reduce rank if MCS is not supported at the requested rank.
%
%   CFG = APPLY_RANK_ADAPTATION(CFG) checks whether the configured MCS
%   index is within the allowed range for the requested rank. If not, the
%   rank is reduced and MCS is selected to maximize the resulting total
%   spectral efficiency without exceeding the original total.
%   Uniform adaptation is supported for QAM256 only. PS adaptation falls
%   back to uniform QAM256 if the PS table has no feasible MCS.

if ~cfg.mimo.rankAdaptation
    return;
end

% Only apply rank adaptation for closed-loop precoding
if ~(lower(string(cfg.mimo.precodingMode)) == "closedloop")
    return;
end

num_layers = cfg.pdsch.numLayers;
if num_layers <= 1
    return;
end

mcs_info = toolbox.resolveMcsInfo(cfg);
shaping_enabled = isfield(cfg, 'shaping') ...
    && isfield(cfg.shaping, 'enabled') ...
    && logical(cfg.shaping.enabled);
ps_table_enabled = shaping_enabled && startsWith(string(mcs_info.table), "ps_");
if ~strcmp(mcs_info.table, 'qam256') && ~ps_table_enabled
    return;
end

% Build lookup key
key = sprintf("x%dx%d_%s", cfg.mimo.numTransmitAntennas, ...
    cfg.channel.numReceiveAntennas, strrep(cfg.channel.delayProfile, '-', '_'));

tbl = toolbox.config.get_rank_mcs_table();

if ~isfield(tbl, key)
    return;
end

entry = tbl.(key);
mcs = cfg.pdsch.mcsIndex;
original_rank = num_layers;

% Check rank 4 -> rank 3 reduction
if num_layers == 4 && mcs < entry.min_mcs_rank4
    num_layers = 3;
end

% Check rank 3 -> rank 2 reduction (direct request at rank 3)
if original_rank == 3 && num_layers == 3 && mcs < entry.min_mcs_rank3
    num_layers = 2;
end

if num_layers < original_rank
    % Select the MCS with the highest total spectral efficiency that does
    % not exceed the original total spectral efficiency.
    original_total_speff = mcs_info.spectralEfficiency * original_rank;
    mcs_table_name = mcs_info.table;
    [new_mcs, new_mcs_table] = toolbox.config.select_rank_adapted_mcs( ...
        original_total_speff, num_layers, mcs_table_name);

    % Check if the new MCS at rank 3 needs further cascade to rank 2
    if num_layers == 3 && new_mcs < entry.min_mcs_rank3
        num_layers = 2;
        [new_mcs, new_mcs_table] = toolbox.config.select_rank_adapted_mcs( ...
            original_total_speff, num_layers, mcs_table_name);
    end

    config_name = sprintf("%dx%d %s", cfg.mimo.numTransmitAntennas, ...
        cfg.channel.numReceiveAntennas, cfg.channel.delayProfile);
    cfg.pdsch.numLayers = num_layers;
    cfg.pdsch.mcsIndex = new_mcs;
    if ~strcmp(new_mcs_table, mcs_table_name)
        cfg.pdsch.mcsTable = new_mcs_table;
        cfg.shaping.enabled = false;
        cfg.shaping.numShapedAmplitudeBitLevelsPerDimension = 0;
        fprintf("Warning: Rank adaptation - MCS %d not supported at rank %d " + ...
            "for %s. Reducing rank to %d, switching to %s MCS %d.\n", ...
            mcs, original_rank, config_name, num_layers, new_mcs_table, new_mcs);
    else
        fprintf("Warning: Rank adaptation - MCS %d not supported at rank %d " + ...
            "for %s. Reducing rank to %d, MCS adjusted to %d.\n", ...
            mcs, original_rank, config_name, num_layers, new_mcs);
    end
end

end
