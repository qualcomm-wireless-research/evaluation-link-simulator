function [decision, metrics, sorted_snr_db] = decide(state, warmup, snr_db_point)
%DECIDE Run the configured AMC selector on one SNR point's warmup.
%
%   [DECISION, METRICS] = DECIDE(STATE, WARMUP, SNR_DB_POINT) reduces the warmup
%   to one per-layer SNR vector, dispatches to the selector named by
%   STATE.selector, and normalises the result for the per-SNR results row.
%

% --- Reduce this point's warmup to one per-layer SNR vector -------------------
if warmup.count > 0
    switch state.timeDomain
        case 'db'
            mean_layer_snr_db = warmup.timeDomainSum / warmup.count;
        case 'capacity'
            mean_capacity = warmup.timeDomainSum / warmup.count;
            mean_layer_snr_lin = 2 .^ mean_capacity - 1;
            mean_layer_snr_db = 10 * log10(max(mean_layer_snr_lin, realmin));
            mean_layer_snr_db = max(mean_layer_snr_db, -100);
        otherwise
            error('toolbox:amc:InvalidTimeAveragingDomain', ...
                'Unknown AMC time averaging domain "%s".', state.timeDomain);
    end
else
    warning('toolbox:amc:NoWarmupSamples', ...
        ['AMC: no antenna-domain SINR samples collected during warmup ', ...
         'at SNR %.1f dB; AMC decision falls back to a no-op (flat 100 dB ', ...
         'per-layer SNR).'], snr_db_point);
    mean_layer_snr_db = 100 * ones(state.numLayers, 1);
end
if ~all(isfinite(mean_layer_snr_db))
    warning('toolbox:amc:NonFiniteSnr', ...
        ['AMC: non-finite per-layer SNR at SNR %.1f dB; AMC decision ', ...
         'falls back to the baseline MCS.'], snr_db_point);
    mean_layer_snr_db = 100 * ones(state.numLayers, 1);
end

% Sorted for the caller's log line; selectors sort their own input independently.
sorted_snr_db = sort(mean_layer_snr_db, 'descend');

% --- Dispatch ----------------------------------------------------------------
switch state.selector
    case 'condition_number'
        decision = toolbox.amc.select_mcs_by_condition_number(sorted_snr_db, state.params);
    otherwise
        error('toolbox:amc:UnknownSelector', ...
            'Unknown amc.selector "%s".', state.selector);
end

% --- Normalise the selection metrics for the results row ---------------------
% Absent fields stay at the ""/NaN prefill so struct2table sees uniform column
% types on every run, including no-AMC runs.
metrics = struct( ...
    'selector',        string(state.selector), ...
    'timeDomain',      string(state.timeDomain), ...
    'table',           "", ...
    'meanSnrDb',       NaN, ...
    'spreadDb',        NaN);

if isfield(decision, 'mcsTable'); metrics.table = string(decision.mcsTable); end
if isfield(decision, 'meanSnrDb'); metrics.meanSnrDb = decision.meanSnrDb; end
if isfield(decision, 'conditionNumberDb')
    % condition_number's name for the layer-SNR spread.
    metrics.spreadDb = decision.conditionNumberDb;
end
end
