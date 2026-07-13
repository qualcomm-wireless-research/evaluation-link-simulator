function [mcs_info, effective_shaping_nu, resolved_table_name] = resolveMcsInfo(cfg)
%RESOLVEMCSINFO Resolve the active MCS table for uniform or PS operation.

shaping_enabled = isfield(cfg, 'shaping') ...
    && isfield(cfg.shaping, 'enabled') ...
    && logical(cfg.shaping.enabled);

if shaping_enabled
    resolved_table_name = "ps_mcs_table1";
    if isfield(cfg.shaping, 'mcsTable') ...
            && strlength(string(cfg.shaping.mcsTable)) > 0
        resolved_table_name = string(cfg.shaping.mcsTable);
    end
else
    resolved_table_name = string(cfg.pdsch.mcsTable);
end

mcs_info = toolbox.getMcsInfo(cfg.pdsch.mcsIndex, resolved_table_name);
effective_shaping_nu = 0.0;
if isfield(cfg, 'shaping') && isfield(cfg.shaping, 'nu')
    effective_shaping_nu = cfg.shaping.nu;
end

if ~shaping_enabled
    return;
end

shaped_bit_level = 0;
if isfield(cfg.shaping, 'numShapedAmplitudeBitLevelsPerDimension')
    shaped_bit_level = cfg.shaping.numShapedAmplitudeBitLevelsPerDimension;
end

if shaped_bit_level <= 0
    return;
end

use_mcs_table_nu = true;
if isfield(cfg.shaping, 'useMcsTableNu')
    use_mcs_table_nu = logical(cfg.shaping.useMcsTableNu);
end

if ~use_mcs_table_nu
    return;
end

max_shaped_bit_level = mcs_info.bitsPerSymbol / 2 - 1;
shaped_bit_level = min(shaped_bit_level, max_shaped_bit_level);

if ~isfinite(mcs_info.nu_MB)
    error("toolbox:MissingShapingNuForMCS", ...
        "MCS %d in table %s does not define an MB nu value.", ...
        cfg.pdsch.mcsIndex, mcs_info.table);
end

effective_shaping_nu = mcs_info.nu_MB;
end
