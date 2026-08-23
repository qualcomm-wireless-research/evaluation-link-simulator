function decision = select_mcs_by_condition_number(per_layer_snr_db, params)
%SELECT_MCS_BY_CONDITION_NUMBER AMC gated on layer-SNR spread ("condition number").
%
%   DECISION = SELECT_MCS_BY_CONDITION_NUMBER(PER_LAYER_SNR_DB, PARAMS) measures
%   the spread between the strongest and weakest layer's effective SNR
%   (L1 - Lmin, dB) and, once it exceeds a threshold, switches the MCS TABLE from
%   the configured reference (qam256 on uniform, ps_mcs_table2 on PS) to a
%   companion table (qam1024, ps_mcs_table3) at the SAME MCS index. The companion
%   table carries the same spectral efficiency row-for-row, so the switch is
%   SpEff-preserving by construction. It selects a TABLE, not a modulation: the
%   resulting modulation and code rate are whatever getMcsInfo resolves for that
%   row.


sorted_snr_db = sort(per_layer_snr_db(:), 'descend');
condition_number_db = sorted_snr_db(1) - sorted_snr_db(end);
mean_snr_db = mean(sorted_snr_db);

ref_table = string(params.refTable);

% Default uniform for back-compat.
ps_enabled = false;
if isfield(params, 'psEnabled') && ~isempty(params.psEnabled)
    ps_enabled = logical(params.psEnabled);
end

% Default: no change -- hold the configured table.
decision = struct( ...
    'action', "none", ...
    'modulation', "", ...
    'codeRate', NaN, ...
    'mcsTable', ref_table, ...
    'psMcsTable', ref_table, ...
    'psEnabled', ps_enabled, ...
    'conditionNumberDb', condition_number_db, ...
    'meanSnrDb', mean_snr_db, ...
    'reason', "condition number within threshold");

if condition_number_db <= params.conditionNumberThresholdDb
    return;
end

target_table = string(params.targetTable);
if strcmpi(target_table, ref_table)
    decision.reason = sprintf( ...
        "condition number %.1f dB > %.1f dB but already at target table %s", ...
        condition_number_db, params.conditionNumberThresholdDb, target_table);
    return;
end

% Switch to the denser companion table at the same MCS index. The caller applies
% this identically on both paths: write the operating table, re-resolve the MCS
% row, re-resolve the shaping nu (a no-op when shaping is off).
target_row = toolbox.getMcsInfo(params.mcsIndex, target_table);

decision.action = "tableSwitch";
decision.modulation = string(target_row.modulation);
decision.codeRate = target_row.targetCodeRate;
decision.mcsTable = target_table;
decision.psMcsTable = target_table;
decision.reason = sprintf("condition number %.1f dB > %.1f dB: table %s -> %s, mod %s, cr %.4f", ...
    condition_number_db, params.conditionNumberThresholdDb, ...
    ref_table, target_table, string(target_row.modulation), target_row.targetCodeRate);
end
