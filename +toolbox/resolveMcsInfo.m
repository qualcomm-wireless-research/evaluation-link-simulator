function mcs_info = resolveMcsInfo(cfg)
%RESOLVEMCSINFO Resolve the active MCS table entry for uniform or PS operation.
%
%   MCS_INFO = RESOLVEMCSINFO(CFG) looks up cfg.pdsch.mcsIndex in the active
%   MCS table: cfg.shaping.mcsTable when shaping is enabled, otherwise
%   cfg.pdsch.mcsTable. MCS_INFO.nu_MB carries the table's Maxwell-Boltzmann
%   shaping parameter for that MCS, used by toolbox.resolveShapingNu.

shaping_enabled = isfield(cfg, 'shaping') ...
    && isfield(cfg.shaping, 'enabled') ...
    && logical(cfg.shaping.enabled);

if shaping_enabled
    if isfield(cfg.shaping, 'mcsTable') ...
            && strlength(string(cfg.shaping.mcsTable)) > 0
        resolved_table_name = string(cfg.shaping.mcsTable);
    else
        resolved_table_name = "ps_mcs_table1";
    end
else
    resolved_table_name = string(cfg.pdsch.mcsTable);
end
mcs_info = toolbox.getMcsInfo(cfg.pdsch.mcsIndex, resolved_table_name);
end
