function snr_db = reduce_prg_snr(sinr_per_prg, domain)
%REDUCE_PRG_SNR Reduce per-PRG per-layer SINR to one effective SNR (dB) per layer.
%
%   SNR_DB = REDUCE_PRG_SNR(SINR_PER_PRG, DOMAIN) collapses the frequency (PRG)
%   axis of SINR_PER_PRG -- a [nlayers, nprg] matrix of LINEAR post-equaliser SINR
%   -- into a [nlayers, 1] column of effective SNR in dB.
%

% Unphysical negatives come only from round-off; clamp before any log.
sinr_per_prg = max(sinr_per_prg, 0);

switch lower(char(string(domain)))
    case 'capacity'
        mean_capacity = mean(log2(1 + sinr_per_prg), 2);
        snr_db = lin_to_db(2 .^ mean_capacity - 1);
    otherwise
        error('toolbox:reduce_prg_snr:UnknownDomain', ...
            'PRG averaging domain must be "capacity", not "%s".', ...
            char(string(domain)));
end
end

function snr_db = lin_to_db(snr_lin)
%LIN_TO_DB Linear SNR -> dB, floored so an exactly-zero SINR maps to a large
%negative FINITE value instead of -Inf.
snr_db = 10 * log10(max(snr_lin, realmin));
snr_db = max(snr_db, -100);
end
