function [cfg, tbs_match] = resolveShapingNu(cfg, mcs_info)
%RESOLVESHAPINGNU Resolve cfg.shaping.nu for probabilistic shaping.
%
%   [CFG, TBS_MATCH] = RESOLVESHAPINGNU(CFG, MCS_INFO) sets cfg.shaping.nu:
%   - When cfg.shaping.matchUniformTbs, searches nu so the PS payload TBS
%     matches the uniform-QAM TBS for the same MCS
%     (match_ps_nu_to_uniform_tbs); TBS_MATCH carries the match diagnostics.
%   - Otherwise nu is taken directly from the active MCS table's
%     Maxwell-Boltzmann parameter, MCS_INFO.nu_MB.
%   When shaping is disabled (or no shaped amplitude bit levels are
%   requested), CFG is returned unchanged and TBS_MATCH.enabled is false.

tbs_match = struct('enabled', false);

shaping_enabled = isfield(cfg, 'shaping') ...
    && isfield(cfg.shaping, 'enabled') ...
    && logical(cfg.shaping.enabled);
if ~shaping_enabled
    return;
end

if logical(cfg.shaping.matchUniformTbs)
    tbs_match = toolbox.ProbShaping.provider.match_ps_nu_to_uniform_tbs( ...
        cfg, ...
        'UniformMcsTable', cfg.shaping.uniformMcsTable, ...
        'PsMcsTable', cfg.shaping.mcsTable, ...
        'Levels', cfg.shaping.numShapedAmplitudeBitLevelsPerDimension, ...
        'ToleranceFraction', cfg.shaping.tbsMatchToleranceFraction, ...
        'MaxIterations', cfg.shaping.tbsMatchMaxIterations);
    tbs_match.enabled = true;
    cfg.shaping.nu = tbs_match.nu;
    return;
end

shaped_bit_level = 0;
if isfield(cfg.shaping, 'numShapedAmplitudeBitLevelsPerDimension')
    shaped_bit_level = cfg.shaping.numShapedAmplitudeBitLevelsPerDimension;
end
if shaped_bit_level <= 0
    return;
end

if ~isfinite(mcs_info.nu_MB)
    error("toolbox:MissingShapingNuForMCS", ...
        "MCS %d in table %s does not define an MB nu value.", ...
        cfg.pdsch.mcsIndex, mcs_info.table);
end

if mcs_info.nu_MB == 0
    error("toolbox:PlaceholderShapingNuForMCS", ...
        ['MCS %d in table %s has a placeholder nu_MB of 0, so nu cannot be read ', ...
         'from the table. Set cfg.shaping.matchUniformTbs = true to solve nu by ', ...
         'TBS matching, or use a table that defines a real nu_MB column.'], ...
        cfg.pdsch.mcsIndex, mcs_info.table);
end
cfg.shaping.nu = mcs_info.nu_MB;
end
