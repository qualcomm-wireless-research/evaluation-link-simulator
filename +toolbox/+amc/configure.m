function state = configure(cfg, ps_enabled)
%CONFIGURE Build the immutable AMC state for a whole sweep.
%
%   STATE = CONFIGURE(CFG, PS_ENABLED) collapses everything the AMC subsystem
%   needs into one struct, so runSimulation carries a single variable.
%
%
%
%     .enabled        - true
%     .warmupBlocks   - blocks per SNR point used to measure per-layer SINR
%     .numLayers      - transmission rank (held for the whole sweep; AMC adapts
%                       the modulation/table split, not the rank)
%     .selector       - 'condition_number'
%     .prgDomain      - 'capacity'
%     .geom           - .scPerPrg / .csiSymbol for toolbox.amc.measure_layer_snr
%     .origPsMcsTable - baseline shaping table, restored before each decision
%                       ('' when not on the PS path)
%     .origUniformMcsTable - baseline cfg.pdsch.mcsTable, same role on the
%                       uniform path (always populated)
%     .params         - the selector's parameter struct

state = struct('enabled', logical(cfg.simulation.amc.enabled));
if ~state.enabled
    return;
end

fse = cfg.simulation.amc;

state.warmupBlocks = fse.warmupBlocks;
state.numLayers    = cfg.pdsch.numLayers;

% validate_config already guaranteed these are legal; a second copy of the enum
% lists here would be a third place to keep in sync. reduce_prg_snr still guards
% its own domain argument for direct callers.
state.selector  = lower(char(string(fse.selector)));
state.prgDomain = lower(char(string(fse.prgAveragingDomain)));
state.timeDomain = lower(char(string(fse.timeAveragingDomain)));

if ps_enabled
    state.origPsMcsTable = char(string(cfg.shaping.mcsTable));
else
    state.origPsMcsTable = '';
end

% Uniform-path baseline operating table, counterpart of .origPsMcsTable, captured
% before any decision so the per-SNR restore can undo a previous point's switch.
%   NOT necessarily a uniform-QAM table and NOT the TBS-match anchor: on the PS
% path cfg.pdsch.mcsTable is itself set to the PS table, and the TBS match anchors
% on cfg.shaping.uniformMcsTable. Read this ONLY to restore cfg.pdsch.mcsTable.
state.origUniformMcsTable = char(string(cfg.pdsch.mcsTable));

% Per-PRG SINR geometry. The PRG partition mirrors build_subband_precoders, so the
% metric grid lines up with the closed-loop precoder grid. subbandSize and
% csiSymbol are always populated by defaultConfig, including open-loop runs.
num_sc_per_prb = 12;   % NR: 12 subcarriers per PRB
state.geom = struct( ...
    'scPerPrg',  cfg.mimo.closedLoop.subbandSize * num_sc_per_prb, ...
    'csiSymbol', cfg.mimo.closedLoop.csiSymbol);

% The ordered menu [robust ... aggressive], derived via the shared
% toolbox.amc.candidate_tables -- the same call validate_config makes, so the menu
% that was validated is the menu that runs.
cand_tables = toolbox.amc.candidate_tables(cfg, ps_enabled);

switch state.selector
    case 'condition_number'
        % Entry 1 is the active path's baseline table by construction; the target
        % is the last (densest) entry.
        state.params = struct( ...
            'conditionNumberThresholdDb', fse.conditionNumberThresholdDb, ...
            'mcsIndex',                   cfg.pdsch.mcsIndex, ...
            'refTable',                   char(cand_tables(1)), ...
            'targetTable',                char(cand_tables(end)), ...
            'psEnabled',                  ps_enabled);
    otherwise
        % Unreachable for a validated config, but a loud backstop is cheaper than
        % silently running a different algorithm than the one configured.
        error('toolbox:amc:UnknownSelector', ...
            ['Unknown amc.selector "%s". validate_config should have rejected ', ...
             'this; if you added a selector, register it here too.'], state.selector);
end
end
