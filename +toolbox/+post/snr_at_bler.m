function snr_db = snr_at_bler(snr_points, bler, target_bler)
%SNR_AT_BLER  SNR (dB) at which a BLER-vs-SNR curve crosses a target BLER.
%   snr_db = SNR_AT_BLER(snr_points, bler, target_bler) finds the SNR where the
%   BLER-vs-SNR curve first crosses target_bler (default 0.10, i.e. the 10% BLER
%   operating point) as SNR increases, interpolating log10(BLER) linearly across
%   the single bracketing SNR interval. Log space is used because these curves
%   are near-linear on a log-BLER axis, the standard convention for reading SNR
%   operating points. Only the bracketing pair is used, so a globally
%   non-monotonic (Monte-Carlo-noisy) curve is handled without erroring.
%
%   Returns NaN when the curve never crosses the target (every point is above,
%   or every point is below, the target), so a too-short or mis-ranged sweep
%   degrades gracefully rather than erroring.
%
%   Inputs:
%     snr_points  - vector of SNR points in dB
%     bler        - matching vector of BLER values in [0, 1]
%     target_bler - optional target BLER (default 0.10)

if nargin < 3 || isempty(target_bler)
    target_bler = 0.10;
end

snr_points = snr_points(:);
bler = bler(:);

% Drop non-finite and non-positive BLER (log undefined) while keeping the
% paired SNR. Zeros are treated as below-target crossings via the guard below.
valid = isfinite(snr_points) & isfinite(bler);
snr_points = snr_points(valid);
bler = bler(valid);

snr_db = NaN;
if numel(snr_points) < 2
    return;
end

% Sort by SNR so interpolation runs along an increasing x-axis.
[snr_points, order] = sort(snr_points);
bler = bler(order);

% The curve must straddle the target for an in-range crossing to exist.
if min(bler) > target_bler || max(bler) < target_bler
    return;
end

% Interpolate log10(BLER) vs SNR. Clamp BLER to a small floor so exact zeros
% (all blocks decoded) remain usable as a below-target endpoint.
bler_floor = 1e-6;
log_bler = log10(max(bler, bler_floor));
log_target = log10(max(target_bler, bler_floor));

% Find the first SNR interval that brackets the target (a sign change of
% bler - target between adjacent, SNR-sorted points) and interpolate log10(BLER)
% vs SNR within just that pair. Interpolating the whole curve is unsafe: with
% Monte-Carlo BLER the curve wiggles and is not globally monotonic, so a
% full-curve interp1 would either error ("grid vectors must be monotonically
% increasing") or read off the wrong crossing. Restricting to the bracketing
% segment is robust to global non-monotonicity and matches the operating-point
% convention (first crossing as SNR increases).
diff_bler = bler - target_bler;
snr_db = NaN;
for k = 1:(numel(diff_bler) - 1)
    d0 = diff_bler(k);
    d1 = diff_bler(k + 1);
    % Bracket when the two endpoints sit on opposite sides of the target
    % (product <= 0). Skip a flat pair sitting exactly on the target on both
    % ends (d0 == d1 == 0) to avoid a degenerate divide.
    if d0 * d1 <= 0 && ~(d0 == 0 && d1 == 0)
        y0 = log_bler(k);
        y1 = log_bler(k + 1);
        if y1 == y0
            % Flat log-BLER across the pair: no unique crossing SNR; take the
            % lower-SNR endpoint as the operating point.
            snr_db = snr_points(k);
        else
            t = (log_target - y0) / (y1 - y0);
            snr_db = snr_points(k) + t * (snr_points(k + 1) - snr_points(k));
        end
        return;
    end
end
end
