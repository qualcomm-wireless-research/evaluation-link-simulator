function cand_tables = candidate_tables(cfg, ps_enabled)
%CANDIDATE_TABLES Derive the ordered AMC candidate menu from the config.
%
%   CAND_TABLES = CANDIDATE_TABLES(CFG, PS_ENABLED) returns the ordered
%   list of MCS table names as a [1, ncand] string row:
%

if ps_enabled
    operating_table = string(cfg.shaping.mcsTable);
else
    operating_table = string(cfg.pdsch.mcsTable);
end

high_tables = string(cfg.simulation.amc.highMcsTable);

% [] (the default) arrives as a 0-element string, leaving the menu as just the
% operating table. The caller-facing "set this to enable AMC" error belongs in
% validate_config, next to the other config diagnostics.
cand_tables = [operating_table(:).', high_tables(:).'];
end
